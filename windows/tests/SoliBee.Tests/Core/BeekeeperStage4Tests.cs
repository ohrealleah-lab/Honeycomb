using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 4 rules (spec 012): seeds, the Garden, forager and guard bees, pollen, bee bread, the wooden hive.</summary>
public class BeekeeperStage4Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage4-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class FakeRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static BeekeeperEngine Make(BeekeeperState? state = null)
        => new(BeekeeperConfig.Default, state, new FakeRandom());

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    // Hippies who have already traded `trades` times, with candles for one more trade.
    private static BeekeeperEngine WithHippies(long trades)
        => Make(new BeekeeperState { HippiesRevealed = true, HippieTrades = trades, BeeswaxCandles = 100m });

    // ============================================================ seeds from the Hippies

    [Fact]
    public void TheFifthHippieTrade_GivesASeed_AndOpensTheGarden()
    {
        var e = WithHippies(3);
        Assert.False(Has(e.TradeTenCandles().Events, BeekeeperEvents.SeedGiven));   // 4th
        Assert.Equal(0, e.State.Seeds);

        var fifth = e.TradeTenCandles();                                            // 5th
        Assert.True(Has(fifth.Events, BeekeeperEvents.SeedGiven));
        Assert.Equal(1, e.State.Seeds);
        Assert.True(e.State.GardenRevealed);
    }

    [Fact]
    public void TheTenthTrade_GivesASecondSeed_AndNoMoreComeAfter()
    {
        var e = WithHippies(8);
        e.State.SeedsGiven = 1;
        e.State.Seeds = 0;
        e.TradeTenCandles();                       // 9th
        Assert.Equal(0, e.State.Seeds);
        e.TradeTenCandles();                       // 10th
        Assert.Equal(1, e.State.Seeds);
        Assert.Equal(2, e.State.SeedsGiven);

        for (int i = 0; i < 5; i++) e.TradeTenCandles();
        Assert.Equal(1, e.State.Seeds);            // none in this build
    }

    [Fact]
    public void AnOldSaveWithManyTrades_GetsItsFirstSeed_OnTheNextTrade()
    {
        var e = WithHippies(7);
        Assert.Equal(0, e.State.SeedsGiven);
        e.TradeTenCandles();
        Assert.Equal(1, e.State.Seeds);
    }

    [Fact]
    public void TradeAll_IsOneTrade_SoOneSeedAtMost()
    {
        var e = WithHippies(4);
        e.State.BeeswaxCandles = 100m;
        e.TradeAllCandles();
        Assert.Equal(5, e.State.HippieTrades);
        Assert.Equal(1, e.State.Seeds);
    }

    [Fact]
    public void Sage_IsUnchanged_ThereAreNoSagePlants()
    {
        var e = WithHippies(0);
        e.TradeTenCandles();
        Assert.Equal(1m, e.State.Sage);
    }

    // ============================================================ planting and growing

    private static BeekeeperEngine WithSeed(int planted = 0)
        => Make(new BeekeeperState { Seeds = 1, SeedsGiven = planted + 1, SeedsPlanted = planted, GardenRevealed = true });

    [Fact]
    public void PlantingUsesTheSeed_AndStartsTheTenMinutes()
    {
        var e = WithSeed();
        var r = e.PlantSeed();
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.SeedPlanted));
        Assert.Equal(0, e.State.Seeds);
        Assert.Equal(600m, e.State.GrowSecondsLeft);
        Assert.True(e.IsGrowing);
    }

    [Fact]
    public void WithoutASeed_OrWhileOneGrows_PlantingIsRefused()
    {
        Assert.False(Make().PlantSeed().Done);

        var e = WithSeed();
        e.PlantSeed();
        e.State.Seeds = 1;                          // a second seed waits
        Assert.False(e.CanPlantSeed);
        Assert.False(e.PlantSeed().Done);
        Assert.Equal(1, e.State.Seeds);
    }

    [Fact]
    public void ASeedSprouts_AfterTenMinutes_AndLogsIt()
    {
        var e = WithSeed();
        e.PlantSeed();
        var early = e.Advance(599m);
        Assert.False(Has(early.Events, BeekeeperEvents.SeedSprouted));
        Assert.Empty(e.State.Plants);

        var r = e.Advance(1m);
        Assert.True(Has(r.Events, BeekeeperEvents.SeedSprouted));
        Assert.Contains(r.Events, ev => ev.Key == BeekeeperEvents.PlantRevealed && ev.Text == BeekeeperPlants.Wildflowers);
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers }, e.State.Plants);
        Assert.False(e.IsGrowing);
    }

    [Fact]
    public void TheSecondSeedGrowsTheBramble()
    {
        var e = WithSeed(planted: 1);
        e.State.Plants.Add(BeekeeperPlants.Wildflowers);
        e.PlantSeed();
        e.DebugFinishGrowing();
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble }, e.State.Plants);
    }

    [Fact]
    public void ASeedThatFinishedWhileAway_HasSprouted_AndTheRestOfTheTimeCounts()
    {
        var e = WithSeed();
        e.PlantSeed();
        var away = e.AdvanceAway(15m * 60m);        // 10 to grow, 5 minutes of wildflowers
        Assert.True(Has(away.Events, BeekeeperEvents.SeedSprouted));
        Assert.Equal(5m, e.State.ForagerBees);      // 1 a minute
    }

    // ============================================================ forager bees and pollen

    [Fact]
    public void Wildflowers_AttractOneForagerAMinute()
    {
        var e = Make(new BeekeeperState { Plants = { BeekeeperPlants.Wildflowers } });
        e.Advance(60m);
        Assert.Equal(1m, e.State.ForagerBees);
        e.Advance(120m);
        Assert.Equal(3m, e.State.ForagerBees);
    }

    [Fact]
    public void TenForagers_BringBackOnePollenAMinute()
    {
        var e = Make(new BeekeeperState { Plants = { BeekeeperPlants.Wildflowers }, ForagerBees = 10m });
        // the 10 foragers stay 10 for this check: stop new arrivals
        e.State.Plants.Clear();
        e.Advance(60m);
        Assert.Equal(1m, e.State.Pollen);
        e.Advance(120m);
        Assert.Equal(3m, e.State.Pollen);
    }

    [Fact]
    public void PollenAndForagers_SameWhetherLiveInSecondsOrOneAwayStep()
    {
        BeekeeperState Start() => new() { Plants = { BeekeeperPlants.Wildflowers }, ForagerBees = 4m };

        var live = Make(Start());
        for (int i = 0; i < 1800; i++) live.Advance(1m);

        var away = Make(Start());
        away.AdvanceAway(1800m);

        Assert.Equal((double)live.State.ForagerBees, (double)away.State.ForagerBees, 6);
        Assert.Equal((double)live.State.Pollen, (double)away.State.Pollen, 6);
    }

    [Fact]
    public void GrowingAcrossTheSprout_GivesTheSameAsLiveSeconds()
    {
        var live = WithSeed();
        live.PlantSeed();
        for (int i = 0; i < 1500; i++) live.Advance(1m);

        var away = WithSeed();
        away.PlantSeed();
        away.AdvanceAway(1500m);

        Assert.Equal((double)live.State.ForagerBees, (double)away.State.ForagerBees, 6);
        Assert.Equal((double)live.State.Pollen, (double)away.State.Pollen, 6);
        Assert.Equal(live.State.Plants, away.State.Plants);
    }

    [Fact]
    public void TheFirstPollen_IsLogged_AndOpensBeeBread()
    {
        var e = Make(new BeekeeperState { ForagerBees = 10m });
        var r = e.Advance(59m);
        Assert.False(e.State.PollenRevealed);
        r = e.Advance(2m);
        Assert.True(Has(r.Events, BeekeeperEvents.FirstPollen));
        Assert.True(e.State.PollenRevealed);
    }

    [Fact]
    public void Foragers_DoNotMakeHoney_AndAreNotCaught()
    {
        var e = Make(new BeekeeperState { ForagerBees = 50m, HoneyRevealed = true });
        e.Advance(100m);
        Assert.Equal(0m, e.State.Honey);
        Assert.Equal(0m, e.State.Bees);
        Assert.Equal(1m, e.BeesPerCatch);   // slice is only of honeybees
    }

    [Fact]
    public void Foragers_NeverFlyOffInARaid()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, ForagerBees = 50m, Honey = 100m, WorkbenchRevealed = true });
        e.DebugCallWasp();
        e.ThrowShoe();   // FakeRandom 0.99 => miss => raid
        Assert.Equal(50m, e.State.ForagerBees);
    }

    // ============================================================ guard bees

    [Fact]
    public void TheBramble_AttractsOneGuardAMinute()
    {
        var e = Make(new BeekeeperState { Plants = { BeekeeperPlants.Bramble } });
        e.Advance(120m);
        Assert.Equal(2m, e.State.GuardBees);
        Assert.True(e.HasGuards);
    }

    [Fact]
    public void WithAGuard_ARaidNeverCostsABee_ButStillTakesHoney()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, GuardBees = 1m, Honey = 5000m, WorkbenchRevealed = true });
        e.DebugCallWasp();
        var r = e.ThrowShoe();                     // miss -> raid
        var raid = r.Events.Single();
        Assert.Equal(BeekeeperEvents.ShoeMissRaid, raid.Key);
        Assert.Equal("guards", raid.Text);
        Assert.Equal(0m, raid.Value2);
        Assert.Equal(1000m, e.State.Bees);
        Assert.True(raid.Value > 0m);
        Assert.Equal(5000m - raid.Value, e.State.Honey);
    }

    [Fact]
    public void WithoutAGuard_ARaidStillSendsBeesOff()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, GuardBees = 0.9m, Honey = 5000m, WorkbenchRevealed = true });
        e.DebugCallWasp();
        var raid = e.ThrowShoe().Events.Single();
        Assert.Null(raid.Text);
        Assert.Equal(150m, raid.Value2);
        Assert.Equal(850m, e.State.Bees);
    }

    [Fact]
    public void WithAGuard_TheBribeAndTheShoeStillSaveTheHoney()
    {
        var e = Make(new BeekeeperState { Bees = 100m, GuardBees = 3m, Honey = 400m, WorkbenchRevealed = true });
        e.DebugCallWasp();
        Assert.True(e.Bribe().Done);
        Assert.Equal(300m, e.State.Honey);
        Assert.Equal(100m, e.State.Bees);
    }

    // ============================================================ bee bread

    [Fact]
    public void BeeBread_TakesTenPollenAndTenHoney_Instantly()
    {
        var e = Make(new BeekeeperState { PollenRevealed = true, Pollen = 25m, Honey = 15m });
        var r = e.MakeBeeBread();
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.BeeBreadMade));
        Assert.Equal(15m, e.State.Pollen);
        Assert.Equal(5m, e.State.Honey);
        Assert.Equal(1m, e.State.BeeBread);

        // only the first one is announced, and it needs both parts
        Assert.False(e.CanMakeBeeBread);
        e.State.Honey = 10m;
        Assert.False(Has(e.MakeBeeBread().Events, BeekeeperEvents.BeeBreadMade));
        Assert.Equal(2m, e.State.BeeBread);
    }

    [Fact]
    public void BeeBread_IsRefusedWithoutPollenOrHoney()
    {
        Assert.False(Make(new BeekeeperState { PollenRevealed = true, Pollen = 9m, Honey = 100m }).MakeBeeBread().Done);
        Assert.False(Make(new BeekeeperState { PollenRevealed = true, Pollen = 10m, Honey = 9m }).MakeBeeBread().Done);
    }

    // ============================================================ the wooden hive

    [Fact]
    public void TheWoodenHive_IsOfferedAfterTheFirstBeeBread_AndCosts200WaxAnd10BeeBread()
    {
        var e = Make(new BeekeeperState { Wax = 300m, BeeBread = 10m });
        Assert.False(e.WoodenHiveOffered);          // no bee bread made yet
        e.State.BeeBreadRevealed = true;
        Assert.True(e.WoodenHiveOffered);
        var r = e.MoveToWoodenHive();
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.WoodenHive));
        Assert.Equal(100m, e.State.Wax);
        Assert.Equal(0m, e.State.BeeBread);
        Assert.True(e.State.HasWoodenHive);
        Assert.False(e.WoodenHiveOffered);
    }

    [Fact]
    public void TheWoodenHive_IsRefusedWhenShort_OrAlreadyMoved()
    {
        Assert.False(Make(new BeekeeperState { BeeBreadRevealed = true, Wax = 199m, BeeBread = 10m }).MoveToWoodenHive().Done);
        Assert.False(Make(new BeekeeperState { BeeBreadRevealed = true, Wax = 500m, BeeBread = 9m }).MoveToWoodenHive().Done);
        Assert.False(Make(new BeekeeperState { BeeBreadRevealed = true, HasWoodenHive = true, Wax = 500m, BeeBread = 50m }).MoveToWoodenHive().Done);
    }

    [Fact]
    public void TheWoodenHive_GivesEveryHoneybee25PercentMoreHoney_AndChangesNothingElse()
    {
        var skep = Make(new BeekeeperState { Bees = 100m });
        var wood = Make(new BeekeeperState { Bees = 100m, HasWoodenHive = true, Combs = 2, Wax = 5m });
        Assert.Equal(1m, skep.HoneyPerSecond);
        Assert.Equal(1.25m, wood.HoneyPerSecond);

        wood.Advance(80m);
        Assert.Equal(100m, wood.State.Honey);       // 100 x 0.01 x 80 x 1.25
        Assert.Equal(100m, wood.State.Bees);
        Assert.Equal(2, wood.State.Combs);
    }

    // ============================================================ saving

    [Fact]
    public void AGardenInProgress_SurvivesSaveAndLoad()
    {
        var path = Path.Combine(_dir, "bk.json");
        var state = new BeekeeperState
        {
            Seeds = 1, SeedsGiven = 2, SeedsPlanted = 1, GrowSecondsLeft = 240m,
            Plants = { BeekeeperPlants.Wildflowers }, ForagerBees = 7.5m, GuardBees = 2m,
            Pollen = 12m, BeeBread = 3m, HasWoodenHive = true,
            GardenRevealed = true, PollenRevealed = true, BeeBreadRevealed = true,
        };
        Assert.True(BeekeeperSaveService.Save(state, path, DateTime.UtcNow));

        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(4, back.Version);
        Assert.Equal(1, back.Seeds);
        Assert.Equal(240m, back.GrowSecondsLeft);
        Assert.Equal(new[] { BeekeeperPlants.Wildflowers }, back.Plants);
        Assert.Equal(7.5m, back.ForagerBees);
        Assert.Equal(2m, back.GuardBees);
        Assert.Equal(12m, back.Pollen);
        Assert.Equal(3m, back.BeeBread);
        Assert.True(back.HasWoodenHive);
        Assert.True(back.GardenRevealed && back.PollenRevealed && back.BeeBreadRevealed);
    }

    [Fact]
    public void AVersion3Save_LoadsWithNothingLost()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "v3.json");
        File.WriteAllText(path,
            "{\"Version\":3,\"Bees\":120,\"Honey\":33,\"Wax\":80,\"Beebits\":9,\"Combs\":3,\"HippieTrades\":6,"
            + "\"Sage\":2,\"Upgrades\":[\"smoker\"],\"HoneyRevealed\":true,\"CalmMeter\":4,"
            + "\"Log\":[{\"Key\":\"first_bee\",\"Value\":0,\"Value2\":0}]}");

        var s = BeekeeperSaveService.Load(path)!;
        Assert.NotNull(s);
        Assert.Equal(120m, s.Bees);
        Assert.Equal(33m, s.Honey);
        Assert.Equal(3, s.Combs);
        Assert.Equal(6, s.HippieTrades);
        Assert.Equal(new[] { "smoker" }, s.Upgrades);
        Assert.Equal(4, s.CalmMeter);
        Assert.Single(s.Log);
        Assert.Equal(0, s.Seeds);
        Assert.Empty(s.Plants);
        Assert.False(s.HasWoodenHive);

        // 6 trades is past the first seed's trade: the next trade gives it
        var e = new BeekeeperEngine(BeekeeperConfig.Default, s, new FakeRandom());
        s.HippiesRevealed = true;
        s.BeeswaxCandles = 20m;
        e.TradeTenCandles();
        Assert.Equal(1, s.Seeds);
    }

    [Fact]
    public void ASaveWithNegativeGardenAmounts_IsRefused()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "bad.json");
        File.WriteAllText(path, "{\"Version\":4,\"Pollen\":-5}");
        Assert.Null(BeekeeperSaveService.Load(path));
    }
}
