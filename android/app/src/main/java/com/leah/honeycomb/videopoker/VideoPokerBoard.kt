package com.leah.honeycomb.videopoker

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.leah.honeycomb.CardView

@Composable
private fun PayTableDialog(
    payTable: List<VideoPokerPayEntry>,
    currentBet: Int,
    language: AppLanguage,
    onDismiss: () -> Unit
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
                    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                        Text(
                            localizedHandName(entry.handName, language),
                            modifier = Modifier.weight(2f),
                            color = Color.White,
                            fontSize = 13.sp
                        )
                        for (bet in 1..5) {
                            Text(
                                "${entry.multipliers[bet - 1]}",
                                modifier = Modifier.weight(1f),
                                color = if (bet == currentBet) Color.Yellow else Color.White.copy(alpha = 0.85f),
                                fontWeight = if (bet == currentBet) FontWeight.Bold else FontWeight.Normal,
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

    if (showPayTable) {
        PayTableDialog(
            payTable = viewModel.payTable,
            currentBet = state.currentBet,
            language = language,
            onDismiss = { showPayTable = false }
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

        val topBar = @Composable {
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
            }
        }

        val resultText = @Composable {
            if (state.phase == VideoPokerPhase.Result) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    if (state.lastPayout > 0) {
                        Text(localizedHandName(state.lastHandName, language), color = Color.Yellow, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        Text("Win $${state.lastPayout}", color = Color.Yellow, fontSize = 20.sp)
                    } else {
                        Text(com.leah.honeycomb.Strings.get(StringKey.GameOver, language), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    }
                }
            } else if (state.phase == VideoPokerPhase.Holding) {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Text("Tap cards to hold, then Draw", color = Color.White, fontSize = 16.sp)
                }
            }
        }

        val cardsRow = @Composable {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy((-8).dp, Alignment.CenterHorizontally)
            ) {
                val config = androidx.compose.ui.platform.LocalConfiguration.current
                val cardW = ((config.screenWidthDp.dp - 32.dp) / 5).coerceAtMost(100.dp)
                val cardH = cardW * 1.4f
                if (state.hand.isEmpty()) {
                    repeat(5) {
                        CardView(card = com.leah.honeycomb.Card(suit = com.leah.honeycomb.Suit.Spades, rank = 1, faceUp = false), modifier = Modifier.size(cardW, cardH))
                    }
                } else {
                    state.hand.forEachIndexed { index, card ->
                        val isHeld = state.heldIndices.contains(index)
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            if (isHeld) {
                                Text("HELD", color = Color.Yellow, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                            } else {
                                Text(" ", fontSize = 12.sp)
                            }
                            Box(
                                modifier = Modifier
                                    .clickable(enabled = state.phase == VideoPokerPhase.Holding) {
                                        viewModel.toggleHold(index)
                                    }
                            ) {
                                CardView(card = card, modifier = Modifier.size(cardW, cardH))
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
                                .clickable { viewModel.decreaseBet() }
                                .padding(horizontal = 24.dp, vertical = 16.dp)
                            ) {
                                Text("-", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                            }
                            // Max Button
                            Box(modifier = Modifier
                                .background(Color(0xFFE67E22), RoundedCornerShape(12.dp))
                                .clickable { viewModel.maxBet() }
                                .padding(horizontal = 24.dp, vertical = 16.dp)
                            ) {
                                Text("Max", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                            }
                            // + Button
                            Box(modifier = Modifier
                                .background(Color(0xFF4CAF50), RoundedCornerShape(12.dp))
                                .clickable { viewModel.increaseBet() }
                                .padding(horizontal = 24.dp, vertical = 16.dp)
                            ) {
                                Text("+", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                            }
                        }
                    }
                    if (!viewModel.isFreePlay && state.sessionCredits < state.currentBet) {
                        Box(modifier = Modifier
                            .background(Color(0xFFFFC107), RoundedCornerShape(12.dp))
                            .clickable { viewModel.rebuy() }
                            .padding(horizontal = 48.dp, vertical = 16.dp)
                        ) {
                            Text("Rebuy", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                        }
                    } else {
                        Box(modifier = Modifier
                            .background(Color(0xFFFFC107), RoundedCornerShape(12.dp))
                            .clickable { viewModel.deal() }
                            .padding(horizontal = 48.dp, vertical = 16.dp)
                        ) {
                            Text("Deal", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 24.sp)
                        }
                    }
                } else if (state.phase == VideoPokerPhase.Holding) {
                    Box(modifier = Modifier
                        .background(Color(0xFF4CAF50), RoundedCornerShape(12.dp))
                        .clickable { viewModel.draw() }
                        .padding(horizontal = 48.dp, vertical = 16.dp)
                    ) {
                        Text("DRAW", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 24.sp)
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
                    Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.Center) {
                        cardsRow()
                    }
                    Column(modifier = Modifier.width(300.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                        resultText()
                        Spacer(modifier = Modifier.height(16.dp))
                        bottomControls()
                    }
                }
            }
        }
    }
}
