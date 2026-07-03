using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using System.Linq;

namespace SoliBee.Tests.ViewModels;

public class UndoTests
{
    [Fact]
    public void TestUndoStackBehavior()
    {
        var vm = new GameViewModel();
        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();
        foreach (var t in vm.Tableaus)
        {
            t.Cards.Clear();
        }

        var king = new Card("king", CardSuit.Spades, 13, true);
        vm.Tableaus[0].Cards.Add(king);

        // Record a state check/save before move
        vm.SaveStateForUndo();

        // Perform a move: move king to empty Tableau 1
        var cardToMove = vm.Tableaus[0].Cards.Last();
        vm.MoveCard(cardToMove, vm.Tableaus[1]);

        Assert.Empty(vm.Tableaus[0].Cards);
        Assert.Single(vm.Tableaus[1].Cards);
        Assert.Equal(1, vm.State.MovesCount);

        // Perform Undo
        vm.Undo();

        Assert.Single(vm.Tableaus[0].Cards);
        Assert.Empty(vm.Tableaus[1].Cards);
        Assert.Equal(0, vm.State.MovesCount);
    }
}
