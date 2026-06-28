using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public record OptionsChangedMessage(GameOptions Options);
public record FaceCardArtChangedMessage();

public record HintMove(Card Card, string SourcePileId, string TargetPileId, string Description);

public partial class FreecellViewModel : ObservableObject
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

    public List<Pile> FreeCells { get; } = new();
    public List<Pile> Foundations { get; } = new();
    public List<Pile> Tableaus { get; } = new();

    private readonly Stack<FreecellSnapshot> _undoStack = new();
    private FreecellSnapshot? _initialSnapshot;
    private System.Threading.Timer? _gameTimer;

    public string TimeDisplay => TimeSpan.FromSeconds(State?.TimerSeconds ?? 0).ToString(@"mm\:ss");
    public string ScoreDisplay => State.Score.ToString();
    public bool CanUndo => _undoStack.Count > 0;

    private string ModeKey => $"{(Options.IsVegasScoring ? "vegas" : "standard")}_{Options.FreecellDeckCount}deck";
    private int ExpectedCards => Options.FreecellDeckCount * 52;
    private int NumTableaus => Options.FreecellDeckCount == 1 ? 8 : 10;
    private int NumFreeCells => Options.FreecellDeckCount == 1 ? 4 : 8;
    private int NumFoundations => Options.FreecellDeckCount == 1 ? 4 : 8;

    public FreecellViewModel()
    {
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            var old = Options;
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
            if (Options.FreecellDeckCount != old.FreecellDeckCount || Options.IsVegasScoring != old.IsVegasScoring)
                InitializeGame();
        });

        InitializeGame();
    }

    public void InitializeGame()
    {
        _gameTimer?.Dispose();
        FreeCells.Clear();
        Foundations.Clear();
        Tableaus.Clear();
        _undoStack.Clear();

        for (int i = 0; i < NumFreeCells; i++)
            FreeCells.Add(new Pile($"FreeCell_{i}", PileType.FreeCell));
        for (int i = 0; i < NumFoundations; i++)
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));
        for (int i = 0; i < NumTableaus; i++)
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));

        State = new GameState
        {
            Score = Options.IsVegasScoring ? -5200 * Options.FreecellDeckCount : 0,
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = false,
            HasWon = false
        };

        var suits = new[] { CardSuit.Spades, CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs };
        var deck = new List<Card>();
        for (int d = 0; d < Options.FreecellDeckCount; d++)
        {
            foreach (var suit in suits)
            {
                for (int rank = 1; rank <= 13; rank++)
                {
                    var suitName = suit.ToString().ToLower();
                    var rankStr = rank switch { 1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => rank.ToString() };
                    deck.Add(new Card($"freecell_{d}_{suitName}_{rankStr}", suit, rank, true));
                }
            }
        }

        var rng = new Random();
        deck = deck.OrderBy(_ => rng.Next()).ToList();

        int tableauIndex = 0;
        foreach (var card in deck)
        {
            Tableaus[tableauIndex].Cards.Add(card);
            tableauIndex = (tableauIndex + 1) % NumTableaus;
        }

        var stats = StatsService.LoadStats();
        if (!stats.FreecellStatsByMode.ContainsKey(ModeKey))
            stats.FreecellStatsByMode[ModeKey] = new ModeStats();
        stats.FreecellStatsByMode[ModeKey].GamesPlayed++;
        StatsService.SaveStats(stats);
        Stats = stats;

        _initialSnapshot = CaptureSnapshot();
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

        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
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

        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
    }

    // MARK: - Move Limits

    private int EmptyFreeCellCount => FreeCells.Count(p => p.Cards.Count == 0);
    private int EmptyTableauCount => Tableaus.Count(p => p.Cards.Count == 0);

    private int MaxMoveSize(bool toEmptyTableau)
    {
        int empty = EmptyFreeCellCount;
        int emptyT = toEmptyTableau ? Math.Max(0, EmptyTableauCount - 1) : EmptyTableauCount;
        return (empty + 1) * (1 << emptyT);
    }

    // MARK: - Move Validation

    public bool CanMoveCards(List<Card> cards, Pile target)
    {
        if (cards.Count == 0) return false;
        var first = cards[0];

        for (int i = 0; i < cards.Count - 1; i++)
        {
            if (cards[i].Rank != cards[i + 1].Rank + 1 || IsRed(cards[i].Suit) == IsRed(cards[i + 1].Suit))
                return false;
        }

        if (target.Type == PileType.FreeCell)
            return cards.Count == 1 && target.Cards.Count == 0;

        if (target.Type == PileType.Foundation)
        {
            if (cards.Count != 1) return false;
            if (target.Cards.Count == 0) return first.Rank == 1;
            var top = target.Cards.Last();
            return top.Suit == first.Suit && first.Rank == top.Rank + 1;
        }

        if (target.Type == PileType.Tableau)
        {
            bool toEmpty = target.Cards.Count == 0;
            if (cards.Count > MaxMoveSize(toEmpty)) return false;
            if (toEmpty) return true;
            var top = target.Cards.Last();
            return top.IsFaceUp && first.Rank == top.Rank - 1 && IsRed(first.Suit) != IsRed(top.Suit);
        }

        return false;
    }

    public void MoveCards(List<Card> cards, Pile source, Pile target)
    {
        if (!CanMoveCards(cards, target)) return;

        SaveStateForUndo();

        if (!State.IsTimerActive && !State.HasWon)
            State.IsTimerActive = true;

        var cardIds = new HashSet<string>(cards.Select(c => c.Id));

        var sourcePile = FindPileContaining(cards[0]);
        sourcePile?.Cards.RemoveAll(c => cardIds.Contains(c.Id));

        foreach (var card in cards)
            target.Cards.Add(card);

        UpdateScore(source.Type, target.Type, cards.Count);
        State.MovesCount++;
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        ActiveHint = null;

        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(TimeDisplay));
    }

    private Pile? FindPileContaining(Card card)
    {
        foreach (var p in FreeCells) if (p.Cards.Any(c => c.Id == card.Id)) return p;
        foreach (var p in Foundations) if (p.Cards.Any(c => c.Id == card.Id)) return p;
        foreach (var p in Tableaus) if (p.Cards.Any(c => c.Id == card.Id)) return p;
        return null;
    }

    private void UpdateScore(PileType source, PileType target, int cardCount)
    {
        if (Options.IsVegasScoring)
        {
            if (target == PileType.Foundation) State.Score += 500 * cardCount;
            else if (source == PileType.Foundation) State.Score -= 500 * cardCount;
        }
        else
        {
            if (target == PileType.Foundation) State.Score += 10 * cardCount;
            else if (source == PileType.Foundation) State.Score = Math.Max(0, State.Score - 15 * cardCount);
        }
        OnPropertyChanged(nameof(ScoreDisplay));
    }

    // MARK: - Victory

    private void CheckVictory()
    {
        if (Foundations.Sum(f => f.Cards.Count) == ExpectedCards && !State.HasWon)
        {
            State.HasWon = true;
            State.IsTimerActive = false;
            _gameTimer?.Dispose();

            var stats = StatsService.LoadStats();
            if (!stats.FreecellStatsByMode.ContainsKey(ModeKey))
                stats.FreecellStatsByMode[ModeKey] = new ModeStats();
            var ms = stats.FreecellStatsByMode[ModeKey];
            ms.GamesWon++;
            ms.CurrentStreak++;
            if (ms.CurrentStreak > ms.LongestStreak) ms.LongestStreak = ms.CurrentStreak;
            if (State.Score > ms.HighScore) ms.HighScore = State.Score;
            stats.FreecellStatsByMode[ModeKey] = ms;
            StatsService.SaveStats(stats);
            Stats = stats;
        }
    }

    // MARK: - Autocomplete

    private void CheckAutocomplete()
    {
        bool freeCellsEmpty = FreeCells.All(f => f.Cards.Count == 0);
        bool tableauSorted = Tableaus.All(pile =>
        {
            for (int i = 0; i < pile.Cards.Count - 1; i++)
            {
                if (pile.Cards[i].Rank != pile.Cards[i + 1].Rank + 1 ||
                    IsRed(pile.Cards[i].Suit) == IsRed(pile.Cards[i + 1].Suit))
                    return false;
            }
            return true;
        });
        IsAutocompletable = freeCellsEmpty && tableauSorted && !State.HasWon;
    }

    [RelayCommand]
    public void Autocomplete()
    {
        if (!IsAutocompletable) return;

        while (Foundations.Sum(f => f.Cards.Count) < ExpectedCards)
        {
            bool moved = false;
            foreach (var tableau in Tableaus.Where(t => t.Cards.Count > 0))
            {
                var card = tableau.Cards.Last();
                foreach (var foundation in Foundations)
                {
                    if (CanMoveCards(new List<Card> { card }, foundation))
                    {
                        MoveCards(new List<Card> { card }, tableau, foundation);
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
        // Free cell → foundation or tableau
        foreach (var cell in FreeCells)
        {
            if (cell.Cards.Count == 0) continue;
            var single = new List<Card> { cell.Cards.Last() };
            foreach (var f in Foundations) if (CanMoveCards(single, f)) return true;
            foreach (var t in Tableaus) if (CanMoveCards(single, t)) return true;
        }
        // Tableau top → foundation
        foreach (var tab in Tableaus)
        {
            if (tab.Cards.Count == 0) continue;
            var single = new List<Card> { tab.Cards.Last() };
            foreach (var f in Foundations) if (CanMoveCards(single, f)) return true;
        }
        // Tableau sequence → other tableau
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var seq = GetMovableSequence(src);
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (tgt.Cards.Count == 0 && seq.Count == src.Cards.Count) continue;
                if (CanMoveCards(seq, tgt)) return true;
            }
        }
        // Tableau top → free cell
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var single = new List<Card> { src.Cards.Last() };
            foreach (var cell in FreeCells) if (CanMoveCards(single, cell)) return true;
        }
        return false;
    }

    // MARK: - Hint

    [RelayCommand]
    public void FindHint()
    {
        ActiveHint = null;

        foreach (var cell in FreeCells)
        {
            if (cell.Cards.Count == 0) continue;
            var card = cell.Cards.Last();
            foreach (var f in Foundations)
            {
                if (CanMoveCards(new List<Card> { card }, f))
                {
                    ActiveHint = new HintMove(card, cell.Id, f.Id, $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} from Free Cell to Foundation.");
                    return;
                }
            }
        }

        foreach (var tab in Tableaus)
        {
            if (tab.Cards.Count == 0) continue;
            var card = tab.Cards.Last();
            foreach (var f in Foundations)
            {
                if (CanMoveCards(new List<Card> { card }, f))
                {
                    ActiveHint = new HintMove(card, tab.Id, f.Id, $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} to Foundation.");
                    return;
                }
            }
        }

        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var seq = GetMovableSequence(src);
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;
                if (tgt.Cards.Count == 0 && seq.Count == src.Cards.Count) continue;
                if (CanMoveCards(seq, tgt))
                {
                    ActiveHint = new HintMove(seq[0], src.Id, tgt.Id, $"Move {RankStr(seq[0].Rank)}{SuitStr(seq[0].Suit)} sequence.");
                    return;
                }
            }
        }

        foreach (var cell in FreeCells)
        {
            if (cell.Cards.Count == 0) continue;
            var card = cell.Cards.Last();
            foreach (var tgt in Tableaus)
            {
                if (CanMoveCards(new List<Card> { card }, tgt))
                {
                    ActiveHint = new HintMove(card, cell.Id, tgt.Id, $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} from Free Cell to Tableau.");
                    return;
                }
            }
        }

        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var card = src.Cards.Last();
            foreach (var cell in FreeCells)
            {
                if (CanMoveCards(new List<Card> { card }, cell))
                {
                    ActiveHint = new HintMove(card, src.Id, cell.Id, $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} to Free Cell.");
                    return;
                }
            }
        }

        ActiveHint = new HintMove(new Card("no_move", CardSuit.Spades, 1, true), "", "", "No moves available.");
    }

    private List<Card> GetMovableSequence(Pile source)
    {
        var result = new List<Card>();
        if (source.Cards.Count == 0) return result;
        result.Add(source.Cards.Last());
        for (int i = source.Cards.Count - 2; i >= 0; i--)
        {
            var upper = source.Cards[i];
            var lower = source.Cards[i + 1];
            if (upper.IsFaceUp && upper.Rank == lower.Rank + 1 && IsRed(upper.Suit) != IsRed(lower.Suit))
                result.Insert(0, upper);
            else
                break;
        }
        return result;
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
        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(ScoreDisplay));
    }

    private void SaveStateForUndo()
    {
        _undoStack.Push(CaptureSnapshot());
        OnPropertyChanged(nameof(CanUndo));
    }

    private FreecellSnapshot CaptureSnapshot()
    {
        return new FreecellSnapshot
        {
            Score = State.Score,
            MovesCount = State.MovesCount,
            TimerSeconds = State.TimerSeconds,
            FreeCells = FreeCells.Select(p => p.Cards.ToList()).ToList(),
            Foundations = Foundations.Select(p => p.Cards.ToList()).ToList(),
            Tableaus = Tableaus.Select(p => p.Cards.ToList()).ToList()
        };
    }

    private void RestoreSnapshot(FreecellSnapshot snapshot)
    {
        State.Score = snapshot.Score;
        State.MovesCount = snapshot.MovesCount;
        State.TimerSeconds = snapshot.TimerSeconds;
        State.HasWon = false;

        for (int i = 0; i < FreeCells.Count && i < snapshot.FreeCells.Count; i++)
        {
            FreeCells[i].Cards.Clear();
            FreeCells[i].Cards.AddRange(snapshot.FreeCells[i]);
        }
        for (int i = 0; i < Foundations.Count && i < snapshot.Foundations.Count; i++)
        {
            Foundations[i].Cards.Clear();
            Foundations[i].Cards.AddRange(snapshot.Foundations[i]);
        }
        for (int i = 0; i < Tableaus.Count && i < snapshot.Tableaus.Count; i++)
        {
            Tableaus[i].Cards.Clear();
            Tableaus[i].Cards.AddRange(snapshot.Tableaus[i]);
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
        stats.FreecellStatsByMode.Remove(ModeKey);
        StatsService.SaveStats(stats);
        Stats = stats;
    }

    // MARK: - Helpers

    private static bool IsRed(CardSuit suit) => suit == CardSuit.Hearts || suit == CardSuit.Diamonds;

    private static string RankStr(int rank) => rank switch { 1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => rank.ToString() };

    private static string SuitStr(CardSuit suit) => suit switch
    {
        CardSuit.Spades => "♠",
        CardSuit.Hearts => "♥",
        CardSuit.Diamonds => "♦",
        CardSuit.Clubs => "♣",
        _ => "?"
    };

    private class FreecellSnapshot
    {
        public int Score { get; set; }
        public int MovesCount { get; set; }
        public int TimerSeconds { get; set; }
        public List<List<Card>> FreeCells { get; set; } = new();
        public List<List<Card>> Foundations { get; set; } = new();
        public List<List<Card>> Tableaus { get; set; } = new();
    }
}
