using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using System.Linq;

namespace SoliBee.Tests.Core;

public class MoveRulesTests
{
    [Fact]
    public void TestTableauAlternateColorAndRankSequencing()
    {
        var vm = new GameViewModel();
        // Clear all tableaus for test
        foreach (var t in vm.Tableaus)
        {
            t.Cards.Clear();
        }
        vm.Waste.Cards.Clear();

        // Rule: Empty tableau only accepts King
        var jack = new Card("jack", CardSuit.Spades, 11, true);
        var king = new Card("king", CardSuit.Diamonds, 13, true);

        // Put them in the waste pile so FindPileContaining succeeds and they are top cards
        vm.Waste.Cards.Add(jack);
        Assert.False(vm.CanMoveCard(jack, vm.Tableaus[0]));

        vm.Waste.Cards.Clear();
        vm.Waste.Cards.Add(king);
        Assert.True(vm.CanMoveCard(king, vm.Tableaus[0]));

        // Place the King on Tableau 0
        vm.Tableaus[0].Cards.Add(king);
        vm.Waste.Cards.Clear();

        // Rule: Alternating color, rank lower by 1
        var queenClubs = new Card("queen_c", CardSuit.Clubs, 12, true); // Black queen on Red King - should be valid
        var queenHearts = new Card("queen_h", CardSuit.Hearts, 12, true); // Red queen on Red King - should be invalid

        vm.Waste.Cards.Add(queenClubs);
        Assert.True(vm.CanMoveCard(queenClubs, vm.Tableaus[0]));

        vm.Waste.Cards.Clear();
        vm.Waste.Cards.Add(queenHearts);
        Assert.False(vm.CanMoveCard(queenHearts, vm.Tableaus[0]));
    }

    [Fact]
    public void TestFoundationMoveRules()
    {
        var vm = new GameViewModel();
        foreach (var f in vm.Foundations)
        {
            f.Cards.Clear();
        }
        vm.Waste.Cards.Clear();

        // Rule: Empty foundation only accepts Ace
        var aceSpades = new Card("ace_s", CardSuit.Spades, 1, true);
        var twoSpades = new Card("two_s", CardSuit.Spades, 2, true);

        vm.Waste.Cards.Add(aceSpades);
        Assert.True(vm.CanMoveCard(aceSpades, vm.Foundations[0]));

        vm.Waste.Cards.Clear();
        vm.Waste.Cards.Add(twoSpades);
        Assert.False(vm.CanMoveCard(twoSpades, vm.Foundations[0]));

        // Place Ace of Spades
        vm.Foundations[0].Cards.Add(aceSpades);
        vm.Waste.Cards.Clear();

        // Rule: Same suit, rank higher by 1
        var twoHearts = new Card("two_h", CardSuit.Hearts, 2, true); // Wrong suit

        vm.Waste.Cards.Add(twoSpades);
        Assert.True(vm.CanMoveCard(twoSpades, vm.Foundations[0]));

        vm.Waste.Cards.Clear();
        vm.Waste.Cards.Add(twoHearts);
        Assert.False(vm.CanMoveCard(twoHearts, vm.Foundations[0]));
    }
}
