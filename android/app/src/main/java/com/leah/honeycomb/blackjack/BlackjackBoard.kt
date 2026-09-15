package com.leah.honeycomb.blackjack
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import com.leah.honeycomb.audio.UISound
import com.leah.honeycomb.rememberFireOnceTrigger
import androidx.compose.runtime.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.Alignment
import com.leah.honeycomb.Strings
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.zIndex
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.leah.honeycomb.Card
import com.leah.honeycomb.CardView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Dims a color roughly the way SwiftUI's brightness(-0.08) does, for the pressed-state
// feedback below (CasinoButton.swift:12-14 on iOS: scaleEffect(0.93) + brightness(-0.08)).
private fun Color.pressedDim(): Color = Color(red * 0.92f, green * 0.92f, blue * 0.92f, alpha)

@Composable
fun BetChip(amount: String, color: Color, onClick: () -> Unit) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    // Ported from iOS's CasinoButtonPressStyle (CasinoButton.swift:8-19) — the same
    // scale(0.93)+brightness(-0.08) press feedback, driven by Compose's standard
    // interactionSource/collectIsPressedAsState pattern instead of a custom ButtonStyle.
    val scale by animateFloatAsState(if (isPressed) 0.93f else 1f, animationSpec = tween(80))
    val pressedColor = if (isPressed) color.pressedDim() else color
    Box(
        modifier = Modifier
            .graphicsLayer(scaleX = scale, scaleY = scale)
            .size(50.dp)
            .background(pressedColor, CircleShape)
            .border(2.dp, Color.White, CircleShape)
            .clickable(interactionSource = interactionSource, indication = null) { UISound.click(); onClick() },
        contentAlignment = Alignment.Center
    ) {
        Box(modifier = Modifier.size(40.dp).border(1.dp, Color.White.copy(alpha=0.5f), CircleShape))
        Text(amount, color = if (color == Color.White) Color.Black else Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

@Composable
fun ActionButton(text: String, color: Color, onClick: () -> Unit, enabled: Boolean = true) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(if (isPressed && enabled) 0.93f else 1f, animationSpec = tween(80))
    val baseColor = if (enabled) color else Color.Gray
    val pressedColor = if (isPressed && enabled) baseColor.pressedDim() else baseColor
    Box(modifier = Modifier
        .graphicsLayer(scaleX = scale, scaleY = scale)
        .background(pressedColor, RoundedCornerShape(12.dp))
        .clickable(enabled = enabled, interactionSource = interactionSource, indication = null) { UISound.click(); onClick() }
        .padding(horizontal = 24.dp, vertical = 16.dp)
        .fillMaxWidth()
    ) {
        Text(text, color = if (color == Color(0xFFFFC107) && enabled) Color.Black else Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.align(Alignment.Center))
    }
}

// Staggered deal fade-in — ported from iOS's cardsVisible-driven per-card opacity
// animation (BlackjackTouchView.swift:619-620,688-689): .easeIn(duration: 0.15)
// .delay(i * 0.08). Each card animates in on its own, keyed by its own id, so newly
// dealt cards fade in with the same stagger whether they arrived via the initial
// deal, a hit, a double-down, or a split.
@Composable
private fun DealtCard(card: Card, index: Int, cardW: Dp, cardH: Dp) {
    val alpha = remember(card.id) { Animatable(0f) }
    LaunchedEffect(card.id) {
        delay(index * 80L)
        alpha.animateTo(1f, animationSpec = tween(durationMillis = 150))
    }
    CardView(card = card, modifier = Modifier.size(cardW, cardH).graphicsLayer(alpha = alpha.value))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BlackjackBoard(
    viewModel: BlackjackViewModel,
    onMenuTap: () -> Unit,
    onOptions: () -> Unit,
    onThemes: () -> Unit = {}
) {
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val state by viewModel.state.collectAsState()
    var showQuitDialog by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val activeBanner by viewModel.activeBanner.collectAsState()
    val manuallyDismissBanners by viewModel.sharedOptions.manuallyDismissBanners.collectAsState()
    LaunchedEffect(Unit) { viewModel.checkLoadingBanner() }
    // Fade-out/fade-in cycle around a hand's reset — ported from iOS's cardsVisible
    // (BlackjackTouchView.swift:475,483): when the round resolves back to Betting
    // (New Bet/Re-Deal tapped, clearing the settled hand back to placeholders), the
    // dealer/player rows fade out briefly before fading back in, rather than the
    // placeholders popping in directly on top of the just-finished hand.
    var cardsVisible by remember { mutableStateOf(true) }
    var previousPhase by remember { mutableStateOf(state.phase) }
    LaunchedEffect(state.phase) {
        val cameFromResult = previousPhase == BlackjackPhase.Result
        previousPhase = state.phase
        if (state.phase == BlackjackPhase.Betting && cameFromResult) {
            cardsVisible = false
            delay(250)
            cardsVisible = true
        } else {
            cardsVisible = true
        }
    }
    val resetFadeAlpha by animateFloatAsState(
        targetValue = if (cardsVisible) 1f else 0f,
        animationSpec = tween(durationMillis = if (cardsVisible) 300 else 400)
    )
    // Fires once the win/lose result banner has had time to fade, so this toast lands
    // alongside the Rebuy button rather than stacking on top of it. Mirrors Windows'
    // BlackjackView timing for BannerCatalog.Fire(GameplayPlayerRunsOutOfCreditsVideoPokerBlackjack).
    LaunchedEffect(state.phase) {
        if (state.phase == BlackjackPhase.Result) {
            kotlinx.coroutines.delay(1500)
            viewModel.checkOutOfCredits()
        }
    }
    // Confetti burst on a win — mirrors iOS's BlackjackTouchView bannerShowTask: a 1.0s beat
    // (so the banner pop-in above is visible first) before the burst, held ~0.8s. See
    // FireOnceTrigger for why the hold/reset isn't inlined into this LaunchedEffect
    // directly — its own 1.0s lead-in delay already made it the exact shape that bug
    // class needs (a `state.phase`/`resultOutcome` change mid-delay would cancel it),
    // fire() is what makes the actual show-then-hide immune to that.
    val particleTrigger = rememberFireOnceTrigger(holdMs = 800)
    LaunchedEffect(state.phase, state.resultOutcome) {
        val isWin = state.resultOutcome == BlackjackRoundOutcome.Win || state.resultOutcome == BlackjackRoundOutcome.Blackjack
        if (state.phase == BlackjackPhase.Result && isWin) {
            kotlinx.coroutines.delay(1000)
            particleTrigger.fire()
        }
    }
    val showParticles = particleTrigger.active

    // Full-screen result banner: shows ~1.0s after the round resolves (so the player
    // sees the final hand first), stays up ~4.0s, then auto-hides back to the betting
    // controls underneath — or the player can tap the scrim/card to dismiss it early.
    // Mirrors iOS's showResultBanner/resultBannerShowTask/resultHideTask/
    // dismissResultBannerEarly (BlackjackTouchView.swift:451-493,775-789). Separate
    // from `state.phase == Result` itself (which stays true the whole time, showing
    // the next-bet controls) — this only gates the modal banner's own visibility.
    var showResultBanner by remember { mutableStateOf(false) }
    val resultBannerScope = rememberCoroutineScope()
    var resultBannerJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    LaunchedEffect(state.phase, state.resultOutcome) {
        resultBannerJob?.cancel()
        if (state.phase == BlackjackPhase.Result && state.resultOutcome != BlackjackRoundOutcome.None) {
            resultBannerJob = resultBannerScope.launch {
                kotlinx.coroutines.delay(1000)
                showResultBanner = true
                kotlinx.coroutines.delay(4000)
                showResultBanner = false
            }
        } else {
            showResultBanner = false
        }
    }
    fun dismissResultBannerEarly() {
        resultBannerJob?.cancel()
        showResultBanner = false
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

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        com.leah.honeycomb.BannerToast(
            text = activeBanner,
            manuallyDismissBanners = manuallyDismissBanners,
            onDismiss = { viewModel.dismissBanner() }
        )
        val isLandscape = maxWidth > maxHeight
        val cardW = minOf(100.dp, maxWidth / 5, maxHeight / 3)
        val cardH = cardW * 1.4f
        val cardSpacing = -cardW * 0.4f

        val scoreCapsule = @Composable {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 24.dp, vertical = 8.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.CreditsLabel, language), fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text(if (!viewModel.isFreePlay) "${state.sessionCredits}" else "FREE", fontWeight = FontWeight.Bold, color = Color.Yellow)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.BetLabel, language), fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text("${state.currentBet}", fontWeight = FontWeight.Bold, color = Color.White)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.HandsLabel, language), fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text("${state.handsDealt}", fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
        }

        val topBar = @Composable {
            Row(
                modifier = Modifier.fillMaxWidth().height(48.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row {
                    IconButton(onClick = { if (!viewModel.canOpenOptions) showQuitDialog = true else onMenuTap() }) {
                        Icon(Icons.Default.GridView, contentDescription = "Menu", tint = Color.White)
                    }
                    IconButton(onClick = onOptions) {
                        Icon(Icons.Default.Settings, contentDescription = "Options", tint = Color.White)
                    }
                    IconButton(onClick = onThemes) {
                        Icon(Icons.Default.Palette, contentDescription = "Themes", tint = Color.White)
                    }
                }
                Text("Blackjack", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.padding(end = 16.dp))
            }
        }

        val dealerArea = @Composable {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                val dealerText = if (state.phase == BlackjackPhase.Betting) "DEALER" else "DEALER ${state.dealerVisibleValue}"
                Text(dealerText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(cardSpacing),
                    modifier = Modifier.graphicsLayer(alpha = resetFadeAlpha)
                ) {
                    if (state.dealerCards.isEmpty()) {
                        val placeholder = remember { com.leah.honeycomb.Card(suit = com.leah.honeycomb.Suit.Spades, rank = 1, faceUp = false) }
                        CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                        CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                    } else {
                        state.dealerCards.forEachIndexed { i, card ->
                            DealtCard(card = card, index = i, cardW = cardW, cardH = cardH)
                        }
                    }
                }
            }
        }

        // Full-screen win/lose overlay — matches iOS's resultOverlay (ZStack: a dimmed
        // scrim behind a dark banner card, tap-anywhere-to-dismiss, no X button unlike
        // the solitaire games' win overlays). Gated on showResultBanner (its own timed
        // show/hide, see above), not state.phase == Result directly — the betting
        // controls underneath stay in the normal layout the whole time state.phase ==
        // Result, same as iOS's bettingControls being declared before this overlay.
        val resultOverlay = @Composable {
            if (showResultBanner && state.resultOutcome != BlackjackRoundOutcome.None) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.45f))
                        .clickable(indication = null, interactionSource = remember { MutableInteractionSource() }) { dismissResultBannerEarly() }
                        .zIndex(260f),
                    contentAlignment = Alignment.Center
                ) {
                    // Matches shared/Blackjack/Models/BlackjackResultLocalization.swift's
                    // localizedBlackjackResult exactly — was using the plain "WIN"/"LOSS"/
                    // etc. TouchResultXxx labels instead of this richer copy ("You Win!",
                    // "Not today, partner!", per-hand breakdown for a split), which iOS/Mac
                    // both share via that one function so they can't drift apart.
                    val outcomeText = when (state.resultOutcome) {
                        BlackjackRoundOutcome.Blackjack -> com.leah.honeycomb.Strings.get(StringKey.ResultHeadlineBlackjack, language)
                        BlackjackRoundOutcome.Win -> com.leah.honeycomb.Strings.get(StringKey.YouWin, language)
                        BlackjackRoundOutcome.Push -> com.leah.honeycomb.Strings.get(StringKey.ResultHeadlinePush, language)
                        BlackjackRoundOutcome.Bust -> com.leah.honeycomb.Strings.get(StringKey.ResultHeadlineBust, language)
                        BlackjackRoundOutcome.Loss -> com.leah.honeycomb.Strings.get(StringKey.NotTodayPartner, language)
                        else -> ""
                    }
                    val subline = if (state.playerHands.size > 1) {
                        state.playerHands.mapIndexed { i, hand ->
                            when (hand.result) {
                                BlackjackHandResult.Blackjack -> com.leah.honeycomb.Strings.get(StringKey.ResultHeadlineBlackjack, language) + " 🃏"
                                BlackjackHandResult.Win -> com.leah.honeycomb.Strings.format(StringKey.ResultHandWinFmt, language, i + 1)
                                BlackjackHandResult.Loss -> com.leah.honeycomb.Strings.format(StringKey.ResultHandLossFmt, language, i + 1)
                                BlackjackHandResult.Push -> com.leah.honeycomb.Strings.format(StringKey.ResultHandPushFmt, language, i + 1)
                                BlackjackHandResult.Bust -> com.leah.honeycomb.Strings.format(StringKey.ResultHandBustFmt, language, i + 1)
                                null -> ""
                            }
                        }.joinToString("  ·  ")
                    } else if (state.resultOutcome == BlackjackRoundOutcome.Push) {
                        com.leah.honeycomb.Strings.get(StringKey.ResultSubPush, language)
                    } else {
                        val net = state.lastNetResult
                        when {
                            net > 0 -> com.leah.honeycomb.Strings.format(StringKey.ResultSubNetPositiveFmt, language, net)
                            net < 0 -> com.leah.honeycomb.Strings.format(StringKey.ResultSubNetNegativeFmt, language, net)
                            else -> com.leah.honeycomb.Strings.get(StringKey.ResultSubEven, language)
                        }
                    }
                    val isWin = state.resultOutcome == BlackjackRoundOutcome.Win || state.resultOutcome == BlackjackRoundOutcome.Blackjack
                    val bannerScale = remember { Animatable(1f) }
                    // Continuous flash on top of the pop-in — ported from iOS's
                    // bannerWinFlash (BlackjackTouchView.swift:761): easeInOut(duration:
                    // 0.6).repeatForever(autoreverses: true). Kept as a separate
                    // Animatable multiplied into the same scaleX/scaleY below, rather
                    // than reusing bannerScale, so the flash's own animateTo calls never
                    // fight the pop-in's spring animateTo on the same Animatable — the
                    // flash loop only starts once the pop-in's animateTo above actually
                    // completes.
                    val bannerFlash = remember { Animatable(1f) }
                    LaunchedEffect(isWin) {
                        if (isWin) {
                            bannerScale.snapTo(1.4f)
                            bannerFlash.snapTo(1f)
                            bannerScale.animateTo(1f, animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy))
                            while (true) {
                                bannerFlash.animateTo(1.06f, animationSpec = tween(600, easing = FastOutSlowInEasing))
                                bannerFlash.animateTo(1f, animationSpec = tween(600, easing = FastOutSlowInEasing))
                            }
                        } else {
                            bannerScale.snapTo(1f)
                            bannerFlash.snapTo(1f)
                        }
                    }
                    val totalBannerScale = bannerScale.value * bannerFlash.value
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .shadow(
                                if (isWin) 32.dp else 0.dp,
                                RoundedCornerShape(24.dp),
                                spotColor = Color(0xFFFFD700).copy(alpha = 0.5f)
                            )
                            .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(24.dp))
                            .clickable(indication = null, interactionSource = remember { MutableInteractionSource() }) { dismissResultBannerEarly() }
                            .padding(horizontal = 40.dp, vertical = 36.dp)
                            .graphicsLayer(scaleX = totalBannerScale, scaleY = totalBannerScale)
                    ) {
                        Text(
                            outcomeText,
                            color = if (isWin) Color.Yellow else Color.White,
                            fontSize = 40.sp,
                            fontWeight = FontWeight.Black
                        )
                        // Matches iOS: the subline (per-hand breakdown or net credits) is
                        // entirely gated on free play, same as the dollar amount used to be
                        // here on its own — a split's per-hand breakdown was previously
                        // shown unconditionally, which iOS never does.
                        if (!viewModel.isFreePlay) {
                            Text(subline, color = Color.White, fontSize = if (state.playerHands.size > 1) 15.sp else 24.sp)
                        }
                    }
                }
            }
        }

        val playerArea = @Composable {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                val activeHand = state.playerHands.getOrNull(state.activeHandIndex)
                val playerText = if (state.phase == BlackjackPhase.Betting || activeHand == null) "YOU" else "YOU ${activeHand.value}" + (if (activeHand.isBust) " (Bust)" else "")
                Text(playerText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.graphicsLayer(alpha = resetFadeAlpha)
                ) {
                    if (state.playerHands.isEmpty()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(cardSpacing)) {
                            val placeholder = remember { com.leah.honeycomb.Card(suit = com.leah.honeycomb.Suit.Spades, rank = 1, faceUp = false) }
                            CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                            CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                        }
                    } else {
                        state.playerHands.forEach { hand ->
                            Row(horizontalArrangement = Arrangement.spacedBy(cardSpacing)) {
                                hand.cards.forEachIndexed { i, card ->
                                    key(card.id) {
                                        DealtCard(card = card, index = i, cardW = cardW, cardH = cardH)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        val controlsArea = @Composable {
            Column(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                if (state.phase == BlackjackPhase.Betting || state.phase == BlackjackPhase.Result) {
                    if (state.phase == BlackjackPhase.Result) {
                        Box(modifier = Modifier.padding(bottom = 16.dp)) {
                            ActionButton(Strings.get(StringKey.BtnNewBet, language), Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.resetIfRoundOver() })
                        }
                    }
                    if (viewModel.canRebuy) {
                        Box(modifier = Modifier.padding(bottom = 16.dp)) {
                            ActionButton(Strings.get(StringKey.BtnRebuy, language), Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.rebuy() })
                        }
                    }
                    
                    if (!viewModel.isFreePlay) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 16.dp) .horizontalScroll(rememberScrollState())) {
                            BetChip("1", Color.White, { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.addToBet(1) })
                            BetChip("5", Color(0xFFF44336), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.addToBet(5) })
                            BetChip("10", Color(0xFF2196F3), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.addToBet(10) })
                            BetChip("25", Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.addToBet(25) })
                            BetChip("2X", Color(0xFFFF9800), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.doubleBet() })
                        }
                    }
                    
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth(0.9f)) {
                        if (!viewModel.isFreePlay) {
                            Box(modifier = Modifier.weight(1f)) {
                                ActionButton(Strings.get(StringKey.BtnClearBet, language), Color.DarkGray, { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.clearBet() })
                            }
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            ActionButton(if (state.phase == BlackjackPhase.Result) Strings.get(StringKey.BtnReDeal, language) else Strings.get(StringKey.DealButton, language), Color(0xFFFFC107), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.deal() }, enabled = (viewModel.isFreePlay || state.sessionCredits >= state.currentBet))
                        }
                    }
                } else if (state.phase == BlackjackPhase.Playing) {
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth(0.9f)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth()) {
                            Box(modifier = Modifier.weight(1f)) {
                                ActionButton(Strings.get(StringKey.TouchActionHit, language), Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.hit() }, enabled = !viewModel.isDealerBlackjackPending)
                            }
                            Box(modifier = Modifier.weight(1f)) {
                                ActionButton(Strings.get(StringKey.TouchActionStand, language), Color(0xFFF44336), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.stand() }, enabled = !viewModel.isDealerBlackjackPending)
                            }
                        }
                        if (viewModel.canDouble || viewModel.canSplit) {
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth()) {
                                if (viewModel.canDouble) {
                                    Box(modifier = Modifier.weight(1f)) {
                                        ActionButton(Strings.get(StringKey.TouchActionDouble, language), Color(0xFF2196F3), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.doubleDown() }, enabled = !viewModel.isDealerBlackjackPending)
                                    }
                                }
                                if (viewModel.canSplit) {
                                    Box(modifier = Modifier.weight(1f)) {
                                        ActionButton(Strings.get(StringKey.TouchActionSplit, language), Color(0xFF9C27B0), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.split() }, enabled = !viewModel.isDealerBlackjackPending)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if (!isLandscape) {
            Column(modifier = Modifier.fillMaxSize().padding(8.dp)) {
                topBar()
                Box(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                    scoreCapsule()
                }
                Spacer(modifier = Modifier.height(24.dp))
                dealerArea()
                Spacer(modifier = Modifier.weight(1f))
                playerArea()
                Spacer(modifier = Modifier.height(24.dp))
                controlsArea()
            }
        } else {
            Column(modifier = Modifier.fillMaxSize().padding(8.dp)) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Box(modifier = Modifier.weight(1f)) {
                        topBar()
                    }
                    Box(modifier = Modifier.padding(top = 8.dp), contentAlignment = Alignment.Center) {
                        scoreCapsule()
                    }
                    Spacer(modifier = Modifier.weight(1f))
                }
                Row(modifier = Modifier.fillMaxSize().padding(top = 16.dp)) {
                    Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.TopEnd) {
                        playerArea()
                    }
                    Box(modifier = Modifier.width(180.dp), contentAlignment = Alignment.Center) {
                        controlsArea()
                    }
                    Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.TopStart) {
                        dealerArea()
                    }
                }
            }
        }

        // Overlay, not part of either orientation's layout flow above — centers on the
        // whole screen regardless of how tall the dealer/player areas are, matching
        // iOS's own resultOverlay declared outside its ScrollView content.
        resultOverlay()

        // Listed last (highest z-order), same as iOS/Windows: the burst renders in front of
        // the result banner rather than behind it.
        Box(modifier = Modifier.fillMaxSize()) {
            com.leah.honeycomb.WinParticleView(active = showParticles)
        }
    }
}
