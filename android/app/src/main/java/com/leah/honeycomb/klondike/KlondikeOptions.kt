package com.leah.honeycomb.klondike

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings
import com.leah.honeycomb.AppLanguage
import com.leah.honeycomb.OptionsFullScreenView
import com.leah.honeycomb.SwitchOptionRow
import com.leah.honeycomb.SegmentedControl
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.leah.honeycomb.LocalAppContainer

@Composable
fun KlondikeOptionsSheet(
    viewModel: GameViewModel,
    onDismiss: () -> Unit,
    onShowStats: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()
    val appContainer = LocalAppContainer.current
    val sharedOptions = appContainer.sharedOptions
    val language by appContainer.language.collectAsState()

    DisposableEffect(viewModel) {
        sharedOptions.onNoStressModeChange = { viewModel.reactToNoStressModeChange() }
        onDispose { sharedOptions.onNoStressModeChange = null }
    }

    OptionsFullScreenView(
        title = Strings.get(StringKey.Options, language),
        gameSectionTitle = "Klondike",
        onDismiss = onDismiss,
        onShowStats = onShowStats,
        helpText = Strings.get(StringKey.HelpKlondikeRules, language),
        gameSettings = {
            Column {
                SegmentedControl(
                    items = listOf(DrawMode.DrawOne, DrawMode.DrawThree),
                    selectedItem = options.drawMode,
                    onItemSelection = { viewModel.updateOptions(options.copy(drawMode = it)) },
                    itemLabel = {
                        if (it == DrawMode.DrawOne) Strings.get(StringKey.DrawOne, language)
                        else Strings.get(StringKey.DrawThree, language)
                    }
                )
                SwitchOptionRow(
                    label = Strings.get(StringKey.VegasScoring, language),
                    checked = options.isVegasScoring,
                    onCheckedChange = { viewModel.updateOptions(options.copy(isVegasScoring = it)) }
                )
            }
        }
    )
}
