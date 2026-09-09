package com.leah.honeycomb
import kotlinx.coroutines.launch

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.preferences.core.emptyPreferences
import kotlinx.coroutines.flow.catch
import kotlinx.serialization.SerializationException
import java.io.IOException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(
    name = "honeycomb_prefs",
    corruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() }
)

object PreferencesHelper {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        // A single field that fails to decode (a renamed/removed enum constant, a null
        // where non-null is now required) falls back to that field's own default instead
        // of throwing and wiping the whole persisted object — matches iOS's per-field
        // try?/?? default recovery, without hand-writing a custom decoder for every class.
        coerceInputValues = true
    }

    fun <T> getObject(
        dataStore: DataStore<Preferences>,
        key: String,
        serializer: KSerializer<T>,
        defaultValue: T
    ): Flow<T> {
        val prefKey = stringPreferencesKey(key)
        return dataStore.data.catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }.map { preferences ->
            val jsonString = preferences[prefKey]
            if (jsonString != null) {
                try {
                    json.decodeFromString(serializer, jsonString)
                } catch (e: SerializationException) {
                    defaultValue
                } catch (e: IllegalArgumentException) {
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
        return try {
            val jsonString = runBlocking { dataStore.data.first() }[prefKey]
            if (jsonString != null) {
                json.decodeFromString(serializer, jsonString)
            } else {
                defaultValue
            }
        } catch (e: SerializationException) {
            defaultValue
        } catch (e: IllegalArgumentException) {
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

    private val ioScope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.IO)
    private val pendingWrites = java.util.Collections.newSetFromMap(
        java.util.concurrent.ConcurrentHashMap<kotlinx.coroutines.Job, Boolean>()
    )

    fun <T> saveObjectAsync(
        dataStore: DataStore<Preferences>,
        key: String,
        serializer: KSerializer<T>,
        value: T
    ) {
        lateinit var job: kotlinx.coroutines.Job
        job = ioScope.launch { setObject(dataStore, key, serializer, value) }
        pendingWrites.add(job)
        job.invokeOnCompletion { pendingWrites.remove(job) }
    }

    suspend fun awaitPendingWrites(timeoutMs: Long = 800L) {
        kotlinx.coroutines.withTimeoutOrNull(timeoutMs) {
            kotlinx.coroutines.joinAll(*pendingWrites.toTypedArray())
        }
    }
}
