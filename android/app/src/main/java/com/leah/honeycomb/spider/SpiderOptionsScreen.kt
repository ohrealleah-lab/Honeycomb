package com.leah.honeycomb.spider

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
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
fun SpiderOptionsScreen(
    viewModel: SpiderViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Spider Options") },
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
            Text("Suit Count (Difficulty)", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.suitCount == 1,
                    onClick = { viewModel.updateOptions(options.copy(suitCount = 1)) }
                )
                Text("1 Suit (Easy)")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.suitCount == 2,
                    onClick = { viewModel.updateOptions(options.copy(suitCount = 2)) }
                )
                Text("2 Suits (Medium)")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.suitCount == 4,
                    onClick = { viewModel.updateOptions(options.copy(suitCount = 4)) }
                )
                Text("4 Suits (Hard)")
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