using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Regression tests for the fixes from the 2026-11-15 "code review by attack" of the Beekeeper engine:
/// time away paying the same honey as live play, the first wasp's Engage choice, the Hippies' Trade-all on a huge
/// stack, craft counts that overflowed, saves refused for one unknown story id, and the smaller items.</summary>
public class BeekeeperAttackReviewTests : IDisposable
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;   // never stung, a shoe always misses, no lucky rolls
        public int Next(int maxExclusive) => 0;
    }

    private sealed class LowRandom : IRandomSource
    {
        public double NextDouble() => 0.0;    // a shoe always hits
        public int Next(int maxExclusive) => 0;
    }

    private sealed class SeededRandom : IRandomSource
    {
        private readonly Random _r;
        public SeededRandom(int seed) => _r = new Random(seed);
        public double NextDouble() => _r.NextDouble();
        public int Next(int maxExclusive) => _r.Next(maxExclusive);
    }

    private static readonly BeekeeperConfig Cfg = new() { StartingHoneyCap = 1_000_000m, StartingWaxCap = 1_000_000m };

    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-attack-review-" + Guid.NewGuid().ToString("N"));

    public BeekeeperAttackReviewTests() => Directory.CreateDirectory(_dir);

    public void Dispose()
    {
        try { Directory.Delete(_dir, recursive: true); } catch { }
    }

    private static BeekeeperEngine Make(BeekeeperState s, BeekeeperConfig? c = null, IRandomSource? rng = null) =>
        new(c ?? Cfg, s, rng ?? new NoRandom());

    /// <summary>A started hive at The Workbench with no story due.</summary>
    private static BeekeeperState Hive(Action<BeekeeperState>? tweak = null)
    {
        var s = new BeekeeperState
        {
            Version = BeekeeperSaveService.CurrentVersion, HoneyRevealed = true, BearName = "Bruno",
            StartingJarsGiven = true, Combs = 3, WorkbenchRevealed = true, CombsRevealed = true, ShopRevealed = true,
            StoriesDone = { BeekeeperStories.Opening },
        };
        tweak?.Invoke(s);
        return s;
    }

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    private BeekeeperState? SaveAndLoad(BeekeeperState state)
    {
        string path = Path.Combine(_dir, Guid.NewGuid().ToString("N") + ".json");
        Assert.True(BeekeeperSaveService.Save(state, path, DateTime.UtcNow));
        return BeekeeperSaveService.Load(path);
    }

    // ============================================================ 1. time away pays the same honey as live play

    [Theory]
    [InlineData(1_000, 5_000, 3_600)]       // well under the free bees' cap
    [InlineData(50_000, 50_000, 86_400)]    // the review's repro: a day, crossing the cap (125,000 bees)
    [InlineData(123_000, 50, 3_600)]        // crossing the cap part-way through the hour
    [InlineData(1_000, 5, 3_600)]           // the pantry runs out after 500 s
    [InlineData(200_000, 100, 600)]         // already past the cap
    [InlineData(0, 100, 3_600)]             // from no free bees
    public void TimeAway_PaysTheSameHoneyAsLivePlay_WhileTheQueenLays(int bees, int bread, int seconds)
    {
        // The free bees' bonus is on here (the shared test default turns it off).
        var cfg = new BeekeeperConfig
        {
            StartingHoneyCap = 1e15m, StartingWaxCap = 1e15m, FreeBeeHoneyBonusPer100 = 0.0002m,
        };
        BeekeeperState Mk() => Hive(s =>
        {
            s.Combs = 20; s.HasWoodenHive = true; s.QueenSettled = true; s.Bees = bees; s.BeeBread = bread;
        });
        var live = Make(Mk(), cfg);
        var away = Make(Mk(), cfg);
        Assert.True(live.IsQueenLaying || bread == 0);

        for (int i = 0; i < seconds; i++) live.Advance(1m);
        away.AdvanceAway(seconds);

        Assert.Equal(live.State.Bees, away.State.Bees, 9);
        decimal tolerance = 1e-12m * Math.Max(1m, away.State.Honey);
        Assert.True(Math.Abs(live.State.Honey - away.State.Honey) <= tolerance,
            $"live {live.State.Honey} vs away {away.State.Honey}");
        Assert.True(Math.Abs(live.State.Wax - away.State.Wax) <= 1e-12m * Math.Max(1m, away.State.Wax));
    }

    [Fact]
    public void TheFreeBeesBonus_FollowsTheBeesAsTheyGrow_NotTheEndOfTheStretch()
    {
        // 0 → 3,600 bees in an hour at 60 a minute: the bonus rises in a straight line from 0 to 0.0072,
        // so the hour averages half of it.
        var cfg = new BeekeeperConfig { StartingHoneyCap = 1e15m, StartingWaxCap = 1e15m, FreeBeeHoneyBonusPer100 = 0.0002m };
        var e = Make(Hive(s => { s.Combs = 5; s.HasWoodenHive = true; s.QueenSettled = true; s.BeeBread = 1_000m; }), cfg);
        decimal before = e.HiveMultiplier / e.FreeBeeHoneyFactor;   // the other lasting boosts (wooden hive)
        decimal rate = e.BaseHoneyPerSecond;
        e.AdvanceAway(3_600m);
        Assert.Equal(3_600m, e.State.Bees);
        Assert.Equal(rate * before * 3_600m * (1m + 0.0072m / 2m), e.State.Honey, 10);
    }

    [Fact]
    public void WithNoQueen_TheHoneyIsUnchanged_LiveOrAway()
    {
        var cfg = new BeekeeperConfig { StartingHoneyCap = 1e15m, StartingWaxCap = 1e15m, FreeBeeHoneyBonusPer100 = 0.0002m };
        var e = Make(Hive(s => { s.Combs = 5; s.Bees = 10_000m; }), cfg);
        decimal perSecond = e.HoneyPerSecond;
        e.AdvanceAway(1_000m);
        Assert.Equal(perSecond * 1_000m, e.State.Honey);
    }

    // ============================================================ 2. the first wasp's Engage choice

    [Fact]
    public void AWaspThatDriftsOffUnanswered_DoesNotUseUpTheFirstVisit()
    {
        var e = Make(Hive(s => s.Honey = 100m));
        e.DebugCallWasp();
        Assert.True(e.CanEngageWasp);
        Assert.True(Has(e.WaspLeaves(), BeekeeperEvents.WaspLeft));   // stepped away, went idle or slept
        Assert.Equal(0, e.State.WaspVisits);

        e.DebugCallWasp();
        Assert.True(e.WaspFirstVisit);
        Assert.True(e.CanEngageWasp);
    }

    [Fact]
    public void AWaspAtTheDoorWhenTheAppCloses_DoesNotUseUpTheFirstVisit()
    {
        var e = Make(Hive(s => s.Honey = 100m));
        e.DebugCallWasp();
        Assert.True(e.WaspApproaching);

        var loaded = SaveAndLoad(e.State);   // the countdown is never saved: the wasp is simply gone
        Assert.NotNull(loaded);
        var back = Make(loaded!);
        Assert.False(back.WaspApproaching);
        back.DebugCallWasp();
        Assert.True(back.CanEngageWasp);
    }

    [Fact]
    public void AMetWasp_UsesUpTheFirstVisit_HoweverItWasAnswered()
    {
        // A shoe that hits
        var hit = Make(Hive(s => s.Honey = 100m), rng: new LowRandom());
        hit.DebugCallWasp();
        Assert.True(hit.ThrowShoe().Done);
        Assert.Equal(1, hit.State.WaspVisits);
        hit.DebugCallWasp();
        Assert.False(hit.CanEngageWasp);

        // A shoe that misses (a raid)
        var miss = Make(Hive(s => s.Honey = 100m));
        miss.DebugCallWasp();
        Assert.True(miss.ThrowShoe().Done);
        Assert.Equal(1, miss.State.WaspVisits);

        // Watched until its countdown ran out
        var watched = Make(Hive(s => s.Honey = 100m));
        watched.DebugCallWasp();
        Assert.True(Has(watched.AdvanceWaspCountdown(Cfg.WaspCountdownSeconds), BeekeeperEvents.WaspRaid));
        Assert.Equal(1, watched.State.WaspVisits);
        watched.DebugCallWasp();
        Assert.False(watched.CanEngageWasp);
    }

    [Theory]
    [InlineData("0.7", "0", "0.7")]
    [InlineData("5.6", "5", "0.6")]
    [InlineData("0.9999", "0", "0.9999")]
    public void AWaspSteals_OnlyWholeHoney(string honey, string stolen, string left)
    {
        var e = Make(Hive(s => s.Honey = decimal.Parse(honey, System.Globalization.CultureInfo.InvariantCulture)));
        e.DebugCallWasp();
        var ev = Assert.Single(e.EngageWasp().Events);
        Assert.Equal(decimal.Parse(stolen, System.Globalization.CultureInfo.InvariantCulture), ev.Value);
        Assert.Equal(decimal.Parse(left, System.Globalization.CultureInfo.InvariantCulture), e.State.Honey);
    }

    [Fact]
    public void ARaid_OnFractionalHoney_TakesAWholeAmount()
    {
        var e = Make(Hive(s => s.Honey = 3.5m));
        e.DebugCallWasp();
        var raid = e.AdvanceWaspCountdown(Cfg.WaspCountdownSeconds).Single();
        Assert.Equal(3m, raid.Value);
        Assert.Equal(0.5m, e.State.Honey);
    }

    // ============================================================ 3. Trade all on a huge stack of candles

    private static BeekeeperState HippieHive(decimal candles) => Hive(s =>
    {
        s.HippiesRevealed = true; s.RepsMet.Add("hippies"); s.RepsEngaged.Add("hippies"); s.BeeswaxCandles = candles;
    });

    [Fact]
    public void TradeAll_OnAHugeStack_FinishesQuickly_AndGivesBoundedSeeds()
    {
        var e = Make(HippieHive(30_000_000m), BeekeeperConfig.Default, new SeededRandom(3));
        var watch = System.Diagnostics.Stopwatch.StartNew();
        var r = e.TradeAllCandles();
        watch.Stop();

        Assert.True(r.Done);
        Assert.True(watch.Elapsed < TimeSpan.FromSeconds(2), $"took {watch.Elapsed}");
        Assert.Equal(10_000_000m, r.Amount);
        Assert.Equal(10_000_000L, e.State.HippieTrades);
        Assert.Equal(0m, e.State.BeeswaxCandles);
        int seeds = e.State.SeedsInHand.Count + e.State.Plants.Count;
        Assert.Equal(BeekeeperConfig.Default.HippieTradeSeedsMax, seeds);
        Assert.True(Has(r.Events, BeekeeperEvents.SeedsGivenBatch));
        Assert.Equal(seeds, r.Events.Single(x => x.Key == BeekeeperEvents.SeedsGivenBatch).Value);
    }

    [Fact]
    public void TradeAll_OnALoaderSizedStack_NeverThrows_AndTheTradeCountStops()
    {
        var e = Make(HippieHive(1e24m), BeekeeperConfig.Default, new SeededRandom(5));
        var r = e.TradeAllCandles();
        Assert.True(r.Done);
        Assert.Equal(long.MaxValue, e.State.HippieTrades);
        Assert.True(e.State.SeedsInHand.Count + e.State.Plants.Count <= BeekeeperConfig.Default.HippieTradeSeedsMax);
        Assert.NotNull(SaveAndLoad(e.State));   // the hive still saves and loads
    }

    [Fact]
    public void TradeAll_IsTheSameEveryTime_WithTheSameSeed()
    {
        BeekeeperEngine Run()
        {
            var e = Make(HippieHive(3_000_000m), BeekeeperConfig.Default, new SeededRandom(11));
            e.TradeAllCandles();
            return e;
        }
        var a = Run();
        var b = Run();
        Assert.Equal(a.State.SeedsInHand, b.State.SeedsInHand);
        Assert.Equal(a.State.Plants, b.State.Plants);
        Assert.Equal(a.State.HippieTrades, b.State.HippieTrades);
    }

    [Fact]
    public void ThePastTheExactRollsJars_StillUnlockEachSeedAtItsTrade_AndGiveTheAverage()
    {
        // No exact rolls: all 500 jars are worked out in runs from each seed's trade (1, 40, 200, 400) to just
        // before the next: 39, 160, 200 and 101 trades, averaging 7.8, 32, 40 and 20.2 seeds. The fractions roll
        // 0.99 here, so none adds one.
        var cfg = new BeekeeperConfig { HippieTradeExactRolls = 0 };
        var e = Make(HippieHive(1_500m), cfg);
        var r = e.TradeAllCandles();
        Assert.Equal(500m, r.Amount);
        Assert.Equal(500L, e.State.HippieTrades);
        foreach (var plant in cfg.Plants.Where(p => p.Giver == BeekeeperGivers.Hippies))
            Assert.Contains(plant.Id, e.State.SeedsGivenIds);
        Assert.Equal(7 + 32 + 40 + 20, e.State.SeedsInHand.Count + e.State.Plants.Count);
    }

    // ============================================================ 4. craft counts never overflow

    [Fact]
    public void AHugeCraft_WithCandleMolds_NeverGoesNegative_AndTheHiveStillSaves()
    {
        var e = Make(Hive(s => { s.Wax = 1e20m; s.Upgrades.Add(BeekeeperUpgrades.CandleMolds); }));
        var r = e.CraftBeeswax(int.MaxValue);
        Assert.True(r.Done);
        decimal expected = 2m * int.MaxValue;
        Assert.Equal(expected, r.Amount);
        Assert.Equal(expected, e.State.BeeswaxCandles);
        Assert.Equal((long)expected, e.State.CandlesCrafted);
        Assert.NotNull(SaveAndLoad(e.State));
    }

    [Fact]
    public void TheCandlesCraftedCount_StopsAtItsMost_InsteadOfWrapping()
    {
        var e = Make(Hive(s =>
        {
            s.Wax = 1e20m; s.Upgrades.Add(BeekeeperUpgrades.CandleMolds); s.CandlesCrafted = long.MaxValue - 1;
        }));
        Assert.True(e.CraftBeeswax(10).Done);
        Assert.Equal(long.MaxValue, e.State.CandlesCrafted);
    }

    // ============================================================ 5. one unknown id never throws away the hive

    [Fact]
    public void UnknownStoryIds_AreDroppedOnLoad_NotTheWholeHive()
    {
        var state = Hive(s =>
        {
            s.Honey = 123m;
            s.StoriesDone.Add("a_retired_card");
            s.StoryHere = "a_renamed_card";
            s.StoryReturnIn["another_old_card"] = 30m;
        });
        var loaded = SaveAndLoad(state);
        Assert.NotNull(loaded);
        var e = Make(loaded!);
        Assert.Equal(123m, e.State.Honey);
        Assert.DoesNotContain("a_retired_card", e.State.StoriesDone);
        Assert.Null(e.State.StoryHere);
        Assert.Empty(e.State.StoryReturnIn);
    }

    [Fact]
    public void ConfigLimits_AreTrimmedOnLoad_NotRefused()
    {
        var state = Hive(s =>
        {
            s.ToolLevel = 99; s.GlovesDeclines = 99; s.Bees = 1e22m;
        });
        var loaded = SaveAndLoad(state);
        Assert.NotNull(loaded);
        var e = Make(loaded!, BeekeeperConfig.Default);
        Assert.Equal(BeekeeperConfig.Default.Tools.Count, e.State.ToolLevel);
        Assert.Equal(BeekeeperConfig.Default.GlovesMaxDeclines, e.State.GlovesDeclines);
        Assert.Equal(BeekeeperConfig.Default.MaxBees, e.State.Bees);
        Assert.True(e.BeesPerClick > 0);   // a tool past the list used to throw here
    }

    [Theory]
    [InlineData("honey")]
    [InlineData("bees")]
    [InlineData("tool")]
    [InlineData("returnTime")]
    public void RealDamage_IsStillRefused(string what)
    {
        var state = Hive(s =>
        {
            switch (what)
            {
                case "honey": s.Honey = -1m; break;
                case "bees": s.Bees = -1m; break;
                case "tool": s.ToolLevel = -1; break;
                case "returnTime": s.StoryReturnIn[BeekeeperStories.Gloves] = -5m; break;
            }
        });
        Assert.Null(SaveAndLoad(state));
    }

    // ============================================================ 6. the smaller items

    [Fact]
    public void ASaveWithOnlyHerbalCandles_StillSeesTheBeeswaxCandleCard()
    {
        var e = Make(Hive(s => { s.CandlesCrafted = 5; s.RepellentCrafted = true; s.RepellentCandles = 5m; }));
        Assert.DoesNotContain(BeekeeperStories.Candle, e.State.StoriesDone);

        var made = Make(Hive(s => { s.CandlesCrafted = 5; s.BeeswaxCrafted = true; }));   // all traded away since
        Assert.Contains(BeekeeperStories.Candle, made.State.StoriesDone);
    }

    [Fact]
    public void AnyCraft_MarksItsStoryCardDone_AtOnce()
    {
        var e = Make(Hive(s => { s.Wax = 100m; s.Honey = 100m; s.ClayJars = 5m; }));
        Assert.True(e.CraftBeeswax().Done);
        Assert.True(e.State.BeeswaxCrafted);
        Assert.Contains(BeekeeperStories.Candle, e.State.StoriesDone);
        Assert.True(e.PotHoney().Done);
        Assert.Contains(BeekeeperStories.PotHoney, e.State.StoriesDone);
        Assert.True(e.CraftLinksOpen(BeekeeperStories.PotHoney));
    }

    [Fact]
    public void AnOldSavesRepellentCandle_BurnsDown_AndKeepsAQueuedWaspAway()
    {
        var e = Make(Hive(s => { s.StoriesDone = BeekeeperStories.Order.ToList(); s.RepellentSecondsLeft = 10m; s.StoryQueue.Add("wasp"); }));
        Assert.False(Has(e.AdvanceWaspTime(5m), BeekeeperEvents.WaspArrives));
        Assert.Equal(5m, e.State.RepellentSecondsLeft);
        var events = e.AdvanceWaspTime(5m);
        Assert.True(Has(events, BeekeeperEvents.CandleOut));
        Assert.False(Has(events, BeekeeperEvents.WaspArrives));
        Assert.True(Has(e.AdvanceWaspTime(1m), BeekeeperEvents.WaspArrives));   // burnt out: now it comes
    }

    [Fact]
    public void AFadingCard_FadesOnlyWhileWatched()
    {
        var e = Make(Hive(s => { s.StoriesDone = BeekeeperStories.Order.Where(id => id != BeekeeperStories.Ouch).ToList(); }));
        Assert.NotEmpty(e.DebugShowStory(BeekeeperStories.Ouch));
        e.AdvanceStoryTime(1_000m, watched: false);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);
        Assert.DoesNotContain(BeekeeperStories.Ouch, e.State.StoriesDone);

        e.AdvanceStoryTime(Cfg.OuchSeconds, watched: true);
        Assert.Null(e.StoryHere);
        Assert.Contains(BeekeeperStories.Ouch, e.State.StoriesDone);
    }

    [Fact]
    public void TheHippiesFifthShoe_SendsThemAwayForGood_EvenFromAHandEditedCount()
    {
        var e = Make(Hive(s => { s.HippiesRevealed = true; s.RepsMet.Add("hippies"); s.RepsPresent.Add("hippies"); s.HippieShoes = int.MaxValue; }));
        Assert.True(e.ThrowShoeAtRep("hippies").Done);
        Assert.True(e.State.HippiesDismissedForGood);
        Assert.Equal(int.MaxValue, e.State.HippieShoes);
    }

    [Fact]
    public void TheHippies_TradeNoMore_OnceGoneForGood()
    {
        var e = Make(Hive(s =>
        {
            s.HippiesRevealed = true; s.HippiesDismissedForGood = true; s.RepsEngaged.Add("hippies"); s.BeeswaxCandles = 30m;
        }));
        Assert.False(e.RepEngaged("hippies"));
        Assert.False(e.CanTradeCandles);
        Assert.False(e.TradeAllCandles().Done);
        Assert.Equal(30m, e.State.BeeswaxCandles);
    }

    [Fact]
    public void APotHoneyCardWithNoJars_StepsAsideForTheHippies_SoTheQueueMoves()
    {
        var e = Make(Hive(s =>
        {
            s.StoriesDone = BeekeeperStories.Order.Where(id => id != BeekeeperStories.PotHoney).ToList();
            s.StoryHere = BeekeeperStories.PotHoney; s.ClayJars = 0m; s.Honey = 100m;
            s.HippiesRevealed = true; s.RepsMet.Add("hippies"); s.RepReturnIn["hippies"] = 0m;
        }));
        Assert.Contains("rep:hippies", e.StoryQueue);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
        Assert.Contains("hippies", e.RepsPresent);
        Assert.DoesNotContain(BeekeeperStories.PotHoney, e.State.StoriesDone);   // not done: it comes back with jars
    }
}
