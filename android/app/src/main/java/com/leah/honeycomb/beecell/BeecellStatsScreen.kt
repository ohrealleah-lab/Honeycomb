package com.leah.honeycomb.beecell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.RoundedContainer
import com.leah.honeycomb.StatRow
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings
import com.leah.honeycomb.formatSeconds

@Composable
fun BeecellStatsScreen(viewModel: BeecellViewModel, onBack: () -> Unit) {
    val statistics by viewModel.statistics.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()
    val stats = statistics.statsByFreeCells[4] ?: BeecellModeStats()

    StatisticsFullScreenView(title = "Beecell Statistics", onDismiss = onBack) {
        RoundedContainer {
            StatRow(Strings.get(StringKey.GamesPlayed, language), "${stats.gamesPlayed}")
            StatRow(Strings.get(StringKey.GamesWon, language), "${stats.gamesWon}")
            StatRow(Strings.get(StringKey.HighScoreColon, language), "${stats.highScore}")
            StatRow(Strings.get(StringKey.WinPercentage, language), "%.0f%%".format(stats.winPercentage))
            StatRow(Strings.get(StringKey.CurrentStreak, language), "${stats.currentStreak}")
            StatRow(Strings.get(StringKey.LongestStreak, language), "${stats.longestStreak}")
            StatRow(Strings.get(StringKey.StatAverageWinTime, language), formatSeconds(stats.averageWinningTime.toInt()))
            StatRow(Strings.get(StringKey.StatShortestWinTime, language), formatSeconds(stats.shortestWinTime))
        }
    }
}
