using System;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 7.5 (spec 016) on the screen's side: walls kept apart from "can't afford yet",
/// the wax row with its cap, the capacity rows, the bear's bundle of the moment and the debug commands.</summary>
public class BeekeeperStage75ViewModelTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static readonly DateTime T0 = new(2026, 11, 9, 12, 0, 0, DateTimeKind.Utc);

    private static BeekeeperViewModel Make(BeekeeperState? state = null) =>
        new(isHeadless: true, persist: false, rng: new NoRandom(), clock: () => T0, initialState: state);

    private static BeekeeperHiveRow Row(BeekeeperViewModel vm, string id) =>
        vm.HiveGroups.SelectMany(g => g.Rows).Single(r => r.Id == id);

    [Fact]
    public void AWall_AndCantAffordYet_AreTwoDifferentStates()
    {
        var wall = Make(new BeekeeperState { Combs = 8, CombsRevealed = true, Bees = 1000m, Wax = 34m });
        Assert.True(wall.CombIsWall);           // 47 wax, but the hive holds 34
        Assert.False(wall.CanBuildComb);
        Assert.Equal(34m, wall.WaxStorage);

        var poor = Make(new BeekeeperState { Combs = 2, CombsRevealed = true, Bees = 1000m, Wax = 5m });
        Assert.False(poor.CombIsWall);          // 12 wax fits in 22; there just isn't enough yet
        Assert.False(poor.CanBuildComb);
    }

    [Fact]
    public void ShopAndWoodenHiveWalls_AreExposedPerRow()
    {
        var vm = Make(new BeekeeperState { Combs = 3, WorkbenchRevealed = true, ShopRevealed = true, BeeBreadRevealed = true });
        Assert.True(vm.UpgradeIsWall(BeekeeperUpgrades.BiggerCombs1));
        Assert.False(vm.UpgradeIsWall(BeekeeperUpgrades.Notebook));
        Assert.True(vm.WoodenHiveIsWall);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.FirstWall);   // told once on load
    }

    [Fact]
    public void TheWaxRow_ShowsItsCap_AndTheWaxFullLineComesAtTheCap()
    {
        var vm = Make(new BeekeeperState { HoneyRevealed = true, WaxRevealed = true, Wax = 12.9m });
        var wax = Row(vm, BeekeeperHiveRows.Wax);
        Assert.Equal(12m, wax.Value);           // rounded down, fractions kept behind the scenes
        Assert.Equal(20m, wax.Value2);
        Assert.False(Row(vm, BeekeeperHiveRows.WaxFull).Visible);
        Assert.Equal("12 / 20", vm.WaxDisplay);

        vm.DebugFillWax();
        Assert.True(Row(vm, BeekeeperHiveRows.WaxFull).Visible);
        Assert.True(vm.WaxIsFull);
    }

    [Fact]
    public void TheHiveCard_ComesWithTheFirstWax_AndTheHoneyRowWithTheFirstBee()
    {
        var vm = Make(new BeekeeperState { WaxRevealed = true, Wax = 1m });
        Assert.True(vm.HiveCardShown);
        Assert.False(Row(vm, BeekeeperHiveRows.Honey).Visible);
        vm.CatchCommand.Execute(null);
        Assert.True(Row(vm, BeekeeperHiveRows.Honey).Visible);
        Assert.Equal(0.2m, Row(vm, BeekeeperHiveRows.Honey).Rate);
    }

    [Fact]
    public void CapacityRows_BuyAgainAndAgain_AndShowTheNextPriceAndLevel()
    {
        var vm = Make(new BeekeeperState { ShopRevealed = true, CombsRevealed = true, Beebits = 500m });
        Assert.True(vm.CapacityUpgradesShown);
        Assert.Equal(75m, vm.HoneySuperCost);
        vm.BuyHoneySuperCommand.Execute(null);
        Assert.Equal(1, vm.HoneySupers);
        Assert.Equal(112m, vm.HoneySuperCost);
        Assert.Equal(1200m, vm.HoneyStorage);
        vm.BuyWaxTrayCommand.Execute(null);
        Assert.Equal(1, vm.WaxTrays);
        Assert.Equal(30m, vm.WaxStorage);
        Assert.Equal(145m, vm.WaxTrayCost);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.HoneySuperBought);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.WaxTrayBought);
    }

    [Fact]
    public void TheCombRow_ShowsBothPrices_AndWhatAOneCombGives()
    {
        var vm = Make();
        Assert.Equal(20m, vm.CombBeeCost);
        Assert.Equal(10m, vm.CombCost);
        Assert.Equal(0.2m, vm.HoneyPerComb);
        Assert.Equal(300m, vm.StoragePerComb);
        Assert.Equal(2m, vm.WaxStoragePerComb);
    }

    [Fact]
    public void TheDebugCommands_AddCombs_FillWax_AndGiveFreeBees()
    {
        var vm = Make();
        vm.DebugAddCombs(5);
        Assert.Equal(6, vm.Combs);
        Assert.True(vm.WorkbenchRevealed);
        vm.DebugFillWax();
        Assert.Equal(vm.WaxStorage, vm.Wax);
        vm.DebugGrant(10_000m, 0m, 0m);
        Assert.Equal(10_000m, vm.Bees);
        Assert.True(vm.HiveStarted);
    }

    [Fact]
    public void TimeAway_AtZeroFreeBees_StillWelcomesThePlayerBack()
    {
        var vm = Make(new BeekeeperState { HoneyRevealed = true, Bees = 0m, BearName = "Bruno" });
        vm.DebugSpendAway(8m * 3600m);
        Assert.Equal(BeekeeperEvents.WelcomeBack, vm.Log[0].Key);
        Assert.Equal(200m, vm.Honey);
        Assert.Equal(20m, vm.Wax);
    }
}
