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

    // Lazy: each game's ViewModel does its own blocking DataStore read(s) in its
    // constructor (see the parity audit's app-wide "runBlocking in ViewModel
    // construction" finding). Building all six eagerly here — which is what this file
    // used to do — meant every cold start paid ~14 sequential blocking reads on the
    // main thread before the first frame, regardless of which game (if any) the player
    // actually opens. Lazy defers each game's reads to the first time it's actually
    // navigated to, so a typical session pays for 1-2 games instead of 6.
    val klondikeViewModel by lazy { GameViewModel(sharedOptions, context.dataStore) }
    val spiderViewModel by lazy { SpiderViewModel(sharedOptions, context.dataStore) }
    val beecellViewModel by lazy { BeecellViewModel(sharedOptions, context.dataStore) }
    val blackjackViewModel by lazy { BlackjackViewModel(sharedOptions, context.dataStore) }
    val videoPokerViewModel by lazy { VideoPokerViewModel(sharedOptions, context.dataStore) }

    val honeycombDatabase by lazy { HoneycombDatabase(context.dataStore) }
    val honeycombProfileManager by lazy { HoneycombProfileManager(context.dataStore, honeycombDatabase) }
    val honeycombViewModel by lazy { HoneycombViewModel(sharedOptions, honeycombDatabase, honeycombProfileManager, context.dataStore) }
    
    val soundManager = com.leah.honeycomb.audio.SoundManager(context, sharedOptions.isSoundEnabled)
    
    val themeManager = com.leah.honeycomb.theme.ThemeManager(context.dataStore, coroutineScope)
    val customBackgroundManager = com.leah.honeycomb.theme.CustomBackgroundManager(context, context.dataStore, coroutineScope, themeManager)
    val customCardBackManager = com.leah.honeycomb.theme.CustomCardBackManager(context, context.dataStore, coroutineScope, themeManager)

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
