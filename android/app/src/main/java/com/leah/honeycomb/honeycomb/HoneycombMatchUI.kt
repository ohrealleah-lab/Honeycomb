package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.animation.*
import androidx.compose.animation.core.*

import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings
import com.leah.honeycomb.hintHighlight
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

data class DragInfo(
    val index: Int,
    val card: HoneycombCard,
    val initialPosition: Offset,
    val size: IntSize
)

// Ported from HoneycombRuleLocalization.swift's honeycombLocalizedPlayerRankName —
// same thresholds, same fallback to a plain "Player" label below the first rank.
private fun playerRankName(cardsCollected: Int, totalCards: Int, language: com.leah.honeycomb.AppLanguage): String {
    if (totalCards > 0 && cardsCollected >= totalCards) return Strings.get(StringKey.RankApiarist, language)
    return when {
        cardsCollected >= 500 -> Strings.get(StringKey.RankHiveMonarch, language)
        cardsCollected >= 400 -> Strings.get(StringKey.RankSwarmLeader, language)
        cardsCollected >= 300 -> Strings.get(StringKey.RankRoyalAttendant, language)
        cardsCollected >= 200 -> Strings.get(StringKey.RankCombArchitect, language)
        cardsCollected >= 150 -> Strings.get(StringKey.RankWaggleDancer, language)
        cardsCollected >= 100 -> Strings.get(StringKey.RankGuardBee, language)
        cardsCollected >= 50 -> Strings.get(StringKey.RankWorkerBee, language)
        cardsCollected >= 20 -> Strings.get(StringKey.RankScoutBee, language)
        cardsCollected >= 10 -> Strings.get(StringKey.RankNurseBee, language)
        else -> Strings.get(StringKey.PlayerLabel, language)
    }
}

private fun scoreDealerText(language: com.leah.honeycomb.AppLanguage, name: String, score: Int): String =
    Strings.get(StringKey.ScoreDealerFmt, language).replaceFirst("%@", name).replaceFirst("%d", "$score")

// Ported from HoneycombTouchView.swift's rulesBannerLines computed property.
private fun rulesBannerLines(
    isMidMatch: Boolean,
    state: HoneycombState,
    options: HoneycombOptions,
    language: com.leah.honeycomb.AppLanguage
): List<String> {
    if (isMidMatch) {
        if (state.activeRules.isEmpty()) return listOf(Strings.get(StringKey.RuleLineNormal, language))
        return state.activeRules.map { rule ->
            if ((rule == HoneycombRule.Ascension || rule == HoneycombRule.Descension) && state.ascensionDescensionSuits.isNotEmpty()) {
                val suitNames = state.ascensionDescensionSuits.sorted().map { HoneycombCardData.localizedSuitName(it, language) }
                Strings.get(StringKey.RuleLineSuitFmt, language)
                    .replaceFirst("%@", rule.displayName)
                    .replaceFirst("%@", suitNames.joinToString(", "))
            } else {
                rule.displayName
            }
        }
    }
    if (options.forceNormalMode) return listOf(Strings.get(StringKey.RuleLineNormal, language))
    if (options.selectedRules.isNotEmpty()) {
        return HoneycombRule.entries.filter { options.selectedRules.contains(it) }.map { it.displayName }
    }
    return listOf(Strings.get(StringKey.RuleLineRoulette, language))
}

// Ported from intrinsicSize(landscape:landscapeHandCardSize:) — must stay in exact sync
// with computeLandscapeHandCardSize's own formulas below, or the scale solved from this
// and the card size solved from that will disagree about how big the board should be.
private fun intrinsicSize(isLandscape: Boolean, landscapeCardWidth: Dp): Pair<Dp, Dp> {
    return if (isLandscape) {
        val cardHeight = landscapeCardWidth * HoneycombLayout.cardAspect
        val spacing = HoneycombLayout.boardSpacing(landscapeCardWidth)
        val handColumnWidth = landscapeCardWidth * 3 + HoneycombLayout.handSpacing * 2
        val boardWidth = landscapeCardWidth * 3 + spacing * 2
        val width = handColumnWidth * 2 + boardWidth + 24.dp * 2 + 32.dp
        val boardHeight = cardHeight * 3 + spacing * 2
        (width * 1.01f) to (boardHeight * 1.01f)
    } else {
        val width = HoneycombLayout.handCardWidth * 5 + HoneycombLayout.handSpacing * 4 + 16.dp
        val boardHeight = HoneycombLayout.boardCardHeight * 3 + HoneycombLayout.boardSpacingBase * 2
        val height = HoneycombLayout.handCardHeight * 2 + boardHeight + 40.dp
        (width * 1.02f) to (height * 1.04f)
    }
}

// Ported from computeLandscapeHandCardSize — solved so board + both hand columns fit
// side by side, floored at landscapeMinCardWidth.
private fun computeLandscapeCardWidth(availableWidth: Dp, availableHeight: Dp): Dp {
    if (availableWidth <= 0.dp || availableHeight <= 0.dp) return HoneycombLayout.boardCardWidth
    val spacingRatio = HoneycombLayout.boardSpacingBase / HoneycombLayout.boardCardWidth
    val widthFromHeight = (availableHeight / 1.01f) / (3 * HoneycombLayout.cardAspect + 2 * spacingRatio)
    val widthFromWidth = (availableWidth / 1.01f - HoneycombLayout.handSpacing * 4 - 80.dp) / (9 + 2 * spacingRatio)
    return maxOf(minOf(widthFromHeight, widthFromWidth), HoneycombLayout.landscapeMinCardWidth)
}

@OptIn(ExperimentalSharedTransitionApi::class)
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
    val haptics = LocalHapticFeedback.current
    val options by viewModel.options.collectAsState()
    val hintMove by viewModel.hintMove.collectAsState()
    val activeBanner by viewModel.activeBanner.collectAsState()
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val hideHintButton by com.leah.honeycomb.LocalAppContainer.current.sharedOptions.hideHintButton.collectAsState()
    val unlockedCardIds by viewModel.profileManager.unlockedCardIds.collectAsState()
    val totalCards = viewModel.database.allCards.size

    val isMidMatch = state.gameState == HoneycombGameState.Playing || state.gameState == HoneycombGameState.SuddenDeath

    var showQuitConfirm by remember { mutableStateOf(false) }
    androidx.activity.compose.BackHandler(enabled = isMidMatch) { showQuitConfirm = true }

    var isStealingCard by remember { mutableStateOf(false) }
    LaunchedEffect(state.showPostGamePrompt) {
        if (!state.showPostGamePrompt) isStealingCard = false
    }

    var showRulesPopover by remember { mutableStateOf(false) }

    if (state.pendingSteal != null) {
        AlertDialog(
            onDismissRequest = { viewModel.cancelPendingSteal() },
            title = { Text(Strings.get(StringKey.ConfirmStealTitle, language)) },
            text = { Text(state.pendingSteal?.cardName ?: "") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.confirmPendingSteal()
                    isStealingCard = false
                }) { Text(Strings.get(StringKey.Ok, language)) }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.cancelPendingSteal() }) {
                    Text(Strings.get(StringKey.Cancel, language))
                }
            }
        )
    }

    if (showQuitConfirm) {
        AlertDialog(
            onDismissRequest = { showQuitConfirm = false },
            title = { Text(Strings.get(StringKey.ToolbarQuitMatch, language)) },
            text = { Text(Strings.get(StringKey.NewMatchConfirmTitle, language)) },
            confirmButton = {
                TextButton(onClick = {
                    showQuitConfirm = false
                    viewModel.quitMatch()
                }) { Text(Strings.get(StringKey.QuitButton, language)) }
            },
            dismissButton = {
                TextButton(onClick = { showQuitConfirm = false }) {
                    Text(Strings.get(StringKey.Cancel, language))
                }
            }
        )
    }

    val bannerLines = rulesBannerLines(isMidMatch, state, options, language)
    if (showRulesPopover) {
        AlertDialog(
            onDismissRequest = { showRulesPopover = false },
            title = { Text(bannerLines.joinToString("  •  ")) },
            text = {
                Column {
                    val rulesToExplain = if (isMidMatch) state.activeRules
                        else if (!options.forceNormalMode && options.selectedRules.isNotEmpty()) options.selectedRules.toList()
                        else emptyList()
                    if (rulesToExplain.isEmpty()) {
                        Text(Strings.get(StringKey.RuleLineNormal, language))
                    } else {
                        rulesToExplain.forEach { rule ->
                            Text(rule.displayName, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 8.dp))
                            Text(rule.explanation(state.ascensionDescensionSuits), style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showRulesPopover = false }) { Text(Strings.get(StringKey.Ok, language)) }
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

    SharedTransitionLayout {
        AnimatedVisibility(visible = true) {
            val animatedVisibilityScope = this
            Box(modifier = Modifier.fillMaxSize()) {
                com.leah.honeycomb.theme.AppBackground()

        BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            val isLandscape = maxWidth > maxHeight

            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // 1. Top Bar — leading cluster (Menu/Options/Themes always; Manage Decks/
                // Rules pre- and post-match only) and a trailing cluster (Undo/Hint/Quit
                // mid-match, or Rematch/Start otherwise). In landscape the compact rules
                // capsule overlays this same 44dp band instead of taking its own row —
                // there's no vertical room to spare (matches iOS's topBar overlay).
                Box(modifier = Modifier.fillMaxWidth().height(44.dp)) {
                    Row(
                        modifier = Modifier.fillMaxSize(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = onMenuTap) {
                                Icon(Icons.Default.Menu, contentDescription = "Menu", tint = Color.White)
                            }
                            IconButton(onClick = onOptionsTap) {
                                Icon(Icons.Default.Settings, contentDescription = "Options", tint = Color.White)
                            }
                            IconButton(onClick = onThemesTap) {
                                Icon(Icons.Default.Palette, contentDescription = "Themes", tint = Color.White)
                            }
                            if (!isMidMatch) {
                                IconButton(onClick = onManageDecksTap) {
                                    Icon(Icons.Default.Style, contentDescription = "Manage Decks", tint = Color.White)
                                }
                                IconButton(onClick = onRulesTap) {
                                    Icon(Icons.Default.Hexagon, contentDescription = "Rules", tint = Color.White)
                                }
                            }
                        }

                        if (isMidMatch) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                IconButton(onClick = { viewModel.undoLastAction() }, enabled = viewModel.canUndo) {
                                    Icon(Icons.Default.Undo, contentDescription = "Undo", tint = Color.White)
                                }
                                if (!hideHintButton && options.difficulty != HoneycombDifficulty.UltraHard && state.isPlayerTurn) {
                                    IconButton(onClick = { viewModel.findHint() }) {
                                        Icon(Icons.Default.Lightbulb, contentDescription = "Hint", tint = Color.White)
                                    }
                                }
                                TextButton(onClick = { showQuitConfirm = true }) {
                                    Text(Strings.get(StringKey.QuitButton, language), color = Color.White)
                                }
                            }
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                if (state.gameState == HoneycombGameState.GameOver && viewModel.canRematch) {
                                    IconButton(onClick = { viewModel.rematch() }) {
                                        Icon(Icons.Default.Redo, contentDescription = "Rematch", tint = Color.White)
                                    }
                                }
                                Button(onClick = { viewModel.startNewGame() }) {
                                    Icon(Icons.Default.PlayArrow, contentDescription = null)
                                    if (!isLandscape) {
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(Strings.get(StringKey.StartButton, language))
                                    }
                                }
                            }
                        }
                    }

                    if (isLandscape) {
                        RulesCapsuleCompact(
                            text = bannerLines.joinToString("  •  "),
                            onTap = { showRulesPopover = true },
                            modifier = Modifier.align(Alignment.Center)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                if (!isLandscape) {
                    RulesCapsule(
                        lines = bannerLines,
                        onTap = { showRulesPopover = true }
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }

                if (state.showPostGamePrompt) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        val resultTitle = when (state.matchOutcome) {
                            HoneycombMatchOutcome.Win -> Strings.get(StringKey.YouWin, language)
                            HoneycombMatchOutcome.Loss -> Strings.get(StringKey.YouLose, language)
                            HoneycombMatchOutcome.Draw -> Strings.get(StringKey.TieResult, language)
                            else -> state.matchResult
                        }
                        Text(
                            resultTitle,
                            style = MaterialTheme.typography.headlineSmall,
                            fontWeight = FontWeight.Bold
                        )
                        state.matchResultFlavorText?.let {
                            Text(it, style = MaterialTheme.typography.bodyMedium)
                        }
                        if (isStealingCard) {
                            Text(
                                Strings.get(StringKey.StealInstruction, language),
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.Yellow
                            )
                        } else if (viewModel.canStealCard) {
                            Button(onClick = { isStealingCard = true }) {
                                Text(Strings.get(StringKey.StealCard, language))
                            }
                        } else if (viewModel.stealProtectionActive && viewModel.hasStealableCard) {
                            Text(
                                Strings.get(StringKey.StealProtectionLine, language),
                                style = MaterialTheme.typography.bodySmall
                            )
                        } else if (viewModel.profileManager.isCardBankFull && viewModel.hasStealableCard) {
                            Text(
                                Strings.get(StringKey.CardBankFullLine1, language),
                                style = MaterialTheme.typography.bodySmall
                            )
                            Text(
                                Strings.get(StringKey.CardBankFullLine2, language),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }

                // 2. Scaled game content — one fixed "intrinsic" layout, measured against
                // the space actually available here, uniformly scaled to fit. Mirrors
                // iOS's GeometryReader + scaleEffect(scale) pattern exactly, using the
                // same requiredSize+graphicsLayer approach already established for
                // per-card scaling in CardView.kt.
                BoxWithConstraints(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    val landscapeCardWidth = if (isLandscape) computeLandscapeCardWidth(maxWidth, maxHeight) else HoneycombLayout.boardCardWidth
                    val (intrinsicWidth, intrinsicHeight) = intrinsicSize(isLandscape, landscapeCardWidth)
                    val scaleX = if (intrinsicWidth > 0.dp) maxWidth / intrinsicWidth else 1f
                    val scaleY = if (intrinsicHeight > 0.dp) maxHeight / intrinsicHeight else 1f
                    val scale = min(2.0f, max(0.2f, min(scaleX, scaleY)))

                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .requiredSize(intrinsicWidth, intrinsicHeight)
                            .graphicsLayer(scaleX = scale, scaleY = scale)
                            .align(Alignment.Center)
                    ) {
                        if (isLandscape) {
                            Row(
                                modifier = Modifier.padding(horizontal = 16.dp),
                                horizontalArrangement = Arrangement.spacedBy(24.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
                                    HandLabel(playerRankName(unlockedCardIds.size, totalCards, language))
                                    PlayerHandPyramid(
                                        animatedVisibilityScope = animatedVisibilityScope, state = state, hintMove = hintMove, cardWidth = landscapeCardWidth,
                                        scale = scale, draggedCardInfo = draggedCardInfo,
                                        onDragStart = { draggedCardInfo = it; dragOffset = Offset.Zero },
                                        onDrag = { dragOffset += it },
                                        onDragEnd = {
                                            handleDrop(draggedCardInfo, dragOffset, dropTargets, viewModel, haptics)
                                            draggedCardInfo = null; dragOffset = Offset.Zero
                                        },
                                        onDragCancel = { draggedCardInfo = null; dragOffset = Offset.Zero }
                                    )
                                }

                                BoardGrid(animatedVisibilityScope = animatedVisibilityScope, state = state, cardWidth = landscapeCardWidth, hintMove = hintMove, isStealingCard = isStealingCard, viewModel = viewModel, dropTargets = dropTargets)

                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
                                    HandLabel(options.difficulty.displayName)
                                    OpponentHandPyramid(animatedVisibilityScope = animatedVisibilityScope, state = state, cardWidth = landscapeCardWidth)
                                }
                            }
                        } else {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                OpponentHandRow(animatedVisibilityScope = animatedVisibilityScope, state = state, cardWidth = HoneycombLayout.handCardWidth)

                                Box(modifier = Modifier.padding(vertical = 4.dp)) {
                                    BoardGrid(animatedVisibilityScope = animatedVisibilityScope, state = state, cardWidth = HoneycombLayout.boardCardWidth, hintMove = hintMove, isStealingCard = isStealingCard, viewModel = viewModel, dropTargets = dropTargets)
                                }

                                PlayerHandRow(animatedVisibilityScope = animatedVisibilityScope, 
                                    state = state, hintMove = hintMove, cardWidth = HoneycombLayout.handCardWidth,
                                    scale = scale, draggedCardInfo = draggedCardInfo,
                                    onDragStart = { draggedCardInfo = it; dragOffset = Offset.Zero },
                                    onDrag = { dragOffset += it },
                                    onDragEnd = {
                                        handleDrop(draggedCardInfo, dragOffset, dropTargets, viewModel, haptics)
                                        draggedCardInfo = null; dragOffset = Offset.Zero
                                    },
                                    onDragCancel = { draggedCardInfo = null; dragOffset = Offset.Zero }
                                )
                            }
                        }
                    }
                }

                // 3. Score row — fixed, NOT inside the scaled content above, so it stays
                // legible at true size regardless of board scale (matches iOS's
                // scoreCapsule being a sibling row after GeometryReader, not part of
                // gameContent).
                ScoreRow(
                    state = state, options = options, language = language,
                    playerName = playerRankName(unlockedCardIds.size, totalCards, language),
                    isDense = bannerLines.size > 2
                )

                Spacer(modifier = Modifier.height(4.dp))
            }
        }

        // Same!/Plus!/Fallen Ace! capture-rule announcement banner. See
        // HoneycombViewModel.enqueueCaptureBanners/showFrontBanner for the queue.
        Box(modifier = Modifier.fillMaxWidth().zIndex(250f), contentAlignment = Alignment.TopCenter) {
            AnimatedVisibility(
                visible = activeBanner != null,
                enter = fadeIn(animationSpec = tween(150)),
                exit = fadeOut(animationSpec = tween(300))
            ) {
                Box(
                    modifier = Modifier
                        .padding(top = 12.dp)
                        .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 18.dp, vertical = 10.dp)
                ) {
                    Text(
                        activeBanner ?: "",
                        color = Color.Yellow,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
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
                    .zIndex(500f)
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
}

private fun handleDrop(
    info: DragInfo?,
    dragOffset: Offset,
    dropTargets: Map<Int, Rect>,
    viewModel: HoneycombViewModel,
    haptics: androidx.compose.ui.hapticfeedback.HapticFeedback
) {
    if (info == null) return
    val currentCenter = info.initialPosition + dragOffset + Offset(info.size.width / 2f, info.size.height / 2f)
    val targetIndex = dropTargets.entries.firstOrNull { it.value.contains(currentCenter) }?.key
    if (targetIndex != null) {
        if (viewModel.playerPlayCard(info.index, targetIndex)) {
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }
}

@Composable
private fun HandLabel(text: String) {
    Text(text, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
}

@Composable
private fun RulesCapsule(lines: List<String>, onTap: () -> Unit) {
    val isDense = lines.size > 2
    Text(
        text = lines.joinToString("  •  "),
        color = Color.Yellow,
        fontSize = if (isDense) 13.sp else 16.sp,
        fontWeight = FontWeight.Black,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        modifier = Modifier
            .heightIn(min = 40.dp)
            .clickable(onClick = onTap)
            .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = 8.dp)
    )
}

@Composable
private fun RulesCapsuleCompact(text: String, onTap: () -> Unit, modifier: Modifier = Modifier) {
    Text(
        text = text,
        color = Color.Yellow,
        fontSize = 13.sp,
        fontWeight = FontWeight.Black,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .widthIn(max = 240.dp)
            .clickable(onClick = onTap)
            .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 5.dp)
    )
}

@Composable
private fun ScoreRow(
    state: HoneycombState,
    options: HoneycombOptions,
    language: com.leah.honeycomb.AppLanguage,
    playerName: String,
    isDense: Boolean
) {
    val playerScore = state.board.playerScore + state.playerHand.size
    val opponentScore = state.board.opponentScore + state.opponentHand.size
    Row(
        horizontalArrangement = Arrangement.spacedBy(28.dp),
        modifier = Modifier.alpha(if (state.gameState != HoneycombGameState.Setup) 1f else 0f)
    ) {
        Text(
            scoreDealerText(language, playerName, playerScore),
            color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = if (isDense) 13.sp else 16.sp
        )
        Text(
            scoreDealerText(language, options.difficulty.displayName, opponentScore),
            color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = if (isDense) 13.sp else 16.sp
        )
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.BoardGrid(animatedVisibilityScope: AnimatedVisibilityScope, 
    state: HoneycombState,
    cardWidth: Dp,
    hintMove: Pair<Int, Int>?,
    isStealingCard: Boolean,
    viewModel: HoneycombViewModel,
    dropTargets: MutableMap<Int, Rect>
) {
    val cardHeight = cardWidth * HoneycombLayout.cardAspect
    val spacing = HoneycombLayout.boardSpacing(cardWidth)
    Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
        for (row in 0 until 3) {
            Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                for (col in 0 until 3) {
                    val index = row * 3 + col
                    val cell = state.board.cells[index]
                    val stealEligible = isStealingCard && cell.card?.let { viewModel.isStealEligible(it) } == true

                    Box(
                        modifier = Modifier
                            .width(cardWidth)
                            .height(cardHeight)
                            .background(Color.Black.copy(alpha = 0.2f), RoundedCornerShape(8.dp))
                            .hintHighlight(isHighlighted = hintMove?.second == index)
                            .let { if (stealEligible) it.border(3.dp, Color(0xFFFFD700)) else it }
                            .let { if (stealEligible) it.clickable { viewModel.requestSteal(index) } else it }
                            .onGloballyPositioned { coords -> dropTargets[index] = coords.boundsInRoot() },
                        contentAlignment = Alignment.Center
                    ) {
                        cell.card?.let { c ->
                            HoneycombCardView(
                                card = c,
                                isFlipped = false,
                                highlightedStatIndices = if (state.pointHighlightCardId == c.id) state.pointHighlightStatIndices else emptySet(),
                                isCaptureAttacker = state.captureAttackerIds.contains(c.id),
                                modifier = Modifier.fillMaxSize().sharedBounds(rememberSharedContentState(key = c.id.toString()), animatedVisibilityScope = animatedVisibilityScope)
                            )
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.OpponentHandRow(animatedVisibilityScope: AnimatedVisibilityScope, state: HoneycombState, cardWidth: Dp) {
    val cardHeight = cardWidth * HoneycombLayout.cardAspect
    Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
        if (state.opponentHand.isEmpty()) {
            repeat(5) {
                Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                    HoneycombCardView(
                        card = HoneycombCard(data = HoneycombCardData(-1, "", 1, listOf(1,1,1,1), "H"), owner = CardOwner.Opponent),
                        isFlipped = true,
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        } else {
            state.opponentHand.forEach { card ->
                Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                    HoneycombCardView(
                        card = card,
                        isFlipped = !state.openOpponentCardIds.contains(card.id),
                        isCaptureAttacker = state.swapHighlightCardIds.contains(card.id),
                        modifier = Modifier.fillMaxSize().sharedBounds(rememberSharedContentState(key = card.id), animatedVisibilityScope = animatedVisibilityScope)
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.OpponentHandPyramid(animatedVisibilityScope: AnimatedVisibilityScope, state: HoneycombState, cardWidth: Dp) {
    val cardHeight = cardWidth * HoneycombLayout.cardAspect
    val cards = state.opponentHand
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
        if (cards.isEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
                repeat(3) {
                    Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                        HoneycombCardView(card = HoneycombCard(data = HoneycombCardData(-1, "", 1, listOf(1,1,1,1), "H"), owner = CardOwner.Opponent), isFlipped = true, modifier = Modifier.fillMaxSize())
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
                repeat(2) {
                    Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                        HoneycombCardView(card = HoneycombCard(data = HoneycombCardData(-1, "", 1, listOf(1,1,1,1), "H"), owner = CardOwner.Opponent), isFlipped = true, modifier = Modifier.fillMaxSize())
                    }
                }
            }
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
                for (i in 0 until min(3, cards.size)) {
                    val card = cards[i]
                    Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                        HoneycombCardView(card = card, isFlipped = !state.openOpponentCardIds.contains(card.id), isCaptureAttacker = state.swapHighlightCardIds.contains(card.id), modifier = Modifier.fillMaxSize().sharedBounds(rememberSharedContentState(key = card.id), animatedVisibilityScope = animatedVisibilityScope))
                    }
                }
            }
            if (cards.size > 3) {
                Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
                    for (i in 3 until cards.size) {
                        val card = cards[i]
                        Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                            HoneycombCardView(card = card, isFlipped = !state.openOpponentCardIds.contains(card.id), isCaptureAttacker = state.swapHighlightCardIds.contains(card.id), modifier = Modifier.fillMaxSize().sharedBounds(rememberSharedContentState(key = card.id), animatedVisibilityScope = animatedVisibilityScope))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.PlayerHandRow(animatedVisibilityScope: AnimatedVisibilityScope, 
    state: HoneycombState,
    hintMove: Pair<Int, Int>?,
    cardWidth: Dp,
    scale: Float,
    draggedCardInfo: DragInfo?,
    onDragStart: (DragInfo) -> Unit,
    onDrag: (Offset) -> Unit,
    onDragEnd: () -> Unit,
    onDragCancel: () -> Unit
) {
    val cardHeight = cardWidth * HoneycombLayout.cardAspect
    Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
        if (state.playerHand.isEmpty()) {
            repeat(5) {
                Box(modifier = Modifier.width(cardWidth).height(cardHeight)) {
                    HoneycombCardView(
                        card = HoneycombCard(data = HoneycombCardData(-1, "", 1, listOf(1,1,1,1), "H"), owner = CardOwner.Player),
                        isFlipped = true,
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        } else {
            state.playerHand.forEachIndexed { index, card ->
                PlayerHandCard(
                    animatedVisibilityScope = animatedVisibilityScope, index = index, card = card, cardWidth = cardWidth, cardHeight = cardHeight,
                    isHinted = hintMove?.first == index,
                    isMandated = state.mandatedPlayerHandIndex == index,
                    isSwapped = state.swapHighlightCardIds.contains(card.id),
                    canDrag = state.isPlayerTurn && (state.mandatedPlayerHandIndex == null || state.mandatedPlayerHandIndex == index),
                    scale = scale, draggedIndex = draggedCardInfo?.index,
                    onDragStart = onDragStart, onDrag = onDrag, onDragEnd = onDragEnd, onDragCancel = onDragCancel
                )
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.PlayerHandPyramid(animatedVisibilityScope: AnimatedVisibilityScope,
    state: HoneycombState,
    hintMove: Pair<Int, Int>?,
    cardWidth: Dp,
    scale: Float,
    draggedCardInfo: DragInfo?,
    onDragStart: (DragInfo) -> Unit,
    onDrag: (Offset) -> Unit,
    onDragEnd: () -> Unit,
    onDragCancel: () -> Unit
) {
    val cardHeight = cardWidth * HoneycombLayout.cardAspect
    val cards = state.playerHand

    @Composable
    fun row(range: IntRange) {
        Row(horizontalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
            for (index in range) {
                val card = cards[index]
                PlayerHandCard(
                    animatedVisibilityScope = animatedVisibilityScope, index = index, card = card, cardWidth = cardWidth, cardHeight = cardHeight,
                    isHinted = hintMove?.first == index,
                    isMandated = state.mandatedPlayerHandIndex == index,
                    isSwapped = state.swapHighlightCardIds.contains(card.id),
                    canDrag = state.isPlayerTurn && (state.mandatedPlayerHandIndex == null || state.mandatedPlayerHandIndex == index),
                    scale = scale, draggedIndex = draggedCardInfo?.index,
                    onDragStart = onDragStart, onDrag = onDrag, onDragEnd = onDragEnd, onDragCancel = onDragCancel
                )
            }
        }
    }

    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(HoneycombLayout.handSpacing)) {
        row(0 until min(3, cards.size))
        if (cards.size > 3) row(3 until cards.size)
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.PlayerHandCard(animatedVisibilityScope: AnimatedVisibilityScope, 
    index: Int,
    card: HoneycombCard,
    cardWidth: Dp,
    cardHeight: Dp,
    isHinted: Boolean,
    isMandated: Boolean,
    isSwapped: Boolean = false,
    canDrag: Boolean,
    scale: Float,
    draggedIndex: Int?,
    onDragStart: (DragInfo) -> Unit,
    onDrag: (Offset) -> Unit,
    onDragEnd: () -> Unit,
    onDragCancel: () -> Unit
) {
    // cardPosition/cardSize are captured in ROOT coordinates (post-scale, via
    // boundsInRoot/positionInRoot) so they stay consistent with dropTargets (also
    // root-space) regardless of the graphicsLayer scale applied by an ancestor —
    // see the coordinate-space note on the `onDrag` handler below for why `dragAmount`
    // needs the opposite treatment.
    val haptics = LocalHapticFeedback.current
    var cardPosition by remember { mutableStateOf(Offset.Zero) }
    var cardSize by remember { mutableStateOf(IntSize.Zero) }

    Box(
        modifier = Modifier
            .width(cardWidth)
            .height(cardHeight)
            .hintHighlight(isHighlighted = isHinted)
            .let { if (isMandated) it.border(3.dp, Color(0xFFFFD700)) else it }
            .onGloballyPositioned { coords ->
                cardPosition = coords.positionInRoot()
                val bounds = coords.boundsInRoot()
                cardSize = IntSize(bounds.width.roundToInt(), bounds.height.roundToInt())
            }
            .pointerInput(card, canDrag) {
                detectDragGestures(
                    onDragStart = { _ ->
                        if (canDrag) {
                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            onDragStart(DragInfo(index, card, cardPosition, cardSize))
                        }
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        // dragAmount is reported in this node's LOCAL (pre-scale) layout
                        // space, but dragOffset accumulates against cardPosition/
                        // dropTargets which are root-space — must scale it up to match,
                        // or a drag under a shrunk board resolves against the wrong cell
                        // (the exact coordinate-space mismatch class flagged in the port
                        // plan's risk register).
                        onDrag(dragAmount * scale)
                    },
                    onDragEnd = { onDragEnd() },
                    onDragCancel = { onDragCancel() }
                )
            }
    ) {
        if (draggedIndex != index) {
            HoneycombCardView(card = card, isFlipped = false, isCaptureAttacker = isSwapped, modifier = Modifier.fillMaxSize().sharedBounds(rememberSharedContentState(key = card.id), animatedVisibilityScope = animatedVisibilityScope))
        }
    }
}
