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
        var wall = Make(new BeekeeperState { Combs = 11, CombsRevealed = true, Bees = 1000m, Wax = 40m });
        Assert.True(wall.CombIsWall);           // 46 wax, but the hive holds 40
        Assert.False(wall.CanBuildComb);
        Assert.Equal(40m, wall.WaxStorage);

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
    public void CappedRows_ShareOneTimeToFullRule_Filling_Full_AndNoRate()
    {
        // Filling: (cap - amount) / rate, worked from the exact amount (wax 12.9 shows as 12).
        var filling = Make(new BeekeeperState { HoneyRevealed = true, WaxRevealed = true, Honey = 50m, Wax = 12.9m });
        var honey = Row(filling, BeekeeperHiveRows.Honey);
        Assert.Equal((filling.HoneyStorage - 50m) / filling.HoneyPerSecond, honey.SecondsToFull);
        var wax = Row(filling, BeekeeperHiveRows.Wax);
        Assert.Equal((filling.WaxStorage - 12.9m) / filling.WaxPerSecond, wax.SecondsToFull);

        // Full: 0, so the view says "Full" and never "0s".
        var full = Make(new BeekeeperState { HoneyRevealed = true, WaxRevealed = true, Honey = 200m, Wax = 20m });
        Assert.Equal(0m, Row(full, BeekeeperHiveRows.Honey).SecondsToFull);
        Assert.Equal(0m, Row(full, BeekeeperHiveRows.Wax).SecondsToFull);

        // No rate (and the shared rule itself): no time.
        Assert.Null(BeekeeperEngine.SecondsToFull(5m, 10m, 0m));
        Assert.Null(BeekeeperEngine.SecondsToFull(5m, 10m, -1m));
        Assert.Equal(0m, BeekeeperEngine.SecondsToFull(10m, 10m, 0m));
        Assert.Equal(5m, BeekeeperEngine.SecondsToFull(5m, 10m, 1m));

        // Rows without a cap never carry it.
        Assert.All(filling.HiveGroups.SelectMany(g => g.Rows).Where(r => r.Id is not (BeekeeperHiveRows.Honey or BeekeeperHiveRows.Wax)),
            r => Assert.Null(r.SecondsToFull));
    }

    [Fact]
    public void TheWaxRow_ShowsItsCap_AndTheWaxFullLineComesAtTheCap()
    {
        var vm = Make(new BeekeeperState { HoneyRevealed = true, WaxRevealed = true, Wax = 12.9m });
        var wax = Row(vm, BeekeeperHiveRows.Wax);
        Assert.Equal(12m, wax.Value);           // rounded down, fractions kept behind the scenes
        Assert.Equal(20m, wax.Value2);
        Assert.NotEqual(0m, wax.SecondsToFull);
        Assert.Equal("12 / 20", vm.WaxDisplay);

        vm.DebugFillWax();
        Assert.Equal(0m, Row(vm, BeekeeperHiveRows.Wax).SecondsToFull);   // capped: the view colors the number
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

    // Cut in stage 8 (spec 017): Honey Supers cost wood (see BeekeeperStage8ViewModelTests).
    // [Fact]
    // public void CapacityRows_BuyAgainAndAgain_AndShowTheNextPriceAndLevel()
    // {
    //     var vm = Make(new BeekeeperState { ShopRevealed = true, CombsRevealed = true, Beebits = 500m });
    //     Assert.True(vm.CapacityUpgradesShown);
    //     Assert.Equal(75m, vm.HoneySuperCost);
    //     vm.BuyHoneySuperCommand.Execute(null);
    //     Assert.Equal(1, vm.HoneySupers);
    //     Assert.Equal(112m, vm.HoneySuperCost);
    //     Assert.Equal(1200m, vm.HoneyStorage);
    //     vm.BuyWaxTrayCommand.Execute(null);
    //     Assert.Equal(1, vm.WaxTrays);
    //     Assert.Equal(30m, vm.WaxStorage);
    //     Assert.Equal(145m, vm.WaxTrayCost);
    //     Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.HoneySuperBought);
    //     Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.WaxTrayBought);
    // }

    [Fact]
    public void TheCombRow_ShowsBothPrices_AndWhatAOneCombGives()
    {
        var vm = Make();
        Assert.Equal(250m, vm.CombBeeCost);
        Assert.Equal(5m, vm.CombCost);
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
