using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 6 on the view-model side (spec 014): the Hive card in groups, the wasps on the
/// Trading card, No Stress Mode ignored, the emissary ending wasps, old saves, saving.</summary>
public class BeekeeperStage6ViewModelTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-stage6-vm-tests-" + Guid.NewGuid().ToString("N"));
    private string SavePath => Path.Combine(_dir, "beekeeper.json");

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class Clock
    {
        public DateTime Now { get; set; } = new(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc);
        public void Advance(double seconds) => Now = Now.AddSeconds(seconds);
        public Func<DateTime> Func => () => Now;
    }

    /// <summary>0.0: the first wasp comes after 4 minutes; shoes always hit.</summary>
    private sealed class LowRandom : IRandomSource
    {
        public double NextDouble() => 0.0;
        public int Next(int maxExclusive) => 0;
    }

    private BeekeeperViewModel Make(Clock clock, BeekeeperState? state = null, bool persist = false, bool noStress = false)
        => new(isHeadless: true, config: new BeekeeperConfig { StartingStorage = 1_000_000m }, rng: new LowRandom(),
               clock: clock.Func, persist: persist, savePath: SavePath, initialState: state, noStressMode: () => noStress);

    private static bool Logged(BeekeeperViewModel vm, string key) => vm.Log.Any(e => e.Key == key);

    private static void Play(BeekeeperViewModel vm, Clock clock, int seconds)
    {
        for (int i = 0; i < seconds; i++)
        {
            clock.Advance(1);
            vm.NoteActivity();
            vm.Tick();
        }
    }

    private static BeekeeperHiveGroup Group(BeekeeperViewModel vm, string id) => vm.HiveGroups.Single(g => g.Id == id);

    private static BeekeeperHiveRow? Row(BeekeeperViewModel vm, string id) =>
        vm.HiveGroups.SelectMany(g => g.Rows).FirstOrDefault(r => r.Id == id);

    private static BeekeeperState Workshop() => new()
    {
        Bees = 1000m, Honey = 50_000m, Combs = 2, WorkbenchRevealed = true, HoneyRevealed = true, BearName = "Bruno",
        BearRevealed = true,
    };

    // ============================================================ the Hive card in groups (User Story 9)

    [Fact]
    public void TheHiveCard_IsInGroups_InOrder_AndEmptyGroupsAreHidden()
    {
        var vm = Make(new Clock(), new BeekeeperState { Bees = 5m, HoneyRevealed = true, BearName = "Bruno" });
        Assert.Equal(new[]
        {
            BeekeeperHiveRows.GroupBees, BeekeeperHiveRows.GroupHive, BeekeeperHiveRows.GroupGarden,
            BeekeeperHiveRows.GroupCrafts, BeekeeperHiveRows.GroupTradeGoods,
        }, vm.HiveGroups.Select(g => g.Id));
        Assert.True(Group(vm, BeekeeperHiveRows.GroupBees).Visible);
        Assert.True(Group(vm, BeekeeperHiveRows.GroupHive).Visible);
        Assert.False(Group(vm, BeekeeperHiveRows.GroupGarden).Visible);
        Assert.False(Group(vm, BeekeeperHiveRows.GroupCrafts).Visible);
        Assert.False(Group(vm, BeekeeperHiveRows.GroupTradeGoods).Visible);
        Assert.Equal(5m, Row(vm, BeekeeperHiveRows.Honeybees)!.Value);
    }

    [Fact]
    public void EveryRowIsInItsGroup()
    {
        var vm = Make(new Clock(), Workshop());
        string[] Ids(string g) => Group(vm, g).Rows.Select(r => r.Id).ToArray();
        Assert.Equal(new[] { BeekeeperHiveRows.Honeybees, BeekeeperHiveRows.Queen }, Ids(BeekeeperHiveRows.GroupBees));
        Assert.Equal(new[] { BeekeeperHiveRows.Honey, BeekeeperHiveRows.Wax, BeekeeperHiveRows.Combs, BeekeeperHiveRows.CombsFull },
            Ids(BeekeeperHiveRows.GroupHive));
        Assert.Equal(new[] { BeekeeperHiveRows.Seeds, BeekeeperHiveRows.Pollen, BeekeeperHiveRows.BeeBread, BeekeeperHiveRows.Propolis },
            Ids(BeekeeperHiveRows.GroupGarden));
        Assert.Equal(new[]
        {
            BeekeeperHiveRows.BeeswaxCandles, BeekeeperHiveRows.RepellentCandles,
            BeekeeperHiveRows.BeeBoostCandles, BeekeeperHiveRows.SagePropolisCandles,
            BeekeeperHiveRows.BeeBoostBurning, BeekeeperHiveRows.SagePropolisBurning,
        }, Ids(BeekeeperHiveRows.GroupCrafts));
        Assert.Equal(new[] { BeekeeperHiveRows.Beebits, BeekeeperHiveRows.Sage, BeekeeperHiveRows.Paper }, Ids(BeekeeperHiveRows.GroupTradeGoods));
    }

    [Fact]
    public void Specialties_ShowInTheBeesGroup_AndThereAreNoCountRows()
    {
        var s = Workshop();
        s.Plants.AddRange(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble });
        s.ForagerBees = 40m;
        s.GuardBees = 9m;
        s.PollenRevealed = true;
        var vm = Make(new Clock(), s);
        var bees = Group(vm, BeekeeperHiveRows.GroupBees).Rows.Where(r => r.Visible).Select(r => r.Id).ToArray();
        Assert.Equal(new[] { BeekeeperHiveRows.Honeybees, BeekeeperHiveRows.Foraging, BeekeeperHiveRows.Guarding }, bees);
        Assert.Equal(3m, Row(vm, BeekeeperHiveRows.Foraging)!.Value);
        Assert.Equal(25m, Row(vm, BeekeeperHiveRows.Guarding)!.Value);
        Assert.Equal(new[] { BeekeeperSpecialties.Foraging, BeekeeperSpecialties.Guarding }, vm.Specialties);
    }

    [Fact]
    public void TheHoverRates_IncludePollenAndGuarding()
    {
        var s = Workshop();
        s.Plants.AddRange(new[] { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble });
        s.PollenRevealed = true;
        s.WaxRevealed = true;
        var vm = Make(new Clock(), s);
        Assert.Equal(0.05m, Row(vm, BeekeeperHiveRows.Pollen)!.Rate);
        Assert.Equal(12.5m, Row(vm, BeekeeperHiveRows.Honey)!.Rate);      // 1,000 bees × 0.01 × 1.25
        Assert.Equal(vm.WaxPerSecond, Row(vm, BeekeeperHiveRows.Wax)!.Rate);
        Assert.Null(Row(vm, BeekeeperHiveRows.Honeybees)!.Rate);          // no queen yet
    }

    [Fact]
    public void TheQueensRates_StillShowOnHover()
    {
        var s = Workshop();
        s.HasWoodenHive = true;
        s.QueenSettled = true;
        s.BeeBread = 3m;
        s.BeeBreadRevealed = true;
        var vm = Make(new Clock(), s);
        Assert.Equal(vm.QueenBeesPerSecond, Row(vm, BeekeeperHiveRows.Honeybees)!.Rate);
        Assert.Equal(1m, Row(vm, BeekeeperHiveRows.Queen)!.Value);   // laying
        var bread = Row(vm, BeekeeperHiveRows.BeeBread)!;
        Assert.Equal(vm.BeeBreadPerSecond, bread.Rate);
        Assert.Equal(vm.PantrySecondsLeft, bread.Rate2);
    }

    // ============================================================ old saves (User Story 3)

    [Fact]
    public void AnOldSave_SaysOnce_ThatTheForagersAndGuardsSettledIn()
    {
        var s = Workshop();
        s.Plants.Add(BeekeeperPlants.Wildflowers);
        s.ForagerBees = 12m;
        var vm = Make(new Clock(), s, persist: true);
        Assert.True(Logged(vm, BeekeeperEvents.OldCountsSettle));
        vm.SaveNow();
        vm.Dispose();

        var again = Make(new Clock(), state: null, persist: true);
        Assert.Single(again.Log, e => e.Key == BeekeeperEvents.OldCountsSettle);
    }

    // ============================================================ No Stress Mode (User Story 11)

    [Fact]
    public void NoStressMode_DoesNotKeepWaspsAway()
    {
        var clock = new Clock();
        var vm = Make(clock, Workshop(), noStress: true);
        vm.IsWatched = true;
        Play(vm, clock, 240);
        Assert.True(vm.WaspApproaching);
        Play(vm, clock, 60);
        Assert.True(Logged(vm, BeekeeperEvents.WaspRaid));
        Assert.Equal(1000m, vm.Bees);   // only honey taken
    }

    // ============================================================ the emissary (User Stories 6, 7, 8)

    [Fact]
    public void BribesToFour_ThenOneMoreBribe_BringsTheEmissary_AndNoWaspEverComesAgain()
    {
        var clock = new Clock();
        var vm = Make(clock, Workshop());
        vm.IsWatched = true;
        vm.DebugBribesToAlmostEmissary();
        vm.DebugCallWasp();
        vm.BribeCommand.Execute(null);
        Assert.Equal(BeekeeperEvents.Emissary, vm.Log[0].Key);    // newest line, straight after the bribe
        Assert.Equal(BeekeeperEvents.Bribe, vm.Log[1].Key);
        Assert.True(vm.EmissaryCome);

        vm.DebugCallWasp();
        Play(vm, clock, 3000);
        Assert.False(vm.WaspApproaching);
        Assert.Equal(1, vm.Log.Count(e => e.Key == BeekeeperEvents.WaspArrives));   // only the one bribed away
    }

    [Fact]
    public void TheWasps_JoinTheTradingCard_AfterTheBearAndTheHippies()
    {
        var s = Workshop();
        s.HippiesRevealed = true;
        var vm = Make(new Clock(), s);
        Assert.DoesNotContain(vm.TradeOffers, o => o.Id == "wasps");
        vm.DebugBringEmissary();
        Assert.Equal(new[] { "bear", "hippies", "wasps" }, vm.TradeOffers.Select(o => o.Id));
        var wasps = vm.TradeOffers.Last();
        Assert.Equal(50m, wasps.GiveAmount);
        Assert.Equal("honey", wasps.Give);
        Assert.Equal("paper", wasps.Get);
        Assert.NotNull(wasps.TradeTimes);
        Assert.True(wasps.CanTradeTimes!(100));
    }

    [Fact]
    public void TradingForPaper_ShowsPaper_AndCountsTheWaspsTrades()
    {
        var s = Workshop();
        s.Honey = 600m;
        var vm = Make(new Clock(), s);
        vm.DebugBringEmissary();
        Assert.False(Row(vm, BeekeeperHiveRows.Paper)!.Visible);

        var wasps = vm.TradeOffers.Single(o => o.Id == "wasps");
        Assert.True(wasps.CanTradeTimes!(10));
        Assert.False(wasps.CanTradeTimes!(100));
        wasps.TradeTimes!(10);
        Assert.Equal(10m, vm.Paper);
        Assert.Equal(1, vm.WaspTrades);
        Assert.Equal(100m, vm.Honey);
        Assert.True(Row(vm, BeekeeperHiveRows.Paper)!.Visible);
        Assert.Null(Row(vm, BeekeeperHiveRows.Paper)!.Rate);   // paper has no hover rate
        Assert.True(Logged(vm, BeekeeperEvents.FirstPaper));
        Assert.Equal(1, vm.TradeOffers.Single(o => o.Id == "wasps").Trades);
    }

    [Fact]
    public void AfterTheEmissary_RepellentCandlesAreHidden()
    {
        var s = Workshop();
        s.RepellentUnlocked = true;
        s.RepellentCandles = 2m;
        s.RepellentSecondsLeft = 100m;
        var vm = Make(new Clock(), s);
        Assert.True(vm.RepellentShown);
        Assert.True(Row(vm, BeekeeperHiveRows.RepellentCandles)!.Visible);

        vm.DebugBringEmissary();
        Assert.False(vm.RepellentShown);
        Assert.False(vm.CanLightRepellent);
        Assert.False(Row(vm, BeekeeperHiveRows.RepellentCandles)!.Visible);
        Assert.Equal(2m, vm.RepellentCandles);
    }

    [Fact]
    public void TheEmissaryAndPaper_SurviveClosingAndReopening()
    {
        var clock = new Clock();
        var s = Workshop();
        s.Plants.Add(BeekeeperPlants.Bramble);
        var first = Make(clock, s, persist: true);
        first.DebugBringEmissary();
        first.TradePaperTimes(10);
        first.Dispose();

        clock.Advance(3600);
        var second = Make(clock, state: null, persist: true);
        second.IsWatched = true;
        Assert.True(second.EmissaryCome);
        Assert.Equal(10m, second.Paper);
        Assert.Equal(1, second.WaspTrades);
        Assert.Equal(new[] { BeekeeperSpecialties.Guarding }, second.Specialties);
        Play(second, clock, 600);
        Assert.False(second.WaspApproaching);
    }

    [Fact]
    public void DebugGiveHoney_AddsFiveHundred()
    {
        var vm = Make(new Clock(), Workshop());
        decimal before = vm.Honey;
        vm.DebugGiveHoney(500m);
        Assert.Equal(before + 500m, vm.Honey);
    }
}
