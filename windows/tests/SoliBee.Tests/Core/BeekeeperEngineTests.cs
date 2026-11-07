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

    [Fact]
    public void TwelveBeesMakePointOneTwoHoneyPerSecond()
    {
        var e = Make(state: new BeekeeperState { Bees = 12m });
        e.Advance(1m);
        Assert.Equal(0.12m, e.State.Honey);
    }

    [Fact]
    public void Honey_StopsAtStorage_AndTheExtraIsLost()
    {
        var e = Make(state: new BeekeeperState { Bees = 100m, Honey = 199.5m });
        var r = e.Advance(1m);
        Assert.Equal(200m, e.State.Honey);
        Assert.Equal(0.5m, r.HoneyStored);
    }

    [Fact]
    public void WhenStorageIsFull_NoHoneyIsStored_AndItIsAnnouncedOnce()
    {
        var e = Make(state: new BeekeeperState { Bees = 100m, Honey = 200m });
        var first = e.Advance(1m);
        Assert.Equal(0m, first.HoneyStored);
        Assert.True(Has(first.Events, BeekeeperEvents.StorageFull));

        var second = e.Advance(1m);
        Assert.False(Has(second.Events, BeekeeperEvents.StorageFull));
        Assert.Equal(200m, e.State.Honey);
    }

    [Fact]
    public void WhenStorageIsFull_WaxStillComes()
    {
        var e = Make(state: new BeekeeperState { Bees = 100m, Honey = 200m }); // 1 honey/s made, none fits
        var r = e.Advance(50m);
        Assert.Equal(0m, r.HoneyStored);
        Assert.Equal(1m, r.WaxMade);
        Assert.Equal(1m, e.State.Wax);
        Assert.Equal(200m, e.State.Honey);
    }

    [Fact]
    public void StorageFull_IsAnnouncedAgain_AfterRoomOpensUp()
    {
        var e = Make(state: new BeekeeperState { Bees = 100m, Honey = 200m });
        e.Advance(1m);                       // announced
        e.SellTen();                         // room again
        var again = e.Advance(20m);          // refills and overflows
        Assert.True(Has(again.Events, BeekeeperEvents.StorageFull));
    }

    // ============================================================ wax

    [Fact]
    public void FiftyHoneyStored_DropsOneWax_AndRemainderCarries()
    {
        var e = Make(state: new BeekeeperState { Bees = 5000m }); // 50 honey per second
        e.Advance(1m);
        Assert.Equal(1m, e.State.Wax);
        Assert.Equal(0m, e.State.WaxProgress);

        var e2 = Make(state: new BeekeeperState { Bees = 100m }); // 1 honey per second
        e2.Advance(30m);
        Assert.Equal(0m, e2.State.Wax);
        Assert.Equal(30m, e2.State.WaxProgress);
        e2.Advance(20m);
        Assert.Equal(1m, e2.State.Wax);
    }

    [Fact]
    public void WaxCatcher_DoublesWax()
    {
        var e = Make(state: new BeekeeperState { Bees = 5000m, HasWaxCatcher = true });
        e.Advance(1m);
        Assert.Equal(2m, e.State.Wax);
    }

    [Fact]
    public void SellingHoney_DoesNotChangeWaxProgress()
    {
        var e = Make(state: new BeekeeperState { Bees = 100m });
        e.Advance(30m);                      // 30 honey, 30 wax progress
        e.SellAll();                         // honey -> 0
        Assert.Equal(0m, e.State.Honey);
        Assert.Equal(30m, e.State.WaxProgress);
        e.Advance(20m);                      // reaches 50 progress
        Assert.Equal(1m, e.State.Wax);
    }

    [Fact]
    public void BuyingTheWaxCatcherMidGame_OnlyChangesLaterWax()
    {
        var e = Make(state: new BeekeeperState { Bees = 100m, Beebits = 150m, ShopRevealed = true });
        e.Advance(100m);                     // 100 honey -> 2 wax at normal rate
        Assert.Equal(2m, e.State.Wax);
        Assert.True(e.BuyWaxCatcher().Done);
        e.Advance(50m);                      // 50 more honey -> 2 wax (doubled)
        Assert.Equal(4m, e.State.Wax);
    }

    [Fact]
    public void FirstWax_IsAnnouncedOnce()
    {
        var e = Make(state: new BeekeeperState { Bees = 5000m });
        Assert.True(Has(e.Advance(1m).Events, BeekeeperEvents.FirstWax));
        Assert.False(Has(e.Advance(1m).Events, BeekeeperEvents.FirstWax));
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
        var e = Make(state: new BeekeeperState { Bees = 1000m }); // 10 honey per second
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
        Assert.False(e.BuyNextTool().Done);      // the Bee Lure costs 1,000
        Assert.Equal(1000m - 75m - 250m, e.State.Beebits);
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

    [Fact]
    public void CombCosts_FollowFloorOfFiftyTimesOnePointTwoFiveToTheN()
    {
        var expected = new[] { 50m, 62m, 78m, 97m, 122m, 152m, 190m };
        var e = Make();
        for (int n = 0; n < expected.Length; n++)
        {
            e.State.Combs = n;
            Assert.Equal(expected[n], e.CombCost);
        }
    }

    [Fact]
    public void BuildingAComb_SpendsWax_AndAddsHoneyStorage()
    {
        var e = Make(state: new BeekeeperState { Wax = 120m });
        Assert.Equal(200m, e.HoneyStorage);
        var r = e.BuildComb();
        Assert.True(r.Done);
        Assert.Equal(70m, e.State.Wax);
        Assert.Equal(1, e.State.Combs);
        Assert.Equal(400m, e.HoneyStorage);
        Assert.Equal(62m, e.CombCost);
    }

    [Fact]
    public void BuildingAComb_WithTooLittleWax_DoesNothing()
    {
        var e = Make(state: new BeekeeperState { Wax = 49m });
        Assert.False(e.CanBuildComb);
        Assert.False(e.BuildComb().Done);
        Assert.Equal(0, e.State.Combs);
        Assert.Equal(49m, e.State.Wax);
    }

    [Fact]
    public void CombsPanel_AppearsAtFiftyWax_AndStays()
    {
        var e = Make(state: new BeekeeperState { Wax = 49m });
        Assert.False(e.State.CombsRevealed);
        e.State.Bees = 5000m;                   // 50 honey -> 1 wax
        var r = e.Advance(1m);
        Assert.True(e.State.CombsRevealed);
        Assert.True(Has(r.Events, BeekeeperEvents.CombsAvailable));
        e.BuildComb();                          // wax drops below 50
        Assert.True(e.State.CombsRevealed);
    }

    // ============================================================ time away

    private static BeekeeperConfig BigStorage() => new() { StartingStorage = 1_000_000_000m };

    [Fact]
    public void TwoHoursAway_100Bees_Makes7200Honey()
    {
        var e = Make(BigStorage(), state: new BeekeeperState { Bees = 100m });
        var r = e.AdvanceAway(7200m);
        Assert.Equal(7200m, r.CreditedSeconds);
        Assert.Equal(7200m, e.State.Honey);
        Assert.Equal(144m, e.State.Wax);        // 7200 / 50
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.WelcomeBack && ev.Value == 7200m);
    }

    [Fact]
    public void TenDaysAway_IsCutToThreeDays()
    {
        var e = Make(BigStorage(), state: new BeekeeperState { Bees = 100m });
        var r = e.AdvanceAway(10m * 24m * 3600m);
        Assert.Equal(259_200m, r.CreditedSeconds);
        Assert.Equal(100m * 0.01m * 259_200m, e.State.Honey);
    }

    [Fact]
    public void NegativeOrZeroGap_EarnsNothingAndBreaksNothing()
    {
        var e = Make(BigStorage(), state: new BeekeeperState { Bees = 100m });
        var r = e.AdvanceAway(-5000m);
        Assert.Equal(0m, r.CreditedSeconds);
        Assert.Equal(0m, e.State.Honey);
        Assert.Empty(r.Events);
        Assert.Equal(0m, e.AdvanceAway(0m).HoneyStored);
    }

    [Fact]
    public void StorageFillingOneHourIn_StopsHoneyThere_ButWaxKeepsComing()
    {
        var cfg = new BeekeeperConfig { StartingStorage = 3600m };
        var e = Make(cfg, state: new BeekeeperState { Bees = 100m }); // 1 honey/second
        var r = e.AdvanceAway(7200m);
        Assert.Equal(3600m, e.State.Honey);
        Assert.Equal(3600m, r.HoneyStored);
        Assert.Equal(144m, e.State.Wax);         // 7200 honey made / 50
        Assert.True(Has(r.Events, BeekeeperEvents.StorageFull));
    }

    [Fact]
    public void OfflineRate_CanBeLowered()
    {
        var cfg = new BeekeeperConfig { StartingStorage = 1_000_000m, OfflineRate = 0.5m };
        var e = Make(cfg, state: new BeekeeperState { Bees = 100m });
        e.AdvanceAway(7200m);
        Assert.Equal(3600m, e.State.Honey);
    }

    [Fact]
    public void WelcomeBack_SaysNothingForAnEmptyHive_AndAGladLineWhenNothingWasMade()
    {
        var empty = Make();
        Assert.Empty(empty.AdvanceAway(3600m).Events);

        var full = Make(state: new BeekeeperState { Bees = 100m, Honey = 200m });
        var r = full.AdvanceAway(3600m);
        Assert.True(Has(r.Events, BeekeeperEvents.WelcomeBackNothing));
    }

    [Fact]
    public void DebugGrant_AddsWhatItSays_AndRevealsTheCardsItUnlocks()
    {
        var e = Make();
        var events = e.DebugGrant(100m, 100m, 100m);

        Assert.Equal(100m, e.State.Bees);
        Assert.Equal(100m, e.State.Wax);
        Assert.Equal(100m, e.State.Beebits);
        Assert.True(e.State.HoneyRevealed && e.State.WaxRevealed && e.State.BeebitsRevealed);
        Assert.True(e.State.ShopRevealed);    // 100 Beebits ≥ 15
        Assert.True(e.State.CombsRevealed);   // 100 wax ≥ 50
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

    [Theory]
    [InlineData(false, 200000)]   // plenty of room
    [InlineData(true, 200000)]    // with the Wax-Catcher
    [InlineData(false, 1800)]     // storage fills partway through
    [InlineData(true, 1800)]
    public void LiveTicking_AndAwayRoute_GiveTheSameResult(bool catcher, int storage)
    {
        BeekeeperState NewState() => new() { Bees = 150m, Honey = 5m, HasWaxCatcher = catcher };
        var cfg = new BeekeeperConfig { StartingStorage = storage };

        var live = Make(cfg, state: NewState());
        for (int i = 0; i < 3600; i++) live.Advance(1m);

        var away = Make(cfg, state: NewState());
        away.AdvanceAway(3600m);

        Assert.Equal(live.State.Honey, away.State.Honey);
        Assert.Equal(live.State.Wax, away.State.Wax);
        Assert.Equal(live.State.WaxProgress, away.State.WaxProgress);
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
        Assert.Equal(0, e.State.Combs);
        Assert.Equal(0, e.State.ToolLevel);
        Assert.False(e.State.ShopRevealed);
        Assert.Equal("Buster", e.State.BearName);
    }
}
