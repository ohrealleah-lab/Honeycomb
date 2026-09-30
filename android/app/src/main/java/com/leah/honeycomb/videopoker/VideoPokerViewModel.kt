package com.leah.honeycomb.videopoker

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.Card
import com.leah.honeycomb.PreferencesHelper
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.Suit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.max

@OptIn(kotlinx.coroutines.FlowPreview::class)
class VideoPokerViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>,
    private val bannerCatalog: com.leah.honeycomb.BannerCatalog
) : ViewModel(), com.leah.honeycomb.IdleActionChecking {

    private val _state = MutableStateFlow(VideoPokerState())
    val state: StateFlow<VideoPokerState> = _state.asStateFlow()

    private val bannerQueue = com.leah.honeycomb.BannerQueue(viewModelScope) { sharedOptions.manuallyDismissBanners.value }
    val activeBanner: StateFlow<String?> = bannerQueue.active
    private fun enqueueBanner(text: String) = bannerQueue.enqueue(text)
    fun dismissBanner() = bannerQueue.dismissCurrent()

    private fun checkWinMilestones(previousHandsWon: Int) {
        val thresholds = listOf(
            10 to com.leah.honeycomb.BannerId.MilestonesPlayerReaches10TotalWins,
            100 to com.leah.honeycomb.BannerId.MilestonesPlayerReaches100TotalWins,
            1000 to com.leah.honeycomb.BannerId.MilestonesPlayerReaches1000TotalWins
        )
        for ((threshold, id) in thresholds) {
            if (previousHandsWon >= threshold || _statistics.value.handsWon < threshold) continue
            val result = bannerCatalog.fire(id)
            if (result is com.leah.honeycomb.BannerFireResult.Message) enqueueBanner(result.text)
        }
    }

    private var hasFiredLoadingBannerThisSession = false
    fun checkLoadingBanner() {
        if (hasFiredLoadingBannerThisSession) return
        hasFiredLoadingBannerThisSession = true
        val result = bannerCatalog.fire(bannerCatalog.loadingBannerId())
        if (result is com.leah.honeycomb.BannerFireResult.Message) enqueueBanner(result.text)
    }

    private var idleCheckGeneration = 0
    // A game switch counts as player activity: the game being left cancels its pending
    // idle nudge (it would otherwise fire off screen and pop up on return), and the game
    // being entered restarts its minute — see AppContainer.rearmIdleCheck. Mac parity.
    override fun cancelIdleActionCheck() { idleCheckGeneration++ }

    override fun scheduleIdleActionCheck() {
        idleCheckGeneration++
        val generation = idleCheckGeneration
        viewModelScope.launch {
            kotlinx.coroutines.delay(60000)
            if (idleCheckGeneration != generation) return@launch
            val result = bannerCatalog.fire(com.leah.honeycomb.BannerId.IdleActionNoActionTakenForOneMinute)
            if (result is com.leah.honeycomb.BannerFireResult.Message) enqueueBanner(result.text)
        }
    }

    // True from the moment a round resolves until its out-of-credits check has run (or
    // the next round starts). The board calls checkOutOfCredits() from several places —
    // result banner auto-hide, an early tap-dismiss, and leaving the screen mid-banner
    // (so the toast isn't lost) — and this keeps it to one toast per round even when the
    // board is recomposed (e.g. back from Options) and replays its result banner.
    private var outOfCreditsCheckDue = false

    // Called from the view once the win/lose result banner has finished fading.
    // Mirrors Windows' VideoPokerViewModel.CheckOutOfCredits.
    fun checkOutOfCredits() {
        val s = _state.value
        if (!outOfCreditsCheckDue || s.phase != VideoPokerPhase.Result) return
        outOfCreditsCheckDue = false
        if (isFreePlay || sharedOptions.noStressMode.value || s.sessionCredits > 10) return
        if (s.lastPayout > 0) return
        val result = bannerCatalog.fire(com.leah.honeycomb.BannerId.GameplayPlayerRunsOutOfCreditsVideoPokerBlackjack)
        val text = if (result is com.leah.honeycomb.BannerFireResult.Message) {
            result.text
        } else {
            com.leah.honeycomb.Strings.get(com.leah.honeycomb.StringKey.OutOfCreditsToast, bannerCatalog.currentLanguage)
        }
        enqueueBanner(text)
    }

    private fun saveOptions(options: VideoPokerOptions) {
        PreferencesHelper.saveObjectAsync(dataStore, "videopoker_options", VideoPokerOptions.serializer(), options)
    }

    private val _options = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "videopoker_options", VideoPokerOptions.serializer(), VideoPokerOptions())
    )
    val options: StateFlow<VideoPokerOptions> = _options.asStateFlow()

    private val _statistics = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "videopoker_statistics", VideoPokerStatistics.serializer(), VideoPokerStatistics())
    )
    val statistics: StateFlow<VideoPokerStatistics> = _statistics.asStateFlow()

    private fun persistStatistics() {
        val snapshot = _statistics.value
        PreferencesHelper.saveObjectAsync(dataStore, "videopoker_statistics", VideoPokerStatistics.serializer(), snapshot)
    }

    // Declared before init: init may start an evaluation (resuming a hand saved
    // mid-draw), and a later initializer would reset it back to 0 underneath that.
    private var drawGeneration = 0

    init {
        val defaultState = VideoPokerState()
        val savedState = PreferencesHelper.getObjectSync(
            dataStore, "videopoker_saved_state", VideoPokerState.serializer(), defaultState
        )

        if (savedState != defaultState && savedState.phase != VideoPokerPhase.Deal) {
            _state.value = savedState
            // Saved after draw() replaced the cards but before evaluation landed — finish
            // evaluating that hand rather than handing the player a second draw on it.
            if (savedState.phase == VideoPokerPhase.Holding && savedState.drawCommitted) {
                launchEvaluation(++drawGeneration)
            }
        } else {
            startNewGame()
        }

        viewModelScope.launch {
            _state.debounce(500).collect { currentState ->
                val toSave = if (currentState.phase == VideoPokerPhase.Deal) defaultState else currentState
                PreferencesHelper.saveObjectAsync(
                    dataStore, "videopoker_saved_state", VideoPokerState.serializer(), toSave
                )
            }
        }
    }

    // Locked for the hand once it's dealt: deal() deducts the bet based on free play, and
    // the draw's payout must use that same answer. Reading the live toggle mid-hand let a
    // player deal free, turn No Stress off, then draw and collect a real payout.
    // Hard-locked to free play on Android, matching iOS: no betting, credits or payouts
    // (simulated gambling — app stores' gambling rules). Everything that reads this
    // (bet controls, credit display, payouts, money stats, Rebuy, out-of-credits toast)
    // therefore stays off regardless of No Stress Mode.
    val isFreePlay: Boolean
        get() = true

    val canOpenOptions: Boolean
        get() = _state.value.phase == VideoPokerPhase.Deal || _state.value.phase == VideoPokerPhase.Result

    val totalBet: Int
        get() = _state.value.currentBet

    val payTable: List<VideoPokerPayEntry>
        get() = VideoPokerScoring.payTable(_options.value.variant)

    fun rebuy() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Deal && s.phase != VideoPokerPhase.Result) return
        // Re-checked here, not just in the view: a fast double-tap lands twice before the
        // button hides, which paid out two rebuys (credits and rebuyCount both doubled).
        // Mirrors VideoPokerBoard's own show-condition for the Rebuy button.
        if (isFreePlay || s.sessionCredits >= s.currentBet) return
        _state.value = s.copy(
            sessionCredits = s.sessionCredits + _options.value.startingCredits
        )
        _statistics.value = _statistics.value.copy(
            rebuyCount = _statistics.value.rebuyCount + 1
        )
        persistStatistics()
    }

    fun deal() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Deal && s.phase != VideoPokerPhase.Result) return
        if (!isFreePlay && s.sessionCredits < totalBet) return

        val newCredits = if (!isFreePlay) s.sessionCredits - totalBet else s.sessionCredits
        val newWagered = if (!isFreePlay) _statistics.value.totalWagered + totalBet else _statistics.value.totalWagered
        
        if (_statistics.value.handsPlayed == 0) {
            val firstLaunchResult = bannerCatalog.fire(com.leah.honeycomb.BannerId.MilestonesFirstLaunchEver)
            if (firstLaunchResult is com.leah.honeycomb.BannerFireResult.Message) enqueueBanner(firstLaunchResult.text)
        }
        _statistics.value = _statistics.value.copy(
            handsPlayed = _statistics.value.handsPlayed + 1,
            totalWagered = newWagered
        )
        persistStatistics()
        scheduleIdleActionCheck()

        val deck = mutableListOf<Card>()
        for (suit in Suit.values()) {
            for (rank in 1..13) {
                deck.add(Card(suit = suit, rank = rank, faceUp = true))
            }
        }
        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")
        
        val hand = deck.take(5)
        val remainingDeck = deck.drop(5)
        
        drawGeneration++ // a fresh hand invalidates any evaluation still in flight
        _state.value = s.copy(
            handFreePlay = isFreePlay,
            drawCommitted = false,
            sessionCredits = newCredits,
            handsDealt = s.handsDealt + 1,
            lastPayout = 0,
            lastHandName = "",
            heldIndices = emptySet(),
            deck = remainingDeck,
            hand = hand,
            phase = VideoPokerPhase.Holding
        )
    }

    fun toggleHold(index: Int) {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Holding || s.drawCommitted || index >= 5) return
        val newHeld = s.heldIndices.toMutableSet()
        if (newHeld.contains(index)) {
            newHeld.remove(index)
        } else {
            newHeld.add(index)
        }
        _state.value = s.copy(heldIndices = newHeld)
    }


    // Deuces Wild's evaluateWithDeuces() brute-forces up to 13³ candidate hands for 3 held
    // deuces — background it on Dispatchers.Default instead of running synchronously on
    // the UI thread from this onClick. drawGeneration guards against a slow evaluation
    // landing after another draw/deal has already started.
    fun draw() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Holding || s.drawCommitted) return

        val hand = s.hand.toMutableList()
        val deck = s.deck.toMutableList()

        for (i in 0 until 5) {
            if (!s.heldIndices.contains(i)) {
                if (deck.isNotEmpty()) {
                    hand[i] = deck.removeFirst()
                }
            }
        }

        // drawCommitted flips in the same write as the new cards, so a second tap while
        // evaluation is still running (phase is still Holding) can't draw again.
        _state.value = s.copy(
            hand = hand,
            deck = deck,
            drawCommitted = true
        )
        com.leah.honeycomb.audio.UISound.play("snap")

        launchEvaluation(++drawGeneration)
    }

    // Only the evaluation itself runs off the main thread; the result is applied back on
    // Main against the *current* state, and only if nothing replaced the hand meanwhile —
    // deal()/startNewGame()/resetIfRoundOver() all bump drawGeneration. (Previously the
    // background thread wrote a copy of its start-of-evaluation snapshot back into
    // _state, which could overwrite a newer game with the old hand.)
    private fun launchEvaluation(generation: Int) {
        val handToEvaluate = _state.value.hand
        val variant = _options.value.variant
        viewModelScope.launch(kotlinx.coroutines.Dispatchers.Main) {
            val result = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
                if (variant == VideoPokerVariant.DeucesWild) {
                    PokerHandEvaluator.evaluateWithDeuces(handToEvaluate)
                } else {
                    PokerHandEvaluator.evaluate(handToEvaluate)
                }
            }
            if (generation != drawGeneration) return@launch
            applyEvaluation(handToEvaluate, result)
        }
    }

    private fun applyEvaluation(evaluatedHand: List<Card>, result: PokerHandResult) {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Holding || s.hand != evaluatedHand || evaluatedHand.size != 5) return

        var name = "No Win"
        var payout = 0
        var rank: PokerHandRank? = null

        for (entry in payTable) {
            if (VideoPokerScoring.matches(result, evaluatedHand, entry, _options.value.variant)) {
                name = entry.handName
                payout = entry.payout(s.currentBet)
                rank = entry.rank
                break
            }
        }

        // Read before phase flips to Result, while isFreePlay still returns this hand's lock.
        val freePlay = s.handFreePlay
        _state.value = s.copy(
            lastHandName = name,
            lastPayout = payout,
            drawCommitted = false,
            phase = VideoPokerPhase.Result
        )
        outOfCreditsCheckDue = true

        var stats = _statistics.value
        val previousHandsWon = stats.handsWon

        if (rank != null) {
            stats = stats.copy(
                currentStreak = stats.currentStreak + 1,
                longestStreak = max(stats.longestStreak, stats.currentStreak + 1)
            )
            if (payout > 0) {
                com.leah.honeycomb.audio.UISound.play("victory")
                stats = stats.copy(handsWon = stats.handsWon + 1)
                if (rank == PokerHandRank.RoyalFlush) {
                    stats = stats.copy(royalFlushCount = stats.royalFlushCount + 1)
                }
                if (!freePlay) {
                    _state.value = _state.value.copy(sessionCredits = _state.value.sessionCredits + payout)
                    stats = stats.copy(
                        totalPaidOut = stats.totalPaidOut + payout,
                        biggestPayout = max(stats.biggestPayout, payout)
                    )
                }
            }
        } else {
            stats = stats.copy(currentStreak = 0)
        }
        
        _statistics.value = stats
        persistStatistics()
        checkWinMilestones(previousHandsWon)
    }


    fun increaseBet() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Deal && s.phase != VideoPokerPhase.Result) return
        _state.value = s.copy(currentBet = Math.min(5, s.currentBet + 1))
    }

    fun decreaseBet() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Deal && s.phase != VideoPokerPhase.Result) return
        _state.value = s.copy(currentBet = Math.max(1, s.currentBet - 1))
    }

    fun maxBet() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Deal && s.phase != VideoPokerPhase.Result) return
        if (!isFreePlay && s.sessionCredits < 1) return
        _state.value = s.copy(currentBet = max(1, Math.min(5, s.sessionCredits)))
        deal()
    }

    fun updateVariant(variant: VideoPokerVariant) {
        val changed = variant != _options.value.variant
        _options.value = _options.value.copy(variant = variant)
        saveOptions(_options.value)
        // Matches Mac's resetHandDisplay() on a variant change (and Windows' SetVariant):
        // clear the hand in progress rather than let a hand dealt under one variant be
        // evaluated under another — Options is reachable mid-hand here, so without this a
        // player could see two deuces, switch to Deuces Wild, then draw. Credits untouched.
        if (changed && _state.value.phase != VideoPokerPhase.Deal) {
            drawGeneration++
            _state.value = _state.value.copy(
                phase = VideoPokerPhase.Deal,
                hand = emptyList(),
                heldIndices = emptySet(),
                lastPayout = 0,
                lastHandName = "",
                drawCommitted = false
            )
        }
    }

    fun updateOptions(newOptions: VideoPokerOptions) {
        _options.value = newOptions
        saveOptions(newOptions)
    }

    fun resetIfRoundOver() {
        if (_state.value.phase != VideoPokerPhase.Result) return
        drawGeneration++
        _state.value = _state.value.copy(
            phase = VideoPokerPhase.Deal,
            hand = emptyList(),
            heldIndices = emptySet(),
            lastPayout = 0,
            lastHandName = ""
        )
    }

    fun startNewGame() {
        drawGeneration++ // a pending evaluation from the abandoned hand must not land on the new game
        if (_state.value.phase == VideoPokerPhase.Holding) {
            _statistics.value = _statistics.value.copy(currentStreak = 0)
            persistStatistics()
        }
        val newState = VideoPokerState(
            sessionCredits = _options.value.startingCredits,
            currentBet = _options.value.betPerHand
        )
        _state.value = newState
        
        PreferencesHelper.saveObjectAsync(
            dataStore, "videopoker_saved_initial_state", VideoPokerState.serializer(), newState
        )
    }
    
    // For unit tests
    var debugDeck: List<Card>? = null
}

// Pure hand scoring (pay tables + qualifier rules), independent of any live game, so
// the cross-platform Video Poker vectors (VideoPokerVectorTests) can check every
// variant/bet. Mirrors Swift's VideoPokerViewModel.payTable(for:)/scoreHand.
object VideoPokerScoring {
    val jacksOrBetterTable = listOf(
        VideoPokerPayEntry("Royal Flush", PokerHandRank.RoyalFlush, VideoPokerQualifier.None, listOf(250, 250, 250, 250, 800)),
        VideoPokerPayEntry("Straight Flush", PokerHandRank.StraightFlush, VideoPokerQualifier.None, listOf(50, 50, 50, 50, 50)),
        VideoPokerPayEntry("Four of a Kind", PokerHandRank.FourOfAKind, VideoPokerQualifier.None, listOf(25, 25, 25, 25, 25)),
        VideoPokerPayEntry("Full House", PokerHandRank.FullHouse, VideoPokerQualifier.None, listOf(9, 9, 9, 9, 9)),
        VideoPokerPayEntry("Flush", PokerHandRank.Flush, VideoPokerQualifier.None, listOf(6, 6, 6, 6, 6)),
        VideoPokerPayEntry("Straight", PokerHandRank.Straight, VideoPokerQualifier.None, listOf(4, 4, 4, 4, 4)),
        VideoPokerPayEntry("Three of a Kind", PokerHandRank.ThreeOfAKind, VideoPokerQualifier.None, listOf(3, 3, 3, 3, 3)),
        VideoPokerPayEntry("Two Pair", PokerHandRank.TwoPair, VideoPokerQualifier.None, listOf(2, 2, 2, 2, 2)),
        VideoPokerPayEntry("Jacks or Better", PokerHandRank.OnePair, VideoPokerQualifier.JacksOrBetter, listOf(1, 1, 1, 1, 1))
    )

    val deucesWildTable = listOf(
        VideoPokerPayEntry("Natural Royal Flush", PokerHandRank.RoyalFlush, VideoPokerQualifier.None, listOf(250, 250, 250, 250, 800)),
        VideoPokerPayEntry("Four Deuces", PokerHandRank.FourOfAKind, VideoPokerQualifier.BonusFours(2), listOf(200, 200, 200, 200, 200)),
        VideoPokerPayEntry("Wild Royal Flush", PokerHandRank.RoyalFlush, VideoPokerQualifier.DeucesWild, listOf(25, 25, 25, 25, 25)),
        VideoPokerPayEntry("Five of a Kind", PokerHandRank.FourOfAKind, VideoPokerQualifier.DeucesWild, listOf(15, 15, 15, 15, 15)),
        VideoPokerPayEntry("Straight Flush", PokerHandRank.StraightFlush, VideoPokerQualifier.None, listOf(9, 9, 9, 9, 9)),
        VideoPokerPayEntry("Four of a Kind", PokerHandRank.FourOfAKind, VideoPokerQualifier.None, listOf(5, 5, 5, 5, 5)),
        VideoPokerPayEntry("Full House", PokerHandRank.FullHouse, VideoPokerQualifier.None, listOf(3, 3, 3, 3, 3)),
        VideoPokerPayEntry("Flush", PokerHandRank.Flush, VideoPokerQualifier.None, listOf(2, 2, 2, 2, 2)),
        VideoPokerPayEntry("Straight", PokerHandRank.Straight, VideoPokerQualifier.None, listOf(2, 2, 2, 2, 2)),
        VideoPokerPayEntry("Three of a Kind", PokerHandRank.ThreeOfAKind, VideoPokerQualifier.None, listOf(1, 1, 1, 1, 1))
    )

    val bonusPokerTable = listOf(
        VideoPokerPayEntry("Royal Flush", PokerHandRank.RoyalFlush, VideoPokerQualifier.None, listOf(250, 250, 250, 250, 800)),
        VideoPokerPayEntry("Straight Flush", PokerHandRank.StraightFlush, VideoPokerQualifier.None, listOf(50, 50, 50, 50, 50)),
        VideoPokerPayEntry("Four Aces", PokerHandRank.FourOfAKind, VideoPokerQualifier.BonusFours(1), listOf(80, 80, 80, 80, 80)),
        VideoPokerPayEntry("Four 2s–4s", PokerHandRank.FourOfAKind, VideoPokerQualifier.BonusFours(4), listOf(40, 40, 40, 40, 40)),
        VideoPokerPayEntry("Four of a Kind", PokerHandRank.FourOfAKind, VideoPokerQualifier.None, listOf(25, 25, 25, 25, 25)),
        VideoPokerPayEntry("Full House", PokerHandRank.FullHouse, VideoPokerQualifier.None, listOf(8, 8, 8, 8, 8)),
        VideoPokerPayEntry("Flush", PokerHandRank.Flush, VideoPokerQualifier.None, listOf(5, 5, 5, 5, 5)),
        VideoPokerPayEntry("Straight", PokerHandRank.Straight, VideoPokerQualifier.None, listOf(4, 4, 4, 4, 4)),
        VideoPokerPayEntry("Three of a Kind", PokerHandRank.ThreeOfAKind, VideoPokerQualifier.None, listOf(3, 3, 3, 3, 3)),
        VideoPokerPayEntry("Two Pair", PokerHandRank.TwoPair, VideoPokerQualifier.None, listOf(2, 2, 2, 2, 2)),
        VideoPokerPayEntry("Jacks or Better", PokerHandRank.OnePair, VideoPokerQualifier.JacksOrBetter, listOf(1, 1, 1, 1, 1))
    )

    fun payTable(variant: VideoPokerVariant): List<VideoPokerPayEntry> = when (variant) {
        VideoPokerVariant.JacksOrBetter -> jacksOrBetterTable
        VideoPokerVariant.DeucesWild -> deucesWildTable
        VideoPokerVariant.BonusPoker -> bonusPokerTable
    }

    // Returns the paying hand's name and payout, or ("No Win", 0).
    fun scoreHand(hand: List<Card>, variant: VideoPokerVariant, bet: Int): Pair<String, Int> {
        if (hand.size != 5) return Pair("No Win", 0)
        val result = if (variant == VideoPokerVariant.DeucesWild) PokerHandEvaluator.evaluateWithDeuces(hand) else PokerHandEvaluator.evaluate(hand)
        for (entry in payTable(variant)) {
            if (matches(result, hand, entry, variant)) return Pair(entry.handName, entry.payout(bet))
        }
        return Pair("No Win", 0)
    }

    fun matches(result: PokerHandResult, hand: List<Card>, entry: VideoPokerPayEntry, variant: VideoPokerVariant): Boolean {
        if (result.rank != entry.rank) return false
        
        when (entry.qualifier) {
            is VideoPokerQualifier.None -> {
                if (variant == VideoPokerVariant.DeucesWild && entry.rank == PokerHandRank.RoyalFlush) {
                    return !hand.any { it.rank == 2 }
                }
                return true
            }
            is VideoPokerQualifier.JacksOrBetter -> {
                if (result.rank != PokerHandRank.OnePair) return false
                val qualifyingRanks = setOf(1, 11, 12, 13)
                val freq = mutableMapOf<Int, Int>()
                hand.forEach { freq[it.rank] = freq.getOrDefault(it.rank, 0) + 1 }
                return freq.any { qualifyingRanks.contains(it.key) && it.value >= 2 }
            }
            is VideoPokerQualifier.DeucesWild -> {
                if (entry.handName == "Five of a Kind") {
                    return result.kickers.size == 2 && result.kickers[1] == 15
                }
                return hand.any { it.rank == 2 }
            }
            is VideoPokerQualifier.BonusFours -> {
                if (result.rank != PokerHandRank.FourOfAKind) return false
                val freq = mutableMapOf<Int, Int>()
                hand.forEach { freq[it.rank] = freq.getOrDefault(it.rank, 0) + 1 }
                val bonusRank = entry.qualifier.rank
                if (bonusRank == 4) {
                    return freq.any { listOf(2, 3, 4).contains(it.key) && it.value == 4 }
                } else {
                    return freq[bonusRank] == 4
                }
            }
        }
    }
}
