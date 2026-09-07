package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HoneycombOptionsScreen(
    viewModel: HoneycombViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Honeycomb Options") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
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
            Text("Opponent Difficulty", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))

            val difficulties = listOf(
                HoneycombDifficulty.Easy to "Baby Bee (Easy)",
                HoneycombDifficulty.Medium to "Honey Bee (Medium)",
                HoneycombDifficulty.Hard to "Queen Bee (Hard)",
                HoneycombDifficulty.UltraHard to "Killer Bee (Ultra Hard)"
            )
            difficulties.forEach { (difficulty, label) ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(
                        selected = options.difficulty == difficulty,
                        onClick = { viewModel.updateOptions(options.copy(difficulty = difficulty)) }
                    )
                    Text(label)
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
