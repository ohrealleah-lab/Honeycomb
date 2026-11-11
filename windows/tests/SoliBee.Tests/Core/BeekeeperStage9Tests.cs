using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 9 rules (spec 018): the bloom calendar. It starts with the first plant; crocus,
/// clover, linden and goldenrod each last a day of game time and make one specialty work twice as
/// hard; a half-day winter slows honey; live play and time away agree across bloom changes.</summary>
public class BeekeeperStage9Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage9-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;   // every chance roll misses
        public int Next(int maxExclusive) => 0;
    }

    private const decimal Day = 24m * 3600m;

    private static readonly BeekeeperConfig BigCaps = BeekeeperTestHives.BigCaps();

    /// <summary>A short year (10-minute blooms, a 5-minute winter) so 1-second live play can cross many changes.</summary>
    private static readonly BeekeeperConfig ShortYear = new()
    {
        StartingHoneyCap = 1e12m, StartingWaxCap = 1e12m,
        Blooms = new[]
        {
            new BeekeeperBloom(BeekeeperBlooms.Crocus, 600m, BeekeeperSpecialties.Nursing),
            new BeekeeperBloom(BeekeeperBlooms.Clover, 600m, BeekeeperSpecialties.Foraging),
            new BeekeeperBloom(BeekeeperBlooms.Linden, 600m, BeekeeperSpecialties.Guarding),
            new BeekeeperBloom(BeekeeperBlooms.Goldenrod, 600m, BeekeeperSpecialties.Resin),
            new BeekeeperBloom(BeekeeperBlooms.Winter, 300m, null),
        },
    };

    private static BeekeeperEngine Make(BeekeeperState? state = null, BeekeeperConfig? config = null)
        => new(config ?? BeekeeperConfig.Default, state, new NoRandom());

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    /// <summary>A started hive (5 combs: 1 honey a second) growing one of each plant given.</summary>
    private static BeekeeperState Garden(params string[] plants)
    {
        var s = BeekeeperTestHives.Started(5);
        s.GardenRevealed = true;
        s.Plants.AddRange(plants);
        return s;
    }

    private static readonly string[] EveryKind =
    {
        BeekeeperPlants.Wildflowers, BeekeeperPlants.Clover, BeekeeperPlants.Bramble, BeekeeperPlants.Willow, BeekeeperPlants.Poplar,
    };

    /// <summary>Every kind, the wooden hive and a laying queen with a pantry that runs out part-way.</summary>
    private static BeekeeperState Busy()
    {
        var s = Garden(EveryKind);
        s.Plants.AddRange(Enumerable.Repeat(BeekeeperPlants.Poplar, 2));
        s.Plants.AddRange(Enumerable.Repeat(BeekeeperPlants.Bramble, 3));
        s.Bees = 300m;
        s.HasWoodenHive = true;
        s.QueenSettled = true;
        s.BeeBread = 10m;   // 1,000 bees: in the short year it runs out in the first linden
        s.BeeBreadRevealed = true;
        s.CarpenterBeeCame = true;
        return s;
    }

    // ============================================================ the calendar starts (User Story 1)

    [Fact]
    public void TheBlooms_AreData_InOrder_WithTheirLengthsAndFavours()
    {
        var b = BeekeeperConfig.Default.Blooms;
        Assert.Equal(new[] { BeekeeperBlooms.Crocus, BeekeeperBlooms.Clover, BeekeeperBlooms.Linden, BeekeeperBlooms.Goldenrod, BeekeeperBlooms.Winter },
            b.Select(x => x.Id));
        Assert.Equal(new[] { Day, Day, Day, Day, Day / 2m }, b.Select(x => x.Seconds));
        Assert.Equal(new[] { BeekeeperSpecialties.Nursing, BeekeeperSpecialties.Foraging, BeekeeperSpecialties.Guarding, BeekeeperSpecialties.Resin, null },
            b.Select(x => x.Favours));
        Assert.Equal(2m, BeekeeperConfig.Default.BloomFavourMultiplier);
        Assert.Equal(0.75m, BeekeeperConfig.Default.WinterHoneyMultiplier);
    }

    [Fact]
    public void NoCalendar_BeforeTheFirstPlant()
    {
        var e = Make(BeekeeperTestHives.Started(5));
        e.Advance(10m);
        e.AdvanceAway(2m * Day);
        Assert.False(e.State.CalendarStarted);
        Assert.Null(e.CurrentBloom);
        Assert.Equal(0m, e.BloomSecondsLeft);
        Assert.Equal(1m, e.WinterMultiplier);
        Assert.Equal(1m, e.BloomFavour(BeekeeperSpecialties.Nursing));
        Assert.Empty(e.DebugNextBloom());
    }

    [Fact]
    public void TheFirstPlantByHand_StartsTheCalendarOnCrocus_WithALogLine_Once()
    {
        var s = BeekeeperTestHives.Started();
        s.SeedsInHand.AddRange(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble });
        var e = Make(s);
        var r = e.PlantSeed(BeekeeperPlants.Wildflowers);
        var started = Assert.Single(r.Events, ev => ev.Key == BeekeeperEvents.CalendarStarted);
        Assert.Equal(BeekeeperBlooms.Crocus, started.Text);
        Assert.Equal(BeekeeperBlooms.Crocus, e.CurrentBloom!.Id);
        Assert.Equal(Day, e.BloomSecondsLeft);

        e.Advance(100m);
        Assert.False(Has(e.PlantSeed(BeekeeperPlants.Bramble).Events, BeekeeperEvents.CalendarStarted));
        Assert.Equal(Day - 100m, e.BloomSecondsLeft);   // a second plant doesn't restart it
    }

    [Fact]
    public void TheStoryCard_AndTheDebugShortcut_StartTheCalendarToo()
    {
        var s = BeekeeperTestHives.Started();
        s.SeedsInHand.Add(BeekeeperPlants.Willow);
        s.StoryHere = BeekeeperStories.Seed;
        var story = Make(s);
        Assert.True(Has(story.PlantFromStory().Events, BeekeeperEvents.CalendarStarted));
        Assert.Equal(BeekeeperBlooms.Crocus, story.CurrentBloom!.Id);

        var debug = Make(BeekeeperTestHives.Started());
        Assert.True(Has(debug.DebugPlant(BeekeeperPlants.Clover, 3), BeekeeperEvents.CalendarStarted));
        Assert.True(debug.State.CalendarStarted);
    }

    [Fact]
    public void SeedsThatPlantThemselves_KeepTheCalendarRunning()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));   // started on load
        e.Advance(50m);
        e.DebugGiveSeedsOfEvery(2);                          // wildflower seeds plant themselves
        Assert.Equal(3, e.PlantCount(BeekeeperPlants.Wildflowers));
        Assert.Equal(Day - 50m, e.BloomSecondsLeft);
    }

    [Fact]
    public void AnOlderSaveWithPlants_StartsOnCrocusWhenItLoads_AndSaysSoOnce()
    {
        var e = Make(Garden(BeekeeperPlants.Bramble));
        Assert.True(e.State.CalendarStarted);
        Assert.Equal(BeekeeperBlooms.Crocus, e.CurrentBloom!.Id);
        Assert.Equal(Day, e.BloomSecondsLeft);
        Assert.Single(e.RevealOnLoad(), ev => ev.Key == BeekeeperEvents.CalendarStarted);
        Assert.DoesNotContain(e.RevealOnLoad(), ev => ev.Key == BeekeeperEvents.CalendarStarted);

        var noPlants = Make(BeekeeperTestHives.Started());
        Assert.False(noPlants.State.CalendarStarted);
        Assert.DoesNotContain(noPlants.RevealOnLoad(), ev => ev.Key == BeekeeperEvents.CalendarStarted);
    }

    [Fact]
    public void StartCalendar_ForASaveWithNoPlant_StartsOnce()
    {
        var e = Make(BeekeeperTestHives.Started());
        Assert.Single(e.StartCalendar(), ev => ev.Key == BeekeeperEvents.CalendarStarted);
        Assert.Empty(e.StartCalendar());
        Assert.Equal(BeekeeperBlooms.Crocus, e.CurrentBloom!.Id);
    }

    // ============================================================ one bloom a day (User Story 2)

    [Fact]
    public void TheBlooms_FollowInOrder_DayByDay_WinterIsHalfADay_ThenCrocusAgain()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        var r = e.Advance(Day - 1m);
        Assert.False(Has(r.Events, BeekeeperEvents.BloomChanged));
        Assert.Equal(1m, e.BloomSecondsLeft);

        var changes = new List<string?>();
        changes.AddRange(e.Advance(1m).Events.Where(ev => ev.Key == BeekeeperEvents.BloomChanged).Select(ev => ev.Text));
        Assert.Equal(Day, e.BloomSecondsLeft);
        changes.AddRange(e.Advance(Day).Events.Where(ev => ev.Key == BeekeeperEvents.BloomChanged).Select(ev => ev.Text));
        changes.AddRange(e.Advance(Day).Events.Where(ev => ev.Key == BeekeeperEvents.BloomChanged).Select(ev => ev.Text));
        changes.AddRange(e.Advance(Day).Events.Where(ev => ev.Key == BeekeeperEvents.BloomChanged).Select(ev => ev.Text));
        Assert.Equal(Day / 2m, e.BloomSecondsLeft);   // winter: 12 hours
        changes.AddRange(e.Advance(Day / 2m).Events.Where(ev => ev.Key == BeekeeperEvents.BloomChanged).Select(ev => ev.Text));
        Assert.Equal(new[] { BeekeeperBlooms.Clover, BeekeeperBlooms.Linden, BeekeeperBlooms.Goldenrod, BeekeeperBlooms.Winter, BeekeeperBlooms.Crocus }, changes);
        Assert.Equal(BeekeeperBlooms.Crocus, e.CurrentBloom!.Id);
        Assert.Equal(Day, e.BloomSecondsLeft);
    }

    [Fact]
    public void NextBloomUp_NamesTheNext_AndWraps()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        Assert.Equal(BeekeeperBlooms.Clover, e.NextBloomUp!.Id);
        for (int i = 0; i < 4; i++) e.DebugNextBloom();
        Assert.True(e.IsWinter);
        Assert.Equal(BeekeeperBlooms.Crocus, e.NextBloomUp!.Id);
    }

    [Fact]
    public void DebugNextBloom_MovesOn_WithAnEvent_AndProducesNothing()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        decimal honey = e.State.Honey, pollen = e.State.Pollen;
        var ev = Assert.Single(e.DebugNextBloom());
        Assert.Equal(BeekeeperEvents.BloomChanged, ev.Key);
        Assert.Equal(BeekeeperBlooms.Clover, ev.Text);
        Assert.Equal(Day, e.BloomSecondsLeft);
        Assert.Equal(honey, e.State.Honey);
        Assert.Equal(pollen, e.State.Pollen);
    }

    // ============================================================ favours (User Story 3)

    [Fact]
    public void EachBloom_MakesItsSpecialtyWorkTwiceAsHard()
    {
        var s = Garden(EveryKind);
        s.HasWoodenHive = true;
        var e = Make(s);

        // Crocus: nursing ×1.5 → ×2 (the queen lays 40 a minute, not 30).
        Assert.Equal(2m, e.NursingMultiplier);
        Assert.Equal(1.5m, e.NursingMultiplierAlone);
        Assert.Equal(40m, e.QueenRatePerMinute);
        Assert.Equal(1.25m, e.GuardingMultiplier);
        Assert.Equal(6m, e.ForagingPollenPerMinute);
        Assert.Equal(1m, e.ResinPropolisPerMinute);

        e.DebugNextBloom();   // clover: pollen 6 → 12
        Assert.Equal(12m, e.ForagingPollenPerMinute);
        Assert.Equal(1.5m, e.NursingMultiplier);

        e.DebugNextBloom();   // linden: guarding +25% → +50%
        Assert.Equal(1.5m, e.GuardingMultiplier);
        Assert.Equal(1.25m, e.GuardingMultiplierAlone);
        Assert.Equal(6m, e.ForagingPollenPerMinute);

        e.DebugNextBloom();   // goldenrod: propolis 1 → 2
        Assert.Equal(2m, e.ResinPropolisPerMinute);
        Assert.Equal(1.25m, e.GuardingMultiplier);

        e.DebugNextBloom();   // winter favours nothing
        Assert.Equal(1.5m, e.NursingMultiplier);
        Assert.Equal(1.25m, e.GuardingMultiplier);
        Assert.Equal(6m, e.ForagingPollenPerMinute);
        Assert.Equal(1m, e.ResinPropolisPerMinute);
    }

    [Fact]
    public void PlantBonuses_DontDouble_OnlyTheSpecialtyDoes()
    {
        var s = Garden(BeekeeperPlants.Poplar, BeekeeperPlants.Poplar, BeekeeperPlants.Poplar,
            BeekeeperPlants.Bramble, BeekeeperPlants.Bramble, BeekeeperPlants.Bramble);
        var e = Make(s);
        e.DebugNextBloom(); e.DebugNextBloom();   // linden
        Assert.Equal(1.5m * 1.02m, e.HiveMultiplier);           // +50% guarding, the brambles' +2% outside it
        Assert.Equal(1.5m * 1.02m, e.HoneyPerSecond / 1m);       // 5 combs: 1 honey a second before boosts
        e.DebugNextBloom();   // goldenrod
        Assert.Equal(2m, e.ResinPropolisPerMinute);
        Assert.Equal(2m * 1.02m, e.PropolisPerMinute);           // the poplars' +2% outside it
    }

    [Fact]
    public void ABloomWithoutItsSpecialty_ChangesNothing()
    {
        var s = Garden(BeekeeperPlants.Wildflowers);
        s.HasWoodenHive = true;
        var e = Make(s);   // crocus, no willow
        Assert.False(e.BloomFavourActive);
        Assert.Equal(1m, e.NursingMultiplier);
        Assert.Equal(20m, e.QueenRatePerMinute);
        e.DebugNextBloom();
        Assert.True(e.BloomFavourActive);   // clover, and wildflowers forage
        e.DebugNextBloom();
        Assert.Equal(1m, e.GuardingMultiplier);   // linden, no bramble
        Assert.Equal(1.25m, e.HiveMultiplier);   // the wooden hive alone
        e.DebugNextBloom();
        Assert.Equal(0m, e.ResinPropolisPerMinute);   // goldenrod, no poplar
    }

    // ============================================================ winter (User Story 4)

    [Fact]
    public void Winter_SlowsTheCombsAndTheMeadowsHoney_AndNothingElse()
    {
        var s = Busy();
        s.HasMeadow = true;
        var e = Make(s, BigCaps);
        for (int i = 0; i < 3; i++) e.DebugNextBloom();   // goldenrod
        decimal honey = e.HoneyPerSecond, wax = e.WaxPerSecondNow, pollen = e.ForagingPollenPerMinute,
            wood = e.WoodPerMinuteNow, laying = e.QueenRatePerMinute;
        decimal propolisAlone = e.ResinPropolisPerMinute / 2m;   // goldenrod doubles it

        e.DebugNextBloom();   // winter
        Assert.True(e.IsWinter);
        Assert.Equal(0.75m, e.WinterMultiplier);
        Assert.Equal(honey * 0.75m, e.HoneyPerSecond);
        Assert.Equal((5m * 0.2m + 5m) * e.HiveMultiplier, e.HoneyPerSecond);   // combs and meadow alike
        Assert.Equal(wax, e.WaxPerSecondNow);
        Assert.Equal(pollen, e.ForagingPollenPerMinute);
        Assert.Equal(propolisAlone, e.ResinPropolisPerMinute);
        Assert.Equal(wood, e.WoodPerMinuteNow);
        Assert.Equal(laying, e.QueenRatePerMinute);

        decimal bees = e.State.Bees, stored = e.State.Honey;
        int plants = e.State.Plants.Count;
        e.DebugNextBloom();   // spring again: nothing was lost
        Assert.Equal(1m, e.WinterMultiplier);
        Assert.Equal(bees, e.State.Bees);
        Assert.Equal(stored, e.State.Honey);
        Assert.Equal(plants, e.State.Plants.Count);
    }

    // ============================================================ the split, live and away (User Story 6)

    [Fact]
    public void Work_SplitsAtABloomChange_LindenThenGoldenrod()
    {
        BeekeeperState Linden100()
        {
            var s = Garden(BeekeeperPlants.Bramble);
            s.CalendarStarted = true;
            s.BloomIndex = 2;          // linden
            s.BloomSecondsLeft = 100m;
            return s;
        }
        var live = Make(Linden100(), BigCaps);
        var r = live.Advance(300m);
        Assert.Equal(100m * 1.5m + 200m * 1.25m, live.State.Honey);   // 1 honey a second before guarding
        Assert.Single(r.Events, ev => ev.Key == BeekeeperEvents.BloomChanged && ev.Text == BeekeeperBlooms.Goldenrod);
        Assert.Equal(Day - 200m, live.BloomSecondsLeft);

        var away = Make(Linden100(), BigCaps);
        away.AdvanceAway(300m);
        Assert.Equal(400m, away.State.Honey);
    }

    private static void AssertSame(BeekeeperEngine a, BeekeeperEngine b)
    {
        Assert.Equal(a.State.Honey, b.State.Honey);
        Assert.Equal(a.State.Wax, b.State.Wax);
        Assert.Equal(a.State.Bees, b.State.Bees);
        Assert.Equal(a.State.BeeBread, b.State.BeeBread);
        Assert.Equal(a.State.Pollen, b.State.Pollen);
        Assert.Equal(a.State.Propolis, b.State.Propolis);
        Assert.Equal(a.State.Wood, b.State.Wood);
        Assert.Equal(a.State.BloomIndex, b.State.BloomIndex);
        Assert.Equal(a.State.BloomSecondsLeft, b.State.BloomSecondsLeft);
    }

    [Fact]
    public void LiveAndAway_Agree_AcrossSeveralBloomChanges()
    {
        var live = Make(Busy(), ShortYear);
        for (int i = 0; i < 4000; i++) live.Advance(1m);
        var away = Make(Busy(), ShortYear);
        away.AdvanceAway(4000m);
        AssertSame(live, away);
        // 4,000 s = a year (2,700) + crocus + clover + 100 s of linden.
        Assert.Equal(2, away.State.BloomIndex);
        Assert.Equal(500m, away.State.BloomSecondsLeft);
        Assert.Equal(0m, away.State.BeeBread);   // the pantry ran out part-way
        Assert.True(away.State.Honey > 0m && away.State.Pollen > 0m && away.State.Propolis > 0m);

        var parts = Make(Busy(), ShortYear);
        foreach (var st in new[] { 7m, 593m, 0.5m, 1199.5m, 300m, 1m, 1899m }) parts.AdvanceAway(st);
        AssertSame(away, parts);
    }

    [Fact]
    public void TimeAway_CountsLikeLiveTime_UpToTheThreeDayCap()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        var r = e.AdvanceAway(10m * Day);
        Assert.Equal(3m * Day, r.CreditedSeconds);
        Assert.Equal(BeekeeperBlooms.Goldenrod, e.CurrentBloom!.Id);   // crocus, clover, linden: exactly three days
        Assert.Equal(Day, e.BloomSecondsLeft);
        Assert.DoesNotContain(r.Events, ev => ev.Key == BeekeeperEvents.BloomChanged);   // no log line each
        var line = Assert.Single(r.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBackBlooms);
        Assert.Equal("clover|linden|goldenrod", line.Text);
        Assert.Equal(3m, line.Value);
    }

    [Fact]
    public void TimeAway_WithNoBloomChange_HasNoBloomLine()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        var r = e.AdvanceAway(3600m);
        Assert.DoesNotContain(r.WelcomeBack, ev => ev.Key == BeekeeperEvents.WelcomeBackBlooms);
        Assert.Equal(Day - 3600m, e.BloomSecondsLeft);
    }

    [Fact]
    public void ALongGapWithTheAppOpen_TellsEachChangeLive()
    {
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        var r = e.AdvanceGap(2m * Day);
        Assert.Equal(new[] { BeekeeperBlooms.Clover, BeekeeperBlooms.Linden },
            r.Events.Where(ev => ev.Key == BeekeeperEvents.BloomChanged).Select(ev => ev.Text));
        Assert.Empty(r.WelcomeBack);
    }

    [Fact]
    public void WelcomeBackBlooms_IsAWelcomeBackLine()
    {
        Assert.True(BeekeeperEvents.IsWelcomeBack(BeekeeperEvents.WelcomeBackBlooms));
        Assert.False(BeekeeperEvents.IsWelcomeBack(BeekeeperEvents.BloomChanged));
    }

    // ============================================================ save (FR-910)

    [Fact]
    public void TheCalendar_RoundTripsThroughASave()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "hive.json");
        var e = Make(Garden(BeekeeperPlants.Wildflowers));
        e.DebugNextBloom();
        e.Advance(1234.5m);
        Assert.True(BeekeeperSaveService.Save(e.State, path, new DateTime(2026, 11, 11, 12, 0, 0, DateTimeKind.Utc)));
        var loaded = BeekeeperSaveService.Load(path);
        Assert.NotNull(loaded);
        Assert.True(loaded!.CalendarStarted);
        Assert.Equal(1, loaded.BloomIndex);
        Assert.Equal(Day - 1234.5m, loaded.BloomSecondsLeft);
        var again = Make(loaded);
        Assert.Equal(BeekeeperBlooms.Clover, again.CurrentBloom!.Id);
        Assert.Equal(Day - 1234.5m, again.BloomSecondsLeft);
    }

    [Theory]
    [InlineData(7, 999_999, 2, 86_400)]      // index wraps; seconds clamped to the bloom's length
    [InlineData(-1, 100, 4, 100)]            // a negative index wraps too (winter)
    [InlineData(4, 50_000, 4, 43_200)]       // winter is 12 hours long
    [InlineData(1, 0, 1, 86_400)]            // a running calendar with no time left gets the full length
    [InlineData(3, -5, 3, 86_400)]
    public void ABadIndexOrTime_IsFixedOnLoad(int index, int seconds, int fixedIndex, int fixedSeconds)
    {
        var s = Garden(BeekeeperPlants.Wildflowers);
        s.CalendarStarted = true;
        s.BloomIndex = index;
        s.BloomSecondsLeft = seconds;
        var e = Make(s);
        Assert.Equal(fixedIndex, e.State.BloomIndex);
        Assert.Equal((decimal)fixedSeconds, e.State.BloomSecondsLeft);
    }

    [Fact]
    public void ACalendarNotStarted_HasNoLeftoverTime()
    {
        var s = BeekeeperTestHives.Started();
        s.BloomIndex = 3;
        s.BloomSecondsLeft = 77m;
        var e = Make(s);
        Assert.Equal(0, e.State.BloomIndex);
        Assert.Equal(0m, e.State.BloomSecondsLeft);
        Assert.Null(e.CurrentBloom);
    }
}
