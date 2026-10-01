package com.leah.honeycomb.honeycomb

import com.leah.honeycomb.tr

import com.leah.honeycomb.StringKey

import com.leah.honeycomb.trf

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
        // Same rarity caps as Mac/iOS/Windows — an invalid deck can't be saved.
        val rarityError = HoneycombProfileManager.deckRarityError(selectedCardIds) { database.card(it)?.stars }

        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(trf(StringKey.EditItemFmt, deck.name.ifBlank { trf(StringKey.DeckSlotDefaultNameFmt, idx + 1) })) },
                    navigationIcon = {
                        IconButton(onClick = { editingDeckIndex = null }) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = com.leah.honeycomb.tr(StringKey.Back))
                        }
                    },
                    actions = {
                        TextButton(
                            enabled = selectedCardIds.size == 5 && rarityError == null,
                            onClick = {
                                // A blank name stays blank — the list shows the localized "Deck N"
                                // default, so the saved name never bakes in one language.
                                profileManager.saveDeck(idx, deck.name, selectedCardIds)
                                editingDeckIndex = null
                            }
                        ) { Text(tr(StringKey.Save)) }
                    }
                )
            }
        ) { padding ->
            Column(modifier = Modifier.fillMaxSize().padding(padding)) {
                Text(
                    com.leah.honeycomb.trf(StringKey.DeckSelectedCountFmt, selectedCardIds.size),
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    tr(StringKey.DeckRulesHint),
                    modifier = Modifier.padding(horizontal = 16.dp),
                    style = MaterialTheme.typography.bodySmall
                )
                if (rarityError != null) {
                    Text(
                        tr(rarityError),
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error
                    )
                }
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
                title = { Text(tr(StringKey.SheetTitleMac)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = com.leah.honeycomb.tr(StringKey.Back))
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Text(
                com.leah.honeycomb.trf(StringKey.CardBankCountFmt, unlockedIds.size, database.allCards.size),
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
                                deck.name.ifBlank { trf(StringKey.DeckSlotDefaultNameFmt, index + 1) },
                                style = MaterialTheme.typography.titleMedium
                            )
                            Text(
                                com.leah.honeycomb.trf(StringKey.DeckCardCountFmt, deck.cardIds.size),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (options.activeDeckIndex == index) {
                                Icon(Icons.Filled.Star, contentDescription = com.leah.honeycomb.tr(StringKey.DeckActiveBadge), tint = Color(0xFFDDA75B))
                                Spacer(modifier = Modifier.width(8.dp))
                            }
                            OutlinedButton(onClick = { editingDeckIndex = index }) { Text(tr(StringKey.Edit)) }
                        }
                    }
                }
            }
        }
    }
}
