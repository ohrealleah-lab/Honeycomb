package com.leah.honeycomb

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.UUID

class GameTimer(private val scope: CoroutineScope) {
    private var job: Job? = null

    fun start(checkActive: () -> Boolean, onSetActive: (Boolean) -> Unit, tick: () -> Unit) {
        if (checkActive()) return
        onSetActive(true)
        job = scope.launch {
            while (isActive && checkActive()) {
                delay(1000)
                tick()
            }
        }
    }

    fun stop(onSetActive: (Boolean) -> Unit) {
        job?.cancel()
        job = null
        onSetActive(false)
    }
}

object SmartDrop {
    fun resolve(cards: List<Card>, isValidMove: (List<Card>) -> Boolean): List<Card>? {
        if (cards.isEmpty()) return null
        for (start in cards.indices) {
            val suffix = cards.subList(start, cards.size)
            if (isValidMove(suffix)) {
                return suffix
            }
        }
        return null
    }
}

object WinDetection {
    fun hasWon(foundationCardCount: Int, totalCards: Int, alreadyWon: Boolean): Boolean {
        return foundationCardCount == totalCards && !alreadyWon
    }
}

data class CardPointPopup(
    val cardId: UUID,
    val displayText: String,
    val isPositive: Boolean
)
