using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 3 rules (spec 011): tools after the Vacuum, Practice, the slice, the Smoker.</summary>
public class BeekeeperStage3Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage3-tests-" + Guid.NewGuid().ToString("N"));

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

    // ============================================================ tools after the Vacuum

    [Fact]
    public void AfterTheVacuum_ComeTheLure_TheCart_AndTheWhistle_InOrder()
    {
        var e = Make(new BeekeeperState { ToolLevel = 3, ShopRevealed = true, Beebits = 43_000m });
        Assert.True(e.BuyNextTool().Done);
        Assert.Equal(25, e.BeesPerClick);
        Assert.True(e.BuyNextTool().Done);
        Assert.Equal(60, e.BeesPerClick);
        Assert.True(e.BuyNextTool().Done);
        Assert.Equal(150, e.BeesPerClick);
        Assert.Equal(43_000m - 3_000m - 10_000m - 30_000m, e.State.Beebits);
        Assert.Null(e.NextTool);              // nothing after the Hive Whistle in this build
        Assert.False(e.BuyNextTool().Done);
    }

    // ============================================================ Practice

    [Fact]
    public void Practice_AndMorePractice_GrowTheToolsBees()
    {
        var e = Make(new BeekeeperState { ToolLevel = 3 });
        e.State.Upgrades.Add(BeekeeperUpgrades.Practice);
        Assert.Equal(15, e.BeesPerClick);
        e.State.Upgrades.Add(BeekeeperUpgrades.MorePractice);
        Assert.Equal(20, e.BeesPerClick);
    }

    [Fact]
    public void PracticeComesWithTheVacuum_WithoutTheWorkbench_AndTheSmokerNeedsNothing()
    {
        Assert.Equal(new[] { BeekeeperUpgrades.Smoker }, Make(new BeekeeperState { ToolLevel = 2 }).ShopUpgrades.Select(u => u.Id));

        var e = Make(new BeekeeperState { ToolLevel = 3, Beebits = 5_000m, Wax = 500m, Herbs = 5m, Bees = 5_000m, WaxTrays = 100 });   // trays: room for every wax price
        Assert.Equal(new[] { BeekeeperUpgrades.Practice, BeekeeperUpgrades.Smoker }, e.ShopUpgrades.Select(u => u.Id));
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.Practice).Done);
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.MorePractice);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Practice);
    }

    // ============================================================ the slice

    [Fact]
    public void EveryCatch_IsExactlyTheToolsBees_NoSliceOfTheHive()
    {
        var e = Make(new BeekeeperState { ToolLevel = 6, Bees = 250_000m });
        Assert.Equal(150m, e.BeesPerCatch);
        Assert.Equal(150m, e.Catch().BeesGained);
        Assert.Equal(250_150m, e.State.Bees);
    }

    [Fact]
    public void ASmallHive_GetsNoSlice()
    {
        var e = Make(new BeekeeperState { ToolLevel = 1, Bees = 999m });
        Assert.Equal(2m, e.BeesPerCatch);
    }

    [Fact]
    public void Practice_GrowsTheTool_NotTheSlice()
    {
        var e = Make(new BeekeeperState { ToolLevel = 3, Bees = 100_000m });
        e.State.Upgrades.Add(BeekeeperUpgrades.MorePractice);
        Assert.Equal(20m, e.BeesPerCatch);
    }

    [Fact]
    public void AStingCatchesNothing_SliceIncluded()
    {
        var e = Make(new BeekeeperState { Bees = 500_000m }, 0.0);   // bare hands, stung
        var r = e.Catch();
        Assert.True(r.Stung);
        Assert.Equal(500_000m, e.State.Bees);
    }

    // ============================================================ the Smoker

    private static BeekeeperEngine WithSmoker(Action<BeekeeperState>? tweak = null, params double[] dice)
    {
        // 5 combs: 1 honey/s, plenty of room.
        var s = new BeekeeperState { ToolLevel = 3, Bees = 100m, Honey = 0m, Combs = 5, HoneyRevealed = true,
                                     Upgrades = { BeekeeperUpgrades.Smoker } };
        tweak?.Invoke(s);
        return Make(s, dice);
    }

    [Fact]
    public void OneHerbalCandle_BuysTheSmoker_WithNothingElseNeeded()
    {
        // Bee, 2026-11-11: Beebits come from the Hippies; one herbal candle pays for the Smoker.
        var e = Make(new BeekeeperState { HippiesRevealed = true, BearName = "Bruno", RepellentCandles = 1m, HoneyRevealed = true });
        Assert.False(e.CanBuyUpgrade(BeekeeperUpgrades.Smoker));   // no Beebits yet
        e.TradeTenCandles();
        Assert.Equal(10m, e.State.Beebits);
        Assert.True(e.State.ShopRevealed);
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Smoker);
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.Smoker).Done);
        Assert.Equal(0m, e.State.Beebits);
        Assert.True(e.CanUseSmoker);
    }

    [Fact]
    public void WithoutTheSmoker_TheSmokerButtonDoesNothing()
    {
        var e = Make(new BeekeeperState { ToolLevel = 3, Combs = 5, HoneyRevealed = true });
        Assert.False(e.CanUseSmoker);
        Assert.False(e.UseSmoker().Done);
        Assert.False(e.IsSmokerBoosted);
        Assert.Equal(1m, e.HoneyPerSecondNow);
    }

    [Fact]
    public void ASmokerClick_DoublesHoney_ForOneSecond()
    {
        var e = WithSmoker();
        Assert.True(e.UseSmoker().Done);
        Assert.True(e.IsSmokerBoosted);
        Assert.Equal(2m, e.HoneyPerSecondNow);
        Assert.Equal(1m, e.HoneyPerSecond);   // raids still use the plain rate

        e.Advance(0.5m);
        Assert.Equal(1m, e.State.Honey);
        Assert.True(e.IsSmokerBoosted);
        e.Advance(1.5m);                       // 0.5 boosted second, then 1 plain
        Assert.Equal(1m + 1m + 1m, e.State.Honey);
        Assert.False(e.IsSmokerBoosted);
        Assert.Equal(1m, e.HoneyPerSecondNow);
    }

    [Fact]
    public void KeepClicking_KeepsTheBoostOn_WithoutStackingTime()
    {
        var e = WithSmoker();
        e.UseSmoker();
        for (int i = 0; i < 4; i++) { e.Advance(0.8m); e.UseSmoker(); }
        Assert.Equal(4 * 0.8m * 2m, e.State.Honey);
        Assert.Equal(1m, e.State.SmokerBoostSecondsLeft);   // a click refreshes to 1s, never more
        e.Advance(3m);
        Assert.Equal(4 * 0.8m * 2m + 2m + 2m, e.State.Honey);
    }

    [Fact]
    public void TheSmokerBoost_MultipliesWithTheBeeBoostCandle()
    {
        var e = WithSmoker(s => s.BeeBoostSecondsLeft = 10m);
        decimal candle = e.HoneyPerSecondNow;
        e.UseSmoker();
        Assert.Equal(candle * 2m, e.HoneyPerSecondNow);
        e.Advance(1m);
        Assert.Equal(candle * 2m, e.State.Honey);
    }

    [Fact]
    public void TheBoostPercentAndSeconds_ComeFromTheConfig()
    {
        var config = new BeekeeperConfig { SmokerBoostPercent = 75m, SmokerBoostSeconds = 2m };
        var s = new BeekeeperState { ToolLevel = 3, Combs = 5, HoneyRevealed = true, Upgrades = { BeekeeperUpgrades.Smoker } };
        var e = new BeekeeperEngine(config, s, new FakeRandom());
        e.UseSmoker();
        Assert.Equal(1.75m, e.HoneyPerSecondNow);
        Assert.Equal(75m, e.UpgradeBonusPercent(BeekeeperUpgrades.Smoker));
        e.Advance(2m);
        Assert.Equal(3.5m, e.State.Honey);
        Assert.False(e.IsSmokerBoosted);
    }

    [Fact]
    public void TheSmokerBoost_LeavesWaxAlone()
    {
        var e = WithSmoker(s => s.Bees = 1000m);
        decimal wax = e.WaxPerSecondNow;
        e.UseSmoker();
        Assert.Equal(wax, e.WaxPerSecondNow);
    }

    [Fact]
    public void TimeAway_NeitherUsesUpNorGetsTheSmokerBoost()
    {
        var boosted = WithSmoker();
        var plain = WithSmoker();
        boosted.UseSmoker();
        boosted.AdvanceAway(3600m);
        plain.AdvanceAway(3600m);
        Assert.Equal(plain.State.Honey, boosted.State.Honey);
    }

    // ============================================================ saving

    [Fact]
    public void TheSmokerBoost_IsNotSaved_AndSavesWithTheOldCalmFieldsStillLoad()
    {
        Directory.CreateDirectory(_dir);
        string path = Path.Combine(_dir, "beekeeper.json");
        var s = new BeekeeperState { ToolLevel = 6, SmokerBoostSecondsLeft = 1m, Upgrades = { BeekeeperUpgrades.Smoker } };
        Assert.True(BeekeeperSaveService.Save(s, path, new DateTime(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc)));
        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.CurrentVersion, back.Version);
        Assert.Equal(6, back.ToolLevel);
        Assert.Equal(0m, back.SmokerBoostSecondsLeft);

        // A save from before the click boost, still carrying the Calm meter's fields.
        string json = File.ReadAllText(path);
        File.WriteAllText(path, "{\"CalmMeter\":9,\"CalmSecondsLeft\":42," + json.TrimStart().Substring(1));
        var old = BeekeeperSaveService.Load(path)!;
        Assert.Equal(6, old.ToolLevel);
        Assert.Contains(BeekeeperUpgrades.Smoker, old.Upgrades);
        Assert.Equal(0m, old.SmokerBoostSecondsLeft);

        File.WriteAllText(path, "{\"Version\":2,\"Bees\":10,\"ToolLevel\":3,\"Upgrades\":[\"bigger_combs_1\"],\"Log\":[]}");
        Assert.Null(BeekeeperSaveService.Load(path));   // stage 7.5: an older save starts a new game
    }
}
