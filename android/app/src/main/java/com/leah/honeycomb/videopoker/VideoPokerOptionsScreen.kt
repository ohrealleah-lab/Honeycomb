package com.leah.honeycomb.videopoker

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideoPokerOptionsScreen(
    viewModel: VideoPokerViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Video Poker Options") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Text("<")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            Text("Variant", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            
            VideoPokerVariant.values().forEach { variant ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(
                        selected = options.variant == variant,
                        onClick = { viewModel.updateVariant(variant) }
                    )
                    Text(variant.name)
                }
            }

            Spacer(modifier = Modifier.weight(1f))
            HorizontalDivider(modifier = Modifier.padding(vertical = 16.dp))
            OutlinedButton(onClick = onOpenThemes, modifier = Modifier.fillMaxWidth()) {
                Text("Themes & Customization")
            }
            OutlinedButton(onClick = onOpenSharedOptions, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Text("Global Settings")
            }
        }
    }
}