package com.leah.honeycomb

import android.content.Context
import androidx.compose.runtime.compositionLocalOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.edit
import com.leah.honeycomb.klondike.GameViewModel
import com.leah.honeycomb.spider.SpiderViewModel
import com.leah.honeycomb.beecell.BeecellViewModel
import com.leah.honeycomb.blackjack.BlackjackViewModel
import com.leah.honeycomb.videopoker.VideoPokerViewModel
import com.leah.honeycomb.honeycomb.HoneycombDatabase
import com.leah.honeycomb.honeycomb.HoneycombProfileManager
import com.leah.honeycomb.honeycomb.HoneycombViewModel

class AppContainer(private val context: Context) {
    val coroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    
    val sharedOptions = SharedGameOptions(context.dataStore, coroutineScope)
    
    val klondikeViewModel = GameViewModel(sharedOptions, context.dataStore)
    val spiderViewModel = SpiderViewModel(sharedOptions, context.dataStore)
    val beecellViewModel = BeecellViewModel(sharedOptions, context.dataStore)
    val blackjackViewModel = BlackjackViewModel(sharedOptions, context.dataStore)
    val videoPokerViewModel = VideoPokerViewModel(sharedOptions, context.dataStore)

    val honeycombDatabase = HoneycombDatabase(context.dataStore)
    val honeycombProfileManager = HoneycombProfileManager(context.dataStore, honeycombDatabase)
    val honeycombViewModel = HoneycombViewModel(sharedOptions, honeycombDatabase, honeycombProfileManager, context.dataStore)
    
    val soundManager = com.leah.honeycomb.audio.SoundManager(context, sharedOptions.isSoundEnabled)
    
    val themeManager = com.leah.honeycomb.theme.ThemeManager(context.dataStore, coroutineScope)
    val customBackgroundManager = com.leah.honeycomb.theme.CustomBackgroundManager(context, context.dataStore, coroutineScope, themeManager)
    val customCardBackManager = com.leah.honeycomb.theme.CustomCardBackManager(context, context.dataStore, coroutineScope, themeManager)
    val customFaceCardArtManager = com.leah.honeycomb.theme.CustomFaceCardArtManager(context, coroutineScope, themeManager)

    private val appLanguageKey = stringPreferencesKey("appLanguage")
    private val lastGameModeKey = stringPreferencesKey("lastGameMode")
    
    private val _language = MutableStateFlow(AppLanguage.English)
    val language: StateFlow<AppLanguage> = _language
    
    var initialGameMode: String = "klondike"
        private set
    
    init {
        com.leah.honeycomb.audio.UISound.backend = soundManager
        val prefs = runBlocking { context.dataStore.data.first() }
        val langString = prefs[appLanguageKey]
        _language.value = if (langString == "Spanish") AppLanguage.Spanish else AppLanguage.English
        initialGameMode = prefs[lastGameModeKey] ?: "klondike"
    }
    
    fun setLanguage(lang: AppLanguage) {
        _language.value = lang
        coroutineScope.launch {
            context.dataStore.edit { it[appLanguageKey] = lang.name }
        }
    }

    fun setLastGameMode(mode: String) {
        coroutineScope.launch {
            context.dataStore.edit { it[lastGameModeKey] = mode }
        }
    }
}

val LocalAppContainer = compositionLocalOf<AppContainer> {
    error("No AppContainer provided")
}
