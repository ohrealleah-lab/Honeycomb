using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class GameViewModel : ObservableObject
{
    [ObservableProperty]
    private GameState _state = new();

    [ObservableProperty]
    private GameOptions _options;

    [ObservableProperty]
    private GameStatistics _stats;

    [ObservableProperty]
    private bool _isAutocompletable;

    [ObservableProperty]
    private bool _isAutoplayRunning;

    [ObservableProperty]
    private bool _hasNoMoves;

    [ObservableProperty]
    private HintMove? _activeHint;

    public Pile Stock { get; } = new("Stock", PileType.Stock);
    public Pile Waste { get; } = new("Waste", PileType.Waste);
    public List<Pile> Foundations { get; } = new();
    public List<Pile> Tableaus { get; } = new();

    private readonly Stack<GameStateSnapshot> _undoStack = new();
    private List<Card> _initialDeck = new();
    private System.Threading.Timer? _gameTimer;
    private int _vegasGameStartScore;

    // Set by PauseTimerForSwitch when the timer was actually running at the moment this
    // game was switched away from, so ResumeTimerForSwitch only restarts it if it was
    // genuinely paused (not, say, a fresh/unstarted or already-won game).
    private bool _timerPausedForSwitch;

    // Bankroll immediately before this deal's buy-in was subtracted, captured in
    // InitializeGame. RestartGame (replay the same deal) restores to this instead of
    // to the post-buy-in starting score, so replaying a deal is free — only playing
    // a genuinely new deal (InitializeGame) costs a fresh buy-in.
    private int _vegasBalanceBeforeDeal;

    // Running total of every standard-mode "-2 every 8 seconds" time penalty applied so
    // far this game, tracked separately from State.Score. Undo needs this to reverse only
    // the specific move it's undoing — if it just restored State.Score to its pre-move
    // snapshot value, it would also refund any time penalties that legitimately accrued
    // in the meantime (real time elapsed between the move and pressing Undo), which have
    // nothing to do with that move.


    private List<HintMove> _hintCycleList  = new();
    private int            _hintCycleIndex = 0;

    // Tracks the last card move so hints can filter out its exact reversal.
    private string? _lastMoveSourcePileId;
    private string? _lastMoveTargetPileId;

    private readonly SynchronizationContext? _syncContext;
    private int _foundationCardCount;

    private System.Threading.Timer? _autocompleteTimer;
    // Windows-fork deviation: once autocomplete has ever run this game, Undo stays
    // disabled for the rest of the game (rather than allowing mid-autoplay cancel-undo).
    private bool _autocompleteLocked;

    public string TimeDisplay => TimeSpan.FromSeconds(State?.TimerSeconds ?? 0).ToString(@"mm\:ss");

    public string ScoreDisplay => ScoreFormatter.FormatScore(State.Score, Options?.IsVegasScoring == true);

    partial void OnStateChanged(GameState value) => OnPropertyChanged(nameof(ScoreDisplay));
    partial void OnOptionsChanged(GameOptions value) => OnPropertyChanged(nameof(ScoreDisplay));

    public GameViewModel()
    {
        _syncContext = SynchronizationContext.Current;
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            bool vegasChanged = m.Options.IsVegasScoring != Options.IsVegasScoring;
            // No Stress Mode's whole point is "no timer" — if it's switched on mid-game,
            // stop the timer immediately instead of leaving it ticking until the next deal.
            bool noStressJustEnabled = m.Options.IsNoStressMode && !Options.IsNoStressMode;
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
            if (vegasChanged) InitializeGame(countAsNewGame: false);
            else if (noStressJustEnabled && State.IsTimerActive)
                State.IsTimerActive = false;
        });

        for (int i = 0; i < 4; i++)
        {
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));
        }

        for (int i = 0; i < 7; i++)
        {
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));
        }

        InitializeGame();
    }

    public void InitializeGame(bool countAsNewGame = true)
    {
        if (State.MovesCount > 0 && !State.HasWon)
            Stats.CurrentStreak = 0;

        ClearHintCycle();
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        _autocompleteTimer?.Dispose();
        _autocompleteTimer = null;
        IsAutoplayRunning = false;
        _autocompleteLocked = false;
        Stock.Cards.Clear();
        Waste.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        _foundationCardCount = 0;
        foreach (var t in Tableaus) t.Cards.Clear();
        _undoStack.Clear();

        _vegasBalanceBeforeDeal = State.Score;
        int startScore = Options.IsVegasScoring ? State.Score - 5200 : 0;
        _vegasGameStartScore = startScore;

        State = new GameState
        {
            Score = startScore,
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = false,
            HasWon = false,
            RecyclesCount = 0,
            Mode = Options.IsDrawConstraintsEnabled ? DrawMode.DrawThree : DrawMode.DrawOne
        };

        // Create standard 52 card deck
        var deck = new List<Card>();
        var suits = new[] { CardSuit.Spades, CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs };
        foreach (var suit in suits)
        {
            for (int rank = 1; rank <= 13; rank++)
            {
                var suitName = suit.ToString().ToLower();
                var rankStr = rank switch
                {
                    1 => "A",
                    11 => "J",
                    12 => "Q",
                    13 => "K",
                    _ => rank.ToString()
                };
                deck.Add(new Card($"{suitName}_{rankStr}", suit, rank, false));
            }
        }

        // Shuffle deck - Fisher-Yates O(n)
        var rng = new Random();
        for (int i = deck.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (deck[i], deck[j]) = (deck[j], deck[i]);
        }

        // Save a copy of the shuffled deck for RestartGame
        _initialDeck = deck.Select(c => c with { IsFaceUp = false }).ToList();

        // Deal cards to tableau using index cursor (avoids O(n²) RemoveAt(0))
        int deckIdx = 0;
        for (int i = 0; i < 7; i++)
        {
            for (int j = 0; j <= i; j++)
            {
                var card = deck[deckIdx++];

                // Top card is face up
                if (j == i)
                {
                    card = card with { IsFaceUp = true };
                }

                Tableaus[i].Cards.Add(card);
            }
        }

        // Put remaining cards in stock
        for (int i = deckIdx; i < deck.Count; i++)
        {
            Stock.Cards.Add(deck[i]);
        }

        IsAutocompletable = false;
        HasNoMoves = false;

        if (countAsNewGame) Stats.GamesPlayed++;
        StatsService.SaveStats(Stats);

        // Start background timer ticking
        _gameTimer?.Dispose();
        _gameTimer = new System.Threading.Timer(_ =>
        {
            // The whole check-and-mutate runs on the UI thread via _syncContext.Post,
            // not just the notification — State is a shared mutable object also written
            // to from the UI thread (Restart/Undo/InitializeGame), so mutating
            // State.TimerSeconds directly on this background timer thread would race
            // with those writes.
            _syncContext?.Post(_ => OnTimerTick(), null);
        }, null, 1000, 1000);

        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
    }

    public void RestartGame()
    {
        if (!_initialDeck.Any()) return;

        // Restart refunds this deal's Vegas buy-in (see the comment below) on the theory
        // that the player already paid for and engaged with this exact deal, so retrying
        // it from scratch isn't a fresh charge. Without this guard, New Game (charge the
        // buy-in) immediately followed by Restart (refund it) — before making even one
        // move — hands back the identical freshly-dealt board at zero net cost, letting
        // a player "reroll" for a nicer deal, or simply play any deal, entirely for free.
        if (State.MovesCount == 0) return;

        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        _autocompleteTimer?.Dispose();
        _autocompleteTimer = null;
        IsAutoplayRunning = false;
        _autocompleteLocked = false;

        // Clear everything
        Stock.Cards.Clear();
        Waste.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        _foundationCardCount = 0;
        foreach (var t in Tableaus) t.Cards.Clear();
        _undoStack.Clear();

        // Restart replays the same deal for free — restore the bankroll to what it
        // was before this deal's buy-in, reversing both the buy-in and any in-game
        // foundation gains, rather than charging a fresh buy-in like a new deal would.
        State.Score = Options.IsVegasScoring ? _vegasBalanceBeforeDeal : 0;
        _vegasGameStartScore = State.Score;
        OnPropertyChanged(nameof(ScoreDisplay));
        State.MovesCount = 0;
        State.TimerSeconds = 0;
        State.IsTimerActive = false;
        State.HasWon = false;
        State.RecyclesCount = 0;
        State.WasteDrawBatchSize = 0;
        IsAutocompletable = false;
        HasNoMoves = false;
        ClearHintCycle();

        var deckCopy = _initialDeck.Select(c => c).ToList();

        // Deal cards to tableau in the exact same order using index cursor
        int copyIdx = 0;
        for (int i = 0; i < 7; i++)
        {
            for (int j = 0; j <= i; j++)
            {
                var card = deckCopy[copyIdx++];

                // Top card is face up
                if (j == i)
                {
                    card = card with { IsFaceUp = true };
                }

                Tableaus[i].Cards.Add(card);
            }
        }

        // Put remaining cards in stock
        for (int i = copyIdx; i < deckCopy.Count; i++)
        {
            Stock.Cards.Add(deckCopy[i]);
        }

        // Reset and restart background timer ticking
        _gameTimer?.Dispose();
        _gameTimer = new System.Threading.Timer(_ =>
        {
            // The whole check-and-mutate runs on the UI thread via _syncContext.Post,
            // not just the notification — State is a shared mutable object also written
            // to from the UI thread (Restart/Undo/InitializeGame), so mutating
            // State.TimerSeconds directly on this background timer thread would race
            // with those writes.
            _syncContext?.Post(_ => OnTimerTick(), null);
        }, null, 1000, 1000);

        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
        // RestartGame mutates the existing State object in place rather than replacing
        // it, so this is the only way the View's nameof(State) handler (which resets
        // _winTriggered and hides the victory overlay) ever fires for a restart —
        // without it, restarting a just-won game leaves the win animation stuck on
        // screen and permanently suppresses the next win's animation.
        OnPropertyChanged(nameof(State));
    }

    // Shared by both InitializeGame's and RestartGame's background timer, so the two
    // don't duplicate (and risk drifting on) this tick logic. Always advances the clock.
    private void OnTimerTick()
    {
        if (State == null || !State.IsTimerActive || State.HasWon) return;
        State.TimerSeconds++;
        OnPropertyChanged(nameof(TimeDisplay));
    }

    // Called by AppCoordinator when switching away to a different game — the background
    // _gameTimer keeps running regardless of which game's View is on screen, so without
    // this it silently piles up TimerSeconds for however long the player is away,
    // corrupting ShortestWinSeconds/TotalWinSeconds on the next win.
    public void PauseTimerForSwitch()
    {
        if (State.IsTimerActive)
        {
            State.IsTimerActive = false;
            _timerPausedForSwitch = true;
        }
    }

    public void ResumeTimerForSwitch()
    {
        if (_timerPausedForSwitch)
        {
            State.IsTimerActive = true;
            _timerPausedForSwitch = false;
        }
    }

    public void DrawCard()
    {
        if (Stock.Cards.Count == 0)
        {
            // Recycle waste back to stock — guard no-ops before snapshot
            if (Waste.Cards.Count == 0) return;
            // Real Vegas-scoring rules: Draw One gets a single pass through the deck (no
            // recycles at all); Draw Three gets 2 recycles (3 total passes).
            int vegasRecycleLimit = State.Mode == DrawMode.DrawThree ? 2 : 0;
            if (Options.IsVegasScoring && State.RecyclesCount >= vegasRecycleLimit) return;

            ClearHintCycle();
            SaveStateForUndo();
            State.RecyclesCount++;
            State.WasteDrawBatchSize = 0;

            // Move waste cards to stock in reverse order, turn face down
            var wasteCards = Waste.Cards.ToList();
            wasteCards.Reverse();
            foreach (var card in wasteCards)
            {
                Stock.Cards.Add(card with { IsFaceUp = false });
            }
            Waste.Cards.Clear();
            if (!State.IsTimerActive && !State.HasWon && !Options.IsNoStressMode)
                State.IsTimerActive = true;
            State.MovesCount++;
            CheckDeadlock();
            OnPropertyChanged(nameof(Stock));
            OnPropertyChanged(nameof(Waste));
            OnPropertyChanged(nameof(CanUndo));
            return;
        }

        ClearHintCycle();
        SaveStateForUndo();

        int drawCount = State.Mode == DrawMode.DrawThree ? 3 : 1;
        int cardsToDraw = Math.Min(drawCount, Stock.Cards.Count);

        // Pop off the top of Stock and append to Waste in that same raw pop order — no
        // within-batch reversal. The last-popped card of the batch (the one furthest
        // from the top of Stock before this draw) ends up on top of Waste.
        var drawn = new List<Card>(cardsToDraw);
        for (int i = 0; i < cardsToDraw; i++)
        {
            drawn.Add(Stock.Cards[^1] with { IsFaceUp = true });
            Stock.Cards.RemoveAt(Stock.Cards.Count - 1);
        }
        foreach (var card in drawn)
            Waste.Cards.Add(card);
        State.WasteDrawBatchSize = cardsToDraw;

        if (!State.IsTimerActive && !State.HasWon && !Options.IsNoStressMode)
            State.IsTimerActive = true;
        State.MovesCount++;
        CheckAutocomplete();
        CheckDeadlock();
        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(CanUndo));
    }

    public bool CanMoveCard(Card card, Pile targetPile)
    {
        if (targetPile == null || card == null) return false;

        // Find the source pile
        var sourcePile = FindPileContaining(card);
        if (sourcePile == null) return false;

        // If card is not face up, it cannot be moved
        if (!card.IsFaceUp) return false;

        // Check rules based on target pile type
        if (targetPile.Type == PileType.Tableau)
        {
            // Validate the sub-stack from card to the pile top is a proper alternating-color run
            if (sourcePile.Type == PileType.Tableau)
            {
                int cardIndex = sourcePile.Cards.IndexOf(card);
                for (int i = cardIndex; i < sourcePile.Cards.Count - 1; i++)
                {
                    var curr = sourcePile.Cards[i];
                    var next = sourcePile.Cards[i + 1];
                    if (!next.IsFaceUp || IsRed(curr.Suit) == IsRed(next.Suit) || curr.Rank != next.Rank + 1)
                        return false;
                }
            }

            // Only King can go to empty tableau
            if (targetPile.Cards.Count == 0)
                return card.Rank == 13;

            var targetTopCard = targetPile.Cards.Last();
            if (!targetTopCard.IsFaceUp) return false;

            bool alternates = (IsRed(card.Suit) != IsRed(targetTopCard.Suit));
            bool sequential = (targetTopCard.Rank == card.Rank + 1);

            return alternates && sequential;
        }
        else if (targetPile.Type == PileType.Foundation)
        {
            // Foundation-to-foundation is legal (players reorganize which foundation slot
            // holds which suit — the only reachable case is relocating a lone Ace between
            // two otherwise-empty foundations, since any foundation with a 2+ buries its
            // Ace for good). UpdateScoreForMove excludes this from the Vegas +500 bonus so
            // it can't be shuffled back and forth for free score — see that method.

            // Foundation can only receive single cards, not stacks
            // Check if card is the top card of its pile
            if (sourcePile.Cards.Last() != card) return false;

            if (targetPile.Cards.Count == 0)
            {
                // Must be an Ace (rank 1)
                return card.Rank == 1;
            }

            var targetTopCard = targetPile.Cards.Last();
            
            // Must be same suit and exactly 1 rank higher
            bool sameSuit = (targetTopCard.Suit == card.Suit);
            bool sequential = (card.Rank == targetTopCard.Rank + 1);

            return sameSuit && sequential;
        }

        return false;
    }

    public void MoveCard(Card card, Pile targetPile)
    {
        if (!CanMoveCard(card, targetPile)) return;

        ClearHintCycle();
        SaveStateForUndo();

        var sourcePile = FindPileContaining(card);
        int index = sourcePile.Cards.IndexOf(card);

        _lastMoveSourcePileId = sourcePile.Id;
        _lastMoveTargetPileId = targetPile.Id;

        // Extract cards from the index to the end
        var cardsToMove = sourcePile.Cards.GetRange(index, sourcePile.Cards.Count - index);
        sourcePile.Cards.RemoveRange(index, sourcePile.Cards.Count - index);

        if (sourcePile == Waste && State.Mode == DrawMode.DrawThree)
            State.WasteDrawBatchSize = Math.Max(0, State.WasteDrawBatchSize - 1);

        // Add to target pile
        foreach (var c in cardsToMove)
        {
            targetPile.Cards.Add(c);
        }
        if (targetPile.Type == PileType.Foundation) _foundationCardCount += cardsToMove.Count;
        if (sourcePile.Type == PileType.Foundation)  _foundationCardCount -= cardsToMove.Count;

        // Auto flip the new top card of the source pile if it's a tableau
        bool didFlip = false;
        if (sourcePile.Type == PileType.Tableau && sourcePile.Cards.Count > 0)
        {
            var topCard = sourcePile.Cards.Last();
            if (!topCard.IsFaceUp)
            {
                sourcePile.Cards[sourcePile.Cards.Count - 1] = topCard with { IsFaceUp = true };
                didFlip = true;
            }
        }

        // Update score
        UpdateScoreForMove(sourcePile.Type, targetPile.Type, didFlip);

        if (!State.IsTimerActive && !State.HasWon && !Options.IsNoStressMode)
            State.IsTimerActive = true;
        State.MovesCount++;
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        // MoveCard never touches Stock, so don't notify it — doing so made the
        // stock pile re-render (and visibly jitter) on every unrelated tableau move.
        if (sourcePile == Waste || targetPile == Waste)
            OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(CanUndo));
    }

    private void UpdateScoreForMove(PileType source, PileType target, bool didFlip = false)
    {
        if (Options.IsVegasScoring)
        {
            // Excludes source==Foundation so relocating a card between foundations (e.g.
            // reorganizing which foundation slot holds which suit's Ace) nets zero score
            // either way — otherwise a lone Ace shuffled between two empty foundations
            // would earn +500 every single move, forever, for free.
            if (target == PileType.Foundation && source != PileType.Foundation)
                State.Score += 500;
            else if (source == PileType.Foundation && target == PileType.Tableau)
                State.Score -= 500;
            OnPropertyChanged(nameof(ScoreDisplay));
        }
        else
        {
            // Standard Klondike scoring rules:
            // Waste to Tableau: 5 pts
            // Waste to Foundation: 10 pts
            // Tableau to Foundation: 10 pts
            // Turn over Tableau card: 5 pts
            // Foundation to Tableau: -15 pts
            if (source == PileType.Waste && target == PileType.Tableau) State.Score += 5;
            else if (source == PileType.Waste && target == PileType.Foundation) State.Score += 10;
            else if (source == PileType.Tableau && target == PileType.Foundation) State.Score += 10;
            else if (source == PileType.Foundation && target == PileType.Tableau) State.Score -= 15;
            if (didFlip) State.Score += 5;
            OnPropertyChanged(nameof(ScoreDisplay));
        }
    }

    public void SaveStateForUndo()
    {
        // No-op during autoplay so every move it makes bundles into the single
        // pre-autocomplete snapshot already pushed when Autocomplete() started.
        if (IsAutoplayRunning) return;

        var snapshot = new GameStateSnapshot
        {
            Score                    = State.Score,
            MovesCount               = State.MovesCount,
            TimerSeconds             = State.TimerSeconds,
            RecyclesCount            = State.RecyclesCount,
            HasWon                   = State.HasWon,
            WasteDrawBatchSize       = State.WasteDrawBatchSize,
            PileCards                = new List<List<Card>>()
        };

        // Snapshot all piles
        snapshot.PileCards.Add(Stock.Cards.ToList());
        snapshot.PileCards.Add(Waste.Cards.ToList());
        foreach (var f in Foundations) snapshot.PileCards.Add(f.Cards.ToList());
        foreach (var t in Tableaus) snapshot.PileCards.Add(t.Cards.ToList());

        _undoStack.Push(snapshot);
    }

    [RelayCommand]
    public void Undo()
    {
        if (_undoStack.Count == 0 || State.HasWon) return;
        ClearHintCycle();
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;

        int scoreBeforeUndo = State.Score;
        var snapshot = _undoStack.Pop();
        State.Score = snapshot.Score;

        if (!Options.IsVegasScoring)
        {
            int pointsEarnedByUndoneMove = scoreBeforeUndo - State.Score;
            State.Score -= Math.Max(0, pointsEarnedByUndoneMove);
        }

        State.MovesCount = snapshot.MovesCount;
        State.TimerSeconds = snapshot.TimerSeconds;
        State.RecyclesCount = snapshot.RecyclesCount;
        State.HasWon = snapshot.HasWon;
        // IsTimerActive is deliberately NOT restored — undoing a move shouldn't stop the
        // clock; the timer keeps running regardless of undo, same as it would if the
        // player just paused to think.
        State.WasteDrawBatchSize = snapshot.WasteDrawBatchSize;

        Stock.Cards.Clear();
        foreach (var c in snapshot.PileCards[0]) Stock.Cards.Add(c);

        Waste.Cards.Clear();
        foreach (var c in snapshot.PileCards[1]) Waste.Cards.Add(c);

        int index = 2;
        for (int i = 0; i < 4; i++)
        {
            Foundations[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) Foundations[i].Cards.Add(c);
            index++;
        }
        _foundationCardCount = Foundations.Sum(f => f.Cards.Count);

        for (int i = 0; i < 7; i++)
        {
            Tableaus[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) Tableaus[i].Cards.Add(c);
            index++;
        }

        HasNoMoves = false;
        CheckAutocomplete();
        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(ScoreDisplay));
        OnPropertyChanged(nameof(CanUndo));
    }

    private void CheckAutocomplete()
    {
        if (Stock.Cards.Any() || Waste.Cards.Any()) { IsAutocompletable = false; return; }
        foreach (var t in Tableaus)
        {
            if (t.Cards.Any(c => !c.IsFaceUp)) { IsAutocompletable = false; return; }
        }
        int total = Tableaus.Sum(t => t.Cards.Count) + Foundations.Sum(f => f.Cards.Count);
        if (total != 52) { IsAutocompletable = false; return; }
        IsAutocompletable = !State.HasWon;
    }

    [RelayCommand]
    public void Autocomplete()
    {
        if (!IsAutocompletable || IsAutoplayRunning) return;

        // One bundled undo snapshot for the whole sequence — SaveStateForUndo() no-ops
        // for every move made once IsAutoplayRunning is true. Once autocomplete has
        // started, Undo stays disabled for the rest of the game (see CanUndo).
        SaveStateForUndo();
        _autocompleteLocked = true;
        OnPropertyChanged(nameof(CanUndo));
        IsAutoplayRunning = true;
        ScheduleNextAutocompleteMove();
    }

    private void ScheduleNextAutocompleteMove()
    {
        _autocompleteTimer?.Dispose();
        _autocompleteTimer = new System.Threading.Timer(_ =>
        {
            _syncContext?.Post(_ => AnimateNextAutocompleteMove(), null);
        }, null, 150, Timeout.Infinite);
    }

    private void AnimateNextAutocompleteMove()
    {
        var move = FindNextFoundationMove();
        if (move != null)
        {
            MoveCard(move.Value.Card, move.Value.Foundation);
            ScheduleNextAutocompleteMove();
        }
        else
        {
            _autocompleteTimer?.Dispose();
            _autocompleteTimer = null;
            IsAutoplayRunning = false;
            CheckVictory();
        }
    }

    // Waste top → foundation first, then each tableau's top card, left to right.
    private (Card Card, Pile Foundation)? FindNextFoundationMove()
    {
        if (Waste.Cards.Count > 0)
        {
            var wasteTop = Waste.Cards.Last();
            foreach (var f in Foundations)
                if (CanMoveCard(wasteTop, f)) return (wasteTop, f);
        }

        foreach (var t in Tableaus)
        {
            if (t.Cards.Count == 0) continue;
            var card = t.Cards.Last();
            foreach (var f in Foundations)
                if (CanMoveCard(card, f)) return (card, f);
        }

        return null;
    }

    public void CheckVictory()
    {
        // Win is when foundations contain all 52 cards
        if (_foundationCardCount == 52)
        {
            if (!State.HasWon)
            {
                State.HasWon = true;
                State.IsTimerActive = false;

                Stats.GamesWon++;
                Stats.CurrentStreak++;
                if (Stats.CurrentStreak > Stats.LongestStreak)
                    Stats.LongestStreak = Stats.CurrentStreak;

                // TimerSeconds only actually ticks when No Stress Mode is off (see the
                // State.IsTimerActive gating on every move above) — otherwise it stays 0
                // for the whole game. Recording that 0 here would permanently pin
                // "Fastest Win" to a bogus 0s (since no real time is ever < 0) and
                // silently deflate "Avg Winning Time", so skip both when untimed.
                if (!Options.IsNoStressMode)
                {
                    if (Stats.ShortestWinSeconds == 0 || State.TimerSeconds < Stats.ShortestWinSeconds)
                        Stats.ShortestWinSeconds = State.TimerSeconds;
                    Stats.TotalWinSeconds += State.TimerSeconds;
                }

                if (Options.IsVegasScoring)
                {
                    if (State.Score > Stats.VegasHighScore)
                    {
                        Stats.VegasHighScore = State.Score;
                    }
                }
                else
                {
                    // Standard-mode time penalty and bonus are applied now that the game is over.
                    // No penalties or bonuses in No Stress Mode — TimerSeconds never advances there.
                    if (!Options.IsNoStressMode)
                    {
                        int timePenalty = (State.TimerSeconds / 10) * 2;
                        State.Score = Math.Max(0, State.Score - timePenalty);

                        // Matches the classic Microsoft Solitaire logic: bonus = 700,000 / seconds,
                        // only applied if the game took at least 30 seconds.
                        if (State.TimerSeconds >= 30)
                        {
                            State.Score += 700000 / State.TimerSeconds;
                        }
                        OnPropertyChanged(nameof(ScoreDisplay));
                    }

                    if (State.Score > Stats.StandardHighScore)
                    {
                        Stats.StandardHighScore = State.Score;
                    }
                }

                StatsService.SaveStats(Stats);
            }
        }
    }

    // Reload fresh first so we don't clobber Freecell/Spider's data in the shared
    // stats file with this ViewModel's (possibly stale) in-memory snapshot.
    public void ResetStats()
    {
        var stats = StatsService.LoadStats();
        stats.GamesPlayed        = 0;
        stats.GamesWon           = 0;
        stats.CurrentStreak      = 0;
        stats.LongestStreak      = 0;
        stats.VegasHighScore     = 0;
        stats.StandardHighScore  = 0;
        stats.ShortestWinSeconds = 0;
        stats.TotalWinSeconds    = 0;
        StatsService.SaveStats(stats);
        Stats = stats;
    }

    private void CheckDeadlock()
    {
        if (State.HasWon || IsAutocompletable) { HasNoMoves = false; return; }
        HasNoMoves = !HasAnyLegalMoves();
    }

    private bool HasAnyLegalMoves()
    {
        // Check waste top — immediately playable
        var wasteTop = Waste.Cards.Count > 0 ? Waste.Cards.Last() : null;
        if (wasteTop != null)
        {
            foreach (var f in Foundations) if (CanMoveCard(wasteTop, f)) return true;
            foreach (var t in Tableaus) if (CanMoveCard(wasteTop, t)) return true;
        }

        // Check stock and buried waste cards, but only the ones that can actually ever
        // become the real top-of-waste card — see ComputeReachableStockWasteCardIds for
        // why "it's somewhere in Stock or Waste" is not the same as "reachable" in
        // Draw-Three mode.
        var reachableIds = ComputeReachableStockWasteCardIds();
        foreach (var card in Stock.Cards)
            if (reachableIds.Contains(card.Id) && CardCanPlayAnywhere(card)) return true;

        int vegasRecycleLimit = State.Mode == DrawMode.DrawThree ? 2 : 0;
        bool canRecycle = Waste.Cards.Count > 0 && !(Options.IsVegasScoring && State.RecyclesCount >= vegasRecycleLimit);
        if (canRecycle && Waste.Cards.Count > 1)
        {
            for (int i = 0; i < Waste.Cards.Count - 1; i++)
                if (reachableIds.Contains(Waste.Cards[i].Id) && CardCanPlayAnywhere(Waste.Cards[i])) return true;
        }

        // Check tableau moves — a move must be both legal (CanMoveCard) and progressive
        // (IsProgressiveTableauMove) to count as evidence the player isn't stuck. Pure
        // reorganization — relocating a run to a structurally-equivalent spot that
        // changes nothing about what's playable — never counts, regardless of whether
        // Stock still has cards. (Matches the Mac original's isProgressiveMove, which
        // applies unconditionally; an earlier version of this check only filtered out
        // non-progressive moves once the deck was fully exhausted, which let a purely
        // lateral tableau shuffle — e.g. relocating a run from one same-rank top to
        // another — incorrectly count as "not stuck" any time Stock still had cards.)
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            int firstFaceUp = src.Cards.FindIndex(c => c.IsFaceUp);
            if (firstFaceUp < 0) continue;
            for (int i = firstFaceUp; i < src.Cards.Count; i++)
            {
                foreach (var f in Foundations) if (CanMoveCard(src.Cards[i], f)) return true;

                foreach (var tgt in Tableaus)
                {
                    if (tgt.Id == src.Id) continue;
                    if (!CanMoveCard(src.Cards[i], tgt)) continue;
                    if (IsProgressiveTableauMove(src, i, tgt, firstFaceUp)) return true;
                }
            }
        }
        return false;
    }

    // A tableau-to-tableau move is "progress" — as opposed to pure reorganization that
    // changes nothing about what's ultimately playable — exactly when one of these holds
    // (matches the Mac original's isProgressiveMove):
    //   - It fully empties the source column, AND the target wasn't already empty
    //     (otherwise it's just relocating which column happens to be the empty one —
    //     e.g. shuffling a lone King back and forth between two empty columns forever).
    //   - It reveals a face-down card underneath (there's a hidden card below the run
    //     being moved).
    //   - It exposes a face-up card underneath that's now immediately playable to a
    //     foundation.
    // Everything else — reorganizing an already-fully-visible column without emptying it,
    // or without exposing anything new — is not progress.
    private bool IsProgressiveTableauMove(Pile src, int cardIndex, Pile tgt, int firstFaceUp)
    {
        if (cardIndex == 0)
            return tgt.Cards.Count > 0;

        if (cardIndex == firstFaceUp && firstFaceUp > 0)
            return true;

        // Can't use CanMoveCard(..., foundation) here — it requires the card to already
        // be its pile's actual top, but src.Cards[cardIndex-1] is still buried under the
        // cards we'd be moving away (that's the whole point of "exposes"). Guaranteed
        // face-up here since cardIndex > firstFaceUp.
        return CanReachFoundation(src.Cards[cardIndex - 1]);
    }

    // Draw-Three's fan only ever exposes the LAST-popped card of each drawn 3-card batch
    // as the real, playable top-of-waste — the other two are shown for visibility but can
    // never be selected. Recycling reverses the whole waste pile back into Stock; because
    // drawing itself no longer reorders a batch (see DrawCard), a full draw-through
    // followed by exactly one recycle reconstructs the original Stock order exactly
    // (reverse-of-reverse is the identity) — so recycling never surfaces a different card
    // out of any given batch. Only 1 of every 3 cards in a batch is EVER reachable, no
    // matter how many times the pile is recycled. Draw-One has no such restriction —
    // every card is its own batch of one and is always reachable.
    //
    // Simulated on copies of Stock/Waste (never mutates real state) by literally replaying
    // DrawCard's mechanics: draw through whatever's left in Stock, then — if recycling is
    // still allowed — simulate exactly one recycle-and-redraw on top of that. One recycle
    // is always enough (recycling further is a no-op, reproducing the same result), but
    // it must actually be simulated: if Stock is already empty (nothing left to draw
    // through on its own), skipping this step would wrongly treat every card sitting in
    // Waste as permanently unreachable even when a recycle would legitimately surface one.
    private HashSet<string> ComputeReachableStockWasteCardIds()
    {
        var reachable = new HashSet<string>();
        int batchSize = State.Mode == DrawMode.DrawThree ? 3 : 1;
        int vegasRecycleLimit = State.Mode == DrawMode.DrawThree ? 2 : 0;

        var simStock = new List<Card>(Stock.Cards);
        var simWaste = new List<Card>(Waste.Cards);

        void DrawThroughStock()
        {
            while (simStock.Count > 0)
            {
                int take = Math.Min(batchSize, simStock.Count);
                var drawn = new List<Card>(take);
                for (int i = 0; i < take; i++)
                {
                    drawn.Add(simStock[^1]);
                    simStock.RemoveAt(simStock.Count - 1);
                }
                foreach (var card in drawn)
                    simWaste.Add(card);
                reachable.Add(simWaste[^1].Id);
            }
        }

        DrawThroughStock();

        bool canRecycle = simWaste.Count > 0 && !(Options.IsVegasScoring && State.RecyclesCount >= vegasRecycleLimit);
        if (canRecycle)
        {
            var reversed = new List<Card>(simWaste);
            reversed.Reverse();
            simStock = reversed;
            simWaste = new List<Card>();
            DrawThroughStock();
        }

        return reachable;
    }

    private bool CanReachFoundation(Card card)
    {
        foreach (var f in Foundations)
        {
            if (f.Cards.Count == 0 && card.Rank == 1) return true;
            if (f.Cards.Count > 0 && f.Cards.Last().Suit == card.Suit && card.Rank == f.Cards.Last().Rank + 1) return true;
        }
        return false;
    }

    private bool CardCanPlayAnywhere(Card card)
    {
        if (CanReachFoundation(card)) return true;
        foreach (var t in Tableaus)
        {
            if (t.Cards.Count == 0 && card.Rank == 13) return true;
            if (t.Cards.Count > 0 && t.Cards.Last().IsFaceUp
                && IsRed(card.Suit) != IsRed(t.Cards.Last().Suit)
                && card.Rank == t.Cards.Last().Rank - 1) return true;
        }
        return false;
    }

    // MARK: - Hint

    public void FindHint()
    {
        // Rebuild the list on first press (or after any state change cleared it)
        if (_hintCycleList.Count == 0)
        {
            _hintCycleList  = CollectAllHints();
            _hintCycleIndex = 0;
        }

        if (_hintCycleList.Count == 0) { ActiveHint = null; return; }

        int shownIndex = _hintCycleIndex;
        var hint       = _hintCycleList[shownIndex];
        _hintCycleIndex = (_hintCycleIndex + 1) % _hintCycleList.Count;
        ActiveHint      = hint with { Index = shownIndex + 1, Total = _hintCycleList.Count };
    }

    // Public so the view can clear the queue when a hint's on-screen timer expires
    // (auto-dismiss), matching the rule that the next Hint press starts fresh.
    public void ClearHintCycle()
    {
        _hintCycleList.Clear();
        _hintCycleIndex = 0;
        ActiveHint      = null;
    }

    private List<HintMove> CollectAllHints()
    {
        var scored   = new List<(int Score, HintMove Hint)>();
        var wasteTop = Waste.Cards.Count > 0 ? Waste.Cards.Last() : null;

        // Priority 1 (1000): any card (waste top or tableau top) → Foundation
        if (wasteTop != null)
            foreach (var f in Foundations)
                if (CanMoveCard(wasteTop, f))
                    scored.Add((1000, new HintMove(wasteTop, Waste.Id, f.Id,
                        $"Move {RankStr(wasteTop.Rank)}{SuitStr(wasteTop.Suit)} to Foundation.")));

        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var card = src.Cards.Last();
            foreach (var f in Foundations)
                if (CanMoveCard(card, f))
                    scored.Add((1000, new HintMove(card, src.Id, f.Id,
                        $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} to Foundation.")));
        }

        // Priority 2 (500 + hidden×100) / Priority 4 (150): tableau → tableau. Checks
        // every possible sub-run start within the face-up portion (i from firstFaceUp to
        // the pile's end), not just the run's very first card, and only suggests a move
        // that IsProgressiveTableauMove actually counts as progress — the identical
        // legality + progressiveness test HasAnyLegalMoves uses, so Hint and
        // stuck-detection can never disagree: if Hint has nothing to suggest here, the
        // board is also correctly flagged stuck, and vice versa (matches the Mac
        // original's guarantee). Suggesting a legal-but-purely-lateral reshuffle (e.g.
        // relocating a run between two structurally-equivalent spots) would let Hint
        // recommend something HasAnyLegalMoves correctly ignores as non-progress.
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            int firstFaceUp = src.Cards.FindIndex(c => c.IsFaceUp);
            if (firstFaceUp < 0) continue;

            for (int i = firstFaceUp; i < src.Cards.Count; i++)
            {
                var card = src.Cards[i];
                bool revealsHidden = i == firstFaceUp && firstFaceUp > 0;

                foreach (var tgt in Tableaus)
                {
                    if (tgt.Id == src.Id) continue;
                    if (!CanMoveCard(card, tgt)) continue;
                    if (!IsProgressiveTableauMove(src, i, tgt, firstFaceUp)) continue;

                    if (revealsHidden)
                    {
                        scored.Add((500 + firstFaceUp * 100, new HintMove(card, src.Id, tgt.Id,
                            $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} sequence.")));
                    }
                    else
                    {
                        scored.Add((150, new HintMove(card, src.Id, tgt.Id,
                            $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} sequence.")));
                    }
                }
            }
        }

        // Priority 3 (300): waste top → tableau
        if (wasteTop != null)
            foreach (var t in Tableaus)
                if (CanMoveCard(wasteTop, t))
                    scored.Add((300, new HintMove(wasteTop, Waste.Id, t.Id,
                        $"Move {RankStr(wasteTop.Rank)}{SuitStr(wasteTop.Suit)} from waste.")));

        // Priority 5 (50) / 6 (20): draw from stock / recycle waste — only when a card
        // that can ACTUALLY become the real top-of-waste would land somewhere. In
        // Draw-Three, "somewhere in Stock/Waste" isn't enough: only the first and last
        // card of each drawn 3-card group can ever become the true playable top — the
        // middle card is stuck there through any number of recycles (see
        // ComputeReachableStockWasteCardIds). Suggesting a draw/recycle whenever the
        // pile is merely non-empty recommends a dead-end action forever once every
        // reachable card is a dud, even after stuck-detection has correctly given up.
        var reachableIds = ComputeReachableStockWasteCardIds();
        if (Stock.Cards.Count > 0 && Stock.Cards.Any(c => reachableIds.Contains(c.Id) && CardCanPlayAnywhere(c)))
            scored.Add((50, new HintMove(new Card("deal", CardSuit.Spades, 1, false), Stock.Id, "", "Draw from stock.")));

        if (Stock.Cards.Count == 0 && Waste.Cards.Count > 0)
        {
            // Real Vegas-scoring rules: Draw One gets a single pass through the deck (no
            // recycles at all); Draw Three gets 2 recycles (3 total passes).
            int vegasRecycleLimit = State.Mode == DrawMode.DrawThree ? 2 : 0;
            bool canRecycle = !(Options.IsVegasScoring && State.RecyclesCount >= vegasRecycleLimit);
            if (canRecycle && Waste.Cards.Any(c => reachableIds.Contains(c.Id) && CardCanPlayAnywhere(c)))
                scored.Add((20, new HintMove(new Card("recycle", CardSuit.Spades, 1, false), Waste.Id, Stock.Id,
                    "Recycle waste back to stock.")));
        }

        var hints = scored.OrderByDescending(s => s.Score).Select(s => s.Hint).ToList();

        // Deliberately no "King to empty column" last-resort fallback here: that move is
        // only ever offered when it's non-progressive (an already-fully-face-up column
        // being relocated to another empty column — see IsProgressiveTableauMove), and
        // surfacing it anyway would let Hint suggest something HasAnyLegalMoves correctly
        // treats as not-a-real-move, breaking the guarantee that Hint and stuck-detection
        // never disagree (matches the Mac original, which has no such fallback either).

        // Last-move filter: drop the exact reversal of the last move (source/target swapped).
        // If that empties the list, fall back to the unfiltered one so something is always shown.
        if (_lastMoveSourcePileId != null && _lastMoveTargetPileId != null)
        {
            var filtered = hints.Where(h =>
                !(h.SourcePileId == _lastMoveTargetPileId && h.TargetPileId == _lastMoveSourcePileId)).ToList();
            if (filtered.Count > 0) hints = filtered;
        }

        if (hints.Count == 0)
            hints.Add(new HintMove(new Card("no_move", CardSuit.Spades, 1, true), "", "", "No moves available."));

        return hints;
    }

    private static string RankStr(int rank) => rank switch { 1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => rank.ToString() };
    private static string SuitStr(CardSuit suit) => suit switch
    {
        CardSuit.Spades => "♠", CardSuit.Hearts => "♥",
        CardSuit.Diamonds => "♦", CardSuit.Clubs => "♣", _ => ""
    };

    public bool CanUndo => _undoStack.Count > 0 && !_autocompleteLocked && !State.HasWon;

    private Pile FindPileContaining(Card card)
    {
        if (Stock.Cards.Contains(card)) return Stock;
        if (Waste.Cards.Contains(card)) return Waste;
        
        var found = Foundations.FirstOrDefault(f => f.Cards.Contains(card));
        if (found != null) return found;

        return Tableaus.FirstOrDefault(t => t.Cards.Contains(card))!;
    }

    private static bool IsRed(CardSuit suit)
    {
        return suit == CardSuit.Hearts || suit == CardSuit.Diamonds;
    }

    [RelayCommand]
    public void UpdateFeltColor(FeltColorTheme theme)
    {
        Options.FeltColor = theme;
        Options.CustomFeltColorRevision++;
        SettingsService.SaveOptions(Options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(Options));
    }
}

public class GameStateSnapshot
{
    public int Score { get; set; }
    public int MovesCount { get; set; }
    public int TimerSeconds { get; set; }
    public int RecyclesCount { get; set; }
    public bool HasWon { get; set; }
    public int WasteDrawBatchSize { get; set; }

    public List<List<Card>> PileCards { get; set; } = new();
}
