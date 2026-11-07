using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 4 on the view-model side (spec 012): the commands, the log, ticking and time away.</summary>
public class BeekeeperGardenViewModelTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-garden-vm-tests-" + Guid.NewGuid().ToString("N"));
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

    [Fact]
    public void TheFifthHippieTrade_LogsTheSeed_AndTheGardenAppears()
    {
        var vm = Make(new Clock(), new BeekeeperState { HippiesRevealed = true, HippieTrades = 4, BeeswaxCandles = 10m, BearName = "Bruno" });
        Assert.False(vm.GardenRevealed);
        vm.TradeOffers.First(o => o.Id == "hippies").TradeOne();
        Assert.True(Logged(vm, BeekeeperEvents.SeedGiven));
        Assert.Equal(1, vm.Seeds);
        Assert.True(vm.GardenRevealed);
        Assert.True(vm.CanPlantSeed);
    }

    [Fact]
    public void Planting_ThenTenMinutesOfTicks_SproutsAndLogsBothLines()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Seeds = 1, SeedsGiven = 1, GardenRevealed = true, BearName = "Bruno" });
        vm.PlantSeedCommand.Execute(null);
        Assert.True(Logged(vm, BeekeeperEvents.SeedPlanted));
        Assert.True(vm.IsGrowing);
        Assert.False(vm.CanPlantSeed);

        for (int i = 0; i < 600; i++) { clock.Advance(1); vm.Tick(); }

        Assert.False(vm.IsGrowing);
        Assert.True(Logged(vm, BeekeeperEvents.SeedSprouted));
        Assert.True(Logged(vm, BeekeeperEvents.PlantRevealed));
        Assert.Single(vm.SproutedPlants);
    }

    [Fact]
    public void ReopeningAfterTwentyMinutes_HasSprouted_AndForagersArrived()
    {
        var clock = new Clock();
        var first = Make(clock, new BeekeeperState { Seeds = 1, SeedsGiven = 1, GardenRevealed = true, BearName = "Bruno", Bees = 10m, HoneyRevealed = true }, persist: true);
        first.PlantSeedCommand.Execute(null);
        first.SaveNow();
        first.Dispose();

        clock.Advance(20 * 60);
        var second = Make(clock, state: null, persist: true);
        Assert.False(second.IsGrowing);
        Assert.Single(second.SproutedPlants);
        Assert.Equal(10m, second.ForagerBees);          // 10 minutes of wildflowers
        Assert.Equal(BeekeeperPlants.Wildflowers, second.SproutedPlants[0].Id);
    }

    [Fact]
    public void BeeBreadAndTheWoodenHive_RunThroughTheCommands()
    {
        var vm = Make(new Clock(), new BeekeeperState
        {
            PollenRevealed = true, Pollen = 100m, Honey = 100m, Wax = 250m, Bees = 10m, HoneyRevealed = true, BearName = "Bruno",
        });
        for (int i = 0; i < 10; i++) vm.MakeBeeBreadCommand.Execute(null);
        Assert.Equal(10m, vm.BeeBread);
        Assert.Equal(0m, vm.Pollen);
        Assert.Equal(0m, vm.Honey);
        Assert.True(Logged(vm, BeekeeperEvents.BeeBreadMade));
        Assert.True(vm.WoodenHiveOffered);
        Assert.True(vm.CanMoveToWoodenHive);

        vm.MoveToWoodenHiveCommand.Execute(null);
        Assert.True(vm.HasWoodenHive);
        Assert.True(Logged(vm, BeekeeperEvents.WoodenHive));
        Assert.False(vm.WoodenHiveOffered);
        Assert.Equal(50m, vm.Wax);
        Assert.False(vm.CanMoveToWoodenHive);
    }

    [Fact]
    public void TheDebugHelpers_GiveASeed_FinishGrowing_AndPollen()
    {
        var vm = Make(new Clock(), new BeekeeperState { BearName = "Bruno" });
        vm.DebugGiveSeed();
        Assert.Equal(1, vm.Seeds);
        vm.PlantSeedCommand.Execute(null);
        vm.DebugFinishGrowing();
        Assert.Single(vm.SproutedPlants);
        vm.DebugGivePollen(10m);
        Assert.Equal(10m, vm.Pollen);
        Assert.True(vm.PollenRevealed);
        Assert.True(Logged(vm, BeekeeperEvents.FirstPollen));
    }

    [Fact]
    public void AGardenInProgress_IsKeptWhenTheGameIsReopenedQuickly()
    {
        var clock = new Clock();
        var first = Make(clock, new BeekeeperState { Seeds = 2, SeedsGiven = 2, GardenRevealed = true, BearName = "Bruno" }, persist: true);
        first.PlantSeedCommand.Execute(null);
        clock.Advance(1);
        first.Dispose();

        var second = Make(clock, state: null, persist: true);
        Assert.Equal(1, second.Seeds);
        Assert.True(second.IsGrowing);
        Assert.True(second.State.GrowSecondsLeft is > 590m and <= 600m);
    }
}
