using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Bee, 2026-11-12: the queen comes with the wooden hive (moving in introduces her), so bee
/// bread piles up in the skep for the move. In the wooden hive she raises 1 bee a second while the
/// pantry has bread, so the free bees visibly climb; a loaf of 100 bees lasts 100 seconds.</summary>
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
        HoneyRevealed = true, PollenRevealed = true, Pollen = 1000m, Honey = 1000m, Wax = 1000m, Bees = 0m,
    };

    [Fact]
    public void BeeBread_PilesUpInTheSkep_WithNoQueenToEatIt()
    {
        var e = Make(Skep());
        Assert.True(e.MakeBeeBread(10).Done);
        Assert.False(e.HasQueen);
        Assert.Equal(0m, e.QueenRatePerMinute);
        e.Advance(60m);
        Assert.Equal(10m, e.State.BeeBread);
        Assert.Equal(0m, e.State.Bees);
        Assert.True(e.CanMoveToWoodenHive);
    }

    [Fact]
    public void MovingIntoTheWoodenHive_SettlesTheQueen()
    {
        var e = Make(Skep());
        e.MakeBeeBread(11);
        var r = e.MoveToWoodenHive();
        Assert.True(r.Done);
        Assert.True(e.HasQueen);
        Assert.True(e.IsQueenLaying);
        Assert.Contains(r.Events, x => x.Key == BeekeeperEvents.QueenSettles);
    }

    [Fact]
    public void TheQueen_RaisesOneBeeASecond_AndALoafLastsOneHundredSeconds()
    {
        var e = Make(Skep());
        e.MakeBeeBread(11);
        e.MoveToWoodenHive();   // 10 of the 11 go into the move: 1 loaf left
        Assert.Equal(1m, e.State.BeeBread);
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
}
