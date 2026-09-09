package com.leah.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

// zeroPlaceholder distinguishes "no data yet" (stats screens, default "--:--") from a
// live timer that's genuinely at zero (HUD displays, which want "00:00").
fun formatSeconds(totalSeconds: Int, zeroPlaceholder: String = "--:--"): String {
    if (totalSeconds <= 0) return zeroPlaceholder
    val mins = totalSeconds / 60
    val secs = totalSeconds % 60
    return "%02d:%02d".format(mins, secs)
}

// Mirrors SwitchOptionRow/NavigationRow's shape — a plain label/value pair, no
// interaction, meant to sit inside a RoundedContainer just like the options rows.
@Composable
fun StatRow(label: String, value: String, valueColor: Color = Color.Unspecified) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge)
        Text(text = value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = valueColor)
    }
}

// Same Scaffold/TopAppBar/"Done" shell as OptionsFullScreenView (SharedOptionsScreen.kt),
// with no reset control — iOS has none either, so neither does this port.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatisticsFullScreenView(
    title: String,
    onDismiss: () -> Unit,
    content: @Composable () -> Unit
) {
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(title, fontWeight = FontWeight.Bold) },
                actions = {
                    TextButton(onClick = onDismiss) {
                        Text("Done", color = Color(0xFF007AFF), fontWeight = FontWeight.Bold)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Spacer(modifier = Modifier.height(8.dp))
            content()
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
