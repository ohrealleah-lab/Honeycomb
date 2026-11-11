using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Bee Herbs (Bee, 2026-11-10): bought in the Shop, lit one at a time, each rolls one buff
/// (Busy Bees, Wax Makers, Good Deals, Wanderers, Lingering Smoke, or a rare dud) that burns in
/// live play only.</summary>
public class BeekeeperHerbTests
{
    /// <summary>Next() always returns <see cref="Roll"/> (clamped), so a test picks the buff.</summary>
    private sealed class FixedRoll : IRandomSource
    {
        public int Roll { get; set; }
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => System.Math.Min(Roll, maxExclusive - 1);
    }

    // Default weights: Busy Bees 0-3, Wax 4-7, Trades 8-11, Wanderers 12-15, Lingering Smoke 16-19, Dud 20.
    private static int RollFor(string buff) => buff switch
    {
        BeekeeperHerbs.BusyBees => 0,
        BeekeeperHerbs.Wax => 4,
        BeekeeperHerbs.Trades => 8,
        BeekeeperHerbs.Wanderers => 12,
        BeekeeperHerbs.LingeringSmoke => 16,
        _ => 20,
    };

    private static BeekeeperEngine Make(int roll = 0, decimal herbs = 1m, decimal bees = 100m)
    {
        var state = new BeekeeperState
        {
            BearName = "Bruno",
            ShopRevealed = true,
            HoneyRevealed = true,
            Bees = bees,
            Beebits = 100m,
            BeeHerbs = herbs,
        };
        return new BeekeeperEngine(BeekeeperConfig.Default, state, new FixedRoll { Roll = roll });
    }

    private static BeekeeperEngine Lit(string buff, decimal bees = 100m)
    {
        var e = Make(RollFor(buff), bees: bees);
        Assert.True(e.LightBeeHerb().Done);
        return e;
    }

    [Fact]
    public void Buying_NeedsTheShopAndBeebits_AndAddsOneHerb()
    {
        var e = Make(herbs: 0m);
        Assert.True(e.BuyBeeHerb().Done);
        Assert.Equal(1m, e.State.BeeHerbs);
        Assert.Equal(100m - e.Config.BeeHerbCost, e.State.Beebits);

        e.State.Beebits = e.Config.BeeHerbCost - 1m;
        Assert.False(e.CanBuyBeeHerb);

        e.State.Beebits = 1000m;
        e.State.ShopRevealed = false;
        Assert.False(e.CanBuyBeeHerb);
    }

    [Theory]
    [InlineData(BeekeeperHerbs.BusyBees)]
    [InlineData(BeekeeperHerbs.Wax)]
    [InlineData(BeekeeperHerbs.Trades)]
    [InlineData(BeekeeperHerbs.Wanderers)]
    [InlineData(BeekeeperHerbs.LingeringSmoke)]
    public void Lighting_RollsOneBuff_ThatBurnsFiveMinutes(string buff)
    {
        var e = Make(RollFor(buff));
        var r = e.LightBeeHerb();
        Assert.True(r.Done);
        Assert.Equal(0m, e.State.BeeHerbs);
        Assert.Equal(buff, e.State.HerbBuff);
        Assert.Equal(e.Config.BeeHerbBurnSeconds, e.State.HerbSecondsLeft);
        Assert.True(e.IsHerb(buff));
        var lit = Assert.Single(r.Events);
        Assert.Equal(BeekeeperEvents.HerbLit, lit.Key);
        Assert.Equal(buff, lit.Text);
    }

    [Fact]
    public void ADud_UsesTheHerb_AndNothingBurns()
    {
        var e = Make(RollFor(BeekeeperHerbs.Dud));
        var r = e.LightBeeHerb();
        Assert.True(r.Done);
        Assert.Equal(0m, e.State.BeeHerbs);
        Assert.False(e.IsHerbBurning);
        Assert.Equal(BeekeeperHerbs.Dud, r.Events.Single().Text);
    }

    [Fact]
    public void OneHerbAtATime_AndItBurnsOutAfterItsTime()
    {
        var e = Make(RollFor(BeekeeperHerbs.BusyBees), herbs: 2m);
        Assert.True(e.LightBeeHerb().Done);
        Assert.False(e.CanLightBeeHerb);

        var mid = e.Advance(e.Config.BeeHerbBurnSeconds - 1m);
        Assert.DoesNotContain(mid.Events, x => x.Key == BeekeeperEvents.HerbOut);
        var end = e.Advance(2m);
        var outEvent = Assert.Single(end.Events, x => x.Key == BeekeeperEvents.HerbOut);
        Assert.Equal(BeekeeperHerbs.BusyBees, outEvent.Text);
        Assert.False(e.IsHerbBurning);
        Assert.Null(e.State.HerbBuff);
        Assert.True(e.CanLightBeeHerb);
    }

    [Fact]
    public void TimeAway_DoesNotBurnTheHerb()
    {
        var e = Lit(BeekeeperHerbs.BusyBees);
        e.AdvanceAway(3600m);
        Assert.Equal(e.Config.BeeHerbBurnSeconds, e.State.HerbSecondsLeft);
    }

    [Fact]
    public void BusyBees_RaisesTheHoneyRate()
    {
        var plain = Make();
        var e = Lit(BeekeeperHerbs.BusyBees);
        Assert.Equal(plain.HoneyPerSecondNow * e.Config.HerbHoneyMultiplier, e.HoneyPerSecondNow);

        e.Advance(10m);
        plain.Advance(10m);
        Assert.Equal(plain.State.Honey * e.Config.HerbHoneyMultiplier, e.State.Honey);
    }

    [Fact]
    public void WaxMakers_RaisesTheWaxRate_LiveOnly()
    {
        var plain = Make();
        var e = Lit(BeekeeperHerbs.Wax);
        Assert.Equal(plain.WaxPerSecondNow * e.Config.HerbWaxMultiplier, e.WaxPerSecondNow);

        e.Advance(10m);
        plain.Advance(10m);
        Assert.Equal(plain.State.Wax * e.Config.HerbWaxMultiplier, e.State.Wax);
    }

    [Fact]
    public void GoodDeals_PaysMoreForEachTrade_InWholeAmounts()
    {
        var e = Lit(BeekeeperHerbs.Trades);
        Assert.Equal(8m, e.BeebitsPerTradeNow);    // 5 × 1.5 = 7.5, rounded up
        Assert.Equal(2m, e.SagePerTradeNow);       // 1 × 1.5 = 1.5, rounded up

        e.State.Honey = 10m;
        decimal before = e.State.Beebits;
        Assert.True(e.SellTen().Done);
        Assert.Equal(before + 8m, e.State.Beebits);

        e.State.HippiesRevealed = true;
        e.State.BeeswaxCandles = 20m;
        Assert.True(e.TradeAllCandles().Done);
        Assert.Equal(4m, e.State.Sage);            // two trades, 2 sage each
        Assert.Equal(2, e.State.HippieTrades);
    }

    [Fact]
    public void Wanderers_BringStrayBeesWhileItBurns()
    {
        var e = Lit(BeekeeperHerbs.Wanderers);
        e.Advance(60m);
        Assert.Equal(100m + e.Config.HerbWanderersBeesPerMinute, e.State.Bees);

        e.Advance(e.Config.BeeHerbBurnSeconds);    // burns out part-way; no more strays after
        decimal after = e.State.Bees;
        e.Advance(60m);
        Assert.Equal(after, e.State.Bees);
        Assert.Equal(100m + e.Config.HerbWanderersBeesPerMinute * e.Config.BeeHerbBurnSeconds / 60m, after);
    }

    [Fact]
    public void LingeringSmoke_MakesASmokerClickLastLonger()
    {
        var e = Lit(BeekeeperHerbs.LingeringSmoke);
        e.State.Upgrades.Add(BeekeeperUpgrades.Smoker);
        Assert.True(e.UseSmoker().Done);
        Assert.Equal(e.Config.HerbSmokerSeconds, e.State.SmokerBoostSecondsLeft);

        var plain = Make();
        plain.State.Upgrades.Add(BeekeeperUpgrades.Smoker);
        plain.UseSmoker();
        Assert.Equal(plain.Config.SmokerBoostSeconds, plain.State.SmokerBoostSecondsLeft);
    }

    [Fact]
    public void ALoadedFile_DropsAnUnknownBuff_AndKeepsAKnownOne()
    {
        var odd = new BeekeeperState { HerbBuff = "glitter", HerbSecondsLeft = 100m };
        var e = new BeekeeperEngine(BeekeeperConfig.Default, odd);
        Assert.Null(e.State.HerbBuff);
        Assert.Equal(0m, e.State.HerbSecondsLeft);

        var good = new BeekeeperState { HerbBuff = BeekeeperHerbs.LingeringSmoke, HerbSecondsLeft = 100m, SmokerBoostSecondsLeft = 25m };
        var g = new BeekeeperEngine(BeekeeperConfig.Default, good);
        Assert.True(g.IsHerb(BeekeeperHerbs.LingeringSmoke));
        Assert.Equal(25m, g.State.SmokerBoostSecondsLeft);   // a lingering smoker click survives a reload

        var wax = new BeekeeperState { HerbBuff = BeekeeperHerbs.Wax, HerbSecondsLeft = 100m, SmokerBoostSecondsLeft = 25m };
        Assert.Equal(1m, new BeekeeperEngine(BeekeeperConfig.Default, wax).State.SmokerBoostSecondsLeft);
    }
}
