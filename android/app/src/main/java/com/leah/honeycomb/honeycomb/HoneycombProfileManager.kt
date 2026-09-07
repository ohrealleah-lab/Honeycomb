package com.leah.honeycomb.honeycomb

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class HoneycombDeckState(
    var name: String = "",
    var cardIds: List<Int> = emptyList()
)

class HoneycombProfileManager(
    private val dataStore: DataStore<Preferences>,
    private val database: HoneycombDatabase
) {
    private val unlockedKey = stringPreferencesKey("honeycomb_unlocked_cards")
    private val decksKey = stringPreferencesKey("honeycomb_saved_decks")
    private val favoritesKey = stringPreferencesKey("honeycomb_favorite_cards")

    private val _unlockedCardIds = MutableStateFlow<Set<Int>>(emptySet())
    val unlockedCardIds: StateFlow<Set<Int>> = _unlockedCardIds

    private val _savedDecks = MutableStateFlow<List<HoneycombDeckState>>(emptyList())
    val savedDecks: StateFlow<List<HoneycombDeckState>> = _savedDecks

    private val _favoriteCardIds = MutableStateFlow<Set<Int>>(emptySet())
    val favoriteCardIds: StateFlow<Set<Int>> = _favoriteCardIds

    init {
        runBlocking { loadProfile() }
    }

    private suspend fun loadProfile() {
        val prefs = dataStore.data.first()
        
        val unlockedStr = prefs[unlockedKey]
        if (unlockedStr != null) {
            _unlockedCardIds.value = Json.decodeFromString<List<Int>>(unlockedStr).toSet()
        } else {
            val ones = database.randomCards(1, 3).map { it.id }
            val twos = database.randomCards(2, 2).map { it.id }
            val starters = (ones + twos).toSet()
            _unlockedCardIds.value = starters
            saveUnlockedCards()
        }

        val decksStr = prefs[decksKey]
        if (decksStr != null) {
            _savedDecks.value = Json.decodeFromString<List<HoneycombDeckState>>(decksStr)
        } else {
            val decks = MutableList(5) { HoneycombDeckState() }
            val starters = _unlockedCardIds.value.toList()
            if (starters.size == 5) {
                decks[0].name = "Default"
                decks[0].cardIds = starters
            }
            _savedDecks.value = decks
            saveDecks()
        }

        val favStr = prefs[favoritesKey]
        if (favStr != null) {
            _favoriteCardIds.value = Json.decodeFromString<List<Int>>(favStr).toSet()
        }
    }

    suspend fun unlockCard(id: Int) {
        _unlockedCardIds.value = _unlockedCardIds.value + id
        saveUnlockedCards()
    }

    val isCardBankFull: Boolean
        get() = _unlockedCardIds.value.size >= database.allCards.size

    companion object {
        private val defaultStarterComposition = listOf(1, 1, 1, 2, 2)

        fun computeStartOverDecks(
            currentDecks: List<HoneycombDeckState>,
            starLookup: (Int) -> Int?,
            randomCard: (Int) -> Int?
        ): List<HoneycombDeckState> {
            val decks = MutableList(5) { HoneycombDeckState() }
            decks[0].name = "Default"
            val previousCardIds = currentDecks[0].cardIds
            val starComposition = if (previousCardIds.isEmpty()) {
                defaultStarterComposition
            } else {
                previousCardIds.mapNotNull(starLookup)
            }
            decks[0].cardIds = starComposition.mapNotNull(randomCard)
            return decks
        }
    }

    suspend fun startOver() {
        val alreadyDrawn = mutableSetOf<Int>()
        val newDecks = computeStartOverDecks(
            currentDecks = _savedDecks.value,
            starLookup = { database.card(it)?.stars },
            randomCard = { stars ->
                val candidates = database.randomCards(stars, 5)
                val pick = candidates.firstOrNull { !alreadyDrawn.contains(it.id) } ?: candidates.firstOrNull()
                pick?.id?.let { alreadyDrawn.add(it) }
                pick?.id
            }
        )
        _savedDecks.value = newDecks
        _unlockedCardIds.value = newDecks[0].cardIds.toSet()
        _favoriteCardIds.value = emptySet()
        
        saveUnlockedCards()
        saveDecks()
        saveFavorites()
    }

    suspend fun toggleFavorite(id: Int) {
        val current = _favoriteCardIds.value
        if (current.contains(id)) {
            _favoriteCardIds.value = current - id
        } else {
            _favoriteCardIds.value = current + id
        }
        saveFavorites()
    }

    suspend fun saveDeck(index: Int, name: String, cardIds: List<Int>) {
        if (index !in _savedDecks.value.indices) return
        val current = _savedDecks.value.toMutableList()
        current[index] = current[index].copy(name = name, cardIds = cardIds)
        _savedDecks.value = current
        saveDecks()
    }

    private suspend fun saveUnlockedCards() {
        dataStore.edit { it[unlockedKey] = Json.encodeToString(_unlockedCardIds.value.toList()) }
    }

    private suspend fun saveFavorites() {
        dataStore.edit { it[favoritesKey] = Json.encodeToString(_favoriteCardIds.value.toList()) }
    }

    private suspend fun saveDecks() {
        dataStore.edit { it[decksKey] = Json.encodeToString(_savedDecks.value) }
    }
}
