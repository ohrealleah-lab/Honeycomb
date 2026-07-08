using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using System.Linq;

namespace SoliBee.Tests.Core;

public class DrawRulesTests
{
    [Fact]
    public void TestDrawOneMode()
    {
        var vm = new GameViewModel();
        vm.State.Mode = DrawMode.DrawOne;
        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();

        var c1 = new Card("c1", CardSuit.Spades, 1, false);
        var c2 = new Card("c2", CardSuit.Spades, 2, false);
        vm.Stock.Cards.Add(c1);
        vm.Stock.Cards.Add(c2);

        // Draw 1 card
        vm.DrawCard();
        Assert.Single(vm.Waste.Cards);
        Assert.True(vm.Waste.Cards.Last().IsFaceUp);
        Assert.Single(vm.Stock.Cards);

        // Draw another card
        vm.DrawCard();
        Assert.Equal(2, vm.Waste.Cards.Count);
        Assert.Empty(vm.Stock.Cards);
    }

    [Fact]
    public void TestDrawThreeMode()
    {
        var vm = new GameViewModel();
        vm.State.Mode = DrawMode.DrawThree;
        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();

        var c1 = new Card("c1", CardSuit.Spades, 1, false);
        var c2 = new Card("c2", CardSuit.Spades, 2, false);
        var c3 = new Card("c3", CardSuit.Spades, 3, false);
        var c4 = new Card("c4", CardSuit.Spades, 4, false);

        vm.Stock.Cards.Add(c1);
        vm.Stock.Cards.Add(c2);
        vm.Stock.Cards.Add(c3);
        vm.Stock.Cards.Add(c4);

        // Draw 3 cards
        vm.DrawCard();
        Assert.Equal(3, vm.Waste.Cards.Count);
        Assert.Single(vm.Stock.Cards);
        Assert.True(vm.Waste.Cards.Last().IsFaceUp);

        // Draw remaining card
        vm.DrawCard();
        Assert.Equal(4, vm.Waste.Cards.Count);
        Assert.Empty(vm.Stock.Cards);
    }

    [Fact]
    public void TestStockRecycle()
    {
        var vm = new GameViewModel();
        // GameViewModel() loads real, persisted Options from disk (SettingsService has no
        // test seam), so pin this explicitly rather than inheriting whatever Vegas setting
        // happens to be saved — Vegas Draw 1 now allows 0 recycles (see GameViewModel's
        // vegasRecycleLimit), which would otherwise make this generic recycle test flaky
        // depending on ambient state.
        vm.Options.IsVegasScoring = false;
        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();

        var c1 = new Card("c1", CardSuit.Spades, 1, true);
        vm.Waste.Cards.Add(c1);

        // Click Stock when empty to recycle
        vm.DrawCard();

        Assert.Single(vm.Stock.Cards);
        Assert.False(vm.Stock.Cards[0].IsFaceUp); // Recycled stock is face down
        Assert.Empty(vm.Waste.Cards);
        Assert.Equal(1, vm.State.RecyclesCount);
    }
}
