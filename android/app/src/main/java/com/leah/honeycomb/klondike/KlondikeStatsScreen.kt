package com.leah.honeycomb.klondike

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.StatRowSpec
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StatsBlock
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings
import com.leah.honeycomb.formatSeconds

@Composable
fun KlondikeStatsScreen(viewModel: GameViewModel, onDismiss: () -> Unit) {
    val stats by viewModel.statistics.collectAsState()
    val vegasBankroll by viewModel.vegasBankroll.collectAsState()
    val options by viewModel.options.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    // Read high score directly from the statistics blob — high_score/high_score_vegas
    // are now stored as fields on GameStatistics rather than in separate DataStore keys.
    val rawHighScore = if (options.isVegasScoring) stats.highScoreVegas else stats.highScore
    val highScoreStr = if (options.isVegasScoring) {
        val sign = if (rawHighScore < 0) "-" else ""
        val absScore = Math.abs(rawHighScore) / 100.0
        String.format(java.util.Locale.US, "%s$%,.2f", sign, absScore)
    } else {
        "$rawHighScore"
    }

    val bankrollColor = if (vegasBankroll >= 0) Color(0xFF4CAF50) else Color(0xFFF44336)
    val bankrollSign = if (vegasBankroll < 0) "-" else ""
    val bankrollStr = String.format(java.util.Locale.US, "%s$%,.2f", bankrollSign, Math.abs(vegasBankroll) / 100.0)

    StatisticsFullScreenView(title = Strings.get(StringKey.KlondikeStatisticsTitle, language), onDismiss = onDismiss) {
        StatsBlock(listOf(
            StatRowSpec.Row(Strings.get(StringKey.GamesPlayed, language), "${stats.gamesPlayed}"),
            StatRowSpec.Row(Strings.get(StringKey.GamesWon, language), "${stats.gamesWon}"),
            StatRowSpec.Row(Strings.get(StringKey.HighScoreColon, language), highScoreStr),
            StatRowSpec.Row(Strings.get(StringKey.WinPercentage, language), "%.0f%%".format(stats.winRate * 100.0)),
            StatRowSpec.Row(Strings.get(StringKey.CurrentStreak, language), "${stats.currentStreak}"),
            StatRowSpec.Row(Strings.get(StringKey.LongestStreak, language), "${stats.longestStreak}"),
            StatRowSpec.Row(Strings.get(StringKey.StatAverageWinTime, language), formatSeconds(stats.averageWinningTime.toInt())),
            StatRowSpec.Row(Strings.get(StringKey.StatShortestWinTime, language), formatSeconds(stats.shortestWinTime)),
            StatRowSpec.ConditionalRow(
                label = Strings.get(StringKey.VegasBankrollLabel, language),
                value = bankrollStr,
                valueColor = bankrollColor,
                visible = options.isVegasScoring
            )
        ))
    }
}
