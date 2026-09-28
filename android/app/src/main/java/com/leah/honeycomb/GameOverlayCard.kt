package com.leah.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

// Shared styling for a win/lose/autocomplete banner card — matches iOS's postGameOverlay
// treatment (dark 0.75-alpha card, rounded corners, gold shadow glow, dismiss X in the
// top-trailing corner) rather than a bare Material3 Card{} with the theme's default
// surface color, which is what Klondike/Beecell/Spider's win/stuck/autocomplete overlays
// used before this. Honeycomb's own post-game overlay (HoneycombMatchUI.kt) has the
// identical styling inlined rather than using this — this is the shared version other
// games' Board files should call instead of duplicating it themselves.
@Composable
fun GameOverlayCard(
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Box(modifier) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .shadow(16.dp, RoundedCornerShape(16.dp), spotColor = Color(0xFFFFD700).copy(alpha = 0.5f))
                .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(16.dp))
                .padding(horizontal = 28.dp, vertical = 20.dp),
            content = content
        )
        if (onDismiss != null) {
            IconButton(
                onClick = onDismiss,
                modifier = Modifier.align(Alignment.TopEnd)
            ) {
                Icon(Icons.Default.Close, contentDescription = com.leah.honeycomb.tr(StringKey.DismissA11y), tint = Color.White.copy(alpha = 0.8f))
            }
        }
    }
}
