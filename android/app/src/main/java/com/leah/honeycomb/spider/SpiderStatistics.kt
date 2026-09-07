package com.leah.honeycomb.spider

import kotlinx.serialization.Serializable

@Serializable
data class SpiderModeStats(
    val gamesPlayed: Int = 0,
    val gamesWon: Int = 0,
    val bestScore: Int = 0,
    val bestTime: Int = Int.MAX_VALUE,
    val currentStreak: Int = 0,
    val bestStreak: Int = 0
)

@Serializable
data class SpiderStatistics(
    val statsBySuits: Map<Int, SpiderModeStats> = mapOf(
        1 to SpiderModeStats(),
        2 to SpiderModeStats(),
        4 to SpiderModeStats()
    )
)
