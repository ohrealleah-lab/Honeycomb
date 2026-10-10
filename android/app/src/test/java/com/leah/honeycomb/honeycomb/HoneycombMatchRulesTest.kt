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

    // Capped Brood: the second side's hidden first card lands next to cards already on the
    // board, but captures nothing until it turns over (Mac/Windows pass skipCaptures).
    @Test(timeout = 30_000)
    fun hiddenCappedBroodCardDoesNotCaptureOnPlacement() {
        val vm = newVm()
        fun card(id: Int, owner: CardOwner, stat: Int) =
            HoneycombCard(HoneycombCardData(id, "C$id", 3, listOf(stat, stat, stat, stat), "S"), owner)
        // The opponent's weak first card sits face-down in cell 0, its timer still running.
        val opponentFirst = card(50, CardOwner.Opponent, 1).apply { isFaceDown = true; bombShelterTurnsRemaining = 3 }
        val cells = List(9) { i -> HoneycombCell(card = if (i == 0) opponentFirst else null) }
        // ...and a face-up weak opponent card in cell 4 for the player's strong card to sit beside.
        val weakNeighbour = card(51, CardOwner.Opponent, 1)
        val board = HoneycombBoard(cells = cells.mapIndexed { i, c -> if (i == 4) HoneycombCell(card = weakNeighbour) else c })
        privateFlow<HoneycombState>(vm, "_state").let {
            it.value = it.value.copy(
                activeRules = listOf(HoneycombRule.BombShelter),
                gameState = HoneycombGameState.Playing,
                isPlayerTurn = true,
                board = board,
                playerHand = (1..5).map { id -> card(id, CardOwner.Player, 10) },
                opponentHand = (11..14).map { id -> card(id, CardOwner.Opponent, 1) }
            )
        }

        vm.playerPlayCard(0, 1) // the player's first card: goes face-down beside cell 0 and cell 4
        val st = vm.state.value
        assertEquals(true, st.board.cells[1].card?.isFaceDown)
        assertEquals("Hidden card captured nothing as it landed", CardOwner.Opponent, st.board.cells[4].card?.owner)
        assertEquals(CardOwner.Opponent, st.board.cells[0].card?.owner)
    }
}
