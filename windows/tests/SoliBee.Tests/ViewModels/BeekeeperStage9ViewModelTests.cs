using System;
using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 9 (spec 018) on the screen's side: the Garden card's bloom line and hover, the
/// growth hovers that name the bloom and winter, the log lines, the welcome-back line and debug.</summary>
public class BeekeeperStage9ViewModelTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static readonly DateTime T0 = new(2026, 11, 11, 12, 0, 0, DateTimeKind.Utc);
    private const decimal Day = 24m * 3600m;

    private static BeekeeperViewModel Make(BeekeeperState? state = null) =>
        new(isHeadless: true, persist: false, rng: new NoRandom(), clock: () => T0, initialState: state);

    private static BeekeeperHiveRow Row(BeekeeperViewModel vm, string id) =>
        vm.HiveGroups.SelectMany(g => g.Rows).First(r => r.Id == id);

    private static BeekeeperState Garden(params string[] plants)
    {
        var s = new BeekeeperState { HoneyRevealed = true, Combs = 5, BearName = "Bruno", GardenRevealed = true };
        s.Plants.AddRange(plants);
        return s;
    }

    private static BeekeeperState EveryKind()
    {
        var s = Garden(BeekeeperPlants.Wildflowers, BeekeeperPlants.Clover, BeekeeperPlants.Bramble,
            BeekeeperPlants.Willow, BeekeeperPlants.Poplar);
        s.HasWoodenHive = true;
        s.QueenSettled = true;
        s.BeeBread = 50m;
        s.BeeBreadRevealed = true;
        return s;
    }

    private static IEnumerable<BeekeeperBoost> Blooms(BeekeeperHiveRow r) => (r.Boosts ?? Array.Empty<BeekeeperBoost>()).Where(b => b.Id == "bloom");

    [Fact]
    public void BeforeTheFirstPlant_NothingMentionsBlooms()
    {
        var vm = Make(new BeekeeperState { HoneyRevealed = true, Combs = 5, BearName = "Bruno" });
        Assert.False(vm.BloomShown);
        Assert.Null(vm.Bloom);
        Assert.DoesNotContain(vm.HiveGroups.SelectMany(g => g.Rows).SelectMany(r => r.Boosts ?? Array.Empty<BeekeeperBoost>()),
            b => b.Id is "bloom" or "winter");
        Assert.DoesNotContain(vm.Log, l => l.Key is BeekeeperEvents.CalendarStarted or BeekeeperEvents.BloomChanged);
    }

    [Fact]
    public void TheFirstPlant_StartsTheCalendar_WithALogLine_AndTheGardenLine()
    {
        var s = new BeekeeperState { HoneyRevealed = true, Combs = 5, BearName = "Bruno", GardenRevealed = true };
        s.SeedsInHand.Add(BeekeeperPlants.Wildflowers);
        var vm = Make(s);
        vm.PlantSeedCommand.Execute(BeekeeperPlants.Wildflowers);
        Assert.Contains(vm.Log, l => l.Key == BeekeeperEvents.CalendarStarted);
        var b = vm.Bloom!;
        Assert.Equal(BeekeeperBlooms.Crocus, b.Bloom);
        Assert.Equal(Day, b.SecondsLeft);
        Assert.Equal(BeekeeperSpecialties.Nursing, b.Favours);
        Assert.False(b.HasFavoured);   // no willow yet
        Assert.Equal(BeekeeperBlooms.Clover, b.Next);
    }

    [Fact]
    public void AnOlderSaveWithPlants_LogsTheCalendarStartingOnLoad()
    {
        var vm = Make(Garden(BeekeeperPlants.Bramble));
        Assert.Equal(BeekeeperEvents.CalendarStarted, vm.Log.First().Key);
        Assert.Equal(BeekeeperBlooms.Crocus, vm.Bloom!.Bloom);
    }

    [Fact]
    public void TheBloomView_SaysWhatItFavours_WhetherTheHiveHasIt_AndWhatIsNext()
    {
        var vm = Make(EveryKind());
        Assert.True(vm.Bloom!.HasFavoured);   // crocus, and a willow
        vm.DebugNextBloom(); vm.DebugNextBloom();
        var linden = vm.Bloom!;
        Assert.Equal(BeekeeperBlooms.Linden, linden.Bloom);
        Assert.Equal(50m, linden.GuardingPercent);
        Assert.Equal(BeekeeperBlooms.Goldenrod, linden.Next);
        vm.DebugNextBloom(); vm.DebugNextBloom();
        var winter = vm.Bloom!;
        Assert.Null(winter.Favours);
        Assert.False(winter.HasFavoured);
        Assert.Equal(25m, winter.WinterPercent);
        Assert.Equal(Day / 2m, winter.SecondsLeft);
        Assert.Equal(BeekeeperBlooms.Crocus, winter.Next);
    }

    [Fact]
    public void TheGrowthHovers_NameTheBloom_WhereItChangesTheNumber()
    {
        var vm = Make(EveryKind());

        // Crocus: the bees' hover names it (x2) beside nursing's own +50%. Review fix (2026-11-15): the nursing
        // line no longer has the crocus folded in as well (it read +100% and x2), and the queen's source is her
        // rate before nursing.
        var bees = Row(vm, BeekeeperHiveRows.Honeybees);
        Assert.Contains(bees.Boosts!, b => b.Id == "nursing" && b.Percent == 50m);
        var queen = Assert.Single(bees.Sources!, s => s.Id == "queen");
        Assert.Equal(bees.Rate!.Value, queen.PerSecond * 2m);   // her base, then x(1 + 50% x 2)
        var crocus = Assert.Single(Blooms(bees));
        Assert.Equal(BeekeeperBlooms.Crocus, crocus.Plant);
        Assert.Equal(BeekeeperSpecialties.Nursing, crocus.Specialty);
        Assert.Equal(2m, crocus.Count);
        Assert.Empty(Blooms(Row(vm, BeekeeperHiveRows.Honey)));
        Assert.Empty(Blooms(Row(vm, BeekeeperHiveRows.Pollen)));

        vm.DebugNextBloom();   // clover: the pollen hover names it, and pollen is 12 a minute
        var pollen = Row(vm, BeekeeperHiveRows.Pollen);
        Assert.Equal(BeekeeperBlooms.Clover, Assert.Single(Blooms(pollen)).Plant);
        Assert.Equal(12m / 60m, pollen.Rate);
        Assert.Equal(6m / 60m, Assert.Single(pollen.Sources!).PerSecond);   // foraging before the clover's x2
        Assert.Empty(Blooms(Row(vm, BeekeeperHiveRows.Honeybees)));

        vm.DebugNextBloom();   // linden: the honey hover says guarding +50% and names the linden
        var honey = Row(vm, BeekeeperHiveRows.Honey);
        Assert.Contains(honey.Boosts!, b => b.Id == "guarding" && b.Percent == 25m);   // the linden's x2 is its own line
        Assert.Equal(BeekeeperBlooms.Linden, Assert.Single(Blooms(honey)).Plant);

        vm.DebugNextBloom();   // goldenrod: the propolis hover names it
        Assert.Equal(BeekeeperBlooms.Goldenrod, Assert.Single(Blooms(Row(vm, BeekeeperHiveRows.Propolis))).Plant);
        Assert.Empty(Blooms(Row(vm, BeekeeperHiveRows.Honey)));
    }

    [Fact]
    public void InWinter_TheHoneyHoverListsWinter()
    {
        var vm = Make(EveryKind());
        for (int i = 0; i < 4; i++) vm.DebugNextBloom();
        var honey = Row(vm, BeekeeperHiveRows.Honey);
        var winter = Assert.Single(honey.Boosts!, b => b.Id == "winter");
        Assert.Equal(0.75m, winter.Count);
        Assert.Equal(-25m, winter.Percent);
        Assert.DoesNotContain(Row(vm, BeekeeperHiveRows.Wax).Boosts ?? Array.Empty<BeekeeperBoost>(), b => b.Id == "winter");
    }

    [Fact]
    public void ABloomWithoutItsSpecialty_AddsNoHoverLine()
    {
        var vm = Make(Garden(BeekeeperPlants.Wildflowers));
        vm.DebugNextBloom(); vm.DebugNextBloom();   // linden, no bramble
        Assert.Empty(Blooms(Row(vm, BeekeeperHiveRows.Honey)));
        Assert.False(vm.Bloom!.HasFavoured);
    }

    [Fact]
    public void ALiveBloomChange_IsALogLine()
    {
        var vm = Make(Garden(BeekeeperPlants.Wildflowers));
        vm.DebugSkip(Day);
        var line = vm.Log.First(l => l.Key == BeekeeperEvents.BloomChanged);
        Assert.Equal(BeekeeperBlooms.Clover, line.Text);
        vm.DebugNextBloom();
        Assert.Equal(BeekeeperBlooms.Linden, vm.Log.First().Text);
    }

    [Fact]
    public void TimeAway_GathersTheBloomChanges_IntoOneWelcomeBackLine()
    {
        var vm = Make(Garden(BeekeeperPlants.Wildflowers));
        vm.DebugSpendAway(3m * Day);
        var line = Assert.Single(vm.Log, l => l.Key == BeekeeperEvents.WelcomeBackBlooms);
        Assert.Equal("clover|linden|goldenrod", line.Text);
        Assert.DoesNotContain(vm.Log, l => l.Key == BeekeeperEvents.BloomChanged);
        Assert.Equal(BeekeeperBlooms.Goldenrod, vm.Bloom!.Bloom);
    }

    [Fact]
    public void DebugStartCalendar_StartsItForASaveWithNoPlant()
    {
        var vm = Make(new BeekeeperState { HoneyRevealed = true, Combs = 5, BearName = "Bruno" });
        vm.DebugStartCalendar();
        Assert.True(vm.BloomShown);
        Assert.Equal(BeekeeperEvents.CalendarStarted, vm.Log.First().Key);
        vm.DebugStartCalendar();
        Assert.Single(vm.Log, l => l.Key == BeekeeperEvents.CalendarStarted);
    }
}
