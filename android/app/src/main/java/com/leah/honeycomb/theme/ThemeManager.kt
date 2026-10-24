package com.leah.honeycomb.theme

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.leah.honeycomb.PreferencesHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.SetSerializer
import kotlinx.serialization.builtins.serializer

class ThemeManager(private val dataStore: DataStore<Preferences>, private val coroutineScope: CoroutineScope) {
    private val themesKey = "solibee_themes"
    private val deletedDefaultThemesKey = "solibee_deleted_default_themes"
    private val activeThemeIdKey = stringPreferencesKey("solibee_active_theme_id")
    private val showFeltVignetteKey = booleanPreferencesKey("solibee_show_felt_vignette")
    private val themeListSerializer = ListSerializer(SoliBeeTheme.serializer())
    private val stringSetSerializer = SetSerializer(String.serializer())

    private val _themes = MutableStateFlow<List<SoliBeeTheme>>(emptyList())
    val themes: StateFlow<List<SoliBeeTheme>> = _themes

    private val _activeThemeId = MutableStateFlow<String?>(null)
    val activeThemeId: StateFlow<String?> = _activeThemeId

    private val _showFeltVignette = MutableStateFlow<Boolean>(true)
    val showFeltVignette: StateFlow<Boolean> = _showFeltVignette

    private var deletedDefaultThemes: MutableSet<String> = mutableSetOf()

    private val saveMutex = Mutex()

    companion object {
        // Matched by name when loading, so a player who already has a theme with one of
        // these names keeps their own copy; only names they don't have yet get added.
        // Hint glow and top-bar button colors aren't part of Android themes yet.
        val defaultThemes = listOf(
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000001",
                name = "Default", cardBackTheme = "Solibee", feltColor = FeltColorType.FeltGreen,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 1.0, bgGreen = 1.0, bgBlue = 1.0,
                    blackSuitRed = 0.0667, blackSuitGreen = 0.0667, blackSuitBlue = 0.0667,
                    redSuitRed = 0.7686, redSuitGreen = 0.1176, redSuitBlue = 0.1176
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000006",
                name = "Honey", cardBackTheme = "Solibee", feltColor = FeltColorType.Custom,
                customFeltRed = 0.2314, customFeltGreen = 0.1647, customFeltBlue = 0.0784,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 1.0, bgGreen = 0.9647, bgBlue = 0.8627,
                    blackSuitRed = 0.0549, blackSuitGreen = 0.0353, blackSuitBlue = 0.0118,
                    redSuitRed = 0.7529, redSuitGreen = 0.1882, redSuitBlue = 0.1098
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000007",
                name = "Sunset", cardBackTheme = "Sunset", feltColor = FeltColorType.Custom,
                customFeltRed = 0.1176, customFeltGreen = 0.2275, customFeltBlue = 0.2824,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 0.9922, bgGreen = 0.9529, bgBlue = 0.8902,
                    blackSuitRed = 0.0784, blackSuitGreen = 0.0471, blackSuitBlue = 0.0235,
                    redSuitRed = 0.7412, redSuitGreen = 0.2392, redSuitBlue = 0.102
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000008",
                name = "Moogle", cardBackTheme = "Moogle", feltColor = FeltColorType.Custom,
                customFeltRed = 0.0784, customFeltGreen = 0.0784, customFeltBlue = 0.0784,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 1.0, bgGreen = 1.0, bgBlue = 1.0,
                    blackSuitRed = 0.0, blackSuitGreen = 0.0, blackSuitBlue = 0.0,
                    redSuitRed = 0.8157, redSuitGreen = 0.1255, redSuitBlue = 0.1804
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000002",
                name = "Pareidolic 2", cardBackTheme = "Pareidolic 2", feltColor = FeltColorType.Custom,
                customFeltRed = 0.3608, customFeltGreen = 0.3451, customFeltBlue = 0.651,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 1.0, bgGreen = 1.0, bgBlue = 1.0,
                    blackSuitRed = 0.0667, blackSuitGreen = 0.0667, blackSuitBlue = 0.0667,
                    redSuitRed = 0.7686, redSuitGreen = 0.1176, redSuitBlue = 0.1176
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000003",
                name = "Desert", cardBackTheme = "Vulpera", feltColor = FeltColorType.Desert,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 1.0, bgGreen = 0.9804, bgBlue = 0.9529,
                    blackSuitRed = 0.0667, blackSuitGreen = 0.0667, blackSuitBlue = 0.0667,
                    redSuitRed = 0.7686, redSuitGreen = 0.1176, redSuitBlue = 0.1176
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000004",
                name = "Forest", cardBackTheme = "Forest", feltColor = FeltColorType.Custom,
                customFeltRed = 0.3686, customFeltGreen = 0.3294, customFeltBlue = 0.3137,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 0.902, bgGreen = 0.8118, bgBlue = 0.6745,
                    blackSuitRed = 0.1333, blackSuitGreen = 0.0353, blackSuitBlue = 0.0392,
                    redSuitRed = 0.6588, redSuitGreen = 0.0941, redSuitBlue = 0.102
                )
            ),
            SoliBeeTheme(
                id = "3B1E1B7A-3F0C-4B8D-9C1E-000000000005",
                name = "OceanSky", cardBackTheme = "Pareidolic", feltColor = FeltColorType.Custom,
                customFeltRed = 0.1412, customFeltGreen = 0.4706, customFeltBlue = 0.5608,
                customCardColors = CustomCardColorGroup(
                    isEnabled = true,
                    bgRed = 0.949, bgGreen = 0.9961, bgBlue = 1.0,
                    blackSuitRed = 0.0784, blackSuitGreen = 0.1098, blackSuitBlue = 0.1255,
                    redSuitRed = 0.6902, redSuitGreen = 0.1882, redSuitBlue = 0.4314
                )
            )
        )
    }

    init {
        // PreferencesHelper already falls back to defaultValue on a decode failure, so a
        // corrupted/incompatible persisted blob can't crash the app on launch here.
        deletedDefaultThemes = PreferencesHelper.getObjectSync(dataStore, deletedDefaultThemesKey, stringSetSerializer, emptySet()).toMutableSet()

        val persistedThemes = PreferencesHelper.getObjectSync(dataStore, themesKey, themeListSerializer, emptyList())
        val loadedThemes = if (persistedThemes.isNotEmpty()) {
            persistedThemes.toMutableList()
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

        val prefs = runBlocking { dataStore.data.first() }
        _activeThemeId.value = prefs[activeThemeIdKey]
        _showFeltVignette.value = prefs[showFeltVignetteKey] ?: true

        // Ensure we save the merged list back if there were changes
        val persistedHasAllDefaults = defaultThemes.none { defaultTheme -> 
            !deletedDefaultThemes.contains(defaultTheme.name.lowercase()) && 
            persistedThemes.none { it.name.lowercase() == defaultTheme.name.lowercase() }
        }
        if (!persistedHasAllDefaults) {
            save()
        }
    }

    private fun save() {
        coroutineScope.launch {
            saveMutex.withLock {
                PreferencesHelper.setObject(dataStore, themesKey, themeListSerializer, _themes.value)
                PreferencesHelper.setObject(dataStore, deletedDefaultThemesKey, stringSetSerializer, deletedDefaultThemes)
                dataStore.edit { prefs ->
                    _activeThemeId.value?.let { prefs[activeThemeIdKey] = it } ?: prefs.remove(activeThemeIdKey)
                    prefs[showFeltVignetteKey] = _showFeltVignette.value
                }
            }
        }
    }

    fun setShowFeltVignette(show: Boolean) {
        _showFeltVignette.value = show
        save()
    }

    private fun getOrCreateActiveTheme(): SoliBeeTheme {
        val currentId = _activeThemeId.value
        val currentTheme = if (currentId != null) {
            _themes.value.find { it.id == currentId }
        } else null

        if (currentTheme != null) return currentTheme

        val newTheme = SoliBeeTheme(
            id = java.util.UUID.randomUUID().toString(),
            name = "Custom",
            cardBackTheme = "Solibee",
            feltColor = FeltColorType.FeltGreen
        )
        addTheme(newTheme)
        setActiveTheme(newTheme.id)
        return newTheme
    }

    fun updateActiveThemeCardBack(cardBackTheme: String) {
        val theme = getOrCreateActiveTheme()
        updateTheme(theme.copy(cardBackTheme = cardBackTheme))
    }

    fun updateActiveThemeBackground(feltColor: FeltColorType, customBackgroundId: String? = null) {
        val theme = getOrCreateActiveTheme()
        updateTheme(theme.copy(feltColor = feltColor, customBackgroundName = customBackgroundId))
    }

    fun updateActiveThemeCustomColors(colors: CustomCardColorGroup) {
        val theme = getOrCreateActiveTheme()
        updateTheme(theme.copy(customCardColors = colors))
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

    // `backgroundId` matches SoliBeeTheme.customBackgroundName, which stores a custom
    // background's generated id (custom backgrounds have no user-visible name).
    fun clearBackgroundReferences(backgroundId: String) {
        var changed = false
        val newThemes = _themes.value.toMutableList()
        for (i in newThemes.indices) {
            if (newThemes[i].customBackgroundName == backgroundId) {
                newThemes[i] = newThemes[i].copy(customBackgroundName = null)
                changed = true
            }
        }
        if (changed) {
            _themes.value = newThemes
            save()
        }
    }

    // `value` matches SoliBeeTheme.cardBackTheme, which stores either a built-in deck's
    // fixed name or a custom card back's generated id (custom card backs have no
    // user-visible name) — this function clears either kind identically.
    fun clearCardBackReferences(value: String, fallback: String = "Solibee") {
        var changed = false
        val newThemes = _themes.value.toMutableList()
        for (i in newThemes.indices) {
            if (newThemes[i].cardBackTheme == value) {
                newThemes[i] = newThemes[i].copy(cardBackTheme = fallback)
                changed = true
            }
        }
        if (changed) {
            _themes.value = newThemes
            save()
        }
    }
}
