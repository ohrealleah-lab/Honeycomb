package com.leah.honeycomb.klondike

import kotlinx.serialization.Serializable

@Serializable
data class GameStatistics(
    val gamesPlayed: Int = 0,
    val gamesWon: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val totalWinningTime: Int = 0,
    val winningGamesCount: Int = 0,
    val shortestWinTime: Int = 0
) {
    val winPercentage: Double
        get() = if (gamesPlayed > 0) (gamesWon.toDouble() / gamesPlayed.toDouble()) * 100.0 else 0.0

    val averageWinningTime: Double
        get() = if (winningGamesCount > 0) totalWinningTime.toDouble() / winningGamesCount.toDouble() else 0.0
}
