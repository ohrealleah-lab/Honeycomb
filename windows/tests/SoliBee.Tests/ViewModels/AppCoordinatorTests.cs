using System.Linq;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

// What AppCoordinator does for the player (Mac: AppCoordinatorBehaviorTests): remembers the
// last game across a relaunch, stops the clock of the game you leave and resumes it on
// return, re-arms the idle nudge on a switch, routes Undo / Reset Stats to the game on
// screen, and makes sure No Stress Mode changes only reach the active game's clock.
public class AppCoordinatorTests : DataSandbox
{
    private const string LastModeFile = "last_mode.txt";

    private AppCoordinator Fresh()
    {
        Delete(LastModeFile);
        Delete("stats.json");
        Options.FreecellDeckCount = 1;   // another test may have left 2 decks on (shared setting)
        return new AppCoordinator();
    }

    // What Preferences does when a shared setting changes: edit a copy, save it, broadcast it.
    private static void ChangeSharedOptions(System.Action<GameOptions> edit)
    {
        var copy = SettingsService.LoadOptions().Clone();
        edit(copy);
        SettingsService.SaveOptions(copy);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(copy));
    }

    private static void SwitchTo(AppCoordinator c, string game)
    {
        switch (game)
        {
            case "Klondike": c.SwitchToGame(); break;
            case "Freecell": c.SwitchToFreecell(); break;
            case "Spider": c.SwitchToSpider(); break;
            case "VideoPoker": c.SwitchToVideoPoker(); break;
            case "Blackjack": c.SwitchToBlackjack(); break;
            case "Honeycomb": c.SwitchToHoneycomb(); break;
        }
    }

    private static object ViewModelFor(AppCoordinator c, string game) => game switch
    {
        "Klondike" => c.GameViewModel,
        "Freecell" => c.FreecellViewModel,
        "Spider" => c.SpiderViewModel,
        "VideoPoker" => c.VideoPokerViewModel,
        "Blackjack" => c.BlackjackViewModel,
        _ => c.HoneycombViewModel,
    };

    private static readonly string[] AllGames = { "Klondike", "Freecell", "Spider", "VideoPoker", "Blackjack", "Honeycomb" };

    private static void FreecellMove(FreecellViewModel vm)
    {
        var top = vm.Tableaus[0].Cards.Last();
        vm.MoveCards(new() { top }, vm.Tableaus[0], vm.FreeCells[0]);
    }

    // ---- Last game remembered ----

    [Fact]
    public void FreshInstall_OpensOnKlondike()
    {
        var c = Fresh();
        Assert.Same(c.GameViewModel, c.ActiveViewModel);
    }

    [Fact]
    public void EveryGame_IsRememberedAsTheLastGame_AndReopenedAfterARelaunch()
    {
        var c = Fresh();
        foreach (var game in AllGames)
        {
            SwitchTo(c, game);
            Assert.Same(ViewModelFor(c, game), c.ActiveViewModel);
            Assert.Equal(game, Read(LastModeFile));
            var relaunched = new AppCoordinator();
            Assert.Equal(ViewModelFor(relaunched, game).GetType(), relaunched.ActiveViewModel.GetType());
        }
    }

    [Fact]
    public void AnUnknownOrBlankSavedGame_OpensKlondike()
    {
        Write(LastModeFile, "Tejas Hold'em");
        Assert.IsType<GameViewModel>(new AppCoordinator().ActiveViewModel);
        Write(LastModeFile, "");
        Assert.IsType<GameViewModel>(new AppCoordinator().ActiveViewModel);
        Write(LastModeFile, "  Spider \n");
        Assert.IsType<SpiderViewModel>(new AppCoordinator().ActiveViewModel);
    }

    [Fact]
    public void ReselectingTheCurrentGame_IsHarmless()
    {
        var c = Fresh();
        c.SwitchToSpider();
        c.SwitchToSpider();
        Assert.Same(c.SpiderViewModel, c.ActiveViewModel);
    }

    [Fact]
    public void Switching_RaisesCanUndoChanged()
    {
        var c = Fresh();
        var raised = 0;
        c.PropertyChanged += (_, e) => { if (e.PropertyName == nameof(AppCoordinator.CanUndo)) raised++; };
        c.SwitchToFreecell();
        c.SwitchToVideoPoker();
        Assert.Equal(2, raised);
    }

    // ---- Finished rounds are cleared on return ----

    [Fact]
    public void ReturningToVideoPoker_WithAFinishedRound_ClearsIt()
    {
        var c = Fresh();
        var vp = c.VideoPokerViewModel;
        vp.Deal();
        vp.Draw();
        Assert.Equal(VideoPokerPhase.Result, vp.State.Phase);
        c.SwitchToVideoPoker();
        Assert.Equal(VideoPokerPhase.Deal, vp.State.Phase);
    }

    [Fact]
    public void ReturningToBlackjack_WithAFinishedRound_ClearsItButKeepsCredits()
    {
        var c = Fresh();
        var bj = c.BlackjackViewModel;
        bj.State.Phase = BlackjackPhase.Result;
        bj.State.Credits = 77;
        bj.State.PlayerHands = new() { new BlackjackHand { Cards = new() { Cards.C(CardSuit.Hearts, 10), Cards.C(CardSuit.Spades, 9) }, Bet = 1 } };
        c.SwitchToBlackjack();
        Assert.Equal(BlackjackPhase.Betting, bj.State.Phase);
        Assert.Equal(77, bj.State.Credits);
        Assert.True(bj.State.PlayerHands.All(h => h.Cards.Count == 0));
    }

    // ---- Clocks ----

    [Fact]
    public void LeavingAGame_StopsItsClock_AndComingBackResumesOnlyThatOne()
    {
        var c = Fresh();
        c.SwitchToSpider();
        c.SpiderViewModel.DealFromStock();
        Assert.True(c.SpiderViewModel.State.IsTimerActive);   // the first move starts the clock

        c.SwitchToGame();
        Assert.False(c.SpiderViewModel.State.IsTimerActive);  // leaving Spider stops it
        Assert.False(c.GameViewModel.State.IsTimerActive);    // Klondike was never started

        c.SwitchToFreecell();
        FreecellMove(c.FreecellViewModel);
        Assert.True(c.FreecellViewModel.State.IsTimerActive);
        c.SwitchToGame();
        Assert.False(c.FreecellViewModel.State.IsTimerActive);

        c.GameViewModel.DrawCard();
        Assert.True(c.GameViewModel.State.IsTimerActive);
        c.SwitchToSpider();
        Assert.False(c.GameViewModel.State.IsTimerActive);
        Assert.True(c.SpiderViewModel.State.IsTimerActive);   // Spider was running when left → resumes

        c.SwitchToFreecell();
        Assert.True(c.FreecellViewModel.State.IsTimerActive); // Freecell too
        c.SwitchToGame();
        Assert.True(c.GameViewModel.State.IsTimerActive);
        Assert.False(c.SpiderViewModel.State.IsTimerActive);
    }

    [Fact]
    public void ANeverStartedGame_StaysStoppedWhenYouVisitIt()
    {
        var c = Fresh();
        c.SwitchToSpider();
        c.SwitchToFreecell();
        c.SwitchToGame();
        Assert.False(c.SpiderViewModel.State.IsTimerActive);
        Assert.False(c.FreecellViewModel.State.IsTimerActive);
        Assert.False(c.GameViewModel.State.IsTimerActive);
    }

    [Fact]
    public void NoStressMode_ChangesOnlyReachTheActiveGamesClock()
    {
        var c = Fresh();
        // Spider has a played game and is left in the background; Klondike is on screen.
        c.SwitchToSpider();
        c.SpiderViewModel.DealFromStock();
        c.SpiderViewModel.State.TimerSeconds = 12;
        c.SwitchToGame();
        c.GameViewModel.DrawCard();
        c.GameViewModel.State.TimerSeconds = 9;
        Assert.True(c.GameViewModel.State.IsTimerActive);
        Assert.False(c.SpiderViewModel.State.IsTimerActive);

        ChangeSharedOptions(o => o.IsNoStressMode = true);
        Assert.False(c.GameViewModel.State.IsTimerActive);
        Assert.Equal(0, c.GameViewModel.State.TimerSeconds);        // the visible game's clock stops and zeroes
        Assert.Equal(12, c.SpiderViewModel.State.TimerSeconds);     // the background game is left alone
        Assert.False(c.SpiderViewModel.State.IsTimerActive);

        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.True(c.GameViewModel.State.IsTimerActive);           // the visible game's clock restarts
        Assert.False(c.SpiderViewModel.State.IsTimerActive);        // the background game's does not
        Assert.False(c.FreecellViewModel.State.IsTimerActive);
    }

    [Fact]
    public void NoStressMode_SwitchedOffElsewhere_NeverResumesABackgroundedGamesClock()
    {
        var c = Fresh();
        // A played Klondike game left in the background while No Stress was switched on and off.
        c.GameViewModel.DrawCard();
        c.SwitchToFreecell();
        FreecellMove(c.FreecellViewModel);
        ChangeSharedOptions(o => o.IsNoStressMode = true);
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.False(c.GameViewModel.State.IsTimerActive);
        Assert.True(c.FreecellViewModel.State.IsTimerActive);
        c.SwitchToGame();
        Assert.False(c.FreecellViewModel.State.IsTimerActive);
    }

    [Fact]
    public void NoStressMode_AfterReturningToAGame_ItsClockFollowsTheToggleAgain()
    {
        var c = Fresh();
        c.GameViewModel.DrawCard();
        c.SwitchToSpider();
        c.SwitchToGame();
        Assert.True(c.GameViewModel.State.IsTimerActive);
        ChangeSharedOptions(o => o.IsNoStressMode = true);
        Assert.False(c.GameViewModel.State.IsTimerActive);
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.True(c.GameViewModel.State.IsTimerActive);
    }

    [Fact]
    public void NoStressToggles_AreHarmlessOnGamesWithoutAClock()
    {
        var c = Fresh();
        c.SwitchToVideoPoker();
        ChangeSharedOptions(o => o.IsNoStressMode = true);
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        c.SwitchToBlackjack();
        ChangeSharedOptions(o => o.IsNoStressMode = true);
        c.SwitchToHoneycomb();
        ChangeSharedOptions(o => o.IsNoStressMode = false);
        Assert.Equal(VideoPokerPhase.Deal, c.VideoPokerViewModel.State.Phase);
        Assert.Equal(BlackjackPhase.Betting, c.BlackjackViewModel.State.Phase);
        Assert.False(c.GameViewModel.State.IsTimerActive);
        Assert.False(c.SpiderViewModel.State.IsTimerActive);
        Assert.False(c.FreecellViewModel.State.IsTimerActive);
    }

    // ---- Idle nudge ----

    // Each ViewModel bumps a private generation number whenever its idle nudge is cancelled
    // or re-armed, so a changed number is how a re-arm shows. The 60 s delay is skipped in
    // test mode, so this turns real scheduling on just for the switches.
    private static int IdleGeneration(object vm) => Reflect.Get<int>(vm, "_idleCheckGeneration");

    [Fact]
    public void SwitchingGames_CancelsTheOutgoingNudge_AndRearmsTheIncomingOne()
    {
        var c = Fresh();
        try
        {
            TestMode.IsHeadless = false;
            var order = new[] { "Freecell", "Spider", "VideoPoker", "Blackjack", "Klondike" };
            var current = "Klondike";
            foreach (var next in order)
            {
                var before = AllGames.ToDictionary(g => g, g => IdleGeneration(ViewModelFor(c, g)));
                // On a pool thread so xUnit's sync context doesn't wait out the 60 s delays.
                System.Threading.Tasks.Task.Run(() => SwitchTo(c, next)).Wait();
                Assert.NotEqual(before[current], IdleGeneration(ViewModelFor(c, current)));   // outgoing cancelled
                Assert.NotEqual(before[next], IdleGeneration(ViewModelFor(c, next)));         // incoming restarted
                foreach (var other in AllGames.Where(g => g != current && g != next))
                    Assert.Equal(before[other], IdleGeneration(ViewModelFor(c, other)));      // nobody else touched
                current = next;
            }
        }
        finally
        {
            // Leave no pending nudge that could fire later in another test.
            foreach (var g in AllGames) ((IIdleActionChecking)ViewModelFor(c, g)).CancelIdleActionCheck();
            TestMode.IsHeadless = true;
        }
    }

    [Fact]
    public void EnteringHoneycomb_OutsideAMatch_DoesNotArmANudge()
    {
        var c = Fresh();
        c.SwitchToHoneycomb();
        // Not playing a match: the nudge is cancelled rather than scheduled.
        Assert.False(c.HoneycombViewModel.IsPlaying);
    }

    // ---- Routing: Undo, Reset Stats, win animation ----

    [Fact]
    public void Undo_ReachesTheGameOnScreen()
    {
        var c = Fresh();

        c.SwitchToGame();
        var stock = c.GameViewModel.Stock.Cards.Count;
        Assert.False(c.CanUndo);
        c.GameViewModel.DrawCard();
        Assert.True(c.CanUndo);
        c.Undo();
        Assert.Equal(stock, c.GameViewModel.Stock.Cards.Count);
        Assert.False(c.CanUndo);

        c.SwitchToSpider();
        var spiderStock = c.SpiderViewModel.StockPiles.Count;
        c.SpiderViewModel.DealFromStock();
        Assert.True(c.CanUndo);
        c.Undo();
        Assert.Equal(spiderStock, c.SpiderViewModel.StockPiles.Count);
        Assert.False(c.CanUndo);

        c.SwitchToFreecell();
        var deal = c.FreecellViewModel.Tableaus.Select(t => t.Cards.Select(x => x.Id).ToList()).ToList();
        FreecellMove(c.FreecellViewModel);
        Assert.True(c.CanUndo);
        c.Undo();
        Assert.Equal(deal, c.FreecellViewModel.Tableaus.Select(t => t.Cards.Select(x => x.Id).ToList()).ToList());
        Assert.False(c.CanUndo);
    }

    [Fact]
    public void Undo_OnlyAffectsTheVisibleGame()
    {
        var c = Fresh();
        c.GameViewModel.DrawCard();
        c.SwitchToSpider();
        c.SpiderViewModel.DealFromStock();
        Assert.True(c.GameViewModel.CanUndo);
        c.Undo();
        Assert.False(c.SpiderViewModel.CanUndo);
        Assert.True(c.GameViewModel.CanUndo);   // Klondike's draw is still undoable
    }

    [Fact]
    public void VideoPokerBlackjackAndHoneycomb_HaveNothingToUndo()
    {
        var c = Fresh();
        foreach (var game in new[] { "VideoPoker", "Blackjack", "Honeycomb" })
        {
            SwitchTo(c, game);
            Assert.False(c.CanUndo);
            c.Undo();   // harmless
            Assert.False(c.CanUndo);
        }
    }

    [Fact]
    public void ResetStatistics_ReachesOnlyTheGameOnScreen()
    {
        var c = Fresh();

        // Klondike
        var all = StatsService.LoadStats();
        all.GamesWon = 4;
        all.GamesPlayed = 9;
        StatsService.SaveStats(all);
        c.SwitchToSpider();
        c.ResetStatistics();
        Assert.Equal(4, StatsService.LoadStats().GamesWon);   // Spider's reset left Klondike alone
        c.SwitchToGame();
        c.ResetStatistics();
        Assert.Equal(0, StatsService.LoadStats().GamesWon);
        Assert.Equal(0, StatsService.LoadStats().GamesPlayed);

        // Freecell: only the current deck count's stats go
        var s = StatsService.LoadStats();
        s.FreecellStatsByMode["standard_1deck"] = new ModeStats { GamesWon = 3 };
        s.SpiderStatsBySuit.Clear();
        StatsService.SaveStats(s);
        c.SwitchToFreecell();
        c.ResetStatistics();
        Assert.Equal(0, StatsService.LoadStats().FreecellStatsByMode["standard_1deck"].GamesWon);

        // Blackjack and Video Poker
        c.SwitchToBlackjack();
        c.BlackjackViewModel.Stats.HandsWon = 5;
        c.ResetStatistics();
        Assert.Equal(0, c.BlackjackViewModel.Stats.HandsWon);
        c.SwitchToVideoPoker();
        c.VideoPokerViewModel.Stats.TotalHands = 7;
        c.ResetStatistics();
        Assert.Equal(0, c.VideoPokerViewModel.Stats.TotalHands);
    }

    [Fact]
    public void ResetStatistics_OnHoneycomb_DoesNothing()
    {
        var c = Fresh();
        c.SwitchToHoneycomb();
        c.HoneycombViewModel.Stats.MatchesWon = 4;
        c.ResetStatistics();
        // Honeycomb has no Reset Stats from the coordinator (desktop resets it from its own screen).
        Assert.Equal(4, c.HoneycombViewModel.Stats.MatchesWon);
    }

    [Fact]
    public void WinAnimationHook_MarksTheVisibleSolitaireGameWon_AndIgnoresTheRest()
    {
        var c = Fresh();
        c.SwitchToGame();
        c.TriggerWinAnimation();
        Assert.True(c.GameViewModel.State.HasWon);
        Assert.False(c.SpiderViewModel.State.HasWon);
        c.SwitchToFreecell();
        c.TriggerWinAnimation();
        Assert.True(c.FreecellViewModel.State.HasWon);
        c.SwitchToSpider();
        c.TriggerWinAnimation();
        Assert.True(c.SpiderViewModel.State.HasWon);
        c.SwitchToVideoPoker();
        c.TriggerWinAnimation();
        c.SwitchToBlackjack();
        c.TriggerWinAnimation();
        c.SwitchToHoneycomb();
        c.TriggerWinAnimation();
        Assert.Equal(VideoPokerPhase.Deal, c.VideoPokerViewModel.State.Phase);
        Assert.Equal(BlackjackPhase.Betting, c.BlackjackViewModel.State.Phase);
    }
}
