package com.leah.honeycomb.spider

import kotlinx.serialization.Serializable

@Serializable
data class SpiderOptions(
    val suitCount: Int = 1, // 1, 2, or 4 — 1 (easiest) is the default, matching the Swift source
    val highlightValidMoves: Boolean = false
)
