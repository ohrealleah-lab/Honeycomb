package com.leah.honeycomb.beecell

import kotlinx.serialization.Serializable

@Serializable
data class BeecellOptions(
    val autoMoveToFoundation: Boolean = true
)
