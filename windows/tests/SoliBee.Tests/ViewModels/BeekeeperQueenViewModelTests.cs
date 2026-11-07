using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 5 on the view-model side (spec 013): the queen's row and rates, the agreement,
/// the welcome-back lines and the debug shortcuts.</summary>
public class BeekeeperQueenViewModelTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-queen-vm-tests-" + Guid.NewGuid().ToString("N"));
    private string SavePath => Path.Combine(_dir, "beekeeper.json");

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class Clock
    {
        public DateTime Now { get; set; } = new(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc);
        public void Advance(double seconds) => Now = Now.AddSeconds(seconds);
        public Func<DateTime> Func => () => Now;
    }

    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private BeekeeperViewModel Make(Clock clock, BeekeeperState? state = null, bool persist = false)
        => new(isHeadless: true, rng: new NoRandom(), clock: clock.Func, persist: persist,
               savePath: SavePath, initialState: state, noStressMode: () => true);

    private static bool Logged(BeekeeperViewModel vm, string key) => vm.Log.Any(e => e.Key == key);

    private static BeekeeperState Queen(decimal beeBread) => new()
    {
        Bees = 1000m, HasWoodenHive = true, QueenSettled = true, BeeBread = beeBread, BeeBreadRevealed = true,
        Combs = 1000, HoneyRevealed = true, BearName = "Bruno", BearRevealed = true,
    };

    [Fact]
    public void LoadingAWoodenHive_LogsTheQueen_AndShowsHerRow()
    {
        var vm = Make(new Clock(), new BeekeeperState { Bees = 100m, HasWoodenHive = true, HoneyRevealed = true });
        Assert.True(Logged(vm, BeekeeperEvents.QueenSettles));
        Assert.True(vm.HasQueen);
        Assert.False(vm.IsQueenLaying);   // no bee bread yet
    }

    [Fact]
    public void TheRates_ShowWhileLaying_AndReadZeroWhileResting()
    {
        var vm = Make(new Clock(), Queen(10m));
        Assert.True(vm.IsQueenLaying);
        Assert.Equal(1.0 / 3.0, (double)vm.QueenBeesPerSecond, 6);
        Assert.Equal(1.0 / 300.0, (double)vm.BeeBreadPerSecond, 6);
        Assert.Equal(3000m, vm.PantrySecondsLeft);

        vm.DebugSkip(3000m);
        Assert.False(vm.IsQueenLaying);
        Assert.Equal(0m, vm.QueenBeesPerSecond);
        Assert.Equal(0m, vm.BeeBreadPerSecond);
        Assert.True(Logged(vm, BeekeeperEvents.PantryEmpty));
    }

    [Fact]
    public void TicksGrowTheHive_WithoutClicking()
    {
        var clock = new Clock();
        var vm = Make(clock, Queen(10m));
        for (int i = 0; i < 60; i++) { clock.Advance(1); vm.Tick(); }
        Assert.Equal(1020m, Math.Round(vm.Bees, 6));
    }

    [Fact]
    public void DebugBeeBread_StartsTheQueenAgain_AndLogsIt()
    {
        var vm = Make(new Clock(), Queen(0m));
        vm.State.PantryEmptyAnnounced = true;
        vm.DebugGiveBeeBread(10m);
        Assert.True(vm.IsQueenLaying);
        Assert.True(Logged(vm, BeekeeperEvents.QueenResumes));
    }

    [Fact]
    public void BearTradesTo99_ThenOneSale_BringsTheAgreement()
    {
        var vm = Make(new Clock(), new BeekeeperState { Bees = 10m, Honey = 50m, HoneyRevealed = true, BearRevealed = true, BearName = "Bruno" });
        vm.DebugBearTradesToAlmostAgreement();
        Assert.Equal(99, vm.Trades);
        Assert.False(vm.HasTradeAgreement);
        vm.SellTen();
        Assert.True(vm.HasTradeAgreement);
        Assert.True(Logged(vm, BeekeeperEvents.TradeAgreement));
    }

    [Fact]
    public void TheAgreementRate_ShowsWhileTheCombsAreFull()
    {
        var vm = Make(new Clock(), new BeekeeperState { Bees = 1000m, Honey = 200m, HasTradeAgreement = true, HoneyRevealed = true, BearName = "Bruno" });
        Assert.Equal(0.5m, vm.AgreementBeebitsPerSecond);
    }

    [Fact]
    public void SpendingTimeAway_LogsTheWelcomeBackLines()
    {
        var s = Queen(10m);
        s.Combs = 0;
        s.HasTradeAgreement = true;
        var vm = Make(new Clock(), s);
        vm.DebugSpendAway(8m * 3600m);
        Assert.True(Logged(vm, BeekeeperEvents.WelcomeBack));
        Assert.True(Logged(vm, BeekeeperEvents.WelcomeBackQueen));
        Assert.True(Logged(vm, BeekeeperEvents.WelcomeBackBear));
        Assert.True(Logged(vm, BeekeeperEvents.WelcomeBackPantry));
        Assert.Equal(BeekeeperEvents.WelcomeBack, vm.Log[0].Key);   // newest first: the honey line on top
        Assert.Equal(2000m, Math.Round(vm.Bees, 6));
    }

    [Fact]
    public void ALongGapWhileTheAppIsOpen_IsQuiet_ButStillSaysThePantryRanOut()
    {
        var clock = new Clock();
        var vm = Make(clock, Queen(1m));
        clock.Advance(3600);
        vm.Tick();
        Assert.False(vm.Log.Any(e => BeekeeperEvents.IsWelcomeBack(e.Key)));
        Assert.True(Logged(vm, BeekeeperEvents.PantryEmpty));
    }

    [Fact]
    public void ReopeningAfterANight_CreditsTheQueen_AndKeepsTheAgreement()
    {
        var clock = new Clock();
        var s = Queen(100m);
        s.HasTradeAgreement = true;
        s.Trades = 120;
        var vm = Make(clock, s, persist: true);
        vm.SaveNow();
        vm.Dispose();

        clock.Advance(8 * 3600);
        var back = Make(clock, persist: true);
        Assert.True(back.HasQueen);
        Assert.True(back.HasTradeAgreement);
        Assert.Equal(1000m + 9600m, Math.Round(back.Bees, 6));   // 20 a minute for 8 hours
        Assert.True(Logged(back, BeekeeperEvents.WelcomeBackQueen));
        Assert.False(Logged(back, BeekeeperEvents.QueenSettles));   // she was already there
    }

    [Fact]
    public void BeesTimesTen_MultipliesTheHive()
    {
        var vm = Make(new Clock(), new BeekeeperState { Bees = 300m, HoneyRevealed = true });
        vm.DebugMultiplyBees();
        Assert.Equal(3000m, vm.Bees);
    }
}
