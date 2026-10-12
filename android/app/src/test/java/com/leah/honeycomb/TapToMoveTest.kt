package com.leah.honeycomb

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Tap a card, then tap a pile: the selection rules shared by Klondike, Beecell and Spider.
class TapToMoveTest {
    private val a = Card(suit = Suit.Spades, rank = 5, faceUp = true)
    private val b = Card(suit = Suit.Hearts, rank = 4, faceUp = true)
    private val c = Card(suit = Suit.Clubs, rank = 9, faceUp = true)
    private val col1 = Pile("t1", PileType.Tableau, listOf(a, b))
    private val col2 = Pile("t2", PileType.Tableau, listOf(c))
    private val col3 = Pile("t3", PileType.Tableau, emptyList())
    private val piles = listOf(col1, col2, col3)
    private val anyFaceUp: (Pile, Int) -> Boolean = { p, i -> p.cards[i].faceUp }

    @Test
    fun tapPicksUpTheCardAndEverythingOnTopThenMovesToTheTappedPile() {
        val tap = TapToMove()
        var moved: Triple<String, List<Card>, String>? = null
        val tryMove: (Pile, List<Card>, Pile) -> Boolean = { from, cards, to -> moved = Triple(from.id, cards, to.id); true }

        assertEquals(TapResult.Selected, tap.onCardTap("t1", a.id, piles, anyFaceUp, tryMove))
        assertEquals(true, tap.isSelected(b, "t1", piles, anyFaceUp)) // the card on top comes along

        assertEquals(TapResult.Moved, tap.onPileTap("t3", piles, anyFaceUp, tryMove))
        assertEquals(Triple("t1", listOf(a, b), "t3"), moved)
        assertNull(tap.selection)
    }

    @Test
    fun aPileThatCantTakeItKeepsTheSelection() {
        val tap = TapToMove()
        tap.onCardTap("t1", b.id, piles, anyFaceUp) { _, _, _ -> false }
        assertEquals(TapResult.Rejected, tap.onCardTap("t2", c.id, piles, anyFaceUp) { _, _, _ -> false })
        assertEquals(TapSelection("t1", b.id), tap.selection)
    }

    @Test
    fun tappingThePickedCardAgainPutsItDown() {
        val tap = TapToMove()
        val never: (Pile, List<Card>, Pile) -> Boolean = { _, _, _ -> error("no move expected") }
        tap.onCardTap("t1", b.id, piles, anyFaceUp, never)
        assertEquals(TapResult.Cleared, tap.onCardTap("t1", b.id, piles, anyFaceUp, never))
        assertNull(tap.selection)
    }

    @Test
    fun aCardThatCantBePickedUpIsIgnored() {
        val tap = TapToMove()
        assertEquals(TapResult.None, tap.onCardTap("t1", a.id, piles, { _, _ -> false }) { _, _, _ -> true })
        assertNull(tap.selection)
    }
}
