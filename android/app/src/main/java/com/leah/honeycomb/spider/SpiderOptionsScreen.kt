package com.leah.honeycomb.spider

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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

    DisposableEffect(viewModel) {
        sharedOptions.onNoStressModeChange = { viewModel.reactToNoStressModeChange() }
        onDispose { sharedOptions.onNoStressModeChange = null }
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
                onItemSelection = { viewModel.updateOptions(options.copy(suitCount = it)) },
                itemLabel = {
                    when (it) {
                        1 -> "1 Suit"
                        2 -> "2 Suits"
                        else -> "4 Suits"
                    }
                }
            )
        }
    )
}
