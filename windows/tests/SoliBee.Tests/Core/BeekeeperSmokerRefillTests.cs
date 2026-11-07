using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Catch Bee keeps the Smoker's calm topped up while the bees are calm.</summary>
public class BeekeeperSmokerRefillTests
{
    private sealed class NoSting : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperEngine Make(decimal calmLeft)
    {
        var state = new BeekeeperState { ToolLevel = 3, CalmSecondsLeft = calmLeft };
        state.Upgrades.Add(BeekeeperUpgrades.Smoker);
        return new BeekeeperEngine(BeekeeperConfig.Default, state, new NoSting());
    }

    [Fact]
    public void AClickWhileCalm_RefillsTheCalmTimeToFull()
    {
        var e = Make(calmLeft: 20m);
        e.Catch();
        Assert.Equal(BeekeeperConfig.Default.CalmSeconds, e.State.CalmSecondsLeft);
    }

    [Fact]
    public void AClickWhenNotCalm_DoesNotStartCalm_ButStillFillsTheMeter()
    {
        var e = Make(calmLeft: 0m);
        e.Catch();
        Assert.False(e.IsCalm);
        Assert.Equal(1, e.State.CalmMeter);
    }

    [Fact]
    public void ASofterRefill_AddsOnlyThatMuch_AndNeverPastFull()
    {
        var config = new BeekeeperConfig { CalmCatchRefillSeconds = 5m };
        var state = new BeekeeperState { ToolLevel = 3, CalmSecondsLeft = 20m };
        var e = new BeekeeperEngine(config, state, new NoSting());
        e.Catch();
        Assert.Equal(25m, e.State.CalmSecondsLeft);

        e.State.CalmSecondsLeft = config.CalmSeconds - 1m;
        e.Catch();
        Assert.Equal(config.CalmSeconds, e.State.CalmSecondsLeft);
    }
}
