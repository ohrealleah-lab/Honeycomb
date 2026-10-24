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
import kotlinx.coroutines.isActive
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

    // Saves are run strictly one after another, in the order they were requested, one queue per
    // DataStore. Before, each save was its own background job, so two saves of the same item made
    // back to back (a win's high score, then the win itself) could finish in either order — and
    // if the older one finished last it overwrote the newer, silently losing the win from the
    // saved file. Queues are per store so one store that stops answering can't hold up the rest.
    private class WriteQueue {
        val channel = kotlinx.coroutines.channels.Channel<suspend () -> Unit>(kotlinx.coroutines.channels.Channel.UNLIMITED)
        val pending: MutableSet<kotlinx.coroutines.Job> = java.util.Collections.newSetFromMap(
            java.util.concurrent.ConcurrentHashMap<kotlinx.coroutines.Job, Boolean>()
        )
    }

    private val unscopedStore = Any()
    private val queues = java.util.concurrent.ConcurrentHashMap<Any, WriteQueue>()

    private fun queueFor(store: Any): WriteQueue = queues.getOrPut(store) {
        WriteQueue().also { q ->
            ioScope.launch {
                for (write in q.channel) {
                    try {
                        write()
                    } catch (e: kotlinx.coroutines.CancellationException) {
                        // Cancelled because the queue itself is shutting down → stop. Otherwise it's
                        // this store's own DataStore that was cancelled: that save is lost, but the
                        // saves behind it must still run.
                        if (!kotlinx.coroutines.currentCoroutineContext().isActive) throw e
                    } catch (t: Throwable) {
                        // A failed save must not stop the saves queued behind it, but it's still
                        // reported the way an uncaught error in a save job always was.
                        val thread = Thread.currentThread()
                        try { thread.uncaughtExceptionHandler?.uncaughtException(thread, t) } catch (_: Throwable) { /* the handler itself failing mustn't end the queue */ }
                    }
                }
            }
        }
    }

    fun <T> saveObjectAsync(
        dataStore: DataStore<Preferences>,
        key: String,
        serializer: KSerializer<T>,
        value: T
    ) {
        trackWrite(dataStore) { setObject(dataStore, key, serializer, value) }
    }

    // For writes that don't go through setObject's JSON encoding (e.g. a raw
    // stringPreferencesKey edit) but still need to be ordered with the others of the same
    // store and tracked by awaitPendingWrites. Pass the store the write goes to.
    fun trackWrite(store: Any? = null, block: suspend () -> Unit) {
        val queue = queueFor(store ?: unscopedStore)
        val done = kotlinx.coroutines.CompletableDeferred<Unit>()
        queue.pending.add(done)
        done.invokeOnCompletion { queue.pending.remove(done) }
        queue.channel.trySend {
            try { block() } finally { done.complete(Unit) }
        }
    }

    // Waits (up to the timeout) for the saves still in flight — every store's, or just one
    // store's when it's given.
    suspend fun awaitPendingWrites(timeoutMs: Long = 800L, store: Any? = null) {
        kotlinx.coroutines.withTimeoutOrNull(timeoutMs) {
            val jobs = if (store != null) queues[store]?.pending?.toList().orEmpty()
                       else queues.values.flatMap { it.pending.toList() }
            kotlinx.coroutines.joinAll(*jobs.toTypedArray())
        }
    }
}
