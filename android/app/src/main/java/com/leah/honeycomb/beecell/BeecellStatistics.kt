package com.leah.honeycomb.beecell

import kotlinx.serialization.Serializable

@Serializable
data class BeecellModeStats(
    val gamesPlayed: Int = 0,
    val gamesWon: Int = 0,
    val bestTime: Int = Int.MAX_VALUE,
    val currentStreak: Int = 0,
    val bestStreak: Int = 0
)

@Serializable
data class BeecellStatistics(
    val statsByFreeCells: Map<Int, BeecellModeStats> = mapOf(
        1 to BeecellModeStats(),
        2 to BeecellModeStats(),
        3 to BeecellModeStats(),
        4 to BeecellModeStats()
    )
)
