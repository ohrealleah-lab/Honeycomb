package com.leah.honeycomb

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.spring
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
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

// A boolean trigger that, once fired, always completes its own show-then-hide cycle —
// immune to the caller's own LaunchedEffect/recomposition churn cancelling it partway
// through. Fixes a recurring bug class found (and separately patched) twice: a
// `var showX by remember { mutableStateOf(false) }; LaunchedEffect(unrelatedKeys) {
// showX = true; delay(N); showX = false }` pattern gets cancelled — and, without an
// `else` branch, left stuck permanently true — whenever any of unrelatedKeys changes
// again mid-delay (see WinParticleView.kt's own burst coroutine, and
// VideoPokerBoard.kt's winFlash/showParticles, both hit this independently).
//
// Call fire() imperatively from wherever the trigger condition is detected, instead of
// keying a LaunchedEffect on that condition directly — the hold-then-reset here runs in
// its own CoroutineScope (this instance's own, from rememberCoroutineScope, not the
// caller's LaunchedEffect), guarded by its own generation counter, so nothing about the
// caller's recomposition can interrupt or duplicate it. A caller's own LaunchedEffect
// being cancelled before it even calls fire() is safe too — active just never becomes
// true, rather than getting stuck.
class FireOnceTrigger internal constructor(
    private val scope: CoroutineScope,
    private val holdMs: Long
) {
    var active by mutableStateOf(false)
        private set

    private var generation = 0

    fun fire() {
        val myGeneration = ++generation
        active = true
        scope.launch {
            delay(holdMs)
            if (generation == myGeneration) active = false
        }
    }
}

@Composable
fun rememberFireOnceTrigger(holdMs: Long): FireOnceTrigger {
    val scope = rememberCoroutineScope()
    return remember { FireOnceTrigger(scope, holdMs) }
}

// Shared drag-drop settle-spring mechanism for Klondike/Beecell/Spider's floating drag
// overlay (matches iOS/mac's withAnimation(.spring(response: 0.25, dampingFraction: 0.8))
// around moveCards) — was previously duplicated near-verbatim (including the exact spring
// constants) across all three boards' own performDragEnd functions.
//
// Purely cosmetic: `settle`'s `commit` lambda runs synchronously, before any animation
// starts, so the move itself never depends on this class's coroutine surviving — only the
// overlay's hand-off animation does. A generation counter (bumped by both beginDrag() and
// settle()) guards the animation's completion callback against being clobbered by, or
// clobbering, an overlapping second drag — see KlondikeBoard.kt's original comment on this
// for the failure mode it prevents.
class DragSettle(private val scope: CoroutineScope) {
    private val settleOffset = Animatable(Offset.Zero, Offset.VectorConverter)
    var isSettling by mutableStateOf(false)
        private set
    private var generation = 0

    // Call from each onDragStart site, before adopting the new drag's own state —
    // invalidates any settle animation still in flight so its later completion can't
    // reset isSettling/fire onSettled for a drag that isn't the current one anymore.
    fun beginDrag() {
        generation++
        isSettling = false
    }

    // `commit()` performs the actual model mutation and returns whether it succeeded.
    // If it fails, or `landing` is null (no destination frame measured yet), `onSettled()`
    // fires immediately with no animation — same as the old per-board fallback path.
    // Otherwise the overlay animates from `start` to `landing`, then `onSettled()` fires
    // once that finishes, unless a newer drag has begun in the meantime.
    fun settle(start: Offset, landing: Offset?, commit: () -> Boolean, onSettled: () -> Unit) {
        val committed = commit()
        if (!committed || landing == null) {
            onSettled()
            return
        }
        val myGeneration = ++generation
        isSettling = true
        scope.launch {
            settleOffset.snapTo(start)
            settleOffset.animateTo(landing, spring(dampingRatio = 0.8f, stiffness = 630f))
            if (generation == myGeneration) {
                isSettling = false
                onSettled()
            }
        }
    }

    // What the floating overlay should render at: the live drag position while dragging,
    // or the settle animation's current position once the finger has lifted and the
    // overlay is animating toward its resting slot.
    fun displayOffset(rawDragOffset: Offset): Offset = if (isSettling) settleOffset.value else rawDragOffset
}

@Composable
fun rememberDragSettle(): DragSettle {
    val scope = rememberCoroutineScope()
    return remember { DragSettle(scope) }
}
