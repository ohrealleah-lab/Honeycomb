package com.leah.honeycomb.spider

import com.leah.honeycomb.SolitaireModeStats
import kotlinx.serialization.Serializable

// Field set matches shared/Spider/Models/SpiderStatistics.swift's SpiderModeStats
// (dropped the old bestScore/bestTime/bestStreak fields, which didn't match iOS).
@Serializable
data class SpiderModeStats(
    override val gamesPlayed: Int = 0,
    override val gamesWon: Int = 0,
    override val currentStreak: Int = 0,
    override val longestStreak: Int = 0,
    val highScore: Int = 500,
    override val totalWinningTime: Int = 0,
    override val winningGamesCount: Int = 0,
    override val shortestWinTime: Int = 0
) : SolitaireModeStats

@Serializable
data class SpiderStatistics(
    val statsBySuits: Map<Int, SpiderModeStats> = mapOf(
        1 to SpiderModeStats(),
        2 to SpiderModeStats(),
        4 to SpiderModeStats()
    )
)
