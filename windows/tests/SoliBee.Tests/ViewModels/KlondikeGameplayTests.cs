using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;
using static SoliBee.Tests.Cards;

namespace SoliBee.Tests.ViewModels;

// Player-visible Klondike behaviour on hand-built boards (ported from Mac's
// KlondikeGameplayTests): exact point values and popups, the undo penalty, move legality,
// draw and recycle, the timed-win bonus, No Stress, Vegas buy-ins and bankroll, the
// "no moves left" rules, Autocomplete, hints (checked by the move they point at, not their
// wording), restart, and what survives a relaunch. Only "a freshly dealt game" tests use a
// random deal.
public class KlondikeGameplayTests : DataSandbox
{
    public KlondikeGameplayTests()
    {
        Options.IsVegasScoring = false;
        Options.IsDrawConstraintsEnabled = false;
    }

    // A fresh install: no saved stats.
    private static GameViewModel Fresh()
    {
        Delete("stats.json");
        return new GameViewModel();
    }

    // What Preferences does when a shared setting changes: edit a copy, save it, broadcast it.
    private static void ChangeSharedOptions(System.Action<GameOptions> edit)
    {
        var copy = SettingsService.LoadOptions().Clone();
        edit(copy);
        SettingsService.SaveOptions(copy);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(copy));
    }

    private static void SetVegas(bool on) => ChangeSharedOptions(o => o.IsVegasScoring = on);

    private static readonly CardSuit[] FoundationSuits = { CardSuit.Spades, CardSuit.Clubs, CardSuit.Diamonds, CardSuit.Hearts };

    // Replaces the dealt game with a hand-built board. `found` gives how many cards (A…n)
    // each foundation already holds, in Spades/Clubs/Diamonds/Hearts order.
    private static void Board(GameViewModel vm, List<List<Card>>? tableau = null, List<Card>? stock = null,
        List<Card>? waste = null, Dictionary<CardSuit, int>? found = null, DrawMode draw = DrawMode.DrawThree)
    {
        vm.State.Mode = draw;
        for (int i = 0; i < vm.Tableaus.Count; i++)
        {
            vm.Tableaus[i].Cards.Clear();
            if (tableau != null && i < tableau.Count) vm.Tableaus[i].Cards.AddRange(tableau[i]);
        }
        int total = 0;
        for (int i = 0; i < vm.Foundations.Count; i++)
        {
            vm.Foundations[i].Cards.Clear();
            int n = found != null && found.TryGetValue(FoundationSuits[i], out var count) ? count : 0;
            if (n > 0) vm.Foundations[i].Cards.AddRange(Ascending(FoundationSuits[i], n));
            total += n;
        }
        Reflect.Set(vm, "_foundationCardCount", total);
        vm.Stock.Cards.Clear();
        if (stock != null) vm.Stock.Cards.AddRange(stock);
        vm.Waste.Cards.Clear();
        if (waste != null) vm.Waste.Cards.AddRange(waste);
        vm.State.Score = SettingsService.LoadOptions().IsVegasScoring ? -5200 : 0;
        vm.State.MovesCount = 0;
        vm.State.TimerSeconds = 0;
        vm.State.IsTimerActive = false;
        vm.State.HasWon = false;
        vm.State.RecyclesCount = 0;
        vm.State.WasteDrawBatchSize = 0;
        vm.HasNoMoves = false;
        vm.IsAutocompletable = false;
        vm.PointPopup = null;
        vm.ClearHintCycle();
    }

    private static List<Card> L(params Card[] cards) => cards.ToList();
    private static Dictionary<CardSuit, int> Found(int spades = 0, int clubs = 0, int diamonds = 0, int hearts = 0) =>
        new() { [CardSuit.Spades] = spades, [CardSuit.Clubs] = clubs, [CardSuit.Diamonds] = diamonds, [CardSuit.Hearts] = hearts };

    // Seven columns where nothing can move (no aces, no alternating-colour neighbours).
    private static List<List<Card>> DeadTableau() => new()
    {
        L(C(CardSuit.Spades, 13)), L(C(CardSuit.Hearts, 13)), L(C(CardSuit.Diamonds, 13)), L(C(CardSuit.Clubs, 13)),
        L(C(CardSuit.Spades, 9)), L(C(CardSuit.Hearts, 7)), L(C(CardSuit.Spades, 5)),
    };

    // 51 cards done except the K♠, alone in column 0.
    private static void OneCardFromWinning(GameViewModel vm) =>
        Board(vm, new() { L(C(CardSuit.Spades, 13)) }, found: Found(12, 13, 13, 13));

    private static void Move(GameViewModel vm, Pile from, Pile to) => vm.MoveCard(from.Cards.Last(), to);
    private static void PlayLastCard(GameViewModel vm) => Move(vm, vm.Tableaus[0], vm.Foundations[0]);

    private static void CheckDeadlock(GameViewModel vm) => Reflect.Call(vm, "CheckDeadlock");
    private static void CheckAutocomplete(GameViewModel vm) => Reflect.Call(vm, "CheckAutocomplete");

    // Plays the steps the Autocomplete timer would (the timer needs a UI thread).
    private static void RunAutocompleteSteps(GameViewModel vm, int max = 60)
    {
        for (int i = 0; i < max && vm.IsAutoplayRunning; i++) Reflect.Call(vm, "AnimateNextAutocompleteMove");
    }

    private static GameStatistics Stats() => StatsService.LoadStats();

    // ---- Deal ----

    [Fact]
    public void Deal_IsSevenColumnsOfOneToSeven_WithOnlyTheTopCardUp()
    {
        var vm = Fresh();
        Assert.Equal(new[] { 1, 2, 3, 4, 5, 6, 7 }, vm.Tableaus.Select(t => t.Cards.Count));
        Assert.All(vm.Tableaus, t =>
        {
            Assert.True(t.Cards.Last().IsFaceUp);
            Assert.All(t.Cards.Take(t.Cards.Count - 1), c => Assert.False(c.IsFaceUp));
        });
        Assert.Equal(24, vm.Stock.Cards.Count);
        Assert.Empty(vm.Waste.Cards);
        Assert.Equal(4, vm.Foundations.Count);
        var all = vm.Tableaus.SelectMany(t => t.Cards).Concat(vm.Stock.Cards).ToList();
        Assert.Equal(52, all.Select(c => (c.Suit, c.Rank)).Distinct().Count());
        Assert.Equal(1, Stats().GamesPlayed);
    }

    // ---- Scoring ----

    [Fact]
    public void StandardScoring_ForEveryKindOfMove()
    {
        var vm = Fresh();

        // Waste → tableau: +5
        var five = C(CardSuit.Hearts, 5);
        Board(vm, new() { L(C(CardSuit.Spades, 6)) }, waste: L(five));
        vm.MoveCard(five, vm.Tableaus[0]);
        Assert.Equal(5, vm.State.Score);
        Assert.Equal("+5", vm.PointPopup?.DisplayText);
        Assert.Equal(five.Id, vm.PointPopup?.CardId);

        // Waste → foundation: +10
        var ace = C(CardSuit.Spades, 1);
        Board(vm, waste: L(ace));
        vm.MoveCard(ace, vm.Foundations[0]);
        Assert.Equal(10, vm.State.Score);
        Assert.Equal("+10", vm.PointPopup?.DisplayText);

        // Tableau → foundation (+10) that reveals a card (+5)
        var hidden = C(CardSuit.Diamonds, 3, up: false);
        var aceC = C(CardSuit.Clubs, 1);
        Board(vm, new() { L(hidden, aceC) });
        vm.MoveCard(aceC, vm.Foundations[1]);
        Assert.Equal(15, vm.State.Score);
        Assert.Equal("+10", vm.PointPopup?.DisplayText);
        Assert.True(vm.Tableaus[0].Cards.Last().IsFaceUp);

        // Tableau → tableau that only reveals a card: +5
        var h5 = C(CardSuit.Hearts, 5);
        Board(vm, new() { L(C(CardSuit.Clubs, 9, up: false), h5), L(C(CardSuit.Spades, 6)) });
        vm.MoveCard(h5, vm.Tableaus[1]);
        Assert.Equal(5, vm.State.Score);

        // A plain tableau shuffle scores nothing
        Board(vm, new() { L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)) });
        Move(vm, vm.Tableaus[0], vm.Tableaus[1]);
        Assert.Equal(0, vm.State.Score);
        Assert.Null(vm.PointPopup);

        // Foundation → tableau: −15
        var two = C(CardSuit.Spades, 2);
        Board(vm, new() { L(C(CardSuit.Hearts, 3)) });
        vm.Foundations[0].Cards.AddRange(new[] { C(CardSuit.Spades, 1), two });
        Reflect.Set(vm, "_foundationCardCount", 2);
        vm.MoveCard(two, vm.Tableaus[0]);
        Assert.Equal(-15, vm.State.Score);
        Assert.Equal("-15", vm.PointPopup?.DisplayText);

        // Shuffling an ace between foundations scores nothing
        Board(vm, found: Found(spades: 1));
        Move(vm, vm.Foundations[0], vm.Foundations[1]);
        Assert.Equal(0, vm.State.Score);
        Assert.Single(vm.Foundations[1].Cards);
    }

    [Fact]
    public void NoPointPopups_WithHoneyModeOff()
    {
        Options.HoneyMode = false;
        var vm = Fresh();
        Board(vm, waste: L(C(CardSuit.Spades, 1)));
        vm.MoveCard(vm.Waste.Cards[0], vm.Foundations[0]);
        Assert.Null(vm.PointPopup);
        Assert.Equal(10, vm.State.Score);
    }

    [Fact]
    public void Undo_TakesBackThePointsTheMoveEarned()
    {
        var vm = Fresh();
        var five = C(CardSuit.Hearts, 5);
        Board(vm, new() { L(C(CardSuit.Spades, 6)) }, waste: L(five));
        vm.SaveStateForUndo();
        // SaveStateForUndo above is the explicit snapshot; MoveCard adds its own, so undo twice back.
        vm.MoveCard(five, vm.Tableaus[0]);
        Assert.Equal(5, vm.State.Score);
        vm.Undo();
        Assert.Equal(-5, vm.State.Score);   // the revert plus the 5 points taken back off
        Assert.Equal(new[] { five.Id }, vm.Waste.Cards.Select(c => c.Id));
        Assert.Single(vm.Tableaus[0].Cards);
        Assert.Null(vm.PointPopup);
    }

    [Fact]
    public void Undo_OfACostlyMove_NeverBecomesABonus_AndAnEmptyUndoDoesNothing()
    {
        var vm = Fresh();
        var two = C(CardSuit.Spades, 2);
        Board(vm, new() { L(C(CardSuit.Hearts, 3)) });
        vm.Foundations[0].Cards.AddRange(new[] { C(CardSuit.Spades, 1), two });
        Reflect.Set(vm, "_foundationCardCount", 2);
        vm.MoveCard(two, vm.Tableaus[0]);
        Assert.Equal(-15, vm.State.Score);
        vm.Undo();
        Assert.Equal(0, vm.State.Score);

        var before = vm.State.Score;
        vm.Undo();
        Assert.Equal(before, vm.State.Score);
        Assert.False(vm.CanUndo);
    }

    [Fact]
    public void Undo_StepsBackOneMoveAtATime_AndKeepsTheClock()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 6)), L(C(CardSuit.Clubs, 1)) }, waste: L(C(CardSuit.Hearts, 5)));
        vm.MoveCard(vm.Waste.Cards.Last(), vm.Tableaus[0]);
        vm.MoveCard(vm.Tableaus[1].Cards.Last(), vm.Foundations[0]);
        vm.State.TimerSeconds = 33;
        Assert.Equal(2, vm.State.MovesCount);
        vm.Undo();
        Assert.Equal(1, vm.State.MovesCount);
        Assert.Single(vm.Tableaus[1].Cards);
        Assert.Equal(33, vm.State.TimerSeconds);   // undo never rewinds the clock
        vm.Undo();
        Assert.Equal(0, vm.State.MovesCount);
        Assert.False(vm.CanUndo);
    }

    // ---- Move legality ----

    [Fact]
    public void MoveLegality()
    {
        var vm = Fresh();
        var h5 = C(CardSuit.Hearts, 5);
        var c5 = C(CardSuit.Clubs, 5);
        var h4 = C(CardSuit.Hearts, 4);
        var h13 = C(CardSuit.Hearts, 13);
        var h12 = C(CardSuit.Hearts, 12);
        // Each candidate sits in its own column so CanMoveCard can find where it comes from.
        Board(vm, new() { L(C(CardSuit.Spades, 6)), new(), L(h5), L(c5), L(h4), L(h13), L(h12) }, found: Found(hearts: 3));
        var t0 = vm.Tableaus[0];
        var empty = vm.Tableaus[1];

        Assert.True(vm.CanMoveCard(h5, t0));      // red 5 on black 6
        Assert.False(vm.CanMoveCard(c5, t0));     // black on black
        Assert.False(vm.CanMoveCard(h4, t0));     // wrong rank
        Assert.True(vm.CanMoveCard(h13, empty));  // a king may take an empty column
        Assert.False(vm.CanMoveCard(h12, empty)); // only a king may
        Assert.True(vm.CanMoveCard(h4, vm.Foundations[3]));    // 4♥ continues 3♥
        Assert.False(vm.CanMoveCard(h5, vm.Foundations[3]));   // can't skip a rank
        Assert.False(vm.CanMoveCard(h5, vm.Stock));
        Assert.False(vm.CanMoveCard(h5, vm.Waste));
    }

    [Fact]
    public void MoveLegality_RunsFoundationsAndFaceDownCards()
    {
        var vm = Fresh();
        var run5 = C(CardSuit.Hearts, 5);
        var run4 = C(CardSuit.Clubs, 4);
        var sameColour5 = C(CardSuit.Hearts, 5);
        var sameColour4 = C(CardSuit.Diamonds, 4);
        var gap5 = C(CardSuit.Hearts, 5);
        var gap3 = C(CardSuit.Clubs, 3);
        var down = C(CardSuit.Hearts, 5, up: false);
        var ace = C(CardSuit.Diamonds, 1);
        var two = C(CardSuit.Diamonds, 2);
        Board(vm, new()
        {
            L(C(CardSuit.Spades, 6)),
            L(run5, run4),
            L(sameColour5, sameColour4),
            L(C(CardSuit.Hearts, 9), gap5, gap3),
            L(down),
            L(ace),
            L(two),
        });

        Assert.True(vm.CanMoveCard(run5, vm.Tableaus[0]));              // a valid run moves as one: 5♥ 4♣ onto 6♠
        Assert.False(vm.CanMoveCard(run4, vm.Tableaus[0]));             // 4♣ alone doesn't fit on a 6
        Assert.False(vm.CanMoveCard(sameColour5, vm.Tableaus[0]));      // same-colour neighbours aren't a run
        Assert.False(vm.CanMoveCard(gap5, vm.Tableaus[0]));             // a rank gap isn't a run
        Assert.False(vm.CanMoveCard(down, vm.Tableaus[0]));             // a face-down card can't be moved
        Assert.True(vm.CanMoveCard(ace, vm.Foundations[2]));            // any ace starts an empty foundation
        Assert.False(vm.CanMoveCard(two, vm.Foundations[2]));           // only an ace does
        Assert.False(vm.CanMoveCard(run5, vm.Foundations[0]));          // foundations take one card at a time (5♥ has 4♣ on it)
    }

    [Fact]
    public void MovingARun_MovesEveryCardInIt_AndTurnsUpTheCardLeftBehind()
    {
        var vm = Fresh();
        var run = new[] { C(CardSuit.Hearts, 5), C(CardSuit.Clubs, 4), C(CardSuit.Diamonds, 3) };
        Board(vm, new() { L(C(CardSuit.Spades, 9, up: false), run[0], run[1], run[2]), L(C(CardSuit.Spades, 6)) });
        vm.MoveCard(run[0], vm.Tableaus[1]);
        Assert.Equal(4, vm.Tableaus[1].Cards.Count);
        Assert.Single(vm.Tableaus[0].Cards);
        Assert.True(vm.Tableaus[0].Cards[0].IsFaceUp);
        Assert.Equal(5, vm.State.Score);   // revealing a card
    }

    [Fact]
    public void AnIllegalMove_ChangesNothing()
    {
        var vm = Fresh();
        var c5 = C(CardSuit.Clubs, 5);
        Board(vm, new() { L(C(CardSuit.Spades, 6)), L(c5) });
        vm.MoveCard(c5, vm.Tableaus[0]);
        Assert.Equal(0, vm.State.MovesCount);
        Assert.False(vm.CanUndo);
        Assert.Equal(0, vm.State.Score);
        Assert.Single(vm.Tableaus[1].Cards);
    }

    // ---- Draw and recycle ----

    [Fact]
    public void DrawThree_TakesThree_FromTheEndOfTheStock_AndTheLastDrawTakesWhatsLeft()
    {
        var vm = Fresh();
        Board(vm, DeadTableau(), stock: Enumerable.Range(1, 7).Select(r => C(CardSuit.Clubs, r, up: false)).ToList());
        vm.DrawCard();
        Assert.Equal(4, vm.Stock.Cards.Count);
        Assert.Equal(new[] { 7, 6, 5 }, vm.Waste.Cards.Select(c => c.Rank));
        Assert.All(vm.Waste.Cards, c => Assert.True(c.IsFaceUp));
        Assert.Equal(1, vm.State.MovesCount);
        vm.DrawCard();
        vm.DrawCard();   // one card left: draws just that one
        Assert.Empty(vm.Stock.Cards);
        Assert.Equal(7, vm.Waste.Cards.Count);
    }

    [Fact]
    public void DrawingFromAnEmptyStock_Recycles_InTheOriginalOrder_AndUndoPutsItBack()
    {
        var vm = Fresh();
        Board(vm, DeadTableau(), stock: Enumerable.Range(1, 7).Select(r => C(CardSuit.Clubs, r, up: false)).ToList());
        vm.DrawCard(); vm.DrawCard(); vm.DrawCard();
        Assert.Empty(vm.Stock.Cards);

        vm.DrawCard();   // recycles — it doesn't also draw
        Assert.Equal(7, vm.Stock.Cards.Count);
        Assert.Empty(vm.Waste.Cards);
        Assert.Equal(1, vm.State.RecyclesCount);
        Assert.All(vm.Stock.Cards, c => Assert.False(c.IsFaceUp));
        Assert.Equal(Enumerable.Range(1, 7), vm.Stock.Cards.Select(c => c.Rank));   // same order, so the same cards come out again

        vm.Undo();
        Assert.Empty(vm.Stock.Cards);
        Assert.Equal(7, vm.Waste.Cards.Count);
        Assert.Equal(0, vm.State.RecyclesCount);
    }

    [Fact]
    public void DrawingWithNothingToDrawOrRecycle_DoesNothing()
    {
        var vm = Fresh();
        Board(vm, DeadTableau());
        vm.DrawCard();
        Assert.Equal(0, vm.State.MovesCount);
        Assert.False(vm.CanUndo);
        Assert.False(vm.CanRecycleStock);
    }

    [Fact]
    public void DrawOne_DrawsOne()
    {
        var vm = Fresh();
        Board(vm, DeadTableau(), stock: Enumerable.Range(1, 7).Select(r => C(CardSuit.Clubs, r, up: false)).ToList(), draw: DrawMode.DrawOne);
        vm.DrawCard();
        Assert.Single(vm.Waste.Cards);
        Assert.Equal(6, vm.Stock.Cards.Count);
    }

    [Fact]
    public void StandardPlay_HasNoRecycleLimit()
    {
        var vm = Fresh();
        Board(vm, DeadTableau(), stock: L(C(CardSuit.Clubs, 2, up: false)), draw: DrawMode.DrawOne);
        for (int pass = 0; pass < 6; pass++) { vm.DrawCard(); vm.DrawCard(); }   // draw, recycle, again…
        Assert.True(vm.State.RecyclesCount >= 5);
        Assert.Equal(6 * 2, vm.State.MovesCount);
    }

    [Fact]
    public void Vegas_LimitsRecyclesByDrawMode()
    {
        var vm = Fresh();
        SetVegas(true);
        Board(vm, DeadTableau(), waste: L(C(CardSuit.Clubs, 2)), draw: DrawMode.DrawOne);
        Assert.False(vm.CanRecycleStock);   // Draw One: a single pass, no recycles
        vm.DrawCard();
        Assert.Single(vm.Waste.Cards);
        Assert.Equal(0, vm.State.MovesCount);

        Board(vm, DeadTableau(), waste: L(C(CardSuit.Clubs, 2)), draw: DrawMode.DrawThree);
        vm.State.RecyclesCount = 1;
        Assert.True(vm.CanRecycleStock);    // Draw Three allows two recycles
        vm.State.RecyclesCount = 2;
        Assert.False(vm.CanRecycleStock);
    }

    // ---- Winning ----

    [Fact]
    public void TimedWin_ScoresTheBonus_RecordsStats_AndCannotBeUndone()
    {
        var vm = Fresh();
        OneCardFromWinning(vm);
        vm.State.Score = 500;
        vm.State.TimerSeconds = 100;
        PlayLastCard(vm);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.State.IsTimerActive);
        Assert.Equal(510 - 20 + 7000, vm.State.Score);   // −2 per 10 s, then 700,000 ÷ 100
        var s = Stats();
        Assert.Equal(7490, s.StandardHighScore);
        Assert.Equal(1, s.GamesWon);
        Assert.Equal(1, s.CurrentStreak);
        Assert.Equal(100, s.ShortestWinSeconds);
        Assert.Equal(100, s.TotalWinSeconds);
        Assert.Equal(1, s.TimedGamesWon);
        Assert.False(vm.CanUndo);
        vm.Undo();
        Assert.True(vm.State.HasWon);
        Assert.Equal(7490, new GameViewModel().Stats.StandardHighScore);   // survives a relaunch
    }

    [Fact]
    public void AVeryFastWin_HasNoTimeMinimum()
    {
        var vm = Fresh();
        OneCardFromWinning(vm);
        vm.State.Score = 500;
        vm.State.TimerSeconds = 7;
        PlayLastCard(vm);
        Assert.Equal(510 + 100000, vm.State.Score);   // 700,000 ÷ 7, no penalty
    }

    [Fact]
    public void TheTimePenalty_NeverTakesTheScoreBelowZero()
    {
        var vm = Fresh();
        OneCardFromWinning(vm);
        vm.State.Score = 0;
        vm.State.TimerSeconds = 1_000_000;
        PlayLastCard(vm);
        Assert.Equal(0, vm.State.Score);
    }

    [Fact]
    public void WinsAcrossGames_BuildTheStreak_AndKeepTheBestTime()
    {
        var vm = Fresh();
        OneCardFromWinning(vm); vm.State.TimerSeconds = 90; PlayLastCard(vm);
        vm.InitializeGame();
        OneCardFromWinning(vm); vm.State.TimerSeconds = 40; PlayLastCard(vm);
        var s = Stats();
        Assert.Equal(2, s.GamesWon);
        Assert.Equal(2, s.CurrentStreak);
        Assert.Equal(2, s.LongestStreak);
        Assert.Equal(40, s.ShortestWinSeconds);
        Assert.Equal(130, s.TotalWinSeconds);
        Assert.Equal(2, s.TimedGamesWon);
    }

    [Fact]
    public void NoStressWin_CountsButHasNoTimeAndNoBonus()
    {
        Options.IsNoStressMode = true;
        var vm = Fresh();
        OneCardFromWinning(vm);
        vm.State.Score = 500;
        vm.State.TimerSeconds = 100;
        PlayLastCard(vm);
        Assert.True(vm.State.HasWon);
        Assert.Equal(510, vm.State.Score);
        var s = Stats();
        Assert.Equal(1, s.GamesWon);
        Assert.Equal(0, s.TimedGamesWon);
        Assert.Equal(0, s.ShortestWinSeconds);
    }

    [Fact]
    public void TurningNoStressOnPartway_TaintsTheTimeToo()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 12)), L(C(CardSuit.Spades, 13)) }, found: Found(11, 13, 13, 13));
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        Assert.True(vm.State.IsTimerActive);   // the first move starts the clock
        vm.State.TimerSeconds = 50;

        ChangeSharedOptions(o => o.IsNoStressMode = true);
        Assert.False(vm.State.IsTimerActive);
        Assert.Equal(0, vm.State.TimerSeconds);
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.True(vm.State.IsTimerActive);

        vm.State.TimerSeconds = 3;
        Move(vm, vm.Tableaus[1], vm.Foundations[0]);
        Assert.True(vm.State.HasWon);
        Assert.Equal(0, Stats().TimedGamesWon);   // a part-untimed game records no best time
        Assert.Equal(20, vm.State.Score);         // ...and earns no bonus (2 moves × 10)
    }

    [Fact]
    public void NoClock_BeforeTheFirstMove()
    {
        var vm = Fresh();
        ChangeSharedOptions(o => o.IsNoStressMode = true);
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.False(vm.State.IsTimerActive);
    }

    // ---- Vegas ----

    [Fact]
    public void Vegas_EnteringChargesTheBuyIn_WithoutCountingANewGame()
    {
        var vm = Fresh();
        SetVegas(true);
        Assert.Equal(-5200, vm.State.Score);
        Assert.Equal(-5200, vm.Stats.VegasCumulativeScore);
        Assert.Equal(1, Stats().GamesPlayed);
    }

    [Fact]
    public void Vegas_FoundationCardsPay5Dollars_AndNothingElseDoes()
    {
        var vm = Fresh();
        SetVegas(true);
        var ace = C(CardSuit.Spades, 1);
        var two = C(CardSuit.Spades, 2);
        Board(vm, new() { L(C(CardSuit.Hearts, 3)) }, waste: L(ace));
        vm.MoveCard(ace, vm.Foundations[0]);
        Assert.Equal(-4700, vm.State.Score);
        Assert.Equal(-4700, vm.Stats.VegasCumulativeScore);
        Assert.Equal("+$5", vm.PointPopup?.DisplayText);

        vm.Foundations[0].Cards.Add(two);
        Reflect.Set(vm, "_foundationCardCount", 2);
        vm.MoveCard(two, vm.Tableaus[0]);
        Assert.Equal(-5200, vm.State.Score);
        Assert.Equal("-$5", vm.PointPopup?.DisplayText);

        // Waste → tableau and reveals earn nothing; foundation → foundation can't farm money.
        var h5 = C(CardSuit.Hearts, 5);
        Board(vm, new() { L(C(CardSuit.Clubs, 9, up: false), C(CardSuit.Spades, 6)) }, waste: L(h5));
        vm.MoveCard(h5, vm.Tableaus[0]);
        Assert.Equal(-5200, vm.State.Score);
        Board(vm, found: Found(spades: 1));
        Move(vm, vm.Foundations[0], vm.Foundations[1]);
        Assert.Equal(-5200, vm.State.Score);
    }

    [Fact]
    public void Vegas_EachNewGameCostsAnotherBuyIn_AndAWinHasNoTimeBonus()
    {
        var vm = Fresh();
        SetVegas(true);
        var bankroll = vm.Stats.VegasCumulativeScore;
        vm.InitializeGame();
        Assert.Equal(bankroll - 5200, vm.State.Score);
        Assert.Equal(bankroll - 5200, vm.Stats.VegasCumulativeScore);

        OneCardFromWinning(vm);
        vm.State.Score = -5200;
        vm.State.TimerSeconds = 100;
        PlayLastCard(vm);
        Assert.True(vm.State.HasWon);
        Assert.Equal(-5200 + 500, vm.State.Score);
    }

    [Fact]
    public void Vegas_UndoGivesTheMoneyBack_RestartKeepsTheBankrollHonest()
    {
        var vm = Fresh();
        SetVegas(true);
        var ace = C(CardSuit.Spades, 1);
        Board(vm, new() { L(ace) });
        vm.MoveCard(ace, vm.Foundations[0]);
        Assert.Equal(-4700, vm.Stats.VegasCumulativeScore);
        vm.Undo();
        Assert.Equal(-5200, vm.State.Score);   // no undo penalty in Vegas
        Assert.Equal(-5200, vm.Stats.VegasCumulativeScore);

        // Restarting an unwon game rolls back the gains and doesn't charge again.
        Board(vm, new() { L(C(CardSuit.Spades, 1)) });
        Move(vm, vm.Tableaus[0], vm.Foundations[0]);
        vm.RestartGame();
        Assert.Equal(-5200, vm.State.Score);
        Assert.Equal(-5200, vm.Stats.VegasCumulativeScore);
        Assert.Equal(1, Stats().GamesPlayed);

        // Restarting a WON game charges a fresh buy-in on top of the winnings and counts as a new game.
        OneCardFromWinning(vm);
        vm.State.Score = -5200;
        PlayLastCard(vm);
        Assert.True(vm.State.HasWon);
        Assert.Equal(-4700, vm.State.Score);
        vm.RestartGame();
        Assert.False(vm.State.HasWon);
        Assert.Equal(-4700 - 5200, vm.State.Score);
        Assert.Equal(2, Stats().GamesPlayed);
    }

    [Fact]
    public void Vegas_BankrollStartsAtZeroEachLaunch_ButTheModeIsRemembered()
    {
        var vm = Fresh();
        SetVegas(true);
        vm.InitializeGame(); vm.InitializeGame();
        Assert.Equal(-15600, vm.Stats.VegasCumulativeScore);   // three buy-ins in one session

        var relaunched = new GameViewModel();
        Assert.True(relaunched.Options.IsVegasScoring);
        Assert.Equal(-5200, relaunched.Stats.VegasCumulativeScore);   // only this launch's first deal
    }

    [Fact]
    public void TogglingVegasMidGame_BreaksTheStreak_ButNotGamesPlayed()
    {
        var vm = Fresh();
        vm.Stats.CurrentStreak = 3; vm.Stats.LongestStreak = 3;
        Board(vm, new() { L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)) });
        Move(vm, vm.Tableaus[0], vm.Tableaus[1]);
        var played = vm.Stats.GamesPlayed;
        SetVegas(true);
        Assert.Equal(0, vm.Stats.CurrentStreak);
        Assert.Equal(3, vm.Stats.LongestStreak);
        Assert.Equal(played, vm.Stats.GamesPlayed);
    }

    [Fact]
    public void EnteringVegas_ChargesTheBuyIn_WhetherOrNotYouHadPlayed()
    {
        var untouched = Fresh();
        SetVegas(true);
        Assert.Equal(-5200, untouched.State.Score);
        Assert.Equal(-5200, untouched.Stats.VegasCumulativeScore);
        SetVegas(false);

        var played = Fresh();
        Board(played, new() { L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)) });
        Move(played, played.Tableaus[0], played.Tableaus[1]);
        Assert.Equal(1, played.State.MovesCount);
        SetVegas(true);
        Assert.Equal(-5200, played.State.Score);
        Assert.Equal(-5200, played.Stats.VegasCumulativeScore);

        var ace = C(CardSuit.Spades, 1);
        Board(played, new() { L(ace) });
        played.MoveCard(ace, played.Foundations[0]);
        Assert.Equal(-4700, played.Stats.VegasCumulativeScore);
    }

    // ---- "No moves left" ----

    [Fact]
    public void NoMovesLeft_Rules()
    {
        var vm = Fresh();
        Board(vm, DeadTableau());
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);   // nothing playable and nothing to draw or recycle: stuck at once

        Board(vm, new List<List<Card>> { L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)) }.Concat(DeadTableau().Skip(2)).ToList());
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);  // a legal progressive move

        Board(vm, DeadTableau(), stock: L(C(CardSuit.Spades, 1, up: false)));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);  // an ace waiting in the stock is a move

        // A won game is never stuck.
        Board(vm, DeadTableau());
        vm.State.HasWon = true;
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);
    }

    [Fact]
    public void NoMovesLeft_DeadStock_IsOnlyFlaggedAfterRecyclingPastTheFirstDetection()
    {
        var vm = Fresh();
        Board(vm, DeadTableau(), stock: L(C(CardSuit.Hearts, 2, up: false)));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // first detection remembers where we were but doesn't flag
        vm.DrawCard();
        Assert.False(vm.HasNoMoves);   // not stuck on the first pass through the stock
        vm.DrawCard();                 // recycles
        Assert.Equal(1, vm.State.RecyclesCount);
        vm.DrawCard();                 // draws the 2♥ again
        Assert.True(vm.HasNoMoves);
    }

    [Fact]
    public void NoMovesLeft_InVegas_NeverWhileAnotherPassIsAllowed()
    {
        var vm = Fresh();
        SetVegas(true);
        Board(vm, DeadTableau(), stock: L(C(CardSuit.Hearts, 2, up: false)));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);
        Board(vm, DeadTableau(), waste: L(C(CardSuit.Hearts, 2)));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // a pass remaining
        vm.State.RecyclesCount = 2;
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);    // passes used up
    }

    [Fact]
    public void ALateralKingMove_IsNotAWayOut()
    {
        var vm = Fresh();
        Board(vm, new List<List<Card>> { L(C(CardSuit.Hearts, 13)) }.Concat(DeadTableau().Skip(4)).ToList());
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);   // a lone king moving to another empty column changes nothing
    }

    [Fact]
    public void PlayingIntoADeadEnd_RaisesTheFlag_AndUndoClearsIt()
    {
        var vm = Fresh();
        Board(vm, new List<List<Card>> { L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)) }
            .Concat(new List<List<Card>> { L(C(CardSuit.Diamonds, 13)), L(C(CardSuit.Clubs, 13)), L(C(CardSuit.Spades, 9)), L(C(CardSuit.Spades, 2)), L(C(CardSuit.Clubs, 3)) }).ToList());
        Move(vm, vm.Tableaus[0], vm.Tableaus[1]);
        Assert.True(vm.HasNoMoves);
        vm.Undo();
        Assert.False(vm.HasNoMoves);
    }

    // ---- Autocomplete ----

    [Fact]
    public void Autocomplete_IsOfferedOnlyWhenEverythingIsFaceUpAndTheStockIsEmpty()
    {
        var vm = Fresh();
        OneCardFromWinning(vm);
        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // an Autocomplete-able game isn't stuck

        Board(vm, new() { L(C(CardSuit.Spades, 13, up: false)) }, found: Found(12, 13, 13, 13));
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);   // a face-down card

        Board(vm, new() { L(C(CardSuit.Spades, 12)) }, stock: L(C(CardSuit.Spades, 13, up: false)), found: Found(11, 13, 13, 13));
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);   // cards in the stock

        Board(vm, new() { L(C(CardSuit.Spades, 12)) }, waste: L(C(CardSuit.Spades, 13)), found: Found(11, 13, 13, 13));
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);   // cards in the waste
        vm.Autocomplete();
        Assert.False(vm.IsAutoplayRunning);   // does nothing when it isn't offered
    }

    [Fact]
    public void Autocomplete_PlaysTheGameOut_AndRecordsTheWin()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)), L(C(CardSuit.Clubs, 13)) }, found: Found(12, 12, 13, 13));
        CheckAutocomplete(vm);
        vm.Autocomplete();
        Assert.True(vm.IsAutoplayRunning);
        RunAutocompleteSteps(vm);
        Assert.True(vm.State.HasWon);
        Assert.False(vm.IsAutoplayRunning);
        Assert.Equal(20, vm.State.Score);   // two foundation moves
        Assert.Equal(1, Stats().GamesWon);
    }

    [Fact]
    public void UndoDuringAutocomplete_StopsIt()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 13)), L(C(CardSuit.Clubs, 13)) }, found: Found(12, 12, 13, 13));
        CheckAutocomplete(vm);
        vm.Autocomplete();
        vm.Undo();
        Assert.False(vm.IsAutoplayRunning);
        RunAutocompleteSteps(vm);
        Assert.False(vm.State.HasWon);   // the undone cards aren't replayed
    }

    // ---- Hints (by the move they point at) ----

    [Fact]
    public void Hint_PrefersAFoundationMove_AndPointsAtThatCard()
    {
        var vm = Fresh();
        var ace = C(CardSuit.Spades, 1);
        Board(vm, new() { L(C(CardSuit.Spades, 6)), L(C(CardSuit.Hearts, 5)), L(ace) });
        vm.FindHint();
        Assert.NotNull(vm.ActiveHint);
        Assert.Equal(ace.Id, vm.ActiveHint!.Card.Id);
        Assert.Equal(vm.Tableaus[2].Id, vm.ActiveHint.SourcePileId);
        Assert.Contains(vm.Foundations.Select(f => f.Id), id => id == vm.ActiveHint.TargetPileId);
    }

    [Fact]
    public void Hint_CyclesThroughEveryMove_ThenWrapsAround_AndClearsOnTheNextMove()
    {
        var vm = Fresh();
        Board(vm, new() { L(C(CardSuit.Spades, 6)), L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 1)) });
        vm.FindHint();
        var first = vm.ActiveHint!;
        int total = first.Total;
        Assert.True(total >= 2);
        string Key(HintMove h) => $"{h.Card.Id}|{h.SourcePileId}|{h.TargetPileId}";
        var seen = new List<string> { Key(first) };
        for (int i = 1; i < total; i++) { vm.FindHint(); seen.Add(Key(vm.ActiveHint!)); }
        Assert.Equal(total, seen.Distinct().Count());   // each press shows a different move
        vm.FindHint();
        Assert.Equal(Key(first), Key(vm.ActiveHint!));   // wrapped around

        Move(vm, vm.Tableaus[2], vm.Foundations[0]);
        Assert.Null(vm.ActiveHint);
    }

    [Fact]
    public void Hint_OnABoardWithNoMoves_ShowsNothing()
    {
        var vm = Fresh();
        Board(vm, DeadTableau());
        vm.FindHint();
        // The "no moves" answer isn't a real move: it has no source or target pile.
        Assert.True(vm.ActiveHint == null || (vm.ActiveHint.SourcePileId == "" && vm.ActiveHint.TargetPileId == ""));
    }

    // ---- Restart and relaunch ----

    [Fact]
    public void Restart_ReplaysTheSameDeal()
    {
        var vm = Fresh();
        var deal = vm.Tableaus.Select(t => t.Cards.Select(c => c.Id).ToList()).ToList();
        var stock = vm.Stock.Cards.Select(c => c.Id).ToList();
        vm.DrawCard();
        vm.RestartGame();
        Assert.Equal(deal, vm.Tableaus.Select(t => t.Cards.Select(c => c.Id).ToList()).ToList());
        Assert.Equal(stock, vm.Stock.Cards.Select(c => c.Id).ToList());
        Assert.Equal(0, vm.State.MovesCount);
        Assert.False(vm.CanUndo);
    }

    [Fact]
    public void RestartingAnUnwonGame_IsNotAnotherGamePlayed_ButRestartingAWonOneIs()
    {
        var vm = Fresh();
        vm.DrawCard();
        var played = Stats().GamesPlayed;
        vm.RestartGame();
        Assert.Equal(played, Stats().GamesPlayed);

        OneCardFromWinning(vm);
        PlayLastCard(vm);
        Assert.True(vm.State.HasWon);
        vm.RestartGame();
        Assert.Equal(played + 1, Stats().GamesPlayed);
        vm.RestartGame();   // nothing played yet this time
        Assert.Equal(played + 1, Stats().GamesPlayed);
    }

    [Fact]
    public void ResetStats_ClearsEverythingButLeavesOtherGamesAlone()
    {
        var vm = Fresh();
        OneCardFromWinning(vm);
        vm.State.TimerSeconds = 50;
        PlayLastCard(vm);
        var all = StatsService.LoadStats();
        all.FreecellStatsByMode["standard_1deck"] = new ModeStats { GamesWon = 4 };
        StatsService.SaveStats(all);

        vm.ResetStats();

        var s = Stats();
        Assert.Equal(0, s.GamesWon);
        Assert.Equal(0, s.GamesPlayed);
        Assert.Equal(0, s.StandardHighScore);
        Assert.Equal(0, s.ShortestWinSeconds);
        Assert.Equal(4, s.FreecellStatsByMode["standard_1deck"].GamesWon);
    }
}
