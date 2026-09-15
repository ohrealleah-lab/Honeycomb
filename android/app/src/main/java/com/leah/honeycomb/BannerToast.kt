package com.leah.honeycomb

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex

// Shared catalog-backed banner/toast overlay — milestones, loading flavor, idle
// nudges, out-of-credits, etc. (see BannerCatalog.kt/BannerQueue). Used by every
// non-Honeycomb game's Board composable; Honeycomb keeps its own inline copy in
// HoneycombMatchUI.kt since it also renders the multi-line match-start rule
// announcement banner with the same visual treatment.
@Composable
fun BannerToast(
    text: String?,
    manuallyDismissBanners: Boolean,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .zIndex(250f)
            .then(if (manuallyDismissBanners && text != null) Modifier.clickable { onDismiss() } else Modifier),
        contentAlignment = Alignment.Center
    ) {
        AnimatedVisibility(
            visible = text != null,
            enter = fadeIn(animationSpec = tween(150)),
            exit = fadeOut(animationSpec = tween(300))
        ) {
            Box(
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 36.dp, vertical = 20.dp)
            ) {
                Text(
                    text ?: "",
                    // Matches shared/Views/FlashBannerView.swift's golden yellow
                    // (Color(red: 1.0, green: 0.84, blue: 0.0)), not pure Color.Yellow.
                    color = Color(1f, 0.84f, 0f),
                    fontSize = 36.sp,
                    lineHeight = 44.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}
