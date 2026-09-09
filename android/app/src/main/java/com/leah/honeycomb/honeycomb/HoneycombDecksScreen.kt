package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

// Deck management: pick which of the 5 saved 5-card decks is active, and edit a deck's
// composition from the player's unlocked-card bank. Backed by HoneycombProfileManager,
// which already persists everything — this screen is purely the missing UI over it.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HoneycombDecksScreen(
    viewModel: HoneycombViewModel,
    profileManager: HoneycombProfileManager,
    database: HoneycombDatabase,
    onBack: () -> Unit
) {
    val options by viewModel.options.collectAsState()
    val savedDecks by profileManager.savedDecks.collectAsState()
    val unlockedIds by profileManager.unlockedCardIds.collectAsState()

    var editingDeckIndex by remember { mutableStateOf<Int?>(null) }

    if (editingDeckIndex != null) {
        val idx = editingDeckIndex!!
        val deck = savedDecks.getOrNull(idx) ?: HoneycombDeckState()
        var selectedCardIds by remember(idx) { mutableStateOf(deck.cardIds) }

        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Edit ${deck.name.ifBlank { "Deck ${idx + 1}" }}") },
                    navigationIcon = {
                        IconButton(onClick = { editingDeckIndex = null }) {
                            Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                        }
                    },
                    actions = {
                        TextButton(
                            enabled = selectedCardIds.size == 5,
                            onClick = {
                                profileManager.saveDeck(idx, deck.name.ifBlank { "Deck ${idx + 1}" }, selectedCardIds)
                                editingDeckIndex = null
                            }
                        ) { Text("Save") }
                    }
                )
            }
        ) { padding ->
            Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                Text(
                    "${selectedCardIds.size} / 5 cards selected",
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium
                )
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(90.dp),
                    contentPadding = PaddingValues(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(unlockedIds.toList().sorted(), key = { it }) { cardId ->
                        val cardData = database.card(cardId) ?: return@items
                        val isSelected = selectedCardIds.contains(cardId)
                        Box(
                            modifier = Modifier
                                .aspectRatio(0.7f)
                                .clip(RoundedCornerShape(8.dp))
                                .background(if (isSelected) Color(0xFFEAD6AE) else Color.Transparent)
                                .clickable {
                                    selectedCardIds = if (isSelected) {
                                        selectedCardIds - cardId
                                    } else if (selectedCardIds.size < 5) {
                                        selectedCardIds + cardId
                                    } else {
                                        selectedCardIds
                                    }
                                }
                                .padding(4.dp)
                        ) {
                            HoneycombCardView(
                                card = HoneycombCard(data = cardData, owner = CardOwner.Player),
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }
            }
        }
        return
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Manage Decks") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Text(
                "${unlockedIds.size} / ${database.allCards.size} cards unlocked",
                style = MaterialTheme.typography.bodyMedium
            )
            Spacer(modifier = Modifier.height(16.dp))
            savedDecks.forEachIndexed { index, deck ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                        .clickable {
                            viewModel.updateOptions(options.copy(activeDeckIndex = index))
                        }
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                deck.name.ifBlank { "Deck ${index + 1}" },
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                "${deck.cardIds.size} / 5 cards",
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (options.activeDeckIndex == index) {
                                Icon(Icons.Filled.Star, contentDescription = "Active deck", tint = Color(0xFFDDA75B))
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                            OutlinedButton(onClick = { editingDeckIndex = index }) { Text("Edit") }
                        }
                    }
                }
            }
        }
    }
}
