package com.leah.honeycomb.videopoker

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.repeatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.leah.honeycomb.CardView
import com.leah.honeycomb.rememberFireOnceTrigger
import com.leah.honeycomb.audio.UISound
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
private fun PayTableDialog(
    payTable: List<VideoPokerPayEntry>,
    currentBet: Int,
    language: AppLanguage,
    onDismiss: () -> Unit,
    // Both default to "nothing is pulsing" so callers that don't care about the
    // win-pulse (there are none right now, but keeps this dialog usable standalone)
    // still compile without wiring it up.
    isHit: (VideoPokerPayEntry) -> Boolean = { false },
    winFlash: Boolean = false
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(12.dp), color = Color(0xFF14321F)) {
            Column(modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
                Text("Pay Table", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(modifier = Modifier.fillMaxWidth()) {
                    Spacer(modifier = Modifier.weight(2f))
                    for (bet in 1..5) {
                        Text(
                            "$bet",
                            modifier = Modifier.weight(1f),
                            color = if (bet == currentBet) Color.Yellow else Color.White.copy(alpha = 0.7f),
                            fontWeight = if (bet == currentBet) FontWeight.Bold else FontWeight.Normal,
                            fontSize = 13.sp,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
                for (entry in payTable) {
                    val hit = isHit(entry)
                    // Mirrors VideoPokerTouchView.swift's isHit row: bounded 10-rep
                    // autoreversing pulse driven by winFlash, not repeatForever — a
                    // forever-repeating animation started while winFlash is true is
                    // never explicitly canceled once winFlash flips back to false (a
                    // later hand's isHit going false doesn't stop an already-running
                    // repeat), so it would keep pulsing indefinitely after the win
                    // that triggered it. 10 reps (~3s at 300ms/leg) comfortably
                    // outlasts the ~450ms window winFlash is actually true for, then
                    // settles and stays stopped.
                    val rowAlpha = remember(entry.handName) { Animatable(0.7f) }
                    // Keyed on `hit` alone, not `winFlash` too — winFlash and hit become
                    // true together when a win resolves, but winFlash clears ~450ms later
                    // on its own timer while hit stays true for the rest of the hand. Keying
                    // on winFlash as well would restart (and cancel) this bounded repeat
                    // right as it flips false, kicking off a brand new ~3s cycle instead of
                    // letting the already-running one finish and settle as intended above.
                    LaunchedEffect(hit) {
                        if (hit) {
                            rowAlpha.animateTo(
                                targetValue = if (winFlash) 1f else 0.7f,
                                animationSpec = repeatable(
                                    iterations = 10,
                                    animation = tween(300, easing = LinearEasing),
                                    repeatMode = RepeatMode.Reverse
                                )
                            )
                        } else {
                            rowAlpha.snapTo(0.7f)
                        }
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                if (hit) Color.Yellow.copy(alpha = rowAlpha.value) else Color.Transparent,
                                RoundedCornerShape(4.dp)
                            )
                            .padding(vertical = 3.dp, horizontal = if (hit) 4.dp else 0.dp)
                    ) {
                        Text(
                            localizedHandName(entry.handName, language),
                            modifier = Modifier.weight(2f),
                            color = if (hit) Color.Black else Color.White,
                            fontWeight = if (hit) FontWeight.Black else FontWeight.Normal,
                            fontSize = 13.sp
                        )
                        for (bet in 1..5) {
                            Text(
                                "${entry.multipliers[bet - 1]}",
                                modifier = Modifier.weight(1f),
                                color = if (hit) Color.Black else if (bet == currentBet) Color.Yellow else Color.White.copy(alpha = 0.85f),
                                fontWeight = if (bet == currentBet || hit) FontWeight.Bold else FontWeight.Normal,
                                fontSize = 13.sp,
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center
                            )
                        }
                    }
                }
            }
        }
    }
}

// Display-only translation for a poker hand name
private fun localizedHandName(handName: String, language: AppLanguage): String {
    val key = when (handName) {
        "Royal Flush" -> StringKey.HandRoyalFlush
        "Jacks or Better" -> StringKey.HandJacksOrBetter
        "High Card" -> StringKey.HandHighCard
        "One Pair" -> StringKey.HandOnePair
        "Two Pair" -> StringKey.HandTwoPair
        "Three of a Kind" -> StringKey.HandThreeOfAKind
        "Flush" -> StringKey.HandFlush
        "Straight" -> StringKey.HandStraight
        "Straight Flush" -> StringKey.HandStraightFlush
        "Four of a Kind" -> StringKey.HandFourOfAKind
        "Full House" -> StringKey.HandFullHouse
        "Five of a Kind" -> StringKey.HandFiveOfAKind
        "Four Aces" -> StringKey.HandFourAces
        "Four 2s–4s" -> StringKey.HandFour2s4s
        "Four Deuces" -> StringKey.HandFourDeuces
        "Natural Royal Flush" -> StringKey.HandNaturalRoyalFlush
        "Wild Royal Flush" -> StringKey.HandWildRoyalFlush
        "No Win" -> StringKey.HandNoWin
        else -> return handName
    }
    return com.leah.honeycomb.Strings.get(key, language)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VideoPokerBoard(
    viewModel: VideoPokerViewModel,
    onMenuTap: () -> Unit,
    onOptions: () -> Unit,
    onThemes: () -> Unit = {}
) {
    val language by com.leah.honeycomb.LocalAppContainer.current.language.collectAsState()
    val state by viewModel.state.collectAsState()
    val options by viewModel.options.collectAsState()
    var showQuitDialog by remember { mutableStateOf(false) }
    var showPayTable by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val activeBanner by viewModel.activeBanner.collectAsState()
    val manuallyDismissBanners by viewModel.sharedOptions.manuallyDismissBanners.collectAsState()
    LaunchedEffect(Unit) { viewModel.checkLoadingBanner() }
    LaunchedEffect(state.phase) {
        if (state.phase == VideoPokerPhase.Result) {
            kotlinx.coroutines.delay(1500)
            viewModel.checkOutOfCredits()
        }
    }

    // Full-screen result banner: shows ~1.0s after the hand resolves (so the player
    // sees the final hand first), stays up ~4.0s, then auto-hides — or the player can
    // tap the scrim/card to deal the next hand immediately. Mirrors iOS's
    // showResultBanner/resultBannerShowTask/resultAnimationTask/resultHideTask
    // (VideoPokerTouchView.swift:213-251). Separate from `state.phase == Result` itself
    // (which stays true the whole time, showing the Deal/chip controls underneath) —
    // this only gates the modal banner's own visibility.
    var showResultBanner by remember { mutableStateOf(false) }
    val resultBannerScope = rememberCoroutineScope()
    var resultBannerJob by remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
    LaunchedEffect(state.phase) {
        resultBannerJob?.cancel()
        if (state.phase == VideoPokerPhase.Result) {
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
    fun dealFromResultBanner() {
        resultBannerJob?.cancel()
        showResultBanner = false
        viewModel.deal()
        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
    }

    // Mirrors VideoPokerTouchView.swift's winFlash: flips true for ~0.45s right as a
    // winning hand resolves, driving the pay-table row pulse, the result headline pop
    // below, and the confetti burst's own trigger — all three read the same underlying
    // event (a hand just won), not three independent ones, same as iOS sharing one flag
    // across them. FireOnceTrigger (see GameSessionHelpers.kt) makes the show-then-hide
    // immune to `state.phase`/lastHandName/lastPayout changing again mid-window (e.g. a
    // fast redeal within 450ms) — the LaunchedEffect below only needs to detect the
    // rising edge and call fire(); it no longer needs an `else` branch to avoid getting
    // stuck, since active only ever becomes true via fire() itself.
    val winTrigger = rememberFireOnceTrigger(holdMs = 450)
    LaunchedEffect(state.phase, state.lastHandName, state.lastPayout) {
        if (state.phase == VideoPokerPhase.Result && state.lastPayout > 0) {
            winTrigger.fire()
        }
    }
    val winFlash = winTrigger.active
    // Confetti burst, fired alongside winFlash — mirrors iOS's winFlashTask, which sets
    // both winFlash and showParticles together (winFlash clears after 0.45s, the burst
    // itself keeps running to its own ~1.4s completion regardless).
    val showParticles = winTrigger.active

    // Result headline pop (VideoPokerTouchView.swift:553-554): scaleEffect(1.1 while
    // winFlash) driven by a spring, matching BlackjackBoard's bannerScale idiom.
    val headlineScale = remember { Animatable(1f) }
    LaunchedEffect(winFlash) {
        headlineScale.animateTo(
            targetValue = if (winFlash) 1.1f else 1f,
            animationSpec = spring(dampingRatio = 0.45f, stiffness = 632f)
        )
    }

    // Staggered deal-in (VideoPokerTouchView.swift:291-300, animateDeal()): each of
    // the 5 cards lifts from below and fades in, 0.06s apart, settling from a small
    // starting rotation ("wobble"). Triggered by handsDealt (only bumped by deal(),
    // never by draw()) so redraws after holding don't replay the stagger.
    val cardOffsetY = remember { List(5) { Animatable(40f) } }
    val cardAlpha = remember { List(5) { Animatable(0f) } }
    val cardRotation = remember { List(5) { Animatable(0f) } }
    LaunchedEffect(state.handsDealt) {
        if (state.hand.isEmpty()) return@LaunchedEffect
        val startAngles = listOf(-8f, -5f, 0f, 5f, 8f)
        for (i in 0 until 5) {
            cardOffsetY[i].snapTo(40f)
            cardAlpha[i].snapTo(0f)
            cardRotation[i].snapTo(startAngles[i])
        }
        for (i in 0 until 5) {
            launch {
                delay(i * 60L)
                launch { cardOffsetY[i].animateTo(0f, spring(dampingRatio = 0.5f, stiffness = 632f)) }
                launch { cardAlpha[i].animateTo(1f, spring(dampingRatio = 0.5f, stiffness = 632f)) }
                launch { cardRotation[i].animateTo(0f, spring(dampingRatio = 0.4f, stiffness = 987f)) }
            }
        }
    }

    if (showPayTable) {
        PayTableDialog(
            payTable = viewModel.payTable,
            currentBet = state.currentBet,
            language = language,
            onDismiss = { showPayTable = false },
            isHit = { entry ->
                state.phase == VideoPokerPhase.Result &&
                    state.lastPayout > 0 &&
                    state.lastHandName == entry.handName
            },
            winFlash = winFlash
        )
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
        val scoreCapsule = @Composable {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    .clickable { showPayTable = true }
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
                    IconButton(onClick = { if (state.phase == VideoPokerPhase.Holding) showQuitDialog = true else onMenuTap() }) {
                        Icon(Icons.Default.GridView, contentDescription = "Menu", tint = Color.White)
                    }
                    IconButton(onClick = onOptions) {
                        Icon(Icons.Default.Settings, contentDescription = "Options", tint = Color.White)
                    }
                    IconButton(onClick = onThemes) {
                        Icon(Icons.Default.Palette, contentDescription = "Themes", tint = Color.White)
                    }
                }
            }
        }

        // Holding-phase hint only now — the Result-phase content below moved into
        // resultOverlay (a full-screen modal), since it isn't the same kind of thing as
        // this inline hint text and doesn't belong in the normal layout flow.
        val resultText = @Composable {
            if (state.phase == VideoPokerPhase.Holding) {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Text(com.leah.honeycomb.Strings.get(StringKey.TapHoldDrawHint, language), color = Color.White, fontSize = 16.sp)
                }
            }
        }

        // Full-screen win/lose overlay — matches iOS's resultOverlay (ZStack: a dimmed
        // scrim behind a dark banner card, tap-anywhere-to-deal-the-next-hand, no X
        // button, gold glow only on a win). Gated on showResultBanner (its own timed
        // show/hide), not state.phase == Result directly — the Deal/chip controls
        // underneath stay in the normal layout the whole time state.phase == Result.
        val resultOverlay = @Composable {
            if (showResultBanner) {
                val isWin = state.lastPayout > 0
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.45f))
                        .clickable(indication = null, interactionSource = remember { MutableInteractionSource() }) { dealFromResultBanner() }
                        .zIndex(260f),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .shadow(
                                if (isWin) 24.dp else 0.dp,
                                RoundedCornerShape(28.dp),
                                spotColor = Color(0xFFFFD700).copy(alpha = 0.5f)
                            )
                            .background(Color.Black.copy(alpha = 0.75f), RoundedCornerShape(28.dp))
                            .clickable(indication = null, interactionSource = remember { MutableInteractionSource() }) { dealFromResultBanner() }
                            .padding(horizontal = 40.dp, vertical = 32.dp)
                    ) {
                        if (isWin) {
                            // Matches iOS's resultHandNameFmt ("%@!") rather than the bare
                            // hand name with no exclamation, and resultCreditsWonFmt ("+%d
                            // Credits") rather than hardcoded "Win $N" — same class of copy
                            // drift as Blackjack's outcome text had (see BlackjackBoard.kt).
                            Text(
                                com.leah.honeycomb.Strings.format(StringKey.ResultHandNameFmt, language, localizedHandName(state.lastHandName, language)),
                                color = Color.Yellow,
                                fontSize = 40.sp,
                                fontWeight = FontWeight.Black,
                                modifier = Modifier.graphicsLayer(scaleX = headlineScale.value, scaleY = headlineScale.value)
                            )
                            if (!viewModel.isFreePlay) {
                                Text(com.leah.honeycomb.Strings.format(StringKey.ResultCreditsWonFmt, language, state.lastPayout), color = Color.White, fontSize = 24.sp)
                            }
                        } else {
                            Text(
                                com.leah.honeycomb.Strings.get(StringKey.NotTodayPartner, language),
                                color = Color.Yellow,
                                fontSize = 40.sp,
                                fontWeight = FontWeight.Black
                            )
                            if (!viewModel.isFreePlay) {
                                Text(com.leah.honeycomb.Strings.format(StringKey.ResultCreditsLostFmt, language, state.currentBet), color = Color.White, fontSize = 24.sp)
                            }
                        }
                    }
                }
            }
        }

        val cardsRow = @Composable {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy((-8).dp, Alignment.CenterHorizontally)
            ) {
                val config = androidx.compose.ui.platform.LocalConfiguration.current
                val cardW = remember(config.screenWidthDp) { ((config.screenWidthDp.dp - 32.dp) / 5).coerceAtMost(100.dp) }
                val cardH = cardW * 1.4f
                if (state.hand.isEmpty()) {
                    val placeholder = remember { com.leah.honeycomb.Card(suit = com.leah.honeycomb.Suit.Spades, rank = 1, faceUp = false) }
                    repeat(5) {
                        CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                    }
                } else {
                    state.hand.forEachIndexed { index, card ->
                        key(card.id) {
                            val isHeld = state.heldIndices.contains(index)
                            // Held-card lift (VideoPokerTouchView.swift:499,503): a held card
                            // rises by 18dp while holding is in progress, eased in/out over
                            // 150ms.
                            val lifting = isHeld && state.phase == VideoPokerPhase.Holding
                            val liftDp by animateFloatAsState(
                                targetValue = if (lifting) -18f else 0f,
                                animationSpec = tween(150, easing = FastOutSlowInEasing)
                            )
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                if (isHeld) {
                                    Text("HELD", color = Color.Yellow, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                } else {
                                    Text(" ", fontSize = 12.sp)
                                }
                                Box(
                                    modifier = Modifier
                                        .clickable(enabled = state.phase == VideoPokerPhase.Holding) {
                                            haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                            viewModel.toggleHold(index)
                                        }
                                        .offset(y = (cardOffsetY[index].value + liftDp).dp)
                                        .graphicsLayer {
                                            alpha = cardAlpha[index].value
                                            rotationZ = cardRotation[index].value
                                        }
                                ) {
                                    CardView(card = card, modifier = Modifier.size(cardW, cardH))
                                }
                            }
                        }
                    }
                }
            }
        }

        val bottomControls = @Composable {
            Column(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                if (state.phase == VideoPokerPhase.Deal || state.phase == VideoPokerPhase.Result) {
                    if (!viewModel.isFreePlay) {
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.padding(bottom = 16.dp)) {
                            // - Button
                            Box(modifier = Modifier
                                .background(Color(0xFF4CAF50), RoundedCornerShape(12.dp))
                                .clickable { UISound.click(); viewModel.decreaseBet() }
                                .padding(horizontal = 24.dp, vertical = 16.dp)
                            ) {
                                Text("-", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                            }
                            // Max Button
                            Box(modifier = Modifier
                                .background(Color(0xFFE67E22), RoundedCornerShape(12.dp))
                                .clickable { UISound.click(); viewModel.maxBet() }
                                .padding(horizontal = 24.dp, vertical = 16.dp)
                            ) {
                                Text(com.leah.honeycomb.Strings.get(StringKey.TouchBetMaxButton, language), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                            }
                            // + Button
                            Box(modifier = Modifier
                                .background(Color(0xFF4CAF50), RoundedCornerShape(12.dp))
                                .clickable { UISound.click(); viewModel.increaseBet() }
                                .padding(horizontal = 24.dp, vertical = 16.dp)
                            ) {
                                Text("+", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                            }
                        }
                    }
                    if (!viewModel.isFreePlay && state.sessionCredits < state.currentBet) {
                        Box(modifier = Modifier
                            .background(Color(0xFFFFC107), RoundedCornerShape(12.dp))
                            .clickable { UISound.click(); viewModel.rebuy() }
                            .padding(horizontal = 48.dp, vertical = 16.dp)
                        ) {
                            Text(com.leah.honeycomb.Strings.get(StringKey.BtnRebuy, language), color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                        }
                    } else {
                        Box(modifier = Modifier
                            .background(Color(0xFFFFC107), RoundedCornerShape(12.dp))
                            .clickable { UISound.click(); haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.deal() }
                            .padding(horizontal = 48.dp, vertical = 16.dp)
                        ) {
                            Text(com.leah.honeycomb.Strings.get(StringKey.DealButton, language), color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                        }
                    }
                } else if (state.phase == VideoPokerPhase.Holding) {
                    Box(modifier = Modifier
                        .background(Color(0xFF4CAF50), RoundedCornerShape(12.dp))
                        .clickable { UISound.click(); haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.draw() }
                        .padding(horizontal = 48.dp, vertical = 16.dp)
                    ) {
                        Text(com.leah.honeycomb.Strings.get(StringKey.BtnDraw, language), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
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
                Spacer(modifier = Modifier.weight(1f))
                resultText()
                Spacer(modifier = Modifier.height(16.dp))
                cardsRow()
                Spacer(modifier = Modifier.weight(1f))
                bottomControls()
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
                Row(modifier = Modifier.fillMaxSize().padding(top = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        resultText()
                        Spacer(modifier = Modifier.height(8.dp))
                        cardsRow()
                        Spacer(modifier = Modifier.height(8.dp))
                        bottomControls()
                    }
                }
            }
        }

        // Overlay, not part of either orientation's layout flow above — centers on the
        // whole screen regardless of how tall the cards/controls areas are, matching
        // iOS's own resultOverlay declared outside its content stack.
        resultOverlay()

        // Listed last (highest z-order) — matches iOS/Windows: the burst renders in front of
        // the result banner/pay-table pulse rather than behind it.
        Box(modifier = Modifier.fillMaxSize()) {
            com.leah.honeycomb.WinParticleView(active = showParticles)
        }
    }
}
