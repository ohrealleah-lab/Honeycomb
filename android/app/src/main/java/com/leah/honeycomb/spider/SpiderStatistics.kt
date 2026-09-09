package com.leah.honeycomb.spider

import kotlinx.serialization.Serializable

// Field set matches shared/Spider/Models/SpiderStatistics.swift's SpiderModeStats
// (dropped the old bestScore/bestTime/bestStreak fields, which didn't match iOS).
@Serializable
data class SpiderModeStats(
    val gamesPlayed: Int = 0,
    val gamesWon: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val highScore: Int = 500,
    val totalWinningTime: Int = 0,
    val winningGamesCount: Int = 0,
    val shortestWinTime: Int = 0
) {
    val winRate: Double
        get() = if (gamesPlayed > 0) gamesWon.toDouble() / gamesPlayed.toDouble() else 0.0

    val averageWinningTime: Double
        get() = if (winningGamesCount > 0) totalWinningTime.toDouble() / winningGamesCount.toDouble() else 0.0
}

@Serializable
data class SpiderStatistics(
    val statsBySuits: Map<Int, SpiderModeStats> = mapOf(
        1 to SpiderModeStats(),
        2 to SpiderModeStats(),
        4 to SpiderModeStats()
    )
)
