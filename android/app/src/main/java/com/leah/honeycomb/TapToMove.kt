package com.leah.honeycomb

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.keyframes
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import java.util.UUID

// Tap to move (Klondike / Beecell / Spider) — iOS's TapSelection/TapSelectedCard.
// Alternative to dragging, always on: tap a card to pick it (and everything on top of it)
// up, then tap the pile it should go to. Tapping the picked card again, or the felt,
// puts it down; a pile that can't take it shakes the selection and keeps it picked up.

/** The picked-up stack, identified by its pile and its bottom card. */
data class TapSelection(val pileId: String, val cardId: UUID)

enum class TapResult { Selected, Moved, Rejected, Cleared, None }

@Stable
class TapToMove {
    var selection by mutableStateOf<TapSelection?>(null)
    /** Horizontal wobble (px) applied to the picked-up cards after a rejected tap. */
    val shake = Animatable(0f)

    fun clear() { selection = null }

    /** The picked-up pile and stack, re-read from the live board (null if it no longer matches). */
    fun selectedStack(piles: List<Pile>, canSelect: (Pile, Int) -> Boolean): Pair<Pile, List<Card>>? {
        val sel = selection ?: return null
        val pile = piles.firstOrNull { it.id == sel.pileId } ?: return null
        val index = pile.cards.indexOfFirst { it.id == sel.cardId }
        if (index < 0 || !canSelect(pile, index)) return null
        return pile to pile.cards.subList(index, pile.cards.size)
    }

    fun isSelected(card: Card, pileId: String, piles: List<Pile>, canSelect: (Pile, Int) -> Boolean): Boolean {
        val (pile, cards) = selectedStack(piles, canSelect) ?: return false
        return pile.id == pileId && cards.any { it.id == card.id }
    }

    /**
     * A tap on a card. [tryMove] attempts the move (same rules as a drop) and returns whether
     * it happened.
     */
    fun onCardTap(
        pileId: String, cardId: UUID, piles: List<Pile>,
        canSelect: (Pile, Int) -> Boolean,
        tryMove: (from: Pile, cards: List<Card>, to: Pile) -> Boolean
    ): TapResult {
        val pile = piles.firstOrNull { it.id == pileId } ?: return TapResult.None
        val index = pile.cards.indexOfFirst { it.id == cardId }
        if (index < 0) return TapResult.None
        val selected = selectedStack(piles, canSelect)
        if (selected != null) {
            val (fromPile, cards) = selected
            if (fromPile.id == pile.id) {
                // Same pile: tapping the picked-up card puts it down; another card picks that one up instead.
                return if (cards.first().id == cardId || !canSelect(pile, index)) {
                    selection = null; TapResult.Cleared
                } else {
                    selection = TapSelection(pile.id, cardId); TapResult.Selected
                }
            }
            return move(fromPile, cards, pile, tryMove)
        }
        if (!canSelect(pile, index)) return TapResult.None
        selection = TapSelection(pile.id, cardId)
        return TapResult.Selected
    }

    /** A tap on a pile's empty space (an empty column/cell/foundation, or below a column). */
    fun onPileTap(
        pileId: String, piles: List<Pile>,
        canSelect: (Pile, Int) -> Boolean,
        tryMove: (from: Pile, cards: List<Card>, to: Pile) -> Boolean
    ): TapResult {
        val (fromPile, cards) = selectedStack(piles, canSelect) ?: return TapResult.None
        if (fromPile.id == pileId) { selection = null; return TapResult.Cleared }
        val target = piles.firstOrNull { it.id == pileId } ?: return TapResult.None
        return move(fromPile, cards, target, tryMove)
    }

    private fun move(
        from: Pile, cards: List<Card>, to: Pile,
        tryMove: (from: Pile, cards: List<Card>, to: Pile) -> Boolean
    ): TapResult =
        if (tryMove(from, cards, to)) { selection = null; TapResult.Moved } else TapResult.Rejected

    suspend fun playShake(amplitudePx: Float) {
        shake.snapTo(0f)
        shake.animateTo(0f, keyframes {
            durationMillis = 300
            amplitudePx at 50
            -amplitudePx at 125
            amplitudePx at 200
            -amplitudePx at 260
        })
    }
}

@Composable
fun rememberTapToMove(): TapToMove = remember { TapToMove() }

/** Steady outline (hint gold) around a picked-up card, plus the rejected-tap wobble. */
fun Modifier.tapSelected(isSelected: Boolean, tap: TapToMove): Modifier =
    if (!isSelected) this
    else this
        .graphicsLayer { translationX = tap.shake.value }
        .border(3.dp, HintHighlightGold, RoundedCornerShape(4.dp))
