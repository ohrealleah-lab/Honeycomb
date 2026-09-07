package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.leah.honeycomb.OptionsFullScreenView
import com.leah.honeycomb.SegmentedControl
import com.leah.honeycomb.Strings
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.LocalAppContainer

@Composable
fun HoneycombOptionsScreen(
    viewModel: HoneycombViewModel,
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
        gameSectionTitle = "Honeycomb",
        helpText = Strings.get(StringKey.HelpHoneycombObjective, language) + "\n\n" + Strings.get(StringKey.HelpHoneycombMechanics, language),
        onDismiss = onBack,
        onShowStats = onShowStats,
        gameSettings = {
            SegmentedControl(
                items = listOf(
                    HoneycombDifficulty.Easy,
                    HoneycombDifficulty.Medium,
                    HoneycombDifficulty.Hard,
                    HoneycombDifficulty.UltraHard
                ),
                selectedItem = options.difficulty,
                onItemSelection = { viewModel.updateOptions(options.copy(difficulty = it)) },
                itemLabel = {
                    when (it) {
                        HoneycombDifficulty.Easy -> "Baby"
                        HoneycombDifficulty.Medium -> "Honey"
                        HoneycombDifficulty.Hard -> "Queen"
                        HoneycombDifficulty.UltraHard -> "Killer"
                    }
                }
            )
        }
    )
}
