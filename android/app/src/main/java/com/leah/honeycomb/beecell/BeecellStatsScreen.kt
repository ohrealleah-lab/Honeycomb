package com.leah.honeycomb.beecell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.StatRowSpec
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StatsBlock
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings
import com.leah.honeycomb.formatSeconds

@Composable
fun BeecellStatsScreen(viewModel: BeecellViewModel, onBack: () -> Unit) {
    val statistics by viewModel.statistics.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()
    val stats = statistics.statsByFreeCells[4] ?: BeecellModeStats()

    StatisticsFullScreenView(title = "Beecell Statistics", onDismiss = onBack) {
        StatsBlock(listOf(
            StatRowSpec.Row(Strings.get(StringKey.GamesPlayed, language), "${stats.gamesPlayed}"),
            StatRowSpec.Row(Strings.get(StringKey.GamesWon, language), "${stats.gamesWon}"),
            StatRowSpec.Row(Strings.get(StringKey.HighScoreColon, language), "${stats.highScore}"),
            StatRowSpec.Row(Strings.get(StringKey.WinPercentage, language), "%.0f%%".format(stats.winRate * 100.0)),
            StatRowSpec.Row(Strings.get(StringKey.CurrentStreak, language), "${stats.currentStreak}"),
            StatRowSpec.Row(Strings.get(StringKey.LongestStreak, language), "${stats.longestStreak}"),
            StatRowSpec.Row(Strings.get(StringKey.StatAverageWinTime, language), formatSeconds(stats.averageWinningTime.toInt())),
            StatRowSpec.Row(Strings.get(StringKey.StatShortestWinTime, language), formatSeconds(stats.shortestWinTime))
        ))
    }
}
