package com.leah.honeycomb.beecell

import com.leah.honeycomb.Card
import com.leah.honeycomb.Pile
import com.leah.honeycomb.PileType
import com.leah.honeycomb.PreferencesHelper
import com.leah.honeycomb.Suit
import com.leah.honeycomb.ViewModelTestBase
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// Player-visible Beecell (1-deck FreeCell) behaviour on fixed boards — ported from Mac's
// BeecellGameplayTests: the supermove limit, what each pile accepts, scoring, undo,
// winning, stuck detection, Autocomplete, streaks/restart, No Stress and the clock, and
// what survives a relaunch. Android is 1-deck only, so there is no 2-deck coverage.
@OptIn(ExperimentalCoroutinesApi::class)
class BeecellGameplayTest : ViewModelTestBase() {

    // ---- Fixtures ----

    private class Rig(val vm: BeecellViewModel, val ds: DataStore<Preferences>)

    private fun newRig(ds: DataStore<Preferences> = newDataStore()): Rig {
        val shared = newSharedOptions(ds)
        return Rig(BeecellViewModel(shared, ds, newBannerCatalog(ds, shared)), ds)
    }

    private fun newVm() = newRig().vm

    private fun card(suit: Suit, rank: Int) = up(suit, rank)
    private fun ascending(suit: Suit, through: Int) = (1..through).map { card(suit, it) }

    // Hand-built board: 8 columns, 4 cells (one card each, in order), 4 foundations.
    private fun BeecellViewModel.board(
        tableau: List<List<Card>> = emptyList(),
        cells: List<Card> = emptyList(),
        found: List<List<Card>> = emptyList()
    ) {
        val flow = privateFlow<BeecellState>(this, "_state")
        flow.value = flow.value.copy(
            tableau = (0 until 8).map { Pile("tableau_$it", PileType.Tableau, tableau.getOrElse(it) { emptyList() }) },
            freeCells = (0 until 4).map { Pile("freecell_$it", PileType.FreeCell, cells.getOrNull(it)?.let { c -> listOf(c) } ?: emptyList()) },
            foundations = (0 until 4).map { Pile("foundation_$it", PileType.Foundation, found.getOrElse(it) { emptyList() }) },
            score = 0, movesCount = 0, timerSeconds = 0, isTimerActive = false, hasWon = false
        )
        privateFlow<Boolean>(this, "_isStuck").value = false
        privateFlow<Boolean>(this, "_isAutocompleteAvailable").value = false
    }

    private fun BeecellViewModel.setState(f: (BeecellState) -> BeecellState) {
        val flow = privateFlow<BeecellState>(this, "_state")
        flow.value = f(flow.value)
    }

    private fun BeecellViewModel.callPrivate(name: String) {
        val m = javaClass.getDeclaredMethod(name)
        m.isAccessible = true
        m.invoke(this)
    }

    private fun BeecellViewModel.checkStuck() = callPrivate("checkStuckState")
    private fun BeecellViewModel.checkAutocomplete() = callPrivate("checkAutocompleteState")

    private fun BeecellViewModel.t(i: Int) = state.value.tableau[i]
    private fun BeecellViewModel.cell(i: Int) = state.value.freeCells[i]
    private fun BeecellViewModel.foundation(i: Int) = state.value.foundations[i]

    private fun BeecellViewModel.stats() = statistics.value.statsByFreeCells[4] ?: BeecellModeStats()

    private fun BeecellViewModel.primeStats(stats: BeecellModeStats) {
        privateFlow<BeecellStatistics>(this, "_statistics").value = BeecellStatistics(mapOf(4 to stats))
    }

    // Single kings and nines: keep columns occupied without creating moves among themselves.
    private fun fillers(count: Int): List<List<Card>> {
        val pool = listOf(
            card(Suit.Diamonds, 13), card(Suit.Hearts, 13), card(Suit.Clubs, 13), card(Suit.Spades, 13),
            card(Suit.Diamonds, 9), card(Suit.Hearts, 9), card(Suit.Clubs, 9), card(Suit.Spades, 9)
        )
        return (0 until count).map { listOf(pool[it % pool.size]) }
    }

    private fun BeecellViewModel.stuckBoard(withFoundation: Boolean = false) = board(
        tableau = listOf(
            listOf(card(Suit.Spades, 13)), listOf(card(Suit.Hearts, 13)), listOf(card(Suit.Diamonds, 13)),
            listOf(card(Suit.Clubs, 13)), listOf(card(Suit.Hearts, 5)), listOf(card(Suit.Clubs, 9)),
            listOf(card(Suit.Spades, 9)), listOf(card(Suit.Diamonds, 9))
        ),
        cells = listOf(card(Suit.Spades, 7), card(Suit.Hearts, 7), card(Suit.Diamonds, 7), card(Suit.Clubs, 7)),
        found = if (withFoundation) listOf(ascending(Suit.Spades, 4)) else emptyList()
    )

    // Everything but the K♠ is already on the foundations.
    private fun nearlyDoneFoundations() = listOf(
        ascending(Suit.Spades, 12), ascending(Suit.Clubs, 13),
        ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13)
    )

    private fun BeecellViewModel.playLastWinningMove() {
        board(tableau = listOf(listOf(card(Suit.Spades, 13))), found = nearlyDoneFoundations())
        moveCards(listOf(t(0).cards[0]), t(0), foundation(0))
    }

    private fun BeecellViewModel.oneMove() {
        board(tableau = listOf(listOf(card(Suit.Spades, 1))) + fillers(7))
        moveCards(listOf(t(0).cards[0]), t(0), foundation(0))
    }

    // ---- Deal ----

    @Test fun dealLayoutIsEightColumnsFourCellsFourFoundations() {
        val vm = newVm()
        val s = vm.state.value
        assertEquals(8, s.tableau.size)
        assertEquals(4, s.freeCells.size)
        assertEquals(4, s.foundations.size)
        assertEquals(listOf(7, 7, 7, 7, 6, 6, 6, 6), s.tableau.map { it.cards.size })
        assertTrue(s.tableau.flatMap { it.cards }.all { it.faceUp })
        assertEquals(52, s.tableau.flatMap { it.cards }.map { it.id }.toSet().size)
        assertEquals(52, s.tableau.flatMap { it.cards }.map { it.suit to it.rank }.toSet().size)
        assertEquals(1, vm.stats().gamesPlayed)
    }

    // ---- Supermove limit and pile rules ----

    @Test fun supermoveLimitShrinksWithCellsAndGrowsWithEmptyColumns() {
        val vm = newVm()
        val run5 = listOf(card(Suit.Spades, 9), card(Suit.Hearts, 8), card(Suit.Clubs, 7), card(Suit.Diamonds, 6), card(Suit.Spades, 5))
        val run6 = listOf(card(Suit.Clubs, 9), card(Suit.Diamonds, 8), card(Suit.Spades, 7), card(Suit.Hearts, 6),
            card(Suit.Clubs, 5), card(Suit.Diamonds, 4))
        vm.board(tableau = listOf(listOf(card(Suit.Clubs, 13)) + run5, listOf(card(Suit.Hearts, 10)), run6) + fillers(5))

        assertEquals(4, vm.emptyFreeCellsCount)
        assertEquals(0, vm.emptyTableauColumnsCount)
        assertEquals(5, vm.maxMoveLimit(toEmptyTableau = false))
        assertEquals(5, vm.maxMoveLimit(toEmptyTableau = true))
        assertTrue(vm.isValidMove(run5, vm.t(1)))
        assertFalse("Six cards exceed the limit of five", vm.isValidMove(run6, vm.t(1)))
        assertFalse(vm.moveCards(run6, vm.t(2), vm.t(1)))
        assertEquals(6, vm.t(2).cards.size)
        assertEquals(0, vm.state.value.movesCount)

        // A filled cell shrinks the limit to 4.
        vm.board(tableau = listOf(listOf(card(Suit.Clubs, 13)) + run5, listOf(card(Suit.Hearts, 10))) + fillers(6),
            cells = listOf(card(Suit.Spades, 2)))
        assertEquals(4, vm.maxMoveLimit(toEmptyTableau = false))
        assertFalse(vm.isValidMove(run5, vm.t(1)))

        // An empty column doubles the limit for other columns but not for itself.
        vm.board(tableau = listOf(listOf(card(Suit.Clubs, 13)) + run6, listOf(card(Suit.Hearts, 10))) + fillers(5))
        assertEquals(1, vm.emptyTableauColumnsCount)
        assertEquals(10, vm.maxMoveLimit(toEmptyTableau = false))
        assertEquals(5, vm.maxMoveLimit(toEmptyTableau = true))
        assertTrue(vm.isValidMove(run6, vm.t(1)))
        assertFalse("Six cards can't go into the empty column", vm.isValidMove(run6, vm.t(7)))
        assertTrue(vm.isValidMove(run6.takeLast(1), vm.t(7)))
        assertTrue(vm.moveCards(run6, vm.t(0), vm.t(1)))
        assertEquals(7, vm.t(1).cards.size)
        assertEquals(1, vm.state.value.movesCount)
    }

    @Test fun maxMoveLimitFormulaWithExplicitCounts() {
        val vm = newVm()
        assertEquals(1, vm.maxMoveLimit(false, emptyFreeCells = 0, emptyTableauColumns = 0))
        assertEquals(5, vm.maxMoveLimit(false, emptyFreeCells = 4, emptyTableauColumns = 0))
        assertEquals(20, vm.maxMoveLimit(false, emptyFreeCells = 4, emptyTableauColumns = 2))
        assertEquals(10, vm.maxMoveLimit(true, emptyFreeCells = 4, emptyTableauColumns = 2))
        assertEquals(5, vm.maxMoveLimit(true, emptyFreeCells = 4, emptyTableauColumns = 1))
        assertEquals(5, vm.maxMoveLimit(true, emptyFreeCells = 4, emptyTableauColumns = 0))
    }

    @Test fun pileRules() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 6))) + fillers(7),
            cells = listOf(card(Suit.Hearts, 2)),
            found = listOf(ascending(Suit.Hearts, 3))
        )
        val h5 = card(Suit.Hearts, 5)
        val c5 = card(Suit.Clubs, 5)
        val d4 = card(Suit.Diamonds, 4)
        assertTrue("Red 5 on black 6", vm.isValidMove(listOf(h5), vm.t(0)))
        assertFalse("Same colour", vm.isValidMove(listOf(c5), vm.t(0)))
        assertFalse("Wrong rank", vm.isValidMove(listOf(d4), vm.t(0)))
        assertFalse("Non-alternating pair", vm.isValidMove(listOf(h5, card(Suit.Hearts, 4)), vm.t(0)))
        assertFalse("Nothing to move", vm.isValidMove(emptyList(), vm.t(0)))
        assertFalse("Occupied cell", vm.isValidMove(listOf(h5), vm.cell(0)))
        assertTrue("Vacant cell", vm.isValidMove(listOf(h5), vm.cell(1)))
        assertFalse("Only one card to a cell", vm.isValidMove(listOf(card(Suit.Spades, 6), h5), vm.cell(1)))
        assertTrue(vm.isValidMove(listOf(card(Suit.Hearts, 4)), vm.foundation(0)))
        assertFalse("Can't skip a rank", vm.isValidMove(listOf(card(Suit.Hearts, 5)), vm.foundation(0)))
        assertFalse("Wrong suit", vm.isValidMove(listOf(card(Suit.Spades, 4)), vm.foundation(0)))
        assertTrue("Ace starts a foundation", vm.isValidMove(listOf(card(Suit.Spades, 1)), vm.foundation(1)))
        assertFalse("Only an ace", vm.isValidMove(listOf(card(Suit.Spades, 2)), vm.foundation(1)))
        assertFalse("Foundations take one card at a time",
            vm.isValidMove(listOf(card(Suit.Spades, 1), card(Suit.Spades, 2)), vm.foundation(1)))
        assertFalse("Stock accepts nothing", vm.isValidMove(listOf(h5), Pile("stock", PileType.Stock)))
        assertTrue(vm.isValidDragSequence(listOf(card(Suit.Spades, 6), card(Suit.Hearts, 5))))
        assertFalse(vm.isValidDragSequence(emptyList()))
        assertFalse(vm.isValidDragSequence(listOf(card(Suit.Spades, 6), card(Suit.Clubs, 5))))
    }

    @Test fun anySingleCardMayStartAnEmptyColumn() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(card(Suit.Hearts, 5))) + fillers(6))
        assertTrue(vm.isValidMove(listOf(card(Suit.Hearts, 5)), vm.t(7)))
        assertTrue(vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.t(7)))
        assertEquals(listOf(card(Suit.Hearts, 5).suit to 5), vm.t(7).cards.map { it.suit to it.rank })
        assertTrue(vm.t(0).isEmpty)
    }

    @Test fun doubleTapMovePrefersFoundationThenCellThenColumn() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(card(Suit.Spades, 1)), listOf(card(Suit.Hearts, 5)), listOf(card(Suit.Clubs, 6))) + fillers(5))
        assertTrue(vm.doubleClickMove(vm.t(0).cards[0], vm.t(0)))
        assertEquals(1, vm.foundation(0).cards.size)

        // Not a foundation card, so it goes to the first free cell (even though it also fits a column).
        assertTrue(vm.doubleClickMove(vm.t(1).cards[0], vm.t(1)))
        assertEquals(5, vm.cell(0).cards[0].rank)

        // A card that isn't on top of its column can't be double-tapped.
        vm.board(tableau = listOf(listOf(card(Suit.Hearts, 5), card(Suit.Spades, 1))) + fillers(7))
        assertFalse(vm.doubleClickMove(vm.t(0).cards[0], vm.t(0)))
    }

    // ---- Scoring and undo ----

    @Test fun scoringAndUndo() {
        val vm = newVm()
        val ace = card(Suit.Spades, 1)
        vm.board(tableau = listOf(listOf(ace)) + fillers(7))
        vm.moveCards(listOf(ace), vm.t(0), vm.foundation(0))
        assertEquals("Tableau → foundation", 10, vm.state.value.score)
        vm.undoLastAction()
        assertEquals("Undo restores the score with no extra penalty", 0, vm.state.value.score)

        val aceC = card(Suit.Clubs, 1)
        vm.board(tableau = fillers(8), cells = listOf(aceC))
        vm.moveCards(listOf(aceC), vm.cell(0), vm.foundation(0))
        assertEquals("Cell → foundation", 10, vm.state.value.score)
        assertTrue(vm.cell(0).isEmpty)

        // Leaving a foundation costs 15, never below zero.
        val two = card(Suit.Spades, 2)
        vm.board(tableau = listOf(listOf(card(Suit.Hearts, 3))) + fillers(7), found = listOf(listOf(card(Suit.Spades, 1), two)))
        vm.setState { it.copy(score = 20) }
        vm.moveCards(listOf(two), vm.foundation(0), vm.t(0))
        assertEquals("Foundation → tableau", 5, vm.state.value.score)

        vm.board(tableau = fillers(8), found = listOf(listOf(card(Suit.Spades, 1), two)))
        vm.setState { it.copy(score = 5) }
        vm.moveCards(listOf(two), vm.foundation(0), vm.cell(0))
        assertEquals("Foundation → cell never goes below 0", 0, vm.state.value.score)

        // Free moves.
        vm.board(tableau = fillers(8), found = listOf(listOf(card(Suit.Spades, 1))))
        vm.moveCards(listOf(card(Suit.Spades, 1)), vm.foundation(0), vm.foundation(1))
        assertEquals("Foundation → foundation is free", 0, vm.state.value.score)
        val five = card(Suit.Hearts, 5)
        vm.board(tableau = listOf(listOf(five)) + fillers(7))
        vm.moveCards(listOf(five), vm.t(0), vm.cell(0))
        assertEquals("Tableau → cell is free", 0, vm.state.value.score)
    }

    @Test fun honeyModeShowsPlus10GoingUpAndMinus15ComingBack() {
        val vm = newVm()
        val ace = card(Suit.Spades, 1)
        vm.board(tableau = listOf(listOf(ace)) + fillers(7))
        vm.moveCards(listOf(ace), vm.t(0), vm.foundation(0))
        assertEquals("+10", vm.pointPopup.value?.displayText)
        assertEquals(true, vm.pointPopup.value?.isPositive)
        assertEquals(ace.id, vm.pointPopup.value?.cardId)
        vm.undoLastAction()
        assertEquals("Undo clears the popup", null, vm.pointPopup.value)

        val two = card(Suit.Spades, 2)
        vm.board(tableau = listOf(listOf(card(Suit.Hearts, 3))) + fillers(7), found = listOf(listOf(card(Suit.Spades, 1), two)))
        vm.moveCards(listOf(two), vm.foundation(0), vm.t(0))
        assertEquals("-15", vm.pointPopup.value?.displayText)
        assertEquals(false, vm.pointPopup.value?.isPositive)

        vm.board(tableau = fillers(8), found = listOf(listOf(card(Suit.Spades, 1), two)))
        vm.moveCards(listOf(two), vm.foundation(0), vm.cell(0))
        assertEquals("-15 too when it goes to a free cell", "-15", vm.pointPopup.value?.displayText)
    }

    @Test fun noPopupForFreeMovesOrWithHoneyModeOff() {
        val vm = newVm()
        val five = card(Suit.Hearts, 5)
        vm.board(tableau = listOf(listOf(five)) + fillers(7))
        vm.moveCards(listOf(five), vm.t(0), vm.cell(0))
        assertEquals("A tableau → free cell move scores nothing", null, vm.pointPopup.value)

        val quiet = newVm()
        quiet.sharedOptions.setHoneyMode(false)
        quiet.board(tableau = listOf(listOf(card(Suit.Spades, 1))) + fillers(7))
        quiet.moveCards(listOf(quiet.t(0).cards[0]), quiet.t(0), quiet.foundation(0))
        assertEquals(null, quiet.pointPopup.value)
        assertEquals("Points still count", 10, quiet.state.value.score)
    }

    @Test fun undoStepsBackOneMoveAtATimeAndKeepsTheClock() {
        val vm = newVm()
        vm.undoLastAction()
        assertFalse("Nothing to undo on a fresh deal", vm.canUndo)

        vm.board(tableau = listOf(listOf(card(Suit.Spades, 1), card(Suit.Hearts, 5)), listOf(card(Suit.Clubs, 6))) + fillers(6))
        val before = vm.state.value
        vm.moveCards(listOf(vm.t(0).cards[1]), vm.t(0), vm.t(1))
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.foundation(0))
        vm.setState { it.copy(timerSeconds = 33) }
        assertTrue(vm.canUndo)
        assertEquals(2, vm.state.value.movesCount)

        vm.undoLastAction()
        assertEquals(1, vm.state.value.movesCount)
        assertEquals(0, vm.state.value.score)
        assertEquals("The clock keeps running through undo", 33, vm.state.value.timerSeconds)
        vm.undoLastAction()
        assertEquals(0, vm.state.value.movesCount)
        assertEquals(before.tableau, vm.state.value.tableau)
        assertFalse(vm.canUndo)
    }

    @Test fun undoCannotReopenAWonGame() {
        val vm = newVm()
        vm.playLastWinningMove()
        assertTrue(vm.state.value.hasWon)
        assertFalse(vm.canUndo)
        vm.undoLastAction()
        assertTrue(vm.state.value.hasWon)
        assertEquals(52, vm.state.value.foundations.sumOf { it.cards.size })
    }

    // ---- Winning ----

    @Test fun winningRecordsStatsAndStopsTheClock() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(card(Suit.Spades, 13))), found = nearlyDoneFoundations())
        vm.setState { it.copy(timerSeconds = 60) }
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.foundation(0))
        assertTrue(vm.state.value.hasWon)
        assertFalse(vm.state.value.isTimerActive)
        val s = vm.stats()
        assertEquals(1, s.gamesWon)
        assertEquals(1, s.currentStreak)
        assertEquals(1, s.longestStreak)
        assertEquals(60, s.shortestWinTime)
        assertEquals(60, s.totalWinningTime)
        assertEquals(1, s.winningGamesCount)
        assertEquals(10, s.highScore)
    }

    @Test fun fiftyOneOfFiftyTwoIsNotAWin() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 13)), listOf(card(Suit.Hearts, 13))),
            found = listOf(ascending(Suit.Spades, 12), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 12))
        )
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.foundation(0))
        assertFalse(vm.state.value.hasWon)
        assertEquals(0, vm.stats().gamesWon)
    }

    @Test fun winStreakAndBestScoreAcrossTwoWins() {
        val vm = newVm()
        vm.playLastWinningMove()
        vm.startNewGame()
        vm.playLastWinningMove()
        val s = vm.stats()
        assertEquals(2, s.gamesWon)
        assertEquals(2, s.currentStreak)
        assertEquals(2, s.longestStreak)
        assertEquals(2, s.gamesPlayed)
        assertEquals(1.0, s.winRate, 0.0)
    }

    @Test fun aWinWithNoTimeRecordedKeepsShortestWinTimeUnset() {
        val vm = newVm()
        vm.sharedOptions.setNoStressMode(true)
        vm.playLastWinningMove()
        val s = vm.stats()
        assertEquals(1, s.gamesWon)
        assertEquals(0, s.winningGamesCount)
        assertEquals(0, s.shortestWinTime)
        assertEquals(0.0, s.averageWinningTime, 0.0)
    }

    @Test fun shortestWinTimeKeepsTheBestOfSeveral() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(card(Suit.Spades, 13))), found = nearlyDoneFoundations())
        vm.setState { it.copy(timerSeconds = 90) }
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.foundation(0))
        vm.startNewGame()
        vm.board(tableau = listOf(listOf(card(Suit.Spades, 13))), found = nearlyDoneFoundations())
        vm.setState { it.copy(timerSeconds = 40) }
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.foundation(0))
        val s = vm.stats()
        assertEquals(40, s.shortestWinTime)
        assertEquals(130, s.totalWinningTime)
        assertEquals(2, s.winningGamesCount)
        assertEquals(65.0, s.averageWinningTime, 0.0)
    }

    // ---- Streaks and restart ----

    private fun primed(streak: Int): BeecellViewModel {
        val vm = newVm()
        vm.primeStats(BeecellModeStats(gamesPlayed = 5, currentStreak = streak, longestStreak = streak))
        return vm
    }

    @Test fun newGameBeforeMovingKeepsTheStreak() {
        val vm = primed(3)
        vm.startNewGame()
        assertEquals(3, vm.stats().currentStreak)
        assertEquals(6, vm.stats().gamesPlayed)
    }

    @Test fun abandoningAPlayedGameBreaksTheStreak() {
        val vm = primed(3)
        vm.oneMove()
        vm.startNewGame()
        assertEquals(0, vm.stats().currentStreak)
        assertEquals(3, vm.stats().longestStreak)
    }

    @Test fun undoToTheStartCannotDodgeTheStreakBreak() {
        val vm = primed(3)
        vm.oneMove()
        vm.undoLastAction()
        assertEquals(0, vm.state.value.movesCount)
        vm.startNewGame()
        assertEquals(0, vm.stats().currentStreak)
    }

    @Test fun restartCannotDodgeTheStreakBreakEither() {
        val vm = primed(3)
        vm.oneMove()
        vm.restartCurrentGame()
        vm.startNewGame()
        assertEquals(0, vm.stats().currentStreak)
    }

    @Test fun restartReplaysTheSameDealWithoutCountingAnotherGame() {
        val vm = newVm()
        val deal = vm.state.value.tableau.map { p -> p.cards.map { it.id } }
        val played = vm.stats().gamesPlayed
        val gen = vm.gameGeneration
        vm.moveCards(listOf(vm.t(0).cards.last()), vm.t(0), vm.cell(0))
        vm.restartCurrentGame()
        assertEquals(deal, vm.state.value.tableau.map { p -> p.cards.map { it.id } })
        assertEquals(0, vm.state.value.movesCount)
        assertFalse(vm.canUndo)
        assertEquals(played, vm.stats().gamesPlayed)
        assertEquals(gen + 1, vm.gameGeneration)
    }

    @Test fun restartingAWonGameCountsAsANewGamePlayedOnce() {
        val vm = newVm()
        val played = vm.stats().gamesPlayed
        vm.playLastWinningMove()
        assertTrue(vm.state.value.hasWon)
        vm.restartCurrentGame()
        assertFalse(vm.state.value.hasWon)
        assertEquals(played + 1, vm.stats().gamesPlayed)
        vm.restartCurrentGame()
        assertEquals("Restarting again doesn't count twice", played + 1, vm.stats().gamesPlayed)
    }

    @Test fun newGameResetsBoardScoreAndFlags() {
        val vm = newVm()
        vm.oneMove()
        assertEquals(10, vm.state.value.score)
        vm.startNewGame()
        val s = vm.state.value
        assertEquals(0, s.score)
        assertEquals(0, s.movesCount)
        assertEquals(0, s.timerSeconds)
        assertFalse(s.hasWon)
        assertFalse(s.isTimerActive)
        assertFalse(vm.canUndo)
        assertFalse(vm.isStuck.value)
        assertFalse(vm.isAutocompleteAvailable.value)
        assertEquals(52, s.tableau.sumOf { it.cards.size })
    }

    // ---- Stuck ----

    @Test fun stuckDetection() {
        val vm = newVm()
        vm.stuckBoard()
        vm.checkStuck()
        assertTrue("Full cells and no legal move", vm.isStuck.value)

        vm.stuckBoard(withFoundation = true)
        vm.checkStuck()
        assertTrue("Pulling a card back off a foundation is no way out", vm.isStuck.value)

        // One open free cell is always a way forward.
        vm.board(tableau = vm.state.value.tableau.map { it.cards },
            cells = listOf(card(Suit.Spades, 7), card(Suit.Hearts, 7), card(Suit.Diamonds, 7)))
        vm.checkStuck()
        assertFalse(vm.isStuck.value)

        // A real tableau move.
        vm.stuckBoard()
        vm.setState { s -> s.copy(tableau = s.tableau.mapIndexed { i, p -> if (i == 5) p.copy(cards = listOf(card(Suit.Clubs, 6))) else p }) }
        vm.checkStuck()
        assertFalse(vm.isStuck.value)

        // A cell card can still go to an empty column.
        vm.board(tableau = listOf(listOf(card(Suit.Spades, 13))),
            cells = listOf(card(Suit.Spades, 7), card(Suit.Hearts, 7), card(Suit.Diamonds, 7), card(Suit.Clubs, 7)))
        vm.checkStuck()
        assertFalse(vm.isStuck.value)

        // Won games are never stuck.
        vm.stuckBoard()
        vm.setState { it.copy(hasWon = true) }
        vm.checkStuck()
        assertFalse(vm.isStuck.value)
    }

    @Test fun playingIntoADeadEndRaisesStuckAndUndoClearsIt() {
        val vm = newVm()
        vm.stuckBoard()
        vm.setState { s ->
            s.copy(
                freeCells = s.freeCells.mapIndexed { i, p -> if (i == 3) p.copy(cards = emptyList()) else p },
                tableau = s.tableau.mapIndexed { i, p -> if (i == 0) p.copy(cards = listOf(card(Suit.Spades, 13), card(Suit.Clubs, 3))) else p }
            )
        }
        vm.moveCards(listOf(vm.t(0).cards[1]), vm.t(0), vm.cell(3))
        assertTrue(vm.isStuck.value)
        vm.undoLastAction()
        assertFalse(vm.isStuck.value)
    }

    @Test fun aSingleCardMoveOntoAnotherColumnIsAWayOutOfBeingStuck() {
        val vm = newVm()
        // Cells are full, but 5♠ can go onto 6♥.
        vm.board(
            tableau = listOf(
                listOf(card(Suit.Clubs, 13)), listOf(card(Suit.Hearts, 13)), listOf(card(Suit.Diamonds, 13)),
                listOf(card(Suit.Spades, 13)), listOf(card(Suit.Hearts, 6)), listOf(card(Suit.Clubs, 9)),
                listOf(card(Suit.Spades, 9)), listOf(card(Suit.Spades, 5))
            ),
            cells = listOf(card(Suit.Spades, 7), card(Suit.Hearts, 7), card(Suit.Diamonds, 7), card(Suit.Clubs, 7))
        )
        vm.checkStuck()
        assertFalse(vm.isStuck.value)
    }

    // ---- Autocomplete ----

    @Test fun autocompleteIsNotOfferedAtTheStartOfAGame() {
        val vm = newVm()
        vm.checkAutocomplete()
        assertFalse(vm.isAutocompleteAvailable.value)
    }

    @Test fun autocompletePlaysTheGameOutAndRecordsTheWin() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 13), card(Suit.Spades, 12))),
            found = listOf(ascending(Suit.Spades, 11), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13))
        )
        vm.checkAutocomplete()
        assertTrue(vm.isAutocompleteAvailable.value)
        vm.checkStuck()
        assertFalse("Not stuck while Autocomplete is possible", vm.isStuck.value)

        vm.runAutocomplete()
        assertTrue(vm.isAutoplayRunning.value)
        clock.scheduler.advanceTimeBy(1000)
        clock.scheduler.runCurrent()
        assertTrue(vm.state.value.hasWon)
        assertFalse(vm.isAutoplayRunning.value)
        assertEquals(20, vm.state.value.score)
        assertEquals(1, vm.stats().gamesWon)
    }

    @Test fun autocompleteNotOfferedWhenANeededCardIsBuried() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 12), card(Suit.Spades, 13))),
            found = listOf(ascending(Suit.Spades, 11), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13))
        )
        vm.checkAutocomplete()
        assertFalse(vm.isAutocompleteAvailable.value)
        vm.runAutocomplete()
        assertFalse(vm.isAutoplayRunning.value)
    }

    @Test fun autocompleteNotOfferedWhenAQueenIsUnsafe() {
        val vm = newVm()
        // Q♠ is playable, but hearts/diamonds are far behind, so it isn't auto-played.
        vm.board(tableau = listOf(listOf(card(Suit.Spades, 12))), found = listOf(ascending(Suit.Spades, 11)))
        vm.checkAutocomplete()
        assertFalse(vm.isAutocompleteAvailable.value)
    }

    @Test fun autocompletePlaysFreeCellCardsFirst() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 13))),
            cells = listOf(card(Suit.Spades, 12)),
            found = listOf(ascending(Suit.Spades, 11), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13))
        )
        vm.checkAutocomplete()
        assertTrue("Free-cell cards count", vm.isAutocompleteAvailable.value)
        vm.runAutocomplete()
        assertTrue("The cell's Q♠ is the first card played", vm.cell(0).isEmpty)
        clock.scheduler.advanceTimeBy(1000)
        clock.scheduler.runCurrent()
        assertTrue(vm.state.value.hasWon)
    }

    @Test fun autocompleteNotOfferedWhenTheKingIsMissingFromTheBoard() {
        val vm = newVm()
        vm.board(
            cells = listOf(card(Suit.Spades, 12)),
            found = listOf(ascending(Suit.Spades, 11), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13))
        )
        vm.checkAutocomplete()
        assertFalse(vm.isAutocompleteAvailable.value)
    }

    @Test fun undoDuringAutocompleteStopsIt() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 13), card(Suit.Spades, 12))),
            found = listOf(ascending(Suit.Spades, 11), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13))
        )
        vm.checkAutocomplete()
        vm.runAutocomplete()
        assertTrue(vm.isAutoplayRunning.value)
        vm.undoLastAction()
        assertFalse(vm.isAutoplayRunning.value)
        clock.scheduler.advanceTimeBy(1000)
        clock.scheduler.runCurrent()
        assertFalse("The undone cards are not replayed", vm.state.value.hasWon)
    }

    // ---- No Stress Mode and the clock ----

    @Test fun clockStartsOnFirstMoveAndTicksEverySecond() {
        val vm = newVm()
        vm.board(tableau = listOf(listOf(card(Suit.Hearts, 5))) + fillers(7))
        assertFalse(vm.state.value.isTimerActive)
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.cell(0))
        assertTrue(vm.state.value.isTimerActive)
        clock.scheduler.advanceTimeBy(3500)
        clock.scheduler.runCurrent()
        assertEquals(3, vm.state.value.timerSeconds)
    }

    @Test fun noStressModeStopsAndZeroesTheClockAndTaintsTheWin() {
        val vm = newVm()
        vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 13)), listOf(card(Suit.Hearts, 5))) + fillers(6),
            found = nearlyDoneFoundations()
        )
        vm.moveCards(listOf(vm.t(1).cards[0]), vm.t(1), vm.cell(0))
        assertTrue(vm.state.value.isTimerActive)
        vm.setState { it.copy(timerSeconds = 40) }

        vm.sharedOptions.setNoStressMode(true)
        vm.reactToNoStressModeChange()
        assertFalse(vm.state.value.isTimerActive)
        assertEquals(0, vm.state.value.timerSeconds)

        vm.sharedOptions.setNoStressMode(false)
        vm.reactToNoStressModeChange()
        assertTrue("Turning No Stress off restarts the clock mid-game", vm.state.value.isTimerActive)

        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.foundation(0))
        assertTrue(vm.state.value.hasWon)
        assertEquals("A part-untimed win records no time", 0, vm.stats().winningGamesCount)
        assertEquals(1, vm.stats().gamesWon)
    }

    @Test fun noClockInNoStressModeAndNoneBeforeTheFirstMove() {
        val quiet = newVm()
        quiet.sharedOptions.setNoStressMode(true)
        quiet.oneMove()
        assertFalse(quiet.state.value.isTimerActive)

        val fresh = newVm()
        fresh.sharedOptions.setNoStressMode(true); fresh.reactToNoStressModeChange()
        fresh.sharedOptions.setNoStressMode(false); fresh.reactToNoStressModeChange()
        assertFalse("No clock before the first move", fresh.state.value.isTimerActive)
        assertFalse("Toggling before any move doesn't taint the game", fresh.state.value.untimedThisGame)
    }

    @Test fun backgroundingPausesTheClockAndForegroundingResumesIt() {
        val vm = newVm()
        vm.oneMove()
        assertTrue(vm.state.value.isTimerActive)
        vm.pauseTimerForBackground()
        assertFalse(vm.state.value.isTimerActive)
        clock.scheduler.advanceTimeBy(5000)
        clock.scheduler.runCurrent()
        assertEquals(0, vm.state.value.timerSeconds)
        vm.resumeTimerAfterBackground()
        assertTrue(vm.state.value.isTimerActive)

        // Nothing to resume if the clock wasn't running when the app went to the background.
        val idle = newVm()
        idle.pauseTimerForBackground()
        idle.resumeTimerAfterBackground()
        assertFalse(idle.state.value.isTimerActive)
    }

    // ---- Relaunch: options, stats and the game in progress ----

    private fun flush(rig: Rig) {
        clock.scheduler.advanceTimeBy(600)   // past the 500 ms save debounce
        clock.scheduler.runCurrent()
        awaitSaves()
    }

    @Test fun optionsSurviveARelaunch() {
        val rig = newRig()
        assertTrue("Auto-move to foundation defaults on", rig.vm.options.value.autoMoveToFoundation)
        rig.vm.updateOptions(BeecellOptions(autoMoveToFoundation = false))
        flush(rig)
        assertFalse(newRig(rig.ds).vm.options.value.autoMoveToFoundation)
    }

    @Test fun statsSurviveARelaunch() {
        val rig = newRig()
        flush(rig)   // let the deal's own stats write land first — saves aren't ordered, so back-to-back ones can cross
        rig.vm.playLastWinningMove()
        flush(rig)
        val again = newRig(rig.ds).vm.stats()
        assertEquals(1, again.gamesWon)
        assertEquals(1, again.currentStreak)
        assertEquals(10, again.highScore)
    }

    @Test fun aGameInProgressComesBackAfterARelaunchWithTheClockPaused() {
        val rig = newRig()
        rig.vm.board(tableau = listOf(listOf(card(Suit.Spades, 1), card(Suit.Hearts, 5))) + fillers(7))
        rig.vm.moveCards(listOf(rig.vm.t(0).cards[1]), rig.vm.t(0), rig.vm.cell(0))
        val saved = rig.vm.state.value
        flush(rig)

        val back = newRig(rig.ds).vm
        clock.scheduler.runCurrent()
        assertEquals(saved.tableau, back.state.value.tableau)
        assertEquals(saved.freeCells, back.state.value.freeCells)
        assertEquals(1, back.state.value.movesCount)
        assertFalse("The clock doesn't run until the player moves", back.state.value.isTimerActive)
    }

    @Test fun aWonGameIsNotRestoredAfterARelaunch() {
        val rig = newRig()
        rig.vm.playLastWinningMove()
        flush(rig)
        val back = newRig(rig.ds).vm
        assertFalse(back.state.value.hasWon)
        assertEquals(52, back.state.value.tableau.sumOf { it.cards.size })
    }

    @Test fun relaunchedBoardRecomputesAutocompleteAvailability() {
        val rig = newRig()
        rig.vm.board(
            tableau = listOf(listOf(card(Suit.Spades, 13), card(Suit.Spades, 12))),
            found = listOf(ascending(Suit.Spades, 11), ascending(Suit.Clubs, 13), ascending(Suit.Diamonds, 13), ascending(Suit.Hearts, 13))
        )
        rig.vm.setState { it.copy(movesCount = 5) }
        flush(rig)
        val back = newRig(rig.ds).vm
        clock.scheduler.runCurrent()
        assertTrue(back.isAutocompleteAvailable.value)
    }

    @Test fun restartAfterARelaunchReplaysTheSavedDeal() {
        val rig = newRig()
        val deal = rig.vm.state.value.tableau.map { p -> p.cards.map { it.id } }
        rig.vm.moveCards(listOf(rig.vm.t(0).cards.last()), rig.vm.t(0), rig.vm.cell(0))
        flush(rig)
        val back = newRig(rig.ds).vm
        back.restartCurrentGame()
        assertEquals(deal, back.state.value.tableau.map { p -> p.cards.map { it.id } })
        assertNotEquals(0, back.state.value.tableau.size)
    }

    // ---- Stats maths ----

    @Test fun emptyStatsAreSafe() {
        val s = BeecellModeStats()
        assertEquals(0.0, s.winRate, 0.0)
        assertEquals(0.0, s.averageWinningTime, 0.0)
        assertEquals(setOf(4), BeecellStatistics().statsByFreeCells.keys)
    }
}
