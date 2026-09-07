package com.leah.honeycomb.klondike

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KlondikeOptionsSheet(
    viewModel: GameViewModel,
    onDismiss: () -> Unit
) {
    val options by viewModel.options.collectAsState()
    val sharedOptions = LocalAppContainer.current.sharedOptions
    val honeyMode by sharedOptions.honeyMode.collectAsState(initial = false)
    val noStressMode by sharedOptions.noStressMode.collectAsState(initial = false)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Options") },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text("Klondike Rules", style = MaterialTheme.typography.titleMedium)
            
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Draw Mode")
                Button(onClick = { 
                    viewModel.updateOptions(options.copy(drawMode = if (options.drawMode == DrawMode.DrawOne) DrawMode.DrawThree else DrawMode.DrawOne)) 
                }) {
                    Text(if (options.drawMode == DrawMode.DrawOne) "Draw 1" else "Draw 3")
                }
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Vegas Scoring")
                Switch(
                    checked = options.isVegasScoring,
                    onCheckedChange = { viewModel.updateOptions(options.copy(isVegasScoring = it)) }
                )
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Timed Match")
                Switch(
                    checked = options.isTimed,
                    onCheckedChange = { viewModel.updateOptions(options.copy(isTimed = it)) }
                )
            }
            
            Divider()
            Text("Global Settings", style = MaterialTheme.typography.titleMedium)
            
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Honey Mode")
                Switch(
                    checked = honeyMode,
                    onCheckedChange = { sharedOptions.setHoneyMode(it) }
                )
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("No Stress Mode")
                Switch(
                    checked = noStressMode,
                    onCheckedChange = { sharedOptions.setNoStressMode(it) }
                )
            }
        }
    }
}
