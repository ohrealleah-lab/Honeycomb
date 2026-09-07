package com.leah.honeycomb

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.cos

// Gold used for every hint highlight across all 4 games — matches iOS's default
// hintHighlightColor and Android's own existing steal-highlight gold.
val HintHighlightGold = Color(0xFFFFD700)

// Ported from iOS's TouchHintHighlight/TouchHintAnimatable
// (ios/Honeycomb/Views/TouchCardView.swift:234-284): a ONE-SHOT 1.8s linear phase 0->1,
// opacity = (1 - cos(phase * PI * 4)) / 2 — this pulses twice over 1.8s then settles at
// 0 opacity (roughly matching the 2s hint-auto-clear timer used everywhere), it is NOT
// an infinite repeat. Fades back to 0 over ~100ms when un-highlighted, animating the same
// underlying phase (not the opacity directly) so the fade-out follows the identical curve.
fun Modifier.hintHighlight(
    isHighlighted: Boolean,
    cornerRadius: Dp = 8.dp,
    color: Color = HintHighlightGold
): Modifier = composed {
    var phase by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(isHighlighted) {
        if (isHighlighted) {
            animate(0f, 1f, animationSpec = tween(durationMillis = 1800, easing = LinearEasing)) { value, _ -> phase = value }
        } else {
            animate(phase, 0f, animationSpec = tween(durationMillis = 100)) { value, _ -> phase = value }
        }
    }
    val opacity = ((1f - cos(phase * Math.PI.toFloat() * 4f)) / 2f).coerceIn(0f, 1f)

    this
        .graphicsLayer {
            shadowElevation = if (opacity > 0.01f) 8.dp.toPx() else 0f
            shape = RoundedCornerShape(cornerRadius)
            clip = false
            ambientShadowColor = color.copy(alpha = opacity)
            spotShadowColor = color.copy(alpha = opacity)
        }
        .border(4.dp, color.copy(alpha = opacity), RoundedCornerShape(cornerRadius))
}
