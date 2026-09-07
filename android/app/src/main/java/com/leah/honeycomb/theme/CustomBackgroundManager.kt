package com.leah.honeycomb.theme

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
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
data class CustomBackground(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val relativePath: String,
    val scale: Double = 1.0,
    val offsetX: Double = 0.0,
    val offsetY: Double = 0.0,
    val dominantColorRed: Double? = null,
    val dominantColorGreen: Double? = null,
    val dominantColorBlue: Double? = null
)

class CustomBackgroundManager(
    private val context: Context,
    private val dataStore: DataStore<Preferences>,
    private val coroutineScope: CoroutineScope,
    private val themeManager: ThemeManager
) {
    private val backgroundsKey = stringPreferencesKey("custom_backgrounds")

    private val _backgrounds = MutableStateFlow<List<CustomBackground>>(emptyList())
    val backgrounds: StateFlow<List<CustomBackground>> = _backgrounds

    private val storageDir: File
        get() {
            val dir = File(context.filesDir, "Backgrounds")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    init {
        val prefs = runBlocking { dataStore.data.first() }
        val json = prefs[backgroundsKey]
        val list = if (!json.isNullOrEmpty()) {
            Json.decodeFromString<List<CustomBackground>>(json).filter {
                File(storageDir, it.relativePath).exists()
            }
        } else emptyList()
        
        _backgrounds.value = list
        if (list.size != (json?.let { Json.decodeFromString<List<CustomBackground>>(it).size } ?: 0)) {
            save()
        }
    }

    private fun save() {
        coroutineScope.launch {
            dataStore.edit { prefs ->
                prefs[backgroundsKey] = Json.encodeToString(_backgrounds.value)
            }
        }
    }

    fun deleteBackground(id: String) {
        val bg = _backgrounds.value.find { it.id == id } ?: return
        val file = File(storageDir, bg.relativePath)
        if (file.exists()) file.delete()
        
        _backgrounds.value = _backgrounds.value.filter { it.id != id }
        save()
        themeManager.clearBackgroundReferences(bg.name)
    }

    fun addBackground(uri: Uri, name: String): Result<Unit> {
        val cleanedName = name.trim()
        if (cleanedName.isEmpty() || _backgrounds.value.any { it.name.equals(cleanedName, ignoreCase = true) }) {
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
            val maxDim = 2400
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
            
            val newBg = CustomBackground(
                name = cleanedName,
                relativePath = fileName,
                dominantColorRed = 0.5, // placeholder
                dominantColorGreen = 0.5,
                dominantColorBlue = 0.5
            )
            _backgrounds.value = _backgrounds.value + newBg
            save()
            
            return Result.success(Unit)
        } catch (e: Exception) {
            return Result.failure(e)
        }
    }
}
