using System;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Stage 10 (spec 019) on the screen's side: the Clay jars and Potted honey rows, the Pot
/// honey button, the bear's potted-honey sale, the Hippies' jar trade, the beeswax candle, the
/// opening card, the hovers (Beebits, clay jars, herbs) and the debug shortcuts.</summary>
public class BeekeeperStage10ViewModelTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private sealed class Clock
    {
        public DateTime Now { get; set; } = new(2026, 11, 12, 12, 0, 0, DateTimeKind.Utc);
        public void Advance(double seconds) => Now = Now.AddSeconds(seconds);
    }

    private static BeekeeperViewModel Make(BeekeeperState? state = null, Clock? clock = null)
    {
        clock ??= new Clock();
        return new(isHeadless: true, persist: false, rng: new NoRandom(), clock: () => clock.Now, initialState: state);
    }

    private static BeekeeperHiveRow Row(BeekeeperViewModel vm, string id) =>
        vm.HiveGroups.SelectMany(g => g.Rows).Single(r => r.Id == id);

    private static bool Logged(BeekeeperViewModel vm, string key) => vm.Log.Any(e => e.Key == key);

    private static BeekeeperState Bear(Action<BeekeeperState>? more = null)
    {
        var s = new BeekeeperState { BearName = "Bruno", HoneyRevealed = true, BearRevealed = true };
        s.RepsMet.Add("bear");
        s.RepsEngaged.Add("bear");
        more?.Invoke(s);
        return s;
    }

    // ============================================================ the opening

    [Fact]
    public void ANewGame_ShowsTheHiveCardWithThreeJars_AndTheOpeningCard()
    {
        var clock = new Clock();
        var vm = Make(clock: clock);
        Assert.True(vm.HiveCardShown);
        var jars = Row(vm, BeekeeperHiveRows.ClayJars);
        Assert.True(jars.Visible);
        Assert.Equal(3m, jars.Value);
        Assert.False(Row(vm, BeekeeperHiveRows.Honey).Visible);
        Assert.False(vm.PotHoneyShown);

        clock.Advance(1);
        vm.Tick();
        Assert.Equal(BeekeeperStories.Opening, vm.StoryHere);
        vm.BeginFromStory();
        Assert.Null(vm.StoryHere);
    }

    [Fact]
    public void CatchingABee_SendsTheOpeningCardAway()
    {
        var clock = new Clock();
        var vm = Make(clock: clock);
        clock.Advance(1);
        vm.Tick();
        vm.Catch();
        Assert.Null(vm.StoryHere);
        Assert.True(vm.PotHoneyShown);   // the first bee starts the honey
    }

    // ============================================================ potting

    [Fact]
    public void PotHoney_IsDisabledWhenShort_AndAddsThePottedRowOnce()
    {
        var vm = Make(new BeekeeperState { HoneyRevealed = true, Honey = 5m });
        Assert.True(vm.PotHoneyShown);
        Assert.False(vm.PotHoneyCommand.CanExecute(null));
        Assert.False(Row(vm, BeekeeperHiveRows.PottedHoney).Visible);

        vm.State.Honey = 20m;
        Assert.True(vm.PotHoneyCommand.CanExecute(null));
        vm.PotHoneyCommand.Execute(null);
        Assert.Equal(10m, vm.Honey);
        Assert.Equal(2m, vm.ClayJars);
        var row = Row(vm, BeekeeperHiveRows.PottedHoney);
        Assert.True(row.Visible);
        Assert.Equal(1m, row.Value);
        Assert.True(Logged(vm, BeekeeperEvents.HoneyPotted));
    }

    // ============================================================ the bear

    [Fact]
    public void TheBearsCard_OffersPottedHoney_OnceTheFirstIsMade()
    {
        var vm = Make(Bear(s => s.Honey = 10m));
        var bear = vm.TradeOffers.Single(o => o.Id == "bear");
        Assert.Equal(("honey", "beebits", 10m, 5m), (bear.Give, bear.Get, bear.GiveAmount, bear.GetAmount));
        Assert.False(bear.PottedShown);

        vm.State.PottedHoney = 2m;
        vm.State.PottedHoneyRevealed = true;
        bear = vm.TradeOffers.Single(o => o.Id == "bear");
        Assert.True(bear.PottedShown);
        Assert.True(bear.CanSellPotted);
        Assert.Equal(15m, bear.PottedGet);
        bear.SellPotted!();
        Assert.Equal(15m, vm.Beebits);
        Assert.Equal(1, vm.Trades);
        vm.TradeOffers.Single(o => o.Id == "bear").SellAllPotted!();
        Assert.Equal(30m, vm.Beebits);
        Assert.Equal(2, vm.Trades);
        Assert.False(vm.TradeOffers.Single(o => o.Id == "bear").CanSellPotted);
        Assert.True(Logged(vm, BeekeeperEvents.PottedSale));
    }

    [Fact]
    public void WhileTheBearIsAway_ThereIsNoSale()
    {
        var s = Bear(x => { x.PottedHoney = 3m; x.PottedHoneyRevealed = true; x.Honey = 50m; });
        s.RepsEngaged.Clear();
        s.RepsPresent.Add("bear");   // at the door, not yet engaged (or sent off with a shoe)
        var vm = Make(s);
        Assert.DoesNotContain(vm.TradeOffers, o => o.Id == "bear");
    }

    // ============================================================ the Hippies and the beeswax candle

    [Fact]
    public void TheHippiesOffer_IsThreeBeeswaxCandlesForAJar()
    {
        var s = new BeekeeperState { HippiesRevealed = true, BeeswaxCandles = 7m };
        s.RepsMet.Add("hippies");
        s.RepsEngaged.Add("hippies");
        var vm = Make(s);
        var hippies = vm.TradeOffers.Single(o => o.Id == "hippies");
        Assert.Equal(("beeswax_candles", "clay_jars", 3m, 1m), (hippies.Give, hippies.Get, hippies.GiveAmount, hippies.GetAmount));
        hippies.TradeAll();
        Assert.Equal(5m, vm.ClayJars);
        Assert.Equal(1m, vm.BeeswaxCandles);
        Assert.Equal(0m, vm.Beebits);
    }

    [Fact]
    public void TheBeeswaxCandle_ShowsWithTheWorkbench_AndHasItsRow()
    {
        var vm = Make(new BeekeeperState { Wax = 30m });
        Assert.False(vm.BeeswaxShown);
        Assert.False(Row(vm, BeekeeperHiveRows.BeeswaxCandles).Visible);

        vm.State.WorkbenchRevealed = true;
        Assert.True(vm.BeeswaxShown);
        Assert.True(vm.CraftBeeswaxCommand.CanExecute(null));
        vm.CraftBeeswaxCommand.Execute(null);
        Assert.Equal(1m, Row(vm, BeekeeperHiveRows.BeeswaxCandles).Value);
        Assert.True(vm.CanCraftBeeswaxTimes(10));
        vm.CraftBeeswaxTimes(10);
        Assert.Equal(11m, vm.BeeswaxCandles);
        Assert.True(Logged(vm, BeekeeperEvents.BeeswaxCrafted));
        Assert.False(vm.RepellentShown);   // the herbal candle still waits for the first herbs
    }

    // ============================================================ hovers (User Story 7)

    [Fact]
    public void TheBeebitsHover_ListsPlainAndPottedHoney_TheAgreement_AndTheTradesHerb()
    {
        var vm = Make(Bear(s => s.BeebitsRevealed = true));
        var row = Row(vm, BeekeeperHiveRows.Beebits);
        var plain = Assert.Single(row.Sources!);
        Assert.Equal(("plain_honey", 5m, 10m), (plain.Id, plain.PerSecond, plain.Count));
        Assert.Empty(row.Boosts!);

        vm.State.PottedHoneyRevealed = true;
        vm.State.HasTradeAgreement = true;
        vm.State.HerbBuff = BeekeeperHerbs.Trades;
        vm.State.HerbSecondsLeft = 60m;
        row = Row(vm, BeekeeperHiveRows.Beebits);
        Assert.Equal(new[] { "plain_honey_agreement", "potted_honey" }, row.Sources!.Select(x => x.Id));
        Assert.Equal(8m, row.Sources![0].Count);
        Assert.Equal(15m, row.Sources![1].PerSecond);
        var boost = Assert.Single(row.Boosts!);
        Assert.Equal((BeekeeperHerbs.Trades, 50m), (boost.Id, boost.Percent));
    }

    [Fact]
    public void TheClayJarsRow_CarriesWhatItsHoverQuotes()
    {
        var vm = Make();
        var row = Row(vm, BeekeeperHiveRows.ClayJars);
        Assert.Equal(3m, row.Rate2);    // jars in the garden
        Assert.Equal(10m, row.Value2);  // honey one jar pots
    }

    // ============================================================ debug

    [Fact]
    public void TheDebugShortcuts_Work()
    {
        var vm = Make();
        vm.DebugGiveClayJars(10m);
        Assert.Equal(13m, vm.ClayJars);
        vm.DebugGivePottedHoney(10m);
        Assert.Equal(10m, vm.PottedHoney);
        Assert.True(Row(vm, BeekeeperHiveRows.PottedHoney).Visible);
        vm.DebugGiveBeeswaxCandles(30m);
        Assert.Equal(30m, vm.BeeswaxCandles);
    }
}
