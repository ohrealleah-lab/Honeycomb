package com.leah.honeycomb.blackjack

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BlackjackOptionsScreen(
    viewModel: BlackjackViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Blackjack Options") },
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
            Text("Starting Credits", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            // Option to rebuy manually would go here in a full implementation
            Text("Current starting credits setting: ${options.startingCredits}")

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