using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Crafting in batches (x10, x100): exactly N times the cost, or nothing.</summary>
public class BeekeeperBatchCraftTests
{
    // Bee, 2026-11-11: the herbal candle costs 1 wax now. These test the batch rule, so they keep a
    // 10-wax candle, where "ten times the cost" shows.
    private static readonly BeekeeperConfig TenWax = new() { HerbalCandleWax = 10m };
    private static BeekeeperEngine Make(BeekeeperState state) => new(TenWax, state);
    // Before: private static BeekeeperEngine Make(BeekeeperState state) => new(BeekeeperConfig.Default, state);

    // Bee, 2026-11-11: the beeswax candle is gone; these batches use the herbal candle (10 wax + 1 herb).
    private static BeekeeperState Herbal(decimal wax, decimal herbs) =>
        new() { WorkbenchRevealed = true, RepellentUnlocked = true, Wax = wax, Herbs = herbs };

    [Fact]
    public void ABatchOfCandles_TakesTenTimesTheCost_AndGivesTenCandles()
    {
        var e = Make(Herbal(105m, 10m));
        Assert.True(e.CanCraftRepellentTimes(10));
        Assert.False(e.CanCraftRepellentTimes(100));
        var r = e.CraftRepellent(10);
        Assert.True(r.Done);
        Assert.Equal(5m, e.State.Wax);
        Assert.Equal(10m, e.State.RepellentCandles);
        Assert.Equal(10, e.State.CandlesCrafted);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.Crafted && ev.Value == 10m && ev.Text == "repellent");
    }

    [Fact]
    public void ABatchTooBig_IsRefused_AndChangesNothing()
    {
        var e = Make(Herbal(99m, 10m));
        Assert.False(e.CraftRepellent(10).Done);
        Assert.Equal(99m, e.State.Wax);
        Assert.Equal(0m, e.State.RepellentCandles);
    }

    [Fact]
    public void ASingleCraft_StillHasNoBatchLine()
    {
        var e = Make(Herbal(50m, 5m));
        Assert.DoesNotContain(e.CraftRepellent().Events, ev => ev.Key == BeekeeperEvents.Crafted);
    }

    [Fact]
    public void ABatchOfCandles_CountsTowardTheHippies()
    {
        var e = Make(Herbal(100m, 10m));
        var r = e.CraftRepellent(10);
        Assert.True(e.State.HippiesRevealed);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.HippiesArrive);
    }

    [Fact]
    public void RepellentBatches_NeedWaxAndSageForTheWholeBatch()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, RepellentUnlocked = true, Wax = 100m, Herbs = 9m });
        Assert.False(e.CanCraftRepellentTimes(10));      // 9 sage is one short
        e.State.Herbs = 10m;
        Assert.True(e.CanCraftRepellentTimes(10));
        Assert.True(e.CraftRepellent(10).Done);
        Assert.Equal(0m, e.State.Wax);
        Assert.Equal(0m, e.State.Herbs);
        Assert.Equal(10m, e.State.RepellentCandles);
    }

    [Fact]
    public void BeeBreadBatches_NeedPollenAndHoneyForTheWholeBatch()
    {
        var e = Make(new BeekeeperState { PollenRevealed = true, Pollen = 100m, Honey = 9m });   // 10 pollen + 1 honey each (Bee, 2026-11-12)
        Assert.False(e.CanMakeBeeBreadTimes(10));
        e.State.Honey = 10m;
        var r = e.MakeBeeBread(10);
        Assert.True(r.Done);
        Assert.Equal(10m, e.State.BeeBread);
        Assert.Equal(0m, e.State.Pollen);
        Assert.Equal(0m, e.State.Honey);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.Crafted && ev.Text == "bee_bread");
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.BeeBreadMade);
    }
}
