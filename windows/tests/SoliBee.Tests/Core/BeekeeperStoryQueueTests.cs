using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Bee's 2026-11-12 play-test notes: story cards and visitors show one at a time in arrival order,
/// the gloves-fit card, the first shoe at a bear, the Hippies' 5th shoe, the Honey Dipper, and the Hive Log
/// waiting for the first bee.</summary>
public class BeekeeperStoryQueueTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;   // never stung by chance
        public int Next(int maxExclusive) => 0;
    }

    private static readonly BeekeeperConfig Cfg = new() { StartingHoneyCap = 1_000_000m };

    private static BeekeeperEngine Make(BeekeeperState s) => new(Cfg, s, new NoRandom());

    /// <summary>A started hive with no story due (the opening card done, no honey to pot).</summary>
    private static BeekeeperState Hive(Action<BeekeeperState>? tweak = null)
    {
        var s = new BeekeeperState
        {
            HoneyRevealed = true, BearName = "Bruno", StartingJarsGiven = true,
            StoriesDone = { BeekeeperStories.Opening },
        };
        tweak?.Invoke(s);
        return s;
    }

    private static bool Has(System.Collections.Generic.IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    // ============================================================ the queue

    [Fact]
    public void VisitorsAndCards_ShowOneAtATime_InTheOrderTheyArrive()
    {
        var e = Make(Hive(s => { s.BearRevealed = true; s.HippiesRevealed = true; }));
        e.AdvanceRepTime(1m);
        Assert.Equal(new[] { "bear" }, e.RepsPresent);
        Assert.Equal(new[] { "rep:hippies" }, e.StoryQueue);

        e.State.FirstStingDone = true;   // "Ouch!" is due now, after the Hippies arrived
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);        // the bear still holds the door
        Assert.Equal(new[] { "rep:hippies", BeekeeperStories.Ouch }, e.StoryQueue);

        e.EngageRep("bear");
        e.AdvanceStoryTime(1m);
        Assert.Equal(new[] { "hippies" }, e.RepsPresent);
        Assert.Null(e.StoryHere);

        e.EngageRep("hippies");
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);
        Assert.Empty(e.StoryQueue);
    }

    [Fact]
    public void AVisitorArrivingWhileACardIsUp_WaitsWithItsTimerPaused()
    {
        var e = Make(Hive(s =>
        {
            s.BearRevealed = true; s.RepsMet.Add("bear"); s.RepReturnIn["bear"] = 5m;
            s.Bees = 300m;   // the Smoker card is due
        }));
        e.AdvanceStoryTime(0m);
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);

        Assert.False(Has(e.AdvanceRepTime(10m), BeekeeperEvents.RepArrives));
        Assert.Equal(0m, e.State.RepReturnIn["bear"]);   // held at 0 while it waits
        Assert.Empty(e.RepsPresent);
        Assert.Equal(new[] { "rep:bear" }, e.StoryQueue);
        Assert.False(Has(e.AdvanceRepTime(500m), BeekeeperEvents.RepArrives));
        Assert.Empty(e.RepsPresent);

        Assert.True(e.RepairSmoker().Done);
        var events = e.AdvanceStoryTime(1m);
        Assert.Equal(new[] { "bear" }, e.RepsPresent);
        Assert.True(Has(events, BeekeeperEvents.RepArrives));   // the "back again" line is told when he is shown
        Assert.False(e.State.RepReturnIn.ContainsKey("bear"));
    }

    [Fact]
    public void ACardThatFadesByItself_HoldsTheQueueWhileItFades()
    {
        var e = Make(Hive(s => { s.BearRevealed = true; s.RepsMet.Add("bear"); s.RepReturnIn["bear"] = 1m; s.FirstStingDone = true; }));
        e.AdvanceStoryTime(0m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);
        e.AdvanceRepTime(1m);
        Assert.Empty(e.RepsPresent);
        e.AdvanceStoryTime(4m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);   // still fading
        Assert.Empty(e.RepsPresent);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
        Assert.Equal(new[] { "bear" }, e.RepsPresent);       // next in line, as soon as it has gone
    }

    [Fact]
    public void AnOlderSave_WithACardAndTwoVisitorsUp_KeepsTheCardAndQueuesTheVisitors()
    {
        var e = Make(Hive(s =>
        {
            s.Bees = 300m; s.StoryHere = BeekeeperStories.Smoker;
            s.BearRevealed = true; s.HippiesRevealed = true;
            s.RepsMet.AddRange(new[] { "bear", "hippies" });
            s.RepsPresent.AddRange(new[] { "bear", "hippies" });
        }));
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);
        Assert.Empty(e.RepsPresent);
        Assert.Equal(new[] { "rep:bear", "rep:hippies" }, e.StoryQueue);
    }

    [Fact]
    public void AWasp_WaitsItsTurnLikeAVisitor_WithItsTimePausedAndItsCountdownStartingWhenShown()
    {
        // Bee, 2026-11-14: the wasp is part of the story area now (it used to appear at once, in its own card).
        var e = Make(Hive(s => { s.WorkbenchRevealed = true; s.Bees = 1000m; s.Combs = 50; s.NextWaspInSeconds = 1m; }));
        e.AdvanceStoryTime(0m);
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);   // a card is up

        Assert.False(Has(e.AdvanceWaspTime(5m), BeekeeperEvents.WaspArrives));
        Assert.False(e.WaspApproaching);
        Assert.Contains("wasp", e.StoryQueue);
        Assert.False(Has(e.AdvanceWaspTime(100_000m), BeekeeperEvents.WaspArrives));   // paused while it waits
        Assert.False(e.WaspApproaching);
        Assert.Equal(0m, e.State.WaspCountdown);                                       // its countdown has not started

        Assert.True(e.RepairSmoker().Done);
        // Review fix (2026-11-15): story time alone (which also runs while nobody watches) doesn't bring it; wasp time does.
        Assert.False(Has(e.AdvanceStoryTime(1m), BeekeeperEvents.WaspArrives));
        var events = e.AdvanceWaspTime(1m);
        Assert.True(Has(events, BeekeeperEvents.WaspArrives));
        Assert.True(e.WaspApproaching);
        Assert.Equal(Cfg.WaspCountdownSeconds, e.State.WaspCountdown);
        Assert.True(e.StoryAreaBusy);                 // and it holds the door for what comes after
        Assert.DoesNotContain("wasp", e.StoryQueue);
    }

    [Fact]
    public void AQueuedWasp_NeverComesWhileNobodyWatches_AndTheQueueWaitsBehindIt()
    {
        // Review fix (2026-11-15): rep and story time run every tick, watched or not; they used to bring a queued
        // wasp to the door, and the next unwatched tick sent it off unseen, spending a visit (and the Engage choice).
        var e = Make(Hive(s =>
        {
            s.StoriesDone = BeekeeperStories.Order.ToList();
            s.WorkbenchRevealed = true; s.BearRevealed = true; s.RepsMet.Add("bear");
            s.StoryQueue.Add("wasp");
            s.StoryQueue.Add("rep:bear");
            s.RepReturnIn["bear"] = 0m;
        }));

        for (int i = 0; i < 600; i++)
        {
            Assert.False(Has(e.AdvanceRepTime(1m), BeekeeperEvents.WaspArrives));
            Assert.False(Has(e.AdvanceStoryTime(1m), BeekeeperEvents.WaspArrives));
        }
        Assert.False(e.WaspApproaching);
        Assert.Equal(0, e.State.WaspVisits);
        Assert.Empty(e.RepsPresent);                       // the bear waits behind the wasp
        Assert.Equal("wasp", e.StoryQueue[0]);

        Assert.True(Has(e.AdvanceWaspTime(1m), BeekeeperEvents.WaspArrives));   // watched again: it comes
        Assert.Equal(1, e.State.WaspVisits);
        Assert.True(e.CanEngageWasp);                      // the first visit's choice is still there
    }

    [Fact]
    public void EngagingAWasp_WithNoHoney_StealsNothing_AndSaysNoAmount()
    {
        var e = Make(Hive(s =>
        {
            s.StoriesDone = BeekeeperStories.Order.ToList();
            s.WorkbenchRevealed = true; s.Honey = 0m;
        }));
        e.DebugCallWasp();
        var ev = Assert.Single(e.EngageWasp().Events);
        Assert.Equal(0m, ev.Value);
        Assert.Equal(0m, e.State.Honey);
    }

    [Fact]
    public void EngagingAWasp_AlwaysLetsItStealHoney_TheSameAmountAsIfLeftAlone()
    {
        BeekeeperEngine Wasp() => Make(Hive(s =>
        {
            s.StoriesDone = BeekeeperStories.Order.ToList();
            s.WorkbenchRevealed = true; s.Bees = 1000m; s.Combs = 50; s.Honey = 10_000m;
        }));

        var left = Wasp();
        left.DebugCallWasp();
        decimal before = left.State.Honey;
        var raid = left.AdvanceWaspCountdown(Cfg.WaspCountdownSeconds).Single();
        decimal stolenWhenLeftAlone = before - left.State.Honey;
        Assert.True(stolenWhenLeftAlone > 0m);

        var e = Wasp();
        e.DebugCallWasp();
        Assert.True(e.CanEngageWasp);
        var r = e.EngageWasp();
        Assert.True(r.Done);
        Assert.Equal(10_000m - stolenWhenLeftAlone, e.State.Honey);
        var ev = Assert.Single(r.Events);
        Assert.Equal(BeekeeperEvents.WaspEngaged, ev.Key);
        Assert.Equal(stolenWhenLeftAlone, ev.Value);
        Assert.False(e.WaspApproaching);
        Assert.Equal(0, e.State.BribesTotal);   // it is not a bribe
        Assert.Equal(BeekeeperEvents.WaspRaid, raid.Key);
    }

    // ============================================================ the cards

    [Fact]
    public void TheGlovesFitCard_FollowsTheGloves_AndGoesAfterSixBees()
    {
        var e = Make(Hive(s => s.BeesCaught = 30));
        e.AdvanceStoryTime(0m);
        Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);
        Assert.True(Has(e.PutOnGloves().Events, BeekeeperEvents.GlovesOn));   // its log line stays
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.GlovesFit, e.StoryHere);
        e.Catch();
        e.Catch();
        Assert.Equal(BeekeeperStories.GlovesFit, e.StoryHere);   // 4 bees so far
        e.Catch();                                                // 6: it goes by itself
        Assert.Null(e.StoryHere);
        Assert.Contains(BeekeeperStories.GlovesFit, e.State.StoriesDone);
    }

    [Fact]
    public void TheFirstShoeAtABear_BringsAFadingCardOnce_AndEveryThrowSaysHeWandersOff()
    {
        var e = Make(Hive(s => { s.BearRevealed = true; s.RepsMet.Add("bear"); s.RepsPresent.Add("bear"); }));
        Assert.True(Has(e.ThrowShoeAtRep("bear").Events, BeekeeperEvents.RepLeft));
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.BearShoe, e.StoryHere);
        Assert.False(e.CraftFromStory().Done);      // no button: nothing answers it
        Assert.False(e.PutOnGloves().Done);
        e.AdvanceStoryTime(Cfg.BearShoeCardSeconds);
        Assert.Null(e.StoryHere);

        e.AdvanceRepTime(Cfg.RepReturnSeconds);
        Assert.Equal(new[] { "bear" }, e.RepsPresent);
        Assert.True(Has(e.ThrowShoeAtRep("bear").Events, BeekeeperEvents.RepLeft));
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);   // once only
    }

    [Fact]
    public void TheHippiesFifthShoe_SendsThemAwayForGood_WithAFadingCard_AndTheFlagIsSaved()
    {
        var e = Make(Hive(s => { s.HippiesRevealed = true; s.RepsMet.Add("hippies"); s.RepsPresent.Add("hippies"); }));
        for (int i = 1; i <= 4; i++)
        {
            Assert.True(Has(e.ThrowShoeAtRep("hippies").Events, BeekeeperEvents.RepLeft));
            Assert.Equal(i, e.State.HippieShoes);
            e.AdvanceRepTime(Cfg.RepReturnSeconds);
            Assert.Equal(new[] { "hippies" }, e.RepsPresent);   // back again
        }
        var fifth = e.ThrowShoeAtRep("hippies");
        Assert.True(fifth.Done);
        Assert.False(Has(fifth.Events, BeekeeperEvents.RepLeft));   // no "back later": the card speaks
        Assert.True(e.State.HippiesDismissedForGood);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.HippiesGone, e.StoryHere);
        e.AdvanceStoryTime(Cfg.HippiesGoneCardSeconds);
        Assert.Null(e.StoryHere);
        e.AdvanceRepTime(100_000m);
        e.AdvanceStoryTime(1m);
        Assert.Empty(e.RepsPresent);   // never again

        string path = Path.Combine(Path.GetTempPath(), "bk-hippies-" + Guid.NewGuid().ToString("N") + ".json");
        try
        {
            Assert.True(BeekeeperSaveService.Save(e.State, path, DateTime.UtcNow));
            var loaded = BeekeeperSaveService.Load(path, out _);
            Assert.NotNull(loaded);
            Assert.True(loaded!.HippiesDismissedForGood);
            Assert.Equal(5, loaded.HippieShoes);
        }
        finally { File.Delete(path); }
    }

    // ============================================================ the Shop's first buys

    [Fact]
    public void TheHoneyDipperAndTheMeshNet_Cost80_AndTheDipperGivesHalfAgainTheHoney()
    {
        var e = Make(Hive(s => { s.ShopRevealed = true; s.ToolLevel = 1; s.Beebits = 160m; }));
        Assert.Equal(BeekeeperUpgrades.HoneyDipper, e.ShopUpgrades.First().Id);
        Assert.Equal(80m, e.NextTool!.Cost);
        decimal before = e.HoneyPerSecond;
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.HoneyDipper).Done);
        Assert.Equal(80m, e.State.Beebits);
        Assert.Equal(before * 1.5m, e.HoneyPerSecond);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.HoneyDipper);
        Assert.True(e.BuyNextTool().Done);   // and the Mesh Net is still the next goal
        Assert.Equal(0m, e.State.Beebits);
    }

    [Fact]
    public void TheWaxCatcher_Costs120_AndAddsWaxRoom()
    {
        var e = Make(Hive(s => { s.ShopRevealed = true; s.Beebits = 119m; }));
        Assert.False(e.CanBuyWaxCatcher);
        e.State.Beebits = 120m;
        decimal rate = e.WaxPerSecondNow;
        Assert.True(e.BuyWaxCatcher().Done);
        Assert.Equal(Cfg.StartingWaxCap + Cfg.WaxCatcherWaxCap, e.WaxStorage);
        Assert.Equal(rate, e.WaxPerSecondNow);
    }

    // ============================================================ the screen's values

    [Fact]
    public void TheHiveLog_WaitsForTheFirstBee_AndPotLinksAreOnThePottedHoneyRow()
    {
        var vm = new BeekeeperViewModel(isHeadless: true, rng: new NoRandom(), persist: false);
        Assert.False(vm.LogCardShown);
        vm.Catch();
        Assert.True(vm.LogCardShown);
        Assert.Equal(BeekeeperEvents.FirstBee, vm.Log[0].Key);
        Assert.Equal(BeekeeperEvents.NewGame, vm.Log[1].Key);   // the same first line, then the catch

        Assert.Equal(BeekeeperStories.PotHoney, BeekeeperViewModel.CraftOfRow(BeekeeperHiveRows.PottedHoney));
        Assert.Null(BeekeeperViewModel.CraftOfRow(BeekeeperHiveRows.Honey));
    }
}
