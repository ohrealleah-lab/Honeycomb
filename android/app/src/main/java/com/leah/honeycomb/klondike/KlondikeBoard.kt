package com.leah.honeycomb.klondike

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.leah.honeycomb.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.coroutineScope
import kotlin.math.roundToInt
import androidx.compose.ui.zIndex

data class DragState(
    val cards: List<Card> = emptyList(),
    val sourcePile: Pile? = null,
    val startPosition: Offset = Offset.Zero,
    val offset: Offset = Offset.Zero
)

@Composable
fun KlondikeBoard(
    viewModel: GameViewModel,
    onOptionsTap: () -> Unit,
    onMenuTap: () -> Unit,
    onThemesTap: () -> Unit = {}
) {
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val state by viewModel.state.collectAsState()
    val options by viewModel.options.collectAsState()
    val isStuck by viewModel.isStuck.collectAsState()
    val hintSourceId by viewModel.hintSourceId.collectAsState()
    val hintTargetId by viewModel.hintTargetId.collectAsState()
    val isAutocompleteAvailable by viewModel.isAutocompleteAvailable.collectAsState()
    val pointPopup by viewModel.pointPopup.collectAsState()
    val isStockExhausted by viewModel.isStockExhausted.collectAsState()

    var dragState by remember { mutableStateOf(DragState()) }
    val pileFrames = remember { mutableMapOf<String, Rect>() }

    // A DragGesture has no guaranteed "cancelled" callback if the app is backgrounded
    // mid-drag (home gesture, notification shade, an incoming call) — without this, the
    // floating drag overlay and the hidden source card could be left stuck indefinitely.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                dragState = DragState()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    var showQuitConfirm by remember { mutableStateOf(false) }

    BackHandler(enabled = state.movesCount > 0 && !state.hasWon) {
        showQuitConfirm = true
    }

    if (showQuitConfirm) {
        AlertDialog(
            onDismissRequest = { showQuitConfirm = false },
            title = { Text(com.leah.honeycomb.Strings.get(StringKey.ToolbarQuitMatch, language)) },
            text = { Text(com.leah.honeycomb.Strings.get(StringKey.NewMatchConfirmTitle, language)) },
            confirmButton = {
                TextButton(onClick = {
                    showQuitConfirm = false
                    viewModel.startNewGame()
                }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.QuitButton, language))
                }
            },
            dismissButton = {
                TextButton(onClick = { showQuitConfirm = false }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.Cancel, language))
                }
            }
        )
    }

    Box(modifier = Modifier.fillMaxSize()) {
        com.leah.honeycomb.theme.AppBackground()
        Column(modifier = Modifier.fillMaxSize().padding(8.dp)) {
            // Top Bar
            Row(
                modifier = Modifier.fillMaxWidth().height(48.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row {
                    IconButton(onClick = onMenuTap) {
                        Icon(Icons.Default.Menu, contentDescription = "Menu", tint = Color.White)
                    }
                    IconButton(onClick = onOptionsTap) {
                        Icon(Icons.Default.Settings, contentDescription = "Options", tint = Color.White)
                    }
                    IconButton(onClick = onThemesTap) {
                        Icon(Icons.Default.Palette, contentDescription = "Themes", tint = Color.White)
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (options.isVegasScoring) "BANKROLL" else "SCORE", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f))
                        Text(if (options.isVegasScoring) String.format("$%.2f", state.score / 100.0) else "${state.score}", fontWeight = FontWeight.Bold, color = Color.Yellow)
                    }
                    if (options.isTimed) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("TIME", fontSize = 10.sp, color = Color.White.copy(alpha = 0.7f))
                            val mins = state.timerSeconds / 60
                            val secs = state.timerSeconds % 60
                            Text(String.format("%02d:%02d", mins, secs), fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                }

                Row {
                    IconButton(onClick = { viewModel.findHint() }) {
                        Icon(Icons.Default.Lightbulb, contentDescription = "Hint", tint = Color.White)
                    }
                    IconButton(
                        onClick = { viewModel.undoLastAction() },
                        enabled = viewModel.canUndo
                    ) {
                        Icon(Icons.Default.Undo, contentDescription = "Undo", tint = if (viewModel.canUndo) Color.White else Color.White.copy(alpha=0.3f))
                    }
                    IconButton(onClick = {
                        if (state.movesCount == 0) viewModel.startNewGame()
                        else showQuitConfirm = true
                    }) {
                        Icon(Icons.Default.PlayArrow, contentDescription = "New Game", tint = Color.White)
                    }
                }
            }

            if (hintSourceId != null && hintTargetId != null) {
                Text(
                    "Hint: move from ${hintSourceId} to ${hintTargetId}".replace("_", " "),
                    color = Color.Yellow,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp).clickable { viewModel.clearHint() }
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                val cardWidth = (maxWidth.value - 6 * 6) / 7f
                val cardW = cardWidth.coerceAtMost(110f).dp
                val cardH = cardW * 1.4f

                Column(modifier = Modifier.fillMaxSize()) {
                    // Top Row
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        // Stock
                        Box(modifier = Modifier
                            .size(cardW, cardH)
                            .onGloballyPositioned { pileFrames[state.stock.id] = it.boundsInRoot() }
                            .clip(RoundedCornerShape(4.dp))
                            .clickable { viewModel.drawCard() }
                        ) {
                            Box(modifier = Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.2f)))
                            if (state.stock.cards.isNotEmpty()) {
                                CardView(card = state.stock.cards.last().copy(faceUp = false), modifier = Modifier.size(cardW, cardH))
                            } else if (viewModel.canRecycleStock) {
                                Icon(Icons.Default.Refresh, contentDescription = "Recycle", tint = Color.White.copy(alpha = 0.5f), modifier = Modifier.align(Alignment.Center))
                            }
                        }

                        // Waste
                        Box(modifier = Modifier
                            .size(cardW, cardH)
                            .onGloballyPositioned { pileFrames[state.waste.id] = it.boundsInRoot() }
                        ) {
                            Box(modifier = Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.2f)))
                            val wasteCards = state.waste.cards.takeLast(state.wasteDisplayCount)
                            val fanStep = cardW * 0.16f
                            wasteCards.forEachIndexed { i, card ->
                                val isTop = i == wasteCards.size - 1
                                Box(modifier = Modifier
                                    .offset(x = fanStep * i)
                                    .zIndex(i.toFloat())
                                ) {
                                    if (dragState.cards.any { it.id == card.id }) {
                                        // Hide card if dragged
                                    } else {
                                        var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                        Box(
                                            modifier = Modifier
                                                .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                                // Single pointerInput block: drag and double-tap detection run as two
                                                // coroutines launched inside the SAME PointerInputScope (not two separate
                                                // .pointerInput modifiers, which each independently process the raw
                                                // pointer stream and can race on consumption). onTap is a required no-op
                                                // pairing for onDoubleTap so Compose can locally disambiguate 1-vs-2 taps
                                                // on this node instead of a bare double-tap detector misbehaving.
                                                .pointerInput(card.id) {
                                                    if (isTop) {
                                                        coroutineScope {
                                                            launch {
                                                                detectTapGestures(
                                                                    onTap = {},
                                                                    onDoubleTap = { viewModel.doubleClickMoveToFoundation(card, state.waste) }
                                                                )
                                                            }
                                                            launch {
                                                                detectDragGestures(
                                                                    onDragStart = { _ -> dragState = DragState(listOf(card), state.waste, layoutPos, Offset.Zero) },
                                                                    onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                                    onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel); dragState = DragState() },
                                                                    onDragCancel = { dragState = DragState() }
                                                                )
                                                            }
                                                        }
                                                    }
                                                }
                                        ) {
                                            CardView(card = card, modifier = Modifier.size(cardW, cardH))
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.width(cardW)) // Gap

                        // Foundations
                        state.foundations.forEach { pile ->
                            Box(modifier = Modifier
                                .size(cardW, cardH)
                                .onGloballyPositioned { pileFrames[pile.id] = it.boundsInRoot() }
                            ) {
                                Box(modifier = Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.2f)))
                                val topCard = pile.cards.lastOrNull()
                                if (topCard != null) {
                                    if (dragState.cards.any { it.id == topCard.id }) {
                                        // hidden
                                    } else {
                                        var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                        Box(
                                            modifier = Modifier
                                                .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                                .pointerInput(topCard.id) {
                                                    detectDragGestures(
                                                        onDragStart = { _ -> dragState = DragState(listOf(topCard), pile, layoutPos, Offset.Zero) },
                                                        onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                        onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel); dragState = DragState() },
                                                        onDragCancel = { dragState = DragState() }
                                                    )
                                                }
                                        ) {
                                            CardView(card = topCard, modifier = Modifier.size(cardW, cardH))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Tableau
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        val upStep = cardH * 0.24f
                        val downStep = cardH * 0.12f
                        state.tableau.forEach { pile ->
                            Box(modifier = Modifier
                                .width(cardW)
                                .fillMaxHeight()
                                .onGloballyPositioned { pileFrames[pile.id] = it.boundsInRoot() }
                            ) {
                                Box(modifier = Modifier.size(cardW, cardH).background(Color.Black.copy(alpha = 0.2f)))
                                var runningY = 0.dp
                                pile.cards.forEachIndexed { i, card ->
                                    val currentY = runningY
                                    val stack = pile.cards.subList(i, pile.cards.size)
                                    if (dragState.cards.any { it.id == card.id }) {
                                        // hidden
                                    } else {
                                        var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                        Box(
                                            modifier = Modifier
                                                .offset(y = currentY)
                                                .zIndex(i.toFloat())
                                                .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                                .pointerInput(card.id) {
                                                    if (card.faceUp) {
                                                        coroutineScope {
                                                            launch {
                                                                detectTapGestures(
                                                                    onTap = {},
                                                                    onDoubleTap = { viewModel.doubleClickMoveToFoundation(card, pile) }
                                                                )
                                                            }
                                                            launch {
                                                                detectDragGestures(
                                                                    onDragStart = { _ -> dragState = DragState(stack, pile, layoutPos, Offset.Zero) },
                                                                    onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                                    onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel); dragState = DragState() },
                                                                    onDragCancel = { dragState = DragState() }
                                                                )
                                                            }
                                                        }
                                                    }
                                                }
                                        ) {
                                            CardView(card = card, modifier = Modifier.size(cardW, cardH))
                                        }
                                    }
                                    runningY += if (card.faceUp) upStep else downStep
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Full screen Drag Overlay
        if (dragState.cards.isNotEmpty()) {
            val cardW = ((LocalConfiguration.current.screenWidthDp - 6 * 6 - 16) / 7f).coerceAtMost(110f).dp
            val cardH = cardW * 1.4f
            val upStep = cardH * 0.24f
            Box(modifier = Modifier.fillMaxSize().zIndex(100f)) {
                Box(modifier = Modifier
                    .offset { IntOffset((dragState.startPosition.x + dragState.offset.x).roundToInt(), (dragState.startPosition.y + dragState.offset.y).roundToInt()) }
                ) {
                    dragState.cards.forEachIndexed { i, card ->
                        Box(modifier = Modifier.offset(y = upStep * i)) {
                            CardView(card = card, modifier = Modifier.size(cardW, cardH))
                        }
                    }
                }
            }
        }
        
        // Point Popups
        pointPopup?.let { popup ->
            // Minimal implementation
        }
        
        // Banners
        if (isAutocompleteAvailable && !state.hasWon) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Victory Guaranteed!", color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { viewModel.runAutocomplete() }) { Text("Auto-complete") }
                    }
                }
            }
        }

        if (state.hasWon) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("You Win!", color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 32.sp)
                        Text(if (options.isVegasScoring) "Bankroll: " + String.format("$%.2f", state.score / 100.0) else "Score: ${state.score}")
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.startNewGame() }) { Text("Play Again") }
                    }
                }
            }
        }

        if (isStuck && !state.hasWon) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Game Over", color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 32.sp)
                        Text("No moves remaining")
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.restartCurrentGame() }) { Text(com.leah.honeycomb.Strings.get(StringKey.Restart, language)) }
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { viewModel.startNewGame() }) { Text(com.leah.honeycomb.Strings.get(StringKey.NewGame, language)) }
                    }
                }
            }
        }
    }
}

private fun handleDragEnd(
    dragState: DragState,
    pileFrames: Map<String, Rect>,
    viewModel: GameViewModel
) {
    if (dragState.cards.isEmpty() || dragState.sourcePile == null) return
    val releaseX = dragState.startPosition.x + dragState.offset.x + 50f
    val releaseY = dragState.startPosition.y + dragState.offset.y + 50f

    var dropTarget: Pile? = null
    var bestDist = Float.MAX_VALUE

    // Target Tableau
    for (tab in viewModel.state.value.tableau) {
        val frame = pileFrames[tab.id] ?: continue
        val margin = 50f
        if (releaseX >= frame.left - margin && releaseX <= frame.right + margin && releaseY >= frame.top - margin) {
            val dist = Math.abs(releaseX - frame.center.x)
            val isValid = SmartDrop.resolve(dragState.cards) { viewModel.isValidMove(it, tab) } != null
            if (isValid && dist < bestDist) {
                bestDist = dist
                dropTarget = tab
            }
        }
    }

    if (dropTarget == null) {
        for (f in viewModel.state.value.foundations) {
            val frame = pileFrames[f.id] ?: continue
            val margin = 50f
            if (releaseX >= frame.left - margin && releaseX <= frame.right + margin && releaseY >= frame.top - margin && releaseY <= frame.bottom + margin) {
                val dx = releaseX - frame.center.x
                val dy = releaseY - frame.center.y
                val dist = Math.sqrt((dx*dx + dy*dy).toDouble()).toFloat()
                val isValid = SmartDrop.resolve(dragState.cards) { viewModel.isValidMove(it, f) } != null
                if (isValid && dist < bestDist) {
                    bestDist = dist
                    dropTarget = f
                }
            }
        }
    }

    if (dropTarget != null) {
        val resolved = SmartDrop.resolve(dragState.cards) { viewModel.isValidMove(it, dropTarget!!) }
        if (resolved != null) {
            viewModel.moveCards(resolved, dragState.sourcePile, dropTarget)
        }
    }
}
