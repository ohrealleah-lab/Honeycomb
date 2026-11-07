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
        var e = Make(new BeekeeperState { ToolLevel = 3, ShopRevealed = true, Beebits = 20_000m });
        Assert.True(e.BuyNextTool().Done);
        Assert.Equal(25, e.BeesPerClick);
        Assert.True(e.BuyNextTool().Done);
        Assert.Equal(60, e.BeesPerClick);
        Assert.True(e.BuyNextTool().Done);
        Assert.Equal(150, e.BeesPerClick);
        Assert.Equal(20_000m - 1_000m - 4_000m - 15_000m, e.State.Beebits);
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
    public void PracticeAndTheSmoker_ComeWithTheVacuum_WithoutTheWorkbench()
    {
        Assert.Empty(Make(new BeekeeperState { ToolLevel = 2 }).ShopUpgrades);

        var e = Make(new BeekeeperState { ToolLevel = 3, Beebits = 5_000m, Wax = 500m, Sage = 5m });
        Assert.Equal(new[] { BeekeeperUpgrades.Practice, BeekeeperUpgrades.Smoker }, e.ShopUpgrades.Select(u => u.Id));
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.Practice).Done);
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.MorePractice);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.Practice);
    }

    // ============================================================ the slice

    [Fact]
    public void EveryCatch_AlsoBringsInASliceOfTheHive()
    {
        var e = Make(new BeekeeperState { ToolLevel = 6, Bees = 250_000m });
        Assert.Equal(400m, e.BeesPerCatch);   // 150 + 250
        Assert.Equal(400m, e.Catch().BeesGained);
        Assert.Equal(250_400m, e.State.Bees);
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
        Assert.Equal(20m + 100m, e.BeesPerCatch);
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
        var s = new BeekeeperState { ToolLevel = 3, Bees = 100m, Upgrades = { BeekeeperUpgrades.Smoker } };
        tweak?.Invoke(s);
        return Make(s, dice);
    }

    [Fact]
    public void WithoutTheSmoker_ClicksDoNotFillAnyMeter()
    {
        var e = Make(new BeekeeperState { ToolLevel = 3 });
        for (int i = 0; i < 20; i++) e.Catch();
        Assert.Equal(0, e.State.CalmMeter);
    }

    [Fact]
    public void FifteenClicks_FillTheMeter_AndItStopsThere()
    {
        var e = WithSmoker();
        for (int i = 0; i < 14; i++) e.Catch();
        Assert.False(e.CanPuff);
        e.Catch();
        Assert.True(e.CanPuff);
        for (int i = 0; i < 10; i++) e.Catch();
        Assert.Equal(15, e.State.CalmMeter);
    }

    [Fact]
    public void StingsFillTheMeterToo()
    {
        var e = WithSmoker(s => s.ToolLevel = 0, 0.0, 0.0, 0.0);
        e.Catch(); e.Catch(); e.Catch();
        Assert.Equal(3, e.State.CalmMeter);
    }

    [Fact]
    public void APuff_CalmsTheBeesForTwoMinutes_AndDoublesHoney()
    {
        var e = WithSmoker(s => { s.CalmMeter = 15; s.Honey = 0m; s.Combs = 5; });   // 100 bees: 1 honey/s; room for 1,200
        var r = e.PuffSmoker();
        Assert.True(r.Done);
        Assert.Equal(0, e.State.CalmMeter);
        Assert.Equal(120m, e.State.CalmSecondsLeft);
        Assert.True(Has(r.Events, BeekeeperEvents.SmokerPuffed));
        Assert.Equal(2m, e.HoneyPerSecondNow);
        Assert.Equal(1m, e.HoneyPerSecond);   // raids still use the plain rate

        e.Advance(100m);
        Assert.Equal(200m, e.State.Honey);
        var end = e.Advance(30m);              // 20 calm seconds, then 10 plain
        Assert.Equal(200m + 40m + 10m, e.State.Honey);
        Assert.True(Has(end.Events, BeekeeperEvents.CalmEnded));
        Assert.False(e.IsCalm);
    }

    [Fact]
    public void NoSecondPuff_UntilTheCalmEnds()
    {
        var e = WithSmoker(s => { s.CalmMeter = 15; });
        e.PuffSmoker();
        e.State.CalmMeter = 15;
        Assert.False(e.CanPuff);
        Assert.False(e.PuffSmoker().Done);
        e.Advance(120m);
        Assert.True(e.CanPuff);
    }

    [Fact]
    public void CalmBees_MakeWaxTwiceAsFastToo()
    {
        var e = WithSmoker(s => { s.Bees = 5000m; s.CalmSecondsLeft = 10m; s.Honey = 0m; });   // 50 honey/s, 100 calm
        e.Advance(1m);
        Assert.Equal(2m, e.State.Wax);
    }

    [Fact]
    public void WaxPerSecond_FollowsHoney_TheCatcher_AndCalm()
    {
        var e = WithSmoker(s => s.Bees = 1000m);   // 10 honey/s
        Assert.Equal(0.2m, e.WaxPerSecondNow);
        e.State.HasWaxCatcher = true;
        Assert.Equal(0.4m, e.WaxPerSecondNow);
        e.State.CalmSecondsLeft = 60m;
        Assert.Equal(0.8m, e.WaxPerSecondNow);
    }

    [Fact]
    public void TimeAway_NeitherUsesUpNorDoublesCalm()
    {
        var calm = WithSmoker(s => { s.CalmSecondsLeft = 100m; s.Honey = 0m; });
        var plain = WithSmoker(s => { s.Honey = 0m; });
        calm.AdvanceAway(3600m);
        plain.AdvanceAway(3600m);
        Assert.Equal(plain.State.Honey, calm.State.Honey);
        Assert.Equal(100m, calm.State.CalmSecondsLeft);
    }

    // ============================================================ saving

    [Fact]
    public void TheSmokerAndCalm_AreSaved_AndOlderSavesStillLoad()
    {
        Directory.CreateDirectory(_dir);
        string path = Path.Combine(_dir, "beekeeper.json");
        var s = new BeekeeperState { ToolLevel = 6, CalmMeter = 9, CalmSecondsLeft = 42m, Upgrades = { BeekeeperUpgrades.Smoker } };
        Assert.True(BeekeeperSaveService.Save(s, path, new DateTime(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc)));
        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.CurrentVersion, back.Version);
        Assert.Equal(6, back.ToolLevel);
        Assert.Equal(9, back.CalmMeter);
        Assert.Equal(42m, back.CalmSecondsLeft);

        File.WriteAllText(path, "{\"Version\":2,\"Bees\":10,\"ToolLevel\":3,\"Upgrades\":[\"bigger_combs_1\"],\"Log\":[]}");
        var old = BeekeeperSaveService.Load(path)!;
        Assert.Equal(0, old.CalmMeter);
        Assert.Equal(0m, old.CalmSecondsLeft);
        Assert.Equal(new[] { "bigger_combs_1" }, old.Upgrades);
    }
}
