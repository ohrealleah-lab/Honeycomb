package com.leah.honeycomb.beecell

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
fun BeecellOptionsScreen(
    viewModel: BeecellViewModel,
    onBack: () -> Unit,
    onOpenThemes: () -> Unit = {},
    onOpenSharedOptions: () -> Unit = {}
) {
    val options by viewModel.options.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Beecell Options") },
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
            Text("Free Cells Count", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.freeCellCount == 1,
                    onClick = { viewModel.updateOptions(options.copy(freeCellCount = 1)) }
                )
                Text("1 Cell")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.freeCellCount == 2,
                    onClick = { viewModel.updateOptions(options.copy(freeCellCount = 2)) }
                )
                Text("2 Cells")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.freeCellCount == 3,
                    onClick = { viewModel.updateOptions(options.copy(freeCellCount = 3)) }
                )
                Text("3 Cells")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = options.freeCellCount == 4,
                    onClick = { viewModel.updateOptions(options.copy(freeCellCount = 4)) }
                )
                Text("4 Cells")
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