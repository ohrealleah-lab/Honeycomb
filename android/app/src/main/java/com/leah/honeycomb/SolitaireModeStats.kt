package com.leah.honeycomb

// Shared shape for solitaire-style per-mode statistics — identical across
// Klondike (GameStatistics), Spider (SpiderModeStats), and Beecell (BeecellModeStats).
// Implemented as an interface (not abstract class) so the concrete @Serializable
// data classes can remain independent and maintain their existing serialization keys.
interface SolitaireModeStats {
    val gamesPlayed: Int
    val gamesWon: Int
    val currentStreak: Int
    val longestStreak: Int
    val totalWinningTime: Int
    val winningGamesCount: Int
    val shortestWinTime: Int

    val winRate: Double
        get() = if (gamesPlayed > 0) gamesWon.toDouble() / gamesPlayed.toDouble() else 0.0

    val averageWinningTime: Double
        get() = if (winningGamesCount > 0) totalWinningTime.toDouble() / winningGamesCount.toDouble() else 0.0
}
