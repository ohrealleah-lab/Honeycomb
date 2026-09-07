package com.leah.honeycomb

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SharedOptionsScreen(onBack: () -> Unit) {
    val appContainer = LocalAppContainer.current
    val sharedOptions = appContainer.sharedOptions
    
    val isSoundEnabled by sharedOptions.isSoundEnabled.collectAsState()
    val honeyMode by sharedOptions.honeyMode.collectAsState()
    val hideHintButton by sharedOptions.hideHintButton.collectAsState()
    val noStressMode by sharedOptions.noStressMode.collectAsState()
    val manuallyDismissBanners by sharedOptions.manuallyDismissBanners.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Shared Options") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            SwitchOptionRow(
                label = "Sound Enabled",
                checked = isSoundEnabled,
                onCheckedChange = { sharedOptions.setSoundEnabled(it) }
            )
            SwitchOptionRow(
                label = "Honey Mode",
                checked = honeyMode,
                onCheckedChange = { sharedOptions.setHoneyMode(it) }
            )
            SwitchOptionRow(
                label = "Hide Hint Button",
                checked = hideHintButton,
                onCheckedChange = { sharedOptions.setHideHintButton(it) }
            )
            SwitchOptionRow(
                label = "No Stress Mode",
                checked = noStressMode,
                onCheckedChange = { sharedOptions.setNoStressMode(it) }
            )
            SwitchOptionRow(
                label = "Manually Dismiss Banners",
                checked = manuallyDismissBanners,
                onCheckedChange = { sharedOptions.setManuallyDismissBanners(it) }
            )
        }
    }
}

@Composable
fun SwitchOptionRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
