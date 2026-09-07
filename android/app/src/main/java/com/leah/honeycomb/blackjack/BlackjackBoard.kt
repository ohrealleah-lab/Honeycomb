package com.leah.honeycomb.blackjack

import androidx.compose.foundation.background
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.leah.honeycomb.CardView

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
                        Text("Blackjack", fontSize = 18.sp, fontWeight = FontWeight.Bold)
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
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF550000), titleContentColor = Color.White, actionIconContentColor = Color.White, navigationIconContentColor = Color.White)
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF880000))
                .padding(padding)
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Dealer Area
                Spacer(modifier = Modifier.height(16.dp))
                Text("Dealer: ${if (state.phase == BlackjackPhase.Playing) "?" else state.dealerValue}", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.Center) {
                    state.dealerCards.forEach { card ->
                        CardView(card = card, modifier = Modifier.size(70.dp, 98.dp).padding(4.dp))
                    }
                }
                
                Spacer(modifier = Modifier.weight(1f))
                
                // Result Overlay (if round over)
                if (state.phase == BlackjackPhase.Result) {
                    Card(
                        modifier = Modifier.padding(16.dp),
                        colors = CardDefaults.cardColors(containerColor = Color.Black.copy(alpha = 0.7f))
                    ) {
                        Column(
                            modifier = Modifier.padding(24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = when (state.resultOutcome) {
                                    BlackjackRoundOutcome.Blackjack -> "Blackjack!"
                                    BlackjackRoundOutcome.Win -> "You Win!"
                                    BlackjackRoundOutcome.Push -> "Push"
                                    BlackjackRoundOutcome.Bust -> "Bust"
                                    BlackjackRoundOutcome.Loss -> "Dealer Wins"
                                    else -> "Result"
                                },
                                color = Color.White,
                                fontSize = 32.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            if (!viewModel.isFreePlay) {
                                Text(
                                    text = if (state.lastNetResult >= 0) "+$${state.lastNetResult}" else "-$${-state.lastNetResult}",
                                    color = if (state.lastNetResult >= 0) Color.Green else Color.Red,
                                    fontSize = 24.sp
                                )
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.weight(1f))
                
                // Player Area
                Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
                    state.playerHands.forEachIndexed { index, hand ->
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            val isFocus = state.phase == BlackjackPhase.Playing && index == state.activeHandIndex
                            val titleColor = if (isFocus) Color.Yellow else Color.White
                            Text(
                                text = "Player: ${hand.value}" + (if (hand.isBust) " (Bust)" else ""),
                                color = titleColor,
                                fontWeight = if (isFocus) FontWeight.Bold else FontWeight.Normal
                            )
                            Row {
                                hand.cards.forEach { card ->
                                    CardView(card = card, modifier = Modifier.size(70.dp, 98.dp).padding(4.dp))
                                }
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(16.dp))
                
                // Controls
                if (state.phase == BlackjackPhase.Betting || state.phase == BlackjackPhase.Result) {
                    if (state.phase == BlackjackPhase.Result) {
                        Button(onClick = { viewModel.resetIfRoundOver() }) {
                            Text("New Bet")
                        }
                    }
                    if (viewModel.canRebuy) {
                        Button(onClick = { viewModel.rebuy() }) {
                            Text("Rebuy")
                        }
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Button(onClick = { viewModel.clearBet() }) { Text("Clear") }
                        Button(onClick = { viewModel.addToBet(1) }) { Text("+1") }
                        Button(onClick = { viewModel.addToBet(5) }) { Text("+5") }
                        Button(onClick = { viewModel.doubleBet() }) { Text("x2") }
                        Button(onClick = { viewModel.deal() }, enabled = (viewModel.isFreePlay || state.sessionCredits >= state.currentBet)) { 
                            Text(if (state.phase == BlackjackPhase.Result) "Re-Deal" else "Deal") 
                        }
                    }
                } else if (state.phase == BlackjackPhase.Playing) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Button(onClick = { viewModel.hit() }, enabled = !viewModel.isDealerBlackjackPending) { Text("Hit") }
                        Button(onClick = { viewModel.stand() }, enabled = !viewModel.isDealerBlackjackPending) { Text("Stand") }
                        Button(onClick = { viewModel.doubleDown() }, enabled = viewModel.canDouble && !viewModel.isDealerBlackjackPending) { Text("Double") }
                        Button(onClick = { viewModel.split() }, enabled = viewModel.canSplit && !viewModel.isDealerBlackjackPending) { Text("Split") }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}
