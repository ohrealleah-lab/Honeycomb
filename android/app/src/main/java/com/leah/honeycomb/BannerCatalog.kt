package com.leah.honeycomb

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.edit
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable
import java.util.Calendar
import kotlin.math.abs

// Runtime companion to the generated BannerId enum (BannerId.kt) — loads
// HoneycombBannerCatalog.json (also generated, from the same spreadsheet run) and
// decides what text should actually show when a given banner fires. Mirrors the
// Swift port's BannerCatalog (shared/Honeycomb/Models/BannerCatalog.swift) and the
// Windows port's (windows/src/SoliBee.Core/Services/BannerCatalog.cs).
//
// This only knows about *content*: which messages exist for an id, and whether/how
// the 20% gate + fallback applies. It has no opinion on *when* a trigger's condition
// becomes true (that's each call site's own gameplay logic) or on achievement/
// milestone "fire exactly once" guards (the exact crossing condition differs per
// milestone — total wins vs. first launch — so that's the caller's responsibility
// too, not something this can know).

@Serializable
data class BannerDefinition(
    val id: String,
    val category: String = "",
    val trigger: String = "",
    val type: String = "",       // "ambiance" | "repeatableFlavor" | "achievement"
    val location: String = "",   // "toast" | "loading" | "winBanner" | "loseBanner" | "rulesBanner"
    val gated: Boolean = false,
    val gateChance: Double? = null,
    val fallback: String? = null,
    // Same length/order as `messages`, one Spanish translation per English message —
    // "" for a message not yet translated. `fallback` is NOT translated (stays
    // English regardless of language) — see tools/generate_banner_catalog.py.
    val messages: List<String> = emptyList(),
    val messagesEs: List<String> = emptyList()
)

@Serializable
private data class BannerCatalogDocument(
    val version: Int = 1,
    val generatedBy: String = "",
    val banners: List<BannerDefinition> = emptyList()
)

// What `BannerCatalog.fire()` decided should actually show.
sealed class BannerFireResult {
    // A message from the catalog's own pool for this id.
    data class Message(val text: String) : BannerFireResult()
    // The gate roll failed — this is the fallback text instead (an existing
    // production banner's own text, e.g. "Fallen Ace!", or BannerCatalog.RULE_NAME_SENTINEL
    // for rulesBanner entries, which the caller resolves to the active rule's own
    // display name).
    data class Fallback(val text: String) : BannerFireResult()
    // The id has no catalog entry, or its entry has no eligible content — nothing to show.
    object None : BannerFireResult()
}

class BannerCatalog(
    context: Context,
    private val sharedOptions: SharedGameOptions,
    private val languageFlow: StateFlow<AppLanguage>,
    private val dataStore: DataStore<Preferences>
) {
    companion object {
        // Sentinel a `fallback` string can equal for `rulesBanner`-location entries —
        // there's no single literal fallback text for those (it depends on which rule
        // is active), so the catalog can't bake it in; the caller substitutes the
        // rule's own existing display name instead.
        const val RULE_NAME_SENTINEL = "\$RULE_NAME"

        // One shared anchor for the whole app (not per-game) — "a year since you
        // started playing" should have one answer regardless of which game happens to
        // load first on any given day, so this deliberately isn't scoped to any one
        // game's own stats.
        private val FIRST_PLAYED_DATE_KEY = longPreferencesKey("app_first_played_date")
        private val HAS_SHOWN_ONE_YEAR_BANNER_KEY = booleanPreferencesKey("app_has_shown_one_year_banner")

        // Lunisolar/lunar holidays (Holi, Rosh Hashanah, Diwali, Eid al-Fitr, Hanukkah)
        // don't fall on a fixed Gregorian date, so — unlike the month/day checks below —
        // they need a real per-year lookup. No formula shortcut exists for these, so
        // this is a flat 20-year table (2025-2045) keyed "YYYY-M-D", one entry per year
        // per holiday — each holiday is a multi-day observance in real life, but only
        // its first day is listed here, since that's the one day the banner should show.
        private val floatingHolidayDates: Map<String, BannerId> = buildMap {
            val holi = listOf(
                "2025-3-14", "2026-3-3", "2027-3-22", "2028-3-11", "2029-3-29",
                "2030-3-19", "2031-3-8", "2032-3-25", "2033-3-15", "2034-3-4",
                "2035-3-22", "2036-3-12", "2037-3-1", "2038-3-19", "2039-3-8",
                "2040-3-26", "2041-3-15", "2042-3-5", "2043-3-23", "2044-3-12",
                "2045-3-1"
            )
            val roshHashanah = listOf(
                "2025-9-23", "2026-9-12", "2027-10-2", "2028-9-21", "2029-9-10",
                "2030-9-28", "2031-9-18", "2032-9-6", "2033-9-24", "2034-9-14",
                "2035-10-4", "2036-9-22", "2037-9-10", "2038-9-30", "2039-9-19",
                "2040-9-8", "2041-9-26", "2042-9-15", "2043-10-5", "2044-9-22",
                "2045-9-12"
            )
            val diwali = listOf(
                "2025-10-20", "2026-11-8", "2027-10-29", "2028-10-17", "2029-11-5",
                "2030-10-26", "2031-11-14", "2032-11-2", "2033-10-22", "2034-11-10",
                "2035-10-30", "2036-10-19", "2037-11-7", "2038-10-28", "2039-11-15",
                "2040-11-4", "2041-10-24", "2042-11-12", "2043-10-31", "2044-10-20",
                "2045-11-9"
            )
            val eidAlFitr = listOf(
                "2025-3-30", "2026-3-19", "2027-3-9", "2028-2-26", "2029-2-14",
                "2030-2-3", "2031-1-24", "2032-1-13", "2033-1-2", "2033-12-22",
                "2034-12-11", "2035-11-30", "2036-11-18", "2037-11-8", "2038-10-29",
                "2039-10-18", "2040-10-6", "2041-9-26", "2042-9-15", "2043-9-4",
                "2044-8-24", "2045-8-13"
            )
            val hanukkah = listOf(
                "2025-12-15", "2026-12-5", "2027-12-25", "2028-12-13", "2029-12-2",
                "2030-12-21", "2031-12-10", "2032-11-28", "2033-12-17", "2034-12-7",
                "2035-12-26", "2036-12-14", "2037-12-3", "2038-12-22", "2039-12-12",
                "2040-11-30", "2041-12-18", "2042-12-8", "2043-12-27", "2044-12-15",
                "2045-12-4"
            )
            holi.forEach { put(it, BannerId.LoadingGameLoadsOnHoli) }
            roshHashanah.forEach { put(it, BannerId.LoadingGameLoadsOnRoshHashanah) }
            diwali.forEach { put(it, BannerId.LoadingGameLoadsOnDiwali) }
            eidAlFitr.forEach { put(it, BannerId.LoadingGameLoadsOnEidAlFitr) }
            hanukkah.forEach { put(it, BannerId.LoadingGameLoadsOnHanukkah) }
        }

        // Whether ANY game's loading banner has fired yet this app session — not
        // per-game (each ViewModel has its own one-shot flag for that); this one is
        // shared across every game so we can tell "app launch" (the very first
        // loading banner shown this session, whichever game happens to load first)
        // from a later game switch. Process-lifetime, matches the Swift/Windows statics.
        private var hasFiredAnyLoadingBannerThisSession = false

        // Set by loadingBannerId() right before its caller enqueues the resulting
        // banner. The very first loading banner of an app session gets a longer 3s
        // display (vs. the usual 2s) so there's actually time to read it. Consumed
        // (reset to false) by the read itself so it can only ever apply to the one
        // flash it was set for, not some later unrelated banner.
        private var lastLoadingBannerWasAppLaunch = false
    }

    private val entries: Map<BannerId, BannerDefinition> = load(context)

    private fun load(context: Context): Map<BannerId, BannerDefinition> {
        return try {
            val json = context.assets.open("HoneycombBannerCatalog.json").bufferedReader().use { it.readText() }
            val doc = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }
                .decodeFromString(BannerCatalogDocument.serializer(), json)
            val result = mutableMapOf<BannerId, BannerDefinition>()
            for (entry in doc.banners) {
                val id = try {
                    BannerIdExtensions.parse(entry.id)
                } catch (e: Exception) {
                    // Catalog has an id with no matching BannerId case — regenerate via
                    // tools/generate_banner_catalog.py. Skip rather than crash.
                    continue
                }
                result[id] = entry
            }
            result
        } catch (e: Exception) {
            // Missing/corrupt bundled catalog — check that HoneycombBannerCatalog.json
            // is actually in android/app/src/main/assets/.
            emptyMap()
        }
    }

    fun definition(id: BannerId): BannerDefinition? = entries[id]

    // Decides what should show for `id` firing right now. `tokens` fills in any
    // `{PlaceholderName}` markers in the chosen text (e.g. ["OpponentName" to "Baby Bee"]).
    //
    // With Honey Mode off, every non-Achievement banner is either forced to its plain
    // fallback (gated entries) or suppressed entirely (ungated entries). Every fire()
    // call site should discard a Fallback's own text in favor of its own existing
    // default text (except for the rulesBanner sentinel-substitution case), so
    // returning Fallback("") here is safe.
    fun fire(id: BannerId, tokens: Map<String, String> = emptyMap()): BannerFireResult {
        val def = entries[id] ?: return BannerFireResult.None
        val honeyModeEnabled = sharedOptions.honeyMode.value

        if (!honeyModeEnabled && def.type != "achievement") {
            return if (def.gated) BannerFireResult.Fallback("") else BannerFireResult.None
        }

        if (def.gated && def.gateChance != null && Math.random() >= def.gateChance) {
            val fallback = def.fallback ?: return BannerFireResult.None
            return BannerFireResult.Fallback(substitute(fallback, tokens))
        }
        val message = pickMessage(def) ?: return BannerFireResult.None
        return BannerFireResult.Message(substitute(message, tokens))
    }

    // English: any message in the pool. Spanish: only messages that actually have a
    // translation ("" means untranslated) — if none of this entry's messages are
    // translated, the entry has nothing eligible to show in Spanish and the banner is
    // suppressed for that fire (per product decision: don't show English filler in an
    // otherwise-Spanish session).
    private fun pickMessage(def: BannerDefinition): String? {
        if (languageFlow.value != AppLanguage.Spanish) {
            return def.messages.randomOrNull()
        }
        val eligible = def.messagesEs.filter { it.isNotEmpty() }
        return eligible.randomOrNull()
    }

    private fun substitute(text: String, tokens: Map<String, String>): String {
        if (tokens.isEmpty()) return text
        var result = text
        for ((key, value) in tokens) {
            result = result.replace("{$key}", value)
        }
        return result
    }

    // Debug-only: returns a representative message for `id`, bypassing the gate/honey-
    // mode roll entirely so a debug menu always shows real catalog content instead of
    // occasionally doing nothing or showing the plain fallback text.
    fun debugPreviewText(id: BannerId, tokens: Map<String, String> = emptyMap()): String {
        val def = entries[id]
        val message = def?.messages?.randomOrNull() ?: return id.name
        return substitute(message, tokens)
    }

    // Decides which "loading" banner (checked once per game, per app session — each
    // ViewModel guards this with its own one-shot flag) fits right now. Time-of-day
    // windows and the one-year-anniversary check only apply at app launch — they're
    // tied to "the moment you opened the app," not to switching games afterward — so on
    // any later game switch this falls straight to holiday > generic. Shared across
    // every game (not Honeycomb-specific).
    fun loadingBannerId(): BannerId {
        val isAppLaunch = !hasFiredAnyLoadingBannerThisSession
        hasFiredAnyLoadingBannerThisSession = true
        lastLoadingBannerWasAppLaunch = isAppLaunch

        if (isAppLaunch && shouldShowOneYearAnniversaryBanner()) {
            return BannerId.LoadingFirstLaunchAfterPlayingForOneYear
        }

        val now = Calendar.getInstance()
        val month = now.get(Calendar.MONTH) + 1
        val day = now.get(Calendar.DAY_OF_MONTH)
        val year = now.get(Calendar.YEAR)

        if (month == 5 && day == 20) return BannerId.LoadingGameLoadsOnMay20thWorldBeeDay
        if (month == 1 && day == 1) return BannerId.LoadingGameLoadsOnNewYearsDayJan1
        if (month == 10 && day == 31) return BannerId.LoadingGameLoadsOnHalloweenOct31
        if (month == 2 && day == 14) return BannerId.LoadingGameLoadsOnValentinesDayFeb14
        if (month == 4 && day == 1) return BannerId.LoadingPlayingOnAprilFoolsDayApr1
        if (month == 4 && day == 22) return BannerId.LoadingGameLoadsOnEarthDayApr22
        if (month == 8 && day == 15) return BannerId.LoadingGameLoadsOnNationalHoneyDayAug15
        if (month == 3 && day == 14) return BannerId.LoadingGameLoadsOnPiDayMar14
        if (month == 12 && day == 31) return BannerId.LoadingGameLoadsOnNewYearsEveDec31
        if (month == 12 && day == 25) return BannerId.LoadingGameLoadsOnChristmasDec25

        floatingHolidayDates["$year-$month-$day"]?.let { return it }

        if (isAppLaunch) {
            val hour = now.get(Calendar.HOUR_OF_DAY)
            val minute = now.get(Calendar.MINUTE)
            val minutesFromMidnight = hour * 60 + minute
            if (abs(minutesFromMidnight - 720) <= 1) return BannerId.LoadingMatchStartsWithinAMinuteOfLocalNoon
            if (hour < 5) return BannerId.LoadingMatchStartsBetween1200AmAnd500AmLocalTime
            if (hour in 5..7) return BannerId.LoadingMatchStartsBetween500AmAnd800AmLocalTime
            if (hour in 8..11) return BannerId.LoadingMatchStartsBetween800AmAnd1200PmLocalTime
            if (hour in 12..13) return BannerId.LoadingMatchStartsBetween1200PmAnd200PmLocalTime
            if (hour in 14..16) return BannerId.LoadingMatchStartsBetween200PmAnd500PmLocalTime
            if (hour in 17..20) return BannerId.LoadingMatchStartsBetween500PmAnd900PmLocalTime
            if (hour >= 21) return BannerId.LoadingMatchStartsBetween900PmAndMidnightLocalTime
        }
        return BannerId.LoadingOnGameLoad
    }

    // Consumed (reset to false) by the read itself so it can only ever apply to the one
    // flash it was set for, not some later unrelated banner.
    fun consumeAppLaunchLoadingFlag(): Boolean {
        val wasAppLaunch = lastLoadingBannerWasAppLaunch
        lastLoadingBannerWasAppLaunch = false
        return wasAppLaunch
    }

    // Anchors this install date the first time it's ever read — a stats reset
    // deliberately does NOT touch this, since "a year since you started playing"
    // isn't something resetting one game's win count should undo. Reading it here
    // (before the check below) means the very first call always has zero elapsed
    // time, so it can never spuriously fire that day.
    private fun shouldShowOneYearAnniversaryBanner(): Boolean {
        val now = System.currentTimeMillis()
        val prefs = runBlocking { dataStore.data.first() }
        var firstPlayed = prefs[FIRST_PLAYED_DATE_KEY]
        if (firstPlayed == null) {
            firstPlayed = now
            PreferencesHelper.trackWrite { dataStore.edit { it[FIRST_PLAYED_DATE_KEY] = now } }
        }
        val hasShown = prefs[HAS_SHOWN_ONE_YEAR_BANNER_KEY] ?: false
        val oneYearMs = 365L * 24 * 60 * 60 * 1000
        if (hasShown || now - firstPlayed < oneYearMs) return false
        PreferencesHelper.trackWrite { dataStore.edit { it[HAS_SHOWN_ONE_YEAR_BANNER_KEY] = true } }
        return true
    }
}

// Shared FIFO banner-queue mechanism — replaces Honeycomb's original ad hoc
// bannerQueue/enqueueBanner/showFrontBanner and is reused by the other 5 games'
// ViewModels too, since Windows/iOS also queue rather than show banners
// simultaneously. `manuallyDismissBanners` is read fresh on every show (matches
// SharedGameOptions' other reads) — while true, a banner stays up until
// `dismissCurrent()` is called (a board tap) instead of auto-advancing on a timer.
class BannerQueue(
    private val scope: CoroutineScope,
    private val manuallyDismissBanners: () -> Boolean
) {
    private data class Entry(val text: String, val durationMs: Long)

    private val queue = ArrayDeque<Entry>()
    private val _active = MutableStateFlow<String?>(null)
    val active: StateFlow<String?> = _active.asStateFlow()
    private var advanceJob: Job? = null

    // durationMs is the on-screen hold time before the 300ms fade-out. Every toast
    // across every game is a uniform 2000ms — deliberately not tiered by banner
    // "importance" — matching Mac/Windows' 2026-08-07 unification (commit 6856678,
    // "Unify all toast durations to 2.0s"); Honeycomb's mechanical rule banners
    // (Same!/Plus!/Fallen Ace!) used to be a shorter 1200ms before that change. The
    // very first loading banner of a session gets 3000ms instead (see
    // BannerCatalog.consumeAppLaunchLoadingFlag) to cover Android's own cold-start
    // cost, mirroring Windows' Vm_OnFlashBanner.
    fun enqueue(text: String, durationMs: Long = 2000L) {
        queue.addLast(Entry(text, durationMs))
        if (queue.size == 1) showFront()
    }

    fun clear() {
        advanceJob?.cancel()
        queue.clear()
        _active.value = null
    }

    // Called by the UI when the player taps to dismiss a manually-dismissed banner.
    fun dismissCurrent() {
        if (queue.isEmpty()) return
        advanceJob?.cancel()
        _active.value = null
        scope.launch {
            delay(300)
            advance()
        }
    }

    private fun showFront() {
        val front = queue.firstOrNull() ?: return
        _active.value = front.text
        advanceJob?.cancel()
        if (manuallyDismissBanners()) return
        advanceJob = scope.launch {
            delay(front.durationMs)
            _active.value = null
            delay(300)
            advance()
        }
    }

    private fun advance() {
        queue.removeFirstOrNull()
        if (queue.isNotEmpty()) showFront()
    }
}
