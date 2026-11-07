using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 2 rules (spec 010): The Workbench, candles, the Hippies, upgrades, wasps, saving.</summary>
public class BeekeeperStage2Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage2-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class FakeRandom : IRandomSource
    {
        private readonly Queue<double> _doubles;
        public FakeRandom(params double[] doubles) => _doubles = new Queue<double>(doubles);
        public double NextDouble() => _doubles.Count > 0 ? _doubles.Dequeue() : 0.5;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperEngine Make(BeekeeperState? state = null, params double[] dice)
        => new(BeekeeperConfig.Default, state, new FakeRandom(dice));

    // A hive that already has The Workbench open.
    private static BeekeeperState Workshop(Action<BeekeeperState>? tweak = null)
    {
        var s = new BeekeeperState { Combs = 2, WorkbenchRevealed = true, BearName = "Bruno" };
        tweak?.Invoke(s);
        return s;
    }

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    // ============================================================ The Workbench

    [Fact]
    public void TheWorkbench_OpensWithTheSecondComb()
    {
        var e = Make(new BeekeeperState { Combs = 1, Wax = 1000m });
        Assert.False(e.CanCraftBeeswax);
        var r = e.BuildComb();
        Assert.True(e.State.WorkbenchRevealed);
        Assert.True(Has(r.Events, BeekeeperEvents.WorkbenchOpened));
        Assert.False(Has(e.BuildComb().Events, BeekeeperEvents.WorkbenchOpened));   // once only
    }

    [Fact]
    public void AnOldSaveWithTwoCombs_OpensTheWorkbenchOnLoad()
    {
        var e = Make(new BeekeeperState { Combs = 3 });
        Assert.True(Has(e.RevealOnLoad(), BeekeeperEvents.WorkbenchOpened));
        Assert.True(e.State.WorkbenchRevealed);
        Assert.Empty(e.RevealOnLoad());

        var few = Make(new BeekeeperState { Combs = 1 });
        Assert.Empty(few.RevealOnLoad());
        Assert.False(few.State.WorkbenchRevealed);
    }

    [Fact]
    public void BeeswaxCandle_CostsTenWax_AndIsInstant()
    {
        var e = Make(Workshop(s => s.Wax = 25m));
        var first = e.CraftBeeswax();
        Assert.True(first.Done);
        Assert.Equal(15m, e.State.Wax);
        Assert.Equal(1m, e.State.BeeswaxCandles);
        Assert.True(Has(first.Events, BeekeeperEvents.FirstBeeswaxCandle));
        Assert.False(Has(e.CraftBeeswax().Events, BeekeeperEvents.FirstBeeswaxCandle));
        Assert.False(e.CraftBeeswax().Done);   // 5 wax left
        Assert.Equal(5m, e.State.Wax);
        Assert.Equal(2m, e.State.BeeswaxCandles);
    }

    [Fact]
    public void NoWorkbench_NoCrafting()
    {
        var e = Make(new BeekeeperState { Combs = 1, Wax = 100m });
        Assert.False(e.CraftBeeswax().Done);
        Assert.Equal(100m, e.State.Wax);
    }

    // ============================================================ the Hippies and sage

    [Fact]
    public void TheHippies_ArriveAfterFiveCandles()
    {
        var e = Make(Workshop(s => s.Wax = 100m));
        for (int i = 0; i < 4; i++) Assert.False(Has(e.CraftBeeswax().Events, BeekeeperEvents.HippiesArrive));
        Assert.False(e.State.HippiesRevealed);
        Assert.True(Has(e.CraftBeeswax().Events, BeekeeperEvents.HippiesArrive));
        Assert.True(e.State.HippiesRevealed);
        Assert.False(Has(e.CraftBeeswax().Events, BeekeeperEvents.HippiesArrive));
    }

    [Fact]
    public void TradeTen_GivesOneSage_AndUnlocksTheRepellentCandle()
    {
        var e = Make(Workshop(s => { s.HippiesRevealed = true; s.BeeswaxCandles = 12m; }));
        var r = e.TradeTenCandles();
        Assert.True(r.Done);
        Assert.Equal(2m, e.State.BeeswaxCandles);
        Assert.Equal(1m, e.State.Sage);
        Assert.True(e.State.SageRevealed);
        Assert.True(e.State.RepellentUnlocked);
        Assert.True(Has(r.Events, BeekeeperEvents.RepellentUnlocked));
        Assert.False(e.TradeTenCandles().Done);   // only 2 left
    }

    [Fact]
    public void TradeAll_TradesWholeBundles_AndKeepsTheRest()
    {
        var e = Make(Workshop(s => { s.HippiesRevealed = true; s.BeeswaxCandles = 27m; }));
        Assert.True(e.TradeAllCandles().Done);
        Assert.Equal(2m, e.State.Sage);
        Assert.Equal(7m, e.State.BeeswaxCandles);
        Assert.Equal(1, e.State.HippieTrades);
    }

    [Fact]
    public void RepellentCandle_NeedsUnlocking_AndCostsWaxAndSage()
    {
        var locked = Make(Workshop(s => { s.Wax = 50m; s.Sage = 5m; }));
        Assert.False(locked.CraftRepellent().Done);

        var e = Make(Workshop(s => { s.Wax = 50m; s.Sage = 1m; s.RepellentUnlocked = true; }));
        Assert.True(e.CraftRepellent().Done);
        Assert.Equal(40m, e.State.Wax);
        Assert.Equal(0m, e.State.Sage);
        Assert.Equal(1m, e.State.RepellentCandles);
        Assert.False(e.CraftRepellent().Done);   // no sage left
    }

    // ============================================================ upgrades

    [Fact]
    public void Upgrades_AppearWithTheWorkbench_AndOnlyWhenUnlocked()
    {
        Assert.Empty(Make(new BeekeeperState { Combs = 1, Beebits = 5000m }).ShopUpgrades);

        var e = Make(Workshop());
        Assert.Equal(new[] { BeekeeperUpgrades.BiggerCombs1 }, e.ShopUpgrades.Select(u => u.Id));

        var more = Make(Workshop(s => { s.HasWaxCatcher = true; s.RepellentUnlocked = true; }));
        Assert.Equal(new[] { BeekeeperUpgrades.BiggerCombs1, BeekeeperUpgrades.BetterWaxCatcher, BeekeeperUpgrades.StrongerCandles },
                     more.ShopUpgrades.Select(u => u.Id));
    }

    [Fact]
    public void BuyingAnUpgrade_TakesEveryPartOfTheCost_AndItLeavesTheShop()
    {
        var e = Make(Workshop(s => { s.Beebits = 1000m; s.Wax = 300m; s.Sage = 2m; }));
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.BiggerCombs1).Done);
        Assert.Equal(700m, e.State.Beebits);
        Assert.Equal(200m, e.State.Wax);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.BiggerCombs1);
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.BiggerCombs2);
        Assert.False(e.BuyUpgrade(BeekeeperUpgrades.BiggerCombs1).Done);   // once only
    }

    [Fact]
    public void AnUpgradeYouCannotFullyAfford_TakesNothing()
    {
        // Enough Beebits and sage for Even Bigger Combs, but not enough wax.
        var e = Make(Workshop(s => { s.Upgrades.Add(BeekeeperUpgrades.BiggerCombs1); s.Beebits = 5000m; s.Wax = 10m; s.Sage = 5m; }));
        Assert.False(e.BuyUpgrade(BeekeeperUpgrades.BiggerCombs2).Done);
        Assert.Equal(5000m, e.State.Beebits);
        Assert.Equal(10m, e.State.Wax);
        Assert.Equal(5m, e.State.Sage);
    }

    [Fact]
    public void BiggerCombs_GrowAllHoneyStorage()
    {
        var e = Make(Workshop());
        Assert.Equal(600m, e.HoneyStorage);
        e.State.Upgrades.Add(BeekeeperUpgrades.BiggerCombs1);
        Assert.Equal(900m, e.HoneyStorage);
        e.State.Upgrades.Add(BeekeeperUpgrades.BiggerCombs2);
        Assert.Equal(1200m, e.HoneyStorage);
    }

    [Fact]
    public void BetterWaxCatcher_GivesThreeWaxPerFiftyHoney()
    {
        var e = Make(Workshop(s => { s.Bees = 5000m; s.HasWaxCatcher = true; s.Upgrades.Add(BeekeeperUpgrades.BetterWaxCatcher); }));
        e.Advance(1m);   // 50 honey
        Assert.Equal(3m, e.State.Wax);
    }

    [Fact]
    public void StrongerCandles_BurnHalfAsLongAgain()
    {
        var e = Make(Workshop(s => { s.RepellentCandles = 2m; }));
        Assert.Equal(900m, e.RepellentBurnSeconds);
        e.State.Upgrades.Add(BeekeeperUpgrades.StrongerCandles);
        e.LightRepellent();
        Assert.Equal(1350m, e.State.RepellentSecondsLeft);
    }

    // ============================================================ wasps

    [Fact]
    public void NoWorkbench_NoWasps()
    {
        var e = Make(new BeekeeperState { Combs = 1 }, 0.0);
        Assert.Empty(e.AdvanceWaspTime(10_000m));
        Assert.False(e.WaspApproaching);
    }

    [Fact]
    public void AWasp_ArrivesAfterFourToEightMinutesOfWaspTime()
    {
        var e = Make(Workshop(), 0.5);    // 240 + 0.5 × 240 = 360 s
        Assert.Empty(e.AdvanceWaspTime(359m));
        Assert.True(Has(e.AdvanceWaspTime(1m), BeekeeperEvents.WaspArrives));
        Assert.True(e.WaspApproaching);
        Assert.Equal(60m, e.State.WaspCountdown);
        Assert.Empty(e.AdvanceWaspTime(1000m));   // one wasp at a time
    }

    [Fact]
    public void NoResponseForAMinute_TheWaspRaids()
    {
        var e = Make(Workshop(s => { s.Bees = 1000m; s.Honey = 500m; s.Wax = 40m; s.Sage = 3m; s.BeeswaxCandles = 4m; }), 0.0);
        e.AdvanceWaspTime(240m);
        Assert.Empty(e.AdvanceWaspCountdown(59m));
        var raid = e.AdvanceWaspCountdown(1m).Single();
        Assert.Equal(BeekeeperEvents.WaspRaid, raid.Key);
        Assert.Equal(500m, raid.Value);    // 3 minutes of 10 honey/s is 1,800, but only 500 stored
        Assert.Equal(150m, raid.Value2);   // 15% of 1,000 bees
        Assert.Equal(0m, e.State.Honey);
        Assert.Equal(850m, e.State.Bees);
        Assert.Equal(40m, e.State.Wax);            // never wax,
        Assert.Equal(3m, e.State.Sage);            // sage
        Assert.Equal(4m, e.State.BeeswaxCandles);  // or candles
        Assert.False(e.WaspApproaching);
    }

    [Fact]
    public void ARaid_TakesThreeMinutesOfHoney_WhenThereIsPlenty()
    {
        var e = Make(Workshop(s => { s.Bees = 100m; s.Honey = 590m; }), 0.0);   // 1 honey/s
        e.AdvanceWaspTime(240m);
        e.AdvanceWaspCountdown(60m);
        Assert.Equal(410m, e.State.Honey);
        Assert.Equal(85m, e.State.Bees);
    }

    [Fact]
    public void AShoeThatHits_DrivesTheWaspOff_AndNothingIsLost()
    {
        var e = Make(Workshop(s => { s.Bees = 1000m; s.Honey = 500m; }), 0.0, 0.59);
        e.AdvanceWaspTime(240m);
        var r = e.ThrowShoe();
        Assert.True(Has(r.Events, BeekeeperEvents.ShoeHit));
        Assert.False(e.WaspApproaching);
        Assert.Equal(1000m, e.State.Bees);
        Assert.Equal(500m, e.State.Honey);
    }

    [Fact]
    public void AShoeThatMisses_MeansARaidAtOnce()
    {
        var e = Make(Workshop(s => { s.Bees = 1000m; s.Honey = 500m; }), 0.0, 0.60);
        e.AdvanceWaspTime(240m);
        var r = e.ThrowShoe();
        Assert.True(Has(r.Events, BeekeeperEvents.ShoeMissRaid));
        Assert.False(e.WaspApproaching);
        Assert.Equal(850m, e.State.Bees);
        Assert.False(e.ThrowShoe().Done);   // one throw per wasp
    }

    [Fact]
    public void ABribe_CostsAQuarterOfTheHoney_AndNoBees()
    {
        var e = Make(Workshop(s => { s.Bees = 1000m; s.Honey = 403m; }), 0.0);
        e.AdvanceWaspTime(240m);
        var r = e.Bribe();
        Assert.Equal(100m, r.Amount);
        Assert.Equal(303m, e.State.Honey);
        Assert.Equal(1000m, e.State.Bees);
        Assert.False(e.WaspApproaching);
    }

    [Fact]
    public void ABribe_CostsAtLeastOneHoney_AndNeedsSome()
    {
        var some = Make(Workshop(s => s.Honey = 2m), 0.0);
        some.AdvanceWaspTime(240m);
        Assert.Equal(1m, some.Bribe().Amount);

        var none = Make(Workshop(s => s.Honey = 0.5m), 0.0);
        none.AdvanceWaspTime(240m);
        Assert.False(none.Bribe().Done);
        Assert.True(none.WaspApproaching);
    }

    [Fact]
    public void LightingACandle_SendsAnApproachingWaspAway_AndKeepsWaspsOffWhileItBurns()
    {
        var e = Make(Workshop(s => { s.RepellentCandles = 1m; s.Bees = 1000m; }), 0.0, 0.0);
        e.AdvanceWaspTime(240m);
        Assert.True(e.LightRepellent().Done);
        Assert.False(e.WaspApproaching);
        Assert.Equal(0m, e.State.RepellentCandles);

        Assert.Empty(e.AdvanceWaspTime(899m));
        Assert.True(Has(e.AdvanceWaspTime(1m), BeekeeperEvents.CandleOut));
        Assert.True(Has(e.AdvanceWaspTime(240m), BeekeeperEvents.WaspArrives));   // wasps again afterwards
    }

    [Fact]
    public void LightingASecondCandle_AddsItsTime()
    {
        var e = Make(Workshop(s => s.RepellentCandles = 2m));
        e.LightRepellent();
        e.LightRepellent();
        Assert.Equal(1800m, e.State.RepellentSecondsLeft);
    }

    [Fact]
    public void AWaspThatLeaves_TakesNothing()
    {
        var e = Make(Workshop(s => { s.Bees = 1000m; s.Honey = 500m; }), 0.0);
        e.AdvanceWaspTime(240m);
        Assert.True(Has(e.WaspLeaves(), BeekeeperEvents.WaspLeft));
        Assert.False(e.WaspApproaching);
        Assert.Equal(1000m, e.State.Bees);
        Assert.Equal(500m, e.State.Honey);
    }

    [Fact]
    public void TimeAway_NeverBringsWasps_OrBurnsCandles()
    {
        var e = Make(Workshop(s => { s.Bees = 100m; s.RepellentSecondsLeft = 500m; s.NextWaspInSeconds = 100m; }));
        e.AdvanceAway(3 * 24 * 3600m);
        Assert.False(e.WaspApproaching);
        Assert.Equal(500m, e.State.RepellentSecondsLeft);
        Assert.Equal(100m, e.State.NextWaspInSeconds);
    }

    // ============================================================ saving

    [Fact]
    public void AFirstBuildSave_LoadsWithNothingLost()
    {
        Directory.CreateDirectory(_dir);
        string path = Path.Combine(_dir, "beekeeper.json");
        File.WriteAllText(path,
            "{\"Version\":1,\"Bees\":120,\"Honey\":45.5,\"Wax\":30,\"Beebits\":12,\"Combs\":2,\"BearName\":\"Baloo\"," +
            "\"HoneyRevealed\":true,\"Log\":[{\"Key\":\"new_game\",\"Value\":0}]," +
            "\"SavedAtUtc\":\"2026-11-06T12:00:00Z\"}");

        var loaded = BeekeeperSaveService.Load(path);
        Assert.NotNull(loaded);
        Assert.Equal(120m, loaded!.Bees);
        Assert.Equal(45.5m, loaded.Honey);
        Assert.Equal("Baloo", loaded.BearName);
        Assert.Equal(0m, loaded.Sage);
        Assert.Empty(loaded.Upgrades);

        var e = new BeekeeperEngine(BeekeeperConfig.Default, loaded);
        Assert.True(Has(e.RevealOnLoad(), BeekeeperEvents.WorkbenchOpened));
    }

    [Fact]
    public void Stage2Things_AreSaved_ButAnApproachingWaspIsNot()
    {
        Directory.CreateDirectory(_dir);
        string path = Path.Combine(_dir, "beekeeper.json");
        var s = Workshop(x =>
        {
            x.BeeswaxCandles = 7m; x.RepellentCandles = 2m; x.CandlesCrafted = 19; x.Sage = 3m; x.HippieTrades = 4;
            x.HippiesRevealed = true; x.SageRevealed = true; x.RepellentUnlocked = true;
            x.Upgrades.Add(BeekeeperUpgrades.BiggerCombs1);
            x.RepellentSecondsLeft = 321m; x.NextWaspInSeconds = 123m; x.WaspCountdown = 30m;
            x.Log.Add(new BeekeeperLogEntry { Key = BeekeeperEvents.WaspRaid, Value = 50m, Value2 = 12m });
        });
        Assert.True(BeekeeperSaveService.Save(s, path, new DateTime(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc)));

        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.CurrentVersion, back.Version);
        Assert.Equal(7m, back.BeeswaxCandles);
        Assert.Equal(2m, back.RepellentCandles);
        Assert.Equal(19, back.CandlesCrafted);
        Assert.Equal(3m, back.Sage);
        Assert.Equal(4, back.HippieTrades);
        Assert.True(back.WorkbenchRevealed && back.HippiesRevealed && back.SageRevealed && back.RepellentUnlocked);
        Assert.Equal(new[] { BeekeeperUpgrades.BiggerCombs1 }, back.Upgrades);
        Assert.Equal(321m, back.RepellentSecondsLeft);
        Assert.Equal(123m, back.NextWaspInSeconds);
        Assert.Equal(0m, back.WaspCountdown);
        Assert.Equal(12m, back.Log.Single().Value2);
    }
}
