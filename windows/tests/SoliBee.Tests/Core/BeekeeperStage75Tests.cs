using System;
using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 7.5 rules (spec 016): combs make the honey, free bees make the wax, bees and wax
/// buy combs, honey and wax caps, capacity upgrades, Technologies on both caps, walls and the
/// bear's better rate.</summary>
public class BeekeeperStage75Tests
{
    private sealed class FakeRandom : IRandomSource
    {
        private readonly Queue<double> _doubles;
        public FakeRandom(params double[] doubles) => _doubles = new Queue<double>(doubles);
        public double NextDouble() => _doubles.Count > 0 ? _doubles.Dequeue() : 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperEngine Make(BeekeeperState? state = null, BeekeeperConfig? config = null, params double[] dice)
        => new(config ?? BeekeeperConfig.Default, state, new FakeRandom(dice));

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    // ============================================================ the starter comb (User Story 1)

    [Fact]
    public void ANewGame_HasOneComb_NoBees_AndMakesNoHoney_ButTheWaxDrips()
    {
        var e = Make();
        Assert.Equal(1, e.State.Combs);
        Assert.Equal(0m, e.State.Bees);
        Assert.False(e.HiveStarted);
        Assert.Equal(0m, e.HoneyPerSecondNow);
        Assert.Equal(0.005m, e.WaxPerSecondNow);
        e.Advance(60m);
        Assert.Equal(0m, e.State.Honey);
        Assert.Equal(0.3m, e.State.Wax);
    }

    [Fact]
    public void TheFirstBee_StartsTheStarterComb_AndAStingStartsNothing()
    {
        var e = Make(dice: new[] { 0.0, 0.99 });   // a sting, then a catch
        Assert.True(e.Catch().Stung);
        Assert.False(e.HiveStarted);
        e.Advance(10m);
        Assert.Equal(0m, e.State.Honey);

        Assert.False(e.Catch().Stung);
        Assert.True(e.HiveStarted);
        e.Advance(10m);
        Assert.Equal(2m, e.State.Honey);           // 1 comb × 0.2 × 10
    }

    [Fact]
    public void WithZeroFreeBees_AStartedHiveStillMakesHoney()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true, Bees = 20m, Wax = 10m });
        Assert.True(e.BuildComb().Done);
        Assert.Equal(0m, e.State.Bees);            // every free bee moved in
        Assert.True(e.HiveStarted);
        e.Advance(10m);
        Assert.Equal(4m, e.State.Honey);           // 2 combs × 0.2 × 10
        Assert.Equal(0.05m, e.State.Wax);          // the drip alone
    }

    // ============================================================ the queen's bees are free bees (User Story 3)

    [Fact]
    public void TheQueensBees_ArriveAsFreeBees_AndRaiseTheWaxRateAsTheyCome()
    {
        var e = Make(new BeekeeperState
        {
            HoneyRevealed = true, HasWoodenHive = true, QueenSettled = true, BeeBread = 10m, BeeBreadRevealed = true,
        });
        Assert.Equal(0.005m, e.WaxPerSecondNow);
        e.Advance(60m);                            // 20 bees raised
        Assert.Equal(20m, e.State.Bees);
        Assert.Equal(0.007m, e.WaxPerSecondNow);   // 0.005 + 20 × 0.0001
        Assert.Equal(1m, e.BeesPerCatch);          // the slice reads free bees: 1 + floor(20 × 0.001)
    }

    [Fact]
    public void TheCatchSlice_ReadsFreeBeesOnly()
    {
        var e = Make(new BeekeeperState { ToolLevel = 3, Bees = 10_000m, Wax = 1000m, HoneyRevealed = true });
        Assert.Equal(20m, e.BeesPerCatch);         // 10 + 10
        e.State.Combs = 20;                        // combs hold bees, but they are not free bees
        Assert.Equal(20m, e.BeesPerCatch);
        e.State.Bees = 0m;
        Assert.Equal(10m, e.BeesPerCatch);
    }

    // ============================================================ boosts touch honey only (User Story 2)

    [Fact]
    public void Calm_Candles_TheWoodenHiveAndGuarding_BoostHoney_AndNotWax()
    {
        var plain = Make(new BeekeeperState { HoneyRevealed = true, Combs = 4, Bees = 500m });
        var boosted = Make(new BeekeeperState
        {
            HoneyRevealed = true, Combs = 4, Bees = 500m,
            CalmSecondsLeft = 100m, BeeBoostSecondsLeft = 100m, SagePropolisSecondsLeft = 100m,
            HasWoodenHive = true, Plants = { BeekeeperPlants.Bramble },
        });
        Assert.Equal(plain.WaxPerSecondNow, boosted.WaxPerSecondNow);
        Assert.True(boosted.HoneyPerSecondNow > plain.HoneyPerSecondNow);
        plain.Advance(50m);
        boosted.Advance(50m);
        Assert.Equal(plain.State.Wax, boosted.State.Wax);
        Assert.Equal(0.8m * 50m * 2m * 1.2m * 1.1m * 1.25m * 1.25m, boosted.State.Honey);
    }

    // ============================================================ caps (User Story 5)

    [Fact]
    public void Caps_AddRoomForCombsBought_SupersAndTrays()
    {
        var e = Make(new BeekeeperState { Combs = 4, HoneySupers = 2, WaxTrays = 3 });
        Assert.Equal(200m + 3m * 300m + 2m * 1000m, e.HoneyStorage);
        Assert.Equal(20m + 3m * 2m + 3m * 8m, e.WaxStorage);
    }

    [Fact]
    public void BothCapsStopProduction_AndNothingIsWastedIntoTheOther()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true, Combs = 1, Honey = 199m, Wax = 19.9m, Bees = 1000m });
        var r = e.Advance(100m);
        Assert.Equal(200m, e.State.Honey);
        Assert.Equal(20m, e.State.Wax);
        Assert.Equal(1m, r.HoneyStored);
        Assert.Equal(0.1m, r.WaxMade);
        Assert.Equal(0m, e.State.Beebits);
        Assert.True(Has(r.Events, BeekeeperEvents.StorageFull));
        Assert.True(Has(r.Events, BeekeeperEvents.WaxFull));
    }

    // ============================================================ capacity upgrades (User Story 6)

    [Fact]
    public void CapacityUpgrades_ShowOnceTheShopAndTheCombsPanelHaveOpened()
    {
        var e = Make(new BeekeeperState { Beebits = 10_000m });
        Assert.False(e.CapacityUpgradesShown);
        Assert.False(e.BuyHoneySuper().Done);
        e.State.ShopRevealed = true;
        Assert.False(e.CapacityUpgradesShown);
        e.State.CombsRevealed = true;
        Assert.True(e.CapacityUpgradesShown);
    }

    [Fact]
    public void HoneySupers_RepeatAtRisingPrices_ForBeebitsOnly()
    {
        var e = Make(new BeekeeperState { ShopRevealed = true, CombsRevealed = true, Beebits = 1000m });
        var prices = new List<decimal>();
        for (int i = 0; i < 4; i++)
        {
            prices.Add(e.HoneySuperCost);
            var r = e.BuyHoneySuper();
            Assert.True(r.Done);
            Assert.Contains(r.Events, x => x.Key == BeekeeperEvents.HoneySuperBought && x.Value == i + 1);
        }
        Assert.Equal(new[] { 75m, 112m, 168m, 253m }, prices);   // +50%, rounded down
        Assert.Equal(4, e.State.HoneySupers);
        Assert.Equal(200m + 4000m, e.HoneyStorage);
        Assert.Equal(1000m - 608m, e.State.Beebits);
        Assert.Equal(0m, e.State.Wax);
    }

    [Fact]
    public void WaxTrays_RepeatAtRisingPrices_AndAddWaxRoom()
    {
        var e = Make(new BeekeeperState { ShopRevealed = true, CombsRevealed = true, Beebits = 1000m });
        var prices = new List<decimal>();
        for (int i = 0; i < 3; i++)
        {
            prices.Add(e.WaxTrayCost);
            Assert.True(e.BuyWaxTray().Done);
        }
        Assert.Equal(new[] { 100m, 160m, 256m }, prices);        // +60%, rounded down
        Assert.Equal(20m + 24m, e.WaxStorage);
        Assert.Equal(409m, e.WaxTrayCost);
        Assert.True(e.CanBuyWaxTray);                            // 484 left
        e.State.Beebits = 408m;
        Assert.False(e.CanBuyWaxTray);
        Assert.False(e.BuyWaxTray().Done);
        Assert.Equal(3, e.State.WaxTrays);
    }

    // ============================================================ Technologies (User Story 7)

    [Fact]
    public void Technologies_GrowBothCaps_AndMultiply()
    {
        var e = Make(new BeekeeperState { Combs = 2 });          // 500 honey, 22 wax
        e.State.Upgrades.Add(BeekeeperUpgrades.BiggerCombs1);
        Assert.Equal(750m, e.HoneyStorage);
        Assert.Equal(33m, e.WaxStorage);
        e.State.Upgrades.Add(BeekeeperUpgrades.PropolisSeal);
        Assert.Equal(937.5m, e.HoneyStorage);
        Assert.Equal(41.25m, e.WaxStorage);
        e.State.Upgrades.Add(BeekeeperUpgrades.BiggerCombs2);    // replaces I
        Assert.Equal(1250m, e.HoneyStorage);
        Assert.Equal(55m, e.WaxStorage);
        Assert.Equal(2.5m * 2m, e.WaxStoragePerComb);
    }

    // ============================================================ walls (User Story 8)

    [Fact]
    public void AWaxPriceAboveTheCap_IsAWall_NotJustUnaffordable()
    {
        var e = Make(new BeekeeperState { Combs = 8, CombsRevealed = true });   // comb #9: 47 wax; cap 20 + 7 × 2 = 34
        Assert.Equal(47m, e.CombCost);
        Assert.Equal(34m, e.WaxStorage);
        Assert.True(e.CombIsWall);
        Assert.False(e.CanBuildComb);

        var poor = Make(new BeekeeperState { Combs = 2, CombsRevealed = true });  // 12 wax, cap 22: merely unaffordable
        Assert.False(poor.CombIsWall);
        Assert.False(poor.CanBuildComb);
    }

    [Fact]
    public void AWall_IsReportedOnce_AndNeverChangesAPriceOrACap()
    {
        var e = Make(new BeekeeperState { Combs = 7, CombsRevealed = true, Bees = 10_000m, Wax = 30m, HoneyRevealed = true });
        Assert.Equal(38m, e.CombCost);            // comb #8
        Assert.Equal(32m, e.WaxStorage);
        var r = e.Advance(1m);
        Assert.True(Has(r.Events, BeekeeperEvents.FirstWall));
        Assert.True(e.State.FirstWallAnnounced);
        Assert.Equal(38m, e.CombCost);            // nothing clamps
        Assert.Equal(32m, e.WaxStorage);

        for (int i = 0; i < 100; i++) Assert.False(Has(e.Advance(60m).Events, BeekeeperEvents.FirstWall));
        Assert.Equal(32m, e.State.Wax);           // stuck at the cap: intended
        Assert.False(e.CanBuildComb);
        Assert.Equal(38m, e.CombCost);
    }

    [Fact]
    public void TheWall_GoesAwayByItself_WhenTheCapRisesPastThePrice()
    {
        var e = Make(new BeekeeperState { Combs = 7, CombsRevealed = true, ShopRevealed = true, Beebits = 500m, Bees = 10_000m, Wax = 32m });
        Assert.True(e.CombIsWall);
        Assert.True(e.BuyWaxTray().Done);         // 32 + 8 = 40
        Assert.False(e.CombIsWall);
        e.Advance(60m);
        Assert.True(e.CanBuildComb);
    }

    [Fact]
    public void ShopUpgradesAndTheWoodenHive_CanBeWallsToo()
    {
        var e = Make(new BeekeeperState { Combs = 3, WorkbenchRevealed = true, BeeBreadRevealed = true });
        Assert.True(e.UpgradeIsWall(BeekeeperUpgrades.BiggerCombs1));   // 100 wax, cap 24
        Assert.True(e.WoodenHiveIsWall);                                  // 200 wax
        Assert.False(e.UpgradeIsWall(BeekeeperUpgrades.Notebook));        // no wax in its price
        Assert.True(e.AnyWallShown);
        var events = e.RevealOnLoad();
        Assert.True(Has(events, BeekeeperEvents.FirstWall));
    }

    [Fact]
    public void AHiddenPrice_IsNotAWallTheLogMentions()
    {
        var e = Make(new BeekeeperState { Combs = 8 });   // a wall price, but the Combs panel hasn't shown
        Assert.True(e.CombIsWall);
        Assert.False(e.AnyWallShown);
        Assert.False(Has(e.Advance(1m).Events, BeekeeperEvents.FirstWall));
    }

    [Fact]
    public void AHoneyPriceAboveTheHoneyCap_UsesTheSameCheck()
    {
        var e = Make();
        Assert.False(e.IsHoneyWall(200m));
        Assert.True(e.IsHoneyWall(201m));
        Assert.False(e.IsWaxWall(20m));
        Assert.True(e.IsWaxWall(20.5m));
    }

    [Fact]
    public void DebugWaxOverTheCap_CanStillPayPastAWall()
    {
        var e = Make(new BeekeeperState { Combs = 8, CombsRevealed = true, Bees = 1000m });
        e.DebugGrant(0m, 100m, 0m);
        Assert.Equal(100m, e.State.Wax);
        Assert.True(e.CombIsWall);
        Assert.True(e.BuildComb().Done);
    }

    // ============================================================ debug commands

    [Fact]
    public void DebugAddCombs_AndFillWax()
    {
        var e = Make();
        var events = e.DebugAddCombs(5);
        Assert.Equal(6, e.State.Combs);
        Assert.True(e.State.CombsRevealed);
        Assert.True(Has(events, BeekeeperEvents.WorkbenchOpened));
        e.DebugFillWax();
        Assert.Equal(30m, e.State.Wax);            // 20 + 5 × 2
        Assert.True(e.State.WaxRevealed);
        e.State.Wax = 100m;
        e.DebugFillWax();
        Assert.Equal(100m, e.State.Wax);           // never down
    }

    // ============================================================ live and away (FR-715)

    /// <summary>Everything changes part-way: the queen lays until the pantry empties (free bees and
    /// the wax rate grow), a plant sprouts, a sage-propolis candle burns out, and both caps fill.</summary>
    private static BeekeeperState Busy() => new()
    {
        HoneyRevealed = true, Combs = 6, Bees = 300m, Honey = 900m, Wax = 10m, HasWaxCatcher = true,
        HasWoodenHive = true, QueenSettled = true, BeeBread = 3m, BeeBreadRevealed = true,
        Plants = { BeekeeperPlants.Wildflowers, BeekeeperPlants.Poplar }, GardenRevealed = true,
        Beds = { new BeekeeperBed { PlantId = BeekeeperPlants.Bramble, SecondsLeft = 450m } },
        SagePropolisSecondsLeft = 700m, CombsRevealed = true, WaxRevealed = true,
    };

    private static void AssertSame(BeekeeperEngine live, BeekeeperEngine away)
    {
        const int Places = 6;
        Assert.Equal((double)away.State.Honey, (double)live.State.Honey, Places);
        Assert.Equal((double)away.State.Wax, (double)live.State.Wax, Places);
        Assert.Equal((double)away.State.Bees, (double)live.State.Bees, Places);
        Assert.Equal((double)away.State.BeeBread, (double)live.State.BeeBread, Places);
        Assert.Equal((double)away.State.Pollen, (double)live.State.Pollen, Places);
        Assert.Equal((double)away.State.Propolis, (double)live.State.Propolis, Places);
        Assert.Equal(away.State.SagePropolisSecondsLeft, live.State.SagePropolisSecondsLeft);
        Assert.Equal(away.State.Plants, live.State.Plants);
        Assert.Equal(away.State.StorageFullAnnounced, live.State.StorageFullAnnounced);
        Assert.Equal(away.State.WaxFullAnnounced, live.State.WaxFullAnnounced);
        Assert.Equal(away.State.Beebits, live.State.Beebits);
    }

    [Fact]
    public void LiveAndAway_Agree_WithTheQueenThePantryASproutACandleAndBothCaps()
    {
        var live = Make(Busy());
        for (int i = 0; i < 3000; i++) live.Advance(1m);
        var away = Make(Busy());
        away.AdvanceAway(3000m);

        AssertSame(live, away);
        // Everything did happen part-way:
        Assert.Equal(0m, away.State.BeeBread);                                 // the pantry ran out (at 900 s)
        Assert.Equal(600m, away.State.Bees);
        Assert.Contains(BeekeeperPlants.Bramble, away.State.Plants);           // sprouted at 450 s
        Assert.Equal(0m, away.State.SagePropolisSecondsLeft);                  // burned out at 700 s
        Assert.Equal(away.HoneyStorage, away.State.Honey);                     // honey cap reached
        Assert.Equal(away.WaxStorage, away.State.Wax);                         // wax cap reached
        Assert.True(away.State.StorageFullAnnounced && away.State.WaxFullAnnounced);
    }

    [Fact]
    public void LiveAndAway_Agree_InOddSteps()
    {
        var live = Make(Busy());
        decimal[] steps = { 7m, 333m, 60m, 1m, 599m, 1000m, 0.5m, 999.5m };
        foreach (var s in steps) live.Advance(s);
        var away = Make(Busy());
        away.AdvanceAway(steps.Sum());
        AssertSame(live, away);
    }

    [Fact]
    public void TimeAway_NeverSellsHoney_EvenUnderTheAgreement()
    {
        var s = Busy();
        s.HasTradeAgreement = true;
        s.Trades = 40;
        var e = Make(s);
        var r = e.AdvanceAway(3m * 24m * 3600m);
        Assert.Equal(0m, e.State.Beebits);
        Assert.Equal(40, e.State.Trades);
        Assert.Contains(r.WelcomeBack, x => x.Key == BeekeeperEvents.WelcomeBack);
    }

    [Fact]
    public void TheWelcomeBack_IsToldAtZeroFreeBees_OnceTheHiveHasStarted()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true, Bees = 0m });
        var r = e.AdvanceAway(3600m);
        Assert.Contains(r.WelcomeBack, x => x.Key == BeekeeperEvents.WelcomeBack && x.Value == 200m);   // filled to the cap
    }
}
