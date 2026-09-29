package com.leah.honeycomb.videopoker

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.leah.honeycomb.OptionsFullScreenView
import com.leah.honeycomb.SegmentedControl
import com.leah.honeycomb.Strings
import com.leah.honeycomb.LocalAppContainer

@Composable
fun VideoPokerOptionsScreen(
    viewModel: VideoPokerViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {},
    onShowStats: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()
    val appContainer = LocalAppContainer.current
    val language by appContainer.language.collectAsState()

    OptionsFullScreenView(
        title = Strings.get(StringKey.Options, language),
        gameSectionTitle = "Video Poker",
        // Betting-free guide shared with iOS (no bets, coins, payouts or jackpots).
        helpText = listOf(
            StringKey.HelpVideopokerObjectiveIos,
            StringKey.HelpVideopokerHowToPlayIos,
            StringKey.HelpVideopokerStrategyIos
        ).joinToString("\n\n") { Strings.get(it, language) },
        onDismiss = onBack,
        onShowStats = onShowStats,
        gameSettings = {
            Column {
                SegmentedControl(
                    items = VideoPokerVariant.values().toList(),
                    selectedItem = options.variant,
                    onItemSelection = { viewModel.updateVariant(it) },
                    // Variant names deliberately stay English in every language — they're
                    // the casino games' actual names (Mac: localizedVariantName).
                    itemLabel = {
                        when (it) {
                            VideoPokerVariant.JacksOrBetter -> "Jacks or Better"
                            VideoPokerVariant.DeucesWild -> "Deuces Wild"
                            VideoPokerVariant.BonusPoker -> "Bonus Poker"
                        }
                    }
                )
                // No Starting Credits/Default Bet — betting is off on Android, as on iOS.
            }
        }
    )
}
