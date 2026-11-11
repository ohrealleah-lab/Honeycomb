using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Story cards (Bee, 2026-11-11): the gloves are found, the Smoker is repaired; one card at a time.</summary>
public class BeekeeperStoryTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-story-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class FakeRandom : IRandomSource
    {
        private readonly Queue<double> _doubles;
        public FakeRandom(params double[] doubles) => _doubles = new Queue<double>(doubles);
        public double NextDouble() => _doubles.Count > 0 ? _doubles.Dequeue() : 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperEngine Make(BeekeeperState? state = null, params double[] dice)
        => new(BeekeeperConfig.Default, state, new FakeRandom(dice));

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    // ============================================================ the first sting ("Ouch!")

    [Fact]
    public void BareHands_NeverSting_BeforeTenBeesCaught()
    {
        var e = Make(new BeekeeperState(), Enumerable.Repeat(0.0, 20).ToArray());   // every roll would sting
        for (int i = 0; i < 10; i++) Assert.False(e.Catch().Stung);
        Assert.Equal(10, e.State.BeesCaught);
    }

    [Fact]
    public void TheFirstSting_AtTenBees_IsCertain_AndBringsTheOuchCard()
    {
        var e = Make(new BeekeeperState { BeesCaught = 10 }, 0.99);   // the dice would say no
        Assert.True(e.Catch().Stung);
        Assert.True(e.State.FirstStingDone);

        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);
        Assert.False(e.PutOnGloves().Done);
        e.AdvanceStoryTime(4m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);   // still there: it has no button
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);                            // gone by itself after 5 seconds of play
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);   // said once

        Assert.False(e.Catch().Stung);   // after the first, it is the 20% chance again
    }

    [Fact]
    public void Ouch_ComesBeforeTheGloves_WhenBothAreDue()
    {
        var e = Make(new BeekeeperState { BeesCaught = 100, FirstStingDone = true });
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);
        e.AdvanceStoryTime(5m);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);
    }

    // ============================================================ gloves

    [Fact]
    public void Gloves_AreDueAt30BeesCaughtByHand_NotBefore()
    {
        var e = Make(new BeekeeperState { BeesCaught = 29 });
        Assert.Empty(e.AdvanceStoryTime(1m));
        Assert.Null(e.StoryHere);

        e.State.BeesCaught = 30;
        var events = e.AdvanceStoryTime(1m);
        Assert.True(Has(events, BeekeeperEvents.StoryArrives));
        Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);
    }

    [Fact]
    public void Catching_CountsBeesCaughtByHand_NotStings()
    {
        var e = Make(new BeekeeperState { BeesCaught = 10, FirstStingDone = true }, 0.0, 0.99);   // a sting, then a catch
        Assert.True(e.Catch().Stung);
        Assert.Equal(10, e.State.BeesCaught);
        Assert.False(e.Catch().Stung);
        Assert.Equal(11, e.State.BeesCaught);
    }

    [Fact]
    public void Yes_PutsTheGlovesOn_AndStopsTheStings()
    {
        var e = Make(new BeekeeperState { BeesCaught = 100 });
        e.AdvanceStoryTime(1m);
        var result = e.PutOnGloves();
        Assert.True(result.Done);
        Assert.True(Has(result.Events, BeekeeperEvents.GlovesOn));
        Assert.Equal(1, e.State.ToolLevel);
        Assert.Equal(2, e.BeesPerClick);
        Assert.Null(e.StoryHere);
        Assert.Contains(BeekeeperStories.Gloves, e.State.StoriesDone);

        var catchResult = Make(e.State, 0.0).Catch();   // a "sting" roll that never matters now
        Assert.False(catchResult.Stung);
    }

    [Fact]
    public void No_ComesBackAfter120SecondsOfPlay()
    {
        var e = Make(new BeekeeperState { BeesCaught = 100 });
        e.AdvanceStoryTime(1m);
        Assert.True(e.LeaveGloves().Done);
        Assert.Null(e.StoryHere);
        Assert.Equal(0, e.State.ToolLevel);
        Assert.Equal(1, e.State.GlovesDeclines);

        e.AdvanceStoryTime(119m);
        Assert.Null(e.StoryHere);
        var events = e.AdvanceStoryTime(1m);
        Assert.True(Has(events, BeekeeperEvents.StoryArrives));
        Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);
    }

    [Fact]
    public void TheFifthNo_PutsTheGlovesAwayForGood_AndSetsTheFlag()
    {
        var e = Make(new BeekeeperState { BeesCaught = 100 });
        for (int i = 1; i <= 4; i++)
        {
            e.AdvanceStoryTime(121m);
            Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);
            var r = e.LeaveGloves();
            Assert.False(Has(r.Events, BeekeeperEvents.GlovesGone));
        }
        Assert.False(e.State.GlovesRefusedForGood);

        e.AdvanceStoryTime(121m);
        var fifth = e.LeaveGloves();
        Assert.True(Has(fifth.Events, BeekeeperEvents.GlovesGone));
        Assert.True(e.State.GlovesRefusedForGood);
        Assert.Equal(5, e.State.GlovesDeclines);

        e.AdvanceStoryTime(10_000m);
        Assert.Null(e.StoryHere);
        Assert.Equal(0, e.State.ToolLevel);
    }

    [Fact]
    public void Answers_AreRefused_UnlessTheirCardIsShowing()
    {
        var e = Make(new BeekeeperState { BeesCaught = 5 });
        Assert.False(e.PutOnGloves().Done);
        Assert.False(e.LeaveGloves().Done);
        Assert.False(e.RepairSmoker().Done);
        Assert.Equal(0, e.State.ToolLevel);
        Assert.False(e.Owns(BeekeeperUpgrades.Smoker));
    }

    [Fact]
    public void NoCatchingToolCanBeBought_WithoutTheGloves()
    {
        var e = Make(new BeekeeperState { Beebits = 1_000_000m, ShopRevealed = true });
        Assert.False(e.CanBuyNextTool);
        Assert.False(e.BuyNextTool().Done);
        Assert.Equal(0, e.State.ToolLevel);
    }

    // ============================================================ the Smoker

    [Fact]
    public void Smoker_IsDueAt250BeesInTheHive()
    {
        var e = Make(new BeekeeperState { ToolLevel = 1, Bees = 249m });
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);

        e.State.Bees = 250m;
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);
    }

    [Fact]
    public void Smoker_CardStays_WhenBeesDrop()
    {
        var e = Make(new BeekeeperState { ToolLevel = 1, Bees = 250m });
        e.AdvanceStoryTime(1m);
        e.State.Bees = 5m;   // a comb took the bees in
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);
    }

    [Fact]
    public void Repair_IsFree_MakesTheSmokerWork_AndItLeavesTheShop()
    {
        var e = Make(new BeekeeperState { ToolLevel = 1, Bees = 250m, Beebits = 0m, ShopRevealed = true });
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Smoker);   // never sold
        e.AdvanceStoryTime(1m);

        var result = e.RepairSmoker();
        Assert.True(result.Done);
        Assert.True(Has(result.Events, BeekeeperEvents.SmokerRepaired));
        Assert.True(e.CanUseSmoker);
        Assert.True(e.UseSmoker().Done);
        Assert.Equal(0m, e.State.Beebits);
        Assert.Null(e.StoryHere);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Smoker);
        Assert.False(e.CanBuyUpgrade(BeekeeperUpgrades.Smoker));

        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);   // answered for good
    }

    // ============================================================ one at a time

    [Fact]
    public void WhenBothAreDue_GlovesShowFirst_AndTheSmokerFollowsAfterTheAnswer()
    {
        var e = Make(new BeekeeperState { BeesCaught = 100, Bees = 300m });
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Gloves, e.StoryHere);   // still the gloves; no second card

        e.PutOnGloves();
        Assert.Null(e.StoryHere);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);
    }

    [Fact]
    public void ADeclinedGloves_DoNotHoldBackTheSmoker()
    {
        var e = Make(new BeekeeperState { BeesCaught = 100, Bees = 300m });
        e.AdvanceStoryTime(1m);
        e.LeaveGloves();
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Smoker, e.StoryHere);
    }

    // ============================================================ old saves and saving

    [Fact]
    public void AnOldSave_ThatAlreadyHasTheGlovesOrTheSmoker_NeverSeesThoseCards()
    {
        var state = new BeekeeperState { ToolLevel = 2, BeesCaught = 0, Bees = 5_000m };
        state.Upgrades.Add(BeekeeperUpgrades.Smoker);
        var e = Make(state);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
    }

    [Fact]
    public void TheStoryFields_SaveAndLoad()
    {
        var path = Path.Combine(_dir, "beekeeper.json");
        var state = new BeekeeperState
        {
            Version = BeekeeperSaveService.CurrentVersion,
            StoryHere = BeekeeperStories.Smoker,
            BeesCaught = 123,
            GlovesDeclines = 3,
            GlovesRefusedForGood = false,
        };
        state.StoriesDone.Add("gloves");
        state.StoryReturnIn["gloves"] = 42m;
        Assert.True(BeekeeperSaveService.Save(state, path, new DateTime(2026, 11, 11, 12, 0, 0, DateTimeKind.Utc)));

        var loaded = BeekeeperSaveService.Load(path);
        Assert.NotNull(loaded);
        Assert.Equal(BeekeeperStories.Smoker, loaded!.StoryHere);
        Assert.Equal(123, loaded.BeesCaught);
        Assert.Equal(3, loaded.GlovesDeclines);
        Assert.Contains("gloves", loaded.StoriesDone);
        Assert.Equal(42m, loaded.StoryReturnIn["gloves"]);
    }

    [Fact]
    public void ADamagedStoryField_IsRefusedAsInsane()
    {
        var path = Path.Combine(_dir, "bad.json");
        var state = new BeekeeperState { Version = BeekeeperSaveService.CurrentVersion, GlovesDeclines = 99 };
        Assert.True(BeekeeperSaveService.Save(state, path, new DateTime(2026, 11, 11, 12, 0, 0, DateTimeKind.Utc)));
        Assert.Null(BeekeeperSaveService.Load(path));
    }
}
