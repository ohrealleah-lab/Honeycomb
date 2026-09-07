package com.leah.honeycomb.videopoker

import com.leah.honeycomb.Card
import kotlinx.serialization.Serializable

enum class VideoPokerPhase {
    Deal,
    Holding,
    Result
}

@Serializable
sealed class VideoPokerQualifier {
    @Serializable data object None : VideoPokerQualifier()
    @Serializable data object JacksOrBetter : VideoPokerQualifier()
    @Serializable data object DeucesWild : VideoPokerQualifier()
    @Serializable data class BonusFours(val rank: Int) : VideoPokerQualifier()
}

@Serializable
data class VideoPokerPayEntry(
    val handName: String,
    val rank: PokerHandRank,
    val qualifier: VideoPokerQualifier,
    val multipliers: List<Int>
) {
    fun payout(bet: Int): Int {
        val idx = minOf(maxOf(bet - 1, 0), 4)
        return multipliers[idx] * bet
    }
}

@Serializable
data class VideoPokerState(
    val phase: VideoPokerPhase = VideoPokerPhase.Deal,
    val deck: List<Card> = emptyList(),
    val hand: List<Card> = emptyList(),
    val heldIndices: Set<Int> = emptySet(),
    val sessionCredits: Int = 1000,
    val currentBet: Int = 1,
    val lastPayout: Int = 0,
    val lastHandName: String = "",
    val handsDealt: Int = 0
)

enum class VideoPokerVariant {
    JacksOrBetter,
    DeucesWild,
    BonusPoker
}

@Serializable
data class VideoPokerOptions(
    val variant: VideoPokerVariant = VideoPokerVariant.JacksOrBetter,
    val startingCredits: Int = 100,
    val betPerHand: Int = 1
)

@Serializable
data class VideoPokerStatistics(
    val handsPlayed: Int = 0,
    val handsWon: Int = 0,
    val biggestPayout: Int = 0,
    val totalWagered: Int = 0,
    val totalPaidOut: Int = 0,
    val royalFlushCount: Int = 0,
    val rebuyCount: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0
) {
    val returnToPlayer: Double
        get() = if (totalWagered > 0) totalPaidOut.toDouble() / totalWagered else 0.0

    val winRate: Double
        get() = if (handsPlayed > 0) handsWon.toDouble() / handsPlayed else 0.0
}
