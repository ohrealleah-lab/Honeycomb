package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.StatRowSpec
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StatsBlock
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings

@Composable
fun HoneycombStatsScreen(viewModel: HoneycombViewModel, onBack: () -> Unit) {
    val stats by viewModel.statistics.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    StatisticsFullScreenView(title = Strings.get(StringKey.HoneycombStatistics, language), onDismiss = onBack) {
        Column {
            StatsBlock(listOf(
                StatRowSpec.Row(Strings.get(StringKey.StatMatchesPlayed, language), "${stats.gamesPlayed}"),
                StatRowSpec.Row(Strings.get(StringKey.StatMatchesWon, language), "${stats.matchesWon}"),
                StatRowSpec.Row(Strings.get(StringKey.StatMatchesLost, language), "${stats.matchesLost}"),
                StatRowSpec.Row(Strings.get(StringKey.StatMatchesDrawn, language), "${stats.matchesDrawn}"),
                StatRowSpec.Row(Strings.get(StringKey.WinPercentage, language), "%.0f%%".format(stats.winRate * 100.0)),
                StatRowSpec.Row(Strings.get(StringKey.StatCardsCaptured, language), "${stats.cardsCaptured}"),
                StatRowSpec.Row(Strings.get(StringKey.StatCardsStolen, language), "${stats.cardsStolen}"),
                StatRowSpec.Row(Strings.get(StringKey.StatCurrentWinStreak, language), "${stats.currentWinStreak}"),
                StatRowSpec.Row(Strings.get(StringKey.StatLongestWinStreak, language), "${stats.longestWinStreak}"),
                StatRowSpec.Row(Strings.get(StringKey.StatFlawlessVictoriesIos, language), "${stats.flawlessVictories}"),
                StatRowSpec.Row(Strings.get(StringKey.StatSamePlusTriggers, language), "${stats.samePlusTriggers}"),
                StatRowSpec.Row(Strings.get(StringKey.StatFallenAcesIos, language), "${stats.fallenAces}"),
                StatRowSpec.Row(Strings.get(StringKey.StatSuddenDeathCountIos, language), "${stats.suddenDeathCount}"),
                StatRowSpec.Row(Strings.get(StringKey.StatTimesStartedOver, language), "${stats.timesStartedOver}")
            ))

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                Strings.get(StringKey.StatWinsByDifficultySection, language),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            StatsBlock(listOf(
                StatRowSpec.Row(Strings.get(StringKey.StatBabyBee, language), "${stats.easyWins}"),
                StatRowSpec.Row(Strings.get(StringKey.StatHoneyBee, language), "${stats.mediumWins}"),
                StatRowSpec.Row(Strings.get(StringKey.StatQueenBee, language), "${stats.hardWins}"),
                StatRowSpec.Row(Strings.get(StringKey.StatKillerBee, language), "${stats.ultraHardWins}")
            ))
        }
    }
}
