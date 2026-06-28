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

    private List<HintMove> _hintCycleList  = new();
    private int            _hintCycleIndex = 0;

    public string TimeDisplay => TimeSpan.FromSeconds(State?.TimerSeconds ?? 0).ToString(@"mm\:ss");

    public string ScoreDisplay
    {
        get
        {
            if (Options?.IsVegasScoring == true)
            {
                int dollars = State.Score / 100;
                int abs     = Math.Abs(dollars);
                return dollars < 0 ? $"-${abs}.00" : $"${abs}.00";
            }
            return State.Score.ToString();
        }
    }

    partial void OnStateChanged(GameState value) => OnPropertyChanged(nameof(ScoreDisplay));
    partial void OnOptionsChanged(GameOptions value) => OnPropertyChanged(nameof(ScoreDisplay));

    public GameViewModel()
    {
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
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

    public void InitializeGame()
    {
        ClearHintCycle();
        Stock.Cards.Clear();
        Waste.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();
        _undoStack.Clear();

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

        // Shuffle deck
        var rng = new Random();
        deck = deck.OrderBy(c => rng.Next()).ToList();

        // Save a copy of the shuffled deck for RestartGame
        _initialDeck = deck.Select(c => c with { IsFaceUp = false }).ToList();

        // Deal cards to tableau
        for (int i = 0; i < 7; i++)
        {
            for (int j = 0; j <= i; j++)
            {
                var card = deck[0];
                deck.RemoveAt(0);

                // Top card is face up
                if (j == i)
                {
                    card = card with { IsFaceUp = true };
                }

                Tableaus[i].Cards.Add(card);
            }
        }

        // Put remaining cards in stock
        foreach (var card in deck)
        {
            Stock.Cards.Add(card);
        }

        IsAutocompletable = false;
        HasNoMoves = false;

        Stats.GamesPlayed++;
        StatsService.SaveStats(Stats);

        // Start background timer ticking
        _gameTimer?.Dispose();
        _gameTimer = new System.Threading.Timer(_ =>
        {
            if (State != null && State.IsTimerActive && !State.HasWon)
            {
                State.TimerSeconds++;
                OnPropertyChanged(nameof(TimeDisplay));
            }
        }, null, 1000, 1000);
        
        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
    }

    public void RestartGame()
    {
        if (!_initialDeck.Any()) return;

        // Clear everything
        Stock.Cards.Clear();
        Waste.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();
        _undoStack.Clear();

        _vegasGameStartScore = Options.IsVegasScoring ? -5200 : 0;
        State.Score = _vegasGameStartScore;
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

        // Deal cards to tableau in the exact same order
        for (int i = 0; i < 7; i++)
        {
            for (int j = 0; j <= i; j++)
            {
                var card = deckCopy[0];
                deckCopy.RemoveAt(0);

                // Top card is face up
                if (j == i)
                {
                    card = card with { IsFaceUp = true };
                }

                Tableaus[i].Cards.Add(card);
            }
        }

        // Put remaining cards in stock
        foreach (var card in deckCopy)
        {
            Stock.Cards.Add(card);
        }

        // Reset and restart background timer ticking
        _gameTimer?.Dispose();
        _gameTimer = new System.Threading.Timer(_ =>
        {
            if (State != null && State.IsTimerActive && !State.HasWon)
            {
                State.TimerSeconds++;
                OnPropertyChanged(nameof(TimeDisplay));
            }
        }, null, 1000, 1000);

        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
    }

    public void DrawCard()
    {
        if (Stock.Cards.Count == 0)
        {
            // Recycle waste back to stock — guard no-ops before snapshot
            if (Waste.Cards.Count == 0) return;
            if (Options.IsVegasScoring && State.RecyclesCount >= 1) return;

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
            if (!State.IsTimerActive && !State.HasWon && Options.IsTimed)
                State.IsTimerActive = true;
            State.MovesCount++;
            CheckDeadlock();
            OnPropertyChanged(nameof(Stock));
            OnPropertyChanged(nameof(Waste));
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

        if (!State.IsTimerActive && !State.HasWon && Options.IsTimed)
            State.IsTimerActive = true;
        State.MovesCount++;
        CheckAutocomplete();
        CheckDeadlock();
        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
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

        if (!State.IsTimerActive && !State.HasWon && Options.IsTimed)
            State.IsTimerActive = true;
        State.MovesCount++;
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
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
        if (_undoStack.Count == 0) return;
        ClearHintCycle();

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
        IsAutocompletable = !State.HasWon;
    }

    [RelayCommand]
    public void Autocomplete()
    {
        if (!IsAutocompletable) return;

        while (Foundations.Sum(f => f.Cards.Count) < 52)
        {
            bool movedAny = false;
            foreach (var t in Tableaus.Where(x => x.Cards.Count > 0))
            {
                var card = t.Cards.Last();
                foreach (var f in Foundations)
                {
                    if (CanMoveCard(card, f))
                    {
                        MoveCard(card, f);
                        movedAny = true;
                        break;
                    }
                }
                if (movedAny) break;
            }

            if (!movedAny)
            {
                // Prevent infinite loop if something goes wrong
                break;
            }
        }
    }

    public void CheckVictory()
    {
        // Win is when foundations contain all 52 cards
        if (Foundations.Sum(f => f.Cards.Count) == 52)
        {
            if (!State.HasWon)
            {
                State.HasWon = true;
                State.IsTimerActive = false;

                Stats.GamesWon++;
                Stats.CurrentStreak++;
                if (Stats.CurrentStreak > Stats.LongestStreak)
                {
                    Stats.LongestStreak = Stats.CurrentStreak;
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

    private void CheckDeadlock()
    {
        if (State.HasWon) return;
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
        bool canRecycle = Waste.Cards.Count > 0 && !(Options.IsVegasScoring && State.RecyclesCount >= 1);
        if (canRecycle && Waste.Cards.Count > 1)
        {
            for (int i = 0; i < Waste.Cards.Count - 1; i++)
                if (CardCanPlayAnywhere(Waste.Cards[i])) return true;
        }

        // Check tableau moves
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
                    if (CanMoveCard(src.Cards[i], tgt)) return true;
                }
            }
        }
        return false;
    }

    private bool CardCanPlayAnywhere(Card card)
    {
        foreach (var f in Foundations)
        {
            if (f.Cards.Count == 0 && card.Rank == 1) return true;
            if (f.Cards.Count > 0 && f.Cards.Last().Suit == card.Suit && card.Rank == f.Cards.Last().Rank + 1) return true;
        }
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

        ActiveHint      = _hintCycleList[_hintCycleIndex];
        _hintCycleIndex = (_hintCycleIndex + 1) % _hintCycleList.Count;
    }

    private void ClearHintCycle()
    {
        _hintCycleList.Clear();
        _hintCycleIndex = 0;
        ActiveHint      = null;
    }

    private List<HintMove> CollectAllHints()
    {
        var hints    = new List<HintMove>();
        var wasteTop = Waste.Cards.Count > 0 ? Waste.Cards.Last() : null;

        // 1. Waste top → foundation
        if (wasteTop != null)
            foreach (var f in Foundations)
                if (CanMoveCard(wasteTop, f))
                    hints.Add(new HintMove(wasteTop, Waste.Id, f.Id,
                        $"Move {RankStr(wasteTop.Rank)}{SuitStr(wasteTop.Suit)} to Foundation."));

        // 2. Tableau top → foundation
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var card = src.Cards.Last();
            foreach (var f in Foundations)
                if (CanMoveCard(card, f))
                    hints.Add(new HintMove(card, src.Id, f.Id,
                        $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} to Foundation."));
        }

        // 3. Waste top → tableau
        if (wasteTop != null)
            foreach (var t in Tableaus)
                if (CanMoveCard(wasteTop, t))
                    hints.Add(new HintMove(wasteTop, Waste.Id, t.Id,
                        $"Move {RankStr(wasteTop.Rank)}{SuitStr(wasteTop.Suit)} from waste."));

        // 4. Tableau sequence → tableau (most face-down cards to uncover first)
        foreach (var src in Tableaus.OrderByDescending(t => t.Cards.Count(c => !c.IsFaceUp)))
        {
            if (src.Cards.Count == 0) continue;
            int firstFaceUp = src.Cards.FindIndex(c => c.IsFaceUp);
            if (firstFaceUp < 0) continue;
            var seq = src.Cards.GetRange(firstFaceUp, src.Cards.Count - firstFaceUp);
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (CanMoveCard(seq[0], tgt))
                    hints.Add(new HintMove(seq[0], src.Id, tgt.Id,
                        $"Move {RankStr(seq[0].Rank)}{SuitStr(seq[0].Suit)} sequence."));
            }
        }

        // 5. Draw from stock
        if (Stock.Cards.Count > 0)
            hints.Add(new HintMove(new Card("deal", CardSuit.Spades, 1, false), Stock.Id, "", "Draw from stock."));

        // No moves fallback
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

    public bool CanUndo => _undoStack.Count > 0;

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
