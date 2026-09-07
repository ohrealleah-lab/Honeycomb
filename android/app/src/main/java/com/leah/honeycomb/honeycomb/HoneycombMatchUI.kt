package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Redo
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material.icons.filled.Style
import androidx.compose.material.icons.filled.Hexagon
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.leah.honeycomb.StringKey
import kotlin.math.roundToInt

data class DragInfo(
    val index: Int,
    val card: HoneycombCard,
    val initialPosition: Offset,
    val size: IntSize
)

@Composable
fun HoneycombMatchUI(
    viewModel: HoneycombViewModel,
    onMenuTap: () -> Unit,
    onOptionsTap: () -> Unit = {},
    onThemesTap: () -> Unit = {},
    onManageDecksTap: () -> Unit = {},
    onRulesTap: () -> Unit = {}
) {
    val state by viewModel.state.collectAsState()
    val options by viewModel.options.collectAsState()
    val hintMove by viewModel.hintMove.collectAsState()
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val hideHintButton by com.leah.honeycomb.LocalAppContainer.current.sharedOptions.hideHintButton.collectAsState()

    val isMidMatch = state.gameState == HoneycombGameState.Playing || state.gameState == HoneycombGameState.SuddenDeath

    var showQuitConfirm by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler(enabled = isMidMatch) { showQuitConfirm = true }

    if (showQuitConfirm) {
        AlertDialog(
            onDismissRequest = { showQuitConfirm = false },
            title = { Text(com.leah.honeycomb.Strings.get(StringKey.ToolbarQuitMatch, language)) },
            text = { Text(com.leah.honeycomb.Strings.get(StringKey.NewMatchConfirmTitle, language)) },
            confirmButton = {
                TextButton(onClick = {
                    showQuitConfirm = false
                    viewModel.quitMatch()
                }) { Text(com.leah.honeycomb.Strings.get(StringKey.QuitButton, language)) }
            },
            dismissButton = {
                TextButton(onClick = { showQuitConfirm = false }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.Cancel, language))
                }
            }
        )
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
            // 1. Top Bar — leading cluster (Menu/Options/Themes always; Manage Decks/
            // Rules pre- and post-match only, matching iOS's isMidMatch gating) and a
            // trailing cluster (Undo/Hint/Quit mid-match, or Rematch/Start otherwise).
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onMenuTap) {
                        Icon(Icons.Default.Menu, contentDescription = "Menu")
                    }
                    IconButton(onClick = onOptionsTap) {
                        Icon(Icons.Default.Settings, contentDescription = "Options")
                    }
                    IconButton(onClick = onThemesTap) {
                        Icon(Icons.Default.Palette, contentDescription = "Themes")
                    }
                    if (!isMidMatch) {
                        IconButton(onClick = onManageDecksTap) {
                            Icon(Icons.Default.Style, contentDescription = "Manage Decks")
                        }
                        IconButton(onClick = onRulesTap) {
                            Icon(Icons.Default.Hexagon, contentDescription = "Rules")
                        }
                    }
                }

                if (isMidMatch) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = { viewModel.undoLastAction() }, enabled = viewModel.canUndo) {
                            Icon(Icons.Default.Undo, contentDescription = "Undo")
                        }
                        if (!hideHintButton && options.difficulty != HoneycombDifficulty.UltraHard && state.isPlayerTurn) {
                            IconButton(onClick = { viewModel.findHint() }) {
                                Icon(Icons.Default.Lightbulb, contentDescription = "Hint")
                            }
                        }
                        TextButton(onClick = { showQuitConfirm = true }) {
                            Text(com.leah.honeycomb.Strings.get(StringKey.QuitButton, language), color = Color.White)
                        }
                    }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (state.gameState == HoneycombGameState.GameOver && viewModel.canRematch) {
                            IconButton(onClick = { viewModel.rematch() }) {
                                Icon(Icons.Default.Redo, contentDescription = "Rematch")
                            }
                        }
                        Button(onClick = { viewModel.startNewGame() }) {
                            Icon(Icons.Default.PlayArrow, contentDescription = null)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(com.leah.honeycomb.Strings.get(StringKey.StartButton, language))
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            val playerScore = state.board.playerScore + state.playerHand.size
            val opponentScore = state.board.opponentScore + state.opponentHand.size
            Text(
                text = "Opponent: $opponentScore | You: $playerScore",
                style = MaterialTheme.typography.titleLarge
            )

            Spacer(modifier = Modifier.height(16.dp))

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
                                    .let {
                                        if (hintMove?.second == index) it.border(2.dp, Color.Yellow) else it
                                    }
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
                            .let {
                                if (hintMove?.first == index) it.border(2.dp, Color.Yellow) else it
                            }
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

        if (state.showSuddenDeathBanner) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.5f))
                    .zIndex(300f),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Sudden Death!",
                    color = Color.Yellow,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold
                )
            }
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
