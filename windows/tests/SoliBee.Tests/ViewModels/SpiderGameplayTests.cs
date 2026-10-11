using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;
using static SoliBee.Tests.Cards;

namespace SoliBee.Tests.ViewModels;

// Player-visible Spider behaviour on hand-built boards (ported from Mac's
// SpiderGameplayTests): the deal, stock dealing, the move rule, completed runs, winning,
// stats/streaks per suit count, undo, restart, stuck detection, Autocomplete, hints, point
// popups and banners. Only "a freshly dealt game" tests use a random deal.
public class SpiderGameplayTests : DataSandbox
{
    public SpiderGameplayTests()
    {
        Options.SpiderSuitCount = 1;
    }

    // A fresh install: no saved stats for any solitaire game.
    private static SpiderViewModel Fresh()
    {
        Delete("stats.json");
        return new SpiderViewModel();
    }

    private static ModeStats Mode(string suits = "1") =>
        StatsService.LoadStats().SpiderStatsBySuit.GetValueOrDefault(suits) ?? new ModeStats();

    private static void Prime(string suits, ModeStats stats)
    {
        var all = StatsService.LoadStats();
        all.SpiderStatsBySuit[suits] = stats;
        StatsService.SaveStats(all);
    }

    // Replaces the dealt game with a hand-built board: `cols` fills columns 0… in order
    // (the rest empty), `stock` is dealt from the front in rows of ten, and `doneRuns`
    // foundations already hold a finished K→A spade run.
    private static void Board(SpiderViewModel vm, List<List<Card>> cols, List<Card>? stock = null, int doneRuns = 0)
    {
        for (int i = 0; i < 10; i++)
        {
            vm.Tableaus[i].Cards.Clear();
            if (i < cols.Count) vm.Tableaus[i].Cards.AddRange(cols[i]);
        }
        vm.StockPiles.Clear();
        stock ??= new List<Card>();
        for (int i = 0; i < stock.Count; i += 10)
        {
            var pile = new Pile($"Stock_{vm.StockPiles.Count}", PileType.Stock);
            pile.Cards.AddRange(stock.Skip(i).Take(10));
            vm.StockPiles.Add(pile);
        }
        for (int i = 0; i < 8; i++)
        {
            vm.Foundations[i].Cards.Clear();
            if (i < doneRuns) vm.Foundations[i].Cards.AddRange(Run(CardSuit.Spades, 13, 1));
        }
        Reflect.Set(vm, "_foundationCardCount", 13 * doneRuns);
        var undo = Reflect.Get<object>(vm, "_undoStack");
        undo.GetType().GetMethod("Clear")!.Invoke(undo, null);
        vm.State.Score = 500;
        vm.State.MovesCount = 0;
        vm.State.TimerSeconds = 0;
        vm.State.IsTimerActive = false;
        vm.State.HasWon = false;
        vm.HasNoMoves = false;
        vm.IsAutocompletable = false;
        vm.ClearHintCycle();
        vm.PointPopup = null;
    }

    private static List<Card> King() => L(C(CardSuit.Diamonds, 13));

    // Columns 0… from `cols`, padded with lone kings up to 10 columns (no empty column,
    // and nothing can move onto a king).
    private static List<Card> L(params Card[] cards) => cards.ToList();

    private static List<List<Card>> Padded(params List<Card>[] cols) =>
        cols.Concat(Enumerable.Range(cols.Length, 10 - cols.Length).Select(_ => King())).ToList();

    private static List<List<Card>> Kings() => Enumerable.Range(0, 10).Select(_ => King()).ToList();

    private static List<Card> FaceDownStock(int n, CardSuit suit = CardSuit.Hearts, int rank = 0) =>
        Enumerable.Range(0, n).Select(i => C(suit, rank > 0 ? rank : 1 + i % 13, up: false)).ToList();

    // Seven finished runs, K→2♠ in column 0 and the A♠ in column 1.
    private static void OneMoveFromWinning(SpiderViewModel vm) =>
        Board(vm, new() { Run(CardSuit.Spades, 13, 2), L(C(CardSuit.Spades, 1)) }, doneRuns: 7);

    private static void Move(SpiderViewModel vm, int from, int to, int count = 1)
    {
        var src = vm.Tableaus[from];
        vm.MoveSequence(src.Cards.TakeLast(count).ToList(), src, vm.Tableaus[to]);
    }

    private static List<List<string>> Layout(SpiderViewModel vm) =>
        vm.Tableaus.Select(t => t.Cards.Select(c => c.Id).ToList()).ToList();

    private static void CheckDeadlock(SpiderViewModel vm) => Reflect.Call(vm, "CheckDeadlock");
    private static void CheckAutocomplete(SpiderViewModel vm) => Reflect.Call(vm, "CheckAutocomplete");

    // Plays the steps the Autocomplete timer would (the timer needs a UI thread).
    private static void RunAutocompleteSteps(SpiderViewModel vm, int max = 50)
    {
        for (int i = 0; i < max && vm.IsAutoplayRunning; i++) Reflect.Call(vm, "AnimateNextAutocompleteMove");
    }

    private static int Queued(SpiderViewModel vm) => Reflect.Get<Queue<string>>(vm, "_bannerQueue").Count;

    private static int Drain(SpiderViewModel vm)
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

    // ── Deal ──────────────────────────────────────────────────────────────────

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(4)]
    public void Deal_LayoutForEachSuitCount(int suits)
    {
        Options.SpiderSuitCount = suits;
        var vm = Fresh();

        Assert.Equal(10, vm.Tableaus.Count);
        for (int i = 0; i < 10; i++)
        {
            var cards = vm.Tableaus[i].Cards;
            Assert.Equal(i < 4 ? 6 : 5, cards.Count);
            Assert.True(cards[^1].IsFaceUp);
            Assert.All(cards.Take(cards.Count - 1), c => Assert.False(c.IsFaceUp));
        }
        Assert.Equal(5, vm.StockPiles.Count);
        Assert.All(vm.StockPiles, p => { Assert.Equal(10, p.Cards.Count); Assert.All(p.Cards, c => Assert.False(c.IsFaceUp)); });
        Assert.Equal(8, vm.Foundations.Count);
        Assert.All(vm.Foundations, f => Assert.Empty(f.Cards));
        Assert.Equal(500, vm.State.Score);
        Assert.Equal("500", vm.ScoreDisplay);
        Assert.Equal(0, vm.MovesCount);
        Assert.Equal("00:00", vm.TimeDisplay);
        Assert.False(vm.CanUndo);

        var all = vm.Tableaus.Concat(vm.StockPiles).SelectMany(p => p.Cards).ToList();
        Assert.Equal(104, all.Select(c => c.Id).Distinct().Count());
        Assert.Equal(suits, all.Select(c => c.Suit).Distinct().Count());
        Assert.All(all.GroupBy(c => (c.Suit, c.Rank)), g => Assert.Equal(8 / suits, g.Count()));
        Assert.Equal(1, Mode(suits.ToString()).GamesPlayed);
    }

    [Fact]
    public void SwitchingSuitCount_DealsAndCountsAGameInTheNewMode_AndBreaksTheAbandonedModesStreak()
    {
        var vm = Fresh();
        Prime("1", new ModeStats { GamesPlayed = 1, CurrentStreak = 3, LongestStreak = 3 });
        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))));
        Move(vm, 0, 1);

        // MainWindow's suit-count switch: change the shared option, then deal.
        Options.SpiderSuitCount = 2;
        vm.InitializeGame();

        Assert.Equal(1, Mode("2").GamesPlayed);
        Assert.Equal(2, vm.Tableaus.Concat(vm.StockPiles).SelectMany(p => p.Cards).Select(c => c.Suit).Distinct().Count());
        Assert.Equal(0, Mode("1").CurrentStreak);   // the played 1-suit game was abandoned
        Assert.Equal(3, Mode("1").LongestStreak);
    }

    // ── Stock ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Stock_DealsOneFaceUpCardToEveryColumn_AndCanBeUndone()
    {
        var vm = Fresh();
        var stock = FaceDownStock(20);
        Board(vm, Kings(), stock);
        Assert.True(vm.CanDealFromStock);

        vm.DealFromStock();

        Assert.Single(vm.StockPiles);
        Assert.All(vm.Tableaus, t => { Assert.Equal(2, t.Cards.Count); Assert.True(t.Cards[^1].IsFaceUp); });
        Assert.Equal(stock[0].Id, vm.Tableaus[0].Cards[^1].Id);
        Assert.Equal(stock[9].Id, vm.Tableaus[9].Cards[^1].Id);
        Assert.Equal(499, vm.State.Score);   // a deal costs 1 point and is a move
        Assert.Equal(1, vm.MovesCount);
        Assert.True(vm.CanUndo);
        Assert.True(vm.State.IsTimerActive); // the first action starts the clock

        vm.Undo();
        Assert.Equal(2, vm.StockPiles.Count);
        Assert.Equal(20, vm.StockPiles.Sum(p => p.Cards.Count));
        Assert.All(vm.StockPiles.SelectMany(p => p.Cards), c => Assert.False(c.IsFaceUp));
        Assert.All(vm.Tableaus, t => Assert.Single(t.Cards));
        Assert.Equal(500, vm.State.Score);
        Assert.Equal(0, vm.MovesCount);
    }

    [Fact]
    public void Stock_RefusedWhileAColumnIsEmpty_OrWhenEmpty_AndScoreNeverGoesNegative()
    {
        var blocked = Fresh();
        var cols = Kings();
        cols[3] = new();
        Board(blocked, cols, FaceDownStock(20));
        Assert.False(blocked.CanDealFromStock);
        blocked.DealFromStock();
        Assert.Equal(2, blocked.StockPiles.Count);
        Assert.Equal(0, blocked.MovesCount);
        Assert.False(blocked.CanUndo);

        var drained = Fresh();
        Board(drained, Kings());
        drained.DealFromStock();
        Assert.Equal(0, drained.MovesCount);
        Assert.Equal(500, drained.State.Score);

        var broke = Fresh();
        Board(broke, Kings(), FaceDownStock(20));
        broke.State.Score = 0;
        broke.DealFromStock();
        Assert.Equal(0, broke.State.Score);
    }

    [Fact]
    public void Stock_DealingTheLastRowCanLeaveTheBoardStuck()
    {
        var vm = Fresh();
        Board(vm, Kings(), FaceDownStock(10, CardSuit.Spades, 13));
        vm.DealFromStock();
        Assert.Empty(vm.StockPiles);
        Assert.True(vm.HasNoMoves);
        Assert.False(vm.IsAutocompletable);
    }

    // ── Moves ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Moves_AnySuitOnOneRankHigher_FlipsTheUncoveredCard_AndUndoRestoresEverything()
    {
        var vm = Fresh();
        var nine = C(CardSuit.Clubs, 9, up: false);
        var five = C(CardSuit.Hearts, 5);
        var six = C(CardSuit.Spades, 6);
        Board(vm, Padded(L(nine, five), L(six)));
        var before = Layout(vm);

        Assert.True(vm.CanMoveSequence(L(five), vm.Tableaus[1]));
        vm.MoveSequence(L(five), vm.Tableaus[0], vm.Tableaus[1]);
        Assert.Equal(new[] { six.Id, five.Id }, vm.Tableaus[1].Cards.Select(c => c.Id));
        Assert.True(vm.Tableaus[0].Cards[0].IsFaceUp);   // the card left behind turns face up
        Assert.Equal(499, vm.State.Score);
        Assert.Equal(1, vm.MovesCount);

        // The wrong rank is refused.
        var snapshot = Layout(vm);
        Assert.False(vm.CanMoveSequence(L(vm.Tableaus[0].Cards[0]), vm.Tableaus[1]));
        vm.MoveSequence(L(vm.Tableaus[0].Cards[0]), vm.Tableaus[0], vm.Tableaus[1]);
        Assert.Equal(snapshot, Layout(vm));
        Assert.Equal(1, vm.MovesCount);
        Assert.False(vm.CanMoveSequence(new List<Card>(), vm.Tableaus[1]));

        vm.Undo();
        Assert.Equal(before, Layout(vm));
        Assert.False(vm.Tableaus[0].Cards[0].IsFaceUp);   // flipped back face down
        Assert.Equal(500, vm.State.Score);
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.CanUndo);
    }

    [Fact]
    public void Moves_OnlySameSuitDescendingRunsMoveTogether_AndEmptyColumnsTakeAnything()
    {
        var vm = Fresh();
        var s6 = C(CardSuit.Spades, 6);
        var s5 = C(CardSuit.Spades, 5);
        var cols = Padded(L(C(CardSuit.Clubs, 9, up: false), s6, s5));
        cols[1] = new();
        cols[2] = new();
        Board(vm, cols);

        Assert.False(vm.CanMoveSequence(L(s6, C(CardSuit.Hearts, 4)), vm.Tableaus[1]));   // mixed suits
        Assert.False(vm.CanMoveSequence(L(s5, s6), vm.Tableaus[1]));                      // ascending
        Assert.Equal(new[] { s6.Id, s5.Id }, vm.GetMovableSequence(vm.Tableaus[0]).Select(c => c.Id));
        Assert.Empty(vm.GetMovableSequence(vm.Tableaus[1]));

        vm.MoveSequence(L(s6, s5), vm.Tableaus[0], vm.Tableaus[1]);
        Assert.Equal(new[] { s6.Id, s5.Id }, vm.Tableaus[1].Cards.Select(c => c.Id));
        Assert.True(vm.Tableaus[0].Cards[0].IsFaceUp);

        var nine = vm.Tableaus[0].Cards[0];
        vm.MoveSequence(L(nine), vm.Tableaus[0], vm.Tableaus[2]);
        Assert.Single(vm.Tableaus[2].Cards);
        Assert.Empty(vm.Tableaus[0].Cards);
    }

    // Mac refuses any drop that isn't on a tableau column. Windows' CanMoveSequence never
    // looks at the target pile's type, so a card can be dropped onto an empty Spider
    // foundation slot (the foundation PileViews are drop targets in SpiderView).
    [Fact(Skip = "Mac difference found 2026-10-11, not fixed yet: Spider lets a card be moved onto an empty foundation")]
    public void Moves_CannotDropOnAFoundation()
    {
        var vm = Fresh();
        var five = C(CardSuit.Hearts, 5);
        Board(vm, Padded(L(five)));
        Assert.False(vm.CanMoveSequence(L(five), vm.Foundations[0]));
        vm.MoveSequence(L(five), vm.Tableaus[0], vm.Foundations[0]);
        Assert.Empty(vm.Foundations[0].Cards);
    }

    // ── Completed runs ────────────────────────────────────────────────────────

    [Fact]
    public void CompletedRun_GoesToAFoundation_Scores100_AndUndoTakesItBack()
    {
        var vm = Fresh();
        var hidden = C(CardSuit.Hearts, 2, up: false);
        var ace = C(CardSuit.Spades, 1);
        Board(vm, Padded(new List<Card> { hidden }.Concat(Run(CardSuit.Spades, 13, 2)).ToList(), L(ace)));

        Move(vm, 1, 0);

        Assert.Equal(13, vm.Foundations[0].Cards.Count);
        Assert.Equal(13, vm.Foundations[0].Cards[0].Rank);
        Assert.Equal(1, vm.Foundations[0].Cards[^1].Rank);
        Assert.Equal(new[] { hidden.Id }, vm.Tableaus[0].Cards.Select(c => c.Id));
        Assert.True(vm.Tableaus[0].Cards[0].IsFaceUp);
        Assert.Equal(500 - 1 + 100, vm.State.Score);
        Assert.False(vm.State.HasWon);

        vm.Undo();
        Assert.All(vm.Foundations, f => Assert.Empty(f.Cards));
        Assert.Equal(13, vm.Tableaus[0].Cards.Count);
        Assert.Single(vm.Tableaus[1].Cards);
        Assert.Equal(500, vm.State.Score);
    }

    [Fact]
    public void CompletedRun_MixedSuitsStayOnTheBoard()
    {
        var vm = Fresh();
        Board(vm, Padded(Run(CardSuit.Spades, 13, 2), L(C(CardSuit.Hearts, 1))));
        Move(vm, 1, 0);
        Assert.Equal(13, vm.Tableaus[0].Cards.Count);
        Assert.All(vm.Foundations, f => Assert.Empty(f.Cards));
        Assert.Equal(499, vm.State.Score);
    }

    [Fact]
    public void CompletedRun_FromAStockDealIsSweptToo()
    {
        var vm = Fresh();
        var cols = Kings();
        cols[0] = Run(CardSuit.Spades, 13, 2);
        var stock = FaceDownStock(10, CardSuit.Hearts, 13);
        stock[0] = C(CardSuit.Spades, 1, up: false);   // lands on column 0's 2♠
        Board(vm, cols, stock);

        vm.DealFromStock();

        Assert.Equal(13, vm.Foundations[0].Cards.Count);
        Assert.Empty(vm.Tableaus[0].Cards);
        Assert.Equal(500 - 1 + 100, vm.State.Score);
    }

    // ── Winning & stats ───────────────────────────────────────────────────────

    [Fact]
    public void Win_RecordsStats_StopsTheClock_AndLocksUndo()
    {
        var vm = Fresh();
        OneMoveFromWinning(vm);
        vm.State.TimerSeconds = 100;

        Move(vm, 1, 0);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.State.IsTimerActive);
        Assert.Equal(104, vm.Foundations.Sum(f => f.Cards.Count));
        var s = Mode();
        Assert.Equal(1, s.GamesWon);
        Assert.Equal(1, s.CurrentStreak);
        Assert.Equal(1, s.LongestStreak);
        Assert.Equal(100, s.ShortestWinSeconds);
        Assert.Equal(100, s.TotalWinSeconds);
        Assert.Equal(1, s.TimedGamesWon);
        Assert.Equal(599, s.HighScore);
        Assert.False(vm.CanUndo);
        vm.Undo();
        Assert.True(vm.State.HasWon);

        // Saved: a relaunch still sees the win.
        new SpiderViewModel();
        Assert.Equal(1, Mode().GamesWon);
        Assert.Equal(100, Mode().ShortestWinSeconds);
    }

    [Fact]
    public void Win_InNoStressMode_CountsButRecordsNoTime_AndKeepsAHigherHighScore()
    {
        Options.IsNoStressMode = true;
        var vm = Fresh();
        Prime("1", new ModeStats { GamesPlayed = 1, HighScore = 700 });
        OneMoveFromWinning(vm);
        Move(vm, 1, 0);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.State.IsTimerActive);   // no clock in No Stress Mode
        var s = Mode();
        Assert.Equal(1, s.GamesWon);
        Assert.Equal(0, s.TimedGamesWon);
        Assert.Equal(0, s.TotalWinSeconds);
        Assert.Equal(0, s.ShortestWinSeconds);
        Assert.Equal(700, s.HighScore);
    }

    [Fact]
    public void TogglingNoStressMidGame_RecordsNoBestTimeForThatGame()
    {
        var vm = Fresh();
        Board(vm, Padded(Run(CardSuit.Spades, 13, 3), L(C(CardSuit.Spades, 2)), L(C(CardSuit.Spades, 1))), doneRuns: 7);
        Move(vm, 1, 0);
        Assert.True(vm.State.IsTimerActive);   // the first move starts the clock
        vm.State.TimerSeconds = 42;

        ChangeSharedOptions(o => o.IsNoStressMode = true);
        Assert.False(vm.State.IsTimerActive);
        ChangeSharedOptions(o => o.IsNoStressMode = false);

        Move(vm, 2, 0);
        Assert.True(vm.State.HasWon);
        Assert.Equal(1, Mode().GamesWon);
        Assert.Equal(0, Mode().TimedGamesWon);
        Assert.Equal(0, Mode().ShortestWinSeconds);
    }

    [Fact]
    public void Stats_ArePerSuitCount_AndResetClearsOnlyTheCurrentOne()
    {
        var vm = Fresh();
        OneMoveFromWinning(vm);
        Move(vm, 1, 0);
        Assert.Equal(1, Mode("1").GamesWon);

        Options.SpiderSuitCount = 2;
        vm.InitializeGame();
        OneMoveFromWinning(vm);
        Move(vm, 1, 0);
        Assert.Equal(1, Mode("2").GamesWon);
        Assert.Equal(1, Mode("1").GamesWon);   // a 2-suit win doesn't touch 1-suit stats

        vm.ResetStats();
        Assert.Equal(0, Mode("2").GamesWon);
        Assert.Equal(0, Mode("2").GamesPlayed);
        Assert.Equal(1, Mode("1").GamesWon);
        Assert.Equal(0, vm.Stats.SpiderStatsBySuit["2"].GamesWon);
    }

    [Fact]
    public void Streak_NewGameAfterPlaying_EvenAfterUndoOrRestart_BreaksIt()
    {
        SpiderViewModel Primed(int streak)
        {
            var vm = Fresh();
            Prime("1", new ModeStats { GamesPlayed = 1, CurrentStreak = streak, LongestStreak = streak });
            return vm;
        }
        void PlayOneMove(SpiderViewModel vm)
        {
            Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))));
            Move(vm, 0, 1);
        }

        var untouched = Primed(4);
        untouched.InitializeGame();
        Assert.Equal(4, Mode().CurrentStreak);

        var played = Primed(4);
        PlayOneMove(played);
        played.InitializeGame();
        Assert.Equal(0, Mode().CurrentStreak);
        Assert.Equal(4, Mode().LongestStreak);

        var undone = Primed(4);
        PlayOneMove(undone);
        undone.Undo();
        undone.InitializeGame();
        Assert.Equal(0, Mode().CurrentStreak);

        var restarted = Primed(4);
        PlayOneMove(restarted);
        restarted.RestartGame();
        restarted.InitializeGame();
        Assert.Equal(0, Mode().CurrentStreak);

        var won = Primed(0);
        OneMoveFromWinning(won);
        Move(won, 1, 0);
        int playedAtWin = Mode().GamesPlayed;
        won.InitializeGame();
        Assert.Equal(1, Mode().CurrentStreak);              // a won game isn't abandoned
        Assert.Equal(playedAtWin + 1, Mode().GamesPlayed);  // the new game counts
    }

    [Fact]
    public void Restart_ReplaysTheSameDeal_AndOnlyAWonGameCountsAsAnotherGamePlayed()
    {
        var vm = Fresh();
        var deal = Layout(vm);
        var stock = vm.StockPiles.SelectMany(p => p.Cards).Select(c => c.Id).ToList();
        int played = Mode().GamesPlayed;

        vm.DealFromStock();
        Assert.Equal(4, vm.StockPiles.Count);
        vm.RestartGame();
        Assert.Equal(deal, Layout(vm));
        Assert.Equal(stock, vm.StockPiles.SelectMany(p => p.Cards).Select(c => c.Id));
        Assert.Equal(500, vm.State.Score);
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.CanUndo);
        Assert.False(vm.State.IsTimerActive);
        Assert.Equal(played, Mode().GamesPlayed);

        OneMoveFromWinning(vm);
        Move(vm, 1, 0);
        Assert.True(vm.State.HasWon);
        vm.RestartGame();
        Assert.False(vm.State.HasWon);
        Assert.Equal(played + 1, Mode().GamesPlayed);
        Assert.Equal(1, Mode().CurrentStreak);
    }

    [Fact]
    public void SwitchingGames_PausesAndResumesARunningClockOnly()
    {
        var vm = Fresh();
        vm.PauseTimerForSwitch();
        vm.ResumeTimerForSwitch();
        Assert.False(vm.State.IsTimerActive);   // an unstarted game stays unstarted

        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))));
        Move(vm, 0, 1);
        Assert.True(vm.State.IsTimerActive);
        vm.PauseTimerForSwitch();
        Assert.False(vm.State.IsTimerActive);
        vm.ResumeTimerForSwitch();
        Assert.True(vm.State.IsTimerActive);
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
    public void Banners_TheTenthWinAcrossAllSuitCountsShowsTheMilestoneOnce()
    {
        var vm = Fresh();
        Drain(vm);
        Prime("1", new ModeStats { GamesPlayed = 7, GamesWon = 6 });
        Prime("2", new ModeStats { GamesPlayed = 3, GamesWon = 3 });

        OneMoveFromWinning(vm);
        Move(vm, 1, 0);   // the 10th win
        Assert.Equal(1, Queued(vm));
        var replayed = new List<string>();
        vm.OnFlashBanner += replayed.Add;
        vm.ReplayCurrentBanner();
        Assert.Single(replayed);
        Assert.Equal(1, Drain(vm));

        vm.InitializeGame();
        OneMoveFromWinning(vm);
        Move(vm, 1, 0);   // the 11th
        Assert.Equal(0, Drain(vm));
        vm.AdvanceBannerQueue();   // empty queue: harmless
    }

    // ── Undo ──────────────────────────────────────────────────────────────────

    [Fact]
    public void Undo_StepsBackOneActionAtATime_ClearsTheHint_AndKeepsTheClockRunning()
    {
        var vm = Fresh();
        vm.Undo();
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.CanUndo);

        Board(vm, Padded(L(C(CardSuit.Clubs, 9), C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))), FaceDownStock(10, CardSuit.Hearts, 3));
        var start = Layout(vm);
        Move(vm, 0, 1);
        vm.DealFromStock();
        vm.State.TimerSeconds = 30;
        Assert.Equal(2, vm.MovesCount);

        vm.FindHint();
        Assert.NotNull(vm.ActiveHint);
        vm.Undo();
        Assert.Null(vm.ActiveHint);
        Assert.Equal(30, vm.State.TimerSeconds);
        Assert.Single(vm.StockPiles);
        Assert.Equal(1, vm.MovesCount);

        vm.Undo();
        Assert.Equal(start, Layout(vm));
        Assert.Equal(0, vm.MovesCount);
        Assert.False(vm.CanUndo);
    }

    [Fact]
    public void Undo_PastAWinningMoveIsNotPossible_ButUndoBeforeTheWinRestoresTheFoundationCount()
    {
        var vm = Fresh();
        Board(vm, Padded(Run(CardSuit.Spades, 13, 3), L(C(CardSuit.Spades, 2)), L(C(CardSuit.Spades, 1))), doneRuns: 7);
        Move(vm, 1, 0);
        vm.Undo();
        Move(vm, 1, 0);
        Move(vm, 2, 0);
        Assert.True(vm.State.HasWon);   // the undo didn't lose track of the seven finished runs
    }

    // ── Stuck ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Stuck_OnlyWhenNoMoveNoDealAndNotWon()
    {
        var vm = Fresh();
        Board(vm, Kings());
        CheckDeadlock(vm);
        Assert.True(vm.HasNoMoves);

        Board(vm, Kings(), FaceDownStock(10));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // a dealable stock

        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))));
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // a legal move

        Board(vm, Kings());
        vm.State.HasWon = true;
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);   // won games are never stuck

        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))));
        Move(vm, 0, 1);
        Assert.False(vm.HasNoMoves);   // the emptied column can still take cards
        vm.Undo();
        Assert.False(vm.HasNoMoves);
    }

    // ── Autocomplete ──────────────────────────────────────────────────────────

    [Fact]
    public void Autocomplete_OfferedOnlyWhenPlayingItOutFinishesTheGame()
    {
        var vm = Fresh();
        Board(vm, new() { Run(CardSuit.Spades, 13, 2), L(C(CardSuit.Spades, 1)) }, FaceDownStock(1), doneRuns: 7);
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);   // cards still in the stock

        OneMoveFromWinning(vm);
        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);
        CheckDeadlock(vm);
        Assert.False(vm.HasNoMoves);

        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 13))));
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);   // can't be finished
        vm.Autocomplete();
        Assert.False(vm.IsAutoplayRunning);
        Assert.Equal(0, vm.MovesCount);

        Board(vm, new(), doneRuns: 8);
        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);
    }

    [Fact]
    public void Autocomplete_PlaysTheGameOutToAWin()
    {
        var vm = Fresh();
        Board(vm, new() { Run(CardSuit.Spades, 13, 3), L(C(CardSuit.Spades, 2)), L(C(CardSuit.Spades, 1)) }, doneRuns: 7);
        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);

        vm.Autocomplete();
        Assert.True(vm.IsAutoplayRunning);
        Assert.True(vm.CanUndo);
        RunAutocompleteSteps(vm);

        Assert.True(vm.State.HasWon);
        Assert.False(vm.IsAutoplayRunning);
        Assert.Equal(1, Mode().GamesWon);
        Assert.Equal(500 - 2 + 100, vm.State.Score);
        Assert.Null(vm.PointPopup);   // no popups while autoplaying
    }

    [Fact]
    public void Autocomplete_UndoReversesTheWholeRunInOneStep_AndAStaleTickDoesNothing()
    {
        var vm = Fresh();
        Board(vm, new() { Run(CardSuit.Spades, 13, 3), L(C(CardSuit.Spades, 2)), L(C(CardSuit.Spades, 1)) }, doneRuns: 7);
        var start = Layout(vm);
        CheckAutocomplete(vm);
        vm.Autocomplete();
        Reflect.Call(vm, "AnimateNextAutocompleteMove");
        Assert.Equal(12, vm.Tableaus[0].Cards.Count);

        vm.Undo();
        Assert.False(vm.IsAutoplayRunning);
        Assert.Equal(start, Layout(vm));
        Assert.Equal(500, vm.State.Score);

        Reflect.Call(vm, "AnimateNextAutocompleteMove");
        Assert.Equal(start, Layout(vm));
    }

    // ── Hints ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Hint_SuggestsTheMoveThatRevealsACard()
    {
        var vm = Fresh();
        var five = C(CardSuit.Hearts, 5);
        Board(vm, Padded(L(C(CardSuit.Clubs, 9, up: false), five), L(C(CardSuit.Spades, 6))));
        Assert.Null(vm.ActiveHint);

        vm.FindHint();
        Assert.Equal("Tableau_0", vm.ActiveHint!.SourcePileId);
        Assert.Equal("Tableau_1", vm.ActiveHint.TargetPileId);
        Assert.Equal(five.Id, vm.ActiveHint.Card.Id);

        vm.ClearHintCycle();
        Assert.Null(vm.ActiveHint);
    }

    [Fact]
    public void Hint_ParksACardOnAnEmptyColumnWhenThatRevealsOne()
    {
        var vm = Fresh();
        var cols = Kings();
        cols[0] = L(C(CardSuit.Clubs, 9, up: false), C(CardSuit.Hearts, 5));
        cols[1] = new();
        Board(vm, cols);
        vm.FindHint();
        Assert.Equal("Tableau_0", vm.ActiveHint!.SourcePileId);
        Assert.Equal("Tableau_1", vm.ActiveHint.TargetPileId);
    }

    [Fact]
    public void Hint_PrefersTheSameSuit_AndCyclesThroughEveryOption()
    {
        var vm = Fresh();
        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)), L(C(CardSuit.Hearts, 6))));

        vm.FindHint();
        Assert.Equal("Tableau_2", vm.ActiveHint!.TargetPileId);   // 5♥ on 6♥ first
        Assert.Equal(1, vm.ActiveHint.Index);
        Assert.Equal(2, vm.ActiveHint.Total);
        vm.FindHint();
        Assert.Equal("Tableau_1", vm.ActiveHint!.TargetPileId);
        Assert.Equal(2, vm.ActiveHint.Index);
        vm.FindHint();
        Assert.Equal(1, vm.ActiveHint!.Index);                      // wraps around
    }

    [Fact]
    public void Hint_FallsBackToDealOrNoMoves()
    {
        var vm = Fresh();
        Board(vm, Kings());
        vm.FindHint();
        Assert.Equal("no_move", vm.ActiveHint!.Card.Id);
        Assert.Equal("", vm.ActiveHint.SourcePileId);
        Assert.Equal("", vm.ActiveHint.TargetPileId);

        Board(vm, Kings(), FaceDownStock(10));
        vm.FindHint();
        Assert.Equal("deal", vm.ActiveHint!.Card.Id);

        // An empty column blocks the deal: the view shows "fill all empty columns" for this.
        var cols = Kings();
        cols[0] = new();
        Board(vm, cols, FaceDownStock(10));
        vm.FindHint();
        Assert.Equal("deal", vm.ActiveHint!.Card.Id);
        Assert.False(vm.CanDealFromStock);
    }

    [Fact]
    public void Hint_NeverSuggestsMovingTheLastCardStraightBack()
    {
        var vm = Fresh();
        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6)), L(C(CardSuit.Diamonds, 7)), L(C(CardSuit.Clubs, 6))));
        Move(vm, 0, 1);

        var seen = new List<(string, string)>();
        for (int i = 0; i < 6; i++)
        {
            vm.FindHint();
            seen.Add((vm.ActiveHint!.SourcePileId, vm.ActiveHint.TargetPileId));
        }
        Assert.NotEmpty(seen);
        Assert.DoesNotContain(("Tableau_1", "Tableau_0"), seen);
    }

    [Fact]
    public void Hint_ClearsWhenTheBoardChanges()
    {
        var vm = Fresh();
        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))), FaceDownStock(10));
        vm.FindHint();
        Assert.NotNull(vm.ActiveHint);
        Move(vm, 0, 1);
        Assert.Null(vm.ActiveHint);

        Board(vm, Kings(), FaceDownStock(10));
        vm.FindHint();
        vm.DealFromStock();
        Assert.Null(vm.ActiveHint);

        vm.FindHint();
        vm.InitializeGame();
        Assert.Null(vm.ActiveHint);
    }

    // ── Point popups ──────────────────────────────────────────────────────────

    [Fact]
    public void PointPopups_ShowMinusOneForAMove_Plus100ForARun_OnlyInHoneyMode()
    {
        var vm = Fresh();
        var five = C(CardSuit.Hearts, 5);
        Board(vm, Padded(L(five), L(C(CardSuit.Spades, 6))));
        Move(vm, 0, 1);
        Assert.Equal(new CardPointPopup(five.Id, "-1"), vm.PointPopup);
        vm.Undo();
        Assert.Null(vm.PointPopup);

        var ace = C(CardSuit.Spades, 1);
        Board(vm, Padded(Run(CardSuit.Spades, 13, 2), L(ace)));
        Move(vm, 1, 0);
        Assert.Equal(new CardPointPopup(ace.Id, "+100"), vm.PointPopup);

        Options.HoneyMode = false;
        Board(vm, Padded(L(C(CardSuit.Hearts, 5)), L(C(CardSuit.Spades, 6))));
        Move(vm, 0, 1);
        Assert.Null(vm.PointPopup);
    }

    // ── Felt colour ───────────────────────────────────────────────────────────

    [Fact]
    public void FeltColour_IsSavedForTheNextLaunch()
    {
        var vm = Fresh();
        vm.UpdateFeltColor(FeltColorTheme.Desert);
        ForgetCachedSettings();
        Assert.Equal(FeltColorTheme.Desert, SettingsService.LoadOptions().FeltColor);
    }
}
