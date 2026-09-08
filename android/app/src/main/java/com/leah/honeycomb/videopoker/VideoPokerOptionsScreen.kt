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
import com.leah.honeycomb.IntStepperRow
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
        helpText = listOf(
            StringKey.HelpVideopokerObjective,
            StringKey.HelpVideopokerHowToPlay,
            StringKey.HelpVideopokerStrategy,
            StringKey.HelpVideopokerNoStress
        ).joinToString("\n\n") { Strings.get(it, language) },
        onDismiss = onBack,
        onShowStats = onShowStats,
        gameSettings = {
            Column {
                SegmentedControl(
                    items = VideoPokerVariant.values().toList(),
                    selectedItem = options.variant,
                    onItemSelection = { viewModel.updateVariant(it) },
                    itemLabel = {
                        when (it) {
                            VideoPokerVariant.JacksOrBetter -> "Jacks or Better"
                            VideoPokerVariant.DeucesWild -> "Deuces Wild"
                            VideoPokerVariant.BonusPoker -> "Bonus Poker"
                        }
                    }
                )
                IntStepperRow(
                    label = "Starting Credits",
                    value = options.startingCredits,
                    step = 100,
                    range = 10..10000,
                    onValueChange = { viewModel.updateOptions(options.copy(startingCredits = it)) }
                )
                IntStepperRow(
                    label = "Default Bet",
                    value = options.betPerHand,
                    step = 1,
                    range = 1..5,
                    onValueChange = { viewModel.updateOptions(options.copy(betPerHand = it)) }
                )
            }
        }
    )
}
