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
    private bool _isAutoplayRunning;

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
    private readonly SynchronizationContext? _syncContext;
    private int _foundationCardCount;

    // Set by PauseTimerForSwitch when the timer was actually running at the moment this
    // game was switched away from, so ResumeTimerForSwitch only restarts it if it was
    // genuinely paused (not, say, a fresh/unstarted or already-won game).
    private bool _timerPausedForSwitch;

    private List<HintMove> _hintCycleList  = new();
    private int            _hintCycleIndex = 0;

    // Tracks the last card move so hints can filter out its exact reversal.
    private string? _lastMoveSourcePileId;
    private string? _lastMoveTargetPileId;

    private System.Threading.Timer? _autocompleteTimer;
    // Windows-fork deviation: once autocomplete has ever run this game, Undo stays
    // disabled for the rest of the game (rather than allowing mid-autoplay cancel-undo).
    private bool _autocompleteLocked;

    // SuitKey of the game currently in progress, captured at the end of each
    // InitializeGame call. Needed because callers (suit-count change) mutate Options
    // *before* calling InitializeGame — so by the time this method recomputes SuitKey
    // to decide whether an abandoned game broke a streak, it would otherwise reflect
    // the *new* suit count being switched to, not the one just abandoned.
    private string? _lastGameSuitKey;

    public string TimeDisplay => TimeSpan.FromSeconds(State?.TimerSeconds ?? 0).ToString(@"mm\:ss");

    // Spider has no Vegas mode of its own — Options.IsVegasScoring is shared with
    // Klondike, but Spider always uses standard scoring regardless of it.
    public string ScoreDisplay => State.Score.ToString();

    public bool CanUndo => _undoStack.Count > 0 && !_autocompleteLocked && !State.HasWon;

    private string SuitKey => Options.SpiderSuitCount.ToString();
    private const int TotalFoundations = 8;
    private const int WinCards = 104;

    public SpiderViewModel()
    {
        _syncContext = SynchronizationContext.Current;
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            var old = Options;
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
            if (Options.SpiderSuitCount != old.SpiderSuitCount)
                InitializeGame(countAsNewGame: false);
        });

        for (int i = 0; i < 10; i++)
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));
        for (int i = 0; i < TotalFoundations; i++)
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));

        InitializeGame();
    }

    public void InitializeGame(bool countAsNewGame = true)
    {
        bool wasAbandonedGame = State.MovesCount > 0 && !State.HasWon;

        _autocompleteTimer?.Dispose();
        _autocompleteTimer = null;
        IsAutoplayRunning = false;
        _autocompleteLocked = false;

        _gameTimer?.Dispose();
        StockPiles.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        _foundationCardCount = 0;
        _undoStack.Clear();

        int startScore = 500;

        State = new GameState
        {
            Score = startScore,
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = false,
            HasWon = false
        };

        var deck = BuildDeck();
        var rng = new Random();
        for (int i = deck.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (deck[i], deck[j]) = (deck[j], deck[i]);
        }

        int deckIdx = 0;
        for (int col = 0; col < 10; col++)
        {
            int count = col < 4 ? 6 : 5;
            for (int i = 0; i < count; i++)
            {
                var card = deck[deckIdx++];
                Tableaus[col].Cards.Add(i == count - 1 ? card with { IsFaceUp = true } : card);
            }
        }

        while (deckIdx < deck.Count)
        {
            var stockPile = new Pile($"Stock_{StockPiles.Count}", PileType.Stock);
            for (int i = 0; i < 10 && deckIdx < deck.Count; i++)
            {
                stockPile.Cards.Add(deck[deckIdx++]);
            }
            StockPiles.Add(stockPile);
        }

        var stats = StatsService.LoadStats();
        if (!stats.SpiderStatsBySuit.ContainsKey(SuitKey))
            stats.SpiderStatsBySuit[SuitKey] = new ModeStats();
        if (wasAbandonedGame)
        {
            string abandonedSuitKey = _lastGameSuitKey ?? SuitKey;
            if (!stats.SpiderStatsBySuit.ContainsKey(abandonedSuitKey))
                stats.SpiderStatsBySuit[abandonedSuitKey] = new ModeStats();
            stats.SpiderStatsBySuit[abandonedSuitKey].CurrentStreak = 0;
        }
        if (countAsNewGame) stats.SpiderStatsBySuit[SuitKey].GamesPlayed++;
        StatsService.SaveStats(stats);
        Stats = stats;
        _lastGameSuitKey = SuitKey;

        IsAutocompletable = false;
        HasNoMoves = false;
        ClearHintCycle();
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        _initialSnapshot = CaptureSnapshot();

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
        ClearHintCycle();
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        _autocompleteTimer?.Dispose();
        _autocompleteTimer = null;
        IsAutoplayRunning = false;
        _autocompleteLocked = false;

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

        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
        OnPropertyChanged(nameof(Foundations));
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
                result.Add(upper);
            else
                break;
        }
        result.Reverse();
        return result;
    }

    public void MoveSequence(List<Card> cards, Pile source, Pile target)
    {
        if (!CanMoveSequence(cards, target)) return;

        SaveStateForUndo();

        if (!State.IsTimerActive && !State.HasWon && !Options.IsNoStressMode)
            State.IsTimerActive = true;

        var cardIds = new HashSet<string>(cards.Select(c => c.Id));
        source.Cards.RemoveAll(c => cardIds.Contains(c.Id));

        foreach (var card in cards)
            target.Cards.Add(card);

        FlipTopCard(source);

        State.Score--;

        State.MovesCount++;
        TryCompleteRuns();
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        ClearHintCycle();
        _lastMoveSourcePileId = source.Id;
        _lastMoveTargetPileId = target.Id;

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

        if (!State.IsTimerActive && !State.HasWon && !Options.IsNoStressMode)
            State.IsTimerActive = true;

        var deal = StockPiles[0];
        StockPiles.RemoveAt(0);

        for (int i = 0; i < Tableaus.Count && i < deal.Cards.Count; i++)
            Tableaus[i].Cards.Add(deal.Cards[i] with { IsFaceUp = true });

        State.Score--;

        State.MovesCount++;
        TryCompleteRuns();
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        ClearHintCycle();

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
                _foundationCardCount += run.Count;
                tableau.Cards.RemoveRange(tableau.Cards.Count - 13, 13);
                FlipTopCard(tableau);

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
        if (_foundationCardCount == WinCards && !State.HasWon)
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

            // TimerSeconds only actually ticks when No Stress Mode is off (see the
            // State.IsTimerActive gating on every move above) — otherwise it stays 0
            // for the whole game. Recording that 0 here would permanently pin "Fastest
            // Win" to a bogus 0s and silently deflate "Avg Winning Time", so skip both
            // when untimed.
            if (!Options.IsNoStressMode)
            {
                if (ms.ShortestWinSeconds == 0 || State.TimerSeconds < ms.ShortestWinSeconds)
                    ms.ShortestWinSeconds = State.TimerSeconds;
                ms.TotalWinSeconds += State.TimerSeconds;
            }
            stats.SpiderStatsBySuit[SuitKey] = ms;
            StatsService.SaveStats(stats);
            Stats = stats;
        }
    }

    // Resets only the current suit-count bucket, leaving Klondike's and Freecell's
    // data (and Spider's other suit-count buckets) untouched.
    public void ResetStats()
    {
        var stats = StatsService.LoadStats();
        stats.SpiderStatsBySuit[SuitKey] = new ModeStats();
        StatsService.SaveStats(stats);
        Stats = stats;
    }

    // MARK: - Autocomplete

    private void CheckAutocomplete()
    {
        if (StockPiles.Count != 0 || _foundationCardCount >= WinCards) { IsAutocompletable = false; return; }
        IsAutocompletable = FindNextAutocompleteMove() != null;
    }

    // Spider doesn't merge to foundations directly — it merges whole same-suit columns onto
    // each other, and relies on TryCompleteRuns() (called inside MoveSequence) to auto-sweep
    // any newly-formed complete K→A run. A source column only qualifies if its entire stack
    // (not just the topmost movable run) is already one coherent same-suit descending sequence.
    private (Pile Source, Pile Target)? FindNextAutocompleteMove()
    {
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            if (GetMovableSequence(src).Count != src.Cards.Count) continue;

            var sourceHighest = src.Cards[0];
            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id || tgt.Cards.Count == 0) continue;
                var targetTop = tgt.Cards.Last();
                if (targetTop.Suit == sourceHighest.Suit && targetTop.Rank == sourceHighest.Rank + 1)
                    return (src, tgt);
            }
        }
        return null;
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
        var move = FindNextAutocompleteMove();
        if (move != null)
        {
            var (src, tgt) = move.Value;
            MoveSequence(src.Cards.ToList(), src, tgt);
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

    // MARK: - Dead-end detection

    private void CheckDeadlock()
    {
        if (State.HasWon || IsAutocompletable) { HasNoMoves = false; return; }
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

    // Public so the view can clear the queue when a hint's on-screen timer expires
    // (auto-dismiss), matching the rule that the next Hint press starts fresh.
    public void ClearHintCycle()
    {
        _hintCycleList.Clear();
        _hintCycleIndex = 0;
        ActiveHint      = null;
    }

    [RelayCommand]
    public void FindHint()
    {
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

    private List<HintMove> CollectAllHints()
    {
        var scored = new List<(int Score, HintMove Hint)>();

        // Evaluate every valid drag sequence in each column — every suffix of the column's
        // maximal movable run is itself a legal draggable sequence starting further down.
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var maxSeq = GetMovableSequence(src);
            if (maxSeq.Count == 0) continue;
            int firstFaceUpIdx = src.Cards.FindIndex(c => c.IsFaceUp);

            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;

                if (tgt.Cards.Count == 0)
                {
                    // Priority 5/6: sequence → empty column
                    for (int len = maxSeq.Count; len >= 1; len--)
                    {
                        var subSeq = maxSeq.GetRange(maxSeq.Count - len, len);
                        int startIdx = src.Cards.Count - len;
                        bool revealsHidden = startIdx == firstFaceUpIdx && firstFaceUpIdx > 0;
                        bool emptiesColumn = src.Cards.Count - len == 0;

                        if (revealsHidden)
                        {
                            scored.Add((350 + firstFaceUpIdx * 50, new HintMove(subSeq[0], src.Id, tgt.Id,
                                $"Move {RankStr(subSeq[0].Rank)}{SuitStr(subSeq[0].Suit)} sequence.")));
                            break;
                        }
                        if (emptiesColumn) continue; // suppressed — try a shorter, partial sequence instead
                        scored.Add((200, new HintMove(subSeq[0], src.Id, tgt.Id,
                            $"Move {RankStr(subSeq[0].Rank)}{SuitStr(subSeq[0].Suit)} sequence.")));
                        break;
                    }
                }
                else
                {
                    // Priority 1-4: continuation onto a non-empty column (same-suit or cross-suit)
                    for (int len = maxSeq.Count; len >= 1; len--)
                    {
                        var subSeq = maxSeq.GetRange(maxSeq.Count - len, len);
                        if (!CanMoveSequence(subSeq, tgt)) continue;

                        int startIdx        = src.Cards.Count - len;
                        bool revealsHidden   = startIdx == firstFaceUpIdx && firstFaceUpIdx > 0;
                        bool sameSuit        = subSeq[0].Suit == tgt.Cards.Last().Suit;
                        int score = (sameSuit, revealsHidden) switch
                        {
                            (true,  true)  => 1000 + firstFaceUpIdx * 100,
                            (true,  false) => 900,
                            (false, true)  => 600 + firstFaceUpIdx * 100,
                            (false, false) => 400,
                        };
                        scored.Add((score, new HintMove(subSeq[0], src.Id, tgt.Id,
                            $"Move {RankStr(subSeq[0].Rank)}{SuitStr(subSeq[0].Suit)} sequence.")));
                        break;
                    }
                }
            }
        }

        // Priority 7/8: deal from stock
        if (StockPiles.Count > 0)
        {
            var dealCard = new Card("deal", CardSuit.Spades, 1, false);
            if (Tableaus.All(t => t.Cards.Count > 0))
                scored.Add((50, new HintMove(dealCard, "", "", "Deal from stock.")));
            else
                scored.Add((25, new HintMove(dealCard, "", "", "Fill all empty columns before dealing cards.")));
        }

        var hints = scored.OrderByDescending(s => s.Score).Select(s => s.Hint).ToList();

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

    // MARK: - Undo

    [RelayCommand]
    public void Undo()
    {
        if (_undoStack.Count == 0 || State.HasWon) return;
        RestoreSnapshot(_undoStack.Pop());
        ClearHintCycle();
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        HasNoMoves = false;

        // A win disposes _gameTimer (see CheckVictory); undoing past that win leaves
        // State.HasWon false again, so the timer must be recreated here or TimeDisplay
        // freezes for the rest of the session. Dispose is idempotent, so it's safe to
        // call again even if the timer wasn't the disposed one.
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

        CheckAutocomplete();
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(ScoreDisplay));
    }

    private void SaveStateForUndo()
    {
        // No-op during autoplay so every move it makes bundles into the single
        // pre-autocomplete snapshot already pushed when Autocomplete() started.
        if (IsAutoplayRunning) return;

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
        _foundationCardCount = Foundations.Sum(f => f.Cards.Count);
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
