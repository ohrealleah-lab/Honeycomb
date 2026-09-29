package com.leah.honeycomb.videopoker

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.StatRowSpec
import com.leah.honeycomb.StatisticsFullScreenView
import com.leah.honeycomb.StatsBlock
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings

@Composable
fun VideoPokerStatsScreen(viewModel: VideoPokerViewModel, onBack: () -> Unit) {
    val stats by viewModel.statistics.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    StatisticsFullScreenView(title = Strings.get(StringKey.VideoPokerStatistics, language), onDismiss = onBack) {
        // No money rows (wagered/paid/biggest payout/return-to-player/rebuys) — betting
        // is off on Android, as on iOS.
        StatsBlock(listOf(
            StatRowSpec.Row(Strings.get(StringKey.HandsPlayed, language), "${stats.handsPlayed}"),
            StatRowSpec.Row(Strings.get(StringKey.HandsWon, language), "${stats.handsWon}"),
            StatRowSpec.Row(Strings.get(StringKey.WinRate, language), "%.1f%%".format(stats.winRate * 100.0)),
            StatRowSpec.Row(Strings.get(StringKey.RoyalFlushes, language), "${stats.royalFlushCount}"),
            StatRowSpec.Row(Strings.get(StringKey.StatCurStreakShort, language), "${stats.currentStreak}"),
            StatRowSpec.Row(Strings.get(StringKey.StatBestStreak, language), "${stats.longestStreak}")
        ))
    }
}
