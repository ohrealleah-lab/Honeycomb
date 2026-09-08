package com.leah.honeycomb

import androidx.compose.runtime.Immutable
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class Suit {
    Hearts, Diamonds, Spades, Clubs;

    val isRed: Boolean
        get() = this == Hearts || this == Diamonds
        
    val symbol: String
        get() = when (this) {
            Hearts -> "♥"
            Diamonds -> "♦"
            Spades -> "♠"
            Clubs -> "♣"
        }
}

@Immutable
@Serializable
data class Card(
    @Serializable(with = UUIDSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val suit: Suit,
    val rank: Int,
    val faceUp: Boolean = false
) {
    val isRed: Boolean get() = suit.isRed
    val isBlack: Boolean get() = !suit.isRed

    val isFaceCard: Boolean
        get() = rank == 11 || rank == 12 || rank == 13

    val rankString: String
        get() = when (rank) {
            1 -> "A"
            11 -> "J"
            12 -> "Q"
            13 -> "K"
            else -> rank.toString()
        }
}
