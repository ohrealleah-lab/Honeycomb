package com.leah.honeycomb

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.leah.honeycomb.beecell.BeecellModeStats
import com.leah.honeycomb.beecell.BeecellOptions
import com.leah.honeycomb.beecell.BeecellStatistics
import com.leah.honeycomb.beecell.BeecellViewModel
import com.leah.honeycomb.blackjack.BlackjackOptions
import com.leah.honeycomb.blackjack.BlackjackStatistics
import com.leah.honeycomb.klondike.DrawMode
import com.leah.honeycomb.klondike.GameOptions
import com.leah.honeycomb.klondike.GameStatistics
import com.leah.honeycomb.klondike.GameViewModel
import com.leah.honeycomb.spider.SpiderModeStats
import com.leah.honeycomb.spider.SpiderOptions
import com.leah.honeycomb.spider.SpiderStatistics
import com.leah.honeycomb.spider.SpiderViewModel
import com.leah.honeycomb.videopoker.VideoPokerOptions
import com.leah.honeycomb.videopoker.VideoPokerStatistics
import com.leah.honeycomb.videopoker.VideoPokerVariant
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.advanceTimeBy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// How options and stats survive a relaunch, and how old, partial or damaged saves load.
// Mac equivalent: SettingsPersistenceTests. Saves are JSON in the DataStore; "relaunch" is a
// second ViewModel (or SharedGameOptions) built on the same DataStore file.
class SettingsPersistenceTest : ViewModelTestBase() {

    private fun putRaw(ds: DataStore<Preferences>, key: String, json: String) {
        runBlocking { ds.edit { it[stringPreferencesKey(key)] = json } }
    }

    private fun <T> load(ds: DataStore<Preferences>, key: String, s: kotlinx.serialization.KSerializer<T>, default: T): T =
        PreferencesHelper.getObjectSync(ds, key, s, default)

    // Setters write on a background scope; wait until the write has landed.
    private fun awaitStored(ds: DataStore<Preferences>, check: (Preferences) -> Boolean) {
        val deadline = System.currentTimeMillis() + 5000
        while (System.currentTimeMillis() < deadline) {
            if (check(runBlocking { ds.data.first() })) return
            Thread.sleep(10)
        }
        error("The saved value never reached the DataStore")
    }

    private fun flush() {
        awaitSaves()
    }

    private fun klondike(ds: DataStore<Preferences>): GameViewModel {
        val shared = newSharedOptions(ds)
        return GameViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    private fun spider(ds: DataStore<Preferences>): SpiderViewModel {
        val shared = newSharedOptions(ds)
        return SpiderViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    private fun beecell(ds: DataStore<Preferences>): BeecellViewModel {
        val shared = newSharedOptions(ds)
        return BeecellViewModel(shared, ds, newBannerCatalog(ds, shared))
    }

    // ---- Shared options ----

    @Test fun freshInstallDefaults() {
        val o = newSharedOptions(newDataStore())
        assertTrue(o.isSoundEnabled.value)
        assertFalse(o.noStressMode.value)
        assertTrue(o.honeyMode.value)
        assertFalse(o.manuallyDismissBanners.value)
        assertFalse(o.hideHintButton.value)
        assertFalse(o.hideBee.value)
    }

    @Test fun everySharedSettingSurvivesARelaunch() {
        val ds = newDataStore()
        val o = newSharedOptions(ds)
        o.setSoundEnabled(false)
        o.setNoStressMode(true)
        o.setHoneyMode(false)
        o.setManuallyDismissBanners(true)
        o.setHideHintButton(true)
        o.setHideBee(true)
        awaitStored(ds) { p ->
            p[booleanPreferencesKey("global_sound_enabled")] == false &&
                p[booleanPreferencesKey("global_no_stress_mode")] == true &&
                p[booleanPreferencesKey("global_honey_mode")] == false &&
                p[booleanPreferencesKey("global_manually_dismiss_banners")] == true &&
                p[booleanPreferencesKey("global_hide_hint_button")] == true &&
                p[booleanPreferencesKey("global_hide_bee")] == true
        }

        val again = newSharedOptions(ds)
        assertFalse(again.isSoundEnabled.value)
        assertTrue(again.noStressMode.value)
        assertFalse(again.honeyMode.value)
        assertTrue(again.manuallyDismissBanners.value)
        assertTrue(again.hideHintButton.value)
        assertTrue(again.hideBee.value)
    }

    @Test fun aSettingMissingFromTheSaveKeepsItsDefault() {
        val ds = newDataStore()
        runBlocking { ds.edit { it[booleanPreferencesKey("global_no_stress_mode")] = true } }
        val o = newSharedOptions(ds)
        assertTrue(o.noStressMode.value)
        assertTrue("Sound stays on", o.isSoundEnabled.value)
        assertTrue("Honey Mode stays on", o.honeyMode.value)
        assertFalse(o.hideBee.value)
    }

    @Test fun noStressNotifiesOnlyWhenTheValueChanges() {
        val o = newSharedOptions(newDataStore())
        var fired = 0
        o.onNoStressModeChange = { fired++ }
        o.setNoStressMode(true)
        assertEquals(1, fired)
        o.setNoStressMode(true)
        assertEquals("Same value notifies nobody", 1, fired)
        o.setNoStressMode(false)
        assertEquals(2, fired)
    }

    // ---- Per-game options: old and partial saves ----

    @Test fun emptyOrMissingSavesGiveTheDefaults() {
        val ds = newDataStore()
        assertEquals(GameOptions(), load(ds, "solitaire_options", GameOptions.serializer(), GameOptions()))
        putRaw(ds, "solitaire_options", "{}")
        putRaw(ds, "spider_options", "{}")
        putRaw(ds, "beecell_options", "{}")
        putRaw(ds, "videopoker_options", "{}")
        putRaw(ds, "blackjack_options", "{}")
        assertEquals(GameOptions(), load(ds, "solitaire_options", GameOptions.serializer(), GameOptions()))
        assertEquals(SpiderOptions(), load(ds, "spider_options", SpiderOptions.serializer(), SpiderOptions()))
        assertEquals(BeecellOptions(), load(ds, "beecell_options", BeecellOptions.serializer(), BeecellOptions()))
        val vp = load(ds, "videopoker_options", VideoPokerOptions.serializer(), VideoPokerOptions())
        assertEquals(VideoPokerOptions(), vp)
        assertEquals(VideoPokerVariant.JacksOrBetter, vp.variant)
        assertEquals(BlackjackOptions(), load(ds, "blackjack_options", BlackjackOptions.serializer(), BlackjackOptions()))
        assertEquals(1, SpiderOptions().suitCount)
        assertEquals(DrawMode.DrawThree, GameOptions().drawMode)
        assertEquals(1, GameOptions().deckCount)
    }

    @Test fun aPartialSaveKeepsWhatItHasAndDefaultsTheRest() {
        val ds = newDataStore()
        putRaw(ds, "solitaire_options", """{"drawMode":"DrawOne"}""")
        val k = load(ds, "solitaire_options", GameOptions.serializer(), GameOptions())
        assertEquals(DrawMode.DrawOne, k.drawMode)
        assertTrue(k.isStatusBarVisible)
        assertEquals(1, k.deckCount)

        putRaw(ds, "spider_options", """{"suitCount":4}""")
        assertEquals(SpiderOptions(suitCount = 4), load(ds, "spider_options", SpiderOptions.serializer(), SpiderOptions()))

        putRaw(ds, "videopoker_options", """{"variant":"BonusPoker","startingCredits":300}""")
        val vp = load(ds, "videopoker_options", VideoPokerOptions.serializer(), VideoPokerOptions())
        assertEquals(VideoPokerVariant.BonusPoker, vp.variant)
        assertEquals(300, vp.startingCredits)
        assertEquals(1, vp.betPerHand)
    }

    @Test fun unknownFieldsAndUnknownEnumValuesDoNotWipeTheSave() {
        val ds = newDataStore()
        putRaw(ds, "solitaire_options", """{"removedFutureThing":true,"drawMode":"Sideways","isStatusBarVisible":false}""")
        val k = load(ds, "solitaire_options", GameOptions.serializer(), GameOptions())
        assertEquals("An unknown draw mode falls back to the default", DrawMode.DrawThree, k.drawMode)
        assertFalse("The other saved field is kept", k.isStatusBarVisible)
    }

    @Test fun damagedSavesFallBackToDefaultsInsteadOfCrashing() {
        val ds = newDataStore()
        putRaw(ds, "beecell_options", "not json at all")
        putRaw(ds, "spider_options", """{"suitCount":"four"}""")
        putRaw(ds, "beecell_statistics", "[1,2,3]")
        putRaw(ds, "spider_statistics", "")
        assertEquals(BeecellOptions(), load(ds, "beecell_options", BeecellOptions.serializer(), BeecellOptions()))
        assertEquals(SpiderOptions(), load(ds, "spider_options", SpiderOptions.serializer(), SpiderOptions()))
        assertEquals(BeecellStatistics(), load(ds, "beecell_statistics", BeecellStatistics.serializer(), BeecellStatistics()))
        assertEquals(SpiderStatistics(), load(ds, "spider_statistics", SpiderStatistics.serializer(), SpiderStatistics()))
        // And the games still start.
        val vm = beecell(ds)
        assertEquals(52, vm.state.value.tableau.sumOf { it.cards.size })
        assertTrue(vm.options.value.autoMoveToFoundation)
    }

    @Test fun aDamagedGameInProgressStartsAFreshDeal() {
        val ds = newDataStore()
        putRaw(ds, "beecell_saved_state", "{\"tableau\": 7}")
        val vm = beecell(ds)
        assertEquals(52, vm.state.value.tableau.sumOf { it.cards.size })
        assertEquals(0, vm.state.value.movesCount)
    }

    // ---- Stats: old and sparse saves ----

    @Test fun sparseStatsSavesDecodeWithZerosAndTheRightDefaults() {
        val ds = newDataStore()
        putRaw(ds, "klondike_statistics", """{"gamesWon":4}""")
        val g = load(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics())
        assertEquals(4, g.gamesWon)
        assertEquals(0, g.gamesPlayed)
        assertEquals(0, g.shortestWinTime)
        assertEquals(-5200, g.highScoreVegas)

        val sp = Json.decodeSpiderMode("""{"gamesWon":2}""")
        assertEquals(2, sp.gamesWon)
        assertEquals("Spider's high score starts at 500", 500, sp.highScore)

        putRaw(ds, "beecell_statistics", """{"statsByFreeCells":{"4":{"highScore":55}}}""")
        val b = load(ds, "beecell_statistics", BeecellStatistics.serializer(), BeecellStatistics())
        assertEquals(55, b.statsByFreeCells[4]?.highScore)
        assertEquals(0, b.statsByFreeCells[4]?.gamesWon)

        putRaw(ds, "blackjack_statistics", """{"blackjacks":3,"pushes":1}""")
        val bj = load(ds, "blackjack_statistics", BlackjackStatistics.serializer(), BlackjackStatistics())
        assertEquals(3, bj.blackjacks)
        assertEquals(1, bj.pushes)
        assertEquals(0, bj.handsWon)
        putRaw(ds, "videopoker_statistics", "{}")
        assertEquals(0, load(ds, "videopoker_statistics", VideoPokerStatistics.serializer(), VideoPokerStatistics()).handsPlayed)
    }

    private object Json {
        fun decodeSpiderMode(s: String): SpiderModeStats =
            kotlinx.serialization.json.Json { ignoreUnknownKeys = true; coerceInputValues = true }
                .decodeFromString(SpiderModeStats.serializer(), s)
    }

    @Test fun statsRoundTripThroughTheDataStore() {
        val ds = newDataStore()
        val k = GameStatistics(gamesPlayed = 10, gamesWon = 4, currentStreak = 2, longestStreak = 3,
            totalWinningTime = 300, winningGamesCount = 3, shortestWinTime = 70, highScore = 900, highScoreVegas = 20)
        val sp = SpiderStatistics(mapOf(1 to SpiderModeStats(gamesPlayed = 3, gamesWon = 2), 4 to SpiderModeStats(highScore = 900)))
        val bee = BeecellStatistics(mapOf(4 to BeecellModeStats(gamesWon = 5, shortestWinTime = 44)))
        runBlocking {
            PreferencesHelper.setObject(ds, "klondike_statistics", GameStatistics.serializer(), k)
            PreferencesHelper.setObject(ds, "spider_statistics", SpiderStatistics.serializer(), sp)
            PreferencesHelper.setObject(ds, "beecell_statistics", BeecellStatistics.serializer(), bee)
        }
        assertEquals(k, load(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics()))
        assertEquals(sp, load(ds, "spider_statistics", SpiderStatistics.serializer(), SpiderStatistics()))
        assertEquals(bee, load(ds, "beecell_statistics", BeecellStatistics.serializer(), BeecellStatistics()))
        assertEquals(0.4, k.winRate, 1e-9)
        assertEquals(100.0, k.averageWinningTime, 1e-9)
        assertEquals(0.0, GameStatistics().winRate, 0.0)
    }

    // ---- Options changed in a game survive a relaunch ----

    @Test fun klondikeOptionsSurviveARelaunchAndVegasStaysOff() {
        val ds = newDataStore()
        val vm = klondike(ds)
        vm.updateOptions(vm.options.value.copy(drawMode = DrawMode.DrawOne, isStatusBarVisible = false, isVegasScoring = true))
        assertFalse("Vegas scoring is off on Android", vm.options.value.isVegasScoring)
        flush()
        val again = klondike(ds)
        assertEquals(DrawMode.DrawOne, again.options.value.drawMode)
        assertFalse(again.options.value.isStatusBarVisible)
        assertFalse(again.options.value.isVegasScoring)
    }

    @Test fun anOldSaveWithVegasOnLoadsWithVegasOff() {
        val ds = newDataStore()
        putRaw(ds, "solitaire_options", """{"isVegasScoring":true,"drawMode":"DrawOne"}""")
        val vm = klondike(ds)
        assertFalse(vm.options.value.isVegasScoring)
        assertEquals(DrawMode.DrawOne, vm.options.value.drawMode)
    }

    @Test fun oldStandaloneKlondikeHighScoresAreFoldedIntoTheStats() {
        val ds = newDataStore()
        putRaw(ds, "high_score", "4200")
        val vm = klondike(ds)
        assertEquals(4200, vm.statistics.value.highScore)
        flush()
        assertEquals("Persisted so the migration only runs once", 4200,
            load(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics()).highScore)
    }

    @Test fun spiderOptionsSurviveARelaunch() {
        val ds = newDataStore()
        val vm = spider(ds)
        assertEquals(1, vm.options.value.suitCount)
        vm.updateOptions(SpiderOptions(suitCount = 2, highlightValidMoves = true))
        flush()
        clock.scheduler.advanceTimeBy(1)
        val again = spider(ds)
        assertEquals(2, again.options.value.suitCount)
        assertTrue(again.options.value.highlightValidMoves)
    }

    @Test fun beecellStatsPlayedCountSurvivesARelaunch() {
        val ds = newDataStore()
        beecell(ds)
        flush()
        beecell(ds)
        flush()
        // Two launches dealt two games.
        assertEquals(2, load(ds, "beecell_statistics", BeecellStatistics.serializer(), BeecellStatistics())
            .statsByFreeCells[4]?.gamesPlayed)
    }

    // Saves made back to back run in the order they were made, so the last value always wins.
    @Test fun backToBackSavesOfOneItemLandInOrder() {
        repeat(3) {
            val ds = newDataStore()
            repeat(80) { n ->
                PreferencesHelper.saveObjectAsync(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics(gamesWon = n))
            }
            flush()
            assertEquals(79, load(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics()).gamesWon)
        }
    }

    @Test fun savingASettingTwiceQuickly_KeepsTheLastValue() {
        repeat(20) {
            val ds = newDataStore()
            val o = newSharedOptions(ds)
            o.setHoneyMode(false)
            o.setHoneyMode(true)
            o.setHoneyMode(false)
            flush()
            assertFalse(newSharedOptions(ds).honeyMode.value)
        }
    }

    @Test fun aFailedSaveDoesNotStopTheOnesBehindIt() {
        val ds = newDataStore()
        // The queue reports the failure the way a failed save job always did, and carries on.
        PreferencesHelper.trackWrite(ds) { error("boom") }
        PreferencesHelper.saveObjectAsync(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics(gamesWon = 5))
        flush()
        assertEquals(5, load(ds, "klondike_statistics", GameStatistics.serializer(), GameStatistics()).gamesWon)
    }
}
