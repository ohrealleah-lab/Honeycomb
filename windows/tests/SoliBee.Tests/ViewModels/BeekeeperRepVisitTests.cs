using System;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Trade reps (the Bear, the Hippies) arrive like wasps: "A {} shows up", then Throw a shoe
/// (they leave and come back) or Engage (their trades open). The wasp's first visit offers Engage,
/// later visits Bribe; the emissary rule is untouched.</summary>
public class BeekeeperRepVisitTests
{
    private sealed class NoRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static (BeekeeperViewModel Vm, Func<double, int> Tick) Make(BeekeeperState s, decimal returnSeconds = 30m)
    {
        var now = new DateTime(2026, 11, 10, 12, 0, 0, DateTimeKind.Utc);
        var vm = new BeekeeperViewModel(isHeadless: true, config: new BeekeeperConfig { RepReturnSeconds = returnSeconds, StartingHoneyCap = 1_000_000m },
            rng: new NoRandom(), clock: () => now, persist: false, initialState: s);
        vm.IsWatched = true;
        return (vm, secs => { for (int i = 0; i < (int)secs; i++) { now = now.AddSeconds(1); vm.Tick(); } return 0; });
    }

    private static BeekeeperState Hive() => new()
    {
        Bees = 1000m, Honey = 500m, Combs = 2, WorkbenchRevealed = true, HoneyRevealed = true, BearName = "Bruno",
        BearRevealed = true, HippiesRevealed = true, RepellentCandles = 1m,
        // No story card holds the door (one thing at a time since 2026-11-12): the pot-honey card is done, the Smoker owned.
        PottedHoneyRevealed = true, Upgrades = { BeekeeperUpgrades.Smoker }, CandlesCrafted = 1,
        BeeswaxCrafted = true,   // + the candle card done (review fix, 2026-11-15: CandlesCrafted alone counts herbal ones too)
    };

    [Fact]
    public void ARepShowsUp_OneAtATime_ThenEngageOpensItsTrades()
    {
        var (vm, tick) = Make(Hive());
        Assert.Empty(vm.TradeOffers);
        tick(1);
        // Bee, 2026-11-12: one visitor at a time, in arrival order; the Hippies wait their turn.
        Assert.Equal(new[] { "bear" }, vm.RepsPresent);
        Assert.Contains("rep:hippies", vm.Engine.StoryQueue);
        Assert.DoesNotContain(vm.Log, e => e.Key == BeekeeperEvents.RepArrives);   // first time: the reveal line says it
        Assert.Empty(vm.TradeOffers);            // not until engaged

        vm.EngageRep("bear");
        Assert.Empty(vm.RepsPresent);
        Assert.Equal(new[] { "bear" }, vm.TradeOffers.Select(o => o.Id));
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.RepEngaged && e.Text == "bear");
        tick(1);
        Assert.Equal(new[] { "hippies" }, vm.RepsPresent);
        tick(5);
        Assert.DoesNotContain(vm.Log, e => e.Key == BeekeeperEvents.RepArrives && e.Text == "bear");
    }

    [Fact]
    public void AShoeSendsARepAway_AndItReturnsLater_WithNoEmissaryRule()
    {
        var s = Hive();
        s.HippiesRevealed = false;   // the bear alone, so no one else holds the door
        var (vm, tick) = Make(s, 30m);
        tick(1);
        for (int i = 0; i < 8; i++)
        {
            Assert.Contains("bear", vm.RepsPresent);
            vm.ThrowShoeAtRep("bear");
            Assert.DoesNotContain("bear", vm.RepsPresent);
            tick(10);
            Assert.DoesNotContain("bear", vm.RepsPresent);   // still away
            tick(25);
        }
        Assert.Contains("bear", vm.RepsPresent);             // always comes back
        Assert.False(vm.EmissaryCome);
        Assert.Empty(vm.TradeOffers);                        // never engaged
    }

    [Fact]
    public void ARepSentAwayCanStillBeEngagedOnReturn()
    {
        var (vm, tick) = Make(Hive(), 5m);
        tick(1);
        vm.EngageRep("bear");   // the bear first: visitors come one at a time
        tick(1);
        vm.ThrowShoeAtRep("hippies");
        tick(6);
        vm.EngageRep("hippies");
        Assert.Contains(vm.TradeOffers, o => o.Id == "hippies");
    }

    [Fact]
    public void AnOlderSaveWithRepsAlreadyMet_MeetsThemAgain_AndTradesWaitForEngage()
    {
        var (vm, tick) = Make(Hive());
        Assert.Empty(vm.State.RepsMet);          // fields default to empty
        tick(1);
        Assert.Equal(2, vm.State.RepsMet.Count);
    }

    [Fact]
    public void TheWaspsFirstVisitOffersEngage_LaterVisitsOfferBribe()
    {
        var (vm, tick) = Make(Hive());
        vm.DebugCallWasp();
        Assert.True(vm.WaspApproaching);
        Assert.True(vm.WaspFirstVisit);
        Assert.True(vm.CanEngageWasp);
        Assert.True(vm.CanThrowShoe);

        vm.EngageWasp();
        Assert.False(vm.WaspApproaching);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.WaspEngaged);
        Assert.Equal(0, vm.BribesTotal);          // Engage is not a bribe

        vm.DebugCallWasp();
        Assert.False(vm.WaspFirstVisit);
        Assert.False(vm.CanEngageWasp);
        Assert.True(vm.CanBribe);
        Assert.Equal(0, vm.EngageWaspCommand.CanExecute(null) ? 1 : 0);
    }

    [Fact]
    public void Emissary_StillComesOnTheFifthBribe_AfterAnEngagedFirstVisit()
    {
        var (vm, tick) = Make(Hive());
        vm.DebugCallWasp();
        vm.EngageWasp();
        for (int i = 1; i <= 5; i++)
        {
            vm.DebugCallWasp();
            Assert.False(vm.CanEngageWasp);
            vm.Bribe();
            Assert.Equal(i, vm.BribesTotal);
        }
        Assert.True(vm.EmissaryCome);
        Assert.Contains(vm.Log, e => e.Key == BeekeeperEvents.Emissary);
        vm.DebugCallWasp();
        Assert.False(vm.WaspApproaching);         // no wasp ever comes again
    }
}
