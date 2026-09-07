package com.leah.honeycomb.beecell

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
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
fun BeecellBoard(
    viewModel: BeecellViewModel,
    onMenuTap: () -> Unit,
    onOptions: () -> Unit
) {
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val state by viewModel.state.collectAsState()
    val isStuck by viewModel.isStuck.collectAsState()
    val isAutocompleteAvailable by viewModel.isAutocompleteAvailable.collectAsState()
    var dragState by remember { mutableStateOf(DragState()) }
    val pileFrames = remember { mutableStateMapOf<String, Rect>() }
    
    var showQuitDialog by remember { mutableStateOf(false) }
    
    // A DragGesture has no guaranteed "cancelled" callback if the app is backgrounded
    // mid-drag — this must be a real ON_STOP lifecycle observer, not composition-dispose
    // (onDispose here only fires on leaving the composition, e.g. navigating away, which
    // doesn't happen when the app is merely backgrounded and doesn't actually catch the
    // case this exists for).
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

    if (showQuitDialog) {
        AlertDialog(
            onDismissRequest = { showQuitDialog = false },
            title = { Text(com.leah.honeycomb.Strings.get(StringKey.ToolbarQuitMatch, language)) },
            text = { Text(com.leah.honeycomb.Strings.get(StringKey.NewMatchConfirmTitle, language)) },
            confirmButton = {
                TextButton(onClick = { showQuitDialog = false; onMenuTap() }) {
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Column {
                        Text("Beecell", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        Row {
                            Text("Moves: ${state.movesCount}  ", fontSize = 12.sp)
                            Text("Time: ${state.timerSeconds}s", fontSize = 12.sp)
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onMenuTap) {
                        // Avoid AutoMirrored warning by using generic icon or text
                        Text("<")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.undoLastAction() }, enabled = viewModel.canUndo) {
                        Text(com.leah.honeycomb.Strings.get(StringKey.Undo, language))
                    }
                    IconButton(onClick = onOptions) {
                        Icon(Icons.Filled.Settings, contentDescription = "Options")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF003366), titleContentColor = Color.White, actionIconContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF004488))
                .padding(padding)
        ) {
            val config = LocalConfiguration.current
            val screenWidth = config.screenWidthDp.dp
            val cardW = ((screenWidth.value - 18f) / 8f).coerceAtMost(90f).dp
            val cardH = cardW * 1.4f
            val downStep = cardH * 0.24f

            Column(modifier = Modifier.padding(top = 8.dp)) {
                // Top Row: Free Cells on left, Foundations on right
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    // Free Cells
                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        state.freeCells.forEach { cell ->
                            Box(modifier = Modifier
                                .size(cardW, cardH)
                                .onGloballyPositioned { pileFrames[cell.id] = it.boundsInRoot() }
                                .border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
                            ) {
                                if (!cell.isEmpty) {
                                    val card = cell.topCard!!
                                    val isDragging = dragState.cards.any { it.id == card.id }
                                    if (!isDragging) {
                                        var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                        Box(
                                            modifier = Modifier
                                                .fillMaxSize()
                                                .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                                .pointerInput(card.id) {
                                                    coroutineScope {
                                                        launch {
                                                            detectTapGestures(
                                                                onTap = {},
                                                                onDoubleTap = { viewModel.doubleClickMove(card, cell) }
                                                            )
                                                        }
                                                        launch {
                                                            detectDragGestures(
                                                                onDragStart = { _ -> dragState = DragState(listOf(card), cell, layoutPos, Offset.Zero) },
                                                                onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                                onDragEnd = { handleDragEnd(dragState, pileFrames, viewModel); dragState = DragState() },
                                                                onDragCancel = { dragState = DragState() }
                                                            )
                                                        }
                                                    }
                                                }
                                        ) {
                                            CardView(card = card, modifier = Modifier.fillMaxSize())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Foundations
                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                        state.foundations.forEach { fdn ->
                            Box(modifier = Modifier
                                .size(cardW, cardH)
                                .onGloballyPositioned { pileFrames[fdn.id] = it.boundsInRoot() }
                                .border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
                            ) {
                                if (!fdn.isEmpty) {
                                    CardView(card = fdn.topCard!!, modifier = Modifier.fillMaxSize())
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // Tableau (8 columns)
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 2.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                    state.tableau.forEach { pile ->
                        Box(
                            modifier = Modifier
                                .width(cardW)
                                .fillMaxHeight()
                                .onGloballyPositioned { pileFrames[pile.id] = it.boundsInRoot() }
                        ) {
                            if (pile.isEmpty) {
                                Box(modifier = Modifier.size(cardW, cardH).border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp)))
                            } else {
                                var runningY = 0.dp
                                pile.cards.forEachIndexed { i, card ->
                                    val currentY = runningY
                                    val stack = pile.cards.subList(i, pile.cards.size)
                                    val isDragging = dragState.cards.any { it.id == card.id }
                                    
                                    if (!isDragging) {
                                        var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                        Box(
                                            modifier = Modifier
                                                .offset(y = currentY)
                                                .zIndex(i.toFloat())
                                                .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                                .pointerInput(card.id) {
                                                    coroutineScope {
                                                        launch {
                                                            detectTapGestures(
                                                                onTap = {},
                                                                onDoubleTap = { viewModel.doubleClickMove(card, pile) }
                                                            )
                                                        }
                                                        launch {
                                                            if (viewModel.isValidDragSequence(stack)) {
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
                                    runningY += downStep
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
            val cardW = ((screenWidth.value - 18f) / 8f).coerceAtMost(90f).dp
            val cardH = cardW * 1.4f
            val downStep = cardH * 0.24f
            Box(modifier = Modifier.fillMaxSize().zIndex(100f)) {
                Box(modifier = Modifier
                    .offset { IntOffset((dragState.startPosition.x + dragState.offset.x).roundToInt(), (dragState.startPosition.y + dragState.offset.y).roundToInt()) }
                ) {
                    dragState.cards.forEachIndexed { i, card ->
                        Box(modifier = Modifier.offset(y = downStep * i)) {
                            CardView(card = card, modifier = Modifier.size(cardW, cardH))
                        }
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
                        Text("Time: ${state.timerSeconds}s")
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(onClick = { viewModel.startNewGame() }) { Text("Play Again") }
                    }
                }
            }
        } else if (isStuck) {
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

            if (isAutocompleteAvailable && !state.hasWon) {
                Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                    Card {
                        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
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
    viewModel: BeecellViewModel
) {
    if (dragState.cards.isEmpty() || dragState.sourcePile == null) return
    val releaseX = dragState.startPosition.x + dragState.offset.x + 40f
    val releaseY = dragState.startPosition.y + dragState.offset.y + 40f

    var dropTarget: Pile? = null
    var bestDist = Float.MAX_VALUE

    val allPiles = viewModel.state.value.freeCells + viewModel.state.value.foundations + viewModel.state.value.tableau

    for (tab in allPiles) {
        if (tab.id == dragState.sourcePile.id) continue
        
        val frame = pileFrames[tab.id] ?: continue
        val margin = 40f
        if (releaseX >= frame.left - margin && releaseX <= frame.right + margin && releaseY >= frame.top - margin) {
            val dist = Math.abs(releaseX - frame.center.x) + Math.abs(releaseY - frame.top)
            val isValid = viewModel.isValidMove(dragState.cards, tab)
            if (isValid && dist < bestDist) {
                bestDist = dist
                dropTarget = tab
            }
        }
    }

    if (dropTarget != null) {
        viewModel.moveCards(dragState.cards, dragState.sourcePile, dropTarget)
    }
}
