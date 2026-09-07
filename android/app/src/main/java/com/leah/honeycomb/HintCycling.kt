package com.leah.honeycomb

// Ported from shared/ViewModels/HintCycling.swift — shared "cycle through a queue of
// hints, or generate a fresh one" logic used identically by Klondike, Beecell, and
// Spider's findHint(). Swift's version mutates `inout` state in place; Kotlin has no
// direct equivalent, so this returns a new HintCycleState instead — callers replace
// their held state with the result. scheduleClear() is left to the caller (called right
// after this returns) rather than threaded through as a callback param, since there's no
// need for it to live inside this otherwise-pure function.
data class HintCycleState<Move>(
    val activeHint: Move? = null,
    val hintQueue: List<Move> = emptyList(),
    val hintQueueIndex: Int = 0
)

object HintCycling {
    fun <Move> findHint(
        current: HintCycleState<Move>,
        collectHints: () -> List<Move>,
        label: (hint: Move, index: Int, total: Int) -> Move,
        noHintFallback: () -> Move
    ): HintCycleState<Move> {
        // Cycle through the existing queue if a hint is still visible.
        if (current.hintQueue.isNotEmpty() && current.activeHint != null) {
            val newIndex = (current.hintQueueIndex + 1) % current.hintQueue.size
            return current.copy(
                activeHint = label(current.hintQueue[newIndex], newIndex, current.hintQueue.size),
                hintQueueIndex = newIndex
            )
        }

        val queue = collectHints()
        if (queue.isEmpty()) {
            return HintCycleState(activeHint = noHintFallback(), hintQueue = emptyList(), hintQueueIndex = 0)
        }

        return HintCycleState(activeHint = label(queue[0], 0, queue.size), hintQueue = queue, hintQueueIndex = 0)
    }
}
