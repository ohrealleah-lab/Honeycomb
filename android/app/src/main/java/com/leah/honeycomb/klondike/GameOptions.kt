package com.leah.honeycomb.klondike

import kotlinx.serialization.Serializable

@Serializable
data class GameOptions(
    val isTimed: Boolean = true,
    val isStatusBarVisible: Boolean = true,
    val isVegasScoring: Boolean = false,
    val isDrawConstraintsEnabled: Boolean = false,
    val deckCount: Int = 1,
    val drawMode: DrawMode = DrawMode.DrawThree
)
