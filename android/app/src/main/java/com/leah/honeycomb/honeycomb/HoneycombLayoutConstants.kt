package com.leah.honeycomb.honeycomb

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// Mirrors shared/Models/LayoutConstants.swift + the size constants at the top of
// ios/Honeycomb/Games/HoneycombTouchView.swift (lines 18-22). Height/width, so a card
// is TALLER than it is wide (portrait orientation) — matches CardDimensions.aspectRatio.
object HoneycombLayout {
    const val cardAspect: Float = 181f / 128f

    val boardCardWidth: Dp = 150.dp
    val boardCardHeight: Dp = (150f * cardAspect).dp

    // Used for BOTH opponent and player hands — iOS unified these deliberately
    // (HoneycombTouchView.swift:591-592), replacing Android's previous 100dp/120dp split.
    val handCardWidth: Dp = 116.dp
    val handCardHeight: Dp = (116f * cardAspect).dp

    val boardSpacingBase: Dp = 10.dp
    val handSpacing: Dp = 6.dp

    // Mirrors boardSpacing(for cardWidth:) — gaps shrink/grow proportionally to the
    // active card width rather than staying a fixed 10dp regardless of scale.
    fun boardSpacing(cardWidth: Dp): Dp = boardSpacingBase * (cardWidth / boardCardWidth)

    // Landscape floor for computeLandscapeHandCardSize's derived card width.
    val landscapeMinCardWidth: Dp = 40.dp
}
