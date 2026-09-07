package com.leah.honeycomb.videopoker

import com.leah.honeycomb.Card
import com.leah.honeycomb.Suit
import org.junit.Assert.*
import org.junit.Test

class VideoPokerTests {

    @Test
    fun testEvaluator() {
        val royal = listOf(
            Card(suit = Suit.Hearts, rank = 1),
            Card(suit = Suit.Hearts, rank = 13),
            Card(suit = Suit.Hearts, rank = 12),
            Card(suit = Suit.Hearts, rank = 11),
            Card(suit = Suit.Hearts, rank = 10)
        )
        val res = PokerHandEvaluator.evaluate(royal)
        assertEquals(PokerHandRank.RoyalFlush, res.rank)
        
        val deucesRoyal = listOf(
            Card(suit = Suit.Hearts, rank = 2),
            Card(suit = Suit.Hearts, rank = 13),
            Card(suit = Suit.Hearts, rank = 12),
            Card(suit = Suit.Hearts, rank = 11),
            Card(suit = Suit.Hearts, rank = 10)
        )
        val resWild = PokerHandEvaluator.evaluateWithDeuces(deucesRoyal)
        assertEquals(PokerHandRank.RoyalFlush, resWild.rank)
    }
}
