using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

public class BeekeeperEngineTests
{
    // Dice we control: doubles for stings, ints for the bear's name.
    private sealed class FakeRandom : IRandomSource
    {
        private readonly Queue<double> _doubles;
        private readonly Queue<int> _ints;
        public int DoubleDraws { get; private set; }

        public FakeRandom(IEnumerable<double>? doubles = null, IEnumerable<int>? ints = null)
        {
            _doubles = new Queue<double>(doubles ?? new double[] { 0.99, 0.99, 0.99, 0.99, 0.99, 0.99 });
            _ints = new Queue<int>(ints ?? new[] { 0 });
        }

        public double NextDouble() { DoubleDraws++; return _doubles.Count > 0 ? _doubles.Dequeue() : 0.99; }
        public int Next(int maxExclusive) => _ints.Count > 0 ? _ints.Dequeue() : 0;
    }

    private static BeekeeperEngine Make(BeekeeperConfig? config = null, FakeRandom? rng = null, BeekeeperState? state = null)
        => new(config ?? BeekeeperConfig.Default, state, rng ?? new FakeRandom());

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    // ============================================================ catching

    [Fact]
    public void BareHands_StingsBelowTwentyPercent_AndCatchesAtOrAbove()
    {
        var e = Make(rng: new FakeRandom(new[] { 0.19, 0.20 }));
        var stung = e.Catch();
        Assert.True(stung.Stung);
        Assert.Equal(0m, stung.BeesGained);
        Assert.Equal(0m, e.State.Bees);
        Assert.True(Has(stung.Events, BeekeeperEvents.Sting));

        var caught = e.Catch();
        Assert.False(caught.Stung);
        Assert.Equal(1m, caught.BeesGained);
        Assert.Equal(1m, e.State.Bees);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    public void BetterTools_NeverSting_AndNeverRollTheDice(int toolLevel)
    {
        var rng = new FakeRandom(new[] { 0.0, 0.0, 0.0 }); // would sting every time
        var state = new BeekeeperState { ToolLevel = toolLevel };
        var e = Make(rng: rng, state: state);
        for (int i = 0; i < 3; i++) Assert.False(e.Catch().Stung);
        Assert.Equal(0, rng.DoubleDraws);
    }

    [Theory]
    [InlineData(0, 1)]
    [InlineData(1, 2)]
    [InlineData(2, 5)]
    [InlineData(3, 10)]
    public void EachToolCatchesItsNumberOfBees(int toolLevel, int bees)
    {
        var e = Make(state: new BeekeeperState { ToolLevel = toolLevel });
        Assert.Equal(bees, e.BeesPerClick);
        Assert.Equal(bees, e.Catch().BeesGained);
        Assert.Equal(bees, e.State.Bees);
    }

    [Fact]
    public void ThereIsNoLimitOnBees()
    {
        var e = Make(state: new BeekeeperState { ToolLevel = 3, Bees = 1_000_000m });
        var result = e.Catch();
        Assert.False(result.Stung);
        Assert.Equal(1_000_110m, e.State.Bees);   // 10 from the Vacuum + the slice, capped at 10 × 10 (stage 5)
    }

    [Fact]
    public void FirstBee_RevealsTheHiveOnce()
    {
        var e = Make();
        Assert.False(e.State.HoneyRevealed);
        Assert.True(Has(e.Catch().Events, BeekeeperEvents.FirstBee));
        Assert.True(e.State.HoneyRevealed);
        Assert.False(Has(e.Catch().Events, BeekeeperEvents.FirstBee));
    }

    // ============================================================ honey and storage
    // Stage 7.5 (spec 016): the combs make the honey, 0.2 a second each, from the first bee on.

    [Fact]
    public void FiveCombsMakeOneHoneyASecond_HoweverManyBees()
    {
        var e = Make(state: BeekeeperTestHives.Started(5));
        e.Advance(1m);
        Assert.Equal(1m, e.State.Honey);

        var many = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Bees = 1_000_000m });
        many.Advance(1m);
        Assert.Equal(1m, many.State.Honey);
    }

    // Cut in stage 7.5 (spec 016): every bee made 0.01 honey a second.
    // [Fact]
    // public void TwelveBeesMakePointOneTwoHoneyPerSecond()
    // {
    //     var e = Make(state: new BeekeeperState { Bees = 12m });
    //     e.Advance(1m);
    //     Assert.Equal(0.12m, e.State.Honey);
    // }

    [Fact]
    public void Honey_StopsAtStorage_AndTheExtraIsLost()
    {
        // 5 combs: room for 200 + 4 × 300 = 1,400 honey.
        var e = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Honey = 1399.5m });
        var r = e.Advance(1m);
        Assert.Equal(1400m, e.State.Honey);
        Assert.Equal(0.5m, r.HoneyStored);
    }

    [Fact]
    public void WhenStorageIsFull_NoHoneyIsStored_AndNothingIsSaid()
    {
        var e = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Honey = 1400m });
        var first = e.Advance(1m);
        Assert.Equal(0m, first.HoneyStored);
        Assert.False(Has(first.Events, BeekeeperEvents.StorageFull));   // review change: no log line for capped honey

        var second = e.Advance(1m);
        Assert.False(Has(second.Events, BeekeeperEvents.StorageFull));
        Assert.Equal(1400m, e.State.Honey);
    }

    // Cut in stage 7.5 (spec 016): wax followed all the honey made, full combs or not.
    // [Fact]
    // public void WhenStorageIsFull_WaxStillComes()
    // {
    //     var e = Make(state: new BeekeeperState { Bees = 100m, Honey = 200m }); // 1 honey/s made, none fits
    //     var r = e.Advance(50m);
    //     Assert.Equal(0m, r.HoneyStored);
    //     Assert.Equal(1m, r.WaxMade);
    //     Assert.Equal(1m, e.State.Wax);
    //     Assert.Equal(200m, e.State.Honey);
    // }

    [Fact]
    public void WhenHoneyIsFull_NothingSpillsIntoWax()
    {
        var full = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Honey = 1400m });
        var empty = Make(state: BeekeeperTestHives.Started(5));
        full.Advance(100m);
        empty.Advance(100m);
        Assert.Equal(0.5m, full.State.Wax);          // just the drip: 0.005 × 100
        Assert.Equal(empty.State.Wax, full.State.Wax);
        Assert.Equal(1400m, full.State.Honey);
    }

    // Cut after the stage 7.5 review (Bee): no log line when the honey is capped.
    // [Fact]
    // public void StorageFull_IsAnnouncedAgain_AfterRoomOpensUp()
    // {
    //     var e = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Honey = 1400m });
    //     e.Advance(1m);                       // announced
    //     e.SellTen();                         // room again
    //     var again = e.Advance(20m);          // refills and overflows
    //     Assert.True(Has(again.Events, BeekeeperEvents.StorageFull));
    // }

    // ============================================================ wax
    // Stage 7.5 (spec 016): a tiny drip from the start plus a little from every free bee.

    // Cut in stage 7.5 (spec 016): 50 honey stored dropped 1 wax.
    // [Fact]
    // public void FiftyHoneyStored_DropsOneWax_AndRemainderCarries()
    // {
    //     var e = Make(state: new BeekeeperState { Bees = 5000m }); // 50 honey per second
    //     e.Advance(1m);
    //     Assert.Equal(1m, e.State.Wax);
    //     Assert.Equal(0m, e.State.WaxProgress);
    //
    //     var e2 = Make(state: new BeekeeperState { Bees = 100m }); // 1 honey per second
    //     e2.Advance(30m);
    //     Assert.Equal(0m, e2.State.Wax);
    //     Assert.Equal(30m, e2.State.WaxProgress);
    //     e2.Advance(20m);
    //     Assert.Equal(1m, e2.State.Wax);
    // }

    [Fact]
    public void Wax_DripsFromTheStart_WithNoBeesAtAll()
    {
        var e = Make();
        e.Advance(100m);
        Assert.Equal(0.5m, e.State.Wax);              // 0.005 a second
        Assert.Equal(0m, e.State.Honey);              // no honey before the first bee
    }

    [Fact]
    public void Wax_FreeBeesAddToTheRate()
    {
        var e = Make(state: new BeekeeperState { Bees = 1000m });
        Assert.Equal(0.105m, e.WaxPerSecondNow);      // 0.005 + 1,000 × 0.0001
        e.Advance(10m);
        Assert.Equal(1.05m, e.State.Wax);
    }

    [Fact]
    public void WaxCatcher_DoublesTheWholeRate_AndTheBetterOneTriplesIt()
    {
        var e = Make(state: new BeekeeperState { Bees = 1000m, HasWaxCatcher = true });
        e.Advance(10m);
        Assert.Equal(2.1m, e.State.Wax);

        var better = Make(state: new BeekeeperState { Bees = 1000m, HasWaxCatcher = true,
            Upgrades = { BeekeeperUpgrades.BetterWaxCatcher } });
        better.Advance(10m);
        Assert.Equal(3.15m, better.State.Wax);
    }

    // Cut in stage 7.5 (spec 016): the Wax-Catcher doubled wax per 50 honey.
    // [Fact]
    // public void WaxCatcher_DoublesWax()
    // {
    //     var e = Make(state: new BeekeeperState { Bees = 5000m, HasWaxCatcher = true });
    //     e.Advance(1m);
    //     Assert.Equal(2m, e.State.Wax);
    // }

    [Fact]
    public void Wax_DoesNotChangeWithTheNumberOfCombs()
    {
        var one = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 1, Bees = 500m });
        var ten = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 10, Bees = 500m });
        Assert.Equal(one.WaxPerSecondNow, ten.WaxPerSecondNow);
        one.Advance(10m);
        ten.Advance(10m);
        Assert.Equal(one.State.Wax, ten.State.Wax);
    }

    [Fact]
    public void SellingHoney_DoesNotTouchWax()
    {
        var e = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5 });
        e.Advance(30m);                      // 30 honey, 0.15 wax
        e.SellAll();                         // honey -> 0
        Assert.Equal(0m, e.State.Honey);
        Assert.Equal(0.15m, e.State.Wax);
    }

    // Cut in stage 7.5 (spec 016): selling honey never touched the honey-to-wax progress.
    // [Fact]
    // public void SellingHoney_DoesNotChangeWaxProgress()
    // {
    //     var e = Make(state: new BeekeeperState { Bees = 100m });
    //     e.Advance(30m);                      // 30 honey, 30 wax progress
    //     e.SellAll();                         // honey -> 0
    //     Assert.Equal(0m, e.State.Honey);
    //     Assert.Equal(30m, e.State.WaxProgress);
    //     e.Advance(20m);                      // reaches 50 progress
    //     Assert.Equal(1m, e.State.Wax);
    // }

    [Fact]
    public void BuyingTheWaxCatcherMidGame_OnlyChangesLaterWax()
    {
        var e = Make(state: new BeekeeperState { Bees = 1000m, Beebits = 150m, ShopRevealed = true });
        e.Advance(10m);                      // 1.05 wax at the normal rate
        Assert.Equal(1.05m, e.State.Wax);
        Assert.True(e.BuyWaxCatcher().Done);
        e.Advance(10m);                      // 2.1 more (doubled)
        Assert.Equal(3.15m, e.State.Wax);
    }

    [Fact]
    public void FirstWax_IsAnnouncedOnce_AtOneWholeWax()
    {
        var e = Make();                                  // the drip alone: 1 wax in 200 seconds
        Assert.False(Has(e.Advance(199m).Events, BeekeeperEvents.FirstWax));
        Assert.False(e.State.WaxRevealed);
        Assert.True(Has(e.Advance(1m).Events, BeekeeperEvents.FirstWax));
        Assert.True(e.State.WaxRevealed);
        Assert.False(Has(e.Advance(1m).Events, BeekeeperEvents.FirstWax));
    }

    [Fact]
    public void Wax_StopsAtTheWaxCap_AndNothingIsSaid()
    {
        var e = Make(state: new BeekeeperState { Bees = 1000m, Wax = 19.99m });   // cap 20
        Assert.Equal(20m, e.WaxStorage);
        var first = e.Advance(1m);
        Assert.Equal(20m, e.State.Wax);
        Assert.Equal(0.01m, first.WaxMade);
        Assert.True(e.IsWaxFull);
        Assert.False(Has(first.Events, BeekeeperEvents.WaxFull));   // review change: no log line for capped wax

        var second = e.Advance(10m);
        Assert.Equal(20m, e.State.Wax);
        Assert.False(Has(second.Events, BeekeeperEvents.WaxFull));

        e.State.Wax = 10m;                               // spent
        e.Advance(1m);
        Assert.False(Has(e.Advance(100m).Events, BeekeeperEvents.WaxFull));
    }

    [Fact]
    public void FullWax_DoesNotStopHoney_AndFullHoneyDoesNotStopWax()
    {
        var e = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Wax = 28m });   // wax cap 20 + 4 × 2
        Assert.True(e.IsWaxFull);
        e.Advance(10m);
        Assert.Equal(10m, e.State.Honey);
        Assert.Equal(28m, e.State.Wax);
    }

    // ============================================================ the bear

    [Fact]
    public void SellAll_FortySevenHoney_GivesFourBeebitsAndKeepsSeven()
    {
        var e = Make(state: new BeekeeperState { Honey = 47m });
        var r = e.SellAll();
        Assert.True(r.Done);
        Assert.Equal(4m, e.State.Beebits);
        Assert.Equal(7m, e.State.Honey);
        Assert.Equal(1, e.State.Trades);
    }

    [Fact]
    public void SellAll_KeepsHoneyFractions()
    {
        var e = Make(state: new BeekeeperState { Honey = 47.3m });
        e.SellAll();
        Assert.Equal(7.3m, e.State.Honey);
    }

    [Fact]
    public void SellTen_GivesOneBeebit_AndCountsOneTrade()
    {
        var e = Make(state: new BeekeeperState { Honey = 25m });
        Assert.True(e.SellTen().Done);
        Assert.Equal(15m, e.State.Honey);
        Assert.Equal(1m, e.State.Beebits);
        Assert.Equal(1, e.State.Trades);
        Assert.True(e.State.BeebitsRevealed);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(9)]
    public void UnderTenHoney_CannotSell(int honey)
    {
        var e = Make(state: new BeekeeperState { Honey = honey });
        Assert.False(e.CanSell);
        Assert.False(e.SellTen().Done);
        Assert.False(e.SellAll().Done);
        Assert.Equal(0m, e.State.Beebits);
        Assert.Equal(0, e.State.Trades);
    }

    [Fact]
    public void Bear_AppearsAtTenHoney_AndStays()
    {
        var e = Make(state: BeekeeperTestHives.Started(50)); // 10 honey per second
        Assert.False(e.State.BearRevealed);
        var r = e.Advance(1m);
        Assert.True(e.State.BearRevealed);
        Assert.True(Has(r.Events, BeekeeperEvents.BearArrives));
        e.SellAll();
        Assert.True(e.State.BearRevealed);
    }

    [Fact]
    public void BearName_IsChosenByTheDice_FromTheSevenNames()
    {
        Assert.Equal("Bruno", Make(rng: new FakeRandom(ints: new[] { 3 })).State.BearName);
        Assert.Equal("Bartholomew", Make(rng: new FakeRandom(ints: new[] { 6 })).State.BearName);
        Assert.Equal(7, BeekeeperConfig.Default.BearNames.Count);
    }

    // ============================================================ the shop

    [Fact]
    public void Shop_AppearsAtFifteenBeebits_AndStays()
    {
        var e = Make(state: new BeekeeperState { Honey = 150m });
        e.SellAll();                          // 15 Beebits
        Assert.True(e.State.ShopRevealed);
        e.BuyNextTool();                      // spend them
        Assert.True(e.State.ShopRevealed);
    }

    [Fact]
    public void Tools_AreBoughtInOrder_GlovesNetVacuum()
    {
        var e = Make(state: new BeekeeperState { Beebits = 80m, ShopRevealed = true });
        Assert.Equal("gloves", e.NextTool!.Id);
        Assert.True(e.BuyNextTool().Done);     // Gloves 15 -> 65 left
        Assert.Equal(1, e.State.ToolLevel);
        Assert.Equal(65m, e.State.Beebits);
        Assert.False(e.BuyNextTool().Done);    // Net costs 75
        Assert.Equal(1, e.State.ToolLevel);

        e.State.Beebits = 1000m;
        Assert.True(e.BuyNextTool().Done);     // Net
        Assert.True(e.BuyNextTool().Done);     // Vacuum
        Assert.Equal(3, e.State.ToolLevel);
        Assert.Equal("lure", e.NextTool!.Id);   // stage 3 tools come after the Vacuum
        Assert.False(e.BuyNextTool().Done);      // the Bee Lure costs 3,000
        Assert.Equal(1000m - 75m - 400m, e.State.Beebits);
    }

    [Fact]
    public void Tools_CannotBeBoughtBeforeTheShopHasOpened()
    {
        var e = Make(state: new BeekeeperState { Beebits = 500m, ShopRevealed = false });
        Assert.False(e.BuyNextTool().Done);
        Assert.False(e.BuyWaxCatcher().Done);
    }

    [Fact]
    public void WaxCatcher_IsIndependentOfToolOrder_AndBoughtOnlyOnce()
    {
        var e = Make(state: new BeekeeperState { Beebits = 400m, ShopRevealed = true });
        Assert.True(e.BuyWaxCatcher().Done);   // before any tool
        Assert.True(e.State.HasWaxCatcher);
        Assert.Equal(0, e.State.ToolLevel);
        Assert.Equal(250m, e.State.Beebits);
        Assert.False(e.BuyWaxCatcher().Done);
        Assert.Equal(250m, e.State.Beebits);
    }

    // ============================================================ combs
    // Stage 7.5 (spec 016): one starter comb; a comb costs bees and wax; both caps grow.

    // Cut in stage 7.5 (spec 016): wax only, floor(50 × 1.25^n), no starter comb.
    // [Fact]
    // public void CombCosts_FollowFloorOfFiftyTimesOnePointTwoFiveToTheN()
    // {
    //     var expected = new[] { 50m, 62m, 78m, 97m, 122m, 152m, 190m };
    //     var e = Make();
    //     for (int n = 0; n < expected.Length; n++)
    //     {
    //         e.State.Combs = n;
    //         Assert.Equal(expected[n], e.CombCost);
    //     }
    // }

    [Fact]
    public void CombPrices_CountCombsBought_NotTheStarter()
    {
        var wax = new[] { 10m, 12m, 15m, 19m, 24m, 30m, 38m };
        var bees = new[] { 20m, 28m, 39m, 54m, 76m, 107m, 150m };
        var e = Make();
        for (int n = 0; n < wax.Length; n++)
        {
            e.State.Combs = n + 1;                        // n bought, plus the starter
            Assert.Equal(wax[n], e.CombCost);
            Assert.Equal(bees[n], e.CombBeeCost);
        }
    }

    [Fact]
    public void ANewGame_HasOneComb_TheFirstPrice_AndTheStartingCaps()
    {
        var e = Make();
        Assert.Equal(1, e.State.Combs);
        Assert.Equal(0m, e.State.Bees);
        Assert.Equal(20m, e.CombBeeCost);
        Assert.Equal(10m, e.CombCost);
        Assert.Equal(200m, e.HoneyStorage);
        Assert.Equal(20m, e.WaxStorage);
        Assert.Equal(0m, e.HoneyPerSecondNow);            // no honey before the first bee
    }

    // Cut in stage 7.5 (spec 016): a comb cost wax only and added honey storage only.
    // [Fact]
    // public void BuildingAComb_SpendsWax_AndAddsHoneyStorage()
    // {
    //     var e = Make(state: new BeekeeperState { Wax = 120m });
    //     Assert.Equal(200m, e.HoneyStorage);
    //     var r = e.BuildComb();
    //     Assert.True(r.Done);
    //     Assert.Equal(70m, e.State.Wax);
    //     Assert.Equal(1, e.State.Combs);
    //     Assert.Equal(400m, e.HoneyStorage);
    //     Assert.Equal(62m, e.CombCost);
    // }

    [Fact]
    public void BuildingAComb_TakesBeesAndWax_AndGrowsBothCaps()
    {
        var e = Make(state: new BeekeeperState { HoneyRevealed = true, Bees = 25m, Wax = 12m });
        var r = e.BuildComb();
        Assert.True(r.Done);
        Assert.Equal(5m, e.State.Bees);                   // the 20 bees moved in
        Assert.Equal(2m, e.State.Wax);
        Assert.Equal(2, e.State.Combs);
        Assert.Equal(500m, e.HoneyStorage);               // 200 + 300
        Assert.Equal(22m, e.WaxStorage);                  // 20 + 2
        Assert.Equal(28m, e.CombBeeCost);
        Assert.Equal(12m, e.CombCost);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.CombBuilt && ev.Value == 20m);
        Assert.Equal(0.4m, e.HoneyPerSecondNow);          // two combs
    }

    [Theory]
    [InlineData(19, 100)]   // one bee short
    [InlineData(100, 9)]    // one wax short
    public void BuildingAComb_NeedsBothBeesAndWax(int bees, int wax)
    {
        var e = Make(state: new BeekeeperState { Bees = bees, Wax = wax });
        Assert.False(e.CanBuildComb);
        Assert.False(e.BuildComb().Done);
        Assert.Equal(1, e.State.Combs);
        Assert.Equal(bees, e.State.Bees);
        Assert.Equal(wax, e.State.Wax);
    }

    // Cut in stage 7.5 (spec 016): the Combs panel came at 50 wax.
    // [Fact]
    // public void CombsPanel_AppearsAtFiftyWax_AndStays()
    // {
    //     var e = Make(state: new BeekeeperState { Wax = 49m });
    //     Assert.False(e.State.CombsRevealed);
    //     e.State.Bees = 5000m;                   // 50 honey -> 1 wax
    //     var r = e.Advance(1m);
    //     Assert.True(e.State.CombsRevealed);
    //     Assert.True(Has(r.Events, BeekeeperEvents.CombsAvailable));
    //     e.BuildComb();                          // wax drops below 50
    //     Assert.True(e.State.CombsRevealed);
    // }

    [Fact]
    public void CombsPanel_AppearsAtFiveWax_AndStays()
    {
        var e = Make(state: new BeekeeperState { Wax = 4.999m, Bees = 20m, WaxRevealed = true });
        Assert.False(e.State.CombsRevealed);
        var r = e.Advance(1m);                    // the drip and the bees take it past 5
        Assert.True(e.State.CombsRevealed);
        Assert.True(Has(r.Events, BeekeeperEvents.CombsAvailable));
        e.State.Wax = 10m;
        Assert.True(e.BuildComb().Done);          // wax drops below 5
        Assert.True(e.State.CombsRevealed);
    }

    // ============================================================ time away

    // Cut in stage 7.5 (spec 016): private static BeekeeperConfig BigStorage() => new() { StartingStorage = 1_000_000_000m };
    private static BeekeeperConfig BigStorage() => BeekeeperTestHives.BigCaps();

    [Fact]
    public void TwoHoursAway_FiveCombs_Makes7200Honey()
    {
        var e = Make(BigStorage(), state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Bees = 100m });
        var r = e.AdvanceAway(7200m);
        Assert.Equal(7200m, r.CreditedSeconds);
        Assert.Equal(7200m, e.State.Honey);
        Assert.Equal(108m, e.State.Wax);        // (0.005 + 100 × 0.0001) × 7200
        Assert.Contains(r.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBack && ev.Value == 7200m);
    }

    [Fact]
    public void TenDaysAway_IsCutToThreeDays()
    {
        var e = Make(BigStorage(), state: BeekeeperTestHives.Started(5));
        var r = e.AdvanceAway(10m * 24m * 3600m);
        Assert.Equal(259_200m, r.CreditedSeconds);
        Assert.Equal(259_200m, e.State.Honey);
    }

    [Fact]
    public void NegativeOrZeroGap_EarnsNothingAndBreaksNothing()
    {
        var e = Make(BigStorage(), state: BeekeeperTestHives.Started(5));
        var r = e.AdvanceAway(-5000m);
        Assert.Equal(0m, r.CreditedSeconds);
        Assert.Equal(0m, e.State.Honey);
        Assert.Empty(r.Events);
        Assert.Equal(0m, e.AdvanceAway(0m).HoneyStored);
    }

    // Cut in stage 7.5 (spec 016): wax kept coming after the combs filled.
    // [Fact]
    // public void StorageFillingOneHourIn_StopsHoneyThere_ButWaxKeepsComing()
    // {
    //     var cfg = new BeekeeperConfig { StartingStorage = 3600m };
    //     var e = Make(cfg, state: new BeekeeperState { Bees = 100m }); // 1 honey/second
    //     var r = e.AdvanceAway(7200m);
    //     Assert.Equal(3600m, e.State.Honey);
    //     Assert.Equal(3600m, r.HoneyStored);
    //     Assert.Equal(144m, e.State.Wax);         // 7200 honey made / 50
    //     Assert.True(Has(r.Events, BeekeeperEvents.StorageFull));
    // }

    [Fact]
    public void HoneyFillingOneHourIn_StopsHoneyThere_AndWaxStopsAtItsOwnCap()
    {
        var cfg = new BeekeeperConfig { StartingHoneyCap = 3600m, HoneyPerCombPerSecond = 1m };
        var e = Make(cfg, state: BeekeeperTestHives.Started(1));   // 1 honey a second
        var r = e.AdvanceAway(7200m);
        Assert.Equal(3600m, e.State.Honey);
        Assert.Equal(3600m, r.HoneyStored);
        Assert.Equal(20m, e.State.Wax);          // 36 dripped, but the wax cap is 20
        Assert.Equal(20m, r.WaxMade);
        Assert.False(Has(r.Events, BeekeeperEvents.StorageFull));
        Assert.False(Has(r.Events, BeekeeperEvents.WaxFull));
    }

    [Fact]
    public void OfflineRate_CanBeLowered()
    {
        var cfg = new BeekeeperConfig { StartingHoneyCap = 1_000_000m, OfflineRate = 0.5m };
        var e = Make(cfg, state: BeekeeperTestHives.Started(5));
        e.AdvanceAway(7200m);
        Assert.Equal(3600m, e.State.Honey);
    }

    [Fact]
    public void WelcomeBack_SaysNothingBeforeTheFirstBee_AndAGladLineWhenNothingWasMade()
    {
        var empty = Make();
        var none = empty.AdvanceAway(3600m);
        Assert.Empty(none.WelcomeBack);
        Assert.Equal(18m, empty.State.Wax);       // the drip still counted: 0.005 × 3,600

        var full = Make(state: new BeekeeperState { HoneyRevealed = true, Combs = 5, Honey = 1400m });
        var r = full.AdvanceAway(3600m);
        Assert.True(Has(r.WelcomeBack, BeekeeperEvents.WelcomeBackNothing));
    }

    [Fact]
    public void DebugGrant_AddsWhatItSays_AndRevealsTheCardsItUnlocks()
    {
        var e = Make();
        var events = e.DebugGrant(100m, 100m, 100m);

        Assert.Equal(100m, e.State.Bees);
        Assert.Equal(100m, e.State.Wax);          // +wax may go over the cap, like +honey
        Assert.Equal(100m, e.State.Beebits);
        Assert.True(e.State.HoneyRevealed && e.State.WaxRevealed && e.State.BeebitsRevealed);
        Assert.True(e.State.ShopRevealed);    // 100 Beebits ≥ 15
        Assert.True(e.State.CombsRevealed);   // 100 wax ≥ 5
        Assert.True(Has(events, BeekeeperEvents.ShopOpened));
        Assert.True(e.CanBuildComb);
    }

    [Fact]
    public void AGapOverTwoSeconds_CountsAsAway()
    {
        var e = Make();
        Assert.False(e.IsAway(1m));
        Assert.False(e.IsAway(2m));
        Assert.True(e.IsAway(2.01m));
    }

    // Stage 7.5 (spec 016): honey from 5 combs, wax from the drip and 150 free bees; either cap
    // may be reached part-way.
    [Theory]
    [InlineData(false, 200000, 1000000)]   // plenty of room
    [InlineData(true, 200000, 1000000)]    // with the Wax-Catcher
    [InlineData(false, 1800, 1000000)]     // honey fills partway through
    [InlineData(true, 1800, 30)]           // both fill partway through
    public void LiveTicking_AndAwayRoute_GiveTheSameResult(bool catcher, int honeyCap, int waxCap)
    {
        BeekeeperState NewState() => new() { HoneyRevealed = true, Combs = 5, Bees = 150m, Honey = 5m, HasWaxCatcher = catcher };
        var cfg = new BeekeeperConfig { StartingHoneyCap = honeyCap, StartingWaxCap = waxCap };

        var live = Make(cfg, state: NewState());
        for (int i = 0; i < 3600; i++) live.Advance(1m);

        var away = Make(cfg, state: NewState());
        away.AdvanceAway(3600m);

        Assert.Equal(live.State.Honey, away.State.Honey);
        Assert.Equal(live.State.Wax, away.State.Wax);
        // Cut in stage 7.5 (spec 016): Assert.Equal(live.State.WaxProgress, away.State.WaxProgress);
    }

    // ============================================================ new game

    [Fact]
    public void StartNewGame_ResetsEverything_AndPicksANewBear()
    {
        var rng = new FakeRandom(ints: new[] { 5 }); // an existing state is passed in, so only StartNewGame rolls for the bear
        var e = Make(rng: rng, state: new BeekeeperState { BearName = "Barnaby", Bees = 99m, Honey = 50m, Combs = 3, ToolLevel = 2, ShopRevealed = true });
        var events = e.StartNewGame();
        Assert.True(Has(events, BeekeeperEvents.NewGame));
        Assert.Equal(0m, e.State.Bees);
        Assert.Equal(1, e.State.Combs);           // the starter comb (stage 7.5)
        Assert.Equal(0, e.State.ToolLevel);
        Assert.False(e.State.ShopRevealed);
        Assert.Equal("Buster", e.State.BearName);
    }
}
