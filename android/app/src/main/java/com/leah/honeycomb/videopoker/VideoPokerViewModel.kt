package com.leah.honeycomb.videopoker

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.Card
import com.leah.honeycomb.PreferencesHelper
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.Suit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.max

class VideoPokerViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(VideoPokerState())
    val state: StateFlow<VideoPokerState> = _state.asStateFlow()

    private fun saveOptions(options: VideoPokerOptions) {
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "videopoker_options", VideoPokerOptions.serializer(), options)
        }
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
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "videopoker_statistics", VideoPokerStatistics.serializer(), snapshot)
        }
    }

    init {
        startNewGame()
    }

    val isFreePlay: Boolean
        get() = sharedOptions.noStressMode.value

    val canOpenOptions: Boolean
        get() = _state.value.phase == VideoPokerPhase.Deal || _state.value.phase == VideoPokerPhase.Result

    val totalBet: Int
        get() = _state.value.currentBet

    private val jacksOrBetterTable = listOf(
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

    private val deucesWildTable = listOf(
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

    private val bonusPokerTable = listOf(
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

    val payTable: List<VideoPokerPayEntry>
        get() = when (_options.value.variant) {
            VideoPokerVariant.JacksOrBetter -> jacksOrBetterTable
            VideoPokerVariant.DeucesWild -> deucesWildTable
            VideoPokerVariant.BonusPoker -> bonusPokerTable
        }

    fun rebuy() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Deal && s.phase != VideoPokerPhase.Result) return
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
        
        _statistics.value = _statistics.value.copy(
            handsPlayed = _statistics.value.handsPlayed + 1,
            totalWagered = newWagered
        )
        persistStatistics()

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
        
        _state.value = s.copy(
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
        if (s.phase != VideoPokerPhase.Holding || index >= 5) return
        val newHeld = s.heldIndices.toMutableSet()
        if (newHeld.contains(index)) {
            newHeld.remove(index)
        } else {
            newHeld.add(index)
        }
        _state.value = s.copy(heldIndices = newHeld)
    }

    fun draw() {
        val s = _state.value
        if (s.phase != VideoPokerPhase.Holding) return
        
        val hand = s.hand.toMutableList()
        val deck = s.deck.toMutableList()
        
        for (i in 0 until 5) {
            if (!s.heldIndices.contains(i)) {
                if (deck.isNotEmpty()) {
                    hand[i] = deck.removeFirst()
                }
            }
        }
        
        _state.value = s.copy(
            hand = hand,
            deck = deck
        )
        evaluate()
        _state.value = _state.value.copy(phase = VideoPokerPhase.Result)
    }

    private fun evaluate() {
        val s = _state.value
        if (s.hand.size != 5) return
        
        val result = if (_options.value.variant == VideoPokerVariant.DeucesWild) {
            PokerHandEvaluator.evaluateWithDeuces(s.hand)
        } else {
            PokerHandEvaluator.evaluate(s.hand)
        }
        
        var name = "No Win"
        var payout = 0
        var rank: PokerHandRank? = null
        
        for (entry in payTable) {
            if (matches(result, s.hand, entry)) {
                name = entry.handName
                payout = entry.payout(s.currentBet)
                rank = entry.rank
                break
            }
        }
        
        _state.value = s.copy(
            lastHandName = name,
            lastPayout = payout
        )
        
        var stats = _statistics.value
        
        if (rank != null) {
            stats = stats.copy(
                currentStreak = stats.currentStreak + 1,
                longestStreak = max(stats.longestStreak, stats.currentStreak + 1)
            )
            if (payout > 0) {
                stats = stats.copy(handsWon = stats.handsWon + 1)
                if (rank == PokerHandRank.RoyalFlush) {
                    stats = stats.copy(royalFlushCount = stats.royalFlushCount + 1)
                }
                if (!isFreePlay) {
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
    }

    private fun matches(result: PokerHandResult, hand: List<Card>, entry: VideoPokerPayEntry): Boolean {
        if (result.rank != entry.rank) return false
        
        when (entry.qualifier) {
            is VideoPokerQualifier.None -> {
                if (_options.value.variant == VideoPokerVariant.DeucesWild && entry.rank == PokerHandRank.RoyalFlush) {
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
        _state.value = s.copy(currentBet = max(1, Math.min(5, s.sessionCredits)))
        deal()
    }

    fun updateVariant(variant: VideoPokerVariant) {
        _options.value = _options.value.copy(variant = variant)
        saveOptions(_options.value)
    }

    fun resetIfRoundOver() {
        if (_state.value.phase != VideoPokerPhase.Result) return
        _state.value = _state.value.copy(
            phase = VideoPokerPhase.Deal,
            hand = emptyList(),
            heldIndices = emptySet(),
            lastPayout = 0,
            lastHandName = ""
        )
    }

    fun startNewGame() {
        if (_state.value.phase == VideoPokerPhase.Holding) {
            _statistics.value = _statistics.value.copy(currentStreak = 0)
            persistStatistics()
        }
        _state.value = VideoPokerState(
            sessionCredits = _options.value.startingCredits,
            currentBet = _options.value.betPerHand
        )
    }
    
    // For unit tests
    var debugDeck: List<Card>? = null
}
