package com.leah.honeycomb.honeycomb

import org.junit.Test

// Timing benchmark for HoneycombAI's search, not a correctness test. Run manually
// (not part of CI) when changing the minimax/alpha-beta hot path, to compare
// before/after — println output shows in the test report's system-out.
class HoneycombAIBenchmark {

    @Test
    fun benchmarkUltraHardOpeningMove() {
        val deck = HoneycombCardGenerator.generateAllCards(12345L)
        val playerHand = deck.take(5)
        val opponentHand = deck.drop(5).take(5)
        val board = HoneycombBoard()
        val empties = board.cells.indices.toList()

        val times = mutableListOf<Long>()
        repeat(5) {
            val start = System.nanoTime()
            HoneycombAI.computeMove(
                difficulty = HoneycombDifficulty.UltraHard,
                board = board,
                opponentDeck = opponentHand,
                playerDeck = playerHand,
                unknownPlayerCardCount = 5,
                eligibleHands = opponentHand.indices.toList(),
                empties = empties,
                rules = emptyList()
            )
            times.add((System.nanoTime() - start) / 1_000_000)
        }
        println("UltraHard opening move (empty board, 5v5 hands): ${times} ms, avg=${times.average()}ms")
    }

    @Test
    fun benchmarkUltraHardMidGameMove() {
        val deck = HoneycombCardGenerator.generateAllCards(67890L)
        val playerHand = deck.take(3)
        val opponentHand = deck.drop(3).take(3)
        var board = HoneycombBoard()
        // Place 4 cards to simulate a mid-game board (5 empties left, matches
        // a realistic mid-match branching factor rather than the opening move).
        val placed = deck.drop(6).take(4)
        val cellIndices = listOf(0, 2, 6, 8)
        for ((i, cellIdx) in cellIndices.withIndex()) {
            val owner = if (i % 2 == 0) CardOwner.Player else CardOwner.Opponent
            board.cells[cellIdx].card = HoneycombCard(data = placed[i], owner = owner)
        }
        val empties = board.cells.indices.filter { board.cells[it].card == null }

        val times = mutableListOf<Long>()
        repeat(5) {
            val start = System.nanoTime()
            HoneycombAI.computeMove(
                difficulty = HoneycombDifficulty.UltraHard,
                board = board,
                opponentDeck = opponentHand,
                playerDeck = playerHand,
                unknownPlayerCardCount = 3,
                eligibleHands = opponentHand.indices.toList(),
                empties = empties,
                rules = emptyList()
            )
            times.add((System.nanoTime() - start) / 1_000_000)
        }
        println("UltraHard mid-game move (5 empties, 3v3 hands): ${times} ms, avg=${times.average()}ms")
    }
}
