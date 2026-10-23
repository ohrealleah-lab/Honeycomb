package com.leah.honeycomb.klondike

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.leah.honeycomb.Card
import com.leah.honeycomb.Pile
import com.leah.honeycomb.PileType
import com.leah.honeycomb.PreferencesHelper
import com.leah.honeycomb.Suit
import com.leah.honeycomb.ViewModelTestBase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// Player-visible Klondike behaviour on fixed layouts, ported from Mac's KlondikeGameplayTests:
// exact point values, the undo penalty, move legality, draw and recycle, the timed-win bonus,
// No Stress, "no moves left", Autocomplete, and what survives a relaunch. Android has no Vegas
// scoring (hard-off), so those Mac cases are not ported; hints are timing-dependent and skipped.
@OptIn(ExperimentalCoroutinesApi::class)
class KlondikeGameplayTest : ViewModelTestBase() {

    // ---- Fixtures ----

    private class Rig(val vm: GameViewModel, val ds: DataStore<Preferences>)

    private fun newRig(ds: DataStore<Preferences> = newDataStore()): Rig {
        val shared = newSharedOptions(ds)
        return Rig(GameViewModel(shared, ds, newBannerCatalog(ds, shared)), ds)
    }

    private fun newVm() = newRig().vm

    private val foundationSuits = listOf(Suit.Spades, Suit.Clubs, Suit.Diamonds, Suit.Hearts)

    private fun c(suit: Suit, rank: Int, up: Boolean = true) = Card(suit = suit, rank = rank, faceUp = up)

    // Hand-built board. `found` gives how many cards (A…n) each foundation already holds.
    private fun GameViewModel.board(
        tableau: List<List<Card>> = emptyList(),
        stock: List<Card> = emptyList(),
        waste: List<Card> = emptyList(),
        found: Map<Suit, Int> = emptyMap(),
        draw: DrawMode = DrawMode.DrawThree
    ) {
        val flow = privateFlow<GameState>(this, "_state")
        flow.value = flow.value.copy(
            drawMode = draw,
            tableau = (0 until 7).map { Pile("tableau_$it", PileType.Tableau, tableau.getOrElse(it) { emptyList() }) },
            foundations = foundationSuits.map { suit ->
                Pile("foundation_${suit.name}", PileType.Foundation, (1..(found[suit] ?: 0)).map { Card(suit = suit, rank = it, faceUp = true) })
            },
            stock = Pile("stock", PileType.Stock, stock),
            waste = Pile("waste", PileType.Waste, waste),
            wasteDisplayCount = if (waste.isEmpty()) 0 else if (draw == DrawMode.DrawOne) 1 else minOf(3, waste.size),
            score = 0, movesCount = 0, timerSeconds = 0, isTimerActive = false, hasWon = false, recyclesCount = 0
        )
        privateFlow<Boolean>(this, "_isStuck").value = false
        privateFlow<Boolean>(this, "_isStockExhausted").value = false
        privateFlow<Boolean>(this, "_isAutocompleteAvailable").value = false
        privateFlow<Any?>(this, "_pointPopup").value = null
        clearHint()
    }

    private fun GameViewModel.setState(f: (GameState) -> GameState) {
        val flow = privateFlow<GameState>(this, "_state")
        flow.value = f(flow.value)
    }

    private fun GameViewModel.t(i: Int) = state.value.tableau[i]
    private fun GameViewModel.f(i: Int) = state.value.foundations[i]
    private val GameViewModel.waste get() = state.value.waste
    private val GameViewModel.stock get() = state.value.stock

    // Three lone kings: nothing in them can move.
    private fun deadTableau() = listOf(
        listOf(c(Suit.Spades, 13)), listOf(c(Suit.Hearts, 13)), listOf(c(Suit.Diamonds, 13)), listOf(c(Suit.Clubs, 13)),
        listOf(c(Suit.Spades, 9)), listOf(c(Suit.Hearts, 7)), listOf(c(Suit.Spades, 5))
    )

    // 51 cards done except the K♠, alone in column 0.
    private fun GameViewModel.oneCardFromWinning() =
        board(tableau = listOf(listOf(c(Suit.Spades, 13))), found = mapOf(Suit.Spades to 12, Suit.Clubs to 13, Suit.Diamonds to 13, Suit.Hearts to 13))

    private fun GameViewModel.playLastCard() = moveCards(listOf(t(0).cards[0]), t(0), f(0))

    private fun GameViewModel.stats() = statistics.value

    private fun GameViewModel.popup() = pointPopup.value

    // ---- Deal ----

    @Test fun dealLayout() {
        val vm = newVm()
        val s = vm.state.value
        assertEquals(listOf(1, 2, 3, 4, 5, 6, 7), s.tableau.map { it.cards.size })
        assertTrue("Only the top card of each column is face up",
            s.tableau.all { col -> col.cards.dropLast(1).none { it.faceUp } && col.cards.last().faceUp })
        assertEquals(24, s.stock.cards.size)
        assertTrue(s.stock.cards.none { it.faceUp })
        assertTrue(s.waste.isEmpty)
        assertEquals(4, s.foundations.size)
        assertEquals(52, (s.tableau.flatMap { it.cards } + s.stock.cards).map { it.suit to it.rank }.toSet().size)
        assertEquals(1, vm.stats().gamesPlayed)
    }

    // ---- Scoring ----

    @Test fun standardScoringForEveryKindOfMove() {
        val vm = newVm()

        // Waste → tableau: +5
        val five = c(Suit.Hearts, 5)
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 6))), waste = listOf(five))
        vm.moveCards(listOf(five), vm.waste, vm.t(0))
        assertEquals(5, vm.state.value.score)
        assertEquals("+5", vm.popup()?.displayText)
        assertEquals(five.id, vm.popup()?.cardId)
        assertEquals(true, vm.popup()?.isPositive)

        // Waste → foundation: +10
        val ace = c(Suit.Spades, 1)
        vm.board(waste = listOf(ace))
        vm.moveCards(listOf(ace), vm.waste, vm.f(0))
        assertEquals(10, vm.state.value.score)
        assertEquals("+10", vm.popup()?.displayText)

        // Tableau → foundation (+10) that reveals a card (+5)
        val hidden = c(Suit.Diamonds, 3, up = false)
        val aceC = c(Suit.Clubs, 1)
        vm.board(tableau = listOf(listOf(hidden, aceC)))
        vm.moveCards(listOf(aceC), vm.t(0), vm.f(1))
        assertEquals(15, vm.state.value.score)
        assertEquals("The popup shows the foundation move", "+10", vm.popup()?.displayText)
        assertTrue("The uncovered card turns face up", vm.t(0).cards.last().faceUp)

        // Tableau → tableau that only reveals a card: +5, popup on the revealed card
        val nine = c(Suit.Clubs, 9, up = false)
        val h5 = c(Suit.Hearts, 5)
        vm.board(tableau = listOf(listOf(nine, h5), listOf(c(Suit.Spades, 6))))
        vm.moveCards(listOf(h5), vm.t(0), vm.t(1))
        assertEquals(5, vm.state.value.score)
        assertEquals("+5", vm.popup()?.displayText)
        assertEquals(nine.id, vm.popup()?.cardId)

        // A plain tableau shuffle scores nothing
        vm.board(tableau = listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6))))
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.t(1))
        assertEquals(0, vm.state.value.score)
        assertNull(vm.popup())

        // Foundation → tableau: −15
        val two = c(Suit.Spades, 2)
        vm.board(tableau = listOf(listOf(c(Suit.Hearts, 3))))
        vm.setState { s -> s.copy(foundations = s.foundations.mapIndexed { i, p -> if (i == 0) p.copy(cards = listOf(c(Suit.Spades, 1), two)) else p }) }
        vm.moveCards(listOf(two), vm.f(0), vm.t(0))
        assertEquals(-15, vm.state.value.score)
        assertEquals("-15", vm.popup()?.displayText)
        assertEquals(false, vm.popup()?.isPositive)

        // Shuffling an ace between foundations is free
        vm.board(found = mapOf(Suit.Spades to 1))
        vm.moveCards(listOf(vm.f(0).cards[0]), vm.f(0), vm.f(1))
        assertEquals(0, vm.state.value.score)
        assertEquals(1, vm.f(1).cards.size)
    }

    @Test fun noPointPopupsWithHoneyModeOff() {
        val vm = newVm()
        vm.sharedOptions.setHoneyMode(false)
        vm.board(waste = listOf(c(Suit.Spades, 1)))
        vm.moveCards(listOf(vm.waste.cards[0]), vm.waste, vm.f(0))
        assertNull(vm.popup())
        assertEquals("Points still count", 10, vm.state.value.score)
    }

    @Test fun undoTakesBackThePointsTheMoveEarned() {
        val vm = newVm()
        val five = c(Suit.Hearts, 5)
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 6))), waste = listOf(five))
        vm.moveCards(listOf(five), vm.waste, vm.t(0))
        assertEquals(5, vm.state.value.score)
        vm.undoLastAction()
        assertEquals("Undo takes the 5 points back off on top of the revert", -5, vm.state.value.score)
        assertEquals(listOf(five.id), vm.waste.cards.map { it.id })
        assertEquals(1, vm.t(0).cards.size)
        assertEquals("The waste fan is restored", 1, vm.state.value.wasteDisplayCount)
        assertNull(vm.popup())
        assertFalse(vm.canUndo)

        // Undoing a move that COST points never turns into a bonus.
        val two = c(Suit.Spades, 2)
        vm.board(tableau = listOf(listOf(c(Suit.Hearts, 3))))
        vm.setState { s -> s.copy(foundations = s.foundations.mapIndexed { i, p -> if (i == 0) p.copy(cards = listOf(c(Suit.Spades, 1), two)) else p }) }
        vm.moveCards(listOf(two), vm.f(0), vm.t(0))
        assertEquals(-15, vm.state.value.score)
        vm.undoLastAction()
        assertEquals(0, vm.state.value.score)

        vm.undoLastAction()
        assertEquals("An empty undo does nothing", 0, vm.state.value.score)
    }

    @Test fun undoStepsBackOneMoveAtATime() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 6)), listOf(c(Suit.Clubs, 1))), waste = listOf(c(Suit.Hearts, 5)))
        vm.moveCards(listOf(vm.waste.cards.last()), vm.waste, vm.t(0))
        vm.moveCards(listOf(vm.t(1).cards[0]), vm.t(1), vm.f(0))
        assertEquals(2, vm.state.value.movesCount)
        vm.undoLastAction()
        assertEquals(1, vm.state.value.movesCount)
        assertEquals(1, vm.t(1).cards.size)
        vm.undoLastAction()
        assertEquals(0, vm.state.value.movesCount)
        assertEquals(1, vm.waste.cards.size)
        assertFalse(vm.canUndo)
    }

    // ---- Move legality ----

    @Test fun moveLegality() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 6)), emptyList()), found = mapOf(Suit.Hearts to 3))
        val t0 = vm.t(0)
        val empty = vm.t(1)
        val h5 = c(Suit.Hearts, 5)
        assertTrue("Red 5 on black 6", vm.isValidMove(listOf(h5), t0))
        assertFalse("Black 5 can't go on black 6", vm.isValidMove(listOf(c(Suit.Clubs, 5)), t0))
        assertFalse("Wrong rank", vm.isValidMove(listOf(c(Suit.Hearts, 4)), t0))
        assertTrue("A king may take an empty column", vm.isValidMove(listOf(c(Suit.Hearts, 13)), empty))
        assertFalse("Only kings may take an empty column", vm.isValidMove(listOf(c(Suit.Hearts, 12)), empty))
        assertFalse("An empty drag is not a move", vm.isValidMove(emptyList(), t0))

        assertTrue("A valid run moves as one", vm.isValidMove(listOf(c(Suit.Hearts, 5), c(Suit.Clubs, 4)), t0))
        assertFalse("Same-colour neighbours aren't a run", vm.isValidMove(listOf(c(Suit.Hearts, 5), c(Suit.Diamonds, 4)), t0))
        assertFalse("A rank gap isn't a run", vm.isValidMove(listOf(c(Suit.Hearts, 5), c(Suit.Clubs, 3)), t0))

        val hearts = vm.f(3)
        val spades = vm.f(0)
        assertTrue(vm.isValidMove(listOf(c(Suit.Hearts, 4)), hearts))
        assertFalse("Can't skip a rank", vm.isValidMove(listOf(c(Suit.Hearts, 5)), hearts))
        assertFalse("Wrong suit", vm.isValidMove(listOf(c(Suit.Spades, 4)), hearts))
        assertTrue("Any ace may start an empty foundation", vm.isValidMove(listOf(c(Suit.Diamonds, 1)), spades))
        assertFalse("Only an ace starts a foundation", vm.isValidMove(listOf(c(Suit.Diamonds, 2)), spades))
        assertFalse("Foundations take one card at a time", vm.isValidMove(listOf(c(Suit.Hearts, 4), c(Suit.Spades, 3)), hearts))
        assertFalse(vm.isValidMove(listOf(h5), vm.stock))
        assertFalse(vm.isValidMove(listOf(h5), vm.waste))

        // A refused move changes nothing.
        val before = vm.state.value
        assertFalse(vm.moveCards(listOf(c(Suit.Clubs, 5)), vm.waste, t0))
        assertEquals(before, vm.state.value)
    }

    @Test fun movingARunMovesEveryCardInIt() {
        val vm = newVm()
        val run = listOf(c(Suit.Hearts, 5), c(Suit.Clubs, 4), c(Suit.Diamonds, 3))
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 9, up = false)) + run, listOf(c(Suit.Spades, 6))))
        assertTrue(vm.moveCards(run, vm.t(0), vm.t(1)))
        assertEquals(4, vm.t(1).cards.size)
        assertEquals(1, vm.t(0).cards.size)
        assertTrue("The card left behind is turned up", vm.t(0).cards[0].faceUp)
        assertEquals("Revealing a card scores 5", 5, vm.state.value.score)
    }

    @Test fun doubleTapSendsTheTopCardToAFoundationOnlyWhenItFits() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 1)), listOf(c(Suit.Hearts, 5), c(Suit.Clubs, 1)), listOf(c(Suit.Hearts, 9))))
        assertTrue(vm.doubleClickMoveToFoundation(vm.t(0).cards[0], vm.t(0)))
        assertEquals(1, vm.f(0).cards.size)
        assertFalse("A 9 can't go to a foundation yet", vm.doubleClickMoveToFoundation(vm.t(2).cards[0], vm.t(2)))
        assertFalse("A card that isn't on top can't be double-tapped", vm.doubleClickMoveToFoundation(vm.t(1).cards[0], vm.t(1)))
    }

    @Test fun wasteReExposesOlderCardsAfterABatchIsPlayed() {
        val vm = newVm()
        val played = c(Suit.Hearts, 5)
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 6))),
            waste = listOf(c(Suit.Clubs, 9), c(Suit.Diamonds, 4), c(Suit.Clubs, 8), played))
        vm.setState { it.copy(wasteDisplayCount = 1) }   // the last draw only added one card
        vm.moveCards(listOf(played), vm.waste, vm.t(0))
        assertEquals("The three cards beneath fan out again", 3, vm.state.value.wasteDisplayCount)

        val one = newVm()
        one.board(tableau = listOf(listOf(c(Suit.Spades, 6))), waste = listOf(c(Suit.Clubs, 9), played), draw = DrawMode.DrawOne)
        one.moveCards(listOf(played), one.waste, one.t(0))
        assertEquals("Draw One shows just the next card", 1, one.state.value.wasteDisplayCount)
    }

    // ---- Draw and recycle ----

    @Test fun drawAndRecycleRules() {
        val vm = newVm()
        val stock = (1..7).map { c(Suit.Clubs, it, up = false) }
        vm.board(tableau = deadTableau(), stock = stock, draw = DrawMode.DrawThree)
        vm.drawCard()
        assertEquals(4, vm.stock.cards.size)
        assertEquals(3, vm.waste.cards.size)
        assertEquals(3, vm.state.value.wasteDisplayCount)
        assertEquals("Drawn from the end of the stock: 7, 6, then 5 on top", listOf(7, 6, 5), vm.waste.cards.map { it.rank })
        assertTrue(vm.waste.cards.all { it.faceUp })
        assertEquals(1, vm.state.value.movesCount)
        assertTrue(vm.hasDrawnFromStockThisGame)
        vm.drawCard()
        vm.drawCard()   // one card left: draws just that one
        assertTrue(vm.stock.isEmpty)
        assertEquals(7, vm.waste.cards.size)
        assertEquals(1, vm.state.value.wasteDisplayCount)

        // Drawing from an empty stock recycles (and doesn't also draw).
        vm.drawCard()
        assertEquals(7, vm.stock.cards.size)
        assertTrue(vm.waste.isEmpty)
        assertEquals(1, vm.state.value.recyclesCount)
        assertTrue(vm.stock.cards.none { it.faceUp })
        assertEquals("In the original order, so the same cards come out again", (1..7).toList(), vm.stock.cards.map { it.rank })
        vm.undoLastAction()
        assertTrue(vm.stock.isEmpty)
        assertEquals(7, vm.waste.cards.size)
        assertEquals(0, vm.state.value.recyclesCount)
    }

    @Test fun drawingWithNothingToDrawOrRecycleDoesNothing() {
        val vm = newVm()
        vm.board(tableau = deadTableau())
        vm.drawCard()
        vm.recycleStock()
        assertEquals(0, vm.state.value.movesCount)
        assertFalse(vm.canUndo)
        assertFalse("No waste, nothing to recycle", vm.canRecycleStock)
    }

    @Test fun drawOneDrawsOne_AndStandardPlayHasNoRecycleLimit() {
        val vm = newVm()
        vm.board(tableau = deadTableau(), stock = (1..7).map { c(Suit.Clubs, it, up = false) }, draw = DrawMode.DrawOne)
        vm.drawCard()
        assertEquals(1, vm.waste.cards.size)
        assertEquals(6, vm.stock.cards.size)
        assertNull("Standard play has no recycle limit", vm.maxRecycles)
        repeat(30) { vm.drawCard() }   // through the stock and round again, several times
        assertTrue("Still able to recycle after many passes", vm.state.value.recyclesCount >= 3)
    }

    // ---- Winning ----

    @Test fun timedWinBonus() {
        val vm = newVm()
        vm.oneCardFromWinning()
        vm.setState { it.copy(score = 500, timerSeconds = 100) }
        vm.playLastCard()
        assertTrue(vm.state.value.hasWon)
        assertFalse("The last card stops the clock", vm.state.value.isTimerActive)
        assertEquals("510 − 20 (2 per 10 s) + 7000 (700,000 ÷ 100)", 510 - 20 + 7000, vm.state.value.score)
        assertEquals(7490, vm.stats().highScore)
        assertEquals(1, vm.stats().gamesWon)
        assertEquals(100, vm.stats().shortestWinTime)
        assertEquals(100, vm.stats().totalWinningTime)
        assertFalse(vm.canUndo)
        vm.undoLastAction()
        assertTrue("Undo can't reopen a won game", vm.state.value.hasWon)
    }

    @Test fun aVeryFastWinHasNoTimeMinimum() {
        val vm = newVm()
        vm.oneCardFromWinning()
        vm.setState { it.copy(score = 500, timerSeconds = 7) }
        vm.playLastCard()
        assertEquals("7 s earns 700,000 ÷ 7 with no penalty", 510 + 100000, vm.state.value.score)
    }

    @Test fun theTimePenaltyNeverTakesTheScoreBelowZero() {
        val vm = newVm()
        vm.oneCardFromWinning()
        vm.setState { it.copy(score = 0, timerSeconds = 1_000_000) }
        vm.playLastCard()
        assertEquals(0, vm.state.value.score)
    }

    @Test fun winRecordsStreakAndShortestTimeAcrossGames() {
        val vm = newVm()
        vm.oneCardFromWinning(); vm.setState { it.copy(timerSeconds = 90) }; vm.playLastCard()
        vm.startNewGame()
        vm.oneCardFromWinning(); vm.setState { it.copy(timerSeconds = 40) }; vm.playLastCard()
        val s = vm.stats()
        assertEquals(2, s.gamesWon)
        assertEquals(2, s.currentStreak)
        assertEquals(2, s.longestStreak)
        assertEquals(40, s.shortestWinTime)
        assertEquals(130, s.totalWinningTime)
        assertEquals(2, s.winningGamesCount)
        assertEquals(65.0, s.averageWinningTime, 0.0)
    }

    @Test fun noStressWinCountsButHasNoTimeAndNoBonus() {
        val vm = newVm()
        vm.sharedOptions.setNoStressMode(true)
        vm.oneCardFromWinning()
        vm.setState { it.copy(score = 500, timerSeconds = 100) }
        vm.playLastCard()
        assertTrue(vm.state.value.hasWon)
        assertEquals("No time bonus", 510, vm.state.value.score)
        assertEquals(1, vm.stats().gamesWon)
        assertEquals(0, vm.stats().winningGamesCount)
        assertEquals(0, vm.stats().shortestWinTime)
    }

    @Test fun turningNoStressOnPartwayTaintsTheTime() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(c(Suit.Spades, 12)), listOf(c(Suit.Spades, 13))),
            found = mapOf(Suit.Spades to 11, Suit.Clubs to 13, Suit.Diamonds to 13, Suit.Hearts to 13)
        )
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.f(0))
        assertTrue("The first move starts the clock", vm.state.value.isTimerActive)
        vm.setState { it.copy(timerSeconds = 50) }
        vm.sharedOptions.setNoStressMode(true)
        vm.reactToNoStressModeChange()
        assertFalse(vm.state.value.isTimerActive)
        assertEquals(0, vm.state.value.timerSeconds)
        vm.sharedOptions.setNoStressMode(false)
        vm.reactToNoStressModeChange()
        assertTrue("Turning No Stress off restarts the clock", vm.state.value.isTimerActive)
        vm.setState { it.copy(timerSeconds = 3) }
        vm.moveCards(listOf(vm.t(1).cards[0]), vm.t(1), vm.f(0))
        assertTrue(vm.state.value.hasWon)
        assertEquals("A part-untimed game records no best time", 0, vm.stats().winningGamesCount)
        assertEquals("...and earns no time bonus (2 moves × 10)", 20, vm.state.value.score)
    }

    @Test fun noClockBeforeTheFirstMove() {
        val vm = newVm()
        vm.sharedOptions.setNoStressMode(true); vm.reactToNoStressModeChange()
        vm.sharedOptions.setNoStressMode(false); vm.reactToNoStressModeChange()
        assertFalse(vm.state.value.isTimerActive)
    }

    @Test fun clockTicksEverySecond_AndPausesInTheBackground() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 1))))
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.f(0))
        assertTrue(vm.state.value.isTimerActive)
        clock.scheduler.advanceTimeBy(3500); clock.scheduler.runCurrent()
        assertEquals(3, vm.state.value.timerSeconds)
        vm.pauseTimerForBackground()
        assertFalse(vm.state.value.isTimerActive)
        clock.scheduler.advanceTimeBy(5000); clock.scheduler.runCurrent()
        assertEquals(3, vm.state.value.timerSeconds)
        vm.resumeTimerAfterBackground()
        assertTrue(vm.state.value.isTimerActive)
    }

    // ---- "No moves left" ----

    @Test fun noMovesLeftRules() {
        var vm = newVm()
        vm.board(tableau = deadTableau())
        vm.checkStuckState()
        assertTrue(vm.isStockExhausted.value)
        assertTrue("No moves and nothing to draw or recycle: stuck at once", vm.isStuck.value)

        vm.board(tableau = listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6))) + deadTableau().drop(2))
        vm.checkStuckState()
        assertFalse("A legal move: not stuck", vm.isStuck.value)

        vm.board(tableau = deadTableau(), stock = listOf(c(Suit.Spades, 1, up = false)))
        vm.checkStuckState()
        assertFalse("An ace waiting in the stock is a move", vm.isStuck.value)

        // Dead stock, standard play: only flagged once the player has recycled past the first detection.
        vm = newVm()
        vm.board(tableau = deadTableau(), stock = listOf(c(Suit.Hearts, 2, up = false)))
        vm.checkStuckState()
        assertFalse("First detection doesn't flag", vm.isStuck.value)
        vm.drawCard()
        assertFalse("Not stuck on the first pass through the stock", vm.isStuck.value)
        vm.drawCard()   // recycles
        assertEquals(1, vm.state.value.recyclesCount)
        vm.drawCard()   // draws the 2♥ again
        assertTrue("Stuck once the stock has been recycled past the first detection", vm.isStuck.value)

        // A won game is never stuck.
        vm.board(tableau = deadTableau())
        vm.setState { it.copy(hasWon = true) }
        vm.checkStuckState()
        assertFalse(vm.isStuck.value)
        assertFalse(vm.isStockExhausted.value)
    }

    @Test fun movingAKingBetweenColumnsIsNotAWayOut() {
        // A king that fills an empty column from a column holding only it just swaps places.
        val vm = newVm()
        vm.board(tableau = listOf(listOf(c(Suit.Hearts, 13))) + deadTableau().drop(4).map { it })
        vm.checkStuckState()
        assertTrue("Shuffling a lone king to another empty column changes nothing", vm.isStuck.value)
    }

    @Test fun playingIntoADeadEndRaisesStuckAndUndoClearsIt() {
        val vm = newVm()
        // Once 5♥ goes onto 6♠ nothing else can move: the other columns are kings and
        // cards that fit nowhere, and the emptied column only takes a king that isn't already alone.
        val others = listOf(listOf(c(Suit.Diamonds, 13)), listOf(c(Suit.Clubs, 13)), listOf(c(Suit.Spades, 9)),
            listOf(c(Suit.Spades, 2)), listOf(c(Suit.Clubs, 3)))
        vm.board(tableau = listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6))) + others)
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.t(1))
        assertTrue(vm.isStuck.value)
        vm.undoLastAction()
        assertFalse(vm.isStuck.value)
    }

    // ---- Autocomplete ----

    @Test fun autocompleteAvailability() {
        val vm = newVm()
        vm.oneCardFromWinning()
        vm.checkAutocompleteState()
        assertTrue("Everything face up, stock and waste empty: offered", vm.isAutocompleteAvailable.value)
        vm.checkStuckState()
        assertFalse("An Autocomplete-able game isn't stuck", vm.isStuck.value)

        val done = mapOf(Suit.Spades to 12, Suit.Clubs to 13, Suit.Diamonds to 13, Suit.Hearts to 13)
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 13, up = false))), found = done)
        vm.checkAutocompleteState()
        assertFalse("A face-down card: not offered", vm.isAutocompleteAvailable.value)

        val nearly = mapOf(Suit.Spades to 11, Suit.Clubs to 13, Suit.Diamonds to 13, Suit.Hearts to 13)
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 12))), stock = listOf(c(Suit.Spades, 13, up = false)), found = nearly)
        vm.checkAutocompleteState()
        assertFalse("Cards in the stock: not offered", vm.isAutocompleteAvailable.value)
        vm.board(tableau = listOf(listOf(c(Suit.Spades, 12))), waste = listOf(c(Suit.Spades, 13)), found = nearly)
        vm.checkAutocompleteState()
        assertFalse("Cards in the waste: not offered", vm.isAutocompleteAvailable.value)
        vm.runAutocomplete()
        assertFalse("Autocomplete does nothing when it isn't offered", vm.isAutoplayRunning.value)
    }

    @Test fun autocompletePlaysTheGameOutAndRecordsTheWin() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(c(Suit.Spades, 13)), listOf(c(Suit.Clubs, 13))),
            found = mapOf(Suit.Spades to 12, Suit.Clubs to 12, Suit.Diamonds to 13, Suit.Hearts to 13)
        )
        vm.checkAutocompleteState()
        vm.runAutocomplete()
        assertTrue(vm.isAutoplayRunning.value)
        clock.scheduler.advanceTimeBy(1000); clock.scheduler.runCurrent()
        assertTrue(vm.state.value.hasWon)
        assertFalse(vm.isAutoplayRunning.value)
        assertEquals("Two foundation moves scored", 20, vm.state.value.score)
        assertEquals(1, vm.stats().gamesWon)
    }

    @Test fun undoDuringAutocompleteStopsIt() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(c(Suit.Spades, 13)), listOf(c(Suit.Clubs, 13))),
            found = mapOf(Suit.Spades to 12, Suit.Clubs to 12, Suit.Diamonds to 13, Suit.Hearts to 13)
        )
        vm.checkAutocompleteState()
        vm.runAutocomplete()
        vm.undoLastAction()
        assertFalse(vm.isAutoplayRunning.value)
        clock.scheduler.advanceTimeBy(1000); clock.scheduler.runCurrent()
        assertFalse("The undone cards are not replayed", vm.state.value.hasWon)
    }

    // ---- Restart ----

    @Test fun restartReplaysTheSameDeal() {
        val vm = newVm()
        val deal = vm.state.value.tableau.map { p -> p.cards.map { it.id } }
        val stock = vm.stock.cards.map { it.id }
        vm.drawCard()
        vm.restartCurrentGame()
        assertEquals(deal, vm.state.value.tableau.map { p -> p.cards.map { it.id } })
        assertEquals(stock, vm.stock.cards.map { it.id })
        assertEquals(0, vm.state.value.movesCount)
        assertFalse(vm.canUndo)
    }

    // ---- Relaunch ----

    private fun flush() {
        clock.scheduler.advanceTimeBy(600)   // past the 500 ms save debounce
        clock.scheduler.runCurrent()
        runBlocking { PreferencesHelper.awaitPendingWrites(5000) }
    }

    @Test fun statsAndHighScoreSurviveARelaunch() {
        val rig = newRig()
        flush()   // let the deal's own stats write land first — saves aren't ordered, so back-to-back ones can cross
        rig.vm.oneCardFromWinning()
        rig.vm.setState { it.copy(score = 500, timerSeconds = 100) }
        rig.vm.playLastCard()
        flush()
        val again = newRig(rig.ds).vm.stats()
        assertEquals(1, again.gamesWon)
        assertEquals(1, again.currentStreak)
        assertEquals(7490, again.highScore)
        assertEquals(100, again.shortestWinTime)
    }

    @Test fun drawModeSurvivesARelaunch() {
        val rig = newRig()
        val other = if (rig.vm.options.value.drawMode == DrawMode.DrawOne) DrawMode.DrawThree else DrawMode.DrawOne
        rig.vm.updateOptions(rig.vm.options.value.copy(drawMode = other))
        flush()
        assertEquals(other, newRig(rig.ds).vm.options.value.drawMode)
    }

    @Test fun aGameInProgressComesBackAfterARelaunchWithTheClockPaused() {
        val rig = newRig()
        rig.vm.board(tableau = listOf(listOf(c(Suit.Spades, 6)), listOf(c(Suit.Hearts, 5))), waste = listOf(c(Suit.Clubs, 9)))
        rig.vm.moveCards(listOf(rig.vm.t(1).cards[0]), rig.vm.t(1), rig.vm.t(0))
        val saved = rig.vm.state.value
        flush()

        val back = newRig(rig.ds).vm
        clock.scheduler.runCurrent()
        assertEquals(saved.tableau, back.state.value.tableau)
        assertEquals(saved.waste, back.state.value.waste)
        assertEquals(1, back.state.value.movesCount)
        assertFalse(back.state.value.isTimerActive)
    }

    @Test fun aWonGameIsNotRestoredAfterARelaunch() {
        val rig = newRig()
        rig.vm.oneCardFromWinning()
        rig.vm.playLastCard()
        flush()
        val back = newRig(rig.ds).vm
        assertFalse(back.state.value.hasWon)
        assertEquals(28, back.state.value.tableau.sumOf { it.cards.size })
    }

    @Test fun relaunchedBoardRecomputesAutocompleteAvailability() {
        val rig = newRig()
        rig.vm.oneCardFromWinning()
        rig.vm.setState { it.copy(movesCount = 5) }
        flush()
        val back = newRig(rig.ds).vm
        clock.scheduler.runCurrent()
        assertTrue(back.isAutocompleteAvailable.value)
    }

    @Test fun anUnstartedDealNeverBreaksAStreakWhenReplaced() {
        val vm = newVm()
        privateFlow<GameStatistics>(vm, "_statistics").value = GameStatistics(gamesPlayed = 5, currentStreak = 3, longestStreak = 3)
        vm.startNewGame()
        assertEquals(3, vm.stats().currentStreak)
        assertEquals(6, vm.stats().gamesPlayed)
        assertNotNull(vm.state.value)
    }
}
