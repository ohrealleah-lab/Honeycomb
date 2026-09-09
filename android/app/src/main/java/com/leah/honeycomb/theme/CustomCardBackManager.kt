package com.leah.honeycomb.theme

import android.content.Context
import android.net.Uri
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.leah.honeycomb.PreferencesHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer
import java.io.File
import java.util.UUID

// No user-visible name — identity is purely the generated id, matched by thumbnail in the
// picker. Removes the whole class of bugs where a custom import collides with a bundled
// deck's display name.
@Serializable
data class CustomCardBack(
    val id: String = UUID.randomUUID().toString(),
    val relativePath: String,
    val scale: Double = 1.0,
    val offsetXFraction: Double = 0.0,
    val offsetYFraction: Double = 0.0
)

class CustomCardBackManager(
    private val context: Context,
    private val dataStore: DataStore<Preferences>,
    private val coroutineScope: CoroutineScope,
    private val themeManager: ThemeManager
) {
    private val cardBacksKey = "custom_card_backs"
    private val deletedDefaultsKey = "deleted_default_card_backs"
    private val cardBackListSerializer = ListSerializer(CustomCardBack.serializer())
    private val stringSetSerializer = SetSerializer(String.serializer())

    private val _cardBacks = MutableStateFlow<List<CustomCardBack>>(emptyList())
    val cardBacks: StateFlow<List<CustomCardBack>> = _cardBacks

    private var deletedDefaultDecks: MutableSet<String> = mutableSetOf()

    private val storageDir: File by lazy {
        File(context.filesDir, "CardBacks").also { if (!it.exists()) it.mkdirs() }
    }

    init {
        // PreferencesHelper already falls back to defaultValue on a decode failure, so a
        // corrupted/incompatible persisted blob can't crash the app on launch here.
        deletedDefaultDecks = PreferencesHelper.getObjectSync(dataStore, deletedDefaultsKey, stringSetSerializer, emptySet()).toMutableSet()

        val decoded = PreferencesHelper.getObjectSync(dataStore, cardBacksKey, cardBackListSerializer, emptyList())
        val list = decoded.filter { File(storageDir, it.relativePath).exists() }

        _cardBacks.value = list
        if (list.size != decoded.size) {
            // Files for these entries are already gone — also clear any theme still
            // pointing at them, or the theme silently falls back with no explanation.
            val orphanedIds = decoded.map { it.id }.toSet() - list.map { it.id }.toSet()
            orphanedIds.forEach { themeManager.clearCardBackReferences(it) }
            save()
        }
    }

    private fun save() {
        PreferencesHelper.saveObjectAsync(dataStore, cardBacksKey, cardBackListSerializer, _cardBacks.value)
        PreferencesHelper.saveObjectAsync(dataStore, deletedDefaultsKey, stringSetSerializer, deletedDefaultDecks)
    }

    // Total available decks right now, custom + built-in-not-yet-deleted — mirrors the
    // Swift reference's "must keep at least one" guard so deleting the very last deck
    // (built-in or custom) is never possible, even once a delete UI is wired up to call
    // this.
    private fun availableDeckCount(): Int =
        _cardBacks.value.size + (builtinCardBackNames.size - deletedDefaultDecks.size)

    fun deleteCardBack(id: String) {
        if (availableDeckCount() <= 1) return
        val back = _cardBacks.value.find { it.id == id } ?: return
        val file = File(storageDir, back.relativePath)
        if (file.exists()) file.delete()
        _cardBacks.value = _cardBacks.value.filter { it.id != id }
        save()
        themeManager.clearCardBackReferences(id)
    }

    // Separate from deleteCardBack — built-in decks are identified by their fixed bundled
    // name (see CardView.kt's CardBackView), not a generated id.
    fun deleteDefaultCardBack(name: String) {
        if (availableDeckCount() <= 1) return
        deletedDefaultDecks.add(name)
        save()
        themeManager.clearCardBackReferences(name)
    }

    suspend fun addCardBack(uri: Uri): Result<Unit> = withContext(Dispatchers.IO) {
        ImageImportPipeline.importAndDownscale(context, uri, storageDir, maxDim = 1200).map { fileName ->
            _cardBacks.value = _cardBacks.value + CustomCardBack(relativePath = fileName)
            save()
        }
    }
}
