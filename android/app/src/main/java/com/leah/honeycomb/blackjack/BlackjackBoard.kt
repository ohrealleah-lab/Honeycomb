package com.leah.honeycomb.blackjack

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
import androidx.compose.runtime.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
            .clickable { onClick() },
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
        .clickable(enabled = enabled) { onClick() }
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
        val scoreCapsule = @Composable {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(24.dp),
                modifier = Modifier
                    .background(Color.Black.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 24.dp, vertical = 8.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("CREDITS", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text(if (!viewModel.isFreePlay) "${state.sessionCredits}" else "FREE", fontWeight = FontWeight.Bold, color = Color.Yellow)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("BET", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text("${state.currentBet}", fontWeight = FontWeight.Bold, color = Color.White)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("HANDS", fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White.copy(alpha = 0.7f))
                    Text("${state.handsDealt}", fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
        }

        Column(modifier = Modifier.fillMaxSize().padding(8.dp)) {
            // Top Bar
            Row(
                modifier = Modifier.fillMaxWidth().height(48.dp),
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
                Text("Blackjack", color = Color.White, fontWeight = FontWeight.Bold, modifier = Modifier.padding(end = 16.dp))
            }

            Box(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                scoreCapsule()
            }

            Spacer(modifier = Modifier.height(24.dp))
            
            // Dealer Area
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                val dealerText = if (state.phase == BlackjackPhase.Betting) "DEALER" else "DEALER ${state.dealerVisibleValue}"
                Text(dealerText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy((-40).dp)) {
                    if (state.dealerCards.isEmpty()) {
                        Box(modifier = Modifier.size(100.dp, 140.dp))
                    } else {
                        state.dealerCards.forEach { card ->
                            CardView(card = card, modifier = Modifier.size(100.dp, 140.dp))
                        }
                    }
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            // Result Overlay (if round over)
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
                    Text(outcomeText, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
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
            
            Spacer(modifier = Modifier.weight(1f))

            // Player Area
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                val activeHand = state.playerHands.getOrNull(state.activeHandIndex)
                val playerText = if (state.phase == BlackjackPhase.Betting || activeHand == null) "YOU" else "YOU ${activeHand.value}" + (if (activeHand.isBust) " (Bust)" else "")
                Text(playerText, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    if (state.playerHands.isEmpty()) {
                        Box(modifier = Modifier.size(100.dp, 140.dp))
                    } else {
                        state.playerHands.forEachIndexed { index, hand ->
                            Row(horizontalArrangement = Arrangement.spacedBy((-40).dp)) {
                                hand.cards.forEach { card ->
                                    CardView(card = card, modifier = Modifier.size(100.dp, 140.dp))
                                }
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Controls
            Column(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                if (state.phase == BlackjackPhase.Betting || state.phase == BlackjackPhase.Result) {
                    if (state.phase == BlackjackPhase.Result) {
                        Box(modifier = Modifier.padding(bottom = 16.dp)) {
                            ActionButton("New Bet", Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.resetIfRoundOver() })
                        }
                    }
                    if (viewModel.canRebuy) {
                        Box(modifier = Modifier.padding(bottom = 16.dp)) {
                            ActionButton("Rebuy", Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.rebuy() })
                        }
                    }
                    
                    if (!viewModel.isFreePlay) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(bottom = 16.dp)) {
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
                                ActionButton("Clear Bet", Color.DarkGray, { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.clearBet() })
                            }
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            ActionButton(if (state.phase == BlackjackPhase.Result) "Re-Deal" else "Deal", Color(0xFFFFC107), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.deal() }, enabled = (viewModel.isFreePlay || state.sessionCredits >= state.currentBet))
                        }
                    }
                } else if (state.phase == BlackjackPhase.Playing) {
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth(0.9f)) {
                        Box(modifier = Modifier.weight(1f)) {
                            ActionButton("Hit", Color(0xFF4CAF50), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.hit() }, enabled = !viewModel.isDealerBlackjackPending)
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            ActionButton("Stand", Color(0xFFF44336), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.stand() }, enabled = !viewModel.isDealerBlackjackPending)
                        }
                    }
                    
                    if (viewModel.canDouble || viewModel.canSplit) {
                        Spacer(modifier = Modifier.height(16.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth(0.9f)) {
                            if (viewModel.canDouble) {
                                Box(modifier = Modifier.weight(1f)) {
                                    ActionButton("Double", Color(0xFF2196F3), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.doubleDown() }, enabled = !viewModel.isDealerBlackjackPending)
                                }
                            }
                            if (viewModel.canSplit) {
                                Box(modifier = Modifier.weight(1f)) {
                                    ActionButton("Split", Color(0xFF9C27B0), { haptics.performHapticFeedback(HapticFeedbackType.LongPress); viewModel.split() }, enabled = !viewModel.isDealerBlackjackPending)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
