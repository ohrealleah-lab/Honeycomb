package com.leah.honeycomb

import kotlinx.serialization.Serializable

@Serializable
enum class PileType {
    Stock,
    Waste,
    Tableau,
    Foundation,
    FreeCell
}

@Serializable
data class Pile(
    val id: String,
    val type: PileType,
    val cards: List<Card> = emptyList()
) {
    val isEmpty: Boolean get() = cards.isEmpty()
    
    val topCard: Card? get() = cards.lastOrNull()
}
