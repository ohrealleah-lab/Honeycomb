package com.leah.honeycomb.spider

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
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
import androidx.compose.ui.zIndex
import com.leah.honeycomb.Card
import com.leah.honeycomb.CardView
import com.leah.honeycomb.Pile
import com.leah.honeycomb.SmartDrop
import com.leah.honeycomb.hintHighlight
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private data class DragState(
    val cards: List<Card> = emptyList(),
    val sourcePile: Pile? = null,
    val startPosition: Offset = Offset.Zero,
    val offset: Offset = Offset.Zero
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SpiderBoard(
    viewModel: SpiderViewModel,
    onMenuTap: () -> Unit,
    onOptions: () -> Unit,
    onThemes: () -> Unit = {}
) {
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val state by viewModel.state.collectAsState()
    val noStressMode by viewModel.sharedOptions.noStressMode.collectAsState()
    val options by viewModel.options.collectAsState()
    val isAutocompleteAvailable by viewModel.isAutocompleteAvailable.collectAsState()
    val isAutoplayRunning by viewModel.isAutoplayRunning.collectAsState()
    val isStuck by viewModel.isStuck.collectAsState()
    val pointPopup by viewModel.pointPopup.collectAsState()
    val activeHint by viewModel.activeHint.collectAsState()
    val hintSourceId = activeHint?.sourcePileId
    val hintTargetId = activeHint?.targetPileId

    var showEmptyStockWarning by remember { mutableStateOf(false) }
    LaunchedEffect(showEmptyStockWarning) {
        if (showEmptyStockWarning) {
            kotlinx.coroutines.delay(2000)
            showEmptyStockWarning = false
        }
    }

    var activeCardW by remember { mutableStateOf(0.dp) }
    var dragState by remember { mutableStateOf(DragState()) }
    val haptics = LocalHapticFeedback.current
    val pileFrames = remember { mutableStateMapOf<String, Rect>() }

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

    var showQuitDialog by remember { mutableStateOf(false) }

    androidx.activity.compose.BackHandler(enabled = state.movesCount > 0 && !state.hasWon) {
        showQuitDialog = true
    }

    if (showQuitDialog) {
        AlertDialog(
            onDismissRequest = { showQuitDialog = false },
            title = { Text(com.leah.honeycomb.Strings.get(StringKey.ToolbarQuitMatch, language)) },
            text = { Text(com.leah.honeycomb.Strings.get(StringKey.NewMatchConfirmTitle, language)) },
            confirmButton = {
                TextButton(onClick = { showQuitDialog = false; viewModel.startNewGame() }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.QuitButton, language))
                }
            },
            dismissButton = {
                TextButton(onClick = { showQuitDialog = false }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.Cancel, language))
                }
            }
        )
    }

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
                    Text("SCORE", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                        Text("${state.score}", fontWeight = FontWeight.Bold, color = Color.Yellow)
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
                        IconButton(onClick = onOptions) {
                            Icon(Icons.Default.Settings, contentDescription = "Options", tint = Color.White)
                        }
                        IconButton(onClick = onThemes) {
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
                                    else showQuitDialog = true
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
            
            BoxWithConstraints(modifier = Modifier.weight(1f).fillMaxWidth()) {
            if (showEmptyStockWarning) {
                Text(
                    "Fill every empty column before dealing again",
                    color = Color.Yellow,
                    fontSize = 12.sp,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 4.dp)
                        .zIndex(10f)
                )
            }
            val config = LocalConfiguration.current
            val screenWidth = config.screenWidthDp.dp
            // We have 10 columns in Spider, need to fit them in width
            // 9 gaps of 4.dp = 36dp. Plus 4dp total horizontal padding = 40dp.
            val baseCardW = ((maxWidth.value - 40f) / 10f).coerceAtMost(90f)
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
            activeCardW = cardW
            val cardH = cardW * 1.4f
            val downStep = cardH * 0.12f
            val upStep = cardH * 0.24f

            Column(modifier = Modifier.padding(top = 8.dp)) {
                // Top Row: Stock on left, Foundations on right
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 2.dp), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally)) {
                    // Stock
                    Box(modifier = Modifier
                        .size(cardW, cardH)
                        .border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
                        .hintHighlight(isHighlighted = hintSourceId == state.stock.id, cornerRadius = 4.dp)
                        .clickable {
                            if (!state.stock.isEmpty && viewModel.hasEmptyTableauColumn) {
                                showEmptyStockWarning = true
                            } else {
                                viewModel.drawFromStock()
                            }
                        }
                    ) {
                        if (!state.stock.isEmpty) {
                            // Draw stock backing
                            CardView(card = state.stock.cards.last(), modifier = Modifier.fillMaxSize())
                        } else {
                            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                Text("O", color = Color.White.copy(alpha=0.5f))
                            }
                        }
                    }
                    
                    // Foundations (Spider has 8, usually shown clustered or stacked)
                    // We can just show a cluster or the top completed run for brevity.
                    Row(horizontalArrangement = Arrangement.spacedBy((-cardW.value * 0.8f).dp)) {
                        state.foundations.forEach { fdn ->
                            Box(modifier = Modifier
                                .size(cardW, cardH)
                                .onGloballyPositioned { pileFrames[fdn.id] = it.boundsInRoot() }
                                .border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
                                .hintHighlight(isHighlighted = fdn.id == hintSourceId || fdn.id == hintTargetId, cornerRadius = 4.dp)
                            ) {
                                if (!fdn.isEmpty) {
                                    CardView(card = fdn.topCard!!, modifier = Modifier.fillMaxSize())
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Tableau (10 columns)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally)) {
                    state.tableau.forEach { pile ->
                        Box(
                            modifier = Modifier
                                .width(cardW)
                                .fillMaxHeight()
                                .onGloballyPositioned { pileFrames[pile.id] = it.boundsInRoot() }
                                .hintHighlight(isHighlighted = pile.id == hintSourceId || pile.id == hintTargetId, cornerRadius = 4.dp)
                        ) {
                            if (pile.isEmpty) {
                                Box(modifier = Modifier.size(cardW, cardH).border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp)))
                            } else {
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
                                                                onDoubleTap = { viewModel.doubleClickMove(card, pile); haptics.performHapticFeedback(HapticFeedbackType.LongPress) }
                                                            )
                                                        }
                                                        launch {
                                                            if (viewModel.isValidDragSequence(stack)) {
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
            val config = LocalConfiguration.current
            val screenWidth = config.screenWidthDp.dp
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
        }        } // Close inner BoxWithConstraints

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

        
        // End Game Overlays
        if (state.hasWon) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                Card {
                    Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("You Win!", color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 32.sp)
                        Text("Score: ${state.score}")
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.startNewGame() }) { Text("Play Again") }
                    }
                }
            }
        } else {
            var stuckDismissed by remember { mutableStateOf(false) }
            LaunchedEffect(isStuck) { if (!isStuck) stuckDismissed = false }
            var autocompleteDismissed by remember { mutableStateOf(false) }
            LaunchedEffect(isAutocompleteAvailable) { if (!isAutocompleteAvailable) autocompleteDismissed = false }

            if (isStuck && !stuckDismissed) {
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
            } else if (isAutocompleteAvailable && !autocompleteDismissed) {
                Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
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
        }
    }
}

private fun handleDragEnd(
    dragState: DragState,
    pileFrames: Map<String, Rect>,
    viewModel: SpiderViewModel,
    haptics: androidx.compose.ui.hapticfeedback.HapticFeedback
) {
    if (dragState.cards.isEmpty() || dragState.sourcePile == null) return
    val releaseX = dragState.startPosition.x + dragState.offset.x + 40f
    val releaseY = dragState.startPosition.y + dragState.offset.y + 40f

    var dropTarget: Pile? = null
    var bestDist = Float.MAX_VALUE

    // Target Tableau
    for (tab in viewModel.state.value.tableau) {
        if (tab.id == dragState.sourcePile.id) continue
        
        val frame = pileFrames[tab.id] ?: continue
        val margin = 40f
        if (releaseX >= frame.left - margin && releaseX <= frame.right + margin && releaseY >= frame.top - margin) {
            val dist = Math.abs(releaseX - frame.center.x)
            val isValid = SmartDrop.resolve(dragState.cards) { viewModel.isValidMove(it, tab) } != null
            if (isValid && dist < bestDist) {
                bestDist = dist
                dropTarget = tab
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
