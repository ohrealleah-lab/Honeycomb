package com.leah.honeycomb

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import java.io.File

// Base for ViewModel tests: a Main dispatcher on a virtual clock (viewModelScope needs one;
// delays only run when a test advances `clock`), throwaway DataStore files, and the real
// banner catalog read from the repo's shared copy — so ViewModels build without an
// Android Context.
@OptIn(ExperimentalCoroutinesApi::class)
abstract class ViewModelTestBase {
    protected val clock: TestDispatcher = StandardTestDispatcher()
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Before fun setMainDispatcher() { Dispatchers.setMain(clock) }
    @After fun resetMainDispatcher() { Dispatchers.resetMain() }

    protected fun newDataStore(): DataStore<Preferences> {
        val file = File.createTempFile("honeycomb-test", ".preferences_pb").apply { delete(); deleteOnExit() }
        return PreferenceDataStoreFactory.create(scope = ioScope, produceFile = { file })
    }

    protected val language = MutableStateFlow(AppLanguage.English)

    protected fun newSharedOptions(dataStore: DataStore<Preferences>) = SharedGameOptions(dataStore, ioScope)

    protected fun newBannerCatalog(dataStore: DataStore<Preferences>, shared: SharedGameOptions) =
        BannerCatalog({ catalogJson() }, shared, language, dataStore)

    private fun catalogJson(): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val f = File(dir, "shared/Honeycomb/Resources/HoneycombBannerCatalog.json")
            if (f.exists()) return f.readText()
            dir = dir.parentFile
        }
        error("HoneycombBannerCatalog.json not found above ${File("").absolutePath}")
    }

    // ViewModels keep their state flows private; tests set up exact boards through them.
    @Suppress("UNCHECKED_CAST")
    protected fun <T> privateFlow(owner: Any, name: String): MutableStateFlow<T> {
        val field = owner.javaClass.getDeclaredField(name)
        field.isAccessible = true
        return field.get(owner) as MutableStateFlow<T>
    }

    protected fun up(suit: Suit, rank: Int) = Card(suit = suit, rank = rank, faceUp = true)
    protected fun down(suit: Suit, rank: Int) = Card(suit = suit, rank = rank, faceUp = false)
}
