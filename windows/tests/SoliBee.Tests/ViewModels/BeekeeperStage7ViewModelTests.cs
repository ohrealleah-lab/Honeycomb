using System;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 7 on the screen's side (spec 015): beds and seeds, the Notebook, the candles and the Hive rows.</summary>
public class BeekeeperStage7ViewModelTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperViewModel Make(BeekeeperState state)
    {
        var now = new DateTime(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc);
        return new(isHeadless: true, rng: new NoRandom(), clock: () => now, persist: false, initialState: state);
    }

    private static BeekeeperHiveRow Row(BeekeeperViewModel vm, string id) =>
        vm.HiveGroups.SelectMany(g => g.Rows).First(r => r.Id == id);

    [Fact]
    public void ChoosingASeed_PlantsThatOne_AndTheBedsListWhatGrows()
    {
        var vm = Make(new BeekeeperState { SeedsInHand = { "wildflowers", "willow" }, GardenRevealed = true, BearName = "Bruno" });
        Assert.Equal(1, vm.BedCount);
        vm.PlantSeedCommand.Execute(BeekeeperPlants.Willow);
        var bed = Assert.Single(vm.GrowingBeds);
        Assert.Equal(BeekeeperPlants.Willow, bed.Plant.Id);
        Assert.Equal(3600m, bed.SecondsLeft);
        Assert.Equal(0, vm.FreeBeds);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.SeedPlanted && e.Text == BeekeeperPlants.Willow);

        vm.PlantSeedCommand.Execute(BeekeeperPlants.Wildflowers);
        Assert.False(vm.CanPlantSeed);
        Assert.False(vm.CanPlantSeedOf(BeekeeperPlants.Wildflowers));
    }

    [Fact]
    public void TheNotebook_AppearsWhenBought_WithANotePerThingTheHiveHas()
    {
        var vm = Make(new BeekeeperState
        {
            Paper = 20m, PaperRevealed = true, Beebits = 500m, BearName = "Bruno",
            HasWoodenHive = true, QueenSettled = true,
            Plants = { BeekeeperPlants.Willow, BeekeeperPlants.Poplar },
        });
        Assert.False(vm.HasNotebook);
        vm.BuyUpgrade(BeekeeperUpgrades.Notebook);
        Assert.True(vm.HasNotebook);
        Assert.Equal(new[] { BeekeeperNotes.Queen, BeekeeperSpecialties.Nursing, BeekeeperSpecialties.Resin }, vm.NotebookNotes.ToArray());
    }

    [Fact]
    public void HiveRows_ShowNursingResinPropolisAndBurningCandles()
    {
        var vm = Make(new BeekeeperState
        {
            Bees = 10m, HoneyRevealed = true, BearName = "Bruno",
            Plants = { BeekeeperPlants.Willow, BeekeeperPlants.Poplar },
            Propolis = 4.7m, BeeBoostCandles = 1m, SagePropolisSecondsLeft = 7200m,
        });
        Assert.Equal(50m, Row(vm, BeekeeperHiveRows.Nursing).Value);
        Assert.True(Row(vm, BeekeeperHiveRows.Resin).Visible);
        var propolis = Row(vm, BeekeeperHiveRows.Propolis);
        Assert.True(propolis.Visible);
        Assert.Equal(4m, propolis.Value);
        Assert.NotNull(propolis.Rate);
        Assert.True(Row(vm, BeekeeperHiveRows.BeeBoostCandles).Visible);
        Assert.False(Row(vm, BeekeeperHiveRows.BeeBoostBurning).Visible);
        Assert.True(Row(vm, BeekeeperHiveRows.SagePropolisBurning).Visible);
        Assert.Equal(7200m, Row(vm, BeekeeperHiveRows.SagePropolisBurning).Value);
    }

    [Fact]
    public void TheCandleCommands_CraftAndLight_AndTheHoneyRateIncludesTheBoost()
    {
        var vm = Make(new BeekeeperState
        {
            Bees = 100m, HoneyRevealed = true, WorkbenchRevealed = true, BearName = "Bruno",
            Plants = { BeekeeperPlants.Poplar }, Wax = 100m, Propolis = 10m,
        });
        decimal before = vm.HoneyPerSecond;
        Assert.True(vm.PropolisCandlesShown);
        vm.CraftBeeBoostCommand.Execute(null);
        Assert.Equal(1m, vm.BeeBoostCandles);
        vm.LightBeeBoostCommand.Execute(null);
        Assert.Equal(600m, vm.BeeBoostSecondsLeft);
        Assert.Equal(before * 1.2m, vm.HoneyPerSecond);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.BeeBoostLit);
    }

    [Fact]
    public void TheDebugCommands_WorkThroughTheViewModel()
    {
        var vm = Make(new BeekeeperState { BearName = "Bruno" });
        vm.DebugGiveEverySeed();
        Assert.Equal(BeekeeperConfig.Default.Plants.Count, vm.Seeds);
        vm.DebugGivePropolis(50m);
        vm.DebugGivePaper(20m);
        Assert.Equal(50m, vm.Propolis);
        Assert.Equal(20m, vm.Paper);
        vm.DebugHippieTradesTo199();
        Assert.Equal(199, vm.State.HippieTrades);
    }
}
