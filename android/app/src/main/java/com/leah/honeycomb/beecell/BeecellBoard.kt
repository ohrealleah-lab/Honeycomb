package com.leah.honeycomb.beecell

import com.leah.honeycomb.tr

import androidx.compose.animation.core.*
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
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import com.leah.honeycomb.WinAnimationView
import com.leah.honeycomb.rememberFireOnceTrigger
import com.leah.honeycomb.rememberDragSettle
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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
fun BeecellBoard(
    viewModel: BeecellViewModel,
    onMenuTap: () -> Unit,
    onOptions: () -> Unit,
    onThemes: () -> Unit = {}
) {
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val state by viewModel.state.collectAsState()
    val isStuck by viewModel.isStuck.collectAsState()
    val isAutocompleteAvailable by viewModel.isAutocompleteAvailable.collectAsState()
    val activeHint by viewModel.activeHint.collectAsState()
    val hintSourceId = activeHint?.sourcePileId
    val hintTargetId = activeHint?.targetPileId
    val activeBanner by viewModel.activeBanner.collectAsState()
    val manuallyDismissBanners by viewModel.sharedOptions.manuallyDismissBanners.collectAsState()
    LaunchedEffect(Unit) { viewModel.checkLoadingBanner() }
    var activeCardW by remember { mutableStateOf(0.dp) }
    var dragState by remember { mutableStateOf(DragState()) }
    val pileFrames = remember { mutableStateMapOf<String, Rect>() }

    var showQuitDialog by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val density = LocalDensity.current
    // Drag-drop settle spring (see GameSessionHelpers.kt's DragSettle; matches iOS
    // BeecellTouchView's withAnimation(.spring(response: 0.25, dampingFraction: 0.8))
    // around moveCards) — purely cosmetic; the move itself is committed synchronously in
    // performDragEnd, before this animation starts.
    val dragSettle = rememberDragSettle()
    fun beginDrag(newState: DragState) {
        dragSettle.beginDrag()
        dragState = newState
    }

    // Confetti burst, paired with WinAnimationView's bouncing cards below — mirrors iOS's
    // BeecellTouchView onChange(of: hasWon) { showParticles = true; ...cleared after 0.8s }.
    // See FireOnceTrigger for why this isn't a plain `var + LaunchedEffect` pair.
    val particleTrigger = rememberFireOnceTrigger(holdMs = 800)
    LaunchedEffect(state.hasWon) {
        if (state.hasWon) particleTrigger.fire()
    }
    val showParticles = particleTrigger.active

    // A DragGesture has no guaranteed "cancelled" callback if the app is backgrounded
    // mid-drag — this must be a real ON_STOP lifecycle observer, not composition-dispose
    // (onDispose here only fires on leaving the composition, e.g. navigating away, which
    // doesn't happen when the app is merely backgrounded and doesn't actually catch the
    // case this exists for).
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        // The game timer lives in the app-scoped ViewModel, so without pausing it here it
        // kept counting while the app was backgrounded and after switching to another game
        // (Mac/Windows pause it on a game switch, iOS is suspended in the background).
        // Backgrounding (and rotation) resumes it automatically; leaving the board resumes
        // it on the next move, like Mac.
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                dragState = DragState()
                viewModel.pauseTimerForBackground()
            } else if (event == Lifecycle.Event.ON_START) {
                // Also delivered when a recreated board (e.g. after rotation) attaches
                // this observer — the VM remembers whether to resume.
                viewModel.resumeTimerAfterBackground()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            viewModel.stopTimer()
        }
    }

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

        com.leah.honeycomb.BannerToast(
            text = activeBanner,
            manuallyDismissBanners = manuallyDismissBanners,
            onDismiss = { viewModel.dismissBanner() }
        )

        val scoreCapsule = @Composable {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.4f), CircleShape)
                    .padding(horizontal = 24.dp, vertical = 2.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(0.dp)) {
                    Text("SCORE", fontSize = 9.sp, lineHeight = 10.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text("${state.score}", fontSize = 14.sp, lineHeight = 16.sp, fontWeight = FontWeight.Bold, color = Color.Yellow)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(0.dp)) {
                    Text("TIME", fontSize = 9.sp, lineHeight = 10.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text(com.leah.honeycomb.formatSeconds(state.timerSeconds, zeroPlaceholder = "00:00"), fontSize = 14.sp, lineHeight = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
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
                            Text(tr(StringKey.TouchNewDealLabel), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
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
            val config = LocalConfiguration.current
            val screenWidth = config.screenWidthDp.dp
            val baseCardW = ((maxWidth.value - 32f) / 8f).coerceAtMost(90f)
            val baseCardH = baseCardW * 1.4f
            
            val stepTest = baseCardH * 0.24f
            val deepestTableau = state.tableau.maxOfOrNull { pile ->
                if (pile.cards.isEmpty()) return@maxOfOrNull baseCardH
                (pile.cards.size - 1) * stepTest + baseCardH
            } ?: baseCardH
            
            val neededHeight = baseCardH + 16f + deepestTableau + 20f
            val heightShrink = if (neededHeight > maxHeight.value) maxHeight.value / neededHeight else 1.0f
            
            val cardW = (baseCardW * heightShrink).dp
            val cardH = cardW * 1.4f
            val downStep = cardH * 0.24f
            activeCardW = cardW

            // Resolves the current drag to a target pile (if any), then animates the
            // floating overlay stack (spring, matching iOS) from its release point to its
            // exact resting position in that pile before committing the move.
            fun performDragEnd() {
                val plan = resolveDrop(dragState, pileFrames, viewModel)
                val sourcePile = dragState.sourcePile
                if (plan == null || sourcePile == null) {
                    dragState = DragState()
                    return
                }
                val frame = pileFrames[plan.target.id]
                val landing = frame?.let {
                    if (plan.isTableau) {
                        val runningPx = plan.target.cards.size * with(density) { downStep.toPx() }
                        Offset(it.left, it.top + runningPx)
                    } else {
                        it.topLeft
                    }
                }
                val startOffset = Offset(dragState.startPosition.x + dragState.offset.x, dragState.startPosition.y + dragState.offset.y)
                dragSettle.settle(
                    start = startOffset,
                    landing = landing,
                    commit = { viewModel.moveCards(plan.cards, sourcePile, plan.target) },
                    onSettled = { dragState = DragState() }
                )
            }

            Column(modifier = Modifier.padding(top = 8.dp)) {
                // Top Row: Free Cells on left, Foundations on right
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 2.dp), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally)) {
                    state.freeCells.forEach { cell ->
                        Box(modifier = Modifier
                            .size(cardW, cardH)
                            .onGloballyPositioned { pileFrames[cell.id] = it.boundsInRoot() }
                            .border(1.dp, Color.Black.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
                            .hintHighlight(isHighlighted = cell.id == hintSourceId || cell.id == hintTargetId, cornerRadius = 4.dp)
                        ) {
                            if (!cell.isEmpty) {
                                val card = cell.topCard!!
                                val isDragging = dragState.cards.any { it.id == card.id }
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
                                                        onDoubleTap = { if (viewModel.doubleClickMove(card, cell)) haptics.performHapticFeedback(HapticFeedbackType.LongPress) }
                                                    )
                                                }
                                                launch {
                                                    detectDragGestures(
                                                        onDragStart = { _ -> haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove); beginDrag(DragState(listOf(card), cell, layoutPos, Offset.Zero)) },
                                                        onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                        onDragEnd = { performDragEnd() },
                                                        onDragCancel = { dragState = DragState() }
                                                    )
                                                }
                                            }
                                        }
                                ) {
                                    CardView(card = card, modifier = Modifier.fillMaxSize().alpha(if (isDragging) 0f else 1f))
                                }
                            }
                        }
                    }
                    
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

                Spacer(modifier = Modifier.height(16.dp))

                // Tableau (8 columns)
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 2.dp), horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally)) {
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
                                    var layoutPos by remember { mutableStateOf(Offset.Zero) }
                                    Box(
                                        modifier = Modifier
                                            .offset(y = currentY)
                                            .size(cardW, cardH)
                                            .zIndex(i.toFloat())
                                            .onGloballyPositioned { layoutPos = it.positionInRoot() }
                                            .pointerInput(card.id) {
                                                coroutineScope {
                                                    launch {
                                                        detectTapGestures(
                                                            onTap = {},
                                                            onDoubleTap = { if (viewModel.doubleClickMove(card, pile)) haptics.performHapticFeedback(HapticFeedbackType.LongPress) }
                                                        )
                                                    }
                                                    launch {
                                                        if (viewModel.isValidDragSequence(stack)) {
                                                            detectDragGestures(
                                                                onDragStart = { _ -> haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove); beginDrag(DragState(stack, pile, layoutPos, Offset.Zero)) },
                                                                onDrag = { change, amount -> change.consume(); dragState = dragState.copy(offset = dragState.offset + amount) },
                                                                onDragEnd = { performDragEnd() },
                                                                onDragCancel = { dragState = DragState() }
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                    ) {
                                        CardView(card = card, modifier = Modifier.size(cardW, cardH).alpha(if (isDragging) 0f else 1f))
                                    }
                                    runningY += downStep
                                }
                            }
                        }
                    }
                }
            }
        }
        } // close BoxWithConstraints
        
        if (state.hasWon) {
            WinAnimationView(
                foundations = state.foundations,
                pileFrames = pileFrames,
                zoomScale = 1f,
                onFinished = {}
            )

            // On top of the bouncing cards AND the win dialog below (zIndex 200f) —
            // matches Klondike/Spider's identical wrapper; without it this defaults to
            // zIndex 0 and renders underneath the dialog's scrim instead of over it.
            Box(modifier = Modifier.fillMaxSize().zIndex(201f)) {
                com.leah.honeycomb.WinParticleView(active = showParticles)
            }
        }

        // Full screen Drag Overlay
        if (dragState.cards.isNotEmpty()) {
            val cardW = activeCardW
            val cardH = cardW * 1.4f
            val downStep = cardH * 0.24f
            val displayOffset = dragSettle.displayOffset(Offset(dragState.startPosition.x + dragState.offset.x, dragState.startPosition.y + dragState.offset.y))
            Box(modifier = Modifier.fillMaxSize().zIndex(100f)) {
                Box(modifier = Modifier
                    .offset { IntOffset(displayOffset.x.roundToInt(), displayOffset.y.roundToInt()) }
                ) {
                    dragState.cards.forEachIndexed { i, card ->
                        Box(modifier = Modifier.offset(y = downStep * i)) {
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
        var stuckDismissed by remember { mutableStateOf(false) }
        LaunchedEffect(isStuck) { if (!isStuck) stuckDismissed = false }
        var autocompleteDismissed by remember { mutableStateOf(false) }
        LaunchedEffect(isAutocompleteAvailable) { if (!isAutocompleteAvailable) autocompleteDismissed = false }

        if (state.hasWon) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                com.leah.honeycomb.GameOverlayCard {
                    Text(com.leah.honeycomb.Strings.get(StringKey.YouWin, language), color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 32.sp)
                    Text("${com.leah.honeycomb.Strings.get(StringKey.ScoreLabel, language)}: ${state.score}", color = Color.White)
                    Text("${com.leah.honeycomb.Strings.get(StringKey.TimeLabel, language)}: ${com.leah.honeycomb.formatSeconds(state.timerSeconds)}", color = Color.White)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.startNewGame() }) { Text(com.leah.honeycomb.Strings.get(StringKey.NewGame, language)) }
                }
            }
        } else if (isStuck && !stuckDismissed) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha=0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                com.leah.honeycomb.GameOverlayCard(onDismiss = { stuckDismissed = true }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.GameOver, language), color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 32.sp)
                    Text(com.leah.honeycomb.Strings.get(StringKey.NoMovesRemaining, language), color = Color.White)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.restartCurrentGame() }) { Text(com.leah.honeycomb.Strings.get(StringKey.Restart, language)) }
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(onClick = { viewModel.startNewGame() }) { Text(com.leah.honeycomb.Strings.get(StringKey.NewGame, language)) }
                }
            }
        } else if (isAutocompleteAvailable && !autocompleteDismissed) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f)).zIndex(200f), contentAlignment = Alignment.Center) {
                com.leah.honeycomb.GameOverlayCard(onDismiss = { autocompleteDismissed = true }) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.VictoryGuaranteed, language), color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(com.leah.honeycomb.Strings.get(StringKey.AutocompleteBodyOther, language), color = Color.White, fontSize = 14.sp, textAlign = TextAlign.Center)
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(onClick = { viewModel.runAutocomplete() }) { Text(com.leah.honeycomb.Strings.get(StringKey.AutocompleteGame, language)) }
                }
            }
        }
    }

// Result of resolving a drag release to a valid drop target — resolving no longer performs
// the move directly (see performDragEnd) so the caller can animate the settle first.
private data class DropPlan(val target: Pile, val cards: List<Card>, val isTableau: Boolean)

private fun resolveDrop(
    dragState: DragState,
    pileFrames: Map<String, Rect>,
    viewModel: BeecellViewModel
): DropPlan? {
    if (dragState.cards.isEmpty() || dragState.sourcePile == null) return null
    val releaseX = dragState.startPosition.x + dragState.offset.x + 40f
    val releaseY = dragState.startPosition.y + dragState.offset.y + 40f

    var dropTarget: Pile? = null
    var isTableauTarget = false
    var bestDist = Float.MAX_VALUE

    val tableauIds = viewModel.state.value.tableau.map { it.id }.toSet()
    val allPiles = viewModel.state.value.freeCells + viewModel.state.value.foundations + viewModel.state.value.tableau

    for (tab in allPiles) {
        if (tab.id == dragState.sourcePile.id) continue

        val frame = pileFrames[tab.id] ?: continue
        val margin = 40f
        if (releaseX >= frame.left - margin && releaseX <= frame.right + margin && releaseY >= frame.top - margin) {
            val dist = Math.abs(releaseX - frame.center.x) + Math.abs(releaseY - frame.top)
            val isValid = SmartDrop.resolve(dragState.cards) { viewModel.isValidMove(it, tab) } != null
            if (isValid && dist < bestDist) {
                bestDist = dist
                dropTarget = tab
                isTableauTarget = tab.id in tableauIds
            }
        }
    }

    val target = dropTarget ?: return null
    val resolved = SmartDrop.resolve(dragState.cards) { viewModel.isValidMove(it, target) } ?: return null
    return DropPlan(target, resolved, isTableauTarget)
}
