package com.leah.honeycomb.spider

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.leah.honeycomb.OptionsFullScreenView
import com.leah.honeycomb.SegmentedControl
import com.leah.honeycomb.Strings
import com.leah.honeycomb.LocalAppContainer

@Composable
fun SpiderOptionsScreen(
    viewModel: SpiderViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {},
    onShowStats: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()
    val appContainer = LocalAppContainer.current
    val sharedOptions = appContainer.sharedOptions
    val language by appContainer.language.collectAsState()

    // Changing mode (or Vegas) deals a new game — if one is in progress, ask first
    // (same prompt as Mac's Options OK, iOS and Windows) instead of ending it on the tap.
    var pendingOptions by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<SpiderOptions?>(null) }
    val gameState by viewModel.state.collectAsState()
    fun requestOptions(newOptions: SpiderOptions) {
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
        gameSectionTitle = "Spider",
        helpText = Strings.get(StringKey.HelpSpiderRules, language),
        onDismiss = onBack,
        onShowStats = onShowStats,
        gameSettings = {
            SegmentedControl(
                items = listOf(1, 2, 4),
                selectedItem = options.suitCount,
                onItemSelection = { if (it != options.suitCount) requestOptions(options.copy(suitCount = it)) },
                itemLabel = {
                    when (it) {
                        1 -> Strings.get(StringKey.SuitCount1, language)
                        2 -> Strings.get(StringKey.SuitCount2, language)
                        else -> Strings.get(StringKey.SuitCount4, language)
                    }
                }
            )
        }
    )
}
