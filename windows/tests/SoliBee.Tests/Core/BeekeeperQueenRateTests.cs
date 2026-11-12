using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Bee, 2026-11-12: the queen settles with the first bee bread (no wooden hive needed) and
/// raises 1 bee a second while the pantry has bread, so the free bees visibly climb. A loaf of
/// 100 bees lasts 100 seconds.</summary>
public class BeekeeperQueenRateTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperEngine Make(BeekeeperState state) =>
        new(BeekeeperTestHives.NoBlooms(), state, new NoRandom());

    private static BeekeeperState Skep() => new()
    {
        HoneyRevealed = true, PollenRevealed = true, Pollen = 10m, Honey = 10m, Bees = 0m,
    };

    [Fact]
    public void TheFirstBeeBread_SettlesTheQueen_InTheSkep()
    {
        var e = Make(Skep());
        Assert.False(e.HasQueen);
        var r = e.MakeBeeBread();
        Assert.True(r.Done);
        Assert.False(e.State.HasWoodenHive);
        Assert.True(e.HasQueen);
        Assert.True(e.IsQueenLaying);
        Assert.Contains(r.Events, x => x.Key == BeekeeperEvents.QueenSettles);
    }

    [Fact]
    public void TheQueen_RaisesOneBeeASecond_AndALoafLastsOneHundredSeconds()
    {
        var e = Make(Skep());
        e.MakeBeeBread();
        Assert.Equal(60m, e.QueenRatePerMinute);
        Assert.Equal(1m, e.QueenBeesPerSecondNow);
        Assert.Equal(100m, e.PantrySecondsLeft);

        e.Advance(1m);
        Assert.Equal(1m, e.State.Bees);
        e.Advance(1m);
        Assert.Equal(2m, e.State.Bees);

        for (int i = 0; i < 97; i++)
            Assert.DoesNotContain(e.Advance(1m).Events, x => x.Key == BeekeeperEvents.PantryEmpty);
        Assert.Contains(e.Advance(1m).Events, x => x.Key == BeekeeperEvents.PantryEmpty);
        Assert.Equal(100m, e.State.Bees);
        Assert.False(e.IsQueenLaying);
    }

    [Fact]
    public void AnOlderSaveWithBeeBreadMade_GetsTheQueenOnLoad()
    {
        var s = Skep();
        s.BeeBreadRevealed = true;
        var e = Make(s);
        Assert.Contains(e.RevealOnLoad(), x => x.Key == BeekeeperEvents.QueenSettles);
        Assert.True(e.HasQueen);
    }
}
