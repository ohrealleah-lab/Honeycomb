using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 7 rules (spec 015): named seeds, two beds, willow/poplar/clover, propolis, the two candles, new upgrades, save version 7.</summary>
public class BeekeeperStage7Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage7-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

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

    private static BeekeeperState Hive(params string[] plants)
    {
        var s = new BeekeeperState
        {
            // Stage 7.5 (spec 016): 50 combs in the wooden hive make 12.5 honey a second; the bees are free bees.
            Bees = 1000m, HoneyRevealed = true, GardenRevealed = true, HasWoodenHive = true, QueenSettled = true,
            BeeBread = 5m, BeeBreadRevealed = true, WorkbenchRevealed = true, Combs = 50,
        };
        s.Plants.AddRange(plants);
        return s;
    }

    // ============================================================ plant data

    [Fact]
    public void PlantsAreData_WithGiversTradeCountsAndGrowTimes()
    {
        var p = BeekeeperConfig.Default.Plants.ToDictionary(x => x.Id);
        Assert.Equal(600m, p[BeekeeperPlants.Wildflowers].GrowSeconds);
        Assert.Equal(600m, p[BeekeeperPlants.Bramble].GrowSeconds);
        Assert.Equal(3600m, p[BeekeeperPlants.Willow].GrowSeconds);
        Assert.Equal(6m * 3600m, p[BeekeeperPlants.Poplar].GrowSeconds);
        Assert.Equal(12m * 3600m, p[BeekeeperPlants.Clover].GrowSeconds);
        Assert.Equal(20, p[BeekeeperPlants.Willow].SeedAtTrade);
        Assert.Equal(35, p[BeekeeperPlants.Clover].SeedAtTrade);
        Assert.Equal(BeekeeperGivers.Wasps, p[BeekeeperPlants.Poplar].Giver);
        Assert.Equal(10, p[BeekeeperPlants.Poplar].SeedAtTrade);
    }

    // ============================================================ seeds from two givers

    [Fact]
    public void TheTwentiethHippieTrade_GivesAWillowSeed()
    {
        var e = Make(new BeekeeperState
        {
            HippiesRevealed = true, HippieTrades = 19, BeeswaxCandles = 100m,
            SeedsGivenIds = { "wildflowers", "bramble" },
        });
        var r = e.TradeTenCandles();
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.SeedGiven && ev.Text == BeekeeperPlants.Willow);
        Assert.Equal(new[] { BeekeeperPlants.Willow }, e.State.SeedsInHand);
        e.TradeTenCandles();
        Assert.Single(e.State.SeedsInHand);   // each plant is given once
    }

    [Fact]
    public void TheWasps_GiveThePoplarSeed_OnTheirTenthTrade()
    {
        var e = Make(new BeekeeperState { EmissaryCome = true, WaspTrades = 9, Honey = 1000m, HoneyRevealed = true });
        var r = e.TradeForPaper();
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.WaspSeedGiven && ev.Text == BeekeeperPlants.Poplar);
        Assert.Equal(new[] { BeekeeperPlants.Poplar }, e.State.SeedsInHand);
        Assert.True(e.State.GardenRevealed);
    }

    [Fact]
    public void AnOldSavePastTheCounts_GetsTheSeedsOnLoad()
    {
        var s = new BeekeeperState { HippieTrades = 40, WaspTrades = 12, EmissaryCome = true };
        // Cut in stage 7.5 (spec 016): Version = 6, SeedsGiven = 2, SeedsPlanted = 2 (older saves no longer load).
        s.Plants.AddRange(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble });
        var e = Make(s);
        var events = e.RevealOnLoad();
        Assert.Equal(3, events.Count(ev => ev.Key is BeekeeperEvents.SeedGiven or BeekeeperEvents.WaspSeedGiven));
        Assert.Equal(
            new[] { BeekeeperPlants.Willow, BeekeeperPlants.Poplar, BeekeeperPlants.Clover }.OrderBy(x => x),
            e.State.SeedsInHand.OrderBy(x => x));
        Assert.Empty(e.RevealOnLoad().Where(ev => ev.Key is BeekeeperEvents.SeedGiven or BeekeeperEvents.WaspSeedGiven));
    }

    // ============================================================ beds

    [Fact]
    public void TwoSeedsGrowAtOnce_EachOnItsOwnTimer_AndAThirdBedAddsOne()
    {
        var e = Make(new BeekeeperState
        {
            SeedsInHand = { "wildflowers", "willow", "bramble" }, GardenRevealed = true,
            Beebits = 5000m, Wax = 500m, Paper = 20m, PaperRevealed = true,
        });
        Assert.True(e.PlantSeed("willow").Done);
        Assert.True(e.PlantSeed("wildflowers").Done);
        Assert.False(e.CanPlantSeed);
        Assert.Equal(0, e.FreeBeds);

        e.Advance(600m);   // wildflowers (10 min) sprouts; the willow has 50 minutes left
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers }, e.State.Plants);
        Assert.Equal(3000m, Assert.Single(e.State.Beds).SecondsLeft);
        Assert.True(e.CanPlantSeed);

        Assert.Equal(2, e.BedCount);
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.ThirdBed).Done);
        Assert.Equal(3, e.BedCount);
    }

    [Fact]
    public void ASeedSprouting_CountsItsSpecialtyOnlyFromThatMoment_EvenWithSeveralBeds()
    {
        var s = Hive();
        s.BeeBread = 0m;
        s.Beds.Add(new BeekeeperBed { PlantId = BeekeeperPlants.Bramble, SecondsLeft = 60m });
        s.Beds.Add(new BeekeeperBed { PlantId = BeekeeperPlants.Wildflowers, SecondsLeft = 120m });
        var e = Make(s, BigCombs);
        e.AdvanceAway(180m);
        // honey: 60 s at 12.5/s (wooden hive), 60 s at 12.5 × 1.25, 60 s the same
        Assert.Equal(12.5m * 60m + 15.625m * 120m, e.State.Honey);
        Assert.Equal(3m * 60m / 60m, e.State.Pollen);   // foraging only for the last 60 s: 3 a minute
    }

    // ============================================================ nursing, resin, clover

    [Fact]
    public void Nursing_MakesTheQueenLayFiftyPercentFaster_AndOnlyInAWoodenHive()
    {
        var e = Make(Hive(BeekeeperPlants.Willow));
        Assert.Equal(30m, e.QueenRatePerMinute);
        Assert.Equal(0.5m, e.QueenBeesPerSecondNow);
        Assert.Equal(20m, Make(Hive()).QueenRatePerMinute);

        var skep = Hive(BeekeeperPlants.Willow);
        skep.HasWoodenHive = false;
        Assert.Equal(0m, Make(skep).QueenRatePerMinute);
    }

    [Fact]
    public void Resin_GathersPropolisAMinute_AndSaysSoOnce()
    {
        var e = Make(Hive(BeekeeperPlants.Poplar));
        var r = e.Advance(59m);
        Assert.False(Has(r.Events, BeekeeperEvents.FirstPropolis));
        r = e.Advance(1m);
        Assert.True(Has(r.Events, BeekeeperEvents.FirstPropolis));
        Assert.Equal(1m, e.State.Propolis);
        e.AdvanceAway(600m);
        Assert.Equal(11m, e.State.Propolis);
    }

    [Fact]
    public void Clover_AddsThreePollenAMinute_SoForagingIsSix()
    {
        var e = Make(Hive(BeekeeperPlants.Wildflowers, BeekeeperPlants.Clover));
        Assert.Equal(6m, e.ForagingPollenPerMinute);
    }

    // ============================================================ candles

    [Fact]
    public void TheCandleRecipes_NeedThePoplar_AndTheirIngredients()
    {
        var s = Hive();
        s.Wax = 100m; s.Propolis = 20m; s.Sage = 5m;
        var e = Make(s);
        Assert.False(e.CanCraftBeeBoost);   // no poplar yet

        s = Hive(BeekeeperPlants.Poplar);
        s.Wax = 100m; s.Propolis = 20m; s.Sage = 5m;
        e = Make(s);
        Assert.True(e.CraftBeeBoost().Done);
        Assert.Equal(80m, e.State.Wax);
        Assert.Equal(18m, e.State.Propolis);
        Assert.True(e.CraftSagePropolis().Done);
        Assert.Equal(60m, e.State.Wax);
        Assert.Equal(4m, e.State.Sage);
        Assert.Equal(13m, e.State.Propolis);
        Assert.Equal(2, e.State.CandlesCrafted);
        Assert.False(e.CraftSagePropolis(100).Done);
    }

    [Fact]
    public void LightingAddsTime_UpToTheCap()
    {
        var e = Make(Hive(BeekeeperPlants.Poplar));
        e.State.BeeBoostCandles = 10m;
        e.State.SagePropolisCandles = 10m;
        for (int i = 0; i < 6; i++) Assert.True(e.LightBeeBoost().Done);
        Assert.Equal(3600m, e.State.BeeBoostSecondsLeft);
        Assert.False(e.CanLightBeeBoost);
        Assert.False(e.LightBeeBoost().Done);
        Assert.Equal(4m, e.State.BeeBoostCandles);

        for (int i = 0; i < 6; i++) Assert.True(e.LightSagePropolis().Done);
        Assert.Equal(24m * 3600m, e.State.SagePropolisSecondsLeft);
        Assert.False(e.CanLightSagePropolis);
    }

    [Fact]
    public void TheBeeBoost_BoostsLivePlay_ThenGuttersOut_AndMultipliesWithCalm()
    {
        var e = Make(Hive(), BigCombs);
        e.State.BeeBread = 0m;
        e.State.BeeBoostSecondsLeft = 30m;
        var r = e.Advance(60m);
        Assert.True(Has(r.Events, BeekeeperEvents.BeeBoostOut));
        // 30 s at 12.5 × 1.2, 30 s at 12.5
        Assert.Equal(12.5m * 1.2m * 30m + 12.5m * 30m, e.State.Honey);

        var both = Make(Hive(), BigCombs);
        both.State.BeeBread = 0m;
        both.State.BeeBoostSecondsLeft = 10m;
        both.State.CalmSecondsLeft = 10m;
        Assert.Equal(12.5m * 2m * 1.2m, both.HoneyPerSecondNow);
        both.Advance(10m);
        Assert.Equal(12.5m * 2m * 1.2m * 10m, both.State.Honey);
    }

    [Fact]
    public void TheBeeBoost_NeitherBurnsNorBoostsWhileAway()
    {
        var e = Make(Hive(), BigCombs);
        e.State.BeeBread = 0m;
        e.State.BeeBoostSecondsLeft = 300m;
        e.AdvanceAway(600m);
        Assert.Equal(300m, e.State.BeeBoostSecondsLeft);
        Assert.Equal(12.5m * 600m, e.State.Honey);
    }

    [Fact]
    public void TheSagePropolisCandle_BurnsAwayToo_AndTheWelcomeBackSaysSo()
    {
        var s = Hive(BeekeeperPlants.Poplar);
        s.BeeBread = 0m;
        s.SagePropolisSecondsLeft = 100m;
        var e = Make(s, BigCombs);
        var away = e.AdvanceAway(200m);
        Assert.Equal(0m, e.State.SagePropolisSecondsLeft);
        // 100 s at 12.5 × 1.1, 100 s at 12.5
        Assert.Equal(12.5m * 1.1m * 100m + 12.5m * 100m, e.State.Honey);
        Assert.True(Has(away.WelcomeBack, BeekeeperEvents.WelcomeBackSageOut));
        Assert.False(Has(away.Events, BeekeeperEvents.SagePropolisOut));
        Assert.Contains(away.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBackPropolis && ev.Value == 3m);   // 200 s of resin
    }

    [Fact]
    public void TheSagePropolisCandle_ShowsItsOwnLiveLine_WhenItBurnsOutWhilePlaying()
    {
        var s = Hive();
        s.BeeBread = 0m;
        s.SagePropolisSecondsLeft = 5m;
        var e = Make(s, BigCombs);
        Assert.True(Has(e.Advance(5m).Events, BeekeeperEvents.SagePropolisOut));
    }

    // ============================================================ live and away agree (FR-606)

    private static BeekeeperState Busy()
    {
        var s = Hive(BeekeeperPlants.Wildflowers, BeekeeperPlants.Poplar);
        s.Beds.Add(new BeekeeperBed { PlantId = BeekeeperPlants.Willow, SecondsLeft = 400m });
        s.Beds.Add(new BeekeeperBed { PlantId = BeekeeperPlants.Clover, SecondsLeft = 901m });
        s.SagePropolisSecondsLeft = 1000m;
        return s;
    }

    private static void AssertSame(BeekeeperEngine live, BeekeeperEngine away)
    {
        const int Places = 6;
        Assert.Equal((double)away.State.Honey, (double)live.State.Honey, Places);
        Assert.Equal((double)away.State.Bees, (double)live.State.Bees, Places);
        Assert.Equal((double)away.State.Pollen, (double)live.State.Pollen, Places);
        Assert.Equal((double)away.State.Propolis, (double)live.State.Propolis, Places);
        Assert.Equal((double)away.State.BeeBread, (double)live.State.BeeBread, Places);
        // Stage 7.5: wax is fractional now, so it compares like honey (to 6 places).
        Assert.Equal((double)away.State.Wax, (double)live.State.Wax, 6);
        Assert.Equal(away.State.SagePropolisSecondsLeft, live.State.SagePropolisSecondsLeft);
        Assert.Equal(away.State.Plants, live.State.Plants);
        Assert.Equal(away.State.Beds.Count, live.State.Beds.Count);
    }

    [Fact]
    public void TwoBedsNursingResinCloverAndACandleBurningOut_SameLiveSecondsOrOneAwayStep()
    {
        var live = Make(Busy(), BigCombs);
        for (int i = 0; i < 2000; i++) live.Advance(1m);   // sprouts at 400 s and 901 s, candle out at 1000 s, pantry runs out
        var away = Make(Busy(), BigCombs);
        away.AdvanceAway(2000m);
        AssertSame(live, away);
        Assert.Contains(BeekeeperPlants.Willow, live.State.Plants);
        Assert.Contains(BeekeeperPlants.Clover, live.State.Plants);
        Assert.Empty(live.State.Beds);
        Assert.True(live.State.Propolis > 0m && live.State.Pollen > 0m);
    }

    [Fact]
    public void TheSameHolds_ForOddStepsAndTheBeeBoostLeftOut()
    {
        var live = Make(Busy(), BigCombs);
        decimal[] steps = { 7m, 333m, 60m, 1m, 599m, 1000m };
        foreach (var st in steps) live.Advance(st);
        var away = Make(Busy(), BigCombs);
        away.AdvanceAway(steps.Sum());
        AssertSame(live, away);
    }

    // ============================================================ upgrades

    [Fact]
    public void TheNewUpgrades_ShowWhenTheirNeedIsMet_AndCostPaperAndPropolis()
    {
        var e = Make(new BeekeeperState { Beebits = 9999m, Wax = 999m, WorkbenchRevealed = true });
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id is BeekeeperUpgrades.Notebook or BeekeeperUpgrades.ThirdBed or BeekeeperUpgrades.PropolisSeal);

        e.State.Paper = 20m;     // first paper (but no garden yet)
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Notebook);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.ThirdBed);
        e.State.GardenRevealed = true;
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.ThirdBed);

        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.Notebook).Done);
        Assert.Equal(0m, e.State.Paper);
        Assert.Equal(9899m, e.State.Beebits);
        Assert.False(e.CanBuyUpgrade(BeekeeperUpgrades.ThirdBed));   // 10 paper needed, none left
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Notebook);

        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.PropolisSeal);
        e.State.Propolis = 30m;
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.PropolisSeal).Done);
        Assert.Equal(0m, e.State.Propolis);
    }

    [Fact]
    public void ThePropolisSeal_AddsTwentyFivePercentStorage_AndMultipliesWithBiggerCombs()
    {
        var plain = Make(new BeekeeperState());
        Assert.Equal(200m, plain.HoneyStorage);
        var sealedHive = Make(new BeekeeperState { Upgrades = { BeekeeperUpgrades.PropolisSeal } });
        Assert.Equal(250m, sealedHive.HoneyStorage);
        var both = Make(new BeekeeperState { Upgrades = { BeekeeperUpgrades.PropolisSeal, BeekeeperUpgrades.BiggerCombs1 } });
        Assert.Equal(200m * 1.5m * 1.25m, both.HoneyStorage);
    }

    [Fact]
    public void ExistingUpgradePrices_DoNotChange()
    {
        var smoker = BeekeeperConfig.Default.Upgrades.First(u => u.Id == BeekeeperUpgrades.Smoker);
        Assert.Equal(0m, smoker.Paper);
        Assert.Equal(0m, smoker.Propolis);
    }

    // ============================================================ saving and old saves

    // Cut in stage 7.5 (spec 016): older saves start a new game (BeekeeperSaveTests).
    // [Fact]
    // public void AVersion6Save_BecomesNamedSeedsAndABed()
    // {
    //     Directory.CreateDirectory(_dir);
    //     var path = Path.Combine(_dir, "v6.json");
    //     // wildflowers sprouted, the bramble is growing (200 s left), no seeds in hand
    //     File.WriteAllText(path, "{\"Version\":6,\"Bees\":50,\"Seeds\":0,\"SeedsGiven\":2,\"SeedsPlanted\":2,\"GrowSecondsLeft\":200,"
    //         + "\"Plants\":[\"wildflowers\"],\"HippieTrades\":12,\"GardenRevealed\":true,\"Log\":[]}");
    //     var s = BeekeeperSaveService.Load(path)!;
    //     var e = Make(s);
    //     Assert.Equal(7, s.Version);
    //     var bed = Assert.Single(s.Beds);
    //     Assert.Equal(BeekeeperPlants.Bramble, bed.PlantId);
    //     Assert.Equal(200m, bed.SecondsLeft);
    //     Assert.Empty(s.SeedsInHand);
    //     Assert.Contains(BeekeeperPlants.Bramble, s.SeedsGivenIds);
    //     e.Advance(200m);
    //     Assert.Contains(BeekeeperPlants.Bramble, e.State.Plants);
    // }

    // Cut in stage 7.5 (spec 016): older saves start a new game (BeekeeperSaveTests).
    // [Fact]
    // public void AVersion6Save_WithASeedInHand_KeepsItNamed()
    // {
    //     var s = new BeekeeperState { Version = 6, SeedsGiven = 2, SeedsPlanted = 1, Seeds = 1 };
    //     s.Plants.Add(BeekeeperPlants.Wildflowers);
    //     Make(s);
    //     Assert.Equal(new[] { BeekeeperPlants.Bramble }, s.SeedsInHand);
    //     Assert.Empty(s.Beds);
    // }

    [Fact]
    public void Stage7Fields_SurviveASave()
    {
        var path = Path.Combine(_dir, "v7.json");
        var s = new BeekeeperState
        {
            SeedsInHand = { BeekeeperPlants.Clover }, SeedsGivenIds = { BeekeeperPlants.Clover, BeekeeperPlants.Willow },
            Beds = { new BeekeeperBed { PlantId = BeekeeperPlants.Willow, SecondsLeft = 1234.5m } },
            Propolis = 12.5m, PropolisRevealed = true, PaperRevealed = true,
            BeeBoostCandles = 2m, SagePropolisCandles = 3m, BeeBoostSecondsLeft = 77m, SagePropolisSecondsLeft = 9000m,
            Upgrades = { BeekeeperUpgrades.ThirdBed },
        };
        Assert.True(BeekeeperSaveService.Save(s, path, DateTime.UtcNow));
        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.CurrentVersion, back.Version);
        Assert.Equal(s.SeedsInHand, back.SeedsInHand);
        Assert.Equal(s.SeedsGivenIds, back.SeedsGivenIds);
        Assert.Equal(1234.5m, Assert.Single(back.Beds).SecondsLeft);
        Assert.Equal(12.5m, back.Propolis);
        Assert.Equal(2m, back.BeeBoostCandles);
        Assert.Equal(3m, back.SagePropolisCandles);
        Assert.Equal(77m, back.BeeBoostSecondsLeft);
        Assert.Equal(9000m, back.SagePropolisSecondsLeft);
        Assert.True(back.PropolisRevealed && back.PaperRevealed);
    }

    [Theory]
    [InlineData("\"Propolis\":-1")]
    [InlineData("\"BeeBoostCandles\":-1")]
    [InlineData("\"SagePropolisCandles\":-2")]
    [InlineData("\"BeeBoostSecondsLeft\":-5")]
    [InlineData("\"SagePropolisSecondsLeft\":-5")]
    [InlineData("\"Beds\":[{\"PlantId\":\"willow\",\"SecondsLeft\":-3}]")]
    public void NegativeStage7Numbers_AreRefused(string field)
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "bad.json");
        File.WriteAllText(path, "{\"Version\":8," + field + "}");
        Assert.Null(BeekeeperSaveService.Load(path));
    }

    [Fact]
    public void UnknownPlantIds_AreDropped_AndTooManyBedsAreTrimmed()
    {
        var s = new BeekeeperState
        {
            SeedsInHand = { "willow", "dandelion" }, SeedsGivenIds = { "dandelion", "willow" },
            Beds =
            {
                new BeekeeperBed { PlantId = "bramble", SecondsLeft = 10m },
                new BeekeeperBed { PlantId = "nonsense", SecondsLeft = 10m },
                new BeekeeperBed { PlantId = "clover", SecondsLeft = 10m },
                new BeekeeperBed { PlantId = "poplar", SecondsLeft = 10m },
            },
        };
        Make(s);
        Assert.Equal(new[] { "willow", "poplar" }, s.SeedsInHand);   // the seed from the extra bed comes back
        Assert.Equal(new[] { "willow" }, s.SeedsGivenIds);
        Assert.Equal(2, s.Beds.Count);   // two beds owned; the unknown one went first
        Assert.DoesNotContain(s.Beds, b => b.PlantId == "nonsense");
    }

    // ============================================================ debug helpers

    [Fact]
    public void TheDebugHelpers_GiveEverySeed_FinishEveryBed_AndPropolisAndPaper()
    {
        var e = Make(new BeekeeperState());
        e.DebugGiveEverySeed();
        Assert.Equal(BeekeeperConfig.Default.Plants.Count, e.State.SeedsInHand.Count);
        Assert.True(e.PlantSeed(BeekeeperPlants.Willow).Done);
        Assert.True(e.PlantSeed(BeekeeperPlants.Poplar).Done);
        e.DebugFinishGrowing();
        Assert.Empty(e.State.Beds);
        Assert.Equal(2, e.State.Plants.Count);

        e.DebugGivePropolis(50m);
        e.DebugGivePaper(20m);
        Assert.Equal(50m, e.State.Propolis);
        Assert.Equal(20m, e.State.Paper);
        Assert.True(e.PaperSeen && e.PropolisSeen);

        var h = Make(new BeekeeperState());
        h.DebugHippieTradesTo19();
        Assert.Equal(19, h.State.HippieTrades);
        h.TradeTenCandles();
        Assert.Contains(BeekeeperPlants.Willow, h.State.SeedsInHand);
    }
}
