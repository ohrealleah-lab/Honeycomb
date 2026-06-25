using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class SpiderViewModel : ObservableObject
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

    public List<Pile> StockPiles { get; } = new();
    public List<Pile> Tableaus { get; } = new();
    public List<Pile> Foundations { get; } = new();

    private readonly Stack<SpiderSnapshot> _undoStack = new();
    private SpiderSnapshot? _initialSnapshot;
    private System.Threading.Timer? _gameTimer;

    public string TimeDisplay => TimeSpan.FromSeconds(State?.TimerSeconds ?? 0).ToString(@"mm\:ss");
    public string ScoreDisplay => State.Score.ToString();
    public bool CanUndo => _undoStack.Count > 0;

    private string SuitKey => Options.SpiderSuitCount.ToString();
    private const int TotalFoundations = 8;
    private const int WinCards = 104;

    public SpiderViewModel()
    {
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            var old = Options;
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
            if (Options.SpiderSuitCount != old.SpiderSuitCount)
                InitializeGame();
        });

        for (int i = 0; i < 10; i++)
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));
        for (int i = 0; i < TotalFoundations; i++)
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));

        InitializeGame();
    }

    public void InitializeGame()
    {
        _gameTimer?.Dispose();
        StockPiles.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        _undoStack.Clear();

        State = new GameState
        {
            Score = Options.IsVegasScoring ? -500 : 500,
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = false,
            HasWon = false
        };

        var deck = BuildDeck();
        var rng = new Random();
        deck = deck.OrderBy(_ => rng.Next()).ToList();

        for (int col = 0; col < 10; col++)
        {
            int count = col < 4 ? 6 : 5;
            for (int i = 0; i < count; i++)
            {
                var card = deck[0];
                deck.RemoveAt(0);
                Tableaus[col].Cards.Add(i == count - 1 ? card with { IsFaceUp = true } : card);
            }
        }

        while (deck.Count > 0)
        {
            var stockPile = new Pile($"Stock_{StockPiles.Count}", PileType.Stock);
            for (int i = 0; i < 10 && deck.Count > 0; i++)
            {
                stockPile.Cards.Add(deck[0]);
                deck.RemoveAt(0);
            }
            StockPiles.Add(stockPile);
        }

        var stats = StatsService.LoadStats();
        if (!stats.SpiderStatsBySuit.ContainsKey(SuitKey))
            stats.SpiderStatsBySuit[SuitKey] = new ModeStats();
        stats.SpiderStatsBySuit[SuitKey].GamesPlayed++;
        StatsService.SaveStats(stats);
        Stats = stats;

        IsAutocompletable = false;
        HasNoMoves = false;
        ActiveHint = null;
        _initialSnapshot = CaptureSnapshot();

        _gameTimer = new System.Threading.Timer(_ =>
        {
            if (State != null && State.IsTimerActive && !State.HasWon)
            {
                State.TimerSeconds++;
                OnPropertyChanged(nameof(TimeDisplay));
            }
        }, null, 1000, 1000);

        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
    }

    public void RestartGame()
    {
        if (_initialSnapshot == null) return;
        _gameTimer?.Dispose();
        _undoStack.Clear();
        RestoreSnapshot(_initialSnapshot);
        State.IsTimerActive = false;
        State.HasWon = false;
        IsAutocompletable = false;
        HasNoMoves = false;
        ActiveHint = null;

        _gameTimer = new System.Threading.Timer(_ =>
        {
            if (State != null && State.IsTimerActive && !State.HasWon)
            {
                State.TimerSeconds++;
                OnPropertyChanged(nameof(TimeDisplay));
            }
        }, null, 1000, 1000);

        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
    }

    // MARK: - Deck Building

    private List<Card> BuildDeck()
    {
        var deck = new List<Card>();
        var suits = Options.SpiderSuitCount switch
        {
            4 => new[] { CardSuit.Spades, CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs },
            2 => new[] { CardSuit.Spades, CardSuit.Hearts },
            _ => new[] { CardSuit.Spades }
        };
        int setsPerSuit = 8 / suits.Length;

        int cardIndex = 0;
        foreach (var suit in suits)
        {
            for (int s = 0; s < setsPerSuit; s++)
            {
                for (int rank = 1; rank <= 13; rank++)
                {
                    var rankStr = rank switch { 1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => rank.ToString() };
                    deck.Add(new Card($"spider_{cardIndex++}_{suit}_{rankStr}", suit, rank, false));
                }
            }
        }
        return deck;
    }

    // MARK: - Move Validation

    public bool CanMoveSequence(List<Card> cards, Pile target)
    {
        if (cards.Count == 0) return false;

        if (cards.Count > 1)
        {
            var suit = cards[0].Suit;
            for (int i = 0; i < cards.Count - 1; i++)
            {
                if (cards[i].Suit != suit || cards[i].Rank != cards[i + 1].Rank + 1)
                    return false;
            }
        }

        if (target.Cards.Count == 0) return true;
        var topCard = target.Cards.Last();
        return topCard.IsFaceUp && cards[0].Rank == topCard.Rank - 1;
    }

    public List<Card> GetMovableSequence(Pile source)
    {
        var result = new List<Card>();
        if (source.Cards.Count == 0) return result;
        result.Add(source.Cards.Last());
        for (int i = source.Cards.Count - 2; i >= 0; i--)
        {
            var upper = source.Cards[i];
            var lower = source.Cards[i + 1];
            if (upper.IsFaceUp && upper.Suit == lower.Suit && upper.Rank == lower.Rank + 1)
                result.Insert(0, upper);
            else
                break;
        }
        return result;
    }

    public void MoveSequence(List<Card> cards, Pile source, Pile target)
    {
        if (!CanMoveSequence(cards, target)) return;

        SaveStateForUndo();

        if (!State.IsTimerActive && !State.HasWon)
            State.IsTimerActive = true;

        var cardIds = new HashSet<string>(cards.Select(c => c.Id));
        source.Cards.RemoveAll(c => cardIds.Contains(c.Id));

        foreach (var card in cards)
            target.Cards.Add(card);

        FlipTopCard(source);

        if (!Options.IsVegasScoring)
            State.Score--;

        State.MovesCount++;
        TryCompleteRuns();
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        ActiveHint = null;

        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(ScoreDisplay));
    }

    private void FlipTopCard(Pile pile)
    {
        if (pile.Cards.Count > 0 && !pile.Cards.Last().IsFaceUp)
            pile.Cards[pile.Cards.Count - 1] = pile.Cards.Last() with { IsFaceUp = true };
    }

    // MARK: - Deal From Stock

    public bool CanDealFromStock => StockPiles.Count > 0 && Tableaus.All(t => t.Cards.Count > 0);

    public void DealFromStock()
    {
        if (!CanDealFromStock) return;

        SaveStateForUndo();

        var deal = StockPiles[0];
        StockPiles.RemoveAt(0);

        for (int i = 0; i < Tableaus.Count && i < deal.Cards.Count; i++)
            Tableaus[i].Cards.Add(deal.Cards[i] with { IsFaceUp = true });

        if (!Options.IsVegasScoring)
            State.Score--;

        State.MovesCount++;
        TryCompleteRuns();
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        ActiveHint = null;

        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(ScoreDisplay));
    }

    // MARK: - Complete Run Detection

    private void TryCompleteRuns()
    {
        bool found;
        do
        {
            found = false;
            foreach (var tableau in Tableaus)
            {
                if (tableau.Cards.Count < 13) continue;
                var run = tableau.Cards.TakeLast(13).ToList();
                if (!IsCompleteRun(run)) continue;

                var emptyFoundation = Foundations.FirstOrDefault(f => f.Cards.Count == 0);
                if (emptyFoundation == null) continue;

                foreach (var card in run)
                    emptyFoundation.Cards.Add(card);
                tableau.Cards.RemoveRange(tableau.Cards.Count - 13, 13);
                FlipTopCard(tableau);

                if (Options.IsVegasScoring)
                    State.Score += 100;

                found = true;
                break;
            }
        } while (found);
    }

    private static bool IsCompleteRun(List<Card> cards)
    {
        if (cards.Count != 13) return false;
        var suit = cards[0].Suit;
        for (int i = 0; i < 13; i++)
        {
            if (cards[i].Suit != suit || cards[i].Rank != 13 - i)
                return false;
        }
        return true;
    }

    // MARK: - Victory

    private void CheckVictory()
    {
        if (Foundations.Sum(f => f.Cards.Count) == WinCards && !State.HasWon)
        {
            State.HasWon = true;
            State.IsTimerActive = false;
            _gameTimer?.Dispose();

            var stats = StatsService.LoadStats();
            if (!stats.SpiderStatsBySuit.ContainsKey(SuitKey))
                stats.SpiderStatsBySuit[SuitKey] = new ModeStats();
            var ms = stats.SpiderStatsBySuit[SuitKey];
            ms.GamesWon++;
            ms.CurrentStreak++;
            if (ms.CurrentStreak > ms.LongestStreak) ms.LongestStreak = ms.CurrentStreak;
            if (State.Score > ms.HighScore) ms.HighScore = State.Score;
            stats.SpiderStatsBySuit[SuitKey] = ms;
            StatsService.SaveStats(stats);
            Stats = stats;
        }
    }

    // MARK: - Autocomplete

    private void CheckAutocomplete()
    {
        bool allFaceUp = Tableaus.All(t => t.Cards.All(c => c.IsFaceUp));
        bool allSorted = Tableaus.All(t =>
        {
            for (int i = 0; i < t.Cards.Count - 1; i++)
            {
                if (t.Cards[i].Suit != t.Cards[i + 1].Suit || t.Cards[i].Rank != t.Cards[i + 1].Rank + 1)
                    return false;
            }
            return true;
        });
        IsAutocompletable = allFaceUp && allSorted && StockPiles.Count == 0 && !State.HasWon;
    }

    [RelayCommand]
    public void Autocomplete()
    {
        if (!IsAutocompletable) return;

        while (Foundations.Sum(f => f.Cards.Count) < WinCards)
        {
            TryCompleteRuns();
            CheckVictory();
            if (State.HasWon) break;

            bool moved = false;
            foreach (var src in Tableaus.Where(t => t.Cards.Count > 0))
            {
                var seq = GetMovableSequence(src);
                if (seq.Count < 1) continue;
                foreach (var tgt in Tableaus)
                {
                    if (tgt.Id == src.Id) continue;
                    if (CanMoveSequence(seq, tgt))
                    {
                        MoveSequence(seq, src, tgt);
                        moved = true;
                        break;
                    }
                }
                if (moved) break;
            }
            if (!moved) break;
        }
    }

    // MARK: - Dead-end detection

    private void CheckDeadlock()
    {
        if (State.HasWon) return;
        HasNoMoves = !HasAnyLegalMoves();
    }

    private bool HasAnyLegalMoves()
    {
        if (CanDealFromStock) return true;
        foreach (var src in Tableaus)
        {
            var seq = GetMovableSequence(src);
            if (seq.Count == 0) continue;
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (CanMoveSequence(seq, tgt)) return true;
            }
        }
        return false;
    }

    // MARK: - Hint

    [RelayCommand]
    public void FindHint()
    {
        ActiveHint = null;

        foreach (var src in Tableaus)
        {
            var seq = GetMovableSequence(src);
            if (seq.Count == 13 && IsCompleteRun(seq))
            {
                var emptyF = Foundations.FirstOrDefault(f => f.Cards.Count == 0);
                if (emptyF != null)
                {
                    ActiveHint = new HintMove(seq[0], src.Id, emptyF.Id, $"Complete run ready for Foundation.");
                    return;
                }
            }
        }

        foreach (var src in Tableaus)
        {
            var seq = GetMovableSequence(src);
            if (seq.Count == 0) continue;
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (seq.Count > 1 && CanMoveSequence(seq, tgt))
                {
                    ActiveHint = new HintMove(seq[0], src.Id, tgt.Id, $"Move {RankStr(seq[0].Rank)}{SuitStr(seq[0].Suit)} sequence.");
                    return;
                }
            }
        }

        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var card = src.Cards.Last();
            var single = new List<Card> { card };
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (CanMoveSequence(single, tgt))
                {
                    ActiveHint = new HintMove(card, src.Id, tgt.Id, $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)}.");
                    return;
                }
            }
        }

        if (CanDealFromStock)
        {
            ActiveHint = new HintMove(new Card("deal", CardSuit.Spades, 1, false), "", "", "Deal from stock.");
            return;
        }

        ActiveHint = new HintMove(new Card("no_move", CardSuit.Spades, 1, true), "", "", "No moves available.");
    }

    // MARK: - Undo

    [RelayCommand]
    public void Undo()
    {
        if (_undoStack.Count == 0) return;
        RestoreSnapshot(_undoStack.Pop());
        ActiveHint = null;
        HasNoMoves = false;
        CheckAutocomplete();
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(TimeDisplay));
    }

    private void SaveStateForUndo()
    {
        _undoStack.Push(CaptureSnapshot());
        OnPropertyChanged(nameof(CanUndo));
    }

    private SpiderSnapshot CaptureSnapshot()
    {
        return new SpiderSnapshot
        {
            Score = State.Score,
            MovesCount = State.MovesCount,
            TimerSeconds = State.TimerSeconds,
            Tableaus = Tableaus.Select(p => p.Cards.ToList()).ToList(),
            StockPiles = StockPiles.Select(p => p.Cards.ToList()).ToList(),
            Foundations = Foundations.Select(p => p.Cards.ToList()).ToList()
        };
    }

    private void RestoreSnapshot(SpiderSnapshot snapshot)
    {
        State.Score = snapshot.Score;
        State.MovesCount = snapshot.MovesCount;
        State.TimerSeconds = snapshot.TimerSeconds;
        State.HasWon = false;

        for (int i = 0; i < Tableaus.Count && i < snapshot.Tableaus.Count; i++)
        {
            Tableaus[i].Cards.Clear();
            Tableaus[i].Cards.AddRange(snapshot.Tableaus[i]);
        }

        StockPiles.Clear();
        for (int i = 0; i < snapshot.StockPiles.Count; i++)
        {
            var pile = new Pile($"Stock_{i}", PileType.Stock);
            pile.Cards.AddRange(snapshot.StockPiles[i]);
            StockPiles.Add(pile);
        }

        for (int i = 0; i < Foundations.Count && i < snapshot.Foundations.Count; i++)
        {
            Foundations[i].Cards.Clear();
            Foundations[i].Cards.AddRange(snapshot.Foundations[i]);
        }
    }

    // MARK: - Felt Color

    [RelayCommand]
    public void UpdateFeltColor(FeltColorTheme theme)
    {
        Options.FeltColor = theme;
        Options.CustomFeltColorRevision++;
        SettingsService.SaveOptions(Options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(Options));
    }

    public void ResetStatistics()
    {
        var stats = StatsService.LoadStats();
        stats.SpiderStatsBySuit.Remove(SuitKey);
        StatsService.SaveStats(stats);
        Stats = stats;
    }

    // MARK: - Helpers

    private static string RankStr(int rank) => rank switch { 1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => rank.ToString() };

    private static string SuitStr(CardSuit suit) => suit switch
    {
        CardSuit.Spades => "♠",
        CardSuit.Hearts => "♥",
        CardSuit.Diamonds => "♦",
        CardSuit.Clubs => "♣",
        _ => "?"
    };

    private class SpiderSnapshot
    {
        public int Score { get; set; }
        public int MovesCount { get; set; }
        public int TimerSeconds { get; set; }
        public List<List<Card>> Tableaus { get; set; } = new();
        public List<List<Card>> StockPiles { get; set; } = new();
        public List<List<Card>> Foundations { get; set; } = new();
    }
}
