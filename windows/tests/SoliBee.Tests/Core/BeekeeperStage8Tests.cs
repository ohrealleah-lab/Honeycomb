using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 8 rules (spec 017): the seed rolls, instant planting, many plants and their
/// bonuses, the carpenter bee and wood, the wood upgrades, the bee hotel, the meadow, live and away.</summary>
public class BeekeeperStage8Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage8-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    /// <summary>Rolls come from queues (then the defaults: a miss, and the first choice). Counts every call.</summary>
    private sealed class Script : IRandomSource
    {
        public readonly Queue<double> Doubles = new();
        public readonly Queue<int> Ints = new();
        public double DefaultDouble = 0.99;
        public int DefaultInt;
        public int DoubleCalls, IntCalls;
        public readonly List<int> IntRanges = new();

        public double NextDouble() { DoubleCalls++; return Doubles.Count > 0 ? Doubles.Dequeue() : DefaultDouble; }

        public int Next(int maxExclusive)
        {
            IntCalls++;
            IntRanges.Add(maxExclusive);
            int v = Ints.Count > 0 ? Ints.Dequeue() : DefaultInt;
            return Math.Clamp(v, 0, maxExclusive - 1);
        }
    }

    private static readonly BeekeeperConfig BigCaps = new() { StartingHoneyCap = 1e12m, StartingWaxCap = 1e12m };

    /// <summary>The candle tests show halving on a 10-wax herbal candle (Bee set it to 1 wax on 2026-11-11).</summary>
    private static readonly BeekeeperConfig TenWax = new() { HerbalCandleWax = 10m };

    private static BeekeeperEngine Make(BeekeeperState? state = null, IRandomSource? rng = null, BeekeeperConfig? config = null)
        => new(config ?? BeekeeperConfig.Default, state, rng ?? new Script());

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    /// <summary>Stage 10: <paramref name="jars"/> is how many trades the shelf allows (a jar each, for
    /// CandlesPerJar beeswax candles); before, it was herbal candles, one trade each.</summary>
    private static BeekeeperState Hippies(long trades, decimal jars = 100m) =>
        new() { HippiesRevealed = true, HippieTrades = trades, BeeswaxCandles = jars * BeekeeperConfig.Default.CandlesPerJar };

    private static List<string> Many(string id, int n) => Enumerable.Repeat(id, n).ToList();

    // ============================================================ plant data (replaces stage 7's grow times)

    [Fact]
    public void PlantsAreData_WithRollPoints_GiversAndBonusTargets()
    {
        var p = BeekeeperConfig.Default.Plants.ToDictionary(x => x.Id);
        Assert.Equal(1, p[BeekeeperPlants.Wildflowers].SeedAtTrade);
        Assert.Equal(40, p[BeekeeperPlants.Bramble].SeedAtTrade);
        Assert.Equal(200, p[BeekeeperPlants.Willow].SeedAtTrade);
        Assert.Equal(400, p[BeekeeperPlants.Clover].SeedAtTrade);
        Assert.Equal(BeekeeperGivers.Wasps, p[BeekeeperPlants.Poplar].Giver);
        Assert.Equal(20, p[BeekeeperPlants.Poplar].SeedAtTrade);
        Assert.Equal(BeekeeperBonusTargets.Honey, p[BeekeeperPlants.Wildflowers].BonusTarget);
        Assert.Equal(BeekeeperBonusTargets.Honey, p[BeekeeperPlants.Bramble].BonusTarget);
        Assert.Equal(BeekeeperBonusTargets.Wax, p[BeekeeperPlants.Clover].BonusTarget);
        Assert.Equal(BeekeeperBonusTargets.Wood, p[BeekeeperPlants.Willow].BonusTarget);
        Assert.Equal(BeekeeperBonusTargets.Propolis, p[BeekeeperPlants.Poplar].BonusTarget);
        Assert.All(p.Values, x => Assert.Equal(0.01m, x.BonusPerExtra));
    }

    // ============================================================ the Hippies' roll (User Story 1)

    [Fact]
    public void AHit_GivesASeed_AndOpensTheGarden()
    {
        var rng = new Script();
        rng.Doubles.Enqueue(0.1);   // under 20%: a hit
        var e = Make(Hippies(0), rng);
        var r = e.TradeTenCandles();
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.SeedGiven && ev.Text == BeekeeperPlants.Wildflowers);
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers }, e.State.SeedsInHand);
        Assert.True(e.State.GardenRevealed);
        Assert.Equal(0m, e.State.Beebits);   // stage 10: the Hippies pay a jar, no Beebits
    }

    [Fact]
    public void AMiss_IsANormalTrade()
    {
        var e = Make(Hippies(10));
        var r = e.TradeTenCandles();
        Assert.True(r.Done);
        Assert.Empty(e.State.SeedsInHand);
        Assert.False(Has(r.Events, BeekeeperEvents.SeedGiven));
        Assert.Equal(BeekeeperConfig.Default.StartingClayJars + 1m, e.State.ClayJars);   // stage 10: a jar (was 10 Beebits)
        Assert.Equal(11, e.State.HippieTrades);
        Assert.False(e.State.GardenRevealed);
    }

    [Fact]
    public void AHit_PicksOnlyFromUnlockedSeeds_EachEquallyLikely()
    {
        var rng = new Script { DefaultDouble = 0.1, DefaultInt = 99 };   // always a hit, always the last choice
        var e = Make(Hippies(100), rng);   // wildflowers and bramble are in; the willow waits for 200
        e.TradeTenCandles();
        Assert.Equal(new[] { BeekeeperPlants.Bramble }, e.State.SeedsInHand);
        Assert.Equal(2, rng.IntRanges.Last());   // two seeds to pick from
    }

    [Fact]
    public void WithNoSeedUnlocked_ThereIsNoRoll()
    {
        var cfg = new BeekeeperConfig
        {
            Plants = new[] { new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperSpecialties.Foraging, 3m) },
        };
        var rng = new Script { DefaultDouble = 0.0 };
        var e = Make(Hippies(0), rng, cfg);
        e.TradeTenCandles();
        Assert.Equal(0, rng.DoubleCalls);
        Assert.Empty(e.State.SeedsInHand);
    }

    [Fact]
    public void TradeAll_RollsOncePerJar_WithOneLogLine()
    {
        var rng = new Script();
        for (int i = 0; i < 30; i++) rng.Doubles.Enqueue(i % 5 == 0 ? 0.1 : 0.9);   // 6 hits in 30
        var e = Make(Hippies(50, jars: 30m), rng);
        var r = e.TradeAllCandles();
        Assert.Equal(80, e.State.HippieTrades);
        Assert.Equal(30, rng.DoubleCalls);
        Assert.Equal(6, e.State.SeedsInHand.Count);
        var line = Assert.Single(r.Events, ev => ev.Key == BeekeeperEvents.SeedsGivenBatch);
        Assert.Equal(6m, line.Value);
        Assert.False(Has(r.Events, BeekeeperEvents.SeedGiven));
    }

    [Fact]
    public void TradeAll_WithOneSeed_NamesIt()
    {
        var rng = new Script();
        rng.Doubles.Enqueue(0.9);
        rng.Doubles.Enqueue(0.1);
        var e = Make(Hippies(10, jars: 3m), rng);
        var r = e.TradeAllCandles();
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.SeedGiven && ev.Text == BeekeeperPlants.Wildflowers);
        Assert.False(Has(r.Events, BeekeeperEvents.SeedsGivenBatch));
    }

    // ============================================================ pacing (User Story 2)

    [Fact]
    public void ASeedJoinsTheRoll_OnItsTrade_AndTheLogSaysSoOnce()
    {
        var rng = new Script { DefaultDouble = 0.1, DefaultInt = 99 };
        var e = Make(Hippies(199, jars: 5m), rng);
        e.State.SeedsGivenIds.AddRange(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble });
        var r = e.TradeTenCandles();   // the 200th
        Assert.Contains(BeekeeperPlants.Willow, e.State.SeedsGivenIds);   // in the roll (no log line since Bee, 2026-11-11)
        Assert.False(Has(r.Events, BeekeeperEvents.SeedJoinsRoll));
        Assert.Equal(new[] { BeekeeperPlants.Willow }, e.State.SeedsInHand);   // that trade already rolls with it
        Assert.Single(e.State.SeedsGivenIds, BeekeeperPlants.Willow);   // listed once
    }

    [Fact]
    public void TheFirstHippieTrade_BringsWildflowersIntoTheRoll()
    {
        var e = Make(Hippies(0));
        var r = e.TradeTenCandles();
        Assert.Contains(BeekeeperPlants.Wildflowers, e.State.SeedsGivenIds);
        Assert.False(Has(r.Events, BeekeeperEvents.SeedJoinsRoll));   // Bee, 2026-11-11: no log line
    }

    [Fact]
    public void AnOlderSavesGivenList_NeverBlocksARoll()
    {
        // A stage 7.5 save: every seed was "given" once already.
        var s = Hippies(450);
        s.SeedsGivenIds.AddRange(BeekeeperConfig.Default.Plants.Select(p => p.Id));
        var rng = new Script { DefaultDouble = 0.1, DefaultInt = 0 };
        var e = Make(s, rng);
        for (int i = 0; i < 3; i++) e.TradeTenCandles();
        Assert.Equal(3, e.State.SeedsInHand.Count);
        Assert.Equal(4, rng.IntRanges.Last());   // wildflowers, bramble, willow and clover (the poplar is the wasps')
    }

    [Fact]
    public void AnOldSavePastTheCounts_HasThemInTheRollOnLoad_WithNoSeedsHandedOut()
    {
        var e = Make(new BeekeeperState { HippieTrades = 400, WaspTrades = 22, EmissaryCome = true });
        var events = e.RevealOnLoad();
        Assert.False(Has(events, BeekeeperEvents.SeedJoinsRoll));   // quietly (Bee, 2026-11-11: no log line)
        Assert.Equal(5, e.State.SeedsGivenIds.Count);
        Assert.Empty(e.State.SeedsInHand);
        Assert.Equal(5, e.UnlockedSeeds.Count);
        Assert.Empty(e.RevealOnLoad().Where(ev => ev.Key == BeekeeperEvents.SeedJoinsRoll));
    }

    [Fact]
    public void TheWasps_RollForThePoplar_FromTheirTwentiethTrade_ABatchRollingOnce()
    {
        var rng = new Script { DefaultDouble = 0.1 };
        var early = Make(new BeekeeperState { EmissaryCome = true, WaspTrades = 5, Honey = 5000m, HoneyRevealed = true }, rng);
        early.TradeForPaper(10);
        Assert.Empty(early.State.SeedsInHand);
        Assert.Equal(0, rng.DoubleCalls);

        var rng2 = new Script { DefaultDouble = 0.1 };
        var e = Make(new BeekeeperState { EmissaryCome = true, WaspTrades = 19, Honey = 5000m, HoneyRevealed = true }, rng2);
        var r = e.TradeForPaper(10);   // the 20th, one trade
        Assert.Equal(1, rng2.DoubleCalls);
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.WaspSeedGiven && ev.Text == BeekeeperPlants.Poplar);
        Assert.Equal(new[] { BeekeeperPlants.Poplar }, e.State.SeedsInHand);
        Assert.True(e.State.GardenRevealed);

        var miss = Make(new BeekeeperState { EmissaryCome = true, WaspTrades = 30, Honey = 5000m, HoneyRevealed = true });
        Assert.False(Has(miss.TradeForPaper().Events, BeekeeperEvents.WaspSeedGiven));
    }

    // ============================================================ planting (User Story 3)

    [Fact]
    public void Planting_IsInstant_AndTheFirstOfAKindIsRevealed()
    {
        var e = Make(new BeekeeperState { SeedsInHand = Many(BeekeeperPlants.Wildflowers, 3), GardenRevealed = true });
        var r = e.PlantSeed(BeekeeperPlants.Wildflowers);
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.SeedPlanted));
        Assert.True(Has(r.Events, BeekeeperEvents.PlantRevealed));
        Assert.Empty(e.State.Beds);
        // Bee, 2026-11-11: the rest of that kind in hand plants itself with the first.
        Assert.Equal(3, e.PlantCount(BeekeeperPlants.Wildflowers));
        Assert.Equal(0, e.SeedCount(BeekeeperPlants.Wildflowers));
        Assert.False(e.CanPlantSeed);
        Assert.False(e.PlantSeed().Done);
        // Before: one at a time (Plants = [wildflowers], 2 seeds left, each planted by hand).
    }

    [Fact]
    public void OnceAKindGrows_ItsSeedsPlantThemselves_FromEveryGiver()
    {
        var rng = new Script { DefaultDouble = 0.1, DefaultInt = 0 };   // every roll a hit, the first choice
        var s = Hippies(10, jars: 3m);
        s.Plants.Add(BeekeeperPlants.Wildflowers);
        var e = Make(s, rng);
        e.TradeAllCandles();
        Assert.Equal(4, e.PlantCount(BeekeeperPlants.Wildflowers));   // three seeds, all planted at once
        Assert.Empty(e.State.SeedsInHand);

        // A kind never planted waits in hand (and its story card asks for it).
        var fresh = Make(Hippies(10), new Script { DefaultDouble = 0.1 });
        fresh.TradeTenCandles();
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers }, fresh.State.SeedsInHand);
        Assert.Empty(fresh.State.Plants);

        // The debug seeds and the mason bee follow the same rule.
        var debug = Make(new BeekeeperState { Plants = { BeekeeperPlants.Bramble } });
        debug.DebugGiveSeedsOfEvery(2);
        Assert.Equal(3, debug.PlantCount(BeekeeperPlants.Bramble));
        Assert.Equal(0, debug.SeedCount(BeekeeperPlants.Bramble));
        Assert.Equal(2, debug.SeedCount(BeekeeperPlants.Clover));
    }

    [Fact]
    public void SeedsOfAGrowingKind_InAnOlderSave_PlantThemselvesOnLoad()
    {
        var e = Make(new BeekeeperState
        {
            Plants = { BeekeeperPlants.Bramble },
            SeedsInHand = { BeekeeperPlants.Bramble, BeekeeperPlants.Clover, BeekeeperPlants.Bramble },
        });
        Assert.Equal(3, e.PlantCount(BeekeeperPlants.Bramble));
        Assert.Equal(new[] { BeekeeperPlants.Clover }, e.State.SeedsInHand);
    }

    [Fact]
    public void ASeedOfANewKind_BringsThePlantItStoryCard_EachTime()
    {
        var e = Make(new BeekeeperState { SeedsInHand = { BeekeeperPlants.Willow, BeekeeperPlants.Clover }, HoneyRevealed = true });
        Assert.Contains(e.AdvanceStoryTime(1m), ev => ev.Key == BeekeeperEvents.StoryArrives && ev.Text == BeekeeperStories.Seed);
        Assert.Equal(BeekeeperStories.Seed, e.StoryHere);
        Assert.Equal(BeekeeperPlants.Willow, e.StorySeed);

        var r = e.PlantFromStory();
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.CarpenterBee));   // planted like any other willow
        Assert.Null(e.StoryHere);
        Assert.DoesNotContain(BeekeeperStories.Seed, e.State.StoriesDone);   // it comes back for the next kind

        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Seed, e.StoryHere);
        Assert.Equal(BeekeeperPlants.Clover, e.StorySeed);
        e.PlantSeed(BeekeeperPlants.Clover);   // planted another way: the card goes
        Assert.Null(e.StoryHere);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
        Assert.False(e.PlantFromStory().Done);
    }

    [Fact]
    public void APlantCountsFromTheMomentItIsPlanted()
    {
        var e = Make(new BeekeeperState { SeedsInHand = { BeekeeperPlants.Wildflowers }, GardenRevealed = true });
        e.Advance(60m);
        Assert.Equal(0m, e.State.Pollen);
        e.PlantSeed();
        e.Advance(60m);
        Assert.Equal(3m, e.State.Pollen);
    }

    [Fact]
    public void ASeedStillGrowingInAnOldSave_SproutsOnLoad()
    {
        var s = new BeekeeperState
        {
            Plants = { BeekeeperPlants.Wildflowers },
            Beds =
            {
                new BeekeeperBed { PlantId = BeekeeperPlants.Willow, SecondsLeft = 3000m },
                new BeekeeperBed { PlantId = "nonsense", SecondsLeft = 10m },
            },
            SeedsInHand = { BeekeeperPlants.Wildflowers, "dandelion", BeekeeperPlants.Wildflowers },
        };
        var e = Make(s);
        Assert.Empty(e.State.Beds);
        // The unknown ones are dropped; wildflowers already grow, so their seeds plant themselves (Bee, 2026-11-11).
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Willow, BeekeeperPlants.Wildflowers, BeekeeperPlants.Wildflowers },
            e.State.Plants);
        Assert.Empty(e.State.SeedsInHand);
        var events = e.RevealOnLoad();
        Assert.True(Has(events, BeekeeperEvents.CarpenterBee));   // the willow that sprouted brings the carpenter bee
        Assert.True(e.State.CarpenterBeeCame);
    }

    // ============================================================ many plants (User Story 4)

    private static BeekeeperState Garden(params (string Id, int Count)[] plants)
    {
        var s = new BeekeeperState { HoneyRevealed = true, GardenRevealed = true };
        foreach (var (id, n) in plants) s.Plants.AddRange(Many(id, n));
        return s;
    }

    [Fact]
    public void Specialties_CountKinds_NotPlants()
    {
        var e = Make(Garden((BeekeeperPlants.Bramble, 2), (BeekeeperPlants.Wildflowers, 3), (BeekeeperPlants.Clover, 2),
            (BeekeeperPlants.Willow, 5), (BeekeeperPlants.Poplar, 4)), config: BeekeeperTestHives.NoBlooms());   // stage 9: no crocus
        Assert.Equal(1.25m, e.GuardingMultiplier);           // not 1.5625
        Assert.Equal(6m, e.ForagingPollenPerMinute);         // wildflowers and clover once each
        Assert.Equal(1.5m, e.NursingMultiplier);
        Assert.Equal(1m, e.ResinPropolisPerMinute);
        Assert.Equal(4, e.Specialties.Count);
    }

    [Fact]
    public void FiftyWildflowers_AddFortyNinePercentHoney_AddedUpWithTheBramble()
    {
        var e = Make(Garden((BeekeeperPlants.Wildflowers, 50)));
        Assert.Equal(1.49m, e.PlantBonus(BeekeeperBonusTargets.Honey));
        Assert.Equal(0.2m * 1.49m, e.HoneyPerSecond);   // one comb × the bonus

        var both = Make(Garden((BeekeeperPlants.Wildflowers, 50), (BeekeeperPlants.Bramble, 3)));
        Assert.Equal(1.51m, both.PlantBonus(BeekeeperBonusTargets.Honey));   // 49% + 2%, added, never multiplied
        Assert.Equal(1.25m * 1.51m, both.HiveMultiplier);
        var sources = both.PlantBonusSources(BeekeeperBonusTargets.Honey);
        Assert.Equal(2, sources.Count);
        Assert.Equal((BeekeeperPlants.Wildflowers, 49, 0.49m), (sources[0].Plant.Id, sources[0].Extra, sources[0].Share));
        Assert.Equal((BeekeeperPlants.Bramble, 2, 0.02m), (sources[1].Plant.Id, sources[1].Extra, sources[1].Share));
        Assert.Empty(both.PlantBonusSources(BeekeeperBonusTargets.Wax));
    }

    [Fact]
    public void OnePlantOfAKind_GivesNoBonus()
    {
        var e = Make(Garden((BeekeeperPlants.Wildflowers, 1), (BeekeeperPlants.Clover, 1), (BeekeeperPlants.Willow, 1), (BeekeeperPlants.Poplar, 1)));
        foreach (var t in new[] { BeekeeperBonusTargets.Honey, BeekeeperBonusTargets.Wax, BeekeeperBonusTargets.Wood, BeekeeperBonusTargets.Propolis })
            Assert.Equal(1m, e.PlantBonus(t));
    }

    [Fact]
    public void Clover_Willows_AndPoplars_AddToWax_Wood_AndPropolis()
    {
        var s = Garden((BeekeeperPlants.Clover, 11), (BeekeeperPlants.Willow, 3), (BeekeeperPlants.Poplar, 6));
        s.CarpenterBeeCame = true;
        var e = Make(s);
        Assert.Equal(1.10m, e.PlantBonus(BeekeeperBonusTargets.Wax));
        Assert.Equal(0.005m * 1.10m, e.WaxPerSecondNow);
        Assert.Equal(1.02m, e.WoodPerMinuteNow);
        Assert.Equal(1.05m, e.PropolisPerMinute);
        e.Advance(60m);
        Assert.Equal(1.05m, e.State.Propolis);
        Assert.Equal(1.02m, e.State.Wood);
    }

    // ============================================================ the carpenter bee and wood (User Story 5)

    [Fact]
    public void TheFirstWillow_BringsTheCarpenterBee_Once()
    {
        var e = Make(new BeekeeperState { SeedsInHand = Many(BeekeeperPlants.Willow, 2), GardenRevealed = true, HoneyRevealed = true });
        Assert.False(e.WoodShown);
        var r = e.PlantSeed(BeekeeperPlants.Willow);
        Assert.True(Has(r.Events, BeekeeperEvents.CarpenterBee));
        Assert.True(e.State.CarpenterBeeCame);
        Assert.True(e.WoodShown);
        Assert.False(Has(e.PlantSeed(BeekeeperPlants.Willow).Events, BeekeeperEvents.CarpenterBee));
    }

    [Fact]
    public void Wood_IsAStraightLineInTime_WithNoCap_AndNoneWithoutTheBee()
    {
        var none = Make(Garden((BeekeeperPlants.Willow, 1)));
        none.Advance(600m);
        Assert.Equal(0m, none.State.Wood);

        var s = Garden((BeekeeperPlants.Willow, 1));
        s.CarpenterBeeCame = true;
        var e = Make(s);
        e.Advance(59m);
        Assert.False(e.WoodSeen);
        e.Advance(1m);
        Assert.Equal(1m, e.State.Wood);
        Assert.True(e.WoodSeen && e.State.WoodRevealed);
        e.AdvanceAway(3m * 24m * 3600m);
        Assert.Equal(1m + 3m * 24m * 60m, e.State.Wood);   // three days, no cap
    }

    // ============================================================ wood prices and the Honey Super (User Story 6)

    private static BeekeeperState Woodshop(decimal wood = 1000m)
    {
        var s = new BeekeeperState
        {
            HoneyRevealed = true, ShopRevealed = true, WorkbenchRevealed = true, CombsRevealed = true,
            CarpenterBeeCame = true, Wood = wood, WoodRevealed = true, Beebits = 1000m,
            RepellentUnlocked = true, Herbs = 100m, Wax = 1000m, Propolis = 100m, Plants = { BeekeeperPlants.Poplar },
        };
        return s;
    }

    [Fact]
    public void TheWoodUpgrades_ShowWithTheFirstWood_AndCostWood()
    {
        var before = Make(new BeekeeperState { ShopRevealed = true, WorkbenchRevealed = true, Wood = 500m, WoodRevealed = true });
        Assert.DoesNotContain(before.ShopUpgrades, u => u.Wood > 0m);   // no carpenter bee yet

        var e = Make(Woodshop(wood: 220m));
        var ids = e.ShopUpgrades.Where(u => u.Wood > 0m).Select(u => u.Id).ToList();
        Assert.Equal(new[] { BeekeeperUpgrades.WoodenFrames, BeekeeperUpgrades.CandleMolds, BeekeeperUpgrades.DippingRack, BeekeeperUpgrades.BeeHotel }, ids);
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.WoodenFrames).Done);
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.CandleMolds).Done);
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.DippingRack).Done);
        Assert.Equal(100m, e.State.Wood);
        Assert.Equal(1000m, e.State.Beebits);   // wood only
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.BeeHotel).Done);
        Assert.Equal(0m, e.State.Wood);
        Assert.Empty(e.ShopUpgrades.Where(u => u.Wood > 0m));
    }

    [Fact]
    public void HoneySupers_CostWood_AndNoBeebits_HiddenBeforeTheCarpenterBee()
    {
        var early = Make(new BeekeeperState { ShopRevealed = true, CombsRevealed = true, Beebits = 10_000m });
        Assert.True(early.CapacityUpgradesShown);   // the Wax Tray still shows
        Assert.False(early.HoneySuperShown);
        Assert.False(early.BuyHoneySuper().Done);
        Assert.True(early.BuyWaxTray().Done);       // the Wax Tray stays on Beebits
        Assert.Equal(10_000m - 100m, early.State.Beebits);

        var e = Make(Woodshop(wood: 80m));
        Assert.True(e.HoneySuperShown);
        var prices = new List<decimal>();
        for (int i = 0; i < 4; i++)
        {
            prices.Add(e.HoneySuperCost);
            var r = e.BuyHoneySuper();
            Assert.True(r.Done);
            Assert.Contains(r.Events, x => x.Key == BeekeeperEvents.HoneySuperBought && x.Value == i + 1);
        }
        Assert.Equal(new[] { 10m, 15m, 22m, 33m }, prices);   // +50%, rounded down
        Assert.Equal(0m, e.State.Wood);
        Assert.Equal(1000m, e.State.Beebits);
        Assert.Equal(200m + 4000m, e.HoneyStorage);
        Assert.False(e.BuyHoneySuper().Done);
    }

    [Fact]
    public void HoneySupersBoughtWithBeebits_StayOwned()
    {
        var e = Make(new BeekeeperState { HoneySupers = 3 });
        Assert.Equal(200m + 3000m, e.HoneyStorage);
        Assert.Equal(33m, e.HoneySuperCost);   // the next one is priced from the level held (10 × 1.5³)
    }

    [Fact]
    public void WoodenFrames_HalveTheCombsWax_RoundedDown_AndNothingElse()
    {
        var s = Woodshop();
        s.Combs = 5;   // four bought: 5 × 1.25⁴ = 12.2 → 12
        var e = Make(s);
        Assert.Equal(12m, e.CombCost);
        decimal bees = e.CombBeeCost;
        e.BuyUpgrade(BeekeeperUpgrades.WoodenFrames);
        Assert.Equal(6m, e.CombCost);
        Assert.Equal(bees, e.CombBeeCost);
        Assert.Equal(e.Config.HerbalCandleWax, e.HerbalCandleWaxNow);
        Assert.Equal(1, e.CandlesPerCraft);
        Assert.Equal(2m, Make(new BeekeeperState { Upgrades = { BeekeeperUpgrades.WoodenFrames } }).CombCost);   // 5 → 2
    }

    [Fact]
    public void CandleMolds_MakeTwoCandlesACraft_ForEveryKind()
    {
        var e = Make(Woodshop());
        e.BuyUpgrade(BeekeeperUpgrades.CandleMolds);
        Assert.Equal(2, e.CraftRepellent().Amount);
        Assert.Equal(2m, e.State.RepellentCandles);
        Assert.Equal(1000m - e.Config.HerbalCandleWax, e.State.Wax);
        Assert.Equal(99m, e.State.Herbs);
        e.CraftBeeBoost();
        e.CraftSagePropolis();
        Assert.Equal(2m, e.State.BeeBoostCandles);
        Assert.Equal(2m, e.State.SagePropolisCandles);
        Assert.Equal(6, e.State.CandlesCrafted);
        Assert.Equal(10m, e.CombCost * 2m);   // combs untouched
    }

    [Fact]
    public void TheDippingRack_HalvesEveryCandlesWax_AndNothingElse()
    {
        var e = Make(Woodshop(), config: TenWax);
        e.BuyUpgrade(BeekeeperUpgrades.DippingRack);
        Assert.Equal(5m, e.HerbalCandleWaxNow);
        Assert.Equal(10m, e.BeeBoostCandleWaxNow);
        Assert.Equal(10m, e.SagePropolisCandleWaxNow);
        Assert.Equal(7m, e.CandleWax(15m));   // rounded down
        Assert.Equal(5m, e.CombCost);         // combs untouched
        e.CraftBeeBoost();
        Assert.Equal(990m, e.State.Wax);
        Assert.Equal(98m, e.State.Propolis);  // other parts of the price don't change
        Assert.Equal(1m, e.State.BeeBoostCandles);
    }

    [Fact]
    public void MoldsAndRackTogether_AndTheBatchesUseThePriceOfTheMoment()
    {
        var s = Woodshop();
        s.Wax = 55m;
        s.Herbs = 11m;
        var e = Make(s, config: TenWax);
        Assert.False(e.CanCraftRepellentTimes(10));   // 100 wax at the old price
        e.BuyUpgrade(BeekeeperUpgrades.CandleMolds);
        e.BuyUpgrade(BeekeeperUpgrades.DippingRack);
        Assert.True(e.CanCraftRepellentTimes(10));    // 50 wax and 10 herbs now
        Assert.False(e.CanCraftRepellentTimes(100));
        var r = e.CraftRepellent();
        Assert.Equal(2, r.Amount);
        Assert.Equal(50m, e.State.Wax);
        Assert.Equal(10m, e.State.Herbs);
        var batch = e.CraftRepellent(10);
        Assert.Equal(20, batch.Amount);
        Assert.Contains(batch.Events, ev => ev.Key == BeekeeperEvents.Crafted && ev.Value == 20m);
        Assert.Equal(0m, e.State.Wax);
        Assert.Equal(22m, e.State.RepellentCandles);
    }

    // ============================================================ the bee hotel (User Story 7)

    private static BeekeeperState Hotel()
    {
        var s = Woodshop(wood: 0m);
        s.Upgrades.Add(BeekeeperUpgrades.BeeHotel);
        s.HotelSecondsToNext = 1800m;
        s.HippieTrades = 50;   // wildflowers and bramble are in the roll
        s.Herbs = 0m;
        s.Propolis = 0m;
        s.Plants.Clear();   // no poplar: propolis only from the wool carder
        return s;
    }

    [Fact]
    public void BuyingTheHotel_StartsItsTimer()
    {
        var e = Make(Woodshop(wood: 100m));
        e.BuyUpgrade(BeekeeperUpgrades.BeeHotel);
        Assert.True(e.HasBeeHotel);
        Assert.Equal(1800m, e.State.HotelSecondsToNext);
    }

    [Fact]
    public void AGiftComesEveryThirtyMinutes_TheFirstFromEachBeeIsANewBee()
    {
        var rng = new Script();
        rng.Ints.Enqueue(1);   // the leafcutter
        rng.Ints.Enqueue(1);   // the leafcutter again
        rng.Ints.Enqueue(2);   // the wool carder
        var e = Make(Hotel(), rng);
        Assert.Empty(e.Advance(1799m).Events.Where(ev => ev.Key is BeekeeperEvents.RareBeeArrives or BeekeeperEvents.HotelGift));
        var r = e.Advance(1m);
        var first = Assert.Single(r.Events, ev => ev.Key == BeekeeperEvents.RareBeeArrives);
        Assert.Equal(2m, first.Value);
        Assert.Equal(new BeekeeperEngine.GiftParts(BeekeeperBees.Leafcutter, BeekeeperGifts.Herbs, null), BeekeeperEngine.ParseGiftText(first.Text));
        Assert.Equal(2m, e.State.Herbs);
        Assert.Equal(new[] { BeekeeperBees.Leafcutter }, e.State.RareBeesMet);
        Assert.Equal(1800m, e.State.HotelSecondsToNext);

        r = e.Advance(1800m);
        Assert.True(Has(r.Events, BeekeeperEvents.HotelGift));
        Assert.Equal(4m, e.State.Herbs);
        r = e.Advance(1800m);
        Assert.True(Has(r.Events, BeekeeperEvents.RareBeeArrives));
        Assert.Equal(5m, e.State.Propolis);
        Assert.Equal(new[] { BeekeeperBees.Leafcutter, BeekeeperBees.WoolCarder }, e.State.RareBeesMet);
    }

    [Fact]
    public void TheMasonBee_BringsAnUnlockedSeed_OrHerbsWhenThereIsNone()
    {
        var rng = new Script();
        rng.Ints.Enqueue(0);   // the mason bee
        rng.Ints.Enqueue(1);   // the second unlocked seed: bramble
        var e = Make(Hotel(), rng);
        var r = e.Advance(1800m);
        var gift = Assert.Single(r.Events, ev => ev.Key == BeekeeperEvents.RareBeeArrives);
        Assert.Equal(BeekeeperPlants.Bramble, BeekeeperEngine.ParseGiftText(gift.Text).Plant);
        Assert.Equal(new[] { BeekeeperPlants.Bramble }, e.State.SeedsInHand);
        Assert.True(e.State.GardenRevealed);

        var s = Hotel();
        s.HippieTrades = 0;
        var none = Make(s, new Script());   // always the mason bee; nothing in a roll yet
        var n = none.Advance(1800m);
        Assert.Equal(BeekeeperGifts.Herbs, BeekeeperEngine.ParseGiftText(n.Events.Single(ev => ev.Key == BeekeeperEvents.RareBeeArrives).Text).Gift);
        Assert.Equal(2m, none.State.Herbs);
        Assert.Empty(none.State.SeedsInHand);
    }

    [Fact]
    public void HotelGifts_CountOnlyTime_LiveOrAway_ShortOrLong()
    {
        var rng = new Script { DefaultInt = 1 };   // the leafcutter every time
        var live = Make(Hotel(), rng);
        for (int i = 0; i < 5400; i++) live.Advance(1m);
        var away = Make(Hotel(), new Script { DefaultInt = 1 });
        var r = away.AdvanceAway(5400m);
        var parts = Make(Hotel(), new Script { DefaultInt = 1 });
        foreach (var st in new[] { 700m, 1100m, 0.5m, 1999.5m, 1600m }) parts.AdvanceAway(st);

        Assert.Equal(6m, live.State.Herbs);   // three gifts
        Assert.Equal(6m, away.State.Herbs);
        Assert.Equal(6m, parts.State.Herbs);
        Assert.Equal(live.State.HotelSecondsToNext, away.State.HotelSecondsToNext);
        Assert.Equal(live.State.HotelSecondsToNext, parts.State.HotelSecondsToNext);
        var welcome = Assert.Single(r.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBackHotel);
        Assert.Equal(6m, welcome.Value2);    // herbs
        Assert.Equal(0m, welcome.Value);     // seeds
        Assert.Equal("0", welcome.Text);     // propolis
        Assert.False(Has(r.Events, BeekeeperEvents.HotelGift));   // told in the welcome-back instead
        Assert.True(Has(r.Events, BeekeeperEvents.RareBeeArrives));   // a new bee keeps its own line
    }

    [Fact]
    public void WithoutTheHotel_NoGiftsCome()
    {
        var s = Hotel();
        s.Upgrades.Remove(BeekeeperUpgrades.BeeHotel);
        var e = Make(s);
        e.AdvanceAway(10_000m);
        Assert.Empty(e.State.RareBeesMet);
        Assert.Equal(0m, e.State.Herbs);
    }

    // ============================================================ the meadow (User Story 8)

    [Fact]
    public void TheMeadow_IsOfferedAfterOneOfEach_AndCostsFiftyOfEach()
    {
        Assert.False(Make(Garden((BeekeeperPlants.Wildflowers, 60))).MeadowOffered);
        var e = Make(Garden((BeekeeperPlants.Wildflowers, 49), (BeekeeperPlants.Clover, 50)));
        Assert.True(e.MeadowOffered);
        Assert.False(e.CanBuyMeadow);
        Assert.False(e.BuyMeadow().Done);
        e.State.Plants.Add(BeekeeperPlants.Wildflowers);
        Assert.True(e.CanBuyMeadow);
        var r = e.BuyMeadow();
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.MeadowBought));
        Assert.True(e.State.HasMeadow);
        Assert.False(e.MeadowOffered);
        Assert.Equal(100, e.State.Plants.Count);   // the plants move in and keep working
        Assert.Equal(6m, e.ForagingPollenPerMinute);
    }

    [Fact]
    public void TheMeadow_MakesHoney_AndRaisesBothCaps_WithEveryBoostOnIt()
    {
        var s = Garden((BeekeeperPlants.Wildflowers, 50), (BeekeeperPlants.Clover, 50));
        s.HasWoodenHive = true;
        var e = Make(s);
        decimal before = e.HoneyPerSecond, honeyCap = e.HoneyStorage, waxCap = e.WaxStorage;
        e.BuyMeadow();
        Assert.Equal(5m * e.HiveMultiplier, e.HoneyPerSecond - before);
        Assert.Equal(1.25m * 1.49m, e.HiveMultiplier);
        Assert.Equal(25_000m, e.HoneyStorage - honeyCap);
        Assert.Equal(250m, e.WaxStorage - waxCap);

        var tech = Make(new BeekeeperState { HasMeadow = true, Upgrades = { BeekeeperUpgrades.BiggerCombs1 } });
        Assert.Equal((200m + 25_000m) * 1.5m, tech.HoneyStorage);   // before the Technologies
        Assert.Equal((20m + 250m) * 1.5m, tech.WaxStorage);
        Assert.Equal(0m, tech.HoneyPerSecond);   // no bee caught yet: no honey, meadow or not
    }

    // ============================================================ live and away (User Story 10)

    /// <summary>Everything at once: the meadow, plant bonuses on every resource, the carpenter bee,
    /// the hotel (gifts part-way), the queen running out of bee bread and a sage candle burning out.</summary>
    private static BeekeeperState Busy()
    {
        var s = Garden((BeekeeperPlants.Wildflowers, 52), (BeekeeperPlants.Clover, 55), (BeekeeperPlants.Bramble, 4),
            (BeekeeperPlants.Willow, 7), (BeekeeperPlants.Poplar, 3));
        s.HasMeadow = true;
        s.CarpenterBeeCame = true;
        s.Combs = 6;
        s.Bees = 300m;
        s.HasWaxCatcher = true;
        s.HasWoodenHive = true;
        s.QueenSettled = true;
        s.BeeBread = 3m;
        s.BeeBreadRevealed = true;
        s.SagePropolisSecondsLeft = 700m;
        s.Upgrades.Add(BeekeeperUpgrades.BeeHotel);
        s.HotelSecondsToNext = 1000m;
        s.HippieTrades = 500;
        return s;
    }

    private static void AssertSame(BeekeeperEngine live, BeekeeperEngine away)
    {
        Assert.Equal(Math.Round(away.State.Honey, 10), Math.Round(live.State.Honey, 10));
        Assert.Equal(Math.Round(away.State.Wax, 12), Math.Round(live.State.Wax, 12));
        Assert.Equal(Math.Round(away.State.Wood, 10), Math.Round(live.State.Wood, 10));
        Assert.Equal(Math.Round(away.State.Propolis, 10), Math.Round(live.State.Propolis, 10));
        Assert.Equal(Math.Round(away.State.Pollen, 10), Math.Round(live.State.Pollen, 10));
        Assert.Equal(Math.Round(away.State.Bees, 10), Math.Round(live.State.Bees, 10));
        Assert.Equal(away.State.Herbs, live.State.Herbs);
        Assert.Equal(away.State.SeedsInHand.Count, live.State.SeedsInHand.Count);
        Assert.Equal(away.State.HotelSecondsToNext, live.State.HotelSecondsToNext);
        Assert.Equal(away.State.RareBeesMet, live.State.RareBeesMet);
        Assert.Equal(away.State.SagePropolisSecondsLeft, live.State.SagePropolisSecondsLeft);
    }

    [Fact]
    public void LiveAndAway_Agree_WithWood_PlantBonuses_TheMeadow_AndHotelGifts()
    {
        var live = Make(Busy(), new Script { DefaultInt = 2 }, BigCaps);   // the wool carder each time
        for (int i = 0; i < 4000; i++) live.Advance(1m);
        var away = Make(Busy(), new Script { DefaultInt = 2 }, BigCaps);
        away.AdvanceAway(4000m);

        AssertSame(live, away);
        Assert.Equal(0m, away.State.BeeBread);                       // the pantry ran out
        Assert.Equal(0m, away.State.SagePropolisSecondsLeft);        // the candle burned out
        Assert.Equal(new[] { BeekeeperBees.WoolCarder }, away.State.RareBeesMet);
        Assert.Equal(1.06m * 4000m / 60m, away.State.Wood, 10);     // 7 willows: +6%
        Assert.True(away.State.Honey > 0m && away.State.Propolis > 10m);
    }

    [Fact]
    public void LiveAndAway_Agree_WithBothCapsReachedPartWay_AndOddSteps()
    {
        var cfg = new BeekeeperConfig { StartingHoneyCap = 100m, StartingWaxCap = 5m };
        var live = Make(Busy(), new Script { DefaultInt = 1 }, cfg);
        decimal[] steps = { 7m, 333m, 60m, 1m, 599m, 1000m, 0.5m, 999.5m, 2000m };
        foreach (var st in steps) live.Advance(st);
        var away = Make(Busy(), new Script { DefaultInt = 1 }, cfg);
        away.AdvanceAway(steps.Sum());
        AssertSame(live, away);
        Assert.Equal(away.HoneyStorage, away.State.Honey);
        Assert.Equal(away.WaxStorage, away.State.Wax);
    }

    [Fact]
    public void TheWelcomeBack_TellsWoodAndTheHotelsGifts()
    {
        var e = Make(Busy(), new Script { DefaultInt = 0 });   // the mason bee: seeds
        var r = e.AdvanceAway(2m * 3600m);
        Assert.Contains(r.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBackWood && ev.Value == Math.Floor(1.06m * 120m));
        var hotel = Assert.Single(r.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBackHotel);
        Assert.Equal(4m, hotel.Value);   // at 1,000 s, then every 30 minutes: 4 seeds in two hours
        // Every kind already grows in this hive, so the seeds planted themselves (Bee, 2026-11-11).
        Assert.Empty(e.State.SeedsInHand);
        Assert.Equal(52 + 4, e.PlantCount(BeekeeperPlants.Wildflowers));   // the mason bee's first choice
    }

    // ============================================================ saving (FR-814)

    [Fact]
    public void AnOlderSave_WithNoStage8Fields_Loads()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "old.json");
        File.WriteAllText(path, "{\"Version\":8,\"Bees\":5,\"HoneyRevealed\":true,\"HoneySupers\":2,\"Plants\":[\"wildflowers\"],"
            + "\"Beds\":[{\"PlantId\":\"bramble\",\"SecondsLeft\":120}],\"Log\":[]}");
        var s = BeekeeperSaveService.Load(path);
        Assert.NotNull(s);
        Assert.Equal(0m, s!.Wood);
        Assert.False(s.CarpenterBeeCame || s.HasMeadow || s.WoodRevealed);
        Assert.Empty(s.RareBeesMet);
        var e = Make(s);
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble }, e.State.Plants);
        Assert.Equal(2, e.State.HoneySupers);
    }

    [Fact]
    public void Stage8Fields_SurviveASave()
    {
        var path = Path.Combine(_dir, "v8.json");
        var s = new BeekeeperState
        {
            Wood = 12.5m, WoodRevealed = true, CarpenterBeeCame = true, HotelSecondsToNext = 99m, HasMeadow = true,
            RareBeesMet = { BeekeeperBees.WoolCarder, BeekeeperBees.Mason },
            Plants = Many(BeekeeperPlants.Clover, 3), SeedsInHand = Many(BeekeeperPlants.Bramble, 4),
        };
        Assert.True(BeekeeperSaveService.Save(s, path, DateTime.UtcNow));
        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(12.5m, back.Wood);
        Assert.True(back.WoodRevealed && back.CarpenterBeeCame && back.HasMeadow);
        Assert.Equal(99m, back.HotelSecondsToNext);
        Assert.Equal(s.RareBeesMet, back.RareBeesMet);
        Assert.Equal(3, back.Plants.Count);
        Assert.Equal(4, back.SeedsInHand.Count);
    }

    [Theory]
    [InlineData("\"Wood\":-1")]
    [InlineData("\"HotelSecondsToNext\":-5")]
    [InlineData("\"RareBeesMet\":null")]
    public void NegativeStage8Numbers_AreRefused(string field)
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "bad.json");
        File.WriteAllText(path, "{\"Version\":8," + field + "}");
        Assert.Null(BeekeeperSaveService.Load(path));
    }

    // ============================================================ debug helpers (FR-817)

    [Fact]
    public void TheDebugHelpers_UnlockSeeds_GiveSeedsPlantsWood_AndCallTheBees()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true });
        Assert.Empty(e.DebugUnlockNextSeed());   // quietly (Bee, 2026-11-11)
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers }, e.UnlockedSeeds.Select(p => p.Id));
        e.DebugUnlockEverySeed();
        Assert.Equal(BeekeeperConfig.Default.Plants.Count, e.UnlockedSeeds.Count);
        Assert.Empty(e.DebugUnlockNextSeed());

        e.DebugGiveSeedsOfEvery(10);
        Assert.Equal(10 * BeekeeperConfig.Default.Plants.Count, e.State.SeedsInHand.Count);
        Assert.True(e.State.GardenRevealed);

        e.DebugPlant(BeekeeperPlants.Wildflowers, 50);
        e.DebugPlant(BeekeeperPlants.Clover, 50);
        Assert.True(e.CanBuyMeadow);

        Assert.Empty(e.DebugHotelGift());   // no hotel yet
        Assert.True(Has(e.DebugSummonCarpenterBee(), BeekeeperEvents.CarpenterBee));
        Assert.Empty(e.DebugSummonCarpenterBee());
        e.DebugGiveWood(100m);
        Assert.True(e.WoodSeen);
        Assert.True(e.BuyUpgrade(BeekeeperUpgrades.BeeHotel).Done);
        var gift = e.DebugHotelGift();
        Assert.True(Has(gift, BeekeeperEvents.RareBeeArrives));
        Assert.Equal(1800m, e.State.HotelSecondsToNext);   // its timer is untouched
    }
}
