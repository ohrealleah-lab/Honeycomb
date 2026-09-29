package com.leah.honeycomb.blackjack

import com.leah.honeycomb.Card
import com.leah.honeycomb.Suit
import com.leah.honeycomb.ViewModelTestBase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import org.junit.Assert.assertEquals
import org.junit.Test

// Real casino rules (all platforms): the dealer only draws while a player hand is live.
@OptIn(ExperimentalCoroutinesApi::class)
class BlackjackDealerTest : ViewModelTestBase() {
    private fun newVm(): BlackjackViewModel {
        val ds = newDataStore()
        val shared = newSharedOptions(ds)
        return BlackjackViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    // Player 10+6 vs dealer 10 + hidden 6 (16, would normally draw). The deck's last card
    // is dealt first: `playerCard` goes to the player, then 5 is next for the dealer.
    private fun BlackjackViewModel.setUpHand(playerCard: Card) {
        val flow = privateFlow<BlackjackState>(this, "_state")
        flow.value = flow.value.copy(
            phase = BlackjackPhase.Playing,
            playerHands = listOf(BlackjackHand(cards = listOf(up(Suit.Spades, 10), up(Suit.Hearts, 6)), bet = 1)),
            activeHandIndex = 0,
            dealerCards = listOf(up(Suit.Clubs, 10), down(Suit.Diamonds, 6)),
            deck = listOf(up(Suit.Hearts, 5), playerCard)
        )
    }

    private fun finishDealerTurn() {
        clock.scheduler.advanceTimeBy(10_000)
        clock.scheduler.runCurrent()
    }

    @Test(timeout = 20_000)
    fun dealerDoesNotDrawAfterThePlayerBusts() {
        val vm = newVm()
        vm.setUpHand(playerCard = up(Suit.Clubs, 9)) // 10+6+9 = 25, bust
        vm.hit()
        finishDealerTurn()
        assertEquals(BlackjackPhase.Result, vm.state.value.phase)
        assertEquals("Dealer only reveals the hole card", 2, vm.state.value.dealerCards.size)
    }

    @Test(timeout = 20_000)
    fun dealerDrawsWhileAPlayerHandIsLive() {
        val vm = newVm()
        vm.setUpHand(playerCard = up(Suit.Clubs, 9))
        vm.stand() // player stays on 16
        finishDealerTurn()
        assertEquals(BlackjackPhase.Result, vm.state.value.phase)
        assertEquals("Dealer draws to 17+ (16 + the 9 on top of the deck)", 3, vm.state.value.dealerCards.size)
    }
}
