package com.leah.honeycomb.videopoker

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.leah.honeycomb.CardView

// Display-only translation for a poker hand name — internal comparisons (pay-table row
// highlighting) stay keyed on the English name from the paytable; this only swaps in
// translated text at the point of rendering, mirroring iOS's localizedHandName. Variant
// names (Jacks or Better, Deuces Wild, Bonus Poker) are deliberately left untranslated,
// matching iOS's localizedVariantName — they're the actual names of these game variants.
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

    Scaffold(containerColor = Color.Transparent, 
        topBar = {
            TopAppBar(
                title = { 
                    Column {
                        Text(options.variant.name, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        if (!viewModel.isFreePlay) {
                            Text("Credits: $${state.sessionCredits} | Bet: $${state.currentBet}", fontSize = 12.sp)
                        } else {
                            Text("Free Play", fontSize = 12.sp)
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onMenuTap) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onThemes) {
                        Icon(Icons.Filled.Palette, contentDescription = "Themes")
                    }
                    IconButton(onClick = onOptions, enabled = viewModel.canOpenOptions) {
                        Icon(Icons.Filled.Settings, contentDescription = "Options")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF000044), titleContentColor = Color.White, actionIconContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Paytable Header
                Card(
                    modifier = Modifier.fillMaxWidth().padding(8.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.Blue.copy(alpha=0.3f))
                ) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        viewModel.payTable.forEach { entry ->
                            val payout = entry.payout(state.currentBet)
                            val isWin = state.phase == VideoPokerPhase.Result && state.lastHandName == entry.handName
                            Row(
                                modifier = Modifier.fillMaxWidth().background(if (isWin) Color.Yellow.copy(alpha=0.3f) else Color.Transparent),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(localizedHandName(entry.handName, language), color = if (isWin) Color.Yellow else Color.White, fontSize = 12.sp)
                                Text(payout.toString(), color = if (isWin) Color.Yellow else Color.White, fontSize = 12.sp)
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.weight(1f))
                
                // Result Banner
                if (state.phase == VideoPokerPhase.Result) {
                    if (state.lastPayout > 0) {
                        Text(localizedHandName(state.lastHandName, language), color = Color.Yellow, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                        Text("Win $${state.lastPayout}", color = Color.Yellow, fontSize = 20.sp)
                    } else {
                        Text(com.leah.honeycomb.Strings.get(StringKey.GameOver, language), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    }
                }
                
                Spacer(modifier = Modifier.weight(1f))
                
                // Cards
                Row(
                    modifier = Modifier.fillMaxWidth().padding(8.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    if (state.hand.isEmpty()) {
                        repeat(5) {
                            Box(modifier = Modifier.size(60.dp, 84.dp).border(1.dp, Color.Black.copy(alpha=0.3f), RoundedCornerShape(4.dp)))
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
                                        .padding(2.dp)
                                ) {
                                    CardView(card = card, modifier = Modifier.size(60.dp, 84.dp))
                                }
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(16.dp))
                
                // Controls
                if (state.phase == VideoPokerPhase.Deal || state.phase == VideoPokerPhase.Result) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        if (!viewModel.isFreePlay) {
                            Button(onClick = { viewModel.decreaseBet() }) { Text("Bet -") }
                            Button(onClick = { viewModel.increaseBet() }) { Text("Bet +") }
                            Button(onClick = { viewModel.maxBet() }) { Text("Max Bet") }
                        }
                        if (!viewModel.isFreePlay && state.sessionCredits < state.currentBet) {
                            Button(onClick = { viewModel.rebuy() }) { 
                                Text("Rebuy") 
                            }
                        } else {
                            Button(onClick = { viewModel.deal() }) { 
                                Text(if (state.phase == VideoPokerPhase.Result) "Re-Deal" else "Deal") 
                            }
                        }
                    }
                } else if (state.phase == VideoPokerPhase.Holding) {
                    Button(
                        onClick = { viewModel.draw() },
                        modifier = Modifier.padding(16.dp).fillMaxWidth(0.5f)
                    ) { 
                        Text("Draw") 
                    }
                }
                
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}
