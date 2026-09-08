package com.leah.honeycomb.klondike

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
fun KlondikeStatsScreen(viewModel: GameViewModel, onDismiss: () -> Unit) {
    val stats by viewModel.statistics.collectAsState()
    val highScore by viewModel.highScore.collectAsState()
    val vegasBankroll by viewModel.vegasBankroll.collectAsState()
    val options by viewModel.options.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    StatisticsFullScreenView(title = Strings.get(StringKey.KlondikeStatisticsTitle, language), onDismiss = onDismiss) {
        RoundedContainer {
            StatRow(Strings.get(StringKey.GamesPlayed, language), "${stats.gamesPlayed}")
            StatRow(Strings.get(StringKey.GamesWon, language), "${stats.gamesWon}")
            StatRow(Strings.get(StringKey.HighScoreColon, language), "$highScore")
            StatRow(Strings.get(StringKey.WinPercentage, language), "%.1f%%".format(stats.winPercentage))
            StatRow(Strings.get(StringKey.CurrentStreak, language), "${stats.currentStreak}")
            StatRow(Strings.get(StringKey.LongestStreak, language), "${stats.longestStreak}")
            StatRow(Strings.get(StringKey.StatAverageWinTime, language), formatSeconds(stats.averageWinningTime.toInt()))
            StatRow(Strings.get(StringKey.StatShortestWinTime, language), formatSeconds(stats.shortestWinTime))
            if (options.isVegasScoring) {
                StatRow(Strings.get(StringKey.VegasBankrollLabel, language), String.format("$%.2f", vegasBankroll / 100.0))
            }
        }
    }
}
