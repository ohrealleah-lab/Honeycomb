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

    [Fact]
    public void TestStandardScoringUndoPenaltyForPositivePoints()
    {
        var vm = new GameViewModel();
        vm.Options.IsVegasScoring = false;
        vm.State.Score = 100;

        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();
        foreach (var t in vm.Tableaus) t.Cards.Clear();
        foreach (var f in vm.Foundations) f.Cards.Clear();

        var ace = new Card("ace", CardSuit.Spades, 1, true);
        vm.Waste.Cards.Add(ace);

        // Save state before move
        vm.SaveStateForUndo();

        // Waste to Foundation: +10 points
        vm.MoveCard(ace, vm.Foundations[0]);
        Assert.Equal(110, vm.State.Score);

        // Perform Undo
        vm.Undo();

        // Pre-move score was 100. Restoring it returns to 100.
        // Penalty is pointsEarned (110 - 100 = 10), so score becomes 100 - 10 = 90.
        Assert.Equal(90, vm.State.Score);
    }

    [Fact]
    public void TestStandardScoringUndoPenaltyForNegativePoints()
    {
        var vm = new GameViewModel();
        vm.Options.IsVegasScoring = false;
        vm.State.Score = 100;

        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();
        foreach (var t in vm.Tableaus) t.Cards.Clear();
        foreach (var f in vm.Foundations) f.Cards.Clear();

        // Setup Tableau 0 with Red 3 (Hearts)
        var redThree = new Card("three", CardSuit.Hearts, 3, true);
        vm.Tableaus[0].Cards.Add(redThree);

        // Setup Foundation 0 with Black 2 (Spades)
        var blackTwo = new Card("two", CardSuit.Spades, 2, true);
        vm.Foundations[0].Cards.Add(blackTwo);

        // Save state before move
        vm.SaveStateForUndo();

        // Move Foundation to Tableau: -15 points (moving Black 2 on Red 3 is valid)
        vm.MoveCard(blackTwo, vm.Tableaus[0]);
        Assert.Equal(85, vm.State.Score);

        // Perform Undo
        vm.Undo();

        // Pre-move score was 100. Restoring it returns to 100.
        // Points earned is 85 - 100 = -15, which is clamped to 0 penalty.
        // Score remains at 100.
        Assert.Equal(100, vm.State.Score);
    }

    [Fact]
    public void TestVegasScoringUndoNoPenalty()
    {
        var vm = new GameViewModel();
        vm.Options.IsVegasScoring = true;
        vm.State.Score = 1000; // $10.00

        vm.Stock.Cards.Clear();
        vm.Waste.Cards.Clear();
        foreach (var t in vm.Tableaus) t.Cards.Clear();
        foreach (var f in vm.Foundations) f.Cards.Clear();

        var ace = new Card("ace", CardSuit.Spades, 1, true);
        vm.Waste.Cards.Add(ace);

        // Save state before move
        vm.SaveStateForUndo();

        // Waste to Foundation: +$5.00 (+500 points)
        vm.MoveCard(ace, vm.Foundations[0]);
        Assert.Equal(1500, vm.State.Score);

        // Perform Undo
        vm.Undo();

        // Vegas has no penalty, score simply returns to pre-move score.
        Assert.Equal(1000, vm.State.Score);
    }
}
