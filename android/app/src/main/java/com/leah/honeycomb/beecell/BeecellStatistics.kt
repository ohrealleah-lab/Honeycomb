package com.leah.honeycomb.beecell

import kotlinx.serialization.Serializable

// Field set matches shared/Beecell/Models/BeecellStatistics.swift's ModeStats (dropped
// the old bestTime/bestStreak fields). Keyed by free-cell count on Android (1-4) rather
// than iOS's deck-count ("1deck"/"2deck") key, since Android is single-deck only (see
// the port plan §3) and has no deck-count option to key by — BeecellOptions.kt has only
// freeCellCount, no deckCount field.
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
    val winPercentage: Double
        get() = if (gamesPlayed > 0) (gamesWon.toDouble() / gamesPlayed.toDouble()) * 100.0 else 0.0

    val averageWinningTime: Double
        get() = if (winningGamesCount > 0) totalWinningTime.toDouble() / winningGamesCount.toDouble() else 0.0
}

@Serializable
data class BeecellStatistics(
    val statsByFreeCells: Map<Int, BeecellModeStats> = mapOf(
        1 to BeecellModeStats(),
        2 to BeecellModeStats(),
        3 to BeecellModeStats(),
        4 to BeecellModeStats()
    )
)
