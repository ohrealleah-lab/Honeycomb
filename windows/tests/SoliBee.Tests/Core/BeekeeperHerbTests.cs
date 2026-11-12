using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Herbs and herbal candles (Bee, 2026-11-11): herbs replace sage, the herbal candle
/// (2 wax + 1 herb) is lit for one random buff (Busy Bees, Wax Makers, Good Deals, Wanderers,
/// Lingering Smoke, Quick Fingers, or a rare dud). Stage 10: herbs come only from the bee hotel,
/// the bear pays Beebits and the Hippies no longer take herbal candles.</summary>
public class BeekeeperHerbTests
{
    /// <summary>Next() always returns <see cref="Roll"/> (clamped), so a test picks the buff.</summary>
    private sealed class FixedRoll : IRandomSource
    {
        public int Roll { get; set; }
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => System.Math.Min(Roll, maxExclusive - 1);
    }

    // Default weights: Busy Bees 0-3, Wax 4-7, Trades 8-11, Wanderers 12-15, Lingering Smoke 16-19, Quick Fingers 20-21, Dud 22.
    private static int RollFor(string buff) => buff switch
    {
        BeekeeperHerbs.BusyBees => 0,
        BeekeeperHerbs.Wax => 4,
        BeekeeperHerbs.Trades => 8,
        BeekeeperHerbs.Wanderers => 12,
        BeekeeperHerbs.LingeringSmoke => 16,
        BeekeeperHerbs.QuickFingers => 20,
        _ => 22,
    };

    private static BeekeeperEngine Make(int roll = 0, decimal candles = 1m, decimal bees = 100m, BeekeeperState? state = null)
    {
        state ??= new BeekeeperState
        {
            BearName = "Bruno",
            ShopRevealed = true,
            HoneyRevealed = true,
            WorkbenchRevealed = true,
            Bees = bees,
            RepellentCandles = candles,
        };
        return new BeekeeperEngine(BeekeeperConfig.Default, state, new FixedRoll { Roll = roll });
    }

    private static BeekeeperEngine Lit(string buff, decimal bees = 100m)
    {
        var e = Make(RollFor(buff), bees: bees);
        Assert.True(e.LightRepellent().Done);
        return e;
    }

    // ============================================================ the bear (stage 10: Beebits, never herbs)

    [Fact]
    public void TheBear_PaysBeebitsForTenHoney_AndNeverHerbs_AndTheRecipeStaysClosed()
    {
        var e = Make(candles: 0m);
        e.State.Honey = 25m;
        Assert.False(e.State.RepellentUnlocked);

        var r = e.SellTen();
        Assert.True(r.Done);
        Assert.Equal(15m, e.State.Honey);
        Assert.Equal(0m, e.State.Herbs);
        Assert.Equal(5m, e.State.Beebits);          // stage 10: the bear pays Beebits again
        Assert.False(e.State.HerbsRevealed);
        Assert.False(e.State.RepellentUnlocked);    // the leafcutter bee's first herbs open it now
        Assert.DoesNotContain(r.Events, x => x.Key == BeekeeperEvents.RepellentUnlocked);
        Assert.Equal(5m, r.Events.Single(x => x.Key == BeekeeperEvents.Sale).Value);

        e.SellAll();
        Assert.Equal(10m, e.State.Beebits);
        Assert.Equal(5m, e.State.Honey);
        Assert.Equal(0m, e.State.Herbs);
    }

    [Fact]
    public void UnderTheAgreement_FiveBeebitsCostEightHoney()
    {
        var e = Make();
        e.State.HasTradeAgreement = true;
        Assert.Equal(8m, e.HoneyPerTradeNow);
        Assert.Equal(5m, e.BeebitsPerTradeNow);
    }

    [Fact]
    public void AnOlderSave_GetsItsSageAsHerbs()
    {
        var old = new BeekeeperState { Sage = 7m, SageRevealed = true };
        var e = new BeekeeperEngine(BeekeeperConfig.Default, old);
        Assert.Equal(7m, e.State.Herbs);
        Assert.Equal(0m, e.State.Sage);
        Assert.True(e.State.HerbsRevealed);
        Assert.True(e.State.RepellentUnlocked);
    }

    // ============================================================ the herbal candle

    [Fact]
    public void AnHerbalCandle_CostsTwoWaxAndOneHerb()   // Bee, 2026-11-11: was 10 wax
    {
        var e = Make(candles: 0m);
        e.State.RepellentUnlocked = true;
        e.State.Wax = 20m;
        e.State.Herbs = 1m;
        Assert.True(e.CraftRepellent().Done);
        Assert.Equal(18m, e.State.Wax);
        Assert.Equal(0m, e.State.Herbs);
        Assert.Equal(1m, e.State.RepellentCandles);
        Assert.False(e.CanCraftRepellent);           // no herb left
    }

    [Fact]
    public void TheHerbalCandle_NeverRetires_AfterTheEmissary()
    {
        var e = Make();
        e.State.RepellentUnlocked = true;
        e.State.EmissaryCome = true;
        Assert.True(e.RepellentShown);
        Assert.True(e.CanLightRepellent);
    }

    [Fact]
    public void TheHippies_NoLongerTakeHerbalCandles()   // stage 10: beeswax candles for clay jars only
    {
        var e = Make(candles: 3m);
        e.State.ShopRevealed = false;
        e.State.HippiesRevealed = true;

        Assert.False(e.CanTradeCandles);
        Assert.False(e.TradeTenCandles().Done);
        Assert.False(e.TradeAllCandles().Done);
        Assert.Equal(3m, e.State.RepellentCandles);   // they stay on the shelf
        Assert.Equal(0m, e.State.Beebits);
        Assert.Equal(0, e.State.HippieTrades);
        Assert.False(e.State.ShopRevealed);   // Bee, 2026-11-11: the first comb opens the Shop
    }

    [Fact]
    public void Prices_AskForNoHerbs_SoAnUpgradeThatUsedToIsBuyableWithout()   // stage 10 (was: herbs where sage was)
    {
        var e = Make();
        e.State.WorkbenchRevealed = true;
        e.State.HasWaxCatcher = true;
        var u = e.Config.Upgrades.First(x => x.Id == BeekeeperUpgrades.BetterWaxCatcher);
        Assert.Equal(0m, u.Herbs);
        e.State.Beebits = u.Beebits;
        e.State.Wax = u.Wax;
        e.State.Bees = u.Bees;
        e.State.Herbs = 0m;
        Assert.True(e.BuyUpgrade(u.Id).Done);
        Assert.Equal(0m, e.State.Herbs);
    }

    // ============================================================ lighting: one buff each

    [Theory]
    [InlineData(BeekeeperHerbs.BusyBees)]
    [InlineData(BeekeeperHerbs.Wax)]
    [InlineData(BeekeeperHerbs.Trades)]
    [InlineData(BeekeeperHerbs.Wanderers)]
    [InlineData(BeekeeperHerbs.LingeringSmoke)]
    public void Lighting_RollsOneBuff_ThatBurnsFiveMinutes(string buff)
    {
        var e = Make(RollFor(buff));
        var r = e.LightRepellent();
        Assert.True(r.Done);
        Assert.Equal(0m, e.State.RepellentCandles);
        Assert.Equal(buff, e.State.HerbBuff);
        Assert.Equal(e.Config.HerbalCandleBurnSeconds, e.State.HerbSecondsLeft);
        Assert.True(e.IsHerb(buff));
        var lit = Assert.Single(r.Events);
        Assert.Equal(BeekeeperEvents.HerbLit, lit.Key);
        Assert.Equal(buff, lit.Text);
        Assert.Equal(0m, e.State.RepellentSecondsLeft);   // no longer keeps wasps away
    }

    [Fact]
    public void StrongerCandles_MakeItBurnLonger()
    {
        var e = Make(RollFor(BeekeeperHerbs.BusyBees));
        e.State.Upgrades.Add(BeekeeperUpgrades.StrongerCandles);
        e.LightRepellent();
        Assert.Equal(e.Config.HerbalCandleBurnSeconds * e.Config.StrongerCandlesBonus, e.State.HerbSecondsLeft);
    }

    [Fact]
    public void ADud_UsesTheCandle_AndNothingBurns()
    {
        var e = Make(RollFor(BeekeeperHerbs.Dud));
        var r = e.LightRepellent();
        Assert.True(r.Done);
        Assert.Equal(0m, e.State.RepellentCandles);
        Assert.False(e.IsHerbBurning);
        Assert.Equal(BeekeeperHerbs.Dud, r.Events.Single().Text);
    }

    [Fact]
    public void OneAtATime_AndItBurnsOutAfterItsTime()
    {
        var e = Make(RollFor(BeekeeperHerbs.BusyBees), candles: 2m);
        Assert.True(e.LightRepellent().Done);
        Assert.False(e.CanLightRepellent);

        var mid = e.Advance(e.Config.HerbalCandleBurnSeconds - 1m);
        Assert.DoesNotContain(mid.Events, x => x.Key == BeekeeperEvents.HerbOut);
        var end = e.Advance(2m);
        var outEvent = Assert.Single(end.Events, x => x.Key == BeekeeperEvents.HerbOut);
        Assert.Equal(BeekeeperHerbs.BusyBees, outEvent.Text);
        Assert.False(e.IsHerbBurning);
        Assert.Null(e.State.HerbBuff);
        Assert.True(e.CanLightRepellent);
    }

    [Fact]
    public void TimeAway_DoesNotBurnIt()
    {
        var e = Lit(BeekeeperHerbs.BusyBees);
        e.AdvanceAway(3600m);
        Assert.Equal(e.Config.HerbalCandleBurnSeconds, e.State.HerbSecondsLeft);
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
    public void WaxMakers_RaisesTheWaxRate()
    {
        var plain = Make();
        var e = Lit(BeekeeperHerbs.Wax);
        Assert.Equal(plain.WaxPerSecondNow * e.Config.HerbWaxMultiplier, e.WaxPerSecondNow);

        e.Advance(10m);
        plain.Advance(10m);
        Assert.Equal(plain.State.Wax * e.Config.HerbWaxMultiplier, e.State.Wax);
    }

    [Fact]
    public void GoodDeals_PaysTheBearsBeebitsHalfAgain_PlainAndPotted_InWholeAmounts()
    {
        var e = Make(RollFor(BeekeeperHerbs.Trades), candles: 1m);
        Assert.True(e.LightRepellent().Done);
        Assert.Equal(8m, e.BeebitsPerTradeNow);      // 5 × 1.5, rounded up
        Assert.Equal(23m, e.PottedHoneyBeebitsNow);  // 15 × 1.5, rounded up

        e.State.Honey = 10m;
        Assert.True(e.SellTen().Done);
        Assert.Equal(8m, e.State.Beebits);
        Assert.Equal(0m, e.State.Herbs);

        e.State.PottedHoney = 2m;
        Assert.True(e.SellAllPotted().Done);
        Assert.Equal(8m + 46m, e.State.Beebits);     // two pots, 23 each

        // The Hippies' jars are never touched: still 1 jar for 3 candles.
        e.State.HippiesRevealed = true;
        e.State.BeeswaxCandles = 3m;
        decimal jars = e.State.ClayJars;
        Assert.True(e.TradeAllCandles().Done);
        Assert.Equal(jars + 1m, e.State.ClayJars);
    }

    [Fact]
    public void Wanderers_BringStrayBeesWhileItBurns()
    {
        var e = Lit(BeekeeperHerbs.Wanderers);
        e.Advance(60m);
        Assert.Equal(100m + e.Config.HerbWanderersBeesPerMinute, e.State.Bees);

        e.Advance(e.Config.HerbalCandleBurnSeconds);   // burns out part-way; no more strays after
        decimal after = e.State.Bees;
        e.Advance(60m);
        Assert.Equal(after, e.State.Bees);
        Assert.Equal(100m + e.Config.HerbWanderersBeesPerMinute * e.Config.HerbalCandleBurnSeconds / 60m, after);
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

    // ============================================================ Quick Fingers (Bee, 2026-11-11)

    [Fact]
    public void QuickFingers_MakesCatchBeeAndTheSmokerThreeTimesAsStrong()
    {
        var e = Lit(BeekeeperHerbs.QuickFingers);
        e.State.Upgrades.Add(BeekeeperUpgrades.Smoker);
        e.State.ToolLevel = 1;   // better tools never get stung
        decimal perClick = e.BeesPerClick;
        Assert.Equal(perClick * 3m, e.BeesPerCatch);
        decimal before = e.State.Bees;
        Assert.Equal(perClick * 3m, e.Catch().BeesGained);
        Assert.Equal(before + perClick * 3m, e.State.Bees);

        e.UseSmoker();
        Assert.Equal(e.Config.SmokerBoostPercent * 3m, e.SmokerBoostPercentNow);
        Assert.Equal(1m + e.Config.SmokerBoostPercent * 3m / 100m, e.SmokerBoostNow);
        Assert.Equal(e.Config.SmokerBoostPercent, e.SmokerBoostPercent);   // the Shop keeps quoting the base
    }

    [Fact]
    public void QuickFingers_BurnsThirtySeconds_ThenClicksAreNormalAgain()
    {
        var e = Lit(BeekeeperHerbs.QuickFingers);
        e.State.ToolLevel = 1;
        Assert.Equal(30m, e.State.HerbSecondsLeft);
        e.Advance(29m);
        Assert.Equal(e.BeesPerClick * 3m, e.BeesPerCatch);
        e.Advance(1m);
        Assert.False(e.IsHerbBurning);
        Assert.Equal((decimal)e.BeesPerClick, e.BeesPerCatch);
    }

    [Fact]
    public void QuickFingers_StrongerCandlesStretchItsBurn()
    {
        var e = Make(RollFor(BeekeeperHerbs.QuickFingers));
        e.State.Upgrades.Add(BeekeeperUpgrades.StrongerCandles);
        e.LightRepellent();
        Assert.Equal(30m * e.Config.StrongerCandlesBonus, e.State.HerbSecondsLeft);
    }

    [Fact]
    public void QuickFingers_IsRarerThanTheOtherBuffs()
    {
        var w = BeekeeperConfig.Default.HerbBuffWeights.ToDictionary(x => x.Buff, x => x.Weight);
        Assert.Equal(2, w[BeekeeperHerbs.QuickFingers]);
        Assert.True(w[BeekeeperHerbs.QuickFingers] < w[BeekeeperHerbs.BusyBees]);
        Assert.True(w[BeekeeperHerbs.QuickFingers] > w[BeekeeperHerbs.Dud]);
    }

    [Fact]
    public void ALoadedFile_KeepsAQuickFingersCandle()
    {
        var good = new BeekeeperState { HerbBuff = BeekeeperHerbs.QuickFingers, HerbSecondsLeft = 20m };
        var g = new BeekeeperEngine(BeekeeperConfig.Default, good);
        Assert.True(g.IsHerb(BeekeeperHerbs.QuickFingers));
        Assert.Equal(20m, g.State.HerbSecondsLeft);
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
