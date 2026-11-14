using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 8 (spec 017) on the screen's side: the Garden's rows with counts, the growth hovers'
/// plant bonuses, the Wood row, the Honey Super on wood, candle prices, the meadow offer, the Bees
/// tab, the welcome-back and the debug commands.</summary>
public class BeekeeperStage8ViewModelTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage8-vm-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    /// <summary>Every roll a hit; every pick the first choice.</summary>
    private sealed class Lucky : IRandomSource
    {
        public double NextDouble() => 0.0;
        public int Next(int maxExclusive) => 0;
    }

    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static readonly DateTime T0 = new(2026, 11, 11, 12, 0, 0, DateTimeKind.Utc);

    private static BeekeeperViewModel Make(BeekeeperState? state = null, IRandomSource? rng = null) =>
        new(isHeadless: true, persist: false, rng: rng ?? new NoRandom(), clock: () => T0, initialState: state);

    private static BeekeeperHiveRow Row(BeekeeperViewModel vm, string id) =>
        vm.HiveGroups.SelectMany(g => g.Rows).Single(r => r.Id == id);

    private static bool Logged(BeekeeperViewModel vm, string key) => vm.Log.Any(e => e.Key == key);

    private static BeekeeperState Garden(params (string Id, int Count)[] plants)
    {
        var s = new BeekeeperState { BearName = "Bruno", HoneyRevealed = true, GardenRevealed = true };
        foreach (var (id, n) in plants) s.Plants.AddRange(Enumerable.Repeat(id, n));
        return s;
    }

    [Fact]
    public void ALuckyHippieTrade_LogsTheSeed_AndTheGardenAppears()
    {
        var vm = Make(new BeekeeperState { HippiesRevealed = true, HippieTrades = 4, BeeswaxCandles = 3m, BearName = "Bruno" }, new Lucky());
        vm.State.RepsMet.Add("hippies");
        vm.State.RepsEngaged.Add("hippies");
        Assert.False(vm.GardenRevealed);
        vm.TradeOffers.First(o => o.Id == "hippies").TradeOne();
        Assert.True(Logged(vm, BeekeeperEvents.SeedGiven));
        Assert.True(vm.GardenRevealed);
        var row = Assert.Single(vm.SeedRows);
        Assert.Equal((BeekeeperPlants.Wildflowers, 1), (row.Plant.Id, row.Count));
    }

    [Fact]
    public void TheGardenRows_CountSeedsAndPlantsByKind_AndPlantingIsInstant()
    {
        var s = Garden((BeekeeperPlants.Wildflowers, 3));
        s.SeedsInHand.AddRange(Enumerable.Repeat(BeekeeperPlants.Clover, 12));
        s.SeedsInHand.Add(BeekeeperPlants.Bramble);
        var vm = Make(s);
        Assert.Equal(new[] { (BeekeeperPlants.Bramble, 1), (BeekeeperPlants.Clover, 12) },
            vm.SeedRows.Select(r => (r.Plant.Id, r.Count)));
        Assert.Equal(new[] { (BeekeeperPlants.Wildflowers, 3) }, vm.PlantRows.Select(r => (r.Plant.Id, r.Count)));

        vm.PlantSeedCommand.Execute(BeekeeperPlants.Bramble);
        Assert.True(Logged(vm, BeekeeperEvents.SeedPlanted));
        Assert.True(Logged(vm, BeekeeperEvents.PlantRevealed));
        Assert.Single(vm.SeedRows);
        Assert.Equal(2, vm.PlantRows.Count);
        Assert.Equal(2m, vm.PlantBonusPercent(vm.PlantRows[0].Plant));   // wildflowers ×3: +2%
        Assert.True(Row(vm, BeekeeperHiveRows.Guarding).Visible);         // the bramble works at once
    }

    [Fact]
    public void TheHoneyHover_ListsThePlantBonus_WithTheCount()
    {
        var vm = Make(Garden((BeekeeperPlants.Wildflowers, 50), (BeekeeperPlants.Bramble, 3)));
        var plant = Row(vm, BeekeeperHiveRows.Honey).Boosts!.Where(b => b.Id == BeekeeperBeeTab.PlantBoost).ToList();
        Assert.Equal(2, plant.Count);
        Assert.Equal((BeekeeperPlants.Wildflowers, 49m, 49m), (plant[0].Plant, plant[0].Count, plant[0].Percent));
        Assert.Equal((BeekeeperPlants.Bramble, 2m, 2m), (plant[1].Plant, plant[1].Count, plant[1].Percent));
    }

    [Fact]
    public void TheWaxHover_KeepsTheWaxCatcherApartFromTheClover()
    {
        var s = Garden((BeekeeperPlants.Clover, 11));
        s.HasWaxCatcher = true;
        s.Upgrades.Add(BeekeeperUpgrades.BetterWaxCatcher);   // Bee, 2026-11-12: only the Better one boosts the rate
        s.WaxRevealed = true;
        var wax = Row(Make(s), BeekeeperHiveRows.Wax);
        Assert.Contains(wax.Boosts!, b => b.Id == "wax_catcher" && b.Percent == 50m);
        Assert.Contains(wax.Boosts!, b => b.Id == BeekeeperBeeTab.PlantBoost && b.Plant == BeekeeperPlants.Clover && b.Percent == 10m);
        Assert.Equal(0.005m * 1.5m * 1.10m, wax.Rate);
    }

    [Fact]
    public void TheWoodRow_ComesWithTheCarpenterBee_AndItsHoverListsTheWillows()
    {
        Assert.False(Row(Make(Garden((BeekeeperPlants.Wildflowers, 4))), BeekeeperHiveRows.Wood).Visible);
        var s = Garden((BeekeeperPlants.Willow, 4));   // a hive with a willow has the carpenter bee (on load, if not before)
        s.Wood = 7.9m;
        var wood = Row(Make(s), BeekeeperHiveRows.Wood);
        Assert.True(wood.Visible);
        Assert.Equal(7m, wood.Value);
        Assert.Equal(1.03m / 60m, wood.Rate);
        Assert.Equal("carpenter_bee", Assert.Single(wood.Sources!).Id);
        Assert.Contains(wood.Boosts!, b => b.Plant == BeekeeperPlants.Willow && b.Count == 3m && b.Percent == 3m);
    }

    [Fact]
    public void ThePropolisHover_ShowsTheResinAndThePoplars()
    {
        var propolis = Row(Make(Garden((BeekeeperPlants.Poplar, 5))), BeekeeperHiveRows.Propolis);
        Assert.Equal(1.04m / 60m, propolis.Rate);
        Assert.Equal(1m / 60m, Assert.Single(propolis.Sources!).PerSecond);
        Assert.Contains(propolis.Boosts!, b => b.Plant == BeekeeperPlants.Poplar && b.Percent == 4m);
    }

    [Fact]
    public void TheHoneySuperRow_WaitsForWood_AndCostsWood()
    {
        var vm = Make(new BeekeeperState { ShopRevealed = true, CombsRevealed = true, Beebits = 500m, BearName = "Bruno" });
        Assert.True(vm.CapacityUpgradesShown);
        Assert.False(vm.HoneySuperShown);
        vm.BuyWaxTrayCommand.Execute(null);
        Assert.Equal(400m, vm.Beebits);   // the Wax Tray stays on Beebits
        Assert.Equal(1, vm.WaxTrays);

        vm.DebugSummonCarpenterBee();
        vm.DebugGiveWood(30m);
        Assert.True(vm.HoneySuperShown);
        Assert.Equal(10m, vm.HoneySuperCost);
        vm.BuyHoneySuperCommand.Execute(null);
        Assert.Equal(1, vm.HoneySupers);
        Assert.Equal(15m, vm.HoneySuperCost);
        Assert.Equal(20m, vm.Wood);
        Assert.Equal(400m, vm.Beebits);
        Assert.Equal(1200m, vm.HoneyStorage);
        Assert.True(Logged(vm, BeekeeperEvents.HoneySuperBought));
    }

    [Fact]
    public void CandlePrices_FollowTheRack_AndTheMoldsMakeTwo()
    {
        var vm = Make(new BeekeeperState { CarpenterBeeCame = true, Wood = 100m, WoodRevealed = true, ShopRevealed = true, BearName = "Bruno" });
        Assert.Equal(2m, vm.HerbalCandleWaxNow);
        Assert.Equal(1, vm.CandlesPerCraft);
        Assert.Contains(vm.ShopUpgrades, u => u.Id == BeekeeperUpgrades.DippingRack);
        vm.BuyUpgrade(BeekeeperUpgrades.DippingRack);
        vm.BuyUpgrade(BeekeeperUpgrades.CandleMolds);
        Assert.Equal(1m, vm.HerbalCandleWaxNow);   // Bee, 2026-11-11: 2 wax, and the rack takes it to 1
        Assert.Equal(10m, vm.BeeBoostCandleWaxNow);
        Assert.Equal(10m, vm.SagePropolisCandleWaxNow);
        Assert.Equal(2, vm.CandlesPerCraft);
        Assert.Equal(30m, vm.Wood);
        Assert.Equal(50m, vm.UpgradeBonusPercent(BeekeeperUpgrades.DippingRack));
        Assert.False(vm.CandleIsWall(vm.HerbalCandleWaxNow));
    }

    [Fact]
    public void TheMeadow_IsOfferedWithItsCounts_AndBoughtThroughTheCommand()
    {
        var vm = Make(Garden((BeekeeperPlants.Wildflowers, 23), (BeekeeperPlants.Clover, 1)));
        Assert.True(vm.MeadowOffered);
        Assert.Equal((23, 50, 1, 50), (vm.MeadowWildflowersHave, vm.MeadowWildflowersNeed, vm.MeadowCloverHave, vm.MeadowCloverNeed));
        Assert.False(vm.BuyMeadowCommand.CanExecute(null));

        vm.DebugPlantMeadowPrice();
        Assert.True(vm.CanBuyMeadow);
        vm.BuyMeadowCommand.Execute(null);
        Assert.True(vm.HasMeadow);
        Assert.False(vm.MeadowOffered);
        Assert.True(Logged(vm, BeekeeperEvents.MeadowBought));
        Assert.Contains(Row(vm, BeekeeperHiveRows.Honey).Sources!, x => x.Id == "meadow" && x.PerSecond == 5m);
        Assert.Equal(200m + 25_000m, vm.HoneyStorage);
    }

    [Fact]
    public void TheBeesTab_ListsEveryBee_InTheOrderTheyCame()
    {
        var vm = Make(new BeekeeperState { BearName = "Bruno" });
        Assert.Empty(vm.BeesMet);
        var s = new BeekeeperState
        {
            BearName = "Bruno", HoneyRevealed = true, HasWoodenHive = true, QueenSettled = true, CarpenterBeeCame = true,
            RareBeesMet = { BeekeeperBees.WoolCarder, BeekeeperBees.Mason },
        };
        Assert.Equal(new[] { BeekeeperBees.Honey, BeekeeperBees.Queen, BeekeeperBees.Carpenter, BeekeeperBees.WoolCarder, BeekeeperBees.Mason },
            Make(s).BeesMet);
    }

    [Fact]
    public void TheDebugCommands_ReachTheHotel_AndTheWelcomeBackTellsWoodAndGifts()
    {
        var vm = Make(new BeekeeperState { BearName = "Bruno", HoneyRevealed = true, ShopRevealed = true });
        vm.DebugUnlockNextSeed();
        Assert.False(Logged(vm, BeekeeperEvents.SeedJoinsRoll));   // Bee, 2026-11-11: no log line
        Assert.Contains(BeekeeperPlants.Wildflowers, vm.State.SeedsGivenIds);
        vm.DebugUnlockEverySeed();
        vm.DebugGiveTenOfEverySeed();
        Assert.Equal(BeekeeperConfig.Default.Plants.Count, vm.SeedRows.Count);
        Assert.All(vm.SeedRows, r => Assert.Equal(10, r.Count));

        vm.DebugSummonCarpenterBee();
        Assert.True(Logged(vm, BeekeeperEvents.CarpenterBee));
        Assert.Contains(BeekeeperBees.Carpenter, vm.BeesMet);
        vm.DebugGiveWood(100m);
        vm.BuyUpgrade(BeekeeperUpgrades.BeeHotel);
        Assert.True(vm.HasBeeHotel);
        Assert.Equal(1800m, vm.HotelSecondsToNext);
        vm.DebugHotelGift();   // the mason bee (the first pick): a seed
        Assert.True(Logged(vm, BeekeeperEvents.RareBeeArrives));
        Assert.Contains(BeekeeperBees.Mason, vm.BeesMet);

        vm.DebugSpendAway(8m * 3600m);
        Assert.True(Logged(vm, BeekeeperEvents.WelcomeBackWood));
        Assert.True(Logged(vm, BeekeeperEvents.WelcomeBackHotel));
        Assert.False(Logged(vm, BeekeeperEvents.HotelGift));   // the later gifts are told in one line
    }

    [Fact]
    public void ReopeningAnOldSave_SproutsItsBed_AndKeepsEverythingElse()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "beekeeper.json");
        var old = new BeekeeperState
        {
            BearName = "Bruno", HoneyRevealed = true, GardenRevealed = true, HoneySupers = 2,
            Plants = { BeekeeperPlants.Wildflowers },
            Beds = { new BeekeeperBed { PlantId = BeekeeperPlants.Willow, SecondsLeft = 3000m } },
        };
        Assert.True(BeekeeperSaveService.Save(old, path, T0));

        var vm = new BeekeeperViewModel(isHeadless: true, persist: true, savePath: path, rng: new NoRandom(), clock: () => T0.AddSeconds(1));
        Assert.Empty(vm.State.Beds);
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Willow }, vm.SproutedPlants.Select(p => p.Id));
        Assert.True(vm.HasCarpenterBee);   // the willow that sprouted brings her
        Assert.True(Logged(vm, BeekeeperEvents.CarpenterBee));
        Assert.Equal(2, vm.HoneySupers);
        vm.Dispose();
    }
}
