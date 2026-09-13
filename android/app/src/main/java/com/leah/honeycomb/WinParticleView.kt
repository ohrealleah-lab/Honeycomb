package com.leah.honeycomb

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.random.Random

/// Radial confetti burst for a big win — ported from ios/Honeycomb/Views/WinParticleView.swift,
/// cross-checked against windows/src/SoliBee.Desktop/Views/WinParticleSystem.cs (the original
/// non-Apple port this was retimed to match: 72 particles, ~1.4s total burst). The animation
/// itself follows Windows' architecture (a single frame-clock-driven physics sim — radial launch
/// velocity decaying under drag+gravity, linear opacity fade over the full duration) rather than
/// iOS's two-stage SwiftUI `.animation` (spread, then fade) since that's the idiom
/// WinAnimationView.kt (the bouncing-card cascade already ported here) already uses on Android.
///
/// Rendering is a single Canvas drawing all particles imperatively via DrawScope primitives
/// (drawRoundRect/drawCircle/drawPath with translate+rotate+scale) rather than one Box+Canvas+
/// graphicsLayer composable per particle — 72 live recomposing composables per animation frame
/// was measurable overhead (each paying its own measure/layout/draw pass) for no benefit, since
/// nothing about a particle needs to be individually addressable as a composable; a plain draw
/// call inside one Canvas block is the cheaper way to paint 72 small shapes every frame. This
/// also drops the earlier per-particle Modifier.blur() on "background" particles (live
/// RenderEffect blur recomputed every frame on ~36 particles simultaneously is a real cost on
/// lower-end devices) in favor of a lower alpha for the same particles — a cheaper way to read
/// as "further away" without the live blur recompute; approximates rather than exactly
/// reproduces iOS's blurred look.

private enum class ParticleShape { RECTANGLE, CIRCLE, RIBBON, STAR }

private data class WinParticle(
    val shape: ParticleShape,
    val color: Color,
    val scale: Float,
    val depthAlpha: Float,
    var x: Float,
    var y: Float,
    var vx: Float,
    var vy: Float,
    var rotationDeg: Float,
    val rotationSpeed: Float
)

// Matches iOS's WinParticleView palette (yellow / orange / white / cyan / gold) rather than
// Windows' richer 8-color palette — the task calls for a palette "matching iOS's" specifically,
// unlike particle count/timing where Windows' numbers were taken as authoritative.
private val particleColors = listOf(
    Color(0xFFFFD60A), // yellow
    Color(0xFFFF9500), // orange
    Color.White,
    Color(0xFF32ADE6), // cyan
    Color(0xFFFFD700)  // gold
)

private const val PARTICLE_COUNT = 72
private const val TOTAL_MS = 1400f
// Windows steps its sim on a fixed 16ms DispatcherTimer tick; velocities/gravity below are
// expressed in "units per tick" like WinParticleSystem.cs, then scaled by tickFraction each real
// frame so the result matches regardless of device frame rate.
private const val TICK_MS = 16f

private fun burst(cx: Float, cy: Float): List<WinParticle> =
    (0 until PARTICLE_COUNT).map {
        val angle = Random.nextFloat() * (Math.PI * 2).toFloat()
        val isBackground = Random.nextFloat() > 0.5f
        val speedMultiplier = if (isBackground) 0.8f else 1f
        val speed = (Random.nextFloat() * 7f + 3f) * speedMultiplier
        val baseScale = Random.nextFloat() * 1f + 0.6f
        val scale = baseScale * if (isBackground) 0.7f else 1f
        // Stands in for the old per-particle blur on background particles — cheaper (no live
        // RenderEffect recompute), same "further away/softer" read via lower opacity instead.
        val depthAlpha = if (isBackground) 0.6f else 1f
        // Same 40/20/20/20 rectangle/circle/ribbon/star split as both Windows (rng.Next(5), 0-1
        // -> rectangle) and iOS ([.rectangle, .rectangle, .circle, .thinRibbon, .star]).
        val shape = when (Random.nextInt(5)) {
            0, 1 -> ParticleShape.RECTANGLE
            2 -> ParticleShape.CIRCLE
            3 -> ParticleShape.RIBBON
            else -> ParticleShape.STAR
        }
        WinParticle(
            shape = shape,
            color = particleColors.random(),
            scale = scale,
            depthAlpha = depthAlpha,
            x = cx,
            y = cy,
            vx = cos(angle) * speed,
            vy = sin(angle) * speed - 2.5f, // slight upward bias, matches Windows
            rotationDeg = angle * 180f / Math.PI.toFloat(),
            rotationSpeed = Random.nextFloat() * 20f - 10f
        )
    }

/**
 * Radial confetti burst overlay. Call with [active] flipped true→false→true (mirroring the
 * *TouchView pattern on iOS: `showParticles = true` then cleared ~0.8s later) to fire a burst —
 * only the rising edge matters, the burst always runs to completion once started.
 */
@Composable
fun WinParticleView(active: Boolean) {
    var screenSize by remember { mutableStateOf(IntSize.Zero) }
    val particles = remember { mutableListOf<WinParticle>() }
    var elapsedMs by remember { mutableFloatStateOf(0f) }
    var isBursting by remember { mutableStateOf(false) }
    val density = LocalDensity.current

    // Deliberately NOT `LaunchedEffect(active)` — that would restart (and cancel) this
    // coroutine on every change of `active`, including the caller flipping it back to
    // false ~0.8s after triggering the burst (see *Board.kt's showParticles timers),
    // well before the burst's own 1400ms physics loop finishes. That cancellation is
    // exactly what froze particles mid-flight and skipped the isBursting=false cleanup
    // below. A single long-lived effect observing only the rising edge (via
    // snapshotFlow.collect, which processes emissions one at a time) lets the falling
    // edge arrive as a no-op instead of tearing down the still-running burst.
    LaunchedEffect(Unit) {
        snapshotFlow { active }.collect { isActive ->
            if (!isActive || screenSize == IntSize.Zero) return@collect

            particles.clear()
            particles.addAll(burst(screenSize.width / 2f, screenSize.height / 2f))
            elapsedMs = 0f
            isBursting = true

            var lastFrame = 0L
            while (elapsedMs < TOTAL_MS) {
                withFrameNanos { frameTime ->
                    if (lastFrame == 0L) lastFrame = frameTime
                    val dtSeconds = ((frameTime - lastFrame) / 1_000_000_000f).coerceAtMost(1f / 30f)
                    lastFrame = frameTime
                    elapsedMs += dtSeconds * 1000f

                    val tickFraction = (dtSeconds * 1000f) / TICK_MS
                    val drag = 0.97f.pow(tickFraction)
                    for (p in particles) {
                        p.vx *= drag
                        p.vy = p.vy * drag + 0.4f * tickFraction
                        p.x += p.vx * tickFraction
                        p.y += p.vy * tickFraction
                        p.rotationDeg += p.rotationSpeed * tickFraction
                    }
                }
            }

            particles.clear()
            isBursting = false
        }
    }

    Canvas(
        modifier = Modifier
            .fillMaxSize()
            .onSizeChanged { screenSize = it }
    ) {
        if (!isBursting) return@Canvas
        val life = (1f - elapsedMs / TOTAL_MS).coerceIn(0f, 1f)
        for (p in particles) {
            val (widthPx, heightPx) = particleSizePx(p.shape, p.scale, density)
            translate(p.x, p.y) {
                rotate(p.rotationDeg, pivot = Offset.Zero) {
                    drawParticleShape(p.shape, p.color, widthPx, heightPx, alpha = life * p.depthAlpha)
                }
            }
        }
    }
}

private fun particleSizePx(shape: ParticleShape, scale: Float, density: androidx.compose.ui.unit.Density): Pair<Float, Float> {
    val (widthDp, heightDp) = when (shape) {
        ParticleShape.RECTANGLE -> (10.dp * scale) to (4.dp * scale)
        ParticleShape.CIRCLE -> (6.dp * scale) to (6.dp * scale)
        ParticleShape.RIBBON -> (14.dp * scale) to (2.dp * scale)
        ParticleShape.STAR -> (10.dp * scale) to (10.dp * scale)
    }
    return with(density) { widthDp.toPx() to heightDp.toPx() }
}

// Draws one particle centered on the DrawScope's current (translated+rotated) origin.
private fun DrawScope.drawParticleShape(shape: ParticleShape, color: Color, widthPx: Float, heightPx: Float, alpha: Float) {
    val topLeft = Offset(-widthPx / 2f, -heightPx / 2f)
    val size = Size(widthPx, heightPx)
    when (shape) {
        ParticleShape.RECTANGLE, ParticleShape.RIBBON -> drawRoundRect(
            color = color,
            topLeft = topLeft,
            size = size,
            cornerRadius = CornerRadius(size.minDimension * 0.25f),
            alpha = alpha
        )
        ParticleShape.CIRCLE -> drawCircle(
            color = color,
            radius = size.minDimension / 2f,
            center = Offset.Zero,
            alpha = alpha
        )
        ParticleShape.STAR -> drawPath(path = starPath(size, topLeft), color = color, alpha = alpha)
    }
}

// Same 10x10 star geometry as Windows' WinParticleSystem.cs (Geometry.Parse(...)), scaled to fill
// the particle's own size and offset so it's centered on the DrawScope's current origin.
private fun starPath(size: Size, topLeft: Offset): Path {
    val sx = size.width / 10f
    val sy = size.height / 10f
    val points = listOf(
        5f to 0f, 6.5f to 3.5f, 10f to 3.5f, 7f to 5.5f, 8.5f to 9.5f,
        5f to 7f, 1.5f to 9.5f, 3f to 5.5f, 0f to 3.5f, 3.5f to 3.5f
    )
    return Path().apply {
        points.forEachIndexed { i, (px, py) ->
            val x = topLeft.x + px * sx
            val y = topLeft.y + py * sy
            if (i == 0) moveTo(x, y) else lineTo(x, y)
        }
        close()
    }
}
