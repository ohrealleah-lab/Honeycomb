package com.leah.honeycomb.beecell

import kotlinx.serialization.Serializable

@Serializable
data class BeecellModeStats(
    val gamesPlayed: Int = 0,
    val gamesWon: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val highScore: Int = 0,
    val shortestWinTime: Int = 0,
    val totalWinningTime: Int = 0,
    val winningGamesCount: Int = 0
) {
    val winRate: Double
        get() = if (gamesPlayed > 0) gamesWon.toDouble() / gamesPlayed.toDouble() else 0.0

    val averageWinningTime: Double
        get() = if (winningGamesCount > 0) totalWinningTime.toDouble() / winningGamesCount.toDouble() else 0.0
}

@Serializable
data class BeecellStatistics(
    val statsByFreeCells: Map<Int, BeecellModeStats> = mapOf(
        4 to BeecellModeStats()
    )
)
