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
        helpText = "",
        onDismiss = onBack,
        onShowStats = onShowStats,
        gameSettings = {
            SegmentedControl(
                items = VideoPokerVariant.values().toList(),
                selectedItem = options.variant,
                onItemSelection = { viewModel.updateVariant(it) },
                itemLabel = { it.name }
            )
        }
    )
}
