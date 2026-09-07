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

// Statistics are still stored per free-cell-count mode under the hood (see
// BeecellStatistics.kt), but the picker UI for switching between modes was confusing
// with no clear benefit — this screen just shows whichever mode is currently selected
// in Beecell's own options, with no picker exposed.
@Composable
fun BeecellStatsScreen(viewModel: BeecellViewModel, onBack: () -> Unit) {
    val statistics by viewModel.statistics.collectAsState()
    val options by viewModel.options.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()
    val stats = statistics.statsByFreeCells[options.freeCellCount] ?: BeecellModeStats()

    StatisticsFullScreenView(title = "Beecell Statistics", onDismiss = onBack) {
        RoundedContainer {
            StatRow(Strings.get(StringKey.GamesPlayed, language), "${stats.gamesPlayed}")
            StatRow(Strings.get(StringKey.GamesWon, language), "${stats.gamesWon}")
            StatRow(Strings.get(StringKey.WinPercentage, language), "%.1f%%".format(stats.winPercentage))
            StatRow(Strings.get(StringKey.CurrentStreak, language), "${stats.currentStreak}")
            StatRow(Strings.get(StringKey.LongestStreak, language), "${stats.longestStreak}")
            StatRow(Strings.get(StringKey.StatAverageWinTime, language), formatSeconds(stats.averageWinningTime.toInt()))
            StatRow(Strings.get(StringKey.StatShortestWinTime, language), formatSeconds(stats.shortestWinTime))
        }
    }
}
