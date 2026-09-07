package com.leah.honeycomb

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.random.Random
import androidx.compose.ui.graphics.layer.GraphicsLayer

data class BouncingCard(
    val id: String,
    val card: Card,
    var x: Float,
    var y: Float,
    var vx: Float,
    var vy: Float,
    val trail: MutableList<Offset> = mutableListOf(),
    var age: Float = 0f
)

@Composable
fun WinAnimationView(
    foundations: List<Pile>,
    pileFrames: Map<String, Rect>,
    zoomScale: Float = 1f,
    onFinished: () -> Unit
) {
    var activeCards by remember { mutableStateOf(listOf<BouncingCard>()) }
    var cardsQueue by remember { mutableStateOf(listOf<Card>()) }
    var lastFrameTime by remember { mutableLongStateOf(0L) }
    var lastSpawnTime by remember { mutableLongStateOf(System.currentTimeMillis()) }
    var screenSize by remember { mutableStateOf(IntSize.Zero) }

    val maxCardLifetime = 15f
    
    // We only need to cache each unique card in the foundations.
    val allCards = remember(foundations) { foundations.flatMap { it.cards } }

    LaunchedEffect(foundations) {
        val queue = mutableListOf<Card>()
        for (foundation in foundations) {
            for (rank in 13 downTo 1) {
                foundation.cards.find { it.rank == rank }?.let { queue.add(it) }
            }
        }
        cardsQueue = queue
        lastFrameTime = System.nanoTime()
        lastSpawnTime = System.currentTimeMillis()
    }

    LaunchedEffect(screenSize) {
        if (screenSize == IntSize.Zero) return@LaunchedEffect
        while (true) {
            withFrameNanos { frameTime ->
                if (lastFrameTime == 0L) lastFrameTime = frameTime
                val dt = minOf((frameTime - lastFrameTime) / 1_000_000_000f, 1f / 30f)
                lastFrameTime = frameTime

                val now = System.currentTimeMillis()
                val spawnIntervalMs = if (foundations.size > 4) 450L else 900L
                val maxActiveCards = if (foundations.size > 4) 40 else 20

                var nextQueue = cardsQueue.toMutableList()
                val newActive = mutableListOf<BouncingCard>()

                if (now - lastSpawnTime >= spawnIntervalMs && activeCards.size < maxActiveCards) {
                    val card = nextQueue.firstOrNull()
                    if (card != null) {
                        nextQueue.removeAt(0)
                        val pid = foundations.firstOrNull { it.cards.any { c -> c.id == card.id } }?.id ?: ""
                        val frame = pileFrames[pid] ?: Rect(screenSize.width / 2f, screenSize.height / 2f, screenSize.width / 2f, screenSize.height / 2f)

                        val vx = Random.nextFloat() * 600f - 300f
                        val vy = Random.nextFloat() * 300f - 500f

                        newActive.add(BouncingCard(card.id.toString(), card, frame.left, frame.top, vx, vy))
                        lastSpawnTime = now
                    }
                }

                val gravity = 1500f
                val leftLimit = -200f
                val rightLimit = screenSize.width + 200f

                for (c in activeCards) {
                    c.age += dt
                    c.trail.add(Offset(c.x, c.y))
                    if (c.trail.size > 50) c.trail.removeAt(0)

                    c.vy += gravity * dt
                    c.x += c.vx * dt
                    c.y += c.vy * dt

                    if (c.y > screenSize.height) {
                        c.y = screenSize.height.toFloat()
                        c.vy = -c.vy * 0.82f
                        c.vx *= 0.97f
                    }

                    if (c.age > maxCardLifetime || c.x < leftLimit || c.x > rightLimit) {
                        continue
                    }
                    newActive.add(c)
                }

                activeCards = newActive
                cardsQueue = nextQueue

                if (newActive.isEmpty() && nextQueue.isEmpty() && lastFrameTime != 0L) {
                    onFinished()
                }
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize().onSizeChanged { screenSize = it }) {
        // Offscreen renderer for GraphicsLayers
        val layers = remember { mutableMapOf<String, GraphicsLayer>() }
        
        for (card in allCards) {
            val layer = key(card.id) { rememberGraphicsLayer() }
            layers[card.id.toString()] = layer
            
            Box(
                modifier = Modifier
                    .offset(x = (-1000).dp) // Hide offscreen
                    .size(CardDimensions.width * zoomScale, CardDimensions.height * zoomScale)
                    .drawWithContent {
                        layer.record {
                            this@drawWithContent.drawContent()
                        }
                    }
            ) {
                CardView(card = card, modifier = Modifier.fillMaxSize())
            }
        }

        Canvas(modifier = Modifier.fillMaxSize()) {
            for (c in activeCards) {
                val layer = layers[c.id.toString()]
                if (layer != null) {
                    for (point in c.trail) {
                        translate(point.x, point.y) { drawLayer(layer) }
                    }
                    translate(c.x, c.y) { drawLayer(layer) }
                }
            }
        }
    }
}
