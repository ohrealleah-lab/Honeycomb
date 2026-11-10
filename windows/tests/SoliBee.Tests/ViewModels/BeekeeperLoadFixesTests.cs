using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Review fixes: a locked save is never overwritten, an older save's queen and trade
/// agreement count for its first time away, and a candle burning out in an open-app gap says so.</summary>
public class BeekeeperLoadFixesTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "bk-fix-" + Guid.NewGuid().ToString("N"));

    public BeekeeperLoadFixesTests() => Directory.CreateDirectory(_dir);

    public void Dispose() { try { Directory.Delete(_dir, true); } catch { } }

    [Fact]
    public void ALockedSave_IsNotOverwrittenByTheFreshGame()
    {
        var path = Path.Combine(_dir, "beekeeper.json");
        BeekeeperSaveService.Save(new BeekeeperState { Bees = 123456m, BearName = "Real" }, path, DateTime.UtcNow);
        using (new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.None))
        {
            var vm = new BeekeeperViewModel(isHeadless: true, savePath: path);
            Assert.False(vm.SaveNow());
        }
        Assert.Equal(123456m, BeekeeperSaveService.Load(path)!.Bees);
    }

    [Fact]
    public void ALoadWithNoFile_StillSavesNormally()
    {
        var path = Path.Combine(_dir, "none.json");
        var vm = new BeekeeperViewModel(isHeadless: true, savePath: path);
        Assert.True(vm.SaveNow());
    }

    [Fact]
    public void AVersion4WoodenHive_RaisesBeesDuringItsFirstTimeAway()
    {
        var saved = new DateTime(2026, 11, 8, 0, 0, 0, DateTimeKind.Utc);
        var s = new BeekeeperState { Version = 4, BearName = "B", Bees = 1000m, HasWoodenHive = true, BeeBread = 10m, Combs = 200, SavedAtUtc = saved };
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: s, clock: () => saved.AddHours(8));
        Assert.True(vm.State.Bees > 1000m);
        Assert.True(vm.State.BeeBread < 10m);
    }

    // Cut in stage 7.5 (spec 016): older saves no longer load, and the agreement no longer sells honey while away.
    // [Fact]
    // public void AVersion4SaveWith120BearTrades_GetsTheAgreementForItsFirstTimeAway()
    // {
    //     var saved = new DateTime(2026, 11, 8, 0, 0, 0, DateTimeKind.Utc);
    //     var s = new BeekeeperState { Version = 4, BearName = "B", Bees = 1000m, Honey = 200m, Trades = 120, SavedAtUtc = saved };
    //     var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: s, clock: () => saved.AddHours(1));
    //     Assert.True(vm.State.Beebits > 0m);
    // }

    [Fact]
    public void ASaveWith45BearTrades_GetsTheBetterRateOnLoad_AndNothingIsSoldWhileAway()
    {
        var saved = new DateTime(2026, 11, 8, 0, 0, 0, DateTimeKind.Utc);
        var s = new BeekeeperState { BearName = "B", HoneyRevealed = true, Combs = 5, Honey = 1400m, Trades = 45, BearRevealed = true, SavedAtUtc = saved };
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: s, clock: () => saved.AddHours(1));
        Assert.True(vm.HasTradeAgreement);
        Assert.Equal(0m, vm.State.Beebits);
        Assert.Equal(8m, vm.HoneyPerBeebitNow);
        Assert.Equal(8m, vm.TradeOffers.Single(o => o.Id == "bear").GiveAmount);
    }

    [Fact]
    public void TheBeeCountIsCapped_SoThreeDaysAwayNeverOverflows()
    {
        var max = BeekeeperConfig.Default.MaxBees;
        var e = new BeekeeperEngine(state: new BeekeeperState { BearName = "B", Bees = max, HasTradeAgreement = true, Combs = 1 });
        e.AdvanceAway(259200m);
        Assert.Equal(max, e.State.Bees);
        e.DebugGrant(max, 0m, 0m);
        Assert.Equal(max, e.State.Bees);

        var path = Path.Combine(_dir, "huge.json");
        BeekeeperSaveService.Save(new BeekeeperState { Bees = max }, path, DateTime.UtcNow);
        Assert.NotNull(BeekeeperSaveService.Load(path));
        BeekeeperSaveService.Save(new BeekeeperState { Bees = max * 10m }, path, DateTime.UtcNow);
        Assert.Null(BeekeeperSaveService.Load(path));
    }

    [Fact]
    public void ThePropolisSeal_ShowsWithTheFirstPropolisLine_NotBefore()
    {
        var e = new BeekeeperEngine(state: new BeekeeperState { BearName = "B", Propolis = 0.5m });
        Assert.False(e.PropolisSeen);
        e.State.Propolis = 1m;
        Assert.True(e.PropolisSeen);
    }

    [Fact]
    public void ACandleBurningOutInAnOpenAppGap_IsLogged()
    {
        var t = new DateTime(2026, 11, 8, 12, 0, 0, DateTimeKind.Utc);
        var now = t;
        var s = new BeekeeperState { BearName = "B", Bees = 100m, HoneyRevealed = true, SagePropolisSecondsLeft = 10m };
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: s, clock: () => now);
        now = t.AddSeconds(30);
        vm.Tick();
        Assert.Equal(0m, vm.State.SagePropolisSecondsLeft);
        Assert.Contains(vm.State.Log, e => e.Key == BeekeeperEvents.SagePropolisOut);
    }
}
