package com.leah.honeycomb.spider

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.SegmentedControl
import com.leah.honeycomb.StatRowSpec
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StatsBlock
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings
import com.leah.honeycomb.formatSeconds

@Composable
fun SpiderStatsScreen(viewModel: SpiderViewModel, onBack: () -> Unit) {
    val statistics by viewModel.statistics.collectAsState()
    val options by viewModel.options.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()
    var selectedSuitCount by remember { mutableStateOf(options.suitCount) }
    val stats = statistics.statsBySuits[selectedSuitCount] ?: SpiderModeStats()

    val suitNoun = if (selectedSuitCount == 1) Strings.get(StringKey.LabelSuitSingular, language) else Strings.get(StringKey.LabelSuitPlural, language)
    val title = Strings.format(StringKey.SpiderStatisticsFmt, language, selectedSuitCount, suitNoun)

    StatisticsFullScreenView(title = title, onDismiss = onBack) {
        Column {
            SegmentedControl(
                items = listOf(1, 2, 4),
                selectedItem = selectedSuitCount,
                onItemSelection = { selectedSuitCount = it },
                itemLabel = { "$it" }
            )
            Spacer(modifier = Modifier.height(16.dp))
            StatsBlock(listOf(
                StatRowSpec.Row(Strings.get(StringKey.GamesPlayed, language), "${stats.gamesPlayed}"),
                StatRowSpec.Row(Strings.get(StringKey.GamesWon, language), "${stats.gamesWon}"),
                StatRowSpec.Row(Strings.get(StringKey.WinPercentage, language), "%.0f%%".format(stats.winRate * 100.0)),
                StatRowSpec.Row(Strings.get(StringKey.HighScore, language), "${stats.highScore}"),
                StatRowSpec.Row(Strings.get(StringKey.CurrentStreak, language), "${stats.currentStreak}"),
                StatRowSpec.Row(Strings.get(StringKey.LongestStreak, language), "${stats.longestStreak}"),
                StatRowSpec.Row(Strings.get(StringKey.StatAverageWinTime, language), formatSeconds(stats.averageWinningTime.toInt())),
                StatRowSpec.Row(Strings.get(StringKey.StatShortestWinTime, language), formatSeconds(stats.shortestWinTime))
            ))
        }
    }
}
