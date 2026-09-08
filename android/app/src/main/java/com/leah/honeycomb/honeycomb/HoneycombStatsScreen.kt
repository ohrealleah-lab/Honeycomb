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
import com.leah.honeycomb.RoundedContainer
import com.leah.honeycomb.StatRow
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings

@Composable
fun HoneycombStatsScreen(viewModel: HoneycombViewModel, onBack: () -> Unit) {
    val stats by viewModel.statistics.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    StatisticsFullScreenView(title = Strings.get(StringKey.HoneycombStatistics, language), onDismiss = onBack) {
        Column {
            RoundedContainer {
                StatRow(Strings.get(StringKey.StatMatchesPlayed, language), "${stats.gamesPlayed}")
                StatRow(Strings.get(StringKey.StatMatchesWon, language), "${stats.matchesWon}")
                StatRow(Strings.get(StringKey.StatMatchesLost, language), "${stats.matchesLost}")
                StatRow(Strings.get(StringKey.StatMatchesDrawn, language), "${stats.matchesDrawn}")
                StatRow(Strings.get(StringKey.WinPercentage, language), "%.0f%%".format(stats.winRate))
                StatRow(Strings.get(StringKey.StatCardsCaptured, language), "${stats.cardsCaptured}")
                StatRow(Strings.get(StringKey.StatCardsStolen, language), "${stats.cardsStolen}")
                StatRow(Strings.get(StringKey.StatCurrentWinStreak, language), "${stats.currentWinStreak}")
                StatRow(Strings.get(StringKey.StatLongestWinStreak, language), "${stats.longestWinStreak}")
                StatRow(Strings.get(StringKey.StatFlawlessVictoriesIos, language), "${stats.flawlessVictories}")
                StatRow(Strings.get(StringKey.StatSamePlusTriggers, language), "${stats.samePlusTriggers}")
                StatRow(Strings.get(StringKey.StatFallenAcesIos, language), "${stats.fallenAces}")
                StatRow(Strings.get(StringKey.StatSuddenDeathCountIos, language), "${stats.suddenDeathCount}")
                StatRow(Strings.get(StringKey.StatTimesStartedOver, language), "${stats.timesStartedOver}")
            }

            Spacer(modifier = Modifier.height(8.dp))
            Text(
                Strings.get(StringKey.StatWinsByDifficultySection, language),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            RoundedContainer {
                StatRow(Strings.get(StringKey.StatBabyBee, language), "${stats.easyWins}")
                StatRow(Strings.get(StringKey.StatHoneyBee, language), "${stats.mediumWins}")
                StatRow(Strings.get(StringKey.StatQueenBee, language), "${stats.hardWins}")
                StatRow(Strings.get(StringKey.StatKillerBee, language), "${stats.ultraHardWins}")
            }
        }
    }
}
