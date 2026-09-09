package com.leah.honeycomb.klondike

import com.leah.honeycomb.SolitaireModeStats
import kotlinx.serialization.Serializable

@Serializable
data class GameStatistics(
    override val gamesPlayed: Int = 0,
    override val gamesWon: Int = 0,
    override val currentStreak: Int = 0,
    override val longestStreak: Int = 0,
    override val totalWinningTime: Int = 0,
    override val winningGamesCount: Int = 0,
    override val shortestWinTime: Int = 0,
    val highScore: Int = 0,
    val highScoreVegas: Int = -5200
) : SolitaireModeStats
