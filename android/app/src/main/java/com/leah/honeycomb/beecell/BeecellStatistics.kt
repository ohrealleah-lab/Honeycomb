package com.leah.honeycomb.beecell

import com.leah.honeycomb.SolitaireModeStats
import kotlinx.serialization.Serializable

@Serializable
data class BeecellModeStats(
    override val gamesPlayed: Int = 0,
    override val gamesWon: Int = 0,
    override val currentStreak: Int = 0,
    override val longestStreak: Int = 0,
    val highScore: Int = 0,
    override val shortestWinTime: Int = 0,
    override val totalWinningTime: Int = 0,
    override val winningGamesCount: Int = 0
) : SolitaireModeStats

@Serializable
data class BeecellStatistics(
    val statsByFreeCells: Map<Int, BeecellModeStats> = mapOf(
        4 to BeecellModeStats()
    )
)
