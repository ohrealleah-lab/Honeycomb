package com.leah.honeycomb.honeycomb

import com.leah.honeycomb.ViewModelTestBase
import org.junit.Assert.assertEquals
import org.junit.Test

// Leaving a Honeycomb match that's still being played counts as a loss and ends the win
// streak (product decision, all platforms — Mac: HoneycombBannerTriggerTests).
class HoneycombMatchRulesTest : ViewModelTestBase() {
    private fun newVm(): HoneycombViewModel {
        val ds = newDataStore()
        val shared = newSharedOptions(ds)
        val db = HoneycombDatabase(ds)
        return HoneycombViewModel(shared, db, HoneycombProfileManager(ds, db), ds, newBannerCatalog(ds, shared), language)
    }

    private fun HoneycombViewModel.setGameState(s: HoneycombGameState) =
        privateFlow<HoneycombState>(this, "_state").let { it.value = it.value.copy(gameState = s) }

    private fun HoneycombViewModel.setWinStreak(n: Int) =
        privateFlow<HoneycombStats>(this, "_statistics").let { it.value = it.value.copy(currentWinStreak = n) }

    @Test(timeout = 30_000)
    fun leavingAMatchInPlayCountsAsALoss() {
        val vm = newVm()
        vm.setWinStreak(4)
        val lostBefore = vm.statistics.value.matchesLost

        vm.setGameState(HoneycombGameState.Setup)
        vm.quitMatch()
        assertEquals("Quitting from setup records nothing", lostBefore, vm.statistics.value.matchesLost)
        assertEquals(4, vm.statistics.value.currentWinStreak)

        vm.setGameState(HoneycombGameState.Playing)
        vm.quitMatch()
        assertEquals("Quitting mid-match is a loss", lostBefore + 1, vm.statistics.value.matchesLost)
        assertEquals("…and ends the win streak", 0, vm.statistics.value.currentWinStreak)

        vm.setGameState(HoneycombGameState.SuddenDeath)
        vm.startNewGame()
        assertEquals("A new match during Sudden Death abandons the current one", lostBefore + 2, vm.statistics.value.matchesLost)

        vm.setGameState(HoneycombGameState.GameOver)
        vm.quitMatch()
        assertEquals("Leaving a finished match records nothing more", lostBefore + 2, vm.statistics.value.matchesLost)
    }
}
