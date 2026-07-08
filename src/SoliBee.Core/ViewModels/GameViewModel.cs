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
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
            if (vegasChanged) InitializeGame(countAsNewGame: false);
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
            _syncContext?.Post(_ =>
            {
                if (State != null && State.IsTimerActive && !State.HasWon)
                {
                    State.TimerSeconds++;
                    OnPropertyChanged(nameof(TimeDisplay));
                }
            }, null);
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
            _syncContext?.Post(_ =>
            {
                if (State != null && State.IsTimerActive && !State.HasWon)
                {
                    State.TimerSeconds++;
                    OnPropertyChanged(nameof(TimeDisplay));
                }
            }, null);
        }, null, 1000, 1000);

        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
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

        // Collect then reverse so the top-of-stock card ends up as top-of-waste
        var drawn = new List<Card>(cardsToDraw);
        for (int i = 0; i < cardsToDraw; i++)
        {
            drawn.Add(Stock.Cards[^1] with { IsFaceUp = true });
            Stock.Cards.RemoveAt(Stock.Cards.Count - 1);
        }
        for (int i = drawn.Count - 1; i >= 0; i--)
            Waste.Cards.Add(drawn[i]);
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
            if (target == PileType.Foundation)
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
            Score              = State.Score,
            MovesCount         = State.MovesCount,
            TimerSeconds       = State.TimerSeconds,
            RecyclesCount      = State.RecyclesCount,
            HasWon             = State.HasWon,
            WasteDrawBatchSize = State.WasteDrawBatchSize,
            PileCards          = new List<List<Card>>()
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

        var snapshot = _undoStack.Pop();
        State.Score = snapshot.Score;
        State.MovesCount = snapshot.MovesCount;
        State.TimerSeconds = snapshot.TimerSeconds;
        State.RecyclesCount = snapshot.RecyclesCount;
        State.HasWon = snapshot.HasWon;
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

        // Check stock: each card could become the waste top after drawing
        foreach (var card in Stock.Cards)
            if (CardCanPlayAnywhere(card)) return true;

        // Check buried waste cards: accessible after recycle (if allowed)
        int vegasRecycleLimit = State.Mode == DrawMode.DrawThree ? 2 : 0;
        bool canRecycle = Waste.Cards.Count > 0 && !(Options.IsVegasScoring && State.RecyclesCount >= vegasRecycleLimit);
        if (canRecycle && Waste.Cards.Count > 1)
        {
            for (int i = 0; i < Waste.Cards.Count - 1; i++)
                if (CardCanPlayAnywhere(Waste.Cards[i])) return true;
        }

        // No more new cards will ever appear if stock is empty and waste can't be recycled.
        // In that state, tableau→tableau moves only count as progress when they reveal
        // a face-down card, or expose a face-up card underneath that's immediately
        // playable to a foundation — reshuffling otherwise (e.g. a run that doesn't
        // uncover anything new) doesn't change what's playable.
        bool deckExhausted = Stock.Cards.Count == 0 && (Waste.Cards.Count == 0 || !canRecycle);

        // Check tableau moves
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            int firstFaceUp = src.Cards.FindIndex(c => c.IsFaceUp);
            if (firstFaceUp < 0) continue;
            bool revealsHidden = firstFaceUp > 0;
            for (int i = firstFaceUp; i < src.Cards.Count; i++)
            {
                foreach (var f in Foundations) if (CanMoveCard(src.Cards[i], f)) return true;

                bool exposesHiddenCard = i == firstFaceUp && revealsHidden;
                // Can't use CanMoveCard(..., foundation) here — it requires the card to
                // already be its pile's actual top, but src.Cards[i-1] is still buried
                // under the cards we'd be moving away (that's the whole point of "exposes").
                bool exposesFoundationMove = i > 0 && src.Cards[i - 1].IsFaceUp &&
                    CanReachFoundation(src.Cards[i - 1]);

                if (!deckExhausted || exposesHiddenCard || exposesFoundationMove)
                {
                    foreach (var tgt in Tableaus)
                    {
                        if (tgt.Id == src.Id) continue;
                        if (CanMoveCard(src.Cards[i], tgt)) return true;
                    }
                }
            }
        }
        return false;
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

        // Priority 2 (500 + hidden×100) / Priority 4 (150): tableau → tableau
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            int firstFaceUp = src.Cards.FindIndex(c => c.IsFaceUp);
            if (firstFaceUp < 0) continue;
            var seq = src.Cards.GetRange(firstFaceUp, src.Cards.Count - firstFaceUp);
            bool revealsHidden = firstFaceUp > 0;
            int hiddenCount    = firstFaceUp;

            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (!CanMoveCard(seq[0], tgt)) continue;

                if (revealsHidden)
                {
                    scored.Add((500 + hiddenCount * 100, new HintMove(seq[0], src.Id, tgt.Id,
                        $"Move {RankStr(seq[0].Rank)}{SuitStr(seq[0].Suit)} sequence.")));
                }
                else if (tgt.Cards.Count > 0)
                {
                    // Plain, all-face-up moves onto an empty column (e.g. King to empty) are
                    // suppressed here — they're only surfaced later if nothing else is legal.
                    scored.Add((150, new HintMove(seq[0], src.Id, tgt.Id,
                        $"Move {RankStr(seq[0].Rank)}{SuitStr(seq[0].Suit)} sequence.")));
                }
            }
        }

        // Priority 3 (300): waste top → tableau
        if (wasteTop != null)
            foreach (var t in Tableaus)
                if (CanMoveCard(wasteTop, t))
                    scored.Add((300, new HintMove(wasteTop, Waste.Id, t.Id,
                        $"Move {RankStr(wasteTop.Rank)}{SuitStr(wasteTop.Suit)} from waste.")));

        // Priority 5 (50): draw from stock
        if (Stock.Cards.Count > 0)
            scored.Add((50, new HintMove(new Card("deal", CardSuit.Spades, 1, false), Stock.Id, "", "Draw from stock.")));

        // Priority 6 (20): recycle waste back to stock — only when stock is empty and legal
        if (Stock.Cards.Count == 0 && Waste.Cards.Count > 0)
        {
            // Real Vegas-scoring rules: Draw One gets a single pass through the deck (no
            // recycles at all); Draw Three gets 2 recycles (3 total passes).
            int vegasRecycleLimit = State.Mode == DrawMode.DrawThree ? 2 : 0;
            bool canRecycle = !(Options.IsVegasScoring && State.RecyclesCount >= vegasRecycleLimit);
            if (canRecycle)
                scored.Add((20, new HintMove(new Card("recycle", CardSuit.Spades, 1, false), Waste.Id, Stock.Id,
                    "Recycle waste back to stock.")));
        }

        var hints = scored.OrderByDescending(s => s.Score).Select(s => s.Hint).ToList();

        // King-to-empty-column fallback: only surfaced when it's the only legal move at all.
        if (hints.Count == 0)
        {
            foreach (var src in Tableaus)
            {
                if (src.Cards.Count == 0) continue;
                int firstFaceUp = src.Cards.FindIndex(c => c.IsFaceUp);
                if (firstFaceUp < 0) continue;
                var seq = src.Cards.GetRange(firstFaceUp, src.Cards.Count - firstFaceUp);
                foreach (var tgt in Tableaus)
                {
                    if (tgt.Id == src.Id || tgt.Cards.Count != 0) continue;
                    if (CanMoveCard(seq[0], tgt))
                        hints.Add(new HintMove(seq[0], src.Id, tgt.Id,
                            $"Move {RankStr(seq[0].Rank)}{SuitStr(seq[0].Suit)} sequence."));
                }
            }
        }

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
