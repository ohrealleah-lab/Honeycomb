using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>A long gap with the app open (<see cref="BeekeeperEngine.AdvanceGap"/>) must tell the same
/// story as live play, with no view-model rewriting, and time away keeps its welcome-back summary.</summary>
public class BeekeeperGapTests
{
    private sealed class FakeRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static readonly BeekeeperConfig BigCombs = new() { StartingStorage = 100_000_000m };

    private static BeekeeperState Hive() => new()
    {
        Bees = 1000m, HoneyRevealed = true, HasWoodenHive = true, QueenSettled = true, BearName = "B",
        BeeBread = 5m, BeeBreadRevealed = true, WorkbenchRevealed = true,
        Plants = { BeekeeperPlants.Poplar }, SagePropolisSecondsLeft = 100m,
    };

    private static BeekeeperEngine Make() => new(BigCombs, Hive(), new FakeRandom());

    private static string[] Keys(System.Collections.Generic.IEnumerable<BeekeeperEvent> events) =>
        events.Select(e => e.Key).ToArray();

    [Fact]
    public void AGap_TellsTheSameEventsAsLivePlay_InTheSameOrder()
    {
        var live = Make().Advance(5000m);
        var gap = Make().AdvanceGap(5000m);
        Assert.Contains(BeekeeperEvents.PantryEmpty, Keys(gap.Events));
        Assert.Contains(BeekeeperEvents.SagePropolisOut, Keys(gap.Events));
        Assert.Equal(Keys(live.Events), Keys(gap.Events));
        Assert.Empty(gap.WelcomeBack);
    }

    [Fact]
    public void AGap_LeavesTheSameHive_AsTimeAway()
    {
        var a = Make();
        var b = Make();
        a.AdvanceGap(5000m);
        b.AdvanceAway(5000m);
        Assert.Equal(a.State.Honey, b.State.Honey);
        Assert.Equal(a.State.Bees, b.State.Bees);
        Assert.Equal(a.State.Propolis, b.State.Propolis);
        Assert.Equal(a.State.SagePropolisSecondsLeft, b.State.SagePropolisSecondsLeft);
    }

    [Fact]
    public void TimeAway_SwapsThoseTwoLinesForTheSummary()
    {
        var away = Make().AdvanceAway(5000m);
        Assert.DoesNotContain(BeekeeperEvents.PantryEmpty, Keys(away.Events));
        Assert.DoesNotContain(BeekeeperEvents.SagePropolisOut, Keys(away.Events));
        var welcome = Keys(away.WelcomeBack);
        Assert.Equal(BeekeeperEvents.WelcomeBack, welcome[0]);                  // the honey line leads
        Assert.Equal(BeekeeperEvents.WelcomeBackSageOut, welcome[^1]);          // the candle is the last line
        Assert.True(System.Array.IndexOf(welcome, BeekeeperEvents.WelcomeBackPantry)
                    < System.Array.IndexOf(welcome, BeekeeperEvents.WelcomeBackSageOut));
    }

    [Fact]
    public void TheViewModel_LogsAnOpenAppGap_WithoutRewriting()
    {
        var t = new System.DateTime(2026, 11, 8, 12, 0, 0, System.DateTimeKind.Utc);
        var now = t;
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: Hive(), config: BigCombs,
            rng: new FakeRandom(), clock: () => now);
        now = t.AddSeconds(5000);
        vm.Tick();
        var logged = vm.Log.Select(e => e.Key).ToList();
        Assert.Contains(BeekeeperEvents.PantryEmpty, logged);
        Assert.Contains(BeekeeperEvents.SagePropolisOut, logged);
        Assert.DoesNotContain(logged, k => BeekeeperEvents.IsWelcomeBack(k));
    }

    [Fact]
    public void TheViewModel_ShowsTheWelcomeBackTopLineFirst_AfterTimeAway()
    {
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: Hive(), config: BigCombs,
            rng: new FakeRandom());
        vm.DebugSpendAway(5000m);
        var keys = vm.Log.Select(e => e.Key).ToList();   // newest first
        Assert.Equal(BeekeeperEvents.WelcomeBack, keys[0]);
        Assert.True(keys.IndexOf(BeekeeperEvents.WelcomeBack) < keys.IndexOf(BeekeeperEvents.WelcomeBackPantry));
        Assert.True(keys.IndexOf(BeekeeperEvents.WelcomeBackPantry) < keys.IndexOf(BeekeeperEvents.WelcomeBackSageOut));
    }
}
