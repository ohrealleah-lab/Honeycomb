package com.leah.honeycomb.klondike

import com.leah.honeycomb.Card
import com.leah.honeycomb.Pile
import com.leah.honeycomb.PileType
import kotlinx.serialization.Serializable

@Serializable
enum class DrawMode {
    DrawOne,
    DrawThree
}

@Serializable
data class GameState(
    val stock: Pile = Pile(id = "stock", type = PileType.Stock),
    val waste: Pile = Pile(id = "waste", type = PileType.Waste),
    val foundations: List<Pile> = listOf(
        Pile(id = "foundation_Spades", type = PileType.Foundation),
        Pile(id = "foundation_Clubs", type = PileType.Foundation),
        Pile(id = "foundation_Diamonds", type = PileType.Foundation),
        Pile(id = "foundation_Hearts", type = PileType.Foundation)
    ),
    val tableau: List<Pile> = List(7) { index -> Pile(id = "tableau_$index", type = PileType.Tableau) },
    val score: Int = 0,
    val movesCount: Int = 0,
    val timerSeconds: Int = 0,
    val isTimerActive: Boolean = false,
    val drawMode: DrawMode = DrawMode.DrawThree,
    val hasWon: Boolean = false,
    // True once any part of this game was played with No Stress Mode on (a move made while
    // it was on, or it toggled mid-game). Turning it on zeroes the timer and turning it off
    // restarts it from there, so without this a player could play most of a game untimed,
    // switch No Stress off before the last move and record a few-second Best Time (plus
    // Klondike's 700,000/seconds time bonus). Such a win still counts but records no time.
    // In state (not the ViewModel) so it survives a relaunch; Undo keeps the current value.
    val untimedThisGame: Boolean = false,
    val recyclesCount: Int = 0,
    val wasteDisplayCount: Int = 0,
    val vegasBankroll: Int = 0,
    val vegasBankrollAtGameStart: Int = 0
)
