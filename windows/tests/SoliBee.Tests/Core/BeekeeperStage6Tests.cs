using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 6 rules (spec 014): specialties, honey-only raids, bribes, the emissary, paper,
/// repellent candles retired, save version 6.</summary>
public class BeekeeperStage6Tests : IDisposable
{
    private const int Places = 6;
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage6-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    /// <summary>0.99: shoes always miss, wasps come late.</summary>
    private sealed class FakeRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    // Cut in stage 7.5 (spec 016): private static readonly BeekeeperConfig BigCombs = new() { StartingStorage = 100_000_000m };
    private static readonly BeekeeperConfig BigCombs = new() { StartingHoneyCap = 100_000_000m, StartingWaxCap = 100_000_000m };

    private static BeekeeperEngine Make(BeekeeperState? state = null, BeekeeperConfig? config = null)
        => new(config ?? BeekeeperConfig.Default, state, new FakeRandom());

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    private static BeekeeperState Garden(params string[] plants)
    {
        var s = new BeekeeperState { GardenRevealed = true };
        // Cut in stage 7.5 (spec 016): SeedsGiven = plants.Length, SeedsPlanted = plants.Length (no longer saved).
        s.Plants.AddRange(plants);
        return s;
    }

    // ============================================================ foraging (User Story 1)

    [Fact]
    public void Wildflowers_GiveForaging_ThreePollenAMinute()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        Assert.Equal(new[] { BeekeeperSpecialties.Foraging }, e.Specialties);
        Assert.True(e.HasSpecialty(BeekeeperSpecialties.Foraging));
        Assert.False(e.HasSpecialty(BeekeeperSpecialties.Guarding));
        Assert.Equal(0.05m, e.PollenPerSecondNow);
        e.Advance(60m);
        Assert.Equal(3m, e.State.Pollen);
    }

    [Fact]
    public void Foraging_IsSteady_ItDoesNotGrowOverTime()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        e.Advance(600m);
        Assert.Equal(30m, e.State.Pollen);
        e.Advance(600m);
        Assert.Equal(60m, e.State.Pollen);
        // Cut in stage 7.5 (spec 016): Assert.Equal(0m, e.State.ForagerBees);   // no counts any more
    }

    [Fact]
    public void Foraging_WhileAway_UpToTheThreeDayLimit()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        e.AdvanceAway(8m * 3600m);
        Assert.Equal(1440m, e.State.Pollen);
        var f = Make(Garden(BeekeeperPlants.Wildflowers));
        f.AdvanceAway(10m * 24m * 3600m);
        Assert.Equal(3m * 24m * 60m * 3m, f.State.Pollen);   // only 3 days count
    }

    [Fact]
    public void ThePollenRate_BelongsToThePlant_AndForagingPlantsAddUp()
    {
        var config = new BeekeeperConfig
        {
            Plants = new[]
            {
                new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperSpecialties.Foraging, 3m),
                new BeekeeperPlant(BeekeeperPlants.Bramble, 10, BeekeeperSpecialties.Foraging, 2m),
            },
        };
        var e = Make(Garden(BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble), config);
        Assert.Equal(5m, e.ForagingPollenPerMinute);
        Assert.Single(e.Specialties);
        e.Advance(60m);
        Assert.Equal(5m, e.State.Pollen);
    }

    // ============================================================ guarding (User Story 2)

    [Fact]
    public void Bramble_GivesGuarding_AQuarterMoreHoney()
    {
        // Stage 7.5 (spec 016): 50 combs make 10 honey a second.
        var e = Make(new BeekeeperState { HoneyRevealed = true, Combs = 50, Plants = { BeekeeperPlants.Bramble } }, BigCombs);
        Assert.Equal(new[] { BeekeeperSpecialties.Guarding }, e.Specialties);
        Assert.Equal(1.25m, e.HiveMultiplier);
        Assert.Equal(12.5m, e.HoneyPerSecond);        // 50 combs × 0.2 × 1.25
        Assert.Equal(12.5m, e.HoneyPerSecondNow);     // the hover rate sees it
        e.Advance(10m);
        Assert.Equal(125m, e.State.Honey);
    }

    [Fact]
    public void Guarding_MultipliesWithTheWoodenHive_AndGuardingPlantsMultiply()
    {
        var wooden = Make(new BeekeeperState { Bees = 1000m, HasWoodenHive = true, Plants = { BeekeeperPlants.Bramble } });
        Assert.Equal(1.5625m, wooden.HiveMultiplier);

        var config = new BeekeeperConfig
        {
            Plants = new[]
            {
                new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperSpecialties.Guarding, 1.25m),
                new BeekeeperPlant(BeekeeperPlants.Bramble, 10, BeekeeperSpecialties.Guarding, 1.25m),
            },
        };
        var two = Make(Garden(BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble), config);
        Assert.Equal(1.5625m, two.GuardingMultiplier);
    }

    [Fact]
    public void Guarding_CountsWhileAwayToo()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true, Combs = 50, Plants = { BeekeeperPlants.Bramble } }, BigCombs);
        e.AdvanceAway(100m);
        Assert.Equal(1250m, e.State.Honey);
    }

    [Fact]
    public void Guarding_CountsOnlyFromTheMomentTheBrambleSprouts()
    {
        var s = Garden(BeekeeperPlants.Wildflowers);
        s.HoneyRevealed = true;
        s.Combs = 50;   // stage 7.5: 10 honey a second from the combs (was 1,000 bees)
        s.Beds.Add(new BeekeeperBed { PlantId = BeekeeperPlants.Bramble, SecondsLeft = 60m });   // the bramble is growing
        var e = Make(s, BigCombs);
        e.AdvanceAway(120m);
        // 60 s at 10 honey/s, then 60 s at 12.5 honey/s
        Assert.Equal(1350m, e.State.Honey);
        Assert.Equal(6m, e.State.Pollen);   // foraging the whole time
    }

    // ============================================================ live and away agree (FR-504)

    private static BeekeeperState Busy() => new()
    {
        Bees = 1000m, HasWoodenHive = true, QueenSettled = true, BeeBread = 5m, BeeBreadRevealed = true,
        HoneyRevealed = true, Plants = { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble },
        GardenRevealed = true, Combs = 50,
        // Cut in stage 7.5 (spec 016): SeedsGiven = 2, SeedsPlanted = 2,
    };

    private static void AssertSame(BeekeeperEngine live, BeekeeperEngine away)
    {
        Assert.Equal((double)away.State.Honey, (double)live.State.Honey, Places);
        Assert.Equal((double)away.State.Bees, (double)live.State.Bees, Places);
        Assert.Equal((double)away.State.Pollen, (double)live.State.Pollen, Places);
        Assert.Equal((double)away.State.BeeBread, (double)live.State.BeeBread, Places);
        // Stage 7.5: wax is fractional now, so it compares like honey (to 6 places).
        Assert.Equal((double)away.State.Wax, (double)live.State.Wax, 6);
    }

    [Fact]
    public void ForagingGuardingAndALayingQueen_SameLiveInSecondsOrOneAwayStep()
    {
        var live = Make(Busy(), BigCombs);
        for (int i = 0; i < 1800; i++) live.Advance(1m);   // the pantry runs out part-way (500 bees)
        var away = Make(Busy(), BigCombs);
        away.AdvanceAway(1800m);
        AssertSame(live, away);
        Assert.True(live.State.Pollen > 0m && live.State.Honey > 0m);
    }

    [Fact]
    public void TheBrambleSproutingPartWay_SameLiveOrAway()
    {
        BeekeeperState Start()
        {
            var s = Busy();
            s.Plants.Remove(BeekeeperPlants.Bramble);
            s.Beds.Add(new BeekeeperBed { PlantId = BeekeeperPlants.Bramble, SecondsLeft = 400m });   // the bramble sprouts part-way
            return s;
        }
        var live = Make(Start(), BigCombs);
        for (int i = 0; i < 1200; i++) live.Advance(1m);
        var away = Make(Start(), BigCombs);
        away.AdvanceAway(1200m);
        AssertSame(live, away);
        Assert.Equal(away.State.Plants, live.State.Plants);
        Assert.Contains(BeekeeperPlants.Bramble, live.State.Plants);
    }

    // ============================================================ old saves (User Story 3)

    // Cut in stage 7.5 (spec 016): older saves no longer load, so their counts are never announced.
    // [Fact]
    // public void AnOldSavesCounts_BecomeSpecialties_AndAreAnnouncedOnce()
    // {
    //     var s = Garden(BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble);
    //     s.ForagerBees = 40m;
    //     s.GuardBees = 12m;
    //     var e = Make(s);
    //     Assert.Equal(new[] { BeekeeperSpecialties.Foraging, BeekeeperSpecialties.Guarding }, e.Specialties);
    //     Assert.True(Has(e.RevealOnLoad(), BeekeeperEvents.OldCountsSettle));
    //     Assert.False(Has(e.RevealOnLoad(), BeekeeperEvents.OldCountsSettle));
    //     Assert.Equal(40m, e.State.ForagerBees);   // kept in the save, unused
    // }

    // Cut in stage 7.5 (spec 016): older saves no longer load, so their counts are never announced.
    // [Fact]
    // public void NoCounts_NoAnnouncement()
    // {
    //     var e = Make(Garden(BeekeeperPlants.Wildflowers));
    //     Assert.False(Has(e.RevealOnLoad(), BeekeeperEvents.OldCountsSettle));
    //     Assert.True(e.State.OldCountsAnnounced);
    // }

    // Cut in stage 7.5 (spec 016): older saves start a new game (BeekeeperSaveTests).
    // [Fact]
    // public void AVersion5Save_LoadsWithNothingLost_AndNoBribesYet()
    // {
    //     Directory.CreateDirectory(_dir);
    //     var path = Path.Combine(_dir, "v5.json");
    //     File.WriteAllText(path, "{\"Version\":5,\"Bees\":5000,\"Honey\":120.5,\"Wax\":30,\"BearName\":\"Bruno\","
    //         + "\"Seeds\":1,\"SeedsGiven\":2,\"SeedsPlanted\":2,\"GrowSecondsLeft\":125,\"Plants\":[\"wildflowers\"],"
    //         + "\"ForagerBees\":33,\"GuardBees\":0,\"Pollen\":17.5,\"BeeBread\":6,\"HasWoodenHive\":true,\"QueenSettled\":true,"
    //         + "\"RepellentUnlocked\":true,\"RepellentCandles\":4,\"Log\":[]}");
    //     var s = BeekeeperSaveService.Load(path)!;
    //     Assert.NotNull(s);
    //     Assert.Equal(5000m, s.Bees);
    //     Assert.Equal(1, s.Seeds);
    //     Assert.Equal(125m, s.GrowSecondsLeft);
    //     Assert.Equal(17.5m, s.Pollen);
    //     Assert.Equal(6m, s.BeeBread);
    //     Assert.True(s.QueenSettled);
    //     Assert.Equal(4m, s.RepellentCandles);
    //     Assert.Equal(0, s.BribesTotal);
    //     Assert.False(s.EmissaryCome);
    //     Assert.Equal(0m, s.Paper);
    //
    //     var e = Make(s);
    //     Assert.True(Has(e.RevealOnLoad(), BeekeeperEvents.OldCountsSettle));
    //     // Stage 7: the growing seed went into bed 1, time kept; the seed order was plant order.
    //     Assert.Equal(BeekeeperPlants.Bramble, Assert.Single(e.State.Beds).PlantId);
    //     Assert.Equal(125m, e.State.Beds[0].SecondsLeft);
    // }

    [Fact]
    public void Stage6Fields_SurviveASave_AndBadNumbersAreRefused()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "v6.json");
        var s = new BeekeeperState { BribesTotal = 5, EmissaryCome = true, WaspTrades = 7, Paper = 23m };
        // Cut in stage 7.5 (spec 016): OldCountsAnnounced = true (no longer saved).
        Assert.True(BeekeeperSaveService.Save(s, path, DateTime.UtcNow));
        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.CurrentVersion, back.Version);
        Assert.Equal(5, back.BribesTotal);
        Assert.True(back.EmissaryCome);
        Assert.Equal(7, back.WaspTrades);
        Assert.Equal(23m, back.Paper);
        // Cut in stage 7.5 (spec 016): Assert.True(back.OldCountsAnnounced);

        foreach (var bad in new[] { "{\"Version\":8,\"Paper\":-1}", "{\"Version\":8,\"BribesTotal\":-1}", "{\"Version\":8,\"WaspTrades\":-2}" })
        {
            File.WriteAllText(path, bad);
            Assert.Null(BeekeeperSaveService.Load(path));
        }
    }

    // ============================================================ raids take only honey (User Story 4)

    private static BeekeeperState Workshop(decimal honey = 10_000m) => new()
    {
        // Stage 7.5: 50 combs make 10 honey a second (the raid's 3 minutes); the bees are free bees.
        Bees = 1000m, Honey = honey, Combs = 50, WorkbenchRevealed = true, HoneyRevealed = true,
    };

    [Fact]
    public void ARaid_TakesOnlyHoney_WithOrWithoutGuarding()
    {
        foreach (var guarded in new[] { false, true })
        {
            var s = Workshop();
            if (guarded) s.Plants.Add(BeekeeperPlants.Bramble);
            // Cut in stage 7.5 (spec 016): s.GuardBees = 0m;
            var e = Make(s, BigCombs);
            e.DebugCallWasp();
            var raid = e.ThrowShoe().Events.Single();            // 0.99: a miss, so a raid
            Assert.Equal(BeekeeperEvents.ShoeMissRaid, raid.Key);
            Assert.Equal(0m, raid.Value2);
            Assert.Null(raid.Text);
            Assert.Equal(1000m, e.State.Bees);
            Assert.Equal(guarded ? 2250m : 1800m, raid.Value);  // 3 minutes of honey (guarding counts)
        }
    }

    [Fact]
    public void ACountdownRaid_TakesOnlyHoney()
    {
        var e = Make(Workshop());
        e.DebugCallWasp();
        var raid = e.AdvanceWaspCountdown(60m).Single();
        Assert.Equal(BeekeeperEvents.WaspRaid, raid.Key);
        Assert.Equal(1800m, raid.Value);
        Assert.Equal(1000m, e.State.Bees);
    }

    // ============================================================ bribes and the emissary (User Stories 5, 6)

    private static ActionResult CallAndBribe(BeekeeperEngine e)
    {
        e.DebugCallWasp();
        return e.Bribe();
    }

    [Fact]
    public void Bribes_AreCountedInTotal_ThrowsAndRaidsDoNotReset()
    {
        var e = Make(Workshop());
        CallAndBribe(e);
        e.DebugCallWasp();
        e.ThrowShoe();                       // a miss and a raid in between
        CallAndBribe(e);
        e.DebugCallWasp();
        e.AdvanceWaspCountdown(60m);         // a countdown raid
        Assert.Equal(2, e.State.BribesTotal);
    }

    [Fact]
    public void TheThirdBribe_HintsTheWaspIsTakingNotes()
    {
        var e = Make(Workshop());
        Assert.False(Has(CallAndBribe(e).Events, BeekeeperEvents.BribeHint));
        Assert.False(Has(CallAndBribe(e).Events, BeekeeperEvents.BribeHint));
        var third = CallAndBribe(e);
        Assert.True(Has(third.Events, BeekeeperEvents.BribeHint));
        Assert.Equal(BeekeeperEvents.Bribe, third.Events[0].Key);
        Assert.False(Has(CallAndBribe(e).Events, BeekeeperEvents.BribeHint));
    }

    [Fact]
    public void TheBribeCost_StaysAQuarterOfTheHoney()
    {
        var e = Make(Workshop(403m));
        Assert.Equal(100m, CallAndBribe(e).Amount);
    }

    [Fact]
    public void TheFifthBribe_BringsTheEmissary_AndWaspsNeverComeAgain()
    {
        var e = Make(Workshop());
        for (int i = 0; i < 4; i++) Assert.False(Has(CallAndBribe(e).Events, BeekeeperEvents.Emissary));
        var fifth = CallAndBribe(e);
        Assert.Equal(new[] { BeekeeperEvents.Bribe, BeekeeperEvents.Emissary }, fifth.Events.Select(x => x.Key));
        Assert.True(e.EmissaryCome);
        Assert.False(e.WaspApproaching);

        Assert.Empty(e.AdvanceWaspTime(100_000m));
        Assert.Empty(e.DebugCallWasp());
        Assert.False(e.WaspApproaching);
        Assert.Empty(e.AdvanceWaspCountdown(60m));
    }

    [Fact]
    public void ALoadedSaveWithEnoughBribes_GetsTheEmissaryOnLoad_AndAnyWaspLeaves()
    {
        var s = Workshop();
        s.BribesTotal = 6;
        s.WaspCountdown = 30m;
        var e = Make(s);
        Assert.True(Has(e.RevealOnLoad(), BeekeeperEvents.Emissary));
        Assert.True(e.EmissaryCome);
        Assert.False(e.WaspApproaching);
        Assert.Equal(0m, e.State.WaspCountdown);
        Assert.False(Has(e.RevealOnLoad(), BeekeeperEvents.Emissary));   // once
    }

    [Fact]
    public void TheDebugHelpers_BribesToFour_AndBringTheEmissary()
    {
        var e = Make(Workshop());
        e.DebugBribesToAlmostEmissary();
        Assert.Equal(4, e.State.BribesTotal);
        Assert.True(Has(CallAndBribe(e).Events, BeekeeperEvents.Emissary));

        var f = Make(Workshop());
        Assert.True(Has(f.DebugBringEmissary(), BeekeeperEvents.Emissary));
        Assert.True(f.EmissaryCome);
        Assert.Empty(f.DebugBringEmissary());
    }

    // ============================================================ paper (User Story 7)

    [Fact]
    public void Paper_IsOnlyTradedAfterTheEmissary()
    {
        var e = Make(Workshop());
        Assert.False(e.CanTradePaper);
        Assert.False(e.TradeForPaper().Done);
        e.DebugBringEmissary();
        Assert.True(e.CanTradePaper);
    }

    [Fact]
    public void FiftyHoneyAPaper_ABatchCountsAsOneTrade()
    {
        var s = Workshop(600m);
        s.EmissaryCome = true;
        var e = Make(s);
        Assert.True(e.CanTradePaperTimes(10));
        Assert.False(e.CanTradePaperTimes(100));

        var r = e.TradeForPaper(10);
        Assert.True(r.Done);
        Assert.Equal(100m, e.State.Honey);
        Assert.Equal(10m, e.State.Paper);
        Assert.Equal(1, e.State.WaspTrades);
        Assert.True(Has(r.Events, BeekeeperEvents.FirstPaper));
        var trade = r.Events.First(x => x.Key == BeekeeperEvents.WaspTrade);
        Assert.Equal(10m, trade.Value);
        Assert.Equal(500m, trade.Value2);

        Assert.False(e.TradeForPaper(10).Done);   // only 100 honey left: nothing at all
        Assert.Equal(10m, e.State.Paper);
        var one = e.TradeForPaper();
        Assert.True(one.Done);
        Assert.False(Has(one.Events, BeekeeperEvents.FirstPaper));
        Assert.Equal(2, e.State.WaspTrades);
        Assert.Equal(50m, e.State.Honey);
    }

    [Fact]
    public void Paper_DoesNotChangeOnItsOwn()
    {
        var s = Workshop();
        s.EmissaryCome = true;
        s.Paper = 3m;
        var e = Make(s, BigCombs);
        e.Advance(600m);
        e.AdvanceAway(3600m);
        Assert.Equal(3m, e.State.Paper);
    }

    // ============================================================ repellent candles retire (User Story 8)

    [Fact]
    public void TheEmissary_RetiresRepellentCandles_KeepingTheStock()
    {
        var s = Workshop();
        s.Wax = 500m;
        s.Sage = 10m;
        s.RepellentUnlocked = true;
        s.RepellentCandles = 3m;
        s.BeeswaxCandles = 0m;
        var e = Make(s);
        Assert.True(e.CanCraftRepellent);
        Assert.True(e.CanLightRepellent);
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.StrongerCandles);

        e.DebugBringEmissary();
        Assert.True(e.RepellentRetired);
        Assert.False(e.CanCraftRepellent);
        Assert.False(e.CraftRepellent().Done);
        Assert.False(e.CanLightRepellent);
        Assert.False(e.LightRepellent().Done);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.StrongerCandles);
        Assert.False(e.CanBuyUpgrade(BeekeeperUpgrades.StrongerCandles));
        Assert.Equal(3m, e.State.RepellentCandles);   // still in the save, nothing refunded

        Assert.True(e.CanCraftBeeswax);               // beeswax candles carry on
    }

    [Fact]
    public void ABoughtStrongerCandles_StaysOwned()
    {
        var s = Workshop();
        s.RepellentUnlocked = true;
        s.Upgrades.Add(BeekeeperUpgrades.StrongerCandles);
        var e = Make(s);
        e.DebugBringEmissary();
        Assert.True(e.Owns(BeekeeperUpgrades.StrongerCandles));
    }
}
