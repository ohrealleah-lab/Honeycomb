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
import java.io.File
import java.util.UUID

// No user-visible name — identity is purely the generated id, matched by thumbnail in the
// picker. Removes the whole class of bugs where a custom import collides with a bundled
// asset's display name.
@Serializable
data class CustomBackground(
    val id: String = UUID.randomUUID().toString(),
    val relativePath: String,
    val scale: Double = 1.0,
    val offsetX: Double = 0.0,
    val offsetY: Double = 0.0
)

class CustomBackgroundManager(
    private val context: Context,
    private val dataStore: DataStore<Preferences>,
    private val coroutineScope: CoroutineScope,
    private val themeManager: ThemeManager
) {
    private val backgroundsKey = "custom_backgrounds"
    private val serializer = ListSerializer(CustomBackground.serializer())

    private val _backgrounds = MutableStateFlow<List<CustomBackground>>(emptyList())
    val backgrounds: StateFlow<List<CustomBackground>> = _backgrounds

    // Computed once — the directory only needs creating the first time, not re-checked on
    // every access.
    private val storageDir: File by lazy {
        File(context.filesDir, "Backgrounds").also { if (!it.exists()) it.mkdirs() }
    }

    init {
        // PreferencesHelper already falls back to defaultValue on a decode failure, so a
        // corrupted/incompatible persisted blob can't crash the app on launch here.
        val decoded = PreferencesHelper.getObjectSync(dataStore, backgroundsKey, serializer, emptyList())
        val list = decoded.filter { File(storageDir, it.relativePath).exists() }

        _backgrounds.value = list
        if (list.size != decoded.size) {
            // Files for these entries are already gone — also clear any theme still
            // pointing at them, or the theme silently falls back with no explanation.
            val orphanedIds = decoded.map { it.id }.toSet() - list.map { it.id }.toSet()
            orphanedIds.forEach { themeManager.clearBackgroundReferences(it) }
            save()
        }
    }

    private fun save() {
        PreferencesHelper.saveObjectAsync(dataStore, backgroundsKey, serializer, _backgrounds.value)
    }

    fun deleteBackground(id: String) {
        val bg = _backgrounds.value.find { it.id == id } ?: return
        val file = File(storageDir, bg.relativePath)
        if (file.exists()) file.delete()

        _backgrounds.value = _backgrounds.value.filter { it.id != id }
        save()
        themeManager.clearBackgroundReferences(bg.id)
    }

    suspend fun addBackground(uri: Uri): Result<Unit> = withContext(Dispatchers.IO) {
        ImageImportPipeline.importAndDownscale(context, uri, storageDir, maxDim = 2400).map { fileName ->
            _backgrounds.value = _backgrounds.value + CustomBackground(relativePath = fileName)
            save()
        }
    }
}
