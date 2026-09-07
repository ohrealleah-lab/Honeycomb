package com.leah.honeycomb.blackjack

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.leah.honeycomb.Card
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.Suit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class BlackjackRuleTests {

    private lateinit var viewModel: BlackjackViewModel

    @Before
    fun setup() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val datastore = androidx.datastore.preferences.core.PreferenceDataStoreFactory.create { File(context.filesDir, "test.preferences_pb") }
        val sharedOptions = SharedGameOptions(datastore, kotlinx.coroutines.CoroutineScope(Dispatchers.Unconfined))
        viewModel = BlackjackViewModel(sharedOptions)
    }

    private fun deckForDeal(p1: Card, d1: Card, p2: Card, d2: Card, rest: List<Card> = emptyList()): List<Card> {
        val cards = mutableListOf<Card>()
        cards.addAll(rest.reversed())
        cards.add(d2)
        cards.add(p2)
        cards.add(d1)
        cards.add(p1)
        return cards
    }

    @Test
    fun testDealerPeekForBlackjack() = runBlocking {
        viewModel.startNewGame()
        // Dealer gets 10 and Ace (Blackjack). Player gets 10 and 9.
        viewModel.debugDeck = deckForDeal(
            p1 = Card(suit = Suit.Spades, rank = 10),
            d1 = Card(suit = Suit.Hearts, rank = 10),
            p2 = Card(suit = Suit.Clubs, rank = 9),
            d2 = Card(suit = Suit.Diamonds, rank = 1)
        )
        viewModel.deal()
        
        assertTrue(viewModel.isDealerBlackjackPending)
        delay(1500)
        assertEquals(BlackjackPhase.Result, viewModel.state.value.phase)
        assertEquals(BlackjackHandResult.Loss, viewModel.state.value.playerHands[0].result)
    }

    @Test
    fun testDoubleDownOn9to11() {
        viewModel.startNewGame()
        viewModel.debugDeck = deckForDeal(
            p1 = Card(suit = Suit.Spades, rank = 6),
            d1 = Card(suit = Suit.Hearts, rank = 9),
            p2 = Card(suit = Suit.Clubs, rank = 4),
            d2 = Card(suit = Suit.Diamonds, rank = 8),
            rest = listOf(Card(suit = Suit.Spades, rank = 10))
        )
        viewModel.deal()
        
        assertTrue(viewModel.canDouble)
        viewModel.doubleDown()
        
        val hand = viewModel.state.value.playerHands[0]
        assertEquals(3, hand.cards.size)
        assertTrue(hand.isDoubled)
        assertEquals(2, hand.bet)
        assertEquals(BlackjackPhase.Result, viewModel.state.value.phase)
        assertEquals(BlackjackHandResult.Win, hand.result)
    }

    @Test
    fun testSplitOnIdenticalRankAndSplitAceAutoStand() = runBlocking {
        viewModel.startNewGame()
        viewModel.debugDeck = deckForDeal(
            p1 = Card(suit = Suit.Spades, rank = 1),
            d1 = Card(suit = Suit.Hearts, rank = 10),
            p2 = Card(suit = Suit.Clubs, rank = 1),
            d2 = Card(suit = Suit.Diamonds, rank = 9),
            rest = listOf(
                Card(suit = Suit.Spades, rank = 10),
                Card(suit = Suit.Hearts, rank = 10)
            )
        )
        viewModel.deal()
        
        assertTrue(viewModel.canSplit)
        viewModel.split()
        
        delay(2000)
        
        assertEquals(BlackjackPhase.Result, viewModel.state.value.phase)
        assertEquals(2, viewModel.state.value.playerHands.size)
        
        val hand0 = viewModel.state.value.playerHands[0]
        val hand1 = viewModel.state.value.playerHands[1]
        
        assertEquals(2, hand0.cards.size)
        assertEquals(2, hand1.cards.size)
        assertTrue(hand0.isSplitAce)
        assertTrue(hand1.isSplitAce)
        assertEquals(21, hand0.value)
        assertEquals(21, hand1.value)
        assertEquals(BlackjackHandResult.Win, hand0.result)
        assertEquals(BlackjackHandResult.Win, hand1.result)
    }

    @Test
    fun testDealerStandsOnSoft17() {
        viewModel.startNewGame()
        viewModel.debugDeck = deckForDeal(
            p1 = Card(suit = Suit.Spades, rank = 10),
            d1 = Card(suit = Suit.Hearts, rank = 1),
            p2 = Card(suit = Suit.Clubs, rank = 10),
            d2 = Card(suit = Suit.Diamonds, rank = 6),
            rest = listOf(Card(suit = Suit.Hearts, rank = 2))
        )
        viewModel.deal()
        
        viewModel.stand()
        
        assertEquals(BlackjackPhase.Result, viewModel.state.value.phase)
        assertEquals(2, viewModel.state.value.dealerCards.size)
        assertEquals(17, viewModel.state.value.dealerValue)
        assertEquals(BlackjackHandResult.Win, viewModel.state.value.playerHands[0].result)
    }
}
