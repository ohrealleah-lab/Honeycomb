package com.leah.honeycomb

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "honeycomb_prefs")

object PreferencesHelper {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    fun <T> getObject(
        dataStore: DataStore<Preferences>,
        key: String,
        serializer: KSerializer<T>,
        defaultValue: T
    ): Flow<T> {
        val prefKey = stringPreferencesKey(key)
        return dataStore.data.map { preferences ->
            val jsonString = preferences[prefKey]
            if (jsonString != null) {
                try {
                    json.decodeFromString(serializer, jsonString)
                } catch (e: Exception) {
                    defaultValue
                }
            } else {
                defaultValue
            }
        }
    }

    // Synchronous initial read for ViewModel init blocks — mirrors the runBlocking
    // pattern already used by SharedGameOptions/AppContainer so a game's persisted
    // options are available for the very first StateFlow value instead of arriving
    // one frame late via the Flow-based getObject() above.
    fun <T> getObjectSync(
        dataStore: DataStore<Preferences>,
        key: String,
        serializer: KSerializer<T>,
        defaultValue: T
    ): T {
        val prefKey = stringPreferencesKey(key)
        val jsonString = runBlocking { dataStore.data.first() }[prefKey]
        return if (jsonString != null) {
            try {
                json.decodeFromString(serializer, jsonString)
            } catch (e: Exception) {
                defaultValue
            }
        } else {
            defaultValue
        }
    }

    suspend fun <T> setObject(
        dataStore: DataStore<Preferences>,
        key: String,
        serializer: KSerializer<T>,
        value: T
    ) {
        val prefKey = stringPreferencesKey(key)
        val jsonString = json.encodeToString(serializer, value)
        dataStore.edit { preferences ->
            preferences[prefKey] = jsonString
        }
    }
}
