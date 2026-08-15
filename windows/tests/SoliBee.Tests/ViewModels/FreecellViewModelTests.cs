using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Tests.ViewModels;

public class FreecellViewModelTests
{
    // IsSafeFoundationMove (hint scoring) used to hand-count foundations with a hardcoded
    // "safeCount == 2" check that ignored FreecellDeckCount entirely. In 2-deck mode, a
    // suit with one advanced foundation and one still-untouched duplicate foundation would
    // have its untouched copy silently skipped by the loop (Cards.Count == 0 means it's
    // never counted either way) rather than correctly forcing the rank check to fail — so a
    // move could be scored "safe" (1000) while an entire duplicate foundation for that
    // opposite colour hadn't even started. Regression test: with one hearts and one diamonds
    // foundation each parked at rank 4 but their duplicate copies still empty, moving 5♠ to
    // foundation must NOT be preferred over a genuinely safe free-cell-to-tableau move.
    [Fact]
    public void TestSafeFoundationMoveAccountsForUntouchedDuplicateInTwoDeckMode()
    {
        var vm = new FreecellViewModel();
        vm.Options.FreecellDeckCount = 2;
        vm.InitializeGame(countAsNewGame: false);

        foreach (var f in vm.Foundations) f.Cards.Clear();
        foreach (var t in vm.Tableaus) t.Cards.Clear();
        foreach (var c in vm.FreeCells) c.Cards.Clear();

        void Stack(Pile pile, CardSuit suit, int upToRank)
        {
            for (int r = 1; r <= upToRank; r++)
                pile.Cards.Add(new Card($"{suit}_{r}", suit, r, true));
        }

        // One started + one untouched foundation per opposite-colour suit.
        Stack(vm.Foundations[0], CardSuit.Hearts, 4);   // started, top rank 4
        // vm.Foundations[1] left empty — untouched hearts duplicate
        Stack(vm.Foundations[2], CardSuit.Diamonds, 4); // started, top rank 4
        // vm.Foundations[3] left empty — untouched diamonds duplicate

        // Candidate A: 5♠ on a tableau top — foundation-eligible only if truly safe.
        Stack(vm.Foundations[4], CardSuit.Spades, 4); // so 5♠ is the next legal spades foundation card
        vm.Tableaus[1].Cards.Add(new Card("five_spades", CardSuit.Spades, 5, true));

        // Candidate B: a free-cell card with a genuine, unambiguous 500-point tableau move.
        vm.Tableaus[2].Cards.Add(new Card("seven_spades", CardSuit.Spades, 7, true));
        vm.FreeCells[0].Cards.Add(new Card("six_hearts", CardSuit.Hearts, 6, true));

        // Every other tableau must be non-empty and not a valid landing spot for 6♥, so the
        // free-cell candidate has exactly one legal target and isn't ambiguously scored
        // against "any empty column accepts any card".
        for (int i = 0; i < vm.Tableaus.Count; i++)
        {
            if (i == 1 || i == 2) continue;
            vm.Tableaus[i].Cards.Add(new Card($"filler_{i}", CardSuit.Clubs, 9, true));
        }

        vm.ClearHintCycle();
        vm.FindHint();

        Assert.NotNull(vm.ActiveHint);
        Assert.Equal(vm.FreeCells[0].Id, vm.ActiveHint!.SourcePileId);
        Assert.Equal(vm.Tableaus[2].Id, vm.ActiveHint.TargetPileId);
    }
}
