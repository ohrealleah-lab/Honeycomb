using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;
using static SoliBee.Tests.Cards;

namespace SoliBee.Tests.ViewModels;

// Player-visible Freecell (Beecell on Mac) behaviour on hand-built boards (ported from
// Mac's BeecellGameplayTests): the deal, the supermove limit and what each pile accepts,
// exact scoring, winning in 1 and 2 decks, stats/streaks per deck count, "stuck",
// Autocomplete and its safety rule, hints, undo/restart, banners and No Stress Mode. Only
// "a freshly dealt game" tests use a random deal. Mac's keyboard and double-click tests
// have no Windows view-model equivalent (those live in the Desktop view), and hint wording
// isn't shown on Windows, so hints are checked by the move they point at.
public class FreecellGameplayTests : DataSandbox
{
    private const string OneDeck = "standard_1deck";
    private const string TwoDeck = "standard_2deck";

    public FreecellGameplayTests()
    {
        Options.FreecellDeckCount = 1;
    }

    // A fresh install: no saved stats for any solitaire game.
    private static FreecellViewModel Fresh()
    {
        Delete("stats.json");
        return new FreecellViewModel();
    }

    private static ModeStats Mode(string key = OneDeck) =>
        StatsService.LoadStats().FreecellStatsByMode.GetValueOrDefault(key) ?? new ModeStats();

    private static void Prime(string key, ModeStats stats)
    {
        var all = StatsService.LoadStats();
        all.FreecellStatsByMode[key] = stats;
        StatsService.SaveStats(all);
    }

    private static FreecellViewModel PrimedStreak(int streak)
    {
        Delete("stats.json");
        Prime(OneDeck, new ModeStats { GamesPlayed = 5, CurrentStreak = streak, LongestStreak = streak });
        return new FreecellViewModel();
    }

    private void SetDecks(FreecellViewModel vm, int decks)
    {
        Options.FreecellDeckCount = decks;
        vm.InitializeGame();
    }

    // Replaces the dealt game with a hand-built board sized for the current deck count:
    // `tableau` fills columns 0… in order (bottom card first), `cells` puts one card in
    // each free cell in turn, `found` fills the foundations in order.
    private static void Board(FreecellViewModel vm, List<List<Card>>? tableau = null, List<Card>? cells = null,
        List<List<Card>>? found = null)
    {
        for (int i = 0; i < vm.Tableaus.Count; i++)
        {
            vm.Tableaus[i].Cards.Clear();
            if (tableau != null && i < tableau.Count) vm.Tableaus[i].Cards.AddRange(tableau[i]);
        }
        for (int i = 0; i < vm.FreeCells.Count; i++)
        {
            vm.FreeCells[i].Cards.Clear();
            if (cells != null && i < cells.Count) vm.FreeCells[i].Cards.Add(cells[i]);
        }
        for (int i = 0; i < vm.Foundations.Count; i++)
        {
            vm.Foundations[i].Cards.Clear();
            if (found != null && i < found.Count) vm.Foundations[i].Cards.AddRange(found[i]);
        }
        Reflect.Set(vm, "_foundationCardCount", vm.Foundations.Sum(f => f.Cards.Count));
        Reflect.Set(vm, "_lastMoveSourcePileId", null);
        Reflect.Set(vm, "_lastMoveTargetPileId", null);
        var undo = Reflect.Get<object>(vm, "_undoStack");
        undo.GetType().GetMethod("Clear")!.Invoke(undo, null);
        vm.State.Score = 0;
        vm.State.MovesCount = 0;
        vm.State.TimerSeconds = 0;
        vm.State.IsTimerActive = false;
        vm.State.HasWon = false;
        vm.HasNoMoves = false;
        vm.IsAutocompletable = false;
        vm.PointPopup = null;
        vm.ClearHintCycle();
    }

    private static List<Card> L(params Card[] cards) => cards.ToList();

    // Single cards that can't take or give anything to each other (kings and nines): keeps
    // every column occupied without creating extra legal moves among themselves.
    private static List<List<Card>> Fillers(int count)
    {
        CardSuit[] suits = { CardSuit.Diamonds, CardSuit.Hearts, CardSuit.Clubs, CardSuit.Spades };
        return Enumerable.Range(0, count).Select(i => L(C(suits[i % 4], i % 8 < 4 ? 13 : 9))).ToList();
    }

    // Up to four lone kings — columns that can never move anywhere. The rest stay empty.
    private static List<List<Card>> Kings(int count) => Fillers(4).Take(count).ToList();

    private static List<List<Card>> Join(List<List<Card>> first, List<List<Card>> second) =>
        first.Concat(second).ToList();

    // Foundations holding all of one suit: spades through `spades`, the others complete.
    private static List<List<Card>> NearlyDone(int spades) => new()
    {
        Ascending(CardSuit.Spades, spades), Ascending(CardSuit.Clubs, 13),
        Ascending(CardSuit.Diamonds, 13), Ascending(CardSuit.Hearts, 13),
    };

    private static void Move(FreecellViewModel vm, Pile from, Pile to, int count = 1) =>
        vm.MoveCards(from.Cards.TakeLast(count).ToList(), from, to);

    // 8 columns where nothing can move and all 4 cells are full — a genuinely stuck game.
    private static void StuckBoard(FreecellViewModel vm, bool withFoundation = false, int cellsFilled = 4)
    {
        Board(vm,
            tableau: new()
            {
                L(C(CardSuit.Spades, 13)), L(C(CardSuit.Hearts, 13)), L(C(CardSuit.Diamonds, 13)),
                L(C(CardSuit.Clubs, 13)), L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Clubs, 9)),
                L(C(CardSuit.Spades, 9)), L(C(CardSuit.Diamonds, 9)),
            },
            cells: new[] { C(CardSuit.Spades, 7), C(CardSuit.Hearts, 7), C(CardSuit.Diamonds, 7), C(CardSuit.Clubs, 7) }
                .Take(cellsFilled).ToList(),
            found: withFoundation ? new() { Ascending(CardSuit.Spades, 4) } : null);
    }

    private static int MaxMove(FreecellViewModel vm, bool toEmptyTableau) =>
        (int)Reflect.Call(vm, "MaxMoveSize", toEmptyTableau)!;

    private static void CheckDeadlock(FreecellViewModel vm) => Reflect.Call(vm, "CheckDeadlock");
    private static void CheckAutocomplete(FreecellViewModel vm) => Reflect.Call(vm, "CheckAutocomplete");

    // Plays the steps the Autocomplete timer would (the timer needs a UI thread).
    private static void RunAutocompleteSteps(FreecellViewModel vm, int max = 60)
    {
        for (int i = 0; i < max && vm.IsAutoplayRunning; i++) Reflect.Call(vm, "AnimateNextAutocompleteMove");
    }

    private static List<List<string>> Layout(FreecellViewModel vm) =>
        vm.Tableaus.Select(t => t.Cards.Select(c => c.Id).ToList()).ToList();

    private static int Queued(FreecellViewModel vm) => Reflect.Get<Queue<string>>(vm, "_bannerQueue").Count;

    private static int Drain(FreecellViewModel vm)
    {
        int n = Queued(vm);
        for (int i = 0; i < n; i++) vm.AdvanceBannerQueue();
        return n;
    }

    // What Preferences does when a shared setting changes: it edits a copy, saves it and
    // broadcasts that copy.
    private void ChangeSharedOptions(System.Action<GameOptions> edit)
    {
        var copy = SettingsService.LoadOptions().Clone();
        edit(copy);
        SettingsService.SaveOptions(copy);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(copy));
    }

    // Every hint Hint would cycle through for the current board, in the order shown.
    private static List<HintMove> AllHints(FreecellViewModel vm)
    {
        vm.ClearHintCycle();
        vm.FindHint();
        var first = vm.ActiveHint!;
        var all = new List<HintMove> { first };
        for (int i = 1; i < first.Total; i++)
        {
            vm.FindHint();
            all.Add(vm.ActiveHint!);
        }
        return all;
    }

    // ── Deal ──────────────────────────────────────────────────────────────────

    [Fact]
    public void Deal_OneDeck_EightColumnsFourCellsFourFoundations_AllCardsFaceUp()
    {
        var vm = Fresh();

        Assert.Equal(8, vm.Tableaus.Count);
        Assert.Equal(4, vm.FreeCells.Count);
        Assert.Equal(4, vm.Foundations.Count);
        Assert.Equal(new[] { 7, 7, 7, 7, 6, 6, 6, 6 }, vm.Tableaus.Select(t => t.Cards.Count));
        var cards = vm.Tableaus.SelectMany(t => t.Cards).ToList();
        Assert.All(cards, c => Assert.True(c.IsFaceUp));
        Assert.Equal(52, cards.Select(c => c.Id).Distinct().Count());
        Assert.Equal(0, vm.State.Score);
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.State.IsTimerActive);   // the clock starts on the first move
        Assert.False(vm.CanUndo);
        Assert.Equal(1, Mode().GamesPlayed);
    }

    [Fact]
    public void Deal_TwoDecks_TenColumnsEightCellsEightFoundations_AndEachDeckCountKeepsItsOwnStats()
    {
        var vm = Fresh();
        SetDecks(vm, 2);

        Assert.Equal(10, vm.Tableaus.Count);
        Assert.Equal(8, vm.FreeCells.Count);
        Assert.Equal(8, vm.Foundations.Count);
        var cards = vm.Tableaus.SelectMany(t => t.Cards).ToList();
        Assert.Equal(104, cards.Count);
        Assert.Equal(104, cards.Select(c => c.Id).Distinct().Count());
        Assert.Equal(1, Mode(TwoDeck).GamesPlayed);
        Assert.Equal(1, Mode(OneDeck).GamesPlayed);   // the earlier 1-deck deal still counts there

        // Switching back deals a 1-deck game again.
        SetDecks(vm, 1);
        Assert.Equal(8, vm.Tableaus.Count);
        Assert.Equal(2, Mode(OneDeck).GamesPlayed);
        Assert.Equal(1, Mode(TwoDeck).GamesPlayed);
    }

    [Fact]
    public void DeckCount_IsRememberedAcrossARelaunch()
    {
        var vm = Fresh();
        SetDecks(vm, 2);
        SettingsService.SaveOptions(Options);
        ForgetCachedSettings();

        var relaunched = new FreecellViewModel();
        Assert.Equal(2, relaunched.Options.FreecellDeckCount);
        Assert.Equal(10, relaunched.Tableaus.Count);
    }

    [Fact]
    public void DeckCountChange_BroadcastFromSettings_DealsTheNewLayout()
    {
        var vm = Fresh();
        ChangeSharedOptions(o => o.FreecellDeckCount = 2);

        Assert.Equal(10, vm.Tableaus.Count);
        Assert.Equal(8, vm.FreeCells.Count);
        Assert.Equal(104, vm.Tableaus.Sum(t => t.Cards.Count));
    }

    [Fact]
    public void DeckCountChange_OnAPlayedGame_BreaksTheStreakOfTheDeckCountBeingLeft()
    {
        var vm = PrimedStreak(3);
        Board(vm, new() { L(C(CardSuit.Spades, 1)) });
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);

        SetDecks(vm, 2);

        Assert.Equal(0, Mode(OneDeck).CurrentStreak);    // the abandoned 1-deck game
        Assert.Equal(3, Mode(OneDeck).LongestStreak);
        Assert.Equal(0, Mode(TwoDeck).CurrentStreak);
        Assert.Equal(1, Mode(TwoDeck).GamesPlayed);
    }

    // ── Rules ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Supermove_LimitIsFreeCellsPlusOneTimesTwoPerEmptyColumn()
    {
        var vm = Fresh();
        var run5 = L(C(CardSuit.Spades, 9), C(CardSuit.Hearts, 8), C(CardSuit.Clubs, 7), C(CardSuit.Diamonds, 6), C(CardSuit.Spades, 5));
        var run6 = L(C(CardSuit.Clubs, 9), C(CardSuit.Diamonds, 8), C(CardSuit.Spades, 7), C(CardSuit.Hearts, 6),
            C(CardSuit.Clubs, 5), C(CardSuit.Diamonds, 4));
        Board(vm, Join(new() { L(C(CardSuit.Clubs, 13)).Concat(run5).ToList(), L(C(CardSuit.Hearts, 10)), run6 }, Fillers(5)));

        Assert.Equal(5, MaxMove(vm, false));   // (4 cells + 1) × 2^0 columns
        Assert.Equal(5, MaxMove(vm, true));
        Assert.True(vm.CanMoveCards(run5, vm.Tableaus[1]));    // five cards fit within the limit of five
        Assert.False(vm.CanMoveCards(run6, vm.Tableaus[1]));   // six exceed it
        vm.MoveCards(run6, vm.Tableaus[2], vm.Tableaus[1]);
        Assert.Equal(6, vm.Tableaus[2].Cards.Count);           // an over-limit move is refused
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.CanUndo);

        // Filling a cell shrinks the limit.
        Board(vm, Join(new() { L(C(CardSuit.Clubs, 13)).Concat(run5).ToList(), L(C(CardSuit.Hearts, 10)) }, Fillers(6)),
            cells: L(C(CardSuit.Spades, 2)));
        Assert.Equal(4, MaxMove(vm, false));
        Assert.False(vm.CanMoveCards(run5, vm.Tableaus[1]));
        Assert.False(vm.CanMoveCards(run5.TakeLast(4).ToList(), vm.Tableaus[1]));   // 8,7,6,5 don't go on a 10 anyway
    }

    [Fact]
    public void Supermove_AnEmptyColumnDoublesTheLimitForOtherColumnsButNotForItself()
    {
        var vm = Fresh();
        var run6 = L(C(CardSuit.Spades, 9), C(CardSuit.Hearts, 8), C(CardSuit.Clubs, 7), C(CardSuit.Diamonds, 6),
            C(CardSuit.Spades, 5), C(CardSuit.Hearts, 4));
        Board(vm, Join(new() { L(C(CardSuit.Clubs, 13)).Concat(run6).ToList(), L(C(CardSuit.Hearts, 10)) }, Fillers(5)));

        Assert.Equal(10, MaxMove(vm, false));
        Assert.Equal(5, MaxMove(vm, true));
        Assert.True(vm.CanMoveCards(run6, vm.Tableaus[1]));
        Assert.False(vm.CanMoveCards(run6, vm.Tableaus[7]));                       // the empty column itself: limit 5
        Assert.True(vm.CanMoveCards(run6.TakeLast(1).ToList(), vm.Tableaus[7]));   // any single card may start it

        vm.MoveCards(run6, vm.Tableaus[0], vm.Tableaus[1]);
        Assert.Equal(7, vm.Tableaus[1].Cards.Count);   // a legal supermove goes through as one move
        Assert.Equal(1, vm.MovesCount);
        vm.Undo();
        Assert.Equal(7, vm.Tableaus[0].Cards.Count);   // ...and is undone as one move
        Assert.Equal(1, vm.Tableaus[1].Cards.Count);
    }

    [Fact]
    public void Supermove_TwoDecksHaveEightCells()
    {
        var vm = Fresh();
        SetDecks(vm, 2);
        Board(vm, Join(new() { L(C(CardSuit.Clubs, 13)) }, Fillers(9)));

        Assert.Equal(9, MaxMove(vm, false));   // 8 cells + 1, no empty column
        Board(vm, Fillers(8));                 // two empty columns
        Assert.Equal(36, MaxMove(vm, false));  // 9 × 2²
        Assert.Equal(18, MaxMove(vm, true));   // one empty column doesn't count as spare
    }

    [Fact]
    public void PileRules_TableauCellFoundationAndStock()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Spades, 6)) }, Fillers(7)), cells: L(C(CardSuit.Hearts, 2)),
            found: new() { Ascending(CardSuit.Hearts, 3) });
        var h5 = C(CardSuit.Hearts, 5);
        var c5 = C(CardSuit.Clubs, 5);
        var d4 = C(CardSuit.Diamonds, 4);

        Assert.True(vm.CanMoveCards(L(h5), vm.Tableaus[0]));                         // red 5 on black 6
        Assert.False(vm.CanMoveCards(L(c5), vm.Tableaus[0]));                        // same colour
        Assert.False(vm.CanMoveCards(L(d4), vm.Tableaus[0]));                        // wrong rank
        Assert.False(vm.CanMoveCards(L(h5, C(CardSuit.Hearts, 4)), vm.Tableaus[0])); // not alternating
        Assert.False(vm.CanMoveCards(new List<Card>(), vm.Tableaus[0]));             // nothing to move
        Assert.False(vm.CanMoveCards(L(h5), vm.FreeCells[0]));                       // occupied cell
        Assert.True(vm.CanMoveCards(L(h5), vm.FreeCells[1]));                        // vacant cell, one card
        Assert.False(vm.CanMoveCards(L(C(CardSuit.Spades, 6), h5), vm.FreeCells[1]));
        Assert.True(vm.CanMoveCards(L(C(CardSuit.Hearts, 4)), vm.Foundations[0]));   // continues hearts
        Assert.False(vm.CanMoveCards(L(C(CardSuit.Hearts, 5)), vm.Foundations[0]));  // can't skip a rank
        Assert.False(vm.CanMoveCards(L(C(CardSuit.Spades, 4)), vm.Foundations[0]));  // wrong suit
        Assert.False(vm.CanMoveCards(L(C(CardSuit.Hearts, 4), C(CardSuit.Spades, 3)), vm.Foundations[0]));  // one at a time
        Assert.True(vm.CanMoveCards(L(C(CardSuit.Spades, 1)), vm.Foundations[1]));   // an ace starts an empty foundation
        Assert.False(vm.CanMoveCards(L(C(CardSuit.Spades, 2)), vm.Foundations[1]));  // ...only an ace
        Assert.False(vm.CanMoveCards(L(h5), new Pile("stock", PileType.Stock)));     // stock/waste take nothing
        Assert.False(vm.CanMoveCards(L(h5), new Pile("waste", PileType.Waste)));
    }

    [Fact]
    public void PileRules_AnyCardMayStartAnEmptyColumn_ButAFaceDownTopCardAcceptsNothing()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Spades, 6, up: false)) }, Fillers(6)));

        Assert.True(vm.CanMoveCards(L(C(CardSuit.Hearts, 9)), vm.Tableaus[7]));       // empty column takes any card
        Assert.False(vm.CanMoveCards(L(C(CardSuit.Hearts, 5)), vm.Tableaus[0]));      // face-down top card
    }

    [Fact]
    public void FoundationCards_CanComeBackDownToTheTableauAndCells()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Hearts, 3)) }, Fillers(7)), found: new() { Ascending(CardSuit.Spades, 2) });

        Move(vm, vm.Foundations[0], vm.Tableaus[0]);   // 2♠ onto 3♥
        Assert.Equal(2, vm.Tableaus[0].Cards.Count);
        Assert.Single(vm.Foundations[0].Cards);
        Move(vm, vm.Tableaus[0], vm.FreeCells[0]);
        Assert.Single(vm.FreeCells[0].Cards);
    }

    // ── Scoring ───────────────────────────────────────────────────────────────

    [Fact]
    public void Scoring_TableauAndCellToFoundationScoreTen_WithAPopup()
    {
        var vm = Fresh();
        var ace = C(CardSuit.Spades, 1);
        Board(vm, Join(new() { L(ace) }, Fillers(7)));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.Equal(10, vm.State.Score);
        Assert.Equal("10", vm.ScoreDisplay);
        Assert.Equal(new CardPointPopup(ace.Id, "+10"), vm.PointPopup);
        vm.Undo();
        Assert.Equal(0, vm.State.Score);   // undo takes back exactly the points, no extra penalty
        Assert.Null(vm.PointPopup);

        var aceC = C(CardSuit.Clubs, 1);
        Board(vm, Fillers(8), cells: L(aceC));
        Move(vm, vm.FreeCells[0], vm.Foundations[0]);
        Assert.Equal(10, vm.State.Score);
        Assert.Empty(vm.FreeCells[0].Cards);
        Assert.Equal(new CardPointPopup(aceC.Id, "+10"), vm.PointPopup);
    }

    [Fact]
    public void Scoring_LeavingAFoundationCostsFifteen_NeverBelowZero()
    {
        var vm = Fresh();
        var two = C(CardSuit.Spades, 2);
        Board(vm, Join(new() { L(C(CardSuit.Hearts, 3)) }, Fillers(7)), found: new() { L(C(CardSuit.Spades, 1), two) });
        vm.State.Score = 20;
        Move(vm, vm.Foundations[0], vm.Tableaus[0]);
        Assert.Equal(5, vm.State.Score);
        Assert.Equal(new CardPointPopup(two.Id, "-15"), vm.PointPopup);

        Board(vm, Fillers(8), found: new() { L(C(CardSuit.Spades, 1), two) });
        vm.State.Score = 5;
        Move(vm, vm.Foundations[0], vm.FreeCells[0]);
        Assert.Equal(0, vm.State.Score);   // 5 − 15 stops at zero
        vm.Undo();
        Assert.Equal(5, vm.State.Score);
    }

    [Fact]
    public void Scoring_ShufflingBetweenFoundationsOrIntoACell_IsFree()
    {
        var vm = Fresh();
        Board(vm, Fillers(8), found: new() { L(C(CardSuit.Spades, 1)) });
        Move(vm, vm.Foundations[0], vm.Foundations[1]);
        Assert.Equal(0, vm.State.Score);   // else an ace could be shuffled for +10 forever
        Assert.Null(vm.PointPopup);
        Assert.Equal(1, vm.MovesCount);

        var five = C(CardSuit.Hearts, 5);
        Board(vm, Join(new() { L(five) }, Fillers(7)));
        Move(vm, vm.Tableaus[0], vm.FreeCells[0]);
        Assert.Equal(0, vm.State.Score);
        Assert.Null(vm.PointPopup);
    }

    [Fact]
    public void Scoring_MultiCardFoundationMovesAreNotPossible_SoOnlyOneCardIsScoredAtATime()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Spades, 2), C(CardSuit.Hearts, 1)) }, Fillers(7)));
        vm.MoveCards(vm.Tableaus[0].Cards.ToList(), vm.Tableaus[0], vm.Foundations[0]);
        Assert.Equal(0, vm.State.Score);
        Assert.Equal(0, vm.MovesCount);
    }

    [Fact]
    public void PointPopups_OnlyInHoneyMode_ButThePointsAlwaysCount()
    {
        Options.HoneyMode = false;
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Spades, 1)) }, Fillers(7)));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.Null(vm.PointPopup);
        Assert.Equal(10, vm.State.Score);
    }

    [Fact]
    public void Undo_StepsBackOneActionAtATime_KeepsTheClockRunning_AndClearsTheHint()
    {
        var vm = Fresh();
        vm.Undo();   // nothing to undo: harmless
        Assert.False(vm.CanUndo);

        var ace = C(CardSuit.Spades, 1);
        var five = C(CardSuit.Hearts, 5);
        Board(vm, Join(new() { L(ace), L(five) }, Fillers(6)));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Move(vm, vm.Tableaus[1], vm.FreeCells[0]);
        vm.State.TimerSeconds = 33;
        Assert.True(vm.CanUndo);
        Assert.Equal(2, vm.MovesCount);

        vm.FindHint();
        Assert.NotNull(vm.ActiveHint);
        vm.Undo();
        Assert.Null(vm.ActiveHint);   // a hint is stale once the board changes
        Assert.Equal(1, vm.MovesCount);
        Assert.Equal(new[] { five.Id }, vm.Tableaus[1].Cards.Select(c => c.Id));
        Assert.Equal(33, vm.State.TimerSeconds);   // the clock isn't rewound
        Assert.True(vm.State.IsTimerActive);

        vm.Undo();
        Assert.Equal(0, vm.MovesCount);
        Assert.Equal(0, vm.State.Score);
        Assert.Equal(new[] { ace.Id }, vm.Tableaus[0].Cards.Select(c => c.Id));
        Assert.False(vm.CanUndo);
    }

    [Fact]
    public void Display_ShowsClockScoreAndMoves()
    {
        var vm = Fresh();
        Assert.Equal("00:00", vm.TimeDisplay);
        vm.State.TimerSeconds = 75;
        Assert.Equal("01:15", vm.TimeDisplay);
        vm.State.Score = 40;
        Assert.Equal("40", vm.ScoreDisplay);
    }

    // ── Winning & stats ───────────────────────────────────────────────────────

    [Fact]
    public void Win_AllFiftyTwoOnTheFoundations_RecordsStats_StopsTheClock_AndLocksUndo()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        vm.State.TimerSeconds = 60;

        Move(vm, vm.Tableaus[0], vm.Foundations[0]);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.State.IsTimerActive);
        var s = Mode();
        Assert.Equal(1, s.GamesWon);
        Assert.Equal(1, s.CurrentStreak);
        Assert.Equal(1, s.LongestStreak);
        Assert.Equal(60, s.ShortestWinSeconds);
        Assert.Equal(60, s.TotalWinSeconds);
        Assert.Equal(1, s.TimedGamesWon);
        Assert.Equal(10, s.HighScore);
        Assert.False(vm.CanUndo);
        vm.Undo();
        Assert.True(vm.State.HasWon);   // a won game can't be reopened

        // Saved: a relaunch still sees the win.
        var relaunched = new FreecellViewModel();
        Assert.Equal(1, Mode().GamesWon);
        Assert.Equal(60, Mode().ShortestWinSeconds);
        Assert.Equal(1, relaunched.Stats.FreecellStatsByMode[OneDeck].GamesWon);
    }

    [Fact]
    public void Win_FasterTimeReplacesTheFastestWin_SlowerOneDoesNot_AndAHigherHighScoreIsKept()
    {
        var vm = Fresh();
        Prime(OneDeck, new ModeStats { GamesPlayed = 3, GamesWon = 2, TimedGamesWon = 2, ShortestWinSeconds = 50, TotalWinSeconds = 130, HighScore = 700 });
        vm.InitializeGame();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        vm.State.TimerSeconds = 80;
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        var s = Mode();
        Assert.Equal(50, s.ShortestWinSeconds);   // 80 s isn't faster
        Assert.Equal(210, s.TotalWinSeconds);
        Assert.Equal(3, s.TimedGamesWon);
        Assert.Equal(700, s.HighScore);

        vm.InitializeGame();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        vm.State.TimerSeconds = 30;
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.Equal(30, Mode().ShortestWinSeconds);
    }

    [Fact]
    public void Win_TwoDecksNeedAll104_AndOnlyCountInTheTwoDeckStats()
    {
        var vm = Fresh();
        SetDecks(vm, 2);
        CardSuit[] suits = { CardSuit.Spades, CardSuit.Clubs, CardSuit.Diamonds, CardSuit.Hearts,
                             CardSuit.Spades, CardSuit.Clubs, CardSuit.Diamonds, CardSuit.Hearts };

        // 103 of 104 is not a win.
        Board(vm, new() { L(C(CardSuit.Spades, 13)), L(C(CardSuit.Clubs, 13)) },
            found: suits.Select((s, i) => Ascending(s, i < 2 ? 12 : 13)).ToList());
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.False(vm.State.HasWon);
        Assert.Equal(0, Mode(TwoDeck).GamesWon);

        Board(vm, new() { L(C(CardSuit.Spades, 13)) },
            found: suits.Select((s, i) => Ascending(s, i == 0 ? 12 : 13)).ToList());
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.True(vm.State.HasWon);
        Assert.Equal(1, Mode(TwoDeck).GamesWon);
        Assert.Equal(0, Mode(OneDeck).GamesWon);
    }

    [Fact]
    public void Win_InNoStressMode_CountsButRecordsNoTime()
    {
        Options.IsNoStressMode = true;
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.State.IsTimerActive);   // no clock in No Stress Mode
        var s = Mode();
        Assert.Equal(1, s.GamesWon);
        Assert.Equal(0, s.TimedGamesWon);
        Assert.Equal(0, s.TotalWinSeconds);
        Assert.Equal(0, s.ShortestWinSeconds);
    }

    [Fact]
    public void TogglingNoStressMidGame_StopsAndRestartsTheClock_AndRecordsNoBestTimeForThatGame()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Spades, 13)), L(C(CardSuit.Hearts, 5)) }, Fillers(6)), found: NearlyDone(12));
        Move(vm, vm.Tableaus[1], vm.FreeCells[0]);
        Assert.True(vm.State.IsTimerActive);   // the first move starts the clock
        vm.State.TimerSeconds = 40;

        ChangeSharedOptions(o => o.IsNoStressMode = true);
        Assert.False(vm.State.IsTimerActive);
        Assert.Equal(0, vm.State.TimerSeconds);   // the elapsed time is dropped too
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.True(vm.State.IsTimerActive);      // back off: the clock resumes right away

        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.True(vm.State.HasWon);
        Assert.Equal(1, Mode().GamesWon);
        Assert.Equal(0, Mode().TimedGamesWon);    // a part-untimed win records no time
        Assert.Equal(0, Mode().ShortestWinSeconds);
    }

    [Fact]
    public void TogglingNoStress_BeforeTheFirstMove_NeverStartsTheClock()
    {
        var vm = Fresh();
        ChangeSharedOptions(o => o.IsNoStressMode = true);
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.False(vm.State.IsTimerActive);
    }

    [Fact]
    public void SwitchingGames_PausesAndResumesARunningClockOnly()
    {
        var vm = Fresh();
        vm.PauseTimerForSwitch();
        vm.ResumeTimerForSwitch();
        Assert.False(vm.State.IsTimerActive);   // an unstarted game stays unstarted

        Board(vm, Join(new() { L(C(CardSuit.Hearts, 5)) }, Fillers(7)));
        Move(vm, vm.Tableaus[0], vm.FreeCells[0]);
        Assert.True(vm.State.IsTimerActive);
        vm.PauseTimerForSwitch();
        Assert.False(vm.State.IsTimerActive);
        vm.ResumeTimerForSwitch();
        Assert.True(vm.State.IsTimerActive);
    }

    [Fact]
    public void ResetStats_ClearsOnlyTheCurrentDeckCount_AndNoOtherGame()
    {
        var vm = Fresh();
        Prime(OneDeck, new ModeStats { GamesPlayed = 4, GamesWon = 2 });
        Prime(TwoDeck, new ModeStats { GamesPlayed = 3, GamesWon = 1 });
        var all = StatsService.LoadStats();
        all.SpiderStatsBySuit["1"] = new ModeStats { GamesPlayed = 9, GamesWon = 9 };
        StatsService.SaveStats(all);

        vm.ResetStats();

        Assert.Equal(0, Mode(OneDeck).GamesPlayed);
        Assert.Equal(0, Mode(OneDeck).GamesWon);
        Assert.Equal(3, Mode(TwoDeck).GamesPlayed);
        Assert.Equal(9, StatsService.LoadStats().SpiderStatsBySuit["1"].GamesWon);
    }

    // ── Streaks & restart ─────────────────────────────────────────────────────

    private static void OneMove(FreecellViewModel vm)
    {
        Board(vm, Join(new() { L(C(CardSuit.Spades, 1)) }, Fillers(7)));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
    }

    [Fact]
    public void Streak_NewGameBeforeMoving_KeepsIt()
    {
        var vm = PrimedStreak(3);
        vm.InitializeGame();
        Assert.Equal(3, Mode().CurrentStreak);
    }

    [Fact]
    public void Streak_AbandoningAPlayedGame_BreaksIt_EvenAfterUndoOrRestart()
    {
        var played = PrimedStreak(3);
        OneMove(played);
        played.InitializeGame();
        Assert.Equal(0, Mode().CurrentStreak);
        Assert.Equal(3, Mode().LongestStreak);

        var undone = PrimedStreak(3);
        OneMove(undone);
        undone.Undo();
        undone.InitializeGame();
        Assert.Equal(0, Mode().CurrentStreak);   // undoing to the start can't dodge it

        var restarted = PrimedStreak(3);
        restarted.MoveCards(restarted.Tableaus[0].Cards.TakeLast(1).ToList(), restarted.Tableaus[0], restarted.FreeCells[0]);
        restarted.RestartGame();
        restarted.InitializeGame();
        Assert.Equal(0, Mode().CurrentStreak);   // nor can restarting
    }

    [Fact]
    public void Streak_StartingANewGameAfterAWin_KeepsIt()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        int played = Mode().GamesPlayed;

        vm.InitializeGame();
        Assert.Equal(1, Mode().CurrentStreak);   // a won game isn't abandoned
        Assert.Equal(played + 1, Mode().GamesPlayed);
    }

    [Fact]
    public void Restart_ReplaysTheSameDeal_AndOnlyAWonGameCountsAsAnotherGamePlayed()
    {
        var vm = Fresh();
        var deal = Layout(vm);
        int played = Mode().GamesPlayed;

        vm.MoveCards(vm.Tableaus[0].Cards.TakeLast(1).ToList(), vm.Tableaus[0], vm.FreeCells[0]);
        vm.State.TimerSeconds = 12;
        Assert.True(vm.State.IsTimerActive);
        vm.RestartGame();
        Assert.Equal(deal, Layout(vm));
        Assert.All(vm.FreeCells, f => Assert.Empty(f.Cards));
        Assert.Equal(0, vm.MovesCount);
        Assert.Equal(0, vm.State.Score);
        Assert.False(vm.CanUndo);
        Assert.False(vm.State.IsTimerActive);   // the clock starts again on the next move
        Assert.Equal(played, Mode().GamesPlayed);

        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.True(vm.State.HasWon);
        vm.RestartGame();
        Assert.False(vm.State.HasWon);
        Assert.Equal(deal, Layout(vm));
        Assert.Equal(played + 1, Mode().GamesPlayed);   // replaying a won deal is a new game played
        Assert.Equal(1, Mode().CurrentStreak);
        vm.RestartGame();
        Assert.Equal(played + 1, Mode().GamesPlayed);   // ...but only once
    }

    [Fact]
    public void Restart_AfterAWin_CanBeWonAgain_AndThePlayAgainWinsCount()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        vm.RestartGame();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.True(vm.State.HasWon);
        Assert.Equal(2, Mode().GamesWon);
        Assert.Equal(2, Mode().GamesPlayed);
    }

    // ── Stuck ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Stuck_FullCellsAndNoLegalMove()
    {
        var vm = Fresh();
        StuckBoard(vm);
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);

        // Pulling a card back off a foundation doesn't count as a way out.
        StuckBoard(vm, withFoundation: true);
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);
    }

    [Fact]
    public void Stuck_NotWhileAnythingCanStillBePlayed()
    {
        var vm = Fresh();

        StuckBoard(vm, cellsFilled: 3);   // one open free cell is always a way forward
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);

        StuckBoard(vm);
        vm.Tableaus[5].Cards.Clear();
        vm.Tableaus[5].Cards.Add(C(CardSuit.Clubs, 6));   // 5♥ can now go on it
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);

        // A card in a full set of cells can still go to an empty column.
        Board(vm, new() { L(C(CardSuit.Spades, 13)) },
            cells: L(C(CardSuit.Spades, 7), C(CardSuit.Hearts, 7), C(CardSuit.Diamonds, 7), C(CardSuit.Clubs, 7)));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);

        // A cell card that can go straight to a foundation.
        StuckBoard(vm);
        vm.FreeCells[0].Cards.Clear();
        vm.FreeCells[0].Cards.Add(C(CardSuit.Spades, 1));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);
    }

    [Fact]
    public void Stuck_AnEmptyColumnIsAWayOutOfFullCells_UntilItIsFilled()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)), L(C(CardSuit.Hearts, 13)), L(C(CardSuit.Diamonds, 13)),
                          L(C(CardSuit.Clubs, 13)), L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Clubs, 9)),
                          L(C(CardSuit.Spades, 9)) },
            cells: L(C(CardSuit.Spades, 7), C(CardSuit.Hearts, 7), C(CardSuit.Diamonds, 7), C(CardSuit.Clubs, 7)));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // a cell card can still land in the empty eighth column

        vm.Tableaus[7].Cards.Add(C(CardSuit.Diamonds, 9));   // fill it: now nothing moves
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);
    }

    [Fact]
    public void Stuck_PlayingIntoADeadEnd_RaisesTheFlag_AndUndoClearsIt()
    {
        var vm = Fresh();
        StuckBoard(vm, cellsFilled: 3);
        vm.Tableaus[0].Cards.Add(C(CardSuit.Clubs, 3));
        Move(vm, vm.Tableaus[0], vm.FreeCells[3]);   // the last cell fills with nothing left to do
        Assert.True(vm.HasNoMoves);

        vm.Undo();
        Assert.False(vm.HasNoMoves);
    }

    [Fact]
    public void Stuck_NeverOnAWonGame_OrWhileAutocompleteIsPossible()
    {
        var vm = Fresh();
        StuckBoard(vm);
        vm.State.HasWon = true;
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);

        Board(vm, new() { L(C(CardSuit.Spades, 13), C(CardSuit.Spades, 12)) }, found: NearlyDone(11));
        CheckAutocomplete(vm);
        CheckDeadlock(vm);
        Assert.True(vm.IsAutocompletable);
        Assert.False(vm.HasNoMoves);
    }

    // ── Autocomplete ──────────────────────────────────────────────────────────

    [Fact]
    public void Autocomplete_PlaysTheGameOutToAWin_ScoringEachCard_WithNoPopups()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13), C(CardSuit.Spades, 12)) }, found: NearlyDone(11));
        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);   // Q♠ then K♠ can go straight up

        vm.Autocomplete();
        Assert.True(vm.IsAutoplayRunning);
        Assert.True(vm.CanUndo);
        RunAutocompleteSteps(vm);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.IsAutoplayRunning);
        Assert.False(vm.IsAutocompletable);
        Assert.Equal(20, vm.State.Score);
        Assert.Equal(1, Mode().GamesWon);
        Assert.Null(vm.PointPopup);   // no popups while autoplaying
    }

    [Fact]
    public void Autocomplete_NotOfferedWhenACardIsBuried_OrNotYetSafe()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 12), C(CardSuit.Spades, 13)) }, found: NearlyDone(11));
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);   // the Q♠ is under the K♠
        vm.Autocomplete();
        Assert.False(vm.IsAutoplayRunning);   // pressing it anyway does nothing
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.CanUndo);

        // Playable but not "safe": the opposite-colour foundations are too far behind.
        Board(vm, new() { L(C(CardSuit.Spades, 12)) }, found: new() { Ascending(CardSuit.Spades, 11) });
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);
    }

    [Fact]
    public void Autocomplete_PlaysFreeCellCardsFirst()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, cells: L(C(CardSuit.Spades, 12)), found: NearlyDone(11));
        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);

        vm.Autocomplete();
        Reflect.Call(vm, "AnimateNextAutocompleteMove");
        Assert.Empty(vm.FreeCells[0].Cards);       // the cell's Q♠ went first
        Assert.Single(vm.Tableaus[0].Cards);
        RunAutocompleteSteps(vm);
        Assert.True(vm.State.HasWon);
    }

    [Fact]
    public void Autocomplete_TwoDecks_AnUntouchedDuplicateFoundationBlocksTheSafetyRule()
    {
        var vm = Fresh();
        SetDecks(vm, 2);

        // Both red suits are at 4 on both foundations: the 5♠ is safe.
        Board(vm, new() { L(C(CardSuit.Spades, 5)) },
            found: new()
            {
                Ascending(CardSuit.Spades, 4), Ascending(CardSuit.Hearts, 4), Ascending(CardSuit.Hearts, 4),
                Ascending(CardSuit.Diamonds, 4), Ascending(CardSuit.Diamonds, 4),
            });
        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);

        // One hearts foundation hasn't even started: the 5♠ isn't.
        Board(vm, new() { L(C(CardSuit.Spades, 5)) },
            found: new()
            {
                Ascending(CardSuit.Spades, 4), Ascending(CardSuit.Hearts, 4),
                Ascending(CardSuit.Diamonds, 4), Ascending(CardSuit.Diamonds, 4),
            });
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);
    }

    [Fact]
    public void Autocomplete_UndoReversesTheWholeRunInOneStep_AndAStaleTickDoesNothing()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13), C(CardSuit.Spades, 12)) }, found: NearlyDone(11));
        var start = Layout(vm);
        CheckAutocomplete(vm);
        vm.Autocomplete();
        Reflect.Call(vm, "AnimateNextAutocompleteMove");
        Assert.Single(vm.Tableaus[0].Cards);

        vm.Undo();
        Assert.False(vm.IsAutoplayRunning);
        Assert.Equal(start, Layout(vm));
        Assert.Equal(0, vm.State.Score);
        Assert.True(vm.IsAutocompletable);   // offered again

        Reflect.Call(vm, "AnimateNextAutocompleteMove");   // a tick that was already in flight
        Assert.Equal(start, Layout(vm));
    }

    [Fact]
    public void Undo_BeforeAWinningMove_ThenWinning_StillCountsEveryFoundationCard()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)), L(C(CardSuit.Spades, 12)) }, found: NearlyDone(11));
        Move(vm, vm.Tableaus[1], vm.Foundations[0]);
        vm.Undo();
        Move(vm, vm.Tableaus[1], vm.Foundations[0]);
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.True(vm.State.HasWon);
        Assert.Equal(1, Mode().GamesWon);
    }

    // ── Hints ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Hint_PointsAtAFoundationMove_FromTableauOrCell()
    {
        var vm = Fresh();
        var two = C(CardSuit.Spades, 2);
        Board(vm, Join(new() { L(two) }, Kings(3)), found: new() { L(C(CardSuit.Spades, 1)) });
        var hints = AllHints(vm);
        Assert.Equal(two.Id, hints[0].Card.Id);
        Assert.Equal(vm.Tableaus[0].Id, hints[0].SourcePileId);
        Assert.Equal(vm.Foundations[0].Id, hints[0].TargetPileId);

        var cellTwo = C(CardSuit.Spades, 2);
        Board(vm, Kings(4), cells: L(cellTwo), found: new() { L(C(CardSuit.Spades, 1)) });
        hints = AllHints(vm);
        // (Hint looks one move ahead, so it may rank parking the card in an empty column
        // first; the foundation move must still be among the suggestions.)
        Assert.Contains(hints, h => h.Card.Id == cellTwo.Id && h.SourcePileId == vm.FreeCells[0].Id && h.TargetPileId == vm.Foundations[0].Id);
    }

    [Fact]
    public void Hint_OffersCellToTableau_AndSequenceMoves()
    {
        var vm = Fresh();
        var five = C(CardSuit.Hearts, 5);
        Board(vm, Join(new() { L(C(CardSuit.Spades, 6)) }, Kings(3)), cells: L(five));
        var hints = AllHints(vm);
        Assert.Contains(hints, h => h.Card.Id == five.Id && h.SourcePileId == vm.FreeCells[0].Id && h.TargetPileId == vm.Tableaus[0].Id);

        var nine = C(CardSuit.Clubs, 9);
        Board(vm, Join(new() { L(nine, C(CardSuit.Hearts, 8)), L(C(CardSuit.Diamonds, 10)) }, Kings(2)));
        hints = AllHints(vm);
        Assert.Contains(hints, h => h.Card.Id == nine.Id && h.SourcePileId == vm.Tableaus[0].Id && h.TargetPileId == vm.Tableaus[1].Id);
        Assert.True(hints.Count >= 2);
    }

    [Fact]
    public void Hint_CyclesInOrder_Wraps_AndAMoveClearsIt()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Clubs, 9), C(CardSuit.Hearts, 8)), L(C(CardSuit.Diamonds, 10)) }, Kings(2)));

        vm.ClearHintCycle();
        vm.FindHint();
        int total = vm.ActiveHint!.Total;
        Assert.True(total >= 2);
        Assert.Equal(1, vm.ActiveHint.Index);
        var first = vm.ActiveHint;
        vm.FindHint();
        Assert.Equal(2, vm.ActiveHint!.Index);
        for (int i = 2; i < total; i++) vm.FindHint();
        vm.FindHint();   // wraps back to the first
        Assert.Equal(1, vm.ActiveHint!.Index);
        Assert.Equal(first.Card.Id, vm.ActiveHint.Card.Id);
        Assert.Equal(first.TargetPileId, vm.ActiveHint.TargetPileId);

        Move(vm, vm.Tableaus[1], vm.FreeCells[0]);
        Assert.Null(vm.ActiveHint);   // a move clears it; the next press starts fresh
        vm.ClearHintCycle();
        Assert.Null(vm.ActiveHint);
    }

    [Fact]
    public void Hint_NeverSuggestsUndoingTheMoveJustMade()
    {
        var vm = Fresh();
        Board(vm, Join(new() { L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)) }, Kings(2)));
        Move(vm, vm.Tableaus[0], vm.Tableaus[1]);   // 5♥ onto 6♠ (leaves column 0 empty)
        var hints = AllHints(vm);
        Assert.DoesNotContain(hints, h => h.SourcePileId == vm.Tableaus[1].Id && h.TargetPileId == vm.Tableaus[0].Id);
        Assert.NotEmpty(hints);
    }

    [Fact]
    public void Hint_OnlyDeadColumnsAndAnOpenCell_SuggestsParkingACard_ButNeverShufflesAColumnToAnEmptyOne()
    {
        var vm = Fresh();
        Board(vm, Kings(4));
        var hints = AllHints(vm);
        Assert.Equal(4, hints.Count);
        Assert.All(hints, h => Assert.Equal(vm.FreeCells[0].Id, h.TargetPileId));
    }

    [Fact]
    public void Hint_PrefersASafeFoundationMove_ButNotAnUnsafeOneOverAGoodTableauMove()
    {
        var vm = Fresh();
        var five = C(CardSuit.Spades, 5);
        var six = C(CardSuit.Hearts, 6);

        // Hearts and diamonds still behind: the 5♠ isn't safe to send up, so 6♥ onto 7♠ comes first.
        Board(vm, Join(new() { L(five), L(C(CardSuit.Spades, 7)) }, Fillers(6)), cells: L(six),
            found: new() { Ascending(CardSuit.Spades, 4) });
        var hints = AllHints(vm);
        Assert.Equal(six.Id, hints[0].Card.Id);
        Assert.Equal(vm.Tableaus[1].Id, hints[0].TargetPileId);
        Assert.Contains(hints, h => h.Card.Id == five.Id && h.TargetPileId == vm.Foundations[0].Id);

        // With both red suits at 4 it is safe, and goes first.
        Board(vm, Join(new() { L(five), L(C(CardSuit.Spades, 7)) }, Fillers(6)), cells: L(six),
            found: new() { Ascending(CardSuit.Spades, 4), Ascending(CardSuit.Hearts, 4), Ascending(CardSuit.Diamonds, 4) });
        hints = AllHints(vm);
        Assert.Equal(five.Id, hints[0].Card.Id);
        Assert.Equal(vm.Foundations[0].Id, hints[0].TargetPileId);
    }

    [Fact]
    public void Hint_OnAStuckBoard_SaysThereIsNothingToDo_AndANewGameClearsIt()
    {
        var vm = Fresh();
        StuckBoard(vm);
        vm.ClearHintCycle();
        vm.FindHint();
        Assert.NotNull(vm.ActiveHint);
        Assert.Equal("", vm.ActiveHint!.SourcePileId);   // not a real move
        Assert.Equal("", vm.ActiveHint.TargetPileId);

        vm.InitializeGame();
        Assert.Null(vm.ActiveHint);
    }

    [Fact]
    public void Hint_OnAnyDealtGame_FindsALegalMove()
    {
        var vm = Fresh();
        vm.FindHint();
        Assert.NotNull(vm.ActiveHint);
        Assert.True(vm.ActiveHint!.Total >= 1);
    }

    // ── Banners ───────────────────────────────────────────────────────────────

    [Fact]
    public void Banners_FirstGameWelcome_LoadingOnce()
    {
        var vm = Fresh();
        Assert.Equal(1, Drain(vm));   // the first game ever shows the welcome banner
        vm.InitializeGame();
        Assert.Equal(0, Drain(vm));

        vm.CheckLoadingBanner();
        Drain(vm);
        vm.CheckLoadingBanner();
        Assert.Equal(0, Drain(vm));
        vm.ScheduleIdleActionCheck();
        vm.CancelIdleActionCheck();
    }

    [Fact]
    public void Banners_TheTenthWinAcrossBothDeckCountsShowsTheMilestoneOnce()
    {
        var vm = Fresh();
        Drain(vm);
        Prime(OneDeck, new ModeStats { GamesPlayed = 7, GamesWon = 6 });
        Prime(TwoDeck, new ModeStats { GamesPlayed = 3, GamesWon = 3 });

        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);   // the 10th win
        Assert.Equal(1, Queued(vm));
        var replayed = new List<string>();
        vm.OnFlashBanner += replayed.Add;
        vm.ReplayCurrentBanner();
        Assert.Single(replayed);
        Assert.Equal(1, Drain(vm));

        vm.InitializeGame();
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: NearlyDone(12));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);   // the 11th
        Assert.Equal(0, Drain(vm));
        vm.AdvanceBannerQueue();   // empty queue: harmless
        vm.ReplayCurrentBanner();
        Assert.Single(replayed);
    }

    // ── Settings the board reacts to ──────────────────────────────────────────

    [Fact]
    public void HideBee_And_WatermarkSettings_FollowTheSharedOptions()
    {
        Options.HideBee = false;
        var vm = Fresh();
        Assert.False(vm.HideBee);
        Assert.Equal(0.15, vm.WatermarkOpacity);

        ChangeSharedOptions(o =>
        {
            o.HideBee = true;
            o.FreecellWatermarkScale = 2.0;
            o.FreecellWatermarkOffsetX = -10;
            o.FreecellWatermarkOffsetY = 5;
        });
        Assert.True(vm.HideBee);
        Assert.Equal(0.0, vm.WatermarkOpacity);   // hidden by opacity, so the board layout doesn't shift
        Assert.Equal(2.0, vm.FreecellWatermarkScale);
        Assert.Equal(-10, vm.FreecellWatermarkOffsetX);
        Assert.Equal(5, vm.FreecellWatermarkOffsetY);
    }

    [Fact]
    public void FeltColor_IsSavedAndBroadcast()
    {
        var vm = Fresh();
        var seen = new List<FeltColorTheme>();
        var recipient = new object();
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(recipient, (_, m) => seen.Add(m.Options.FeltColor));
        try
        {
            int revision = vm.Options.CustomFeltColorRevision;
            vm.UpdateFeltColor(FeltColorTheme.Crimson);

            Assert.Equal(FeltColorTheme.Crimson, vm.Options.FeltColor);
            Assert.Equal(revision + 1, vm.Options.CustomFeltColorRevision);
            Assert.Contains(FeltColorTheme.Crimson, seen);
            ForgetCachedSettings();
            Assert.Equal(FeltColorTheme.Crimson, SettingsService.LoadOptions().FeltColor);   // saved
        }
        finally
        {
            WeakReferenceMessenger.Default.Unregister<OptionsChangedMessage>(recipient);
        }
    }
}
