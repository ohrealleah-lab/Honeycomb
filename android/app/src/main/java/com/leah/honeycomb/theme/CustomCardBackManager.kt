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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

@Serializable
data class CustomCardBack(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
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

    private var deletedDefaultDecks: MutableList<String> = mutableListOf()

    private val storageDir: File
        get() {
            val dir = File(context.filesDir, "CardBacks")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    init {
        val prefs = runBlocking { dataStore.data.first() }
        
        val deletedJson = prefs[deletedDefaultsKey]
        if (!deletedJson.isNullOrEmpty()) {
            deletedDefaultDecks = Json.decodeFromString<List<String>>(deletedJson).toMutableList()
        }

        val json = prefs[cardBacksKey]
        val list = if (!json.isNullOrEmpty()) {
            Json.decodeFromString<List<CustomCardBack>>(json).filter {
                File(storageDir, it.relativePath).exists()
            }
        } else emptyList()
        
        _cardBacks.value = list
        if (list.size != (json?.let { Json.decodeFromString<List<CustomCardBack>>(it).size } ?: 0)) {
            save()
        }
    }

    private fun save() {
        coroutineScope.launch {
            dataStore.edit { prefs ->
                prefs[cardBacksKey] = Json.encodeToString(_cardBacks.value)
                prefs[deletedDefaultsKey] = Json.encodeToString(deletedDefaultDecks)
            }
        }
    }

    fun deleteCardBack(name: String) {
        val bg = _cardBacks.value.find { it.name == name }
        if (bg != null) {
            val file = File(storageDir, bg.relativePath)
            if (file.exists()) file.delete()
            _cardBacks.value = _cardBacks.value.filter { it.name != name }
        } else {
            // Might be a default one
            if (!deletedDefaultDecks.contains(name)) {
                deletedDefaultDecks.add(name)
            }
        }
        
        save()
        themeManager.clearCardBackReferences(name)
    }

    fun addCardBack(uri: Uri, name: String): Result<Unit> {
        val cleanedName = name.trim()
        if (cleanedName.isEmpty() || _cardBacks.value.any { it.name.equals(cleanedName, ignoreCase = true) }) {
            return Result.failure(Exception("Invalid or duplicate name"))
        }

        try {
            val pfd = context.contentResolver.openFileDescriptor(uri, "r") ?: return Result.failure(Exception("Cannot open file"))
            val sizeBytes = pfd.statSize
            if (sizeBytes > 25 * 1024 * 1024) {
                pfd.close()
                return Result.failure(Exception("File exceeds 25MB limit"))
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
            pfd.close()
            
            if (bitmap == null) return Result.failure(Exception("Failed to decode image"))

            val fileName = "${UUID.randomUUID()}.png"
            val file = File(storageDir, fileName)
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            
            val newDeck = CustomCardBack(
                name = cleanedName,
                relativePath = fileName
            )
            _cardBacks.value = _cardBacks.value + newDeck
            save()
            
            return Result.success(Unit)
        } catch (e: Exception) {
            return Result.failure(e)
        }
    }
}
