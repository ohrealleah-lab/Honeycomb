package com.leah.honeycomb.spider

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
import org.junit.Assert.assertTrue
import org.junit.Test

// Player-visible Spider behaviour on fixed layouts, ported from Mac's SpiderGameplayTests:
// the deal for each suit count, stock deals, move rules, finished runs and scoring, winning
// and stats, No Stress, streak and restart rules, undo, "stuck", Autocomplete, double-tap,
// and what survives a relaunch. Hints are timing-dependent and Mac's keyboard tests have no
// Android equivalent, so neither is ported. (Mac's point-popup test is left out: Android
// Spider never shows one — see the report.)
@OptIn(ExperimentalCoroutinesApi::class)
class SpiderGameplayTest : ViewModelTestBase() {

    // ---- Fixtures ----

    private class Rig(val vm: SpiderViewModel, val ds: DataStore<Preferences>)

    private fun newRig(ds: DataStore<Preferences> = newDataStore()): Rig {
        val shared = newSharedOptions(ds)
        return Rig(SpiderViewModel(shared, ds, newBannerCatalog(ds, shared)), ds)
    }

    private fun newVm() = newRig().vm

    private fun c(suit: Suit, rank: Int, up: Boolean = true) = Card(suit = suit, rank = rank, faceUp = up)
    private fun run(suit: Suit, from: Int, through: Int) = (from downTo through).map { c(suit, it) }
    private fun king() = listOf(c(Suit.Diamonds, 13))
    private fun padded(cols: List<List<Card>>) = cols + (cols.size until 10).map { king() }

    // Hand-built board: `cols` fills columns 0… (the rest empty); `doneRuns` pre-fills that many
    // foundations with a full spade K→A run.
    private fun SpiderViewModel.board(cols: List<List<Card>>, stock: List<Card> = emptyList(), doneRuns: Int = 0) {
        val flow = privateFlow<SpiderState>(this, "_state")
        flow.value = flow.value.copy(
            tableau = (0 until 10).map { Pile("tableau_$it", PileType.Tableau, cols.getOrElse(it) { emptyList() }) },
            stock = Pile("stock", PileType.Stock, stock),
            foundations = (0 until 8).map { Pile("foundation_$it", PileType.Foundation, if (it < doneRuns) run(Suit.Spades, 13, 1) else emptyList()) },
            score = 500, movesCount = 0, timerSeconds = 0, isTimerActive = false, hasWon = false
        )
        privateFlow<Boolean>(this, "_isStuck").value = false
        privateFlow<Boolean>(this, "_isAutocompleteAvailable").value = false
    }

    private fun SpiderViewModel.setState(f: (SpiderState) -> SpiderState) {
        val flow = privateFlow<SpiderState>(this, "_state")
        flow.value = f(flow.value)
    }

    private fun SpiderViewModel.oneMoveFromWinning() =
        board(listOf(run(Suit.Spades, 13, 2), listOf(c(Suit.Spades, 1))), doneRuns = 7)

    private fun SpiderViewModel.checkStuck() {
        val m = javaClass.getDeclaredMethod("checkStuckState")
        m.isAccessible = true
        m.invoke(this)
    }

    private fun SpiderViewModel.t(i: Int) = state.value.tableau[i]
    private fun SpiderViewModel.ids() = state.value.tableau.map { p -> p.cards.map { it.id } }
    private fun SpiderViewModel.mode(suits: Int = options.value.suitCount) = statistics.value.statsBySuits[suits] ?: SpiderModeStats()
    private fun SpiderViewModel.primeStats(suits: Int, stats: SpiderModeStats) {
        val flow = privateFlow<SpiderStatistics>(this, "_statistics")
        flow.value = flow.value.copy(statsBySuits = flow.value.statsBySuits + (suits to stats))
    }

    private fun SpiderViewModel.finishTheLastRun() = moveCards(listOf(t(1).cards[0]), t(1), t(0))

    private fun flush() {
        clock.scheduler.advanceTimeBy(600)   // past the 500 ms save debounce
        clock.scheduler.runCurrent()
        runBlocking { PreferencesHelper.awaitPendingWrites(5000) }
    }

    // ---- Deal ----

    @Test fun dealLayoutForEachSuitCount() {
        val vm = newVm()
        for (suits in listOf(1, 2, 4)) {
            vm.updateOptions(vm.options.value.copy(suitCount = suits))
            val s = vm.state.value
            assertEquals(10, s.tableau.size)
            s.tableau.forEachIndexed { i, pile ->
                assertEquals("Column $i", if (i < 4) 6 else 5, pile.cards.size)
                assertTrue("Top card face up", pile.cards.last().faceUp)
                assertTrue("Other cards face down", pile.cards.dropLast(1).none { it.faceUp })
            }
            assertEquals(50, s.stock.cards.size)
            assertTrue(s.stock.cards.none { it.faceUp })
            assertEquals(8, s.foundations.size)
            assertTrue(s.foundations.all { it.isEmpty })
            assertEquals(500, s.score)
            assertEquals(0, s.movesCount)
            val all = s.tableau.flatMap { it.cards } + s.stock.cards
            assertEquals(104, all.map { it.id }.toSet().size)
            assertEquals("$suits-suit game uses $suits suit(s)", suits, all.map { it.suit }.toSet().size)
            val counts = all.groupingBy { it.suit to it.rank }.eachCount()
            assertTrue("Each (suit, rank) appears ${8 / suits} times", counts.values.all { it == 8 / suits })
        }
        assertEquals("Switching suit count deals and counts a game in the new mode", 1, vm.mode(2).gamesPlayed)
        assertEquals(1, vm.mode(4).gamesPlayed)
    }

    @Test fun suitCountSurvivesARelaunch() {
        val rig = newRig()
        rig.vm.updateOptions(rig.vm.options.value.copy(suitCount = 4))
        flush()
        assertEquals(4, newRig(rig.ds).vm.options.value.suitCount)
    }

    // ---- Stock ----

    @Test fun stockDealRules() {
        val vm = newVm()
        val stock = (0 until 20).map { c(Suit.Hearts, 1 + it % 13, up = false) }
        vm.board((0 until 10).map { king() }, stock = stock)
        val willGoToColumn0 = vm.state.value.stock.cards.last()

        assertTrue(vm.drawFromStock())
        assertEquals("A stock deal uses 10 cards", 10, vm.state.value.stock.cards.size)
        assertTrue(vm.state.value.tableau.all { it.cards.size == 2 && it.cards.last().faceUp })
        assertEquals("The top of the stock goes to the first column", willGoToColumn0.id, vm.t(0).cards.last().id)
        assertEquals(499, vm.state.value.score)
        assertEquals(1, vm.state.value.movesCount)
        assertTrue(vm.canUndo)

        vm.undoLastAction()
        assertEquals(20, vm.state.value.stock.cards.size)
        assertTrue(vm.state.value.tableau.all { it.cards.size == 1 })
        assertEquals(500, vm.state.value.score)
        assertEquals(0, vm.state.value.movesCount)
    }

    @Test fun dealingIsRefusedWhileAColumnIsEmpty_AndAnEmptyStockDoesNothing() {
        val stock = (0 until 20).map { c(Suit.Hearts, 1 + it % 13, up = false) }
        val blocked = newVm()
        blocked.board((0 until 10).map { if (it == 3) emptyList() else king() }, stock = stock)
        assertFalse(blocked.drawFromStock())
        assertEquals(20, blocked.state.value.stock.cards.size)
        assertEquals(0, blocked.state.value.movesCount)
        assertFalse(blocked.canUndo)

        val drained = newVm()
        drained.board((0 until 10).map { king() }, stock = emptyList())
        assertFalse(drained.drawFromStock())
        assertEquals(0, drained.state.value.movesCount)
        assertEquals(500, drained.state.value.score)
    }

    @Test fun theScoreNeverGoesBelowZero() {
        val vm = newVm()
        vm.board((0 until 10).map { king() }, stock = (0 until 10).map { c(Suit.Hearts, 3, up = false) })
        vm.setState { it.copy(score = 0) }
        vm.drawFromStock()
        assertEquals(0, vm.state.value.score)
    }

    @Test fun dealingTheLastRowCanLeaveTheBoardStuck() {
        val vm = newVm()
        vm.board((0 until 10).map { king() }, stock = (0 until 10).map { c(Suit.Spades, 13, up = false) })
        vm.drawFromStock()
        assertTrue(vm.state.value.stock.isEmpty)
        assertTrue("No legal move after the final deal → stuck", vm.isStuck.value)
        assertFalse("Autocomplete can't finish a stuck board", vm.isAutocompleteAvailable.value)
    }

    // ---- Moves ----

    @Test fun moveRulesAndUndo() {
        val vm = newVm()
        val five = c(Suit.Hearts, 5)
        val nine = c(Suit.Clubs, 9, up = false)
        val six = c(Suit.Spades, 6)
        vm.board(padded(listOf(listOf(nine, five), listOf(six), emptyList())))
        val before = vm.ids()

        assertTrue(vm.moveCards(listOf(five), vm.t(0), vm.t(1)))
        assertEquals("5♥ lands on 6♠ (suit doesn't matter)", listOf(six.id, five.id), vm.t(1).cards.map { it.id })
        assertEquals(1, vm.t(0).cards.size)
        assertTrue("The card left behind turns face up", vm.t(0).cards[0].faceUp)
        assertEquals(499, vm.state.value.score)
        assertEquals(1, vm.state.value.movesCount)

        val snapshot = vm.ids()
        assertFalse("9♣ can't go onto 5♥", vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.t(1)))
        assertEquals(snapshot, vm.ids())
        assertEquals(1, vm.state.value.movesCount)

        assertFalse("Can't drop on a foundation", vm.isValidMove(listOf(five), vm.state.value.foundations[0]))
        assertFalse("Can't drop on the stock", vm.isValidMove(listOf(five), vm.state.value.stock))
        assertFalse("Nothing to move isn't a move", vm.isValidMove(emptyList(), vm.t(1)))

        assertTrue(vm.undoLastAction())
        assertEquals("Undo restores the exact layout", before, vm.ids())
        assertFalse("...including the card that had been flipped", vm.t(0).cards[0].faceUp)
        assertEquals(500, vm.state.value.score)
        assertEquals(0, vm.state.value.movesCount)
        assertFalse(vm.canUndo)
    }

    @Test fun dragValidity() {
        val vm = newVm()
        val s6 = c(Suit.Spades, 6)
        val s5 = c(Suit.Spades, 5)
        val h4 = c(Suit.Hearts, 4)
        assertTrue("A same-suit descending run can be dragged", vm.isValidDragSequence(listOf(s6, s5)))
        assertFalse("Mixed suits can't", vm.isValidDragSequence(listOf(s6, h4)))
        assertFalse("Ascending cards can't", vm.isValidDragSequence(listOf(s5, s6)))
        assertFalse("An empty drag is invalid", vm.isValidDragSequence(emptyList()))
        assertFalse("A face-down card can't be dragged", vm.isValidDragSequence(listOf(c(Suit.Spades, 6, up = false))))
        assertFalse("A run with a face-down card can't be dragged", vm.isValidDragSequence(listOf(s6, c(Suit.Spades, 5, up = false))))
    }

    @Test fun aWholeRunMovesToAnEmptyColumn_AndAnyCardMayTakeOne() {
        val vm = newVm()
        val s6 = c(Suit.Spades, 6)
        val s5 = c(Suit.Spades, 5)
        vm.board(padded(listOf(listOf(c(Suit.Clubs, 9, up = false), s6, s5), emptyList(), emptyList())))
        assertTrue(vm.moveCards(listOf(s6, s5), vm.t(0), vm.t(1)))
        assertEquals(listOf(s6.id, s5.id), vm.t(1).cards.map { it.id })
        assertEquals(1, vm.t(0).cards.size)
        assertTrue("The uncovered card flips", vm.t(0).cards[0].faceUp)
        assertTrue(vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.t(2)))
        assertEquals(1, vm.t(2).cards.size)
        assertTrue(vm.t(0).isEmpty)
    }

    // ---- Completed runs ----

    @Test fun aCompletedRunGoesToAFoundationAndScores() {
        val vm = newVm()
        val hidden = c(Suit.Hearts, 2, up = false)
        val ace = c(Suit.Spades, 1)
        vm.board(padded(listOf(listOf(hidden) + run(Suit.Spades, 13, 2), listOf(ace))))

        vm.moveCards(listOf(ace), vm.t(1), vm.t(0))

        val f0 = vm.state.value.foundations[0]
        assertEquals(13, f0.cards.size)
        assertEquals(13, f0.cards.first().rank)
        assertEquals(1, f0.cards.last().rank)
        assertEquals(listOf(hidden.id), vm.t(0).cards.map { it.id })
        assertTrue("The card under the run is revealed", vm.t(0).cards[0].faceUp)
        assertEquals("A move costs 1; a finished run earns 100", 500 - 1 + 100, vm.state.value.score)
        assertFalse("One run is not a win", vm.state.value.hasWon)

        vm.undoLastAction()
        assertTrue(vm.state.value.foundations.all { it.isEmpty })
        assertEquals(13, vm.t(0).cards.size)
        assertEquals(1, vm.t(1).cards.size)
        assertEquals(500, vm.state.value.score)
    }

    @Test fun aMixedSuitRunIsNotRemoved() {
        val vm = newVm()
        val ace = c(Suit.Hearts, 1)
        vm.board(padded(listOf(run(Suit.Spades, 13, 2), listOf(ace))))
        vm.moveCards(listOf(ace), vm.t(1), vm.t(0))
        assertEquals(13, vm.t(0).cards.size)
        assertTrue(vm.state.value.foundations.all { it.isEmpty })
        assertEquals(499, vm.state.value.score)
    }

    // ---- Winning and stats ----

    @Test fun winRecordsStatsAndLocksUndo() {
        val rig = newRig()
        val vm = rig.vm
        vm.oneMoveFromWinning()
        vm.setState { it.copy(timerSeconds = 100) }
        vm.finishTheLastRun()

        assertTrue(vm.state.value.hasWon)
        assertFalse(vm.state.value.isTimerActive)
        assertEquals(104, vm.state.value.foundations.sumOf { it.cards.size })
        val s = vm.mode()
        assertEquals(1, s.gamesWon)
        assertEquals(1, s.currentStreak)
        assertEquals(1, s.longestStreak)
        assertEquals(100, s.totalWinningTime)
        assertEquals(1, s.winningGamesCount)
        assertEquals(100, s.shortestWinTime)
        assertEquals(100.0, s.averageWinningTime, 0.0)
        assertEquals(599, s.highScore)
        assertFalse(vm.canUndo)
        assertFalse(vm.undoLastAction())
        assertTrue(vm.state.value.hasWon)

        flush()
        val again = newRig(rig.ds).vm.mode()
        assertEquals(1, again.gamesWon)
        assertEquals(100, again.shortestWinTime)
        assertEquals(599, again.highScore)
    }

    @Test fun aNoStressWinCountsButRecordsNoTime_AndKeepsAHigherHighScore() {
        val vm = newVm()
        vm.sharedOptions.setNoStressMode(true)
        vm.primeStats(1, SpiderModeStats(highScore = 700))
        vm.oneMoveFromWinning()
        vm.setState { it.copy(timerSeconds = 100) }
        vm.finishTheLastRun()
        val s = vm.mode()
        assertTrue(vm.state.value.hasWon)
        assertEquals(1, s.gamesWon)
        assertEquals(0, s.winningGamesCount)
        assertEquals(0, s.totalWinningTime)
        assertEquals(0, s.shortestWinTime)
        assertEquals("A lower score doesn't replace the high score", 700, s.highScore)
        assertFalse("No clock runs in No Stress Mode", vm.state.value.isTimerActive)
    }

    @Test fun togglingNoStressMidGameTaintsTheTime() {
        val vm = newVm()
        vm.board(padded(listOf(run(Suit.Spades, 13, 3), listOf(c(Suit.Spades, 2)), listOf(c(Suit.Spades, 1)))), doneRuns = 7)
        vm.moveCards(listOf(vm.t(1).cards[0]), vm.t(1), vm.t(0))
        assertTrue("The first move starts the clock", vm.state.value.isTimerActive)
        vm.setState { it.copy(timerSeconds = 42) }

        vm.sharedOptions.setNoStressMode(true)
        vm.reactToNoStressModeChange()
        assertFalse(vm.state.value.isTimerActive)
        assertEquals(0, vm.state.value.timerSeconds)
        vm.sharedOptions.setNoStressMode(false)
        vm.reactToNoStressModeChange()
        assertTrue("Turning it off restarts the clock", vm.state.value.isTimerActive)

        vm.moveCards(listOf(vm.t(2).cards[0]), vm.t(2), vm.t(0))
        assertTrue(vm.state.value.hasWon)
        assertEquals(1, vm.mode().gamesWon)
        assertEquals("A part-untimed game records no best time", 0, vm.mode().winningGamesCount)
        assertEquals(0, vm.mode().shortestWinTime)

        val fresh = newVm()
        fresh.sharedOptions.setNoStressMode(true); fresh.reactToNoStressModeChange()
        fresh.sharedOptions.setNoStressMode(false); fresh.reactToNoStressModeChange()
        assertFalse("No clock before the first move", fresh.state.value.isTimerActive)
    }

    @Test fun clockTicksEverySecond_AndPausesInTheBackground() {
        val vm = newVm()
        vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))))
        vm.moveCards(listOf(vm.t(0).cards[0]), vm.t(0), vm.t(1))
        clock.scheduler.advanceTimeBy(3500); clock.scheduler.runCurrent()
        assertEquals(3, vm.state.value.timerSeconds)
        vm.pauseTimerForBackground()
        assertFalse(vm.state.value.isTimerActive)
        clock.scheduler.advanceTimeBy(5000); clock.scheduler.runCurrent()
        assertEquals(3, vm.state.value.timerSeconds)
        vm.resumeTimerAfterBackground()
        assertTrue(vm.state.value.isTimerActive)
    }

    @Test fun statsStayPerSuitMode_AndWinsAccumulate() {
        val vm = newVm()
        vm.primeStats(1, SpiderModeStats(gamesPlayed = 5, gamesWon = 2, currentStreak = 2, longestStreak = 2, shortestWinTime = 120,
            totalWinningTime = 210, winningGamesCount = 2))
        vm.oneMoveFromWinning()
        vm.setState { it.copy(timerSeconds = 90) }
        vm.finishTheLastRun()
        val s = vm.mode(1)
        assertEquals(3, s.gamesWon)
        assertEquals(3, s.currentStreak)
        assertEquals(3, s.longestStreak)
        assertEquals(90, s.shortestWinTime)
        assertEquals(300, s.totalWinningTime)
        assertEquals(3, s.winningGamesCount)
        assertEquals(100.0, s.averageWinningTime, 0.0)

        vm.updateOptions(vm.options.value.copy(suitCount = 2))
        assertEquals("2-suit stats are separate", 0, vm.mode(2).gamesWon)
        assertEquals(3, vm.mode(1).gamesWon)
        assertEquals(0.0, SpiderModeStats().winRate, 0.0)
        assertEquals(0.0, SpiderModeStats().averageWinningTime, 0.0)
        assertEquals(500, SpiderModeStats().highScore)
    }

    // ---- Streaks and restart ----

    private fun primed(streak: Int): SpiderViewModel {
        val vm = newVm()
        vm.primeStats(1, SpiderModeStats(currentStreak = streak, longestStreak = streak))
        return vm
    }

    private fun SpiderViewModel.playOneMove() {
        board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))))
        moveCards(listOf(t(0).cards[0]), t(0), t(1))
    }

    @Test fun streakRulesForNewGame() {
        val untouched = primed(4); untouched.startNewGame()
        assertEquals("A new deal before moving keeps the streak", 4, untouched.mode().currentStreak)

        val played = primed(4); played.playOneMove(); played.startNewGame()
        assertEquals(0, played.mode().currentStreak)
        assertEquals("...but keeps the best", 4, played.mode().longestStreak)

        val undone = primed(4); undone.playOneMove(); undone.undoLastAction(); undone.startNewGame()
        assertEquals("Undo-to-start can't dodge the break", 0, undone.mode().currentStreak)

        val restarted = primed(4); restarted.playOneMove(); restarted.restartCurrentGame(); restarted.startNewGame()
        assertEquals("Restart can't dodge it either", 0, restarted.mode().currentStreak)

        val won = primed(0)
        won.oneMoveFromWinning(); won.finishTheLastRun()
        val playedBefore = won.mode().gamesPlayed
        won.startNewGame()
        assertEquals("A new game after a win keeps the streak", 1, won.mode().currentStreak)
        assertEquals(playedBefore + 1, won.mode().gamesPlayed)
    }

    @Test fun changingSuitCountMidGameBreaksTheStreakOfTheModeLeft() {
        val vm = primed(4)
        vm.playOneMove()
        vm.updateOptions(vm.options.value.copy(suitCount = 2))
        assertEquals("The abandoned 1-suit game loses its streak", 0, vm.mode(1).currentStreak)
        assertEquals(4, vm.mode(1).longestStreak)
    }

    @Test fun restartRules() {
        val vm = newVm()
        val initialTableau = vm.ids()
        val initialStock = vm.state.value.stock.cards.map { it.id }
        val generation = vm.gameGeneration
        val played = vm.mode().gamesPlayed

        vm.drawFromStock()
        assertEquals(40, vm.state.value.stock.cards.size)
        vm.restartCurrentGame()
        assertEquals("Restart replays the same deal", initialTableau, vm.ids())
        assertEquals(initialStock, vm.state.value.stock.cards.map { it.id })
        assertEquals(500, vm.state.value.score)
        assertEquals(0, vm.state.value.movesCount)
        assertFalse(vm.canUndo)
        assertEquals("Restarting an unwon game isn't another game", played, vm.mode().gamesPlayed)
        assertEquals(generation + 1, vm.gameGeneration)

        vm.oneMoveFromWinning()
        vm.finishTheLastRun()
        assertTrue(vm.state.value.hasWon)
        val playedAtWin = vm.mode().gamesPlayed
        vm.restartCurrentGame()
        assertFalse(vm.state.value.hasWon)
        assertEquals("Restarting a won game counts as a new game", playedAtWin + 1, vm.mode().gamesPlayed)
        assertEquals("...and doesn't break the win streak", 1, vm.mode().currentStreak)
    }

    // ---- Undo ----

    @Test fun undoBehaviour() {
        val vm = newVm()
        assertFalse(vm.undoLastAction())
        assertEquals(0, vm.state.value.movesCount)

        val stock = (0 until 10).map { c(Suit.Hearts, 3, up = false) }
        vm.board(padded(listOf(listOf(c(Suit.Clubs, 9), c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))), stock = stock)
        val start = vm.ids()
        vm.moveCards(listOf(vm.t(0).cards[1]), vm.t(0), vm.t(1))
        vm.drawFromStock()
        vm.setState { it.copy(timerSeconds = 30) }
        assertEquals(2, vm.state.value.movesCount)

        vm.undoLastAction()
        assertEquals("The clock keeps running forward through an undo", 30, vm.state.value.timerSeconds)
        assertEquals(10, vm.state.value.stock.cards.size)
        assertEquals(1, vm.state.value.movesCount)
        vm.undoLastAction()
        assertEquals(start, vm.ids())
        assertEquals(0, vm.state.value.movesCount)
        assertFalse(vm.canUndo)
    }

    @Test fun undoRemembersTheLastHundredMoves() {
        val vm = newVm()
        // Shuttle the 5♥ between two sixes (a one-card stock keeps Autocomplete from simulating).
        vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)), listOf(c(Suit.Diamonds, 6)))),
            stock = listOf(c(Suit.Hearts, 2, up = false)))
        var at = 0
        for (i in 0 until 110) {
            val dst = if (i % 2 == 0) 1 else 2
            vm.moveCards(listOf(vm.t(at).cards.last()), vm.t(at), vm.t(dst))
            at = dst
        }
        var undos = 0
        while (vm.canUndo && undos < 500) { vm.undoLastAction(); undos++ }
        assertEquals(100, undos)
    }

    // ---- Stuck ----

    @Test fun stuckDetection() {
        val vm = newVm()
        vm.board((0 until 10).map { king() })
        vm.checkStuck()
        assertTrue("Ten lone kings, no stock, no empty column: stuck", vm.isStuck.value)

        vm.board((0 until 10).map { king() }, stock = listOf(c(Suit.Spades, 2, up = false)))
        vm.checkStuck()
        assertFalse("A dealable stock means not stuck", vm.isStuck.value)

        vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))))
        vm.checkStuck()
        assertFalse("A legal move means not stuck", vm.isStuck.value)

        vm.board((0 until 10).map { king() })
        vm.setState { it.copy(hasWon = true) }
        vm.checkStuck()
        assertFalse("A won game is never stuck", vm.isStuck.value)
    }

    @Test fun movingBetweenIdenticalStacksIsNotAWayOut() {
        val vm = newVm()
        vm.board(padded(listOf(listOf(c(Suit.Spades, 6), c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))))
        vm.moveCards(listOf(vm.t(0).cards[1]), vm.t(0), vm.t(1))
        assertTrue("Only the pointless 5♥ shuttle between two 6♠ is left: stuck", vm.isStuck.value)

        vm.board(padded(listOf(listOf(c(Suit.Spades, 6), c(Suit.Hearts, 5)), listOf(c(Suit.Clubs, 6)), listOf(c(Suit.Spades, 7)))))
        vm.moveCards(listOf(vm.t(0).cards[1]), vm.t(0), vm.t(1))
        assertFalse("The 6♠ can still go onto the 7♠: not stuck", vm.isStuck.value)
    }

    @Test fun undoingTheLastDealClearsTheStuckFlag() {
        val vm = newVm()
        vm.board((0 until 10).map { king() }, stock = (0 until 10).map { c(Suit.Spades, 13, up = false) })
        vm.drawFromStock()
        assertTrue(vm.isStuck.value)
        vm.undoLastAction()
        assertFalse("With the row back on the stock there's a deal to make", vm.isStuck.value)
    }

    // ---- Autocomplete ----

    @Test fun autocompleteIsOfferedOnlyWhenItFinishesTheGame() {
        val vm = newVm()
        vm.board(listOf(run(Suit.Spades, 13, 2), listOf(c(Suit.Spades, 1))), stock = listOf(c(Suit.Hearts, 1, up = false)), doneRuns = 7)
        vm.checkAutocompleteState()
        assertFalse("Not offered while the stock has cards", vm.isAutocompleteAvailable.value)

        vm.oneMoveFromWinning()
        vm.checkAutocompleteState()
        assertTrue("Offered when simulating it finishes the game", vm.isAutocompleteAvailable.value)
        vm.checkStuck()
        assertFalse("An Autocomplete-able board is never stuck", vm.isStuck.value)

        vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 13)))))
        vm.checkAutocompleteState()
        assertFalse("Not offered when the game can't be finished", vm.isAutocompleteAvailable.value)
        vm.runAutocomplete()
        assertFalse(vm.isAutoplayRunning.value)
        assertEquals(0, vm.state.value.movesCount)

        vm.board(emptyList(), doneRuns = 8)
        vm.checkAutocompleteState()
        assertFalse("Nothing to autocomplete on a finished board", vm.isAutocompleteAvailable.value)
    }

    @Test fun autocompleteRunsToAWin() {
        val vm = newVm()
        // 2♠ must hop onto the 3♠, then the A♠ onto the 2♠ to finish the eighth run.
        vm.board(listOf(run(Suit.Spades, 13, 3), listOf(c(Suit.Spades, 2)), listOf(c(Suit.Spades, 1))), doneRuns = 7)
        vm.checkAutocompleteState()
        assertTrue(vm.isAutocompleteAvailable.value)
        vm.runAutocomplete()
        assertTrue(vm.isAutoplayRunning.value)
        clock.scheduler.advanceTimeBy(1000); clock.scheduler.runCurrent()
        assertTrue(vm.state.value.hasWon)
        assertFalse(vm.isAutoplayRunning.value)
        assertEquals(1, vm.mode().gamesWon)
        assertEquals("Two autoplayed moves cost 2; the run earns 100", 500 - 2 + 100, vm.state.value.score)
    }

    @Test fun undoDuringAutocompleteReversesItInOneStep() {
        val vm = newVm()
        vm.board(listOf(run(Suit.Spades, 13, 3), listOf(c(Suit.Spades, 2)), listOf(c(Suit.Spades, 1))), doneRuns = 7)
        val start = vm.ids()
        vm.checkAutocompleteState()
        vm.runAutocomplete()
        assertEquals("The first autoplay move happens immediately", 12, vm.t(0).cards.size)
        vm.undoLastAction()
        assertFalse(vm.isAutoplayRunning.value)
        assertEquals(start, vm.ids())
        assertEquals(500, vm.state.value.score)
        clock.scheduler.advanceTimeBy(1000); clock.scheduler.runCurrent()
        assertEquals("Autocomplete doesn't resume after an undo", start, vm.ids())
    }

    // ---- Double-tap ----

    @Test fun doubleTapPicksTheBestTarget() {
        // 1) A same-suit build beats a different-suit build.
        var vm = newVm()
        vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)), listOf(c(Suit.Hearts, 6)))))
        assertTrue(vm.doubleClickMove(vm.t(0).cards[0], vm.t(0)))
        assertEquals(2, vm.t(2).cards.size)
        assertTrue(vm.t(0).isEmpty)

        // 2) Otherwise any card one rank higher.
        vm = newVm()
        vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))))
        assertTrue(vm.doubleClickMove(vm.t(0).cards[0], vm.t(0)))
        assertEquals(2, vm.t(1).cards.size)

        // 3) Otherwise an empty column; the uncovered card flips.
        vm = newVm()
        vm.board(listOf(listOf(c(Suit.Clubs, 9, up = false), c(Suit.Hearts, 5)), king(), emptyList()) + (3 until 10).map { king() })
        assertTrue(vm.doubleClickMove(vm.t(0).cards[1], vm.t(0)))
        assertEquals(1, vm.t(2).cards.size)
        assertEquals(1, vm.t(0).cards.size)
        assertTrue(vm.t(0).cards[0].faceUp)

        // 4) Face-down cards, broken runs and dead ends do nothing.
        vm = newVm()
        vm.board(listOf(listOf(c(Suit.Clubs, 9, up = false), c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6), c(Suit.Hearts, 5))) + (2 until 10).map { king() })
        assertFalse("A face-down card", vm.doubleClickMove(vm.t(0).cards[0], vm.t(0)))
        assertFalse("A mixed-suit stack", vm.doubleClickMove(vm.t(1).cards[0], vm.t(1)))
        assertFalse("A card with nowhere to go", vm.doubleClickMove(vm.t(5).cards[0], vm.t(5)))
        assertEquals(0, vm.state.value.movesCount)
    }

    // ---- Relaunch ----

    @Test fun aGameInProgressComesBackAfterARelaunchWithTheClockPaused() {
        val rig = newRig()
        rig.vm.board(padded(listOf(listOf(c(Suit.Hearts, 5)), listOf(c(Suit.Spades, 6)))))
        rig.vm.moveCards(listOf(rig.vm.t(0).cards[0]), rig.vm.t(0), rig.vm.t(1))
        val saved = rig.vm.state.value
        flush()

        val back = newRig(rig.ds).vm
        clock.scheduler.runCurrent()
        assertEquals(saved.tableau, back.state.value.tableau)
        assertEquals(1, back.state.value.movesCount)
        assertFalse(back.state.value.isTimerActive)
    }

    @Test fun aWonGameIsNotRestoredAfterARelaunch() {
        val rig = newRig()
        rig.vm.oneMoveFromWinning()
        rig.vm.finishTheLastRun()
        flush()
        val back = newRig(rig.ds).vm
        assertFalse(back.state.value.hasWon)
        assertEquals(104, (back.state.value.tableau.flatMap { it.cards } + back.state.value.stock.cards).size)
    }
}
