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
import com.leah.honeycomb.PreferencesHelper
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer

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
        val prefs = try {
            dataStore.data.first()
        } catch (e: Exception) {
            null
        }
        
        val unlockedStr = prefs?.get(unlockedKey)
        var decodeUnlockedFailed = false
        if (unlockedStr != null) {
            try {
                _unlockedCardIds.value = Json.decodeFromString<List<Int>>(unlockedStr).toSet()
            } catch (e: Exception) {
                decodeUnlockedFailed = true
            }
        }
        
        if (unlockedStr == null || decodeUnlockedFailed) {
            val ones = database.randomCards(1, 3).map { it.id }
            val twos = database.randomCards(2, 2).map { it.id }
            val starters = (ones + twos).toSet()
            _unlockedCardIds.value = starters
            saveUnlockedCards()
        }

        val decksStr = prefs?.get(decksKey)
        var decodeDecksFailed = false
        if (decksStr != null) {
            try {
                _savedDecks.value = Json.decodeFromString<List<HoneycombDeckState>>(decksStr)
            } catch (e: Exception) {
                decodeDecksFailed = true
            }
        }
        
        if (decksStr == null || decodeDecksFailed) {
            val decks = MutableList(5) { HoneycombDeckState() }
            val starters = _unlockedCardIds.value.toList()
            if (starters.size == 5) {
                decks[0].name = "Default"
                decks[0].cardIds = starters
            }
            _savedDecks.value = decks
            saveDecks()
        }

        val favStr = prefs?.get(favoritesKey)
        if (favStr != null) {
            try {
                _favoriteCardIds.value = Json.decodeFromString<List<Int>>(favStr).toSet()
            } catch (e: Exception) {}
        }
    }

    fun unlockCard(id: Int) {
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

    fun startOver() {
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

    fun toggleFavorite(id: Int) {
        val current = _favoriteCardIds.value
        if (current.contains(id)) {
            _favoriteCardIds.value = current - id
        } else {
            _favoriteCardIds.value = current + id
        }
        saveFavorites()
    }

    fun saveDeck(index: Int, name: String, cardIds: List<Int>) {
        if (index !in _savedDecks.value.indices) return
        val current = _savedDecks.value.toMutableList()
        current[index] = current[index].copy(name = name, cardIds = cardIds)
        _savedDecks.value = current
        saveDecks()
    }

    private fun saveUnlockedCards() {
        PreferencesHelper.saveObjectAsync(dataStore, "honeycomb_unlocked_cards", ListSerializer(Int.serializer()), _unlockedCardIds.value.toList())
    }

    private fun saveFavorites() {
        PreferencesHelper.saveObjectAsync(dataStore, "honeycomb_favorite_cards", ListSerializer(Int.serializer()), _favoriteCardIds.value.toList())
    }

    private fun saveDecks() {
        PreferencesHelper.saveObjectAsync(dataStore, "honeycomb_saved_decks", ListSerializer(HoneycombDeckState.serializer()), _savedDecks.value)
    }
}
