package com.leah.honeycomb.beecell

import com.leah.honeycomb.Pile
import kotlinx.serialization.Serializable

@Serializable
data class BeecellState(
    val freeCells: List<Pile> = emptyList(),
    val foundations: List<Pile> = emptyList(),
    val tableau: List<Pile> = emptyList(),
    val movesCount: Int = 0,
    val hasWon: Boolean = false,
    val timerSeconds: Int = 0,
    val isTimerActive: Boolean = false
)
