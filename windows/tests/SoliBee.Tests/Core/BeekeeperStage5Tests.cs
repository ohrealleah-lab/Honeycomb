using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 5 rules (spec 013): the queen, the brood, the pantry, the slice cap and the trade agreement.</summary>
public class BeekeeperStage5Tests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage5-tests-" + Guid.NewGuid().ToString("N"));

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

    // A wooden hive with the queen settled, lots of room, and `beeBread` in the pantry.
    // 0.01 honey per bee per second × 1.25 for the wooden hive = 0.0125.
    private static BeekeeperState Queen(decimal beeBread, decimal bees = 1000m, int combs = 1000) => new()
    {
        Bees = bees, HasWoodenHive = true, QueenSettled = true, BeeBread = beeBread,
        BeeBreadRevealed = true, Combs = combs, HoneyRevealed = true, BearName = "Bruno",
        BearRevealed = true, WaxRevealed = true, CombsRevealed = true, ShopRevealed = true, BeebitsRevealed = true,
    };

    private const double Places = 6;

    // ============================================================ the queen settles

    [Fact]
    public void MovingToTheWoodenHive_SettlesTheQueen()
    {
        var e = Make(new BeekeeperState { Bees = 100m, Wax = 200m, BeeBread = 15m, BeeBreadRevealed = true });
        var r = e.MoveToWoodenHive();
        Assert.True(r.Done);
        Assert.True(Has(r.Events, BeekeeperEvents.QueenSettles));
        Assert.True(e.HasQueen);
        Assert.True(e.IsQueenLaying);   // 5 bee bread left over
    }

    [Fact]
    public void MovingInWithAnEmptyPantry_SaysNothingUntilBeeBreadComes()
    {
        var e = Make(new BeekeeperState { Bees = 100m, Wax = 200m, BeeBread = 10m, BeeBreadRevealed = true });
        var r = e.MoveToWoodenHive();
        Assert.False(Has(r.Events, BeekeeperEvents.PantryEmpty));
        Assert.False(e.IsQueenLaying);
        Assert.False(Has(e.Advance(60m).Events, BeekeeperEvents.PantryEmpty));
        Assert.Equal(100m, e.State.Bees);

        var g = e.DebugGiveBeeBread(10m);
        Assert.True(Has(g, BeekeeperEvents.QueenResumes));
        Assert.True(e.IsQueenLaying);
    }

    [Fact]
    public void TheSkep_HasNoQueen_EvenWithBeeBread()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, BeeBread = 50m, Combs = 100 });
        e.Advance(600m);
        Assert.Equal(1000m, e.State.Bees);
        Assert.Equal(50m, e.State.BeeBread);
        Assert.False(e.HasQueen);
    }

    [Fact]
    public void AnOlderSaveWithTheWoodenHive_GetsTheQueenOnLoad()
    {
        var e = Make(new BeekeeperState { Bees = 100m, HasWoodenHive = true, BeeBread = 3m });
        var events = e.RevealOnLoad();
        Assert.True(Has(events, BeekeeperEvents.QueenSettles));
        Assert.True(e.IsQueenLaying);
        Assert.Empty(e.RevealOnLoad());   // only once
    }

    // ============================================================ laying and the pantry

    [Fact]
    public void TheQueen_Raises20BeesAMinute_AndEats1BeeBreadPer100()
    {
        var e = Make(Queen(10m));
        var r = e.Advance(60m);
        Assert.Equal(1020m, e.State.Bees);
        Assert.Equal(9.8m, e.State.BeeBread);
        Assert.Equal(20m, r.BeesRaised);
    }

    [Fact]
    public void HoneyOverAStretch_IsTheAreaUnderTheGrowingLine()
    {
        var e = Make(Queen(10m));
        e.AdvanceAway(60m);
        // 0.0125 × (1000 × 60 + 20/60 × 60² / 2) = 0.0125 × 60,600
        Assert.Equal(757.5, (double)e.State.Honey, Places);
    }

    [Fact]
    public void ThePantryRunsOutPartway_GrowthBefore_FlatAfter()
    {
        var e = Make(Queen(1m));   // feeds 100 bees: 300 seconds of laying
        var r = e.Advance(600m);
        Assert.Equal(1100m, e.State.Bees);
        Assert.Equal(0m, e.State.BeeBread);
        Assert.True(Has(r.Events, BeekeeperEvents.PantryEmpty));
        Assert.False(e.IsQueenLaying);
        // 0.0125 × (1000 × 600 + (1/3) × 300² / 2 + 100 × 300)
        Assert.Equal(8062.5, (double)e.State.Honey, Places);
    }

    [Fact]
    public void ThePantryEmptyLine_ComesOnce_AndBeeBreadNeverGoesNegative()
    {
        var e = Make(Queen(0.5m));
        Assert.True(Has(e.Advance(600m).Events, BeekeeperEvents.PantryEmpty));
        Assert.False(Has(e.Advance(600m).Events, BeekeeperEvents.PantryEmpty));
        Assert.Equal(0m, e.State.BeeBread);
        Assert.Equal(1050m, e.State.Bees);
    }

    [Fact]
    public void FreshBeeBread_StartsARestingQueenAgain()
    {
        var e = Make(Queen(0.1m));
        e.State.Pollen = 100m;
        e.State.PollenRevealed = true;
        e.State.Honey = 100m;
        e.Advance(60m);
        Assert.False(e.IsQueenLaying);

        var r = e.MakeBeeBread();
        Assert.True(Has(r.Events, BeekeeperEvents.QueenResumes));
        Assert.True(e.IsQueenLaying);
        Assert.False(Has(e.MakeBeeBread().Events, BeekeeperEvents.QueenResumes));   // already laying
    }

    [Fact]
    public void RaisedBees_AreOrdinaryBees_AndARaidTakesNone()
    {
        var e = Make(Queen(10m, bees: 0m));
        e.State.WorkbenchRevealed = true;
        e.Advance(60m);
        Assert.Equal(20m, e.State.Bees);
        e.DebugCallWasp();
        e.AdvanceWaspCountdown(60m);
        Assert.Equal(20m, e.State.Bees);   // stage 6: raids take only honey
    }

    [Fact]
    public void TheCalmPart_SeesTheGrowingHiveToo()
    {
        var e = Make(Queen(10m));
        e.State.CalmSecondsLeft = 60m;
        e.Advance(120m);
        // Calm first: 2 × (1000×60 + 600) = 121,200; then (1020×60 + 600) = 61,800. × 0.0125
        Assert.Equal(2287.5, (double)e.State.Honey, Places);
        Assert.Equal(1040m, e.State.Bees);
    }

    [Fact]
    public void HoverRates_FollowTheQueen()
    {
        var e = Make(Queen(10m));
        Assert.Equal(1.0 / 3.0, (double)e.QueenBeesPerSecondNow, Places);
        Assert.Equal(1.0 / 300.0, (double)e.BeeBreadPerSecondNow, Places);
        Assert.Equal(3000m, e.PantrySecondsLeft);   // 10 bee bread last 50 minutes

        e.State.BeeBread = 0m;
        Assert.Equal(0m, e.QueenBeesPerSecondNow);
        Assert.Equal(0m, e.BeeBreadPerSecondNow);
        Assert.Equal(0m, e.PantrySecondsLeft);
    }

    [Fact]
    public void TheLayingRate_BelongsToTheHiveStep()
    {
        var config = new BeekeeperConfig { QueenBeesPerMinute = new[] { 0m, 60m } };
        var e = new BeekeeperEngine(config, Queen(10m), new FakeRandom());
        e.Advance(60m);
        Assert.Equal(1060m, e.State.Bees);
    }

    // ============================================================ live and away agree (FR-403)

    private static void AssertSame(BeekeeperEngine live, BeekeeperEngine away)
    {
        Assert.Equal((double)live.State.Bees, (double)away.State.Bees, Places);
        Assert.Equal((double)live.State.Honey, (double)away.State.Honey, Places);
        // Wax drops in whole batches, so a hair of rounding can land either side of a batch:
        // compare all the honey counted towards wax instead, and the wax to within one batch.
        decimal waxHoney(BeekeeperEngine x) => x.State.Wax / x.WaxPerBatch * x.Config.HoneyPerWax + x.State.WaxProgress;
        Assert.Equal((double)waxHoney(live), (double)waxHoney(away), 4);
        Assert.True(Math.Abs(live.State.Wax - away.State.Wax) <= live.WaxPerBatch);
        Assert.Equal((double)live.State.BeeBread, (double)away.State.BeeBread, Places);
        Assert.Equal(live.State.Beebits, away.State.Beebits);
        Assert.Equal((double)live.State.AgreementHoneyProgress, (double)away.State.AgreementHoneyProgress, 4);
    }

    private static (BeekeeperEngine live, BeekeeperEngine away) RunBoth(Func<BeekeeperState> start, int seconds)
    {
        var live = Make(start());
        for (int i = 0; i < seconds; i++) live.Advance(1m);
        var away = Make(start());
        away.AdvanceAway(seconds);
        return (live, away);
    }

    [Fact]
    public void LiveAndAway_Agree_WithALayingQueen()
    {
        var (live, away) = RunBoth(() => Queen(100m), 3600);
        AssertSame(live, away);
        Assert.Equal(2200m, Math.Round(away.State.Bees, 6));
    }

    [Fact]
    public void LiveAndAway_Agree_WhenThePantryRunsOutPartway()
    {
        var (live, away) = RunBoth(() => Queen(2m), 1800);   // runs out at 600 s
        AssertSame(live, away);
        Assert.Equal(0m, away.State.BeeBread);
        Assert.Equal(1200m, away.State.Bees);
    }

    [Fact]
    public void LiveAndAway_Agree_WithFullCombsAndTheAgreement()
    {
        BeekeeperState Start()
        {
            var s = Queen(5m, combs: 0);
            s.Honey = 150m;
            s.HasTradeAgreement = true;
            s.Trades = 100;
            return s;
        }
        var (live, away) = RunBoth(Start, 3600);
        AssertSame(live, away);
        Assert.Equal(200m, away.State.Honey);
        Assert.True(away.State.Beebits > 0m);
    }

    // ============================================================ the slice cap

    [Fact]
    public void TheSlice_IsCappedAt10TimesTheToolsBees()
    {
        var e = Make(new BeekeeperState
        {
            Bees = 5_000_000m, ToolLevel = 6,
            Upgrades = { BeekeeperUpgrades.Practice, BeekeeperUpgrades.MorePractice },
        });
        Assert.Equal(300, e.BeesPerClick);
        Assert.Equal(3300m, e.BeesPerCatch);
        Assert.Equal(3300m, e.Catch().BeesGained);
    }

    [Fact]
    public void BelowTheCap_TheSliceIsUnchanged()
    {
        var e = Make(new BeekeeperState { Bees = 250_000m, ToolLevel = 6 });
        Assert.Equal(400m, e.BeesPerCatch);   // 150 + 250
    }

    // ============================================================ the trade agreement

    [Fact]
    public void TheHundredthBearTrade_BringsTheAgreement()
    {
        var e = Make(new BeekeeperState { BearRevealed = true, BearName = "Bruno", Trades = 99, Honey = 100m });
        var r = e.SellAll();
        var offer = r.Events.Single(x => x.Key == BeekeeperEvents.TradeAgreement);
        Assert.Equal("Bruno", offer.Text);
        Assert.True(e.State.HasTradeAgreement);
        Assert.Equal(100, e.State.Trades);   // Sell All counts as one
        Assert.False(Has(e.SellTen().Events, BeekeeperEvents.TradeAgreement));
    }

    [Fact]
    public void AnOlderSavePast100Trades_GetsTheAgreementOnLoad()
    {
        var e = Make(new BeekeeperState { BearRevealed = true, BearName = "Bruno", Trades = 150 });
        Assert.True(Has(e.RevealOnLoad(), BeekeeperEvents.TradeAgreement));
        Assert.True(e.State.HasTradeAgreement);
    }

    [Fact]
    public void WithTheAgreement_OverflowSellsAtHalfPrice_FractionsKept()
    {
        // Skep, 1000 bees: 10 honey a second. Combs full, so 30 s = 300 honey, all overflow.
        var e = Make(new BeekeeperState { Bees = 1000m, Honey = 200m, HasTradeAgreement = true, BearName = "Bruno" });
        var r = e.Advance(31m);
        Assert.Equal(15m, e.State.Beebits);            // 310 / 20 = 15, 10 honey kept towards the next
        Assert.Equal(10m, e.State.AgreementHoneyProgress);
        Assert.Equal(15m, r.AgreementBeebits);
        Assert.Equal(200m, e.State.Honey);
        Assert.Equal(6m, e.State.Wax);                 // wax still follows all 310 honey made
    }

    [Fact]
    public void WithoutTheAgreement_OverflowIsLost()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, Honey = 200m, BearName = "Bruno" });
        e.Advance(30m);
        Assert.Equal(0m, e.State.Beebits);
        Assert.Equal(0m, e.State.AgreementHoneyProgress);
    }

    [Fact]
    public void SellingByHand_StaysAtFullPrice_AndAutoSalesAreNotTrades()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, Honey = 200m, HasTradeAgreement = true, BearRevealed = true, Trades = 100, BearName = "Bruno" });
        e.Advance(20m);
        Assert.Equal(100, e.State.Trades);
        decimal before = e.State.Beebits;
        e.SellTen();
        Assert.Equal(before + 1m, e.State.Beebits);
        Assert.Equal(190m, e.State.Honey);
    }

    [Fact]
    public void CalmBees_SendTheirDoubleHoneyToTheBearToo()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, Honey = 200m, HasTradeAgreement = true, CalmSecondsLeft = 60m, BearName = "Bruno" });
        e.Advance(20m);   // 20 honey a second while calm
        Assert.Equal(20m, e.State.Beebits);
    }

    [Fact]
    public void AgreementRate_ShowsOnlyWhileTheCombsAreFull()
    {
        var e = Make(new BeekeeperState { Bees = 1000m, Honey = 200m, HasTradeAgreement = true });
        Assert.Equal(0.5m, e.AgreementBeebitsPerSecondNow);
        e.State.Honey = 100m;
        Assert.Equal(0m, e.AgreementBeebitsPerSecondNow);
    }

    // ============================================================ welcome back

    [Fact]
    public void WelcomeBack_SaysWhatHappened_LineByLine()
    {
        var s = Queen(10m, combs: 0);
        s.HasTradeAgreement = true;
        var e = Make(s);
        var r = e.AdvanceAway(8m * 3600m);
        var keys = r.Events.Select(x => x.Key).Where(BeekeeperEvents.IsWelcomeBack).ToList();
        // Added bottom line first, so the log (newest first) reads honey, queen, bear, pantry.
        Assert.Equal(new[]
        {
            BeekeeperEvents.WelcomeBackPantry, BeekeeperEvents.WelcomeBackBear,
            BeekeeperEvents.WelcomeBackQueen, BeekeeperEvents.WelcomeBack,
        }, keys);
        Assert.False(Has(r.Events, BeekeeperEvents.PantryEmpty));
        Assert.Equal(1000m, r.Events.Single(x => x.Key == BeekeeperEvents.WelcomeBackQueen).Value);
        Assert.Equal(e.State.Beebits, r.Events.Single(x => x.Key == BeekeeperEvents.WelcomeBackBear).Value);
        Assert.True(r.PantryEmptied);
    }

    [Fact]
    public void WelcomeBack_LeavesOutWhatDidNotHappen()
    {
        var e = Make(new BeekeeperState { Bees = 10m, Combs = 10 });
        var keys = e.AdvanceAway(600m).Events.Select(x => x.Key).Where(BeekeeperEvents.IsWelcomeBack).ToList();
        Assert.Equal(new[] { BeekeeperEvents.WelcomeBack }, keys);
    }

    // ============================================================ saving (version 5)

    [Fact]
    public void TheQueenAndTheAgreement_SurviveASave()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "v5.json");
        var s = Queen(4.5m);
        s.HasTradeAgreement = true;
        s.AgreementHoneyProgress = 12.25m;
        s.PantryEmptyAnnounced = true;
        Assert.True(BeekeeperSaveService.Save(s, path, DateTime.UtcNow));

        var back = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.CurrentVersion, back.Version);
        Assert.True(back.QueenSettled);
        Assert.True(back.HasTradeAgreement);
        Assert.Equal(12.25m, back.AgreementHoneyProgress);
        Assert.Equal(4.5m, back.BeeBread);
        Assert.True(back.PantryEmptyAnnounced);
    }

    [Fact]
    public void AVersion4Save_LoadsWithNothingLost_AndGetsTheQueenAndAgreement()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "v4.json");
        File.WriteAllText(path, "{\"Version\":4,\"Bees\":5000,\"Honey\":120.5,\"Wax\":30,\"Beebits\":77,\"BearName\":\"Bruno\","
            + "\"BearRevealed\":true,\"Trades\":140,\"HasWoodenHive\":true,\"BeeBread\":7,\"Pollen\":3,\"ForagerBees\":12}");
        var s = BeekeeperSaveService.Load(path)!;
        Assert.Equal(5000m, s.Bees);
        Assert.Equal(120.5m, s.Honey);
        Assert.Equal(77m, s.Beebits);
        Assert.Equal(7m, s.BeeBread);
        Assert.Equal(12m, s.ForagerBees);
        Assert.False(s.QueenSettled);
        Assert.False(s.HasTradeAgreement);

        var e = Make(s);
        var events = e.RevealOnLoad();
        Assert.True(Has(events, BeekeeperEvents.QueenSettles));
        Assert.True(Has(events, BeekeeperEvents.TradeAgreement));
    }

    [Fact]
    public void ANegativeAgreementProgress_IsRejected()
    {
        Directory.CreateDirectory(_dir);
        var path = Path.Combine(_dir, "bad.json");
        File.WriteAllText(path, "{\"Version\":5,\"AgreementHoneyProgress\":-1}");
        Assert.Null(BeekeeperSaveService.Load(path));
    }
}
