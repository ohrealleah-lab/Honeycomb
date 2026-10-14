package com.leah.honeycomb.spider

import com.leah.honeycomb.Card
import com.leah.honeycomb.Pile
import com.leah.honeycomb.PileType
import com.leah.honeycomb.Suit
import com.leah.honeycomb.ViewModelTestBase
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SpiderAutocompleteTest : ViewModelTestBase() {
    private fun newVm(): SpiderViewModel {
        val ds = newDataStore()
        val shared = newSharedOptions(ds)
        return SpiderViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    private fun SpiderViewModel.setTableau(columns: List<List<Card>>) {
        val flow = privateFlow<SpiderState>(this, "_state")
        flow.value = flow.value.copy(
            stock = Pile(id = "stock", type = PileType.Stock),
            tableau = columns.mapIndexed { i, cards -> Pile(id = "tableau_$i", type = PileType.Tableau, cards = cards) }
        )
    }

    // A lone 8 on a different-suit 9 with one empty column could be parked and moved back
    // forever — the check never returned, freezing the app. It must finish and say no.
    @Test(timeout = 20_000)
    fun notOfferedWhenItCouldOnlyShuttleACard() {
        val vm = newVm()
        val cols = MutableList(10) { listOf(up(Suit.Diamonds, 12)) }
        cols[0] = listOf(down(Suit.Clubs, 2), up(Suit.Spades, 9), up(Suit.Hearts, 8))
        cols[1] = emptyList()
        vm.setTableau(cols)
        vm.checkAutocompleteState()
        assertFalse(vm.isAutocompleteAvailable.value)
    }

    // Two halves of one suit's King-to-Ace run: joining them completes it and clears the board.
    @Test(timeout = 20_000)
    fun offeredWhenItFinishesTheGame() {
        val vm = newVm()
        val cols = MutableList(10) { emptyList<Card>() }
        cols[0] = (13 downTo 7).map { up(Suit.Spades, it) }
        cols[1] = (6 downTo 1).map { up(Suit.Spades, it) }
        vm.setTableau(cols)
        vm.checkAutocompleteState()
        assertTrue(vm.isAutocompleteAvailable.value)
    }

    // Moving a card between two identical stacks (a 5♥ off one 6♠ onto another 6♠)
    // changes nothing, so it doesn't count as a way out — matches Hint, Mac and Windows.
    @Test(timeout = 20_000)
    fun lateralMoveBetweenIdenticalStacksIsNotAWayOut() {
        val vm = newVm()
        val cols = MutableList(10) { listOf(up(Suit.Diamonds, 13)) }
        cols[0] = listOf(up(Suit.Spades, 6), up(Suit.Hearts, 5))
        cols[1] = listOf(up(Suit.Spades, 6))
        vm.setTableau(cols)
        val t = vm.state.value.tableau
        vm.moveCards(listOf(t[0].cards.last()), t[0], t[1])
        assertTrue(vm.isStuck.value)

        // A real move is still a way out.
        val other = MutableList(10) { listOf(up(Suit.Diamonds, 13)) }
        other[0] = listOf(up(Suit.Spades, 6), up(Suit.Hearts, 5))
        other[1] = listOf(up(Suit.Clubs, 6))
        other[2] = listOf(up(Suit.Spades, 7))
        vm.setTableau(other)
        val t2 = vm.state.value.tableau
        vm.moveCards(listOf(t2[0].cards.last()), t2[0], t2[1])   // 6♠ can still go on the 7♠
        assertFalse(vm.isStuck.value)
    }
}
