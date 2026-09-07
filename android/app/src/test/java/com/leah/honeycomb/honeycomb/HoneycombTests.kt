package com.leah.honeycomb.honeycomb

import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random

class HoneycombTests {
    
    @Test
    fun testAIAndRules() {
        // We will simulate a simple match
        val deck = HoneycombCardGenerator.generateAllCards(12345L)
        val pHandData = deck.take(5)
        val oHandData = deck.drop(5).take(5)
        
        val difficulties = listOf(HoneycombDifficulty.Easy, HoneycombDifficulty.Medium, HoneycombDifficulty.Hard, HoneycombDifficulty.UltraHard)
        
        for (diff in difficulties) {
            var board = HoneycombBoard()
            val empties = board.cells.indices.filter { board.cells[it].card == null }
            val move = HoneycombAI.computeMove(
                difficulty = diff,
                board = board,
                opponentDeck = oHandData,
                playerDeck = pHandData,
                unknownPlayerCardCount = 5,
                eligibleHands = oHandData.indices.toList(),
                empties = empties,
                rules = emptyList()
            )
            assertNotNull(move)
        }
        
        // Verify rules
        val rules = HoneycombRule.values()
        for (rule in rules) {
            var board = HoneycombBoard()
            val move = HoneycombAI.computeMove(
                difficulty = HoneycombDifficulty.Medium,
                board = board,
                opponentDeck = oHandData,
                playerDeck = pHandData,
                unknownPlayerCardCount = 5,
                eligibleHands = oHandData.indices.toList(),
                empties = board.cells.indices.toList(),
                rules = listOf(rule)
            )
            assertNotNull(move)
        }
    }
}
