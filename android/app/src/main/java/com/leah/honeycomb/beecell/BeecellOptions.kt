package com.leah.honeycomb.beecell

import kotlinx.serialization.Serializable

@Serializable
data class BeecellOptions(
    val freeCellCount: Int = 4, // 1 to 4 cells
    val autoMoveToFoundation: Boolean = true
)
