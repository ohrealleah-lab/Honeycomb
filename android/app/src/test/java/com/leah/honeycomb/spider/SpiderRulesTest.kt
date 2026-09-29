package com.leah.honeycomb.spider

import com.leah.honeycomb.ViewModelTestBase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SpiderRulesTest : ViewModelTestBase() {
    private fun newVm(): SpiderViewModel {
        val ds = newDataStore()
        val shared = newSharedOptions(ds)
        return SpiderViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    private fun SpiderViewModel.modeStats(): SpiderModeStats =
        statistics.value.statsBySuits[options.value.suitCount] ?: SpiderModeStats()

    private fun SpiderViewModel.setStreak(n: Int) {
        val flow = privateFlow<SpiderStatistics>(this, "_statistics")
        val suits = options.value.suitCount
        val current = flow.value.statsBySuits[suits] ?: SpiderModeStats()
        flow.value = flow.value.copy(statsBySuits = flow.value.statsBySuits + (suits to current.copy(currentStreak = n)))
    }

    // Undo back to the start (or Restart) then New Game still abandons a played game.
    @Test(timeout = 20_000)
    fun undoOrRestartCantDodgeTheStreakBreak() {
        val vm = newVm()

        vm.setStreak(3)
        assertTrue(vm.drawFromStock())
        vm.undoLastAction()
        assertEquals(0, vm.state.value.movesCount)
        vm.startNewGame()
        assertEquals(0, vm.modeStats().currentStreak)

        vm.setStreak(3)
        assertTrue(vm.drawFromStock())
        vm.restartCurrentGame()
        vm.startNewGame()
        assertEquals(0, vm.modeStats().currentStreak)

        vm.setStreak(3)
        vm.startNewGame()
        assertEquals("An untouched deal keeps the streak", 3, vm.modeStats().currentStreak)
    }
}
