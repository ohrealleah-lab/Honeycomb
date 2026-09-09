package com.leah.honeycomb.klondike

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
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

// Vegas score is stored in cents. Formats it as "-$52.00" (sign before the $, not
// "$-52.00") with thousands grouping — matches KlondikeStatsScreen's Bankroll/High
// Score formatting, which this HUD/win-dialog display had drifted from.
private fun formatVegasCurrency(scoreCents: Int): String {
    val sign = if (scoreCents < 0) "-" else ""
    return String.format(java.util.Locale.US, "%s$%,.2f", sign, Math.abs(scoreCents) / 100.0)
}

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
    val activeHint by viewModel.activeHint.collectAsState()
    val hintSourceId = activeHint?.sourcePileId
    val hintTargetId = activeHint?.targetPileId
    val isAutocompleteAvailable by viewModel.isAutocompleteAvailable.collectAsState()
    val pointPopup by viewModel.pointPopup.collectAsState()
    val isStockExhausted by viewModel.isStockExhausted.collectAsState()
    val noStressMode by viewModel.sharedOptions.noStressMode.collectAsState()

    var dragState by remember { mutableStateOf(DragState()) }
    var lastStockTapTime by remember { mutableStateOf(0L) }
    val haptics = LocalHapticFeedback.current
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

    var activeCardW by remember { mutableStateOf(0.dp) }
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
        
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val isLandscape = maxWidth > maxHeight
            
            val scoreCapsule = @Composable {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(24.dp),
                    modifier = Modifier
                        .background(Color.Black.copy(alpha = 0.4f), CircleShape)
                        .padding(horizontal = 24.dp, vertical = 8.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (options.isVegasScoring) "BANKROLL" else "SCORE", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                        Text(if (options.isVegasScoring) formatVegasCurrency(state.score) else "${state.score}", fontWeight = FontWeight.Bold, color = Color.Yellow)
                    }
                    if (!noStressMode) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("TIME", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                            Text(com.leah.honeycomb.formatSeconds(state.timerSeconds, zeroPlaceholder = "00:00"), fontWeight = FontWeight.Bold, color = Color.White)
                        }
                    }
                }
            }
            
            Column(modifier = Modifier.fillMaxSize().padding(8.dp)) {
                // Top Bar
                Box(modifier = Modifier.fillMaxWidth().height(48.dp)) {
                    Row(
                        modifier = Modifier.fillMaxSize(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row {
                            IconButton(onClick = onMenuTap) {
                                Icon(Icons.Default.GridView, contentDescription = "Menu", tint = Color.White)
                            }
                            IconButton(onClick = onOptionsTap) {
                                Icon(Icons.Default.Settings, contentDescription = "Options", tint = Color.White)
                            }
                            IconButton(onClick = onThemesTap) {
                                Icon(Icons.Default.Palette, contentDescription = "Themes", tint = Color.White)
                            }
                        }

                        Spacer(modifier = Modifier.weight(1f))

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(
                                onClick = { viewModel.undoLastAction() },
                                enabled = viewModel.canUndo
                            ) {
                                Icon(Icons.AutoMirrored.Filled.Undo, contentDescription = "Undo", tint = if (viewModel.canUndo) Color.White else Color.White.copy(alpha=0.3f))
                            }
                            IconButton(onClick = { viewModel.findHint() }) {
                                Icon(Icons.Default.Lightbulb, contentDescription = "Hint", tint = Color.White)
                            }
                            Spacer(modifier = Modifier.width(4.dp))
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .background(Color(0xFF2196F3), CircleShape)
                                    .clickable {
                                        if (state.movesCount == 0) viewModel.startNewGame()
                                        else showQuitConfirm = true
                                    }
                                    .padding(horizontal = 12.dp, vertical = 6.dp)
                            ) {
                                Icon(Icons.Default.PlayArrow, contentDescription = "New", tint = Color.White, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("New", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                            }
                        }
                    }
                    
                    if (isLandscape) {
                        Box(modifier = Modifier.align(Alignment.Center)) {
                            scoreCapsule()
                        }
                    }
                }
                
                if (!isLandscape) {
                    Box(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                        scoreCapsule()
                    }
                }

            Spacer(modifier = Modifier.height(16.dp))

            BoxWithConstraints(modifier = Modifier.weight(1f).fillMaxWidth()) {
                val widthCardW = (maxWidth.value - 6 * 6) / 7f
                val baseCardW = widthCardW.coerceAtMost(110f)
                val baseCardH = baseCardW * 1.4f
                
                val upStepTest = baseCardH * 0.24f
                val downStepTest = baseCardH * 0.12f
                val deepestTableau = state.tableau.maxOfOrNull { pile ->
                    if (pile.cards.isEmpty()) return@maxOfOrNull baseCardH
                    var running = 0f
                    for (i in 0 until pile.cards.size - 1) {
                        running += if (pile.cards[i].faceUp) upStepTest else downStepTest
                    }
                    running + baseCardH
                } ?: baseCardH
                
                val neededHeight = baseCardH + 16f + deepestTableau + 20f
                val heightShrink = if (neededHeight > maxHeight.value) maxHeight.value / neededHeight else 1.0f
                
                val cardW = (baseCardW * heightShrink).dp
                LaunchedEffect(cardW) { activeCardW = cardW }
                val cardH = cardW * 1.4f

                Column(modifier = Modifier.fillMaxSize()) {
                    // Top Row
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                        // Stock
                        Box(modifier = Modifier
                            .size(cardW, cardH)
                            .onGloballyPositioned { pileFrames[state.stock.id] = it.boundsInRoot() }
                            .clip(RoundedCornerShape(4.dp))
                            .clickable {
                                val now = System.currentTimeMillis()
                                if (now - lastStockTapTime < 250) return@clickable
                                lastStockTapTime = now
                                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                viewModel.drawCard()
                            }
                            .hintHighlight(isHighlighted = state.stock.id == hintSourceId || state.stock.id == hintTargetId, cornerRadius = 4.dp)
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
                            .hintHighlight(isHighlighted = state.waste.id == hintSourceId || state.waste.id == hintTargetId, cornerRadius = 4.dp)
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
                                    val isDragging = dragState.cards.any { it.id == card.id }
                                    var layoutPos by remember(card.id) { mutableStateOf(Offset.Zero) }
                                    Box(
                                        modifier = Modifier
                                            .size(cardW, cardH)
                                            .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                            .pointerInput(card.id) {
                                                if (isTop) {
                                                    coroutineScope {
                                                        launch {
                                                            detectTapGestures(
                                                                onTap = {},
                                                                onDoubleTap = { if (viewModel.doubleClickMoveToFoundation(card, state.waste)) haptics.performHapticFeedback(HapticFeedbackType.LongPress) }
                                                            )
                                                        }
                                                        launch {
                                                            detectDragGestures(
                                                                onDragStart = { _ -> haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove); dragState = DragState(listOf(card), state.waste, layoutPos, Offset.Zero) },
                                                                onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                                onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel, haptics); dragState = DragState() },
                                                                onDragCancel = { dragState = DragState() }
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                    ) {
                                        CardView(card = card, modifier = Modifier.size(cardW, cardH).alpha(if (isDragging) 0f else 1f))
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
                                .hintHighlight(isHighlighted = pile.id == hintSourceId || pile.id == hintTargetId, cornerRadius = 4.dp)
                            ) {
                                Box(modifier = Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.2f)))
                                val topCard = pile.cards.lastOrNull()
                                if (topCard != null) {
                                    val isDragging = dragState.cards.any { it.id == topCard.id }
                                    var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                    Box(
                                        modifier = Modifier
                                            .size(cardW, cardH)
                                            .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                            .pointerInput(topCard.id) {
                                                detectDragGestures(
                                                    onDragStart = { _ -> haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove); dragState = DragState(listOf(topCard), pile, layoutPos, Offset.Zero) },
                                                    onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                    onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel, haptics); dragState = DragState() },
                                                    onDragCancel = { dragState = DragState() }
                                                )
                                            }
                                    ) {
                                        CardView(card = topCard, modifier = Modifier.size(cardW, cardH).alpha(if (isDragging) 0f else 1f))
                                    }
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Tableau
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                        val upStep = cardH * 0.24f
                        val downStep = cardH * 0.12f
                        state.tableau.forEach { pile ->
                            Box(modifier = Modifier
                                .width(cardW)
                                .fillMaxHeight()
                                .onGloballyPositioned { pileFrames[pile.id] = it.boundsInRoot() }
                                .hintHighlight(isHighlighted = pile.id == hintSourceId || pile.id == hintTargetId, cornerRadius = 4.dp)
                            ) {
                                Box(modifier = Modifier.size(cardW, cardH).background(Color.Black.copy(alpha = 0.2f)))
                                var runningY = 0.dp
                                pile.cards.forEachIndexed { i, card ->
                                    val currentY = runningY
                                    val stack = pile.cards.subList(i, pile.cards.size)
                                    val isDragging = dragState.cards.any { it.id == card.id }
                                    var layoutPos by remember(card.id) { mutableStateOf(Offset.Zero) }
                                    Box(
                                        modifier = Modifier
                                            .offset(y = currentY)
                                            .size(cardW, cardH)
                                            .zIndex(i.toFloat())
                                            .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                            .pointerInput(card.id) {
                                                if (card.faceUp) {
                                                    coroutineScope {
                                                        launch {
                                                            detectTapGestures(
                                                                onTap = {},
                                                                onDoubleTap = { if (viewModel.doubleClickMoveToFoundation(card, pile)) haptics.performHapticFeedback(HapticFeedbackType.LongPress) }
                                                            )
                                                        }
                                                        launch {
                                                            detectDragGestures(
                                                                onDragStart = { _ -> haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove); dragState = DragState(stack, pile, layoutPos, Offset.Zero) },
                                                                onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                                onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel, haptics); dragState = DragState() },
                                                                onDragCancel = { dragState = DragState() }
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                    ) {
                                        CardView(card = card, modifier = Modifier.size(cardW, cardH).alpha(if (isDragging) 0f else 1f))
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
            val cardW = activeCardW
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
        var autocompleteDismissed by remember { mutableStateOf(false) }
        LaunchedEffect(isAutocompleteAvailable) {
            if (!isAutocompleteAvailable) autocompleteDismissed = false
        }
        if (isAutocompleteAvailable && !state.hasWon && !autocompleteDismissed) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            IconButton(onClick = { autocompleteDismissed = true }) {
                                Icon(Icons.Default.Close, contentDescription = "Dismiss")
                            }
                        }
                        Text("Victory Guaranteed!", color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { viewModel.runAutocomplete() }) { Text("Auto-complete") }
                    }
                }
            }
        }

        // "No hints available" toast — the fallback HintMove has an empty source pile id.
        activeHint?.let { hint ->
            if (hint.sourcePileId.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize().padding(bottom = 32.dp), contentAlignment = Alignment.BottomCenter) {
                    Box(
                        modifier = Modifier
                            .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(8.dp))
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        Text(hint.description, color = Color.White)
                    }
                }
            }
        }
            } // Close BoxWithConstraints for landscape root

        if (state.hasWon) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("You Win!", color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 32.sp)
                        Text(if (options.isVegasScoring) "Bankroll: " + formatVegasCurrency(state.score) else "Score: ${state.score}")
                        if (!noStressMode) {
                            Text("Time: ${com.leah.honeycomb.formatSeconds(state.timerSeconds)}")
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.startNewGame() }) { Text("Play Again") }
                    }
                }
            }
        }

        var stuckDismissed by remember { mutableStateOf(false) }
        LaunchedEffect(isStuck) { if (!isStuck) stuckDismissed = false }
        if (isStuck && !state.hasWon && !stuckDismissed) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            IconButton(onClick = { stuckDismissed = true }) {
                                Icon(Icons.Default.Close, contentDescription = "Dismiss")
                            }
                        }
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
    viewModel: GameViewModel,
    haptics: androidx.compose.ui.hapticfeedback.HapticFeedback
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
            if (viewModel.moveCards(resolved, dragState.sourcePile, dropTarget)) {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            }
        }
    }
}
