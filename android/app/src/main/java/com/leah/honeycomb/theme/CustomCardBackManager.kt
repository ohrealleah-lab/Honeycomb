package com.leah.honeycomb.theme

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream
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
    private val cardBacksKey = stringPreferencesKey("custom_card_backs")
    private val deletedDefaultsKey = stringPreferencesKey("deleted_default_card_backs")

    private val _cardBacks = MutableStateFlow<List<CustomCardBack>>(emptyList())
    val cardBacks: StateFlow<List<CustomCardBack>> = _cardBacks

    private var deletedDefaultDecks: MutableSet<String> = mutableSetOf()

    private val storageDir: File by lazy {
        File(context.filesDir, "CardBacks").also { if (!it.exists()) it.mkdirs() }
    }

    init {
        val prefs = runBlocking { dataStore.data.first() }

        val deletedJson = prefs[deletedDefaultsKey]
        if (!deletedJson.isNullOrEmpty()) {
            deletedDefaultDecks = try {
                Json.decodeFromString<List<String>>(deletedJson).toMutableSet()
            } catch (e: Exception) {
                mutableSetOf()
            }
        }

        val json = prefs[cardBacksKey]
        // Decode failures fall back to an empty list instead of throwing out of init —
        // an uncaught exception here would crash the app on every subsequent launch.
        val decoded = if (!json.isNullOrEmpty()) {
            try {
                Json.decodeFromString<List<CustomCardBack>>(json)
            } catch (e: Exception) {
                emptyList()
            }
        } else emptyList()

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
        coroutineScope.launch {
            dataStore.edit { prefs ->
                prefs[cardBacksKey] = Json.encodeToString(_cardBacks.value)
                prefs[deletedDefaultsKey] = Json.encodeToString(deletedDefaultDecks.toList())
            }
        }
    }

    fun deleteCardBack(id: String) {
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
        deletedDefaultDecks.add(name)
        save()
        themeManager.clearCardBackReferences(name)
    }

    suspend fun addCardBack(uri: Uri): Result<Unit> = withContext(Dispatchers.IO) {
        var pfd: android.os.ParcelFileDescriptor? = null
        try {
            pfd = context.contentResolver.openFileDescriptor(uri, "r")
                ?: return@withContext Result.failure(Exception("Cannot open file"))
            val sizeBytes = pfd.statSize
            if (sizeBytes > 25 * 1024 * 1024) {
                return@withContext Result.failure(Exception("File exceeds 25MB limit"))
            }

            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFileDescriptor(pfd.fileDescriptor, null, options)

            var scale = 1
            val maxDim = 1200 // Max 1200px for card backs
            while (options.outWidth / scale > maxDim || options.outHeight / scale > maxDim) {
                scale *= 2
            }

            val decodeOptions = BitmapFactory.Options().apply { inSampleSize = scale }
            val bitmap = BitmapFactory.decodeFileDescriptor(pfd.fileDescriptor, null, decodeOptions)

            if (bitmap == null) return@withContext Result.failure(Exception("Failed to decode image"))

            val fileName = "${UUID.randomUUID()}.png"
            val file = File(storageDir, fileName)
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            val newDeck = CustomCardBack(relativePath = fileName)
            _cardBacks.value = _cardBacks.value + newDeck
            save()

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        } finally {
            pfd?.close()
        }
    }
}
