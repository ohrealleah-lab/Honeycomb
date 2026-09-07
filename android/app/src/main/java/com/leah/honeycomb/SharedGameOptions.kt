package com.leah.honeycomb

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class SharedGameOptions(
    private val dataStore: DataStore<Preferences>,
    private val coroutineScope: CoroutineScope
) {
    private val globalSoundEnabledKey = booleanPreferencesKey("global_sound_enabled")
    private val globalNoStressModeKey = booleanPreferencesKey("global_no_stress_mode")
    private val globalHoneyModeKey = booleanPreferencesKey("global_honey_mode")
    private val globalManuallyDismissBannersKey = booleanPreferencesKey("global_manually_dismiss_banners")
    private val globalHideHintButtonKey = booleanPreferencesKey("global_hide_hint_button")

    private val _isSoundEnabled = MutableStateFlow(true)
    val isSoundEnabled: StateFlow<Boolean> = _isSoundEnabled

    private val _noStressMode = MutableStateFlow(false)
    val noStressMode: StateFlow<Boolean> = _noStressMode

    private val _honeyMode = MutableStateFlow(true)
    val honeyMode: StateFlow<Boolean> = _honeyMode

    private val _manuallyDismissBanners = MutableStateFlow(false)
    val manuallyDismissBanners: StateFlow<Boolean> = _manuallyDismissBanners

    private val _hideHintButton = MutableStateFlow(false)
    val hideHintButton: StateFlow<Boolean> = _hideHintButton

    var onNoStressModeChange: (() -> Unit)? = null

    init {
        // Read initial values synchronously for immediate availability
        val prefs = runBlocking { dataStore.data.first() }
        _isSoundEnabled.value = prefs[globalSoundEnabledKey] ?: true
        _noStressMode.value = prefs[globalNoStressModeKey] ?: false
        _honeyMode.value = prefs[globalHoneyModeKey] ?: true
        _manuallyDismissBanners.value = prefs[globalManuallyDismissBannersKey] ?: false
        _hideHintButton.value = prefs[globalHideHintButtonKey] ?: false
    }

    fun setSoundEnabled(enabled: Boolean) {
        _isSoundEnabled.value = enabled
        coroutineScope.launch {
            dataStore.edit { it[globalSoundEnabledKey] = enabled }
        }
    }

    fun setNoStressMode(enabled: Boolean) {
        val oldValue = _noStressMode.value
        _noStressMode.value = enabled
        coroutineScope.launch {
            dataStore.edit { it[globalNoStressModeKey] = enabled }
        }
        if (oldValue != enabled) {
            onNoStressModeChange?.invoke()
        }
    }

    fun setHoneyMode(enabled: Boolean) {
        _honeyMode.value = enabled
        coroutineScope.launch {
            dataStore.edit { it[globalHoneyModeKey] = enabled }
        }
    }

    fun setManuallyDismissBanners(enabled: Boolean) {
        _manuallyDismissBanners.value = enabled
        coroutineScope.launch {
            dataStore.edit { it[globalManuallyDismissBannersKey] = enabled }
        }
    }

    fun setHideHintButton(hide: Boolean) {
        _hideHintButton.value = hide
        coroutineScope.launch {
            dataStore.edit { it[globalHideHintButtonKey] = hide }
        }
    }
}
