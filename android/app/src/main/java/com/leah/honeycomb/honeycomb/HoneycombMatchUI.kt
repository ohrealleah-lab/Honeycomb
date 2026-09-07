package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import kotlin.math.roundToInt

data class DragInfo(
    val index: Int,
    val card: HoneycombCard,
    val initialPosition: Offset,
    val size: IntSize
)

@Composable
fun HoneycombMatchUI(viewModel: HoneycombViewModel, onMenuTap: () -> Unit) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(Unit) {
        if (state.gameState == HoneycombGameState.Setup) {
            viewModel.startNewGame()
        }
    }

    var draggedCardInfo by remember { mutableStateOf<DragInfo?>(null) }
    var dragOffset by remember { mutableStateOf(Offset.Zero) }
    val dropTargets = remember { mutableStateMapOf<Int, Rect>() }

    // A DragGesture has no guaranteed "cancelled" callback if the app is backgrounded
    // mid-drag — without this, a dragged card could be left stuck floating indefinitely.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                draggedCardInfo = null
                dragOffset = Offset.Zero
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        com.leah.honeycomb.theme.AppBackground()
        
        Column(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // 1. Top Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                IconButton(onClick = onMenuTap) { 
                    Icon(Icons.Default.Menu, contentDescription = "Menu") 
                }
                
                val playerScore = state.board.playerScore + state.playerHand.size
                val opponentScore = state.board.opponentScore + state.opponentHand.size
                
                Text(
                    text = "Opponent: $opponentScore | You: $playerScore", 
                    style = MaterialTheme.typography.titleLarge
                )
                
                // Placeholder to balance the Row
                Spacer(modifier = Modifier.width(48.dp))
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 2. Opponent Hand
            Row(
                modifier = Modifier.fillMaxWidth().height(100.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                state.opponentHand.forEach { card ->
                    HoneycombCardView(
                        card = card,
                        isFlipped = !state.openOpponentCardIds.contains(card.data.id.toString()),
                        modifier = Modifier
                            .padding(4.dp)
                            .aspectRatio(0.7f)
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // 3. Board
            Column(modifier = Modifier.wrapContentSize()) {
                for (row in 0 until 3) {
                    Row {
                        for (col in 0 until 3) {
                            val index = row * 3 + col
                            val cell = state.board.cells[index]
                            
                            Box(
                                modifier = Modifier
                                    .size(100.dp)
                                    .padding(4.dp)
                                    .background(Color.Black.copy(alpha = 0.2f))
                                    .onGloballyPositioned { coords ->
                                        dropTargets[index] = coords.boundsInRoot()
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                val c = cell.card
                                if (c != null) {
                                    HoneycombCardView(
                                        card = c,
                                        isFlipped = false,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                }
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // 4. Player Hand
            Row(
                modifier = Modifier.fillMaxWidth().height(120.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                state.playerHand.forEachIndexed { index, card ->
                    var cardPosition by remember { mutableStateOf(Offset.Zero) }
                    var cardSize by remember { mutableStateOf(IntSize.Zero) }

                    Box(
                        modifier = Modifier
                            .padding(4.dp)
                            .aspectRatio(0.7f)
                            .onGloballyPositioned { coords ->
                                cardPosition = coords.positionInRoot()
                                cardSize = coords.size
                            }
                            .pointerInput(card, state.isPlayerTurn, state.mandatedPlayerHandIndex) {
                                detectDragGestures(
                                    onDragStart = { _ ->
                                        if (state.isPlayerTurn && (state.mandatedPlayerHandIndex == null || state.mandatedPlayerHandIndex == index)) {
                                            draggedCardInfo = DragInfo(index, card, cardPosition, cardSize)
                                            dragOffset = Offset.Zero
                                        }
                                    },
                                    onDrag = { change, dragAmount ->
                                        change.consume()
                                        dragOffset += dragAmount
                                    },
                                    onDragEnd = {
                                        draggedCardInfo?.let { info ->
                                            val currentCenter = info.initialPosition + dragOffset + Offset(info.size.width / 2f, info.size.height / 2f)
                                            val targetIndex = dropTargets.entries.firstOrNull { it.value.contains(currentCenter) }?.key
                                            
                                            if (targetIndex != null && state.board.cells[targetIndex].card == null) {
                                                viewModel.playerPlayCard(info.index, targetIndex)
                                            }
                                        }
                                        draggedCardInfo = null
                                        dragOffset = Offset.Zero
                                    },
                                    onDragCancel = {
                                        draggedCardInfo = null
                                        dragOffset = Offset.Zero
                                    }
                                )
                            }
                    ) {
                        if (draggedCardInfo?.index != index) {
                            HoneycombCardView(
                                card = card,
                                isFlipped = false,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }

        // Overlay for dragged card
        draggedCardInfo?.let { info ->
            Box(
                modifier = Modifier
                    .offset { 
                        IntOffset(
                            (info.initialPosition.x + dragOffset.x).roundToInt(),
                            (info.initialPosition.y + dragOffset.y).roundToInt()
                        )
                    }
                    .size(
                        with(LocalDensity.current) { info.size.width.toDp() },
                        with(LocalDensity.current) { info.size.height.toDp() }
                    )
            ) {
                HoneycombCardView(
                    card = info.card,
                    isFlipped = false,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}
