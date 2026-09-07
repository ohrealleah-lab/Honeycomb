package com.leah.honeycomb.spider

import com.leah.honeycomb.Pile
import kotlinx.serialization.Serializable

@Serializable
data class SpiderState(
    val stock: Pile = Pile(id = "stock", type = com.leah.honeycomb.PileType.Stock),
    val tableau: List<Pile> = emptyList(),
    val foundations: List<Pile> = emptyList(), // Typically 8 foundations
    val score: Int = 500,
    val movesCount: Int = 0,
    val hasWon: Boolean = false,
    val timerSeconds: Int = 0,
    val isTimerActive: Boolean = false,
    val hintAvailable: Boolean = false
)
