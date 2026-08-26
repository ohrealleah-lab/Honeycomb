using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public record OptionsChangedMessage(GameOptions Options);
public record FaceCardArtChangedMessage();

// Sent by any game view/banner (Win, Stuck, Autocomplete, round-result, etc.) whenever its
// own local darkening scrim shows/hides, so MainWindow can extend that same darkening up
// over the toolbar strip — the local per-view scrims are sized to that view's own board
// content and can never reach the toolbar themselves (it lives in a separate row of
// MainWindow's root Grid). Source disambiguates multiple simultaneously-active scrims
// (e.g. a view's own banner plus its embedded WinAnimationView) so one hiding doesn't
// clear a scrim another still wants shown — see MainWindow's _activeScrimSources.
public record BoardScrimRequestMessage(object Source, bool Active);

// Index/Total are 1-based queue position info for the "[N/Total]" label prefix.
// Left at their defaults (1/1) by callers that don't have a real queue yet — a
// single-hint queue shows no prefix, which is exactly the desired display for those.
public record HintMove(Card Card, string SourcePileId, string TargetPileId, string Description, int Index = 1, int Total = 1);

public partial class FreecellViewModel : ObservableObject, ISolitaireGameViewModel
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

    [ObservableProperty]
    private CardPointPopup? _pointPopup;

    // Flat properties for the bee watermark's RenderTransform bindings (FreecellView.axaml).
    // A binding path like "Options.FreecellWatermarkScale" only refreshes when Avalonia
    // re-walks the whole path, which isn't reliable on the rapid-fire ticks the dev
    // calibration sliders send while being dragged. [ObservableProperty] on a flat double
    // gives each tick its own real equality-checked change notification instead, matching
    // HoneycombViewModel's already-working HoneycombWatermarkScale.
    [ObservableProperty]
    private double _freecellWatermarkScale = 1.0;

    [ObservableProperty]
    private double _freecellWatermarkOffsetX;

    [ObservableProperty]
    private double _freecellWatermarkOffsetY;

    // Flat passthrough so MainWindow's shared Preferences/Stats overlay watermarks (used
    // by all 6 games, unlike the per-game board watermark above) can bind a single
    // "HideBee" path regardless of which game's ViewModel is currently the DataContext —
    // matching HoneycombViewModel's own top-level HideBee.
    public bool HideBee => Options.HideBee;

    public List<Pile> FreeCells { get; } = new();
    public List<Pile> Foundations { get; } = new();
    public List<Pile> Tableaus { get; } = new();

    // Total across every deck-count mode, not just the current ModeKey's bucket —
    // "10 wins" for a milestone should mean the game overall, not one specific mode.
    private int TotalGamesWon => Stats.FreecellStatsByMode.Values.Sum(m => m.GamesWon);
    private int TotalGamesPlayed => Stats.FreecellStatsByMode.Values.Sum(m => m.GamesPlayed);

    // FIFO queue of banner texts (milestones, loading flavor) — mirrors the Honeycomb
    // port's BannerQueue/EnqueueBanner/AdvanceBannerQueue.
    private readonly Queue<string> _bannerQueue = new();
    public event Action<string>? OnFlashBanner;

    private void EnqueueBanner(string text)
    {
        _bannerQueue.Enqueue(text);
        if (_bannerQueue.Count == 1) OnFlashBanner?.Invoke(text);
    }

    public void AdvanceBannerQueue()
    {
        if (_bannerQueue.Count == 0) return;
        _bannerQueue.Dequeue();
        if (_bannerQueue.Count > 0) OnFlashBanner?.Invoke(_bannerQueue.Peek());
    }

    // Fires once, exactly on the win that crosses a threshold — not "TotalGamesWon >=
    // threshold", which would fire on every subsequent win too.
    private void CheckWinMilestones()
    {
        var thresholds = new (int Threshold, BannerId Id)[]
        {
            (10, BannerId.MilestonesPlayerReaches10TotalWins),
            (100, BannerId.MilestonesPlayerReaches100TotalWins),
            (1000, BannerId.MilestonesPlayerReaches1000TotalWins),
        };
        foreach (var (threshold, id) in thresholds)
        {
            if (TotalGamesWon != threshold) continue;
            var result = BannerCatalog.Fire(id);
            if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
        }
    }

    // Fires once per app session, the first time this game's view actually appears
    // (called from FreecellView's Loaded handler — a "loading" banner belongs to a
    // screen transition, not a gameplay action, so switching to this game for the
    // first time this session fires it; switching back to it later doesn't).
    private bool _hasFiredLoadingBannerThisSession;

    public void CheckLoadingBanner()
    {
        if (_hasFiredLoadingBannerThisSession) return;
        _hasFiredLoadingBannerThisSession = true;
        var result = BannerCatalog.Fire(BannerCatalog.LoadingBannerId());
        if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
    }

    // Ambiance/Idle nudge: fires if a full minute passes with no move. Re-armed via a
    // generation-token so an already-scheduled check from before the last move sees a
    // mismatch and silently no-ops instead of firing late. Mirrors the Honeycomb
    // port's ScheduleIdleCheck — called from InitializeGame() and every move site.
    private int _idleCheckGeneration = 0;
    private const int IdleToastDelayMs = 60000;

    public async void ScheduleIdleActionCheck()
    {
        if (TestMode.IsHeadless) return;
        _idleCheckGeneration++;
        var generation = _idleCheckGeneration;
        await Task.Delay(IdleToastDelayMs);
        if (_idleCheckGeneration != generation || State.HasWon) return;
        var result = BannerCatalog.Fire(BannerId.IdleActionNoActionTakenForOneMinute);
        if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
    }

    private readonly Stack<FreecellSnapshot> _undoStack = new();
    private FreecellSnapshot? _initialSnapshot;
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

    private System.Threading.Timer? _pointPopupTimer;
    private int _pointPopupGeneration;

    // ModeKey of the game that's currently in progress, captured at the end of each
    // InitializeGame call. Needed because callers (deck-count change) mutate Options
    // *before* calling InitializeGame — so by the time this method recomputes ModeKey
    // to decide whether an abandoned game broke a streak, it would otherwise reflect
    // the *new* mode being switched to, not the one just abandoned.
    private string? _lastGameModeKey;

    public string TimeDisplay => TimeSpan.FromSeconds(State?.TimerSeconds ?? 0).ToString(@"mm\:ss");
    public string ScoreDisplay => State.Score.ToString();
    // See GameViewModel.MovesCount — GameState is a plain class, so mutating
    // State.MovesCount++ in place never notifies the {Binding MovesCount} MOVES panel on
    // its own; explicit OnPropertyChanged(nameof(MovesCount)) calls at each mutation site
    // are what refresh it.
    public int MovesCount => State?.MovesCount ?? 0;
    public bool CanUndo => _undoStack.Count > 0 && !_autocompleteLocked && !State.HasWon;

    // Freecell has no Vegas-mode option of its own — Options.IsVegasScoring is shared
    // with Klondike/Spider, but Freecell always uses standard scoring regardless of it.
    private string ModeKey => $"standard_{Options.FreecellDeckCount}deck";
    private int ExpectedCards => Options.FreecellDeckCount * 52;
    private int NumTableaus => Options.FreecellDeckCount == 1 ? 8 : 10;
    private int NumFreeCells => Options.FreecellDeckCount == 1 ? 4 : 8;
    private int NumFoundations => Options.FreecellDeckCount == 1 ? 4 : 8;

    public FreecellViewModel()
    {
        _syncContext = SynchronizationContext.Current;
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();
        StatsService.MigrateFreecellVegasStats(Stats);
        StatsService.SaveStats(Stats);
        FreecellWatermarkScale   = Options.FreecellWatermarkScale;
        FreecellWatermarkOffsetX = Options.FreecellWatermarkOffsetX;
        FreecellWatermarkOffsetY = Options.FreecellWatermarkOffsetY;

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            var old = Options;
            // No Stress Mode's whole point is "no timer" — if it's switched on mid-game,
            // stop the timer immediately and zero the elapsed time; if switched back off,
            // resume immediately instead of leaving it frozen until the next move. Only
            // zero on the "stop" branch if the timer was actually running here — a
            // shared-option change reaching a backgrounded game (this one isn't the active
            // tab) shouldn't wipe elapsed time it already had paused.
            bool noStressJustEnabled  = m.Options.IsNoStressMode && !old.IsNoStressMode;
            bool noStressJustDisabled = !m.Options.IsNoStressMode && old.IsNoStressMode;
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
            OnPropertyChanged(nameof(HideBee));
            FreecellWatermarkScale   = m.Options.FreecellWatermarkScale;
            FreecellWatermarkOffsetX = m.Options.FreecellWatermarkOffsetX;
            FreecellWatermarkOffsetY = m.Options.FreecellWatermarkOffsetY;
            if (Options.FreecellDeckCount != old.FreecellDeckCount)
                InitializeGame(countAsNewGame: false);
            else if (noStressJustEnabled && State.IsTimerActive)
            {
                State.IsTimerActive = false;
                State.TimerSeconds = 0;
            }
            else if (noStressJustDisabled && State.MovesCount > 0 && !State.HasWon)
                State.IsTimerActive = true;
        });

        InitializeGame();
    }

    public void InitializeGame(bool countAsNewGame = true)
    {
        bool wasAbandonedGame = State.MovesCount > 0 && !State.HasWon;

        ClearHintCycle();
        PointPopup = null;
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        _autocompleteTimer?.Dispose();
        _autocompleteTimer = null;
        IsAutoplayRunning = false;
        _autocompleteLocked = false;

        _gameTimer?.Dispose();
        FreeCells.Clear();
        Foundations.Clear();
        _foundationCardCount = 0;
        Tableaus.Clear();
        _undoStack.Clear();

        for (int i = 0; i < NumFreeCells; i++)
            FreeCells.Add(new Pile($"FreeCell_{i}", PileType.FreeCell));
        for (int i = 0; i < NumFoundations; i++)
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));
        for (int i = 0; i < NumTableaus; i++)
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));

        // Freecell has no Vegas buy-in — every new game starts at a clean 0.
        int startScore = 0;

        State = new GameState
        {
            Score = startScore,
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
        for (int i = deck.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (deck[i], deck[j]) = (deck[j], deck[i]);
        }

        int tableauIndex = 0;
        foreach (var card in deck)
        {
            Tableaus[tableauIndex].Cards.Add(card);
            tableauIndex = (tableauIndex + 1) % NumTableaus;
        }

        var stats = StatsService.LoadStats();
        if (!stats.FreecellStatsByMode.ContainsKey(ModeKey))
            stats.FreecellStatsByMode[ModeKey] = new ModeStats();
        if (wasAbandonedGame)
        {
            string abandonedModeKey = _lastGameModeKey ?? ModeKey;
            if (!stats.FreecellStatsByMode.ContainsKey(abandonedModeKey))
                stats.FreecellStatsByMode[abandonedModeKey] = new ModeStats();
            stats.FreecellStatsByMode[abandonedModeKey].CurrentStreak = 0;
        }
        if (countAsNewGame)
        {
            // Checked against the freshly-reloaded `stats` local, before this call's
            // own increment below — Stats (the property) still holds whatever was
            // loaded at construction time, which could already be stale by now.
            if (stats.FreecellStatsByMode.Values.Sum(m => m.GamesPlayed) == 0)
            {
                var firstLaunchResult = BannerCatalog.Fire(BannerId.MilestonesFirstLaunchEver);
                if (firstLaunchResult.Kind == BannerFireKind.Message) EnqueueBanner(firstLaunchResult.Text!);
            }

            stats.FreecellStatsByMode[ModeKey].GamesPlayed++;
        }
        StatsService.SaveStats(stats);
        Stats = stats;
        _lastGameModeKey = ModeKey;

        _initialSnapshot = CaptureSnapshot();
        IsAutocompletable = false;
        HasNoMoves = false;

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

        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(TimeDisplay));
        OnPropertyChanged(nameof(CanUndo));
        ScheduleIdleActionCheck();
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
        PointPopup = null;
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

        OnPropertyChanged(nameof(FreeCells));
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
            // Foundation-to-foundation is legal (2-deck mode especially has a real reason
            // to reorganize which foundation slot holds which suit's Ace) — UpdateScore
            // excludes this from the +10 bonus so it can't be shuffled for free score.
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

        if (!State.IsTimerActive && !State.HasWon && !Options.IsNoStressMode)
            State.IsTimerActive = true;

        var cardIds = new HashSet<string>(cards.Select(c => c.Id));

        source.Cards.RemoveAll(c => cardIds.Contains(c.Id));

        foreach (var card in cards)
            target.Cards.Add(card);

        if (target.Type == PileType.Foundation) _foundationCardCount += cards.Count;
        if (source.Type == PileType.Foundation) _foundationCardCount -= cards.Count;

        UpdateScore(source.Type, target.Type, cards.Count);
        State.MovesCount++;
        OnPropertyChanged(nameof(MovesCount));
        ScheduleIdleActionCheck();
        CheckVictory();
        CheckAutocomplete();
        CheckDeadlock();
        ClearHintCycle();
        _lastMoveSourcePileId = source.Id;
        _lastMoveTargetPileId = target.Id;

        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(TimeDisplay));

        // Deliberately last — see the matching comment in GameViewModel.MoveCard: the UI
        // looks up the anchor CardView by card id in reaction to this notification, so it
        // must fire after the pile notifications above have let the views rebuild for
        // the move that just happened.
        UpdatePointPopup(cards.Last(), source.Type, target.Type, cards.Count);
    }

    private void UpdateScore(PileType source, PileType target, int cardCount)
    {
        // Excludes source==Foundation from the bonus so relocating a card between
        // foundations (reorganizing which slot holds which suit) nets zero score either
        // way — otherwise a lone Ace shuffled between two empty foundations would earn
        // +10 every single move, forever, for free.
        if (target == PileType.Foundation && source != PileType.Foundation) State.Score += 10 * cardCount;
        else if (source == PileType.Foundation && target != PileType.Foundation) State.Score = Math.Max(0, State.Score - 15 * cardCount);
        OnPropertyChanged(nameof(ScoreDisplay));
    }

    // Point Highlights: mirrors UpdateScore's branching, anchored to the moved card
    // (its bottom-most card — cards.Last() — matching this fork's convention elsewhere).
    private void UpdatePointPopup(Card anchorCard, PileType source, PileType target, int cardCount)
    {
        if (!Options.HoneyMode || IsAutoplayRunning) return;

        CardPointPopup? popup;
        if (target == PileType.Foundation && source != PileType.Foundation)
            popup = new CardPointPopup(anchorCard.Id, $"+{10 * cardCount}");
        else if (source == PileType.Foundation && target != PileType.Foundation)
            popup = new CardPointPopup(anchorCard.Id, $"-{15 * cardCount}");
        else
            popup = null;

        if (popup != null) ShowPointPopup(popup);
    }

    // Auto-clears after ~1s via a generation counter, same stale-callback guard the
    // game/autocomplete timers above use via _syncContext to marshal onto the UI thread.
    private void ShowPointPopup(CardPointPopup popup)
    {
        _pointPopupGeneration++;
        int generation = _pointPopupGeneration;
        PointPopup = popup;

        _pointPopupTimer?.Dispose();
        _pointPopupTimer = new System.Threading.Timer(_ =>
        {
            _syncContext?.Post(_ =>
            {
                if (_pointPopupGeneration == generation) PointPopup = null;
            }, null);
        }, null, 1000, Timeout.Infinite);
    }

    // MARK: - Victory

    private void CheckVictory()
    {
        if (_foundationCardCount == ExpectedCards && !State.HasWon)
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
            stats.FreecellStatsByMode[ModeKey] = ms;
            StatsService.SaveStats(stats);
            Stats = stats;
            CheckWinMilestones();
        }
    }

    // Resets only the current deck-count/scoring-mode bucket, leaving Klondike's and
    // Spider's data (and Freecell's other buckets) untouched.
    public void ResetStats()
    {
        var stats = StatsService.LoadStats();
        stats.FreecellStatsByMode[ModeKey] = new ModeStats();
        StatsService.SaveStats(stats);
        Stats = stats;
    }

    // MARK: - Autocomplete

    private void CheckAutocomplete()
    {
        if (State.HasWon) { IsAutocompletable = false; return; }
        IsAutocompletable = SimulateAutocomplete();
    }

    // A card of rank R is safe to auto-play to its foundation only if both opposite-colour
    // suits already have at least rank R-2 on their foundations (Aces/2s are always safe) —
    // otherwise the auto-play could strand a lower opposite-colour card that's needed later.
    // In 2-deck mode a suit can have more than one foundation (one per physical Ace), so
    // this takes the MINIMUM rank across all of that suit's foundations (0 if none started
    // yet) — the conservative choice, since being unsafe about the least-advanced copy is
    // what actually protects a card that might still be needed on the tableau.
    private static bool IsSafeToAutoplay(Card card, Dictionary<CardSuit, List<int>> foundationRanks)
    {
        if (card.Rank <= 2) return true;
        var oppositeSuits = IsRed(card.Suit)
            ? new[] { CardSuit.Spades, CardSuit.Clubs }
            : new[] { CardSuit.Hearts, CardSuit.Diamonds };
        return oppositeSuits.All(s =>
        {
            var list = foundationRanks[s];
            int min = list.Count == 0 ? 0 : list.Min();
            return min >= card.Rank - 2;
        });
    }

    // Tracks each foundation's own top rank, grouped by suit — a plain per-suit scalar
    // collapses to one value when 2-deck mode has two independent same-suit foundations,
    // silently overwriting whichever was enumerated first and making autocomplete
    // eligibility checks wrong for the "shadowed" foundation.
    private Dictionary<CardSuit, List<int>> LiveFoundationRanks()
    {
        var ranks = new Dictionary<CardSuit, List<int>>
        {
            [CardSuit.Spades] = new(), [CardSuit.Hearts] = new(), [CardSuit.Diamonds] = new(), [CardSuit.Clubs] = new()
        };
        foreach (var f in Foundations)
            if (f.Cards.Count > 0) ranks[f.Cards[0].Suit].Add(f.Cards.Count);

        // In 2-deck mode each suit can have up to Options.FreecellDeckCount separate
        // foundations (one per physical Ace). Only recording a rank for foundations that
        // have actually been started left a suit with one advanced copy and one
        // untouched duplicate reporting just [advancedRank] — Min() then ignored the
        // unstarted duplicate entirely instead of correctly treating it as rank 0, letting
        // IsSafeToAutoplay judge a card safe when the still-unstarted duplicate foundation
        // means it isn't. Pad every suit up to the full deck count with 0s so an unstarted
        // copy always pulls the minimum back down to 0.
        foreach (var suit in ranks.Keys.ToList())
            while (ranks[suit].Count < Options.FreecellDeckCount)
                ranks[suit].Add(0);

        return ranks;
    }

    // An Ace can only start a genuinely empty foundation (never join a same-suit one, which
    // by definition already has a card on it), so Ace eligibility is tracked separately via
    // a shared empty-foundation count rather than the per-suit rank lists.
    private static bool HasFoundationFor(Dictionary<CardSuit, List<int>> ranks, int emptyFoundations, Card card) =>
        card.Rank == 1 ? emptyFoundations > 0 : ranks[card.Suit].Contains(card.Rank - 1);

    private static void ApplyFoundationMove(Dictionary<CardSuit, List<int>> ranks, ref int emptyFoundations, Card card)
    {
        if (card.Rank == 1)
        {
            emptyFoundations--;
            ranks[card.Suit].Add(1);
        }
        else
        {
            ranks[card.Suit].Remove(card.Rank - 1);
            ranks[card.Suit].Add(card.Rank);
        }
    }

    // Dry-run the safe-move strategy Autocomplete() uses (free cells first, then tableau
    // columns, applying the safe-move filter) against copies of the pile contents, without
    // mutating real state. Only counts as available if it can fully clear the board.
    private bool SimulateAutocomplete()
    {
        var tableauCopies    = Tableaus.Select(t => new List<Card>(t.Cards)).ToList();
        var freeCellCopies   = FreeCells.Select(f => new List<Card>(f.Cards)).ToList();
        var foundationRanks  = LiveFoundationRanks();
        int emptyFoundations = Foundations.Count(f => f.Cards.Count == 0);

        bool movedAny = true;
        while (movedAny)
        {
            movedAny = false;

            foreach (var cell in freeCellCopies)
            {
                if (cell.Count == 0) continue;
                var card = cell[^1];
                if (!HasFoundationFor(foundationRanks, emptyFoundations, card) || !IsSafeToAutoplay(card, foundationRanks)) continue;
                ApplyFoundationMove(foundationRanks, ref emptyFoundations, card);
                cell.RemoveAt(cell.Count - 1);
                movedAny = true;
            }

            foreach (var tab in tableauCopies)
            {
                if (tab.Count == 0) continue;
                var card = tab[^1];
                if (!HasFoundationFor(foundationRanks, emptyFoundations, card) || !IsSafeToAutoplay(card, foundationRanks)) continue;
                ApplyFoundationMove(foundationRanks, ref emptyFoundations, card);
                tab.RemoveAt(tab.Count - 1);
                movedAny = true;
            }
        }

        return tableauCopies.All(t => t.Count == 0) && freeCellCopies.All(c => c.Count == 0);
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
            MoveCards(new List<Card> { move.Value.Card }, move.Value.Source, move.Value.Foundation);
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

    // Free cells first (left to right), then tableau columns (left to right),
    // applying the safe-move filter to every candidate.
    private (Card Card, Pile Source, Pile Foundation)? FindNextFoundationMove()
    {
        var ranks = LiveFoundationRanks();

        foreach (var cell in FreeCells)
        {
            if (cell.Cards.Count == 0) continue;
            var card = cell.Cards.Last();
            var foundation = Foundations.FirstOrDefault(f => CanMoveCards(new List<Card> { card }, f));
            if (foundation != null && IsSafeToAutoplay(card, ranks))
                return (card, cell, foundation);
        }

        foreach (var tab in Tableaus)
        {
            if (tab.Cards.Count == 0) continue;
            var card = tab.Cards.Last();
            var foundation = Foundations.FirstOrDefault(f => CanMoveCards(new List<Card> { card }, f));
            if (foundation != null && IsSafeToAutoplay(card, ranks))
                return (card, tab, foundation);
        }

        return null;
    }

    // MARK: - Dead-end detection

    private void CheckDeadlock()
    {
        if (State.HasWon || IsAutocompletable) { HasNoMoves = false; return; }
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
                bool targetEmpty = tgt.Cards.Count == 0;
                if (MoveSequenceHelper.AnySuffixMoves(seq, s => CanMoveCards(s, tgt),
                        len => targetEmpty && len == src.Cards.Count)) // pointless: relocates the whole column, unchanged
                    return true;
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

    // Public so the view can clear the hint when its on-screen timer expires (auto-dismiss),
    // and when a move/undo happens — matching the rule that the next Hint press starts fresh.
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

    // In 2-deck mode a suit can have more than one foundation (one per physical Ace); a
    // still-unstarted duplicate must count as rank 0, not be skipped, or a card could be
    // deemed safe while an untouched copy of that opposite-colour suit hasn't even begun.
    // LiveFoundationRanks() already pads for this (see its comment) — reuse it here instead
    // of hand-counting foundations directly.
    private bool IsSafeFoundationMove(Card card)
    {
        if (card.Rank <= 2) return true;
        int reqRank = card.Rank - 1;
        var ranks = LiveFoundationRanks();
        var oppositeSuits = IsRed(card.Suit)
            ? new[] { CardSuit.Spades, CardSuit.Clubs }
            : new[] { CardSuit.Hearts, CardSuit.Diamonds };
        return oppositeSuits.All(s => ranks[s].Min() >= reqRank);
    }

    private GameStateSnapshot CreateVirtualSnapshot()
    {
        var snapshot = new GameStateSnapshot();
        foreach (var f in Foundations) snapshot.PileCards.Add(f.Cards.ToList());
        foreach (var t in Tableaus) snapshot.PileCards.Add(t.Cards.ToList());
        foreach (var c in FreeCells) snapshot.PileCards.Add(c.Cards.ToList());
        return snapshot;
    }

    private void RestoreVirtualSnapshot(GameStateSnapshot snapshot)
    {
        int index = 0;
        for (int i = 0; i < Foundations.Count; i++)
        {
            Foundations[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) Foundations[i].Cards.Add(c);
            index++;
        }
        for (int i = 0; i < Tableaus.Count; i++)
        {
            Tableaus[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) Tableaus[i].Cards.Add(c);
            index++;
        }
        for (int i = 0; i < FreeCells.Count; i++)
        {
            FreeCells[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) FreeCells[i].Cards.Add(c);
            index++;
        }
    }

    private List<(int Score, HintMove Hint)> EvaluateImmediateMoves(int depth = 0)
    {
        var scored = new List<(int Score, HintMove Hint)>();

        // Priority 1 (1000): free cell → Foundation, or tableau top → Foundation
        foreach (var cell in FreeCells)
        {
            if (cell.Cards.Count == 0) continue;
            var card = cell.Cards.Last();
            foreach (var f in Foundations)
                if (CanMoveCards(new List<Card> { card }, f))
                {
                    int score = IsSafeFoundationMove(card) ? 1000 : 200;
                    scored.Add((score, new HintMove(card, cell.Id, f.Id,
                        $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} from Free Cell to Foundation.")));
                }
        }

        foreach (var tab in Tableaus)
        {
            if (tab.Cards.Count == 0) continue;
            var card = tab.Cards.Last();
            foreach (var f in Foundations)
                if (CanMoveCards(new List<Card> { card }, f))
                {
                    int score = IsSafeFoundationMove(card) ? 1000 : 200;
                    scored.Add((score, new HintMove(card, tab.Id, f.Id,
                        $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} to Foundation.")));
                }
        }

        // Priority 2 (700, empties source) / Priority 3 (400 + length×20): tableau → tableau
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var maxSeq = GetMovableSequence(src);

            foreach (var tgt in Tableaus)
            {
                if (tgt.Id == src.Id) continue;

                for (int len = maxSeq.Count; len >= 1; len--)
                {
                    var subSeq = maxSeq.GetRange(maxSeq.Count - len, len);
                    if (!CanMoveCards(subSeq, tgt)) continue;

                    bool emptiesSource = len == src.Cards.Count;
                    // Must match HasAnyLegalMoves' AnySuffixMoves skip predicate exactly —
                    // moving the whole column onto an empty target just relocates which
                    // column is empty, no real progress. If that were the only tableau move
                    // on the board, offering it as a hint would contradict a correctly
                    // declared deadlock.
                    bool isPointlessEmptyToEmpty = emptiesSource && tgt.Cards.Count == 0;
                    if (isPointlessEmptyToEmpty) continue;

                    int score = emptiesSource ? 700 : 400 + len * 20;
                    scored.Add((score, new HintMove(subSeq[0], src.Id, tgt.Id,
                        $"Move {RankStr(subSeq[0].Rank)}{SuitStr(subSeq[0].Suit)} sequence.")));
                    break;
                }
            }
        }

        // Priority 4 (500): free cell → tableau
        foreach (var cell in FreeCells)
        {
            if (cell.Cards.Count == 0) continue;
            var card = cell.Cards.Last();
            foreach (var tgt in Tableaus)
                if (CanMoveCards(new List<Card> { card }, tgt))
                    scored.Add((500, new HintMove(card, cell.Id, tgt.Id,
                        $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} from Free Cell to Tableau.")));
        }

        // Priority 5 (100): tableau top → free cell
        foreach (var src in Tableaus)
        {
            if (src.Cards.Count == 0) continue;
            var card = src.Cards.Last();
            foreach (var cell in FreeCells)
            {
                if (CanMoveCards(new List<Card> { card }, cell))
                {
                    scored.Add((100, new HintMove(card, src.Id, cell.Id,
                        $"Move {RankStr(card.Rank)}{SuitStr(card.Suit)} to Free Cell.")));
                    break;
                }
            }
        }

        if (depth == 0)
        {
            var enhancedScores = new List<(int Score, HintMove Hint)>();
            var originalState = CreateVirtualSnapshot();
            
            foreach (var (baseScore, move) in scored)
            {
                bool validSource = false;
                List<Card> dragStack = new();
                
                var srcCell = FreeCells.FirstOrDefault(c => c.Id == move.SourcePileId);
                if (srcCell != null)
                {
                    if (srcCell.Cards.Count > 0 && srcCell.Cards.Last().Id == move.Card.Id)
                    {
                        dragStack.Add(srcCell.Cards.Last());
                        srcCell.Cards.RemoveAt(srcCell.Cards.Count - 1);
                        validSource = true;
                    }
                }
                else
                {
                    var srcCol = Tableaus.FirstOrDefault(t => t.Id == move.SourcePileId);
                    if (srcCol != null)
                    {
                        int cardIdx = srcCol.Cards.FindIndex(c => c.Id == move.Card.Id);
                        if (cardIdx >= 0)
                        {
                            dragStack = srcCol.Cards.GetRange(cardIdx, srcCol.Cards.Count - cardIdx);
                            srcCol.Cards.RemoveRange(cardIdx, dragStack.Count);
                            validSource = true;
                        }
                    }
                }
                
                if (!validSource)
                {
                    enhancedScores.Add((baseScore, move));
                    RestoreVirtualSnapshot(originalState);
                    continue;
                }
                
                var tgtCol = Tableaus.FirstOrDefault(t => t.Id == move.TargetPileId);
                if (tgtCol != null)
                {
                    tgtCol.Cards.AddRange(dragStack);
                }
                else
                {
                    var tgtFnd = Foundations.FirstOrDefault(f => f.Id == move.TargetPileId);
                    if (tgtFnd != null)
                    {
                        tgtFnd.Cards.AddRange(dragStack);
                    }
                    else
                    {
                        var tgtCell = FreeCells.FirstOrDefault(c => c.Id == move.TargetPileId);
                        if (tgtCell != null)
                        {
                            tgtCell.Cards.AddRange(dragStack);
                        }
                    }
                }
                
                var nextLevel = EvaluateImmediateMoves(1);
                if (nextLevel.Count > 0)
                {
                    int bestNextScore = nextLevel.Max(x => x.Score);
                    int futureScore = (int)(bestNextScore * 0.8);
                    enhancedScores.Add((baseScore + futureScore, move));
                }
                else
                {
                    enhancedScores.Add((baseScore, move));
                }
                
                RestoreVirtualSnapshot(originalState);
            }
            scored = enhancedScores;
        }

        return scored;
    }

    private List<HintMove> CollectAllHints()
    {
        var scored = EvaluateImmediateMoves(0);
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
                result.Add(upper);
            else
                break;
        }
        result.Reverse();
        return result;
    }

    // MARK: - Undo

    [RelayCommand]
    public void Undo()
    {
        if (_undoStack.Count == 0 || State.HasWon) return;
        RestoreSnapshot(_undoStack.Pop());
        ClearHintCycle();
        PointPopup = null;
        _lastMoveSourcePileId = null;
        _lastMoveTargetPileId = null;
        CheckDeadlock();

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
        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
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
        OnPropertyChanged(nameof(MovesCount));
        // TimerSeconds deliberately NOT restored — the timer must keep running forward
        // through an undo, not rewind to whatever it read when the undone move's
        // snapshot was saved (matches Mac's BeecellViewModel.undoLastAction()).
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
        _foundationCardCount = Foundations.Sum(f => f.Cards.Count);
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
