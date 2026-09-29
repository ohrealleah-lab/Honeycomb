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
import androidx.compose.runtime.setValue
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

    // Changing mode (or Vegas) deals a new game — if one is in progress, ask first
    // (same prompt as Mac's Options OK, iOS and Windows) instead of ending it on the tap.
    var pendingOptions by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<GameOptions?>(null) }
    val gameState by viewModel.state.collectAsState()
    fun requestOptions(newOptions: GameOptions) {
        if (gameState.movesCount > 0 && !gameState.hasWon) pendingOptions = newOptions
        else viewModel.updateOptions(newOptions)
    }
    pendingOptions?.let { pending ->
        AlertDialog(
            onDismissRequest = { pendingOptions = null },
            title = { Text(Strings.get(StringKey.NewGameConfirmTitle, language)) },
            confirmButton = {
                TextButton(onClick = { viewModel.updateOptions(pending); pendingOptions = null }) {
                    Text(Strings.get(StringKey.NewGame, language))
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingOptions = null }) { Text(Strings.get(StringKey.Cancel, language)) }
            }
        )
    }

    OptionsFullScreenView(
        title = Strings.get(StringKey.Options, language),
        gameSectionTitle = "Klondike",
        onDismiss = onDismiss,
        onShowStats = onShowStats,
        helpText = Strings.get(StringKey.HelpKlondikeRulesIos, language), // rules without Vegas, as on iOS
        gameSettings = {
            Column {
                SegmentedControl(
                    items = listOf(DrawMode.DrawOne, DrawMode.DrawThree),
                    selectedItem = options.drawMode,
                    onItemSelection = { if (it != options.drawMode) requestOptions(options.copy(drawMode = it)) },
                    itemLabel = {
                        if (it == DrawMode.DrawOne) Strings.get(StringKey.DrawOne, language)
                        else Strings.get(StringKey.DrawThree, language)
                    }
                )
                // No Vegas Scoring toggle — betting-style scoring is off on Android, as on iOS.
            }
        }
    )
}
