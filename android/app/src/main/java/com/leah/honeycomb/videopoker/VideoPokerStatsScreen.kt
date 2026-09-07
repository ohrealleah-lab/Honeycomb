package com.leah.honeycomb.videopoker

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.RoundedContainer
import com.leah.honeycomb.StatRow
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings

@Composable
fun VideoPokerStatsScreen(viewModel: VideoPokerViewModel, onBack: () -> Unit) {
    val stats by viewModel.statistics.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    StatisticsFullScreenView(title = Strings.get(StringKey.VideoPokerStatistics, language), onDismiss = onBack) {
        RoundedContainer {
            StatRow(Strings.get(StringKey.HandsPlayed, language), "${stats.handsPlayed}")
            StatRow(Strings.get(StringKey.HandsWon, language), "${stats.handsWon}")
            StatRow(Strings.get(StringKey.StatBiggestPayout, language), "${stats.biggestPayout}")
            StatRow(Strings.get(StringKey.TotalWagered, language), "${stats.totalWagered}")
            StatRow(Strings.get(StringKey.StatTotalPaidOut, language), "${stats.totalPaidOut}")
            StatRow(Strings.get(StringKey.RoyalFlushes, language), "${stats.royalFlushCount}")
            StatRow(Strings.get(StringKey.RtpStat, language), "%.1f%%".format(stats.returnToPlayer * 100.0))
            StatRow(Strings.get(StringKey.RebuysStat, language), "${stats.rebuyCount}")
            StatRow(Strings.get(StringKey.StatCurStreakShort, language), "${stats.currentStreak}")
            StatRow(Strings.get(StringKey.StatBestStreak, language), "${stats.longestStreak}")
        }
    }
}
