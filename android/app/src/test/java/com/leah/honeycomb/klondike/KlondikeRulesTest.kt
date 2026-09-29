package com.leah.honeycomb.klondike

import com.leah.honeycomb.ViewModelTestBase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

// Regression tests for Klondike stats rules fixed on all platforms (Mac is the source of
// truth — see mac/SoliBeeTests/GameViewModelTests.swift for the same cases).
class KlondikeRulesTest : ViewModelTestBase() {
    private fun newVm(): GameViewModel {
        val ds = newDataStore()
        val shared = newSharedOptions(ds)
        return GameViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    private fun GameViewModel.setStreak(n: Int) =
        privateFlow<GameStatistics>(this, "_statistics").let { it.value = it.value.copy(currentStreak = n) }

    @Test(timeout = 20_000)
    fun restartAfterWinCountsAsNewGamePlayed() {
        val vm = newVm()
        vm.drawCard()
        val played = vm.statistics.value.gamesPlayed

        vm.restartCurrentGame()
        assertEquals("Restarting an unfinished game isn't a new game", played, vm.statistics.value.gamesPlayed)

        vm.drawCard()
        privateFlow<GameState>(vm, "_state").let { it.value = it.value.copy(hasWon = true) }
        vm.restartCurrentGame()
        assertEquals("Replaying a won deal counts as a new game played", played + 1, vm.statistics.value.gamesPlayed)
        assertFalse(vm.state.value.hasWon)
    }

    @Test(timeout = 20_000)
    fun undoOrRestartCantDodgeTheStreakBreak() {
        val vm = newVm()

        vm.setStreak(3)
        vm.drawCard()
        vm.undoLastAction()
        assertEquals(0, vm.state.value.movesCount)
        vm.startNewGame()
        assertEquals("New Game after undoing a played game breaks the streak", 0, vm.statistics.value.currentStreak)

        vm.setStreak(3)
        vm.drawCard()
        vm.restartCurrentGame()
        vm.startNewGame()
        assertEquals("New Game after restarting a played game breaks the streak", 0, vm.statistics.value.currentStreak)

        vm.setStreak(3)
        vm.startNewGame()
        assertEquals("An untouched deal keeps the streak", 3, vm.statistics.value.currentStreak)
    }

    @Test(timeout = 20_000)
    fun drawModeChangeDealsACountedGameInTheNewMode() {
        val vm = newVm()
        val target = if (vm.state.value.drawMode == DrawMode.DrawOne) DrawMode.DrawThree else DrawMode.DrawOne
        val played = vm.statistics.value.gamesPlayed
        vm.updateOptions(vm.options.value.copy(drawMode = target))
        assertEquals(target, vm.state.value.drawMode)
        assertEquals(played + 1, vm.statistics.value.gamesPlayed)
    }
}
