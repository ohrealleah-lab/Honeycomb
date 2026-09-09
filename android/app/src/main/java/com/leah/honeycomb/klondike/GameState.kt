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
    val recyclesCount: Int = 0,
    val wasteDisplayCount: Int = 0,
    val vegasBankroll: Int = 0,
    val vegasBankrollAtGameStart: Int = 0
)
