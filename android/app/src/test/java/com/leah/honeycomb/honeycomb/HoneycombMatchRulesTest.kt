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

    // Capped Brood + Sudden Death (+ Nectar Exchange): every card still hidden when the
    // board fills is turned over before scoring — sorted by who played it, not
    // originalOwner (Mac: HoneycombBombShelterTests) — so nothing re-enters a Sudden
    // Death hand face-down, and every card that was visible stays visible.
    @Test(timeout = 30_000)
    fun suddenDeathRevealsEveryHiddenCardEvenWithNectarExchange() {
        val vm = newVm()
        // Equal stats everywhere, so nothing captures and the round ends 5-5.
        fun card(id: Int, owner: CardOwner, originalOwner: CardOwner = owner, faceDown: Boolean = false) =
            HoneycombCard(HoneycombCardData(id, "C$id", 3, listOf(5, 5, 5, 5), "S"), owner, originalOwner,
                isFaceDown = faceDown, bombShelterTurnsRemaining = if (faceDown) 3 else null)
        val cells = List(9) { i ->
            HoneycombCell(card = when {
                i == 0 -> card(0, CardOwner.Player, CardOwner.Opponent, faceDown = true) // swapped card, hidden
                i < 4 -> card(i, CardOwner.Player)
                i == 4 -> card(4, CardOwner.Opponent, faceDown = true)
                i < 8 -> card(i, CardOwner.Opponent)
                else -> null
            })
        }
        val playerHand = listOf(card(100, CardOwner.Player))
        val opponentHand = listOf(card(200, CardOwner.Opponent))
        privateFlow<HoneycombState>(vm, "_state").let {
            it.value = it.value.copy(
                activeRules = listOf(HoneycombRule.BombShelter, HoneycombRule.SuddenDeath, HoneycombRule.Swap, HoneycombRule.AllOpen),
                gameState = HoneycombGameState.Playing,
                isPlayerTurn = true,
                board = HoneycombBoard(cells = cells),
                playerHand = playerHand,
                opponentHand = opponentHand,
                openPlayerCardIds = playerHand.map { c -> c.id }.toSet(),
                openOpponentCardIds = opponentHand.map { c -> c.id }.toSet()
            )
        }

        vm.playerPlayCard(0, 8)
        // End-of-board reveal (3 x 1s) + the Sudden Death lead-in (2.5s + 1.5s banner).
        clock.scheduler.advanceTimeBy(7_500)
        clock.scheduler.runCurrent()

        val st = vm.state.value
        assertEquals(HoneycombGameState.Playing, st.gameState)
        assertEquals(10, st.playerHand.size + st.opponentHand.size)
        assertEquals("No card goes back into a hand face-down", emptyList<Int>(),
            (st.playerHand + st.opponentHand).filter { it.isFaceDown }.map { it.data.id })
        assertEquals(st.playerHand.map { it.id }.toSet(), st.openPlayerCardIds)
        assertEquals(st.opponentHand.map { it.id }.toSet(), st.openOpponentCardIds)
    }
}
