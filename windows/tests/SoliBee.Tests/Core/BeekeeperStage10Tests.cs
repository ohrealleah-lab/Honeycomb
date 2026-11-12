using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Stage 10 (spec 019): the core trade loops. The bear pays Beebits (plain and potted
/// honey), the game starts with 3 clay jars and an opening card, honey + a jar makes potted honey,
/// the beeswax candle is back for the Hippies, who give clay jars, and herbs come only from the
/// bee hotel and leave the Shop.</summary>
public class BeekeeperStage10Tests
{
    /// <summary>NextDouble() and Next() from queues, then fixed defaults.</summary>
    private sealed class Script : IRandomSource
    {
        public Queue<int> Ints { get; } = new();
        public double DefaultDouble { get; init; } = 0.99;   // never a hit
        public int DefaultInt { get; init; }
        public int DoubleCalls { get; private set; }
        public double NextDouble() { DoubleCalls++; return DefaultDouble; }
        public int Next(int maxExclusive) => System.Math.Min(Ints.Count > 0 ? Ints.Dequeue() : DefaultInt, maxExclusive - 1);
    }

    private static BeekeeperEngine Make(BeekeeperState? state = null, IRandomSource? rng = null)
        => new(BeekeeperConfig.Default, state, rng ?? new Script());

    private static bool Has(IEnumerable<BeekeeperEvent> events, string key) => events.Any(e => e.Key == key);

    private static BeekeeperConfig C => BeekeeperConfig.Default;

    // ============================================================ the opening (User Story 1)

    [Fact]
    public void ANewGame_HasThreeJars_AndTheOpeningCardComesFirst()
    {
        var e = Make();
        Assert.Equal(3m, e.State.ClayJars);
        Assert.True(e.State.StartingJarsGiven);
        Assert.Null(e.StoryHere);
        var arrived = e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Opening, e.StoryHere);
        Assert.Contains(arrived, x => x.Key == BeekeeperEvents.StoryArrives && x.Text == BeekeeperStories.Opening);
        Assert.Equal(BeekeeperStories.Opening, BeekeeperStories.Order[0]);
    }

    [Fact]
    public void TheOpeningCard_GoesOnItsButton_ForGood()
    {
        var e = Make();
        e.AdvanceStoryTime(1m);
        var r = e.BeginFromStory();
        Assert.True(r.Done);
        Assert.Empty(r.Events);   // no log line: the card speaks
        Assert.Null(e.StoryHere);
        Assert.Contains(BeekeeperStories.Opening, e.State.StoriesDone);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
        Assert.False(e.BeginFromStory().Done);
    }

    [Fact]
    public void TheFirstBeeCaught_EndsTheOpeningCard_Silently()
    {
        var e = Make();
        e.AdvanceStoryTime(1m);
        var r = e.Catch();
        Assert.False(r.Stung);
        Assert.Null(e.StoryHere);
        Assert.Contains(BeekeeperStories.Opening, e.State.StoriesDone);
        Assert.DoesNotContain(r.Events, x => x.Key == BeekeeperEvents.StoryArrives);

        // Even when it never showed (no story time yet), a bee caught first means it never comes.
        var early = Make();
        early.Catch();
        early.AdvanceStoryTime(1m);
        Assert.Null(early.StoryHere);
    }

    [Fact]
    public void TheOpeningCard_NeverHoldsUpOuch()
    {
        var e = Make();
        e.AdvanceStoryTime(1m);
        while (!e.State.FirstStingDone) e.Catch();
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Ouch, e.StoryHere);
    }

    [Fact]
    public void AnOlderSave_GetsThreeJarsOnce_AndNeverSeesTheOpeningCard()
    {
        var old = new BeekeeperState { BearName = "Bruno", HoneyRevealed = true, ClayJars = 2m };
        var e = Make(old);
        Assert.Equal(5m, e.State.ClayJars);
        Assert.True(e.State.StartingJarsGiven);
        Assert.Contains(BeekeeperStories.Opening, e.State.StoriesDone);
        e.AdvanceStoryTime(1m);
        Assert.NotEqual(BeekeeperStories.Opening, e.StoryHere);

        var again = Make(e.State);   // loading it a second time gives nothing more
        Assert.Equal(5m, again.State.ClayJars);
    }

    // ============================================================ potting honey (User Story 2)

    [Fact]
    public void PotHoney_ShowsFromTheFirstHoney_AndNeedsTenHoneyAndAJar()
    {
        var e = Make();
        Assert.False(e.PotHoneyShown);
        e.Catch();
        Assert.True(e.PotHoneyShown);
        Assert.False(e.CanPotHoney);                 // no honey yet

        e.State.Honey = 9m;
        Assert.False(e.CanPotHoney);
        Assert.False(e.PotHoney().Done);
        e.State.Honey = 10m;
        e.State.ClayJars = 0m;
        Assert.False(e.CanPotHoney);
        Assert.False(e.PotHoney().Done);
        Assert.Equal(10m, e.State.Honey);
    }

    [Fact]
    public void PotHoney_UsesTenHoneyAndAJar_AndTheFirstOneIsTold()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true, Honey = 25m });   // an older save: 3 jars
        var r = e.PotHoney();
        Assert.True(r.Done);
        Assert.Equal(15m, e.State.Honey);
        Assert.Equal(2m, e.State.ClayJars);
        Assert.Equal(1m, e.State.PottedHoney);
        Assert.True(e.State.PottedHoneyRevealed);
        Assert.True(Has(r.Events, BeekeeperEvents.HoneyPotted));

        var second = e.PotHoney();
        Assert.True(second.Done);
        Assert.Empty(second.Events);                 // later pots are silent
        Assert.Equal(2m, e.State.PottedHoney);
    }

    [Fact]
    public void PottedHoney_HasNoCap_AndPottingFreesHoneyRoom()
    {
        var e = Make(new BeekeeperState { HoneyRevealed = true, Bees = 1m });
        e.State.Honey = e.HoneyStorage;
        e.State.ClayJars = 1000m;
        e.Advance(1m);
        Assert.True(e.IsStorageFull);
        Assert.True(e.PotHoney().Done);
        Assert.False(e.IsStorageFull);
        Assert.False(e.State.StorageFullAnnounced);  // can be said again later
        e.State.PottedHoney = e.HoneyStorage * 10m;
        Assert.True(e.CanPotHoney);                  // no cap on potted honey
    }

    // ============================================================ the bear (User Story 3)

    [Fact]
    public void ThePlainSale_PaysFiveBeebitsABundle_AndNoHerbs()
    {
        var e = Make(new BeekeeperState { BearName = "Bruno", Honey = 30m });
        var r = e.SellAll();
        Assert.Equal(15m, e.State.Beebits);
        Assert.Equal(0m, e.State.Herbs);
        Assert.False(e.State.HerbsRevealed);
        var sale = r.Events.Single(x => x.Key == BeekeeperEvents.Sale);
        Assert.Equal((15m, 30m, "Bruno"), (sale.Value, sale.Value2, sale.Text));
    }

    [Fact]
    public void PottedHoney_SellsForFifteenEach_OneOrAll_EachClickOneTrade()
    {
        var e = Make(new BeekeeperState { BearName = "Bruno", PottedHoney = 4m });
        var one = e.SellPotted();
        Assert.True(one.Done);
        Assert.Equal(15m, e.State.Beebits);
        Assert.Equal(3m, e.State.PottedHoney);
        Assert.Equal(1, e.State.Trades);
        var sale = one.Events.Single(x => x.Key == BeekeeperEvents.PottedSale);
        Assert.Equal((15m, 1m, "Bruno"), (sale.Value, sale.Value2, sale.Text));

        var all = e.SellAllPotted();
        Assert.Equal(60m, e.State.Beebits);
        Assert.Equal(0m, e.State.PottedHoney);
        Assert.Equal(2, e.State.Trades);             // Sell all potted counts once
        Assert.Equal(3m, all.Events.Single(x => x.Key == BeekeeperEvents.PottedSale).Value2);

        Assert.False(e.CanSellPotted);
        Assert.False(e.SellPotted().Done);
        Assert.False(e.SellAllPotted().Done);
        Assert.Equal(2, e.State.Trades);
    }

    [Fact]
    public void APottedSale_CanBringTheAgreement_WhichImprovesPlainHoneyOnly()
    {
        var e = Make(new BeekeeperState { BearName = "Bruno", Trades = C.AgreementTrades - 1, PottedHoney = 2m });
        var r = e.SellPotted();
        Assert.True(Has(r.Events, BeekeeperEvents.TradeAgreement));
        Assert.True(e.State.HasTradeAgreement);
        Assert.Equal(8m, e.HoneyPerTradeNow);
        Assert.Equal(15m, e.PottedHoneyBeebitsNow);  // one price for potted honey
        e.SellPotted();
        Assert.Equal(30m, e.State.Beebits);
    }

    // ============================================================ the beeswax candle (User Story 4)

    [Fact]
    public void TheBeeswaxCandle_TwoWax_WithTheWorkbench_BeforeAnyHerb()
    {
        var shut = Make(new BeekeeperState { Wax = 10m });
        Assert.False(shut.BeeswaxShown);
        Assert.False(shut.CraftBeeswax().Done);

        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 5m });
        Assert.True(e.BeeswaxShown);
        Assert.False(e.State.RepellentUnlocked);
        Assert.True(e.CraftBeeswax().Done);
        Assert.Equal(3m, e.State.Wax);
        Assert.Equal(1m, e.State.BeeswaxCandles);
        Assert.Equal(0m, e.State.RepellentCandles);
        Assert.True(e.CanCraftBeeswaxTimes(1));
        Assert.False(e.CanCraftBeeswaxTimes(2));
    }

    [Fact]
    public void TheBeeswaxCandle_FollowsTheRackAndTheMolds()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 10m,
            Upgrades = { BeekeeperUpgrades.DippingRack, BeekeeperUpgrades.CandleMolds } });
        Assert.Equal(1m, e.BeeswaxCandleWaxNow);
        Assert.Equal(2, e.CraftBeeswax().Amount);
        Assert.Equal(9m, e.State.Wax);
        Assert.Equal(2m, e.State.BeeswaxCandles);

        var batch = e.CraftBeeswax(3);
        Assert.Equal(6, batch.Amount);
        Assert.Equal(6m, batch.Events.Single(x => x.Key == BeekeeperEvents.BeeswaxCrafted).Value);
    }

    [Fact]
    public void BeeswaxCandles_BringTheHippies_AndCantBeLit()
    {
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, Wax = 100m });
        for (int i = 0; i < 4; i++) Assert.False(Has(e.CraftBeeswax().Events, BeekeeperEvents.HippiesArrive));
        Assert.True(Has(e.CraftBeeswax().Events, BeekeeperEvents.HippiesArrive));
        Assert.Equal(5m, e.State.BeeswaxCandles);
        Assert.False(e.CanLightRepellent);           // only herbal candles are lit
        Assert.False(e.LightRepellent().Done);
        Assert.Equal(5m, e.State.BeeswaxCandles);
    }

    // ============================================================ the Hippies (User Story 5)

    [Fact]
    public void TheHippies_TradeAJarForThreeBeeswaxCandles_NoBeebitsNoHerbs()
    {
        var e = Make(new BeekeeperState { HippiesRevealed = true, BeeswaxCandles = 2m, RepellentCandles = 5m,
            BeeBoostCandles = 5m, SagePropolisCandles = 5m });
        Assert.False(e.CanTradeCandles);             // 2 beeswax: not enough, and nothing else counts
        e.State.BeeswaxCandles = 10m;
        var r = e.TradeTenCandles();
        Assert.True(r.Done);
        Assert.Equal(7m, e.State.BeeswaxCandles);
        Assert.Equal(4m, e.State.ClayJars);
        Assert.Equal(1, e.State.HippieTrades);
        var traded = r.Events.Single(x => x.Key == BeekeeperEvents.CandlesTraded);
        Assert.Equal((1m, 3m), (traded.Value, traded.Value2));

        var all = e.TradeAllCandles();
        Assert.Equal(2m, all.Amount);                // 7 candles: 2 jars
        Assert.Equal(6m, e.State.ClayJars);
        Assert.Equal(1m, e.State.BeeswaxCandles);
        Assert.Equal(3, e.State.HippieTrades);       // each jar is one trade
        Assert.Equal(0m, e.State.Beebits);
        Assert.Equal(0m, e.State.Herbs);
        Assert.Equal((5m, 5m, 5m), (e.State.RepellentCandles, e.State.BeeBoostCandles, e.State.SagePropolisCandles));
    }

    [Fact]
    public void TheSeedRoll_RunsOncePerJar()
    {
        var rng = new Script();
        var e = Make(new BeekeeperState { HippiesRevealed = true, HippieTrades = 10, BeeswaxCandles = 12m }, rng);
        e.TradeAllCandles();
        Assert.Equal(4, rng.DoubleCalls);
        Assert.Equal(14, e.State.HippieTrades);
    }

    // ============================================================ herbs (User Story 6)

    private static BeekeeperState Hotel() => new()
    {
        HoneyRevealed = true, WorkbenchRevealed = true, Upgrades = { BeekeeperUpgrades.BeeHotel },
        HotelSecondsToNext = BeekeeperConfig.Default.HotelGiftSeconds,
    };

    private static int RareBeeIndex(string id) =>
        BeekeeperConfig.Default.RareBees.ToList().FindIndex(b => b.Id == id);

    [Fact]
    public void TheLeafcuttersFirstHerbs_OpenTheHerbalRecipe_AndStrongerCandles()
    {
        var rng = new Script { DefaultInt = RareBeeIndex(BeekeeperBees.Leafcutter) };
        var e = Make(Hotel(), rng);
        Assert.False(e.RepellentShown);
        Assert.DoesNotContain(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.StrongerCandles);

        var events = e.DebugHotelGift();
        Assert.Equal(2m, e.State.Herbs);
        Assert.True(e.State.HerbsRevealed);
        Assert.True(e.RepellentShown);
        Assert.True(Has(events, BeekeeperEvents.RepellentUnlocked));
        Assert.Contains(e.ShopUpgrades, u => u.Id == BeekeeperUpgrades.StrongerCandles);
        Assert.False(Has(e.DebugHotelGift(), BeekeeperEvents.RepellentUnlocked));   // said once
    }

    [Fact]
    public void TheMasonsFallbackHerbs_OpenTheRecipeToo()
    {
        var rng = new Script { DefaultInt = RareBeeIndex(BeekeeperBees.Mason) };
        var e = Make(Hotel(), rng);
        Assert.Empty(e.UnlockedSeeds);
        Assert.True(Has(e.DebugHotelGift(), BeekeeperEvents.RepellentUnlocked));
        Assert.Equal(C.MasonFallbackHerbs, e.State.Herbs);
    }

    [Fact]
    public void NothingButTheHotel_GivesHerbs()
    {
        var e = Make(new BeekeeperState { BearName = "Bruno", Honey = 100m, PottedHoney = 3m, HippiesRevealed = true,
            BeeswaxCandles = 30m, WorkbenchRevealed = true, Wax = 20m });
        e.SellAll();
        e.SellAllPotted();
        e.TradeAllCandles();
        e.CraftBeeswax(5);
        Assert.Equal(0m, e.State.Herbs);
        Assert.False(e.State.HerbsRevealed);
        Assert.False(e.State.RepellentUnlocked);
    }

    // ============================================================ the Shop

    [Fact]
    public void NoShopUpgrade_AsksForHerbs()
    {
        Assert.All(C.Upgrades, u => Assert.Equal(0m, u.Herbs));
    }

    [Fact]
    public void StrongerCandles_IsBuyableWithNoHerbs_OnceTheRecipeIsOpen()
    {
        var u = C.Upgrades.Single(x => x.Id == BeekeeperUpgrades.StrongerCandles);
        var e = Make(new BeekeeperState { WorkbenchRevealed = true, RepellentUnlocked = true,
            Beebits = u.Beebits, Wax = u.Wax, Bees = u.Bees });
        Assert.True(e.BuyUpgrade(u.Id).Done);
    }

    // ============================================================ save (FR-1014)

    [Fact]
    public void TheNewFields_RoundTrip_ThroughTheSaveFile()
    {
        string dir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "beekeeper-stage10-tests-" + System.Guid.NewGuid().ToString("N"));
        System.IO.Directory.CreateDirectory(dir);
        try
        {
            var path = System.IO.Path.Combine(dir, "beekeeper.json");
            var e = Make();
            e.State.ClayJars = 7m;
            e.State.PottedHoney = 4m;
            e.State.PottedHoneyRevealed = true;
            e.State.BeeswaxCandles = 9m;
            Assert.True(BeekeeperSaveService.Save(e.State, path, new System.DateTime(2026, 11, 12, 12, 0, 0, System.DateTimeKind.Utc)));
            var back = BeekeeperSaveService.Load(path);
            Assert.NotNull(back);
            Assert.Equal((7m, 4m, 9m), (back!.ClayJars, back.PottedHoney, back.BeeswaxCandles));
            Assert.True(back.PottedHoneyRevealed);
            Assert.True(back.StartingJarsGiven);
            Assert.Equal(7m, Make(back).State.ClayJars);   // no second gift of jars
        }
        finally
        {
            try { System.IO.Directory.Delete(dir, recursive: true); } catch { }
        }
    }

    [Fact]
    public void Negatives_AreSetToZeroOnLoad()
    {
        var e = Make(new BeekeeperState { StartingJarsGiven = true, ClayJars = -2m, PottedHoney = -1m, BeeswaxCandles = -5m });
        Assert.Equal((0m, 0m, 0m), (e.State.ClayJars, e.State.PottedHoney, e.State.BeeswaxCandles));
    }

    // ============================================================ debug shortcuts

    [Fact]
    public void TheDebugShortcuts_HandOutJarsPotsAndCandles()
    {
        var e = Make();
        e.DebugGiveClayJars(10m);
        Assert.Equal(13m, e.State.ClayJars);
        Assert.True(Has(e.DebugGivePottedHoney(10m), BeekeeperEvents.HoneyPotted));
        Assert.Equal(10m, e.State.PottedHoney);
        Assert.True(e.State.PottedHoneyRevealed);
        e.DebugGiveBeeswaxCandles(30m);
        Assert.Equal(30m, e.State.BeeswaxCandles);
        Assert.Equal(0, e.State.CandlesCrafted);     // not crafted, so not toward the Hippies
    }
}
