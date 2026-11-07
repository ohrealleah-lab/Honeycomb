using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Crafting in batches (x10, x100): exactly N times the cost, or nothing.</summary>
public class BeekeeperBatchCraftTests
{
    private static BeekeeperEngine Make(BeekeeperState state) => new(BeekeeperConfig.Default, state);

    [Fact]
    public void ABatchOfCandles_TakesTenTimesTheWax_AndGivesTenCandles()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 105m });
        Assert.True(e.CanCraftBeeswaxTimes(10));
        Assert.False(e.CanCraftBeeswaxTimes(100));
        var r = e.CraftBeeswax(10);
        Assert.True(r.Done);
        Assert.Equal(5m, e.State.Wax);
        Assert.Equal(10m, e.State.BeeswaxCandles);
        Assert.Equal(10, e.State.CandlesCrafted);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.Crafted && ev.Value == 10m && ev.Text == "beeswax");
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.FirstBeeswaxCandle);
    }

    [Fact]
    public void ABatchTooBig_IsRefused_AndChangesNothing()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 99m });
        Assert.False(e.CraftBeeswax(10).Done);
        Assert.Equal(99m, e.State.Wax);
        Assert.Equal(0m, e.State.BeeswaxCandles);
    }

    [Fact]
    public void ASingleCraft_StillHasNoBatchLine()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 50m });
        Assert.DoesNotContain(e.CraftBeeswax().Events, ev => ev.Key == BeekeeperEvents.Crafted);
    }

    [Fact]
    public void ABatchOfCandles_CountsTowardTheHippies()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 100m });
        var r = e.CraftBeeswax(10);
        Assert.True(e.State.HippiesRevealed);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.HippiesArrive);
    }

    [Fact]
    public void RepellentBatches_NeedWaxAndSageForTheWholeBatch()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, RepellentUnlocked = true, Wax = 100m, Sage = 9m });
        Assert.False(e.CanCraftRepellentTimes(10));      // 9 sage is one short
        e.State.Sage = 10m;
        Assert.True(e.CanCraftRepellentTimes(10));
        Assert.True(e.CraftRepellent(10).Done);
        Assert.Equal(0m, e.State.Wax);
        Assert.Equal(0m, e.State.Sage);
        Assert.Equal(10m, e.State.RepellentCandles);
    }

    [Fact]
    public void BeeBreadBatches_NeedPollenAndHoneyForTheWholeBatch()
    {
        var e = Make(new BeekeeperState { PollenRevealed = true, Pollen = 100m, Honey = 99m });
        Assert.False(e.CanMakeBeeBreadTimes(10));
        e.State.Honey = 100m;
        var r = e.MakeBeeBread(10);
        Assert.True(r.Done);
        Assert.Equal(10m, e.State.BeeBread);
        Assert.Equal(0m, e.State.Pollen);
        Assert.Equal(0m, e.State.Honey);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.Crafted && ev.Text == "bee_bread");
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.BeeBreadMade);
    }
}
