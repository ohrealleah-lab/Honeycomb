using System.Reflection;
using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Tests.ViewModels;

public class SpiderAutocompleteTests
{
    private static void CheckAutocomplete(SpiderViewModel vm) =>
        typeof(SpiderViewModel).GetMethod("CheckAutocomplete", BindingFlags.NonPublic | BindingFlags.Instance)!.Invoke(vm, null);

    private static Card C(CardSuit suit, int rank, bool up = true) => new($"{suit}_{rank}_{System.Guid.NewGuid()}", suit, rank, up);

    // A lone 8 on a different-suit 9, with one empty column, can only be parked and
    // moved back forever — Autocomplete must not be offered (Mac/Android's check used
    // to loop forever here; Windows used to offer an Autocomplete that never finished).
    [Fact]
    public void NotOfferedWhenItCouldOnlyShuttleACard()
    {
        var vm = new SpiderViewModel();
        vm.StockPiles.Clear();
        foreach (var t in vm.Tableaus) { t.Cards.Clear(); t.Cards.Add(C(CardSuit.Diamonds, 12)); }
        vm.Tableaus[0].Cards.Clear();
        vm.Tableaus[0].Cards.Add(C(CardSuit.Clubs, 2, up: false));
        vm.Tableaus[0].Cards.Add(C(CardSuit.Spades, 9));
        vm.Tableaus[0].Cards.Add(C(CardSuit.Hearts, 8));
        vm.Tableaus[1].Cards.Clear();

        CheckAutocomplete(vm);
        Assert.False(vm.IsAutocompletable);
    }

    // Two halves of one suit's K→A run split across columns: joining them completes the
    // run and clears the board, so Autocomplete is offered.
    [Fact]
    public void OfferedWhenItFinishesTheGame()
    {
        var vm = new SpiderViewModel();
        vm.StockPiles.Clear();
        foreach (var t in vm.Tableaus) t.Cards.Clear();
        for (int r = 13; r >= 7; r--) vm.Tableaus[0].Cards.Add(C(CardSuit.Spades, r));
        for (int r = 6; r >= 1; r--) vm.Tableaus[1].Cards.Add(C(CardSuit.Spades, r));

        CheckAutocomplete(vm);
        Assert.True(vm.IsAutocompletable);
    }
}
