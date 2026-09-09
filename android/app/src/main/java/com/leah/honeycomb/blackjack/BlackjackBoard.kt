package com.leah.honeycomb.blackjack
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.*
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.Alignment
import com.leah.honeycomb.Strings
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.leah.honeycomb.CardView

@Composable
fun BetChip(amount: String, color: Color, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(50.dp)
            .background(color, CircleShape)
            .border(2.dp, Color.White, CircleShape)
            .clickable { UISound.click(); onClick() },
        contentAlignment = Alignment.Center
    ) {
        Box(modifier = Modifier.size(40.dp).border(1.dp, Color.White.copy(alpha=0.5f), CircleShape))
        Text(amount, color = if (color == Color.White) Color.Black else Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
    }
}

@Composable
fun ActionButton(text: String, color: Color, onClick: () -> Unit, enabled: Boolean = true) {
    Box(modifier = Modifier
        .background(if (enabled) color else Color.Gray, RoundedCornerShape(12.dp))
        .clickable(enabled = enabled) { UISound.click(); onClick() }
        .padding(horizontal = 24.dp, vertical = 16.dp)
        .fillMaxWidth()
    ) {
        Text(text, color = if (color == Color(0xFFFFC107) && enabled) Color.Black else Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.align(Alignment.Center))
    }
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
                Row(horizontalArrangement = Arrangement.spacedBy(cardSpacing)) {
                    if (state.dealerCards.isEmpty()) {
                        val placeholder = remember { com.leah.honeycomb.Card(suit = com.leah.honeycomb.Suit.Spades, rank = 1, faceUp = false) }
                        CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                        CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                    } else {
                        state.dealerCards.forEach { card ->
                            CardView(card = card, modifier = Modifier.size(cardW, cardH))
                        }
                    }
                }
            }
        }

        val resultOverlay = @Composable {
            if (state.phase == BlackjackPhase.Result) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    val outcomeText = when (state.resultOutcome) {
                        BlackjackRoundOutcome.Blackjack -> com.leah.honeycomb.Strings.get(StringKey.TouchResultBlackjack, language)
                        BlackjackRoundOutcome.Win -> com.leah.honeycomb.Strings.get(StringKey.TouchResultWin, language)
                        BlackjackRoundOutcome.Push -> com.leah.honeycomb.Strings.get(StringKey.TouchResultPush, language)
                        BlackjackRoundOutcome.Bust -> com.leah.honeycomb.Strings.get(StringKey.TouchResultBust, language)
                        BlackjackRoundOutcome.Loss -> com.leah.honeycomb.Strings.get(StringKey.TouchResultLoss, language)
                        else -> ""
                    }
                    val isWin = state.resultOutcome == BlackjackRoundOutcome.Win || state.resultOutcome == BlackjackRoundOutcome.Blackjack
                    val bannerScale = remember { Animatable(1f) }
                    LaunchedEffect(state.phase, state.resultOutcome) {
                        if (isWin) {
                            bannerScale.snapTo(1.4f)
                            bannerScale.animateTo(1f, animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy))
                        } else {
                            bannerScale.snapTo(1f)
                        }
                    }
                    Text(
                        outcomeText,
                        color = if (isWin) Color.Yellow else Color.White,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.graphicsLayer(scaleX = bannerScale.value, scaleY = bannerScale.value)
                    )
                    if (state.playerHands.size > 1) {
                        // A split round's headline only reflects the aggregate outcome (e.g. "Win" if
                        // any hand won), which loses the fact that another hand may have lost or
                        // pushed — show the per-hand breakdown instead so a split result is never
                        // misreported as a clean win/loss. Matches shared/localizedBlackjackResult.
                        val perHandText = state.playerHands.mapIndexed { i, hand ->
                            val label = when (hand.result) {
                                BlackjackHandResult.Blackjack -> com.leah.honeycomb.Strings.get(StringKey.TouchResultBlackjack, language)
                                BlackjackHandResult.Win -> com.leah.honeycomb.Strings.get(StringKey.TouchResultWin, language)
                                BlackjackHandResult.Loss -> com.leah.honeycomb.Strings.get(StringKey.TouchResultLoss, language)
                                BlackjackHandResult.Push -> com.leah.honeycomb.Strings.get(StringKey.TouchResultPush, language)
                                BlackjackHandResult.Bust -> com.leah.honeycomb.Strings.get(StringKey.TouchResultBust, language)
                                null -> ""
                            }
                            "Hand ${i + 1}: $label"
                        }.joinToString("  ·  ")
                        Text(perHandText, color = Color.White.copy(alpha = 0.85f), fontSize = 15.sp)
                    }
                    if (!viewModel.isFreePlay) {
                        Text(
                            text = if (state.lastNetResult >= 0) "+$${state.lastNetResult}" else "-$${-state.lastNetResult}",
                            color = if (state.lastNetResult >= 0) Color.Green else Color.Red,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold
                        )
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
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    if (state.playerHands.isEmpty()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(cardSpacing)) {
                            val placeholder = remember { com.leah.honeycomb.Card(suit = com.leah.honeycomb.Suit.Spades, rank = 1, faceUp = false) }
                            CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                            CardView(card = placeholder, modifier = Modifier.size(cardW, cardH))
                        }
                    } else {
                        state.playerHands.forEach { hand ->
                            Row(horizontalArrangement = Arrangement.spacedBy(cardSpacing)) {
                                hand.cards.forEach { card ->
                                    key(card.id) {
                                        CardView(card = card, modifier = Modifier.size(cardW, cardH))
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
                resultOverlay()
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
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            resultOverlay()
                            controlsArea()
                        }
                    }
                    Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.TopStart) {
                        dealerArea()
                    }
                }
            }
        }
    }
}
