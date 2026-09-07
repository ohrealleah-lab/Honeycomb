package com.leah.honeycomb.blackjack

import com.leah.honeycomb.Card
import kotlinx.serialization.Serializable

enum class BlackjackPhase {
    Betting,
    Playing,
    DealerTurn,
    Result
}

enum class BlackjackHandResult {
    Win,
    Loss,
    Push,
    Blackjack,
    Bust
}

enum class BlackjackRoundOutcome {
    None,
    Blackjack,
    Win,
    Push,
    Bust,
    Loss
}

@Serializable
data class BlackjackHand(
    val cards: List<Card>,
    val bet: Int,
    val isDoubled: Boolean = false,
    val isSplitAce: Boolean = false,
    val result: BlackjackHandResult? = null
) {
    val value: Int
        get() = BlackjackState.handValue(cards)
    
    val isBust: Boolean
        get() = value > 21
        
    val isBlackjack: Boolean
        get() = cards.size == 2 && value == 21
        
    val isComplete: Boolean
        get() = isBust || value == 21 || isDoubled || isSplitAce
}

@Serializable
data class BlackjackState(
    val phase: BlackjackPhase = BlackjackPhase.Betting,
    val playerHands: List<BlackjackHand> = emptyList(),
    val activeHandIndex: Int = 0,
    val dealerCards: List<Card> = emptyList(),
    val deck: List<Card> = emptyList(),
    val sessionCredits: Int = 100,
    val currentBet: Int = 1,
    val handsDealt: Int = 0,
    val resultOutcome: BlackjackRoundOutcome = BlackjackRoundOutcome.None,
    val lastNetResult: Int = 0
) {
    val isWinRound: Boolean
        get() = resultOutcome == BlackjackRoundOutcome.Blackjack || resultOutcome == BlackjackRoundOutcome.Win

    val dealerValue: Int
        get() = handValue(dealerCards)

    val dealerVisibleValue: Int
        get() = handValue(dealerCards.filter { it.faceUp })

    companion object {
        fun handValue(cards: List<Card>): Int {
            var total = 0
            var aces = 0
            for (card in cards) {
                if (!card.faceUp) continue
                val r = card.rank
                if (r == 1) {
                    aces++
                    total += 11
                } else if (r >= 10) {
                    total += 10
                } else {
                    total += r
                }
            }
            while (total > 21 && aces > 0) {
                total -= 10
                aces--
            }
            return total
        }
    }
}

@Serializable
data class BlackjackOptions(
    val startingCredits: Int = 100
)

@Serializable
data class BlackjackStatistics(
    val handsPlayed: Int = 0,
    val handsWon: Int = 0,
    val handsLost: Int = 0,
    val pushes: Int = 0,
    val blackjacks: Int = 0,
    val totalWagered: Int = 0,
    val totalPaidOut: Int = 0,
    val biggestPayout: Int = 0,
    val rebuyCount: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0
) {
    val winRate: Double
        get() = if (handsPlayed > 0) handsWon.toDouble() / handsPlayed else 0.0

    val returnToPlayer: Double
        get() = if (totalWagered > 0) totalPaidOut.toDouble() / totalWagered else 0.0
}
