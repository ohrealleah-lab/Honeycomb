package com.leah.honeycomb.honeycomb

import com.leah.honeycomb.StringKey
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// The deck editor's rarity caps (same rules as Mac/iOS/Windows): at most one 5★; with a 5★
// present at most one 4★; otherwise at most two 4★. Card ids here are just the star level
// itself, so the lookup is the identity — what matters is the star counts.
class HoneycombDeckRulesTest {
    private fun error(vararg stars: Int): StringKey? =
        HoneycombProfileManager.deckRarityError(stars.toList()) { it }

    @Test
    fun validDecksPass() {
        assertNull(error(5, 4, 3, 3, 3))   // the strongest legal mix
        assertNull(error(4, 4, 3, 3, 3))   // two 4★ with no 5★
        assertNull(error(1, 1, 1, 2, 2))   // the starter deck
    }

    @Test
    fun rejectsMoreThanOneFiveStar() {
        assertEquals(StringKey.ErrTooMany5star, error(5, 5, 3, 3, 3))
        assertEquals(StringKey.ErrTooMany5star, error(5, 5, 5, 5, 5))
    }

    @Test
    fun rejectsExtraFourStarsAlongsideAFiveStar() {
        assertEquals(StringKey.Err5star4starCombo, error(5, 4, 4, 3, 3))
    }

    @Test
    fun rejectsThreeFourStarsWithoutAFiveStar() {
        assertEquals(StringKey.ErrTooMany4star, error(4, 4, 4, 3, 3))
    }

    @Test
    fun unknownCardsAreIgnored() {
        // A card id the database no longer knows can't count toward a cap.
        val result = HoneycombProfileManager.deckRarityError(listOf(1, 2, 3, 4, 5)) { null }
        assertNull(result)
    }
}
