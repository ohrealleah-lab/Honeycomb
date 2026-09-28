package com.leah.honeycomb.beecell

import com.leah.honeycomb.Pile
import kotlinx.serialization.Serializable

@Serializable
data class BeecellState(
    val freeCells: List<Pile> = emptyList(),
    val foundations: List<Pile> = emptyList(),
    val tableau: List<Pile> = emptyList(),
    val score: Int = 0,
    val movesCount: Int = 0,
    val hasWon: Boolean = false,
    // True once any part of this game was played with No Stress Mode on (a move made while
    // it was on, or it toggled mid-game). Turning it on zeroes the timer and turning it off
    // restarts it from there, so without this a player could play most of a game untimed,
    // switch No Stress off before the last move and record a few-second Best Time (plus
    // Klondike's 700,000/seconds time bonus). Such a win still counts but records no time.
    // In state (not the ViewModel) so it survives a relaunch; Undo keeps the current value.
    val untimedThisGame: Boolean = false,
    val timerSeconds: Int = 0,
    val isTimerActive: Boolean = false
)
