package com.leah.honeycomb.theme

import android.content.Context
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
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class ThemeManager(private val dataStore: DataStore<Preferences>, private val coroutineScope: CoroutineScope) {
    private val themesKey = stringPreferencesKey("solibee_themes")
    private val activeThemeIdKey = stringPreferencesKey("solibee_active_theme_id")
    private val deletedDefaultThemesKey = stringPreferencesKey("solibee_deleted_default_themes")

    private val _themes = MutableStateFlow<List<SoliBeeTheme>>(emptyList())
    val themes: StateFlow<List<SoliBeeTheme>> = _themes

    private val _activeThemeId = MutableStateFlow<String?>(null)
    val activeThemeId: StateFlow<String?> = _activeThemeId

    private var deletedDefaultThemes: MutableSet<String> = mutableSetOf()

    companion object {
        val defaultThemes = listOf(
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000001",
                name = "Default", cardBackTheme = "Solibee", feltColor = FeltColorType.FeltGreen
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000002",
                name = "Pareidolic 2", cardBackTheme = "Pareidolic 2", feltColor = FeltColorType.Custom,
                customFeltRed = 0.5925555229187012, customFeltGreen = 0.5882400274276733, customFeltBlue = 0.8116011023521423
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000003",
                name = "Desert", cardBackTheme = "Vulpera", feltColor = FeltColorType.Desert
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000004",
                name = "Forest", cardBackTheme = "Forest", feltColor = FeltColorType.Custom,
                customFeltRed = 0.5211737751960754, customFeltGreen = 0.4769634008407593, customFeltBlue = 0.4559733271598816
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000005",
                name = "OceanSky", cardBackTheme = "Pareidolic", feltColor = FeltColorType.Custom,
                customFeltRed = 0.5867433547973633, customFeltGreen = 0.9626139998435974, customFeltBlue = 0.9703466296195984,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 0.8808431029319763, bgGreen = 0.9917027354240417, bgBlue = 0.9941582083702087,
                    redSuitRed = 0.7544758915901184, redSuitGreen = 0.3275292217731476, redSuitBlue = 0.5698546767234802
                )
            )
        )
    }

    init {
        val prefs = runBlocking { dataStore.data.first() }
        
        val deletedJson = prefs[deletedDefaultThemesKey]
        if (!deletedJson.isNullOrEmpty()) {
            deletedDefaultThemes = Json.decodeFromString<List<String>>(deletedJson).toMutableSet()
        }

        val themesJson = prefs[themesKey]
        val loadedThemes = if (!themesJson.isNullOrEmpty()) {
            Json.decodeFromString<List<SoliBeeTheme>>(themesJson).toMutableList()
        } else {
            defaultThemes.filter { !deletedDefaultThemes.contains(it.name.lowercase()) }.toMutableList()
        }

        // Add missing defaults if they weren't explicitly deleted
        for (defaultTheme in defaultThemes) {
            val lowerName = defaultTheme.name.lowercase()
            if (!deletedDefaultThemes.contains(lowerName)) {
                if (loadedThemes.none { it.name.lowercase() == lowerName }) {
                    loadedThemes.add(defaultTheme)
                }
            }
        }

        _themes.value = loadedThemes
        _activeThemeId.value = prefs[activeThemeIdKey]

        // Ensure we save the merged list back
        save()
    }

    private fun save() {
        coroutineScope.launch {
            dataStore.edit { prefs ->
                prefs[themesKey] = Json.encodeToString(_themes.value)
                prefs[deletedDefaultThemesKey] = Json.encodeToString(deletedDefaultThemes.toList())
                _activeThemeId.value?.let { prefs[activeThemeIdKey] = it } ?: prefs.remove(activeThemeIdKey)
            }
        }
    }

    fun setActiveTheme(id: String) {
        _activeThemeId.value = id
        save()
    }

    fun addTheme(theme: SoliBeeTheme) {
        val newThemes = _themes.value.toMutableList()
        newThemes.add(theme)
        _themes.value = newThemes
        save()
    }

    fun updateTheme(theme: SoliBeeTheme) {
        val newThemes = _themes.value.toMutableList()
        val index = newThemes.indexOfFirst { it.id == theme.id }
        if (index != -1) {
            newThemes[index] = theme
            _themes.value = newThemes
            save()
        }
    }

    fun deleteTheme(id: String) {
        val newThemes = _themes.value.toMutableList()
        val theme = newThemes.find { it.id == id } ?: return
        newThemes.removeAll { it.id == id }
        
        val lowercasedName = theme.name.lowercase()
        if (defaultThemes.any { it.name.lowercase() == lowercasedName }) {
            deletedDefaultThemes.add(lowercasedName)
        }
        
        if (_activeThemeId.value == id) {
            _activeThemeId.value = null
        }
        
        _themes.value = newThemes
        save()
    }

    fun clearBackgroundReferences(name: String) {
        var changed = false
        val newThemes = _themes.value.toMutableList()
        for (i in newThemes.indices) {
            if (newThemes[i].customBackgroundName == name) {
                newThemes[i] = newThemes[i].copy(customBackgroundName = null)
                changed = true
            }
        }
        if (changed) {
            _themes.value = newThemes
            save()
        }
    }

    fun clearCardBackReferences(name: String, fallback: String = "Solibee") {
        var changed = false
        val newThemes = _themes.value.toMutableList()
        for (i in newThemes.indices) {
            if (newThemes[i].cardBackTheme == name) {
                newThemes[i] = newThemes[i].copy(cardBackTheme = fallback)
                changed = true
            }
        }
        if (changed) {
            _themes.value = newThemes
            save()
        }
    }

    fun clearFaceArtReferences(relativePath: String) {
        var changed = false
        val newThemes = _themes.value.toMutableList()
        for (i in newThemes.indices) {
            val faceArts = newThemes[i].faceArts.toMutableList()
            if (faceArts.removeAll { it.relativePath == relativePath }) {
                newThemes[i] = newThemes[i].copy(faceArts = faceArts)
                changed = true
            }
        }
        if (changed) {
            _themes.value = newThemes
            save()
        }
    }
}
