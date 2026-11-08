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

    [Fact]
    public void AVersion4SaveWith120BearTrades_GetsTheAgreementForItsFirstTimeAway()
    {
        var saved = new DateTime(2026, 11, 8, 0, 0, 0, DateTimeKind.Utc);
        var s = new BeekeeperState { Version = 4, BearName = "B", Bees = 1000m, Honey = 200m, Trades = 120, SavedAtUtc = saved };
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: s, clock: () => saved.AddHours(1));
        Assert.True(vm.State.Beebits > 0m);
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
