package com.leah.honeycomb.blackjack

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.Card
import com.leah.honeycomb.PreferencesHelper
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.Suit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.max

class BlackjackViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(BlackjackState())
    val state: StateFlow<BlackjackState> = _state.asStateFlow()

    fun updateOptions(newOptions: BlackjackOptions) {
        _options.value = newOptions
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "blackjack_options", BlackjackOptions.serializer(), newOptions)
        }
    }

    private val _options = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "blackjack_options", BlackjackOptions.serializer(), BlackjackOptions())
    )
    val options: StateFlow<BlackjackOptions> = _options.asStateFlow()

    private val _statistics = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "blackjack_statistics", BlackjackStatistics.serializer(), BlackjackStatistics())
    )
    val statistics: StateFlow<BlackjackStatistics> = _statistics.asStateFlow()

    private fun persistStatistics() {
        val snapshot = _statistics.value
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "blackjack_statistics", BlackjackStatistics.serializer(), snapshot)
        }
    }

    private var handGeneration = 0

    init {
        startNewGame()
    }

    val isFreePlay: Boolean
        get() = sharedOptions.noStressMode.value

    val canOpenOptions: Boolean
        get() = _state.value.phase == BlackjackPhase.Betting || _state.value.phase == BlackjackPhase.Result

    val canSplit: Boolean
        get() {
            val s = _state.value
            return s.playerHands.size == 1 &&
                   s.playerHands[0].cards.size == 2 &&
                   s.playerHands[0].cards[0].rank == s.playerHands[0].cards[1].rank &&
                   (isFreePlay || s.sessionCredits >= s.currentBet)
        }

    val isDealerBlackjackPending: Boolean
        get() {
            val s = _state.value
            if (s.phase != BlackjackPhase.Playing || s.dealerCards.size != 2) return false
            val ranks = s.dealerCards.map { it.rank }
            return ranks.contains(1) && ranks.any { it >= 10 }
        }

    val canDouble: Boolean
        get() {
            val s = _state.value
            if (s.activeHandIndex >= s.playerHands.size) return false
            val hand = s.playerHands[s.activeHandIndex]
            return hand.cards.size == 2 &&
                   !hand.isSplitAce &&
                   hand.value in 9..11 &&
                   (isFreePlay || s.sessionCredits >= hand.bet)
        }

    val canRebuy: Boolean
        get() {
            val s = _state.value
            return !isFreePlay &&
                   (s.phase == BlackjackPhase.Betting || s.phase == BlackjackPhase.Result) &&
                   s.sessionCredits <= 10
        }

    val activeHand: BlackjackHand?
        get() {
            val s = _state.value
            if (s.activeHandIndex >= s.playerHands.size) return null
            return s.playerHands[s.activeHandIndex]
        }

    var debugDeck: List<Card>? = null

    private fun freshDeck(): List<Card> {
        if (debugDeck != null) return debugDeck!!.toList()
        val deck = mutableListOf<Card>()
        for (suit in Suit.values()) {
            for (rank in 1..13) {
                deck.add(Card(suit = suit, rank = rank, faceUp = true))
            }
        }
        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")
        return deck
    }

    private fun popCard(faceUp: Boolean = true): Card? {
        val s = _state.value
        if (s.deck.isEmpty()) return null
        val newDeck = s.deck.toMutableList()
        val card = newDeck.removeLast().copy(faceUp = faceUp)
        _state.value = s.copy(deck = newDeck)
        return card
    }

    fun deal() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Betting && s.phase != BlackjackPhase.Result) return
        if (!isFreePlay && s.sessionCredits < s.currentBet) return

        val newSessionCredits = if (!isFreePlay) s.sessionCredits - s.currentBet else s.sessionCredits
        val newTotalWagered = if (!isFreePlay) _statistics.value.totalWagered + s.currentBet else _statistics.value.totalWagered
        
        val stats = _statistics.value
        _statistics.value = stats.copy(
            handsPlayed = stats.handsPlayed + 1,
            totalWagered = newTotalWagered
        )
        persistStatistics()

        _state.value = s.copy(
            sessionCredits = newSessionCredits,
            handsDealt = s.handsDealt + 1,
            deck = freshDeck(),
            resultOutcome = BlackjackRoundOutcome.None,
            phase = BlackjackPhase.Playing
        )

        val p1 = popCard(faceUp = true) ?: return
        val d1 = popCard(faceUp = true) ?: return
        val p2 = popCard(faceUp = true) ?: return
        val d2 = popCard(faceUp = false) ?: return

        _state.value = _state.value.copy(
            playerHands = listOf(BlackjackHand(cards = listOf(p1, p2), bet = s.currentBet)),
            dealerCards = listOf(d1, d2),
            activeHandIndex = 0
        )

        val dealerRanks = listOf(d1.rank, d2.rank)
        val dealerHasBlackjack = dealerRanks.contains(1) && dealerRanks.any { it >= 10 }
        
        handGeneration++
        val generation = handGeneration

        if (dealerHasBlackjack) {
            viewModelScope.launch(Dispatchers.Main) {
                delay(1000)
                if (handGeneration == generation) {
                    executeDealerTurn()
                }
            }
            return
        }

        if (_state.value.playerHands[0].isBlackjack) {
            viewModelScope.launch(Dispatchers.Main) {
                delay(1500)
                if (handGeneration == generation) {
                    executeDealerTurn()
                }
            }
        }
    }

    fun hit() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Playing) return
        if (isDealerBlackjackPending) return
        if (s.activeHandIndex >= s.playerHands.size) return
        if (s.playerHands.size == 1 && s.playerHands[0].isBlackjack) return
        if (s.playerHands[s.activeHandIndex].isSplitAce) return
        
        val card = popCard(faceUp = true) ?: return
        com.leah.honeycomb.audio.UISound.play("snap")

        val hands = s.playerHands.toMutableList()
        val hand = hands[s.activeHandIndex]
        hands[s.activeHandIndex] = hand.copy(cards = hand.cards + card)
        _state.value = s.copy(playerHands = hands)
        
        val updatedHand = _state.value.playerHands[s.activeHandIndex]
        if (updatedHand.isBust || updatedHand.value == 21) {
            advanceHand()
        }
    }

    fun stand() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Playing) return
        if (isDealerBlackjackPending) return
        if (s.activeHandIndex >= s.playerHands.size) return
        if (s.playerHands.size == 1 && s.playerHands[0].isBlackjack) return
        if (s.playerHands[s.activeHandIndex].isSplitAce) return
        advanceHand()
    }

    fun doubleDown() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Playing) return
        if (isDealerBlackjackPending) return
        if (!canDouble) return
        if (s.playerHands.size == 1 && s.playerHands[0].isBlackjack) return
        
        val hand = s.playerHands[s.activeHandIndex]
        val newSessionCredits = if (!isFreePlay) s.sessionCredits - hand.bet else s.sessionCredits
        val newTotalWagered = if (!isFreePlay) _statistics.value.totalWagered + hand.bet else _statistics.value.totalWagered
        
        _statistics.value = _statistics.value.copy(totalWagered = newTotalWagered)
        persistStatistics()

        val card = popCard(faceUp = true) ?: return
        com.leah.honeycomb.audio.UISound.play("snap")

        val hands = s.playerHands.toMutableList()
        hands[s.activeHandIndex] = hand.copy(
            bet = hand.bet * 2,
            isDoubled = true,
            cards = hand.cards + card
        )
        
        _state.value = s.copy(
            sessionCredits = newSessionCredits,
            playerHands = hands
        )
        advanceHand()
    }

    fun split() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Playing || !canSplit) return
        if (isDealerBlackjackPending) return
        if (s.playerHands.size == 1 && s.playerHands[0].isBlackjack) return
        
        val originalBet = s.playerHands[0].bet
        val newSessionCredits = if (!isFreePlay) s.sessionCredits - originalBet else s.sessionCredits
        val newTotalWagered = if (!isFreePlay) _statistics.value.totalWagered + originalBet else _statistics.value.totalWagered
        
        _statistics.value = _statistics.value.copy(
            totalWagered = newTotalWagered,
            handsPlayed = _statistics.value.handsPlayed + 1
        )
        persistStatistics()

        val card0 = s.playerHands[0].cards[0]
        val card1 = s.playerHands[0].cards[1]
        val isAces = card0.rank == 1
        
        val extra0 = popCard(faceUp = true) ?: card0
        val extra1 = popCard(faceUp = true) ?: card1
        com.leah.honeycomb.audio.UISound.play("snap")
        
        val hand0 = BlackjackHand(cards = listOf(card0, extra0), bet = originalBet, isSplitAce = isAces)
        val hand1 = BlackjackHand(cards = listOf(card1, extra1), bet = originalBet, isSplitAce = isAces)
        
        _state.value = s.copy(
            sessionCredits = newSessionCredits,
            playerHands = listOf(hand0, hand1),
            activeHandIndex = 0
        )
        
        if (isAces) {
            handGeneration++
            val generation = handGeneration
            viewModelScope.launch(Dispatchers.Main) {
                delay(1500)
                if (handGeneration == generation) {
                    executeDealerTurn()
                }
            }
        } else if (_state.value.playerHands[0].value == 21) {
            advanceHand()
        }
    }

    fun addToBet(amount: Int) {
        val s = _state.value
        if (s.phase != BlackjackPhase.Betting && s.phase != BlackjackPhase.Result) return
        if (amount != 1 && s.currentBet == 1) {
            _state.value = s.copy(currentBet = max(1, Math.min(amount, s.sessionCredits)))
        } else {
            _state.value = s.copy(currentBet = max(1, Math.min(s.currentBet + amount, s.sessionCredits)))
        }
    }

    fun doubleBet() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Betting && s.phase != BlackjackPhase.Result) return
        _state.value = s.copy(currentBet = max(1, Math.min(s.currentBet * 2, s.sessionCredits)))
    }

    fun clearBet() {
        val s = _state.value
        if (s.phase != BlackjackPhase.Betting && s.phase != BlackjackPhase.Result) return
        _state.value = s.copy(currentBet = 1)
    }

    fun rebuy() {
        _state.value = _state.value.copy(sessionCredits = _state.value.sessionCredits + _options.value.startingCredits)
        _statistics.value = _statistics.value.copy(rebuyCount = _statistics.value.rebuyCount + 1)
        persistStatistics()
    }

    private fun advanceHand() {
        val s = _state.value
        val next = s.activeHandIndex + 1
        if (next < s.playerHands.size) {
            _state.value = s.copy(activeHandIndex = next)
            if (_state.value.playerHands[next].isComplete) {
                advanceHand()
            }
        } else {
            executeDealerTurn()
        }
    }

    private fun executeDealerTurn() {
        var s = _state.value
        if (s.phase != BlackjackPhase.Playing) return
        
        val dealerCards = s.dealerCards.toMutableList()
        if (dealerCards.size > 1) {
            dealerCards[1] = dealerCards[1].copy(faceUp = true)
        }
        
        _state.value = s.copy(
            phase = BlackjackPhase.DealerTurn,
            dealerCards = dealerCards
        )
        
        while (BlackjackState.handValue(_state.value.dealerCards) < 17) {
            val card = popCard(faceUp = true) ?: break
            com.leah.honeycomb.audio.UISound.play("snap")
            val currentDealerCards = _state.value.dealerCards.toMutableList()
            currentDealerCards.add(card)
            _state.value = _state.value.copy(dealerCards = currentDealerCards)
        }
        
        evaluateAllHands()
        
        s = _state.value
        s = s.copy(phase = BlackjackPhase.Result)
        
        if (!isFreePlay && s.currentBet > s.sessionCredits) {
            s = s.copy(currentBet = 1)
        }
        
        _state.value = s
    }

    private fun evaluateAllHands() {
        val s = _state.value
        val dealerValue = s.dealerValue
        val dealerBJ = s.dealerCards.size == 2 && dealerValue == 21
        var totalPayout = 0
        var totalWagered = 0
        
        var stats = _statistics.value
        
        val hands = s.playerHands.toMutableList()
        
        for (i in hands.indices) {
            val hand = hands[i]
            totalWagered += hand.bet
            val playerValue = hand.value
            val playerBJ = hand.isBlackjack && hands.size == 1
            
            val result: BlackjackHandResult
            var payout = 0
            
            if (playerBJ && dealerBJ) {
                result = BlackjackHandResult.Push
                payout = hand.bet
                stats = stats.copy(pushes = stats.pushes + 1)
            } else if (playerBJ) {
                result = BlackjackHandResult.Blackjack
                payout = hand.bet * 4 // Pays 3:1 (bet + 3*bet) -> Wait, swift says: payout = hand.bet * 4
                // Actually Swift code says: payout = hand.bet * 4 but comment says "profit 3x bet".
                // If it's 3:1 payout, you get your bet back (1) + 3 profit = 4x bet.
                stats = stats.copy(
                    blackjacks = stats.blackjacks + 1,
                    handsWon = stats.handsWon + 1
                )
            } else if (hand.isBust) {
                result = BlackjackHandResult.Bust
                stats = stats.copy(handsLost = stats.handsLost + 1)
            } else if (dealerBJ || (!hand.isBust && dealerValue > playerValue && dealerValue <= 21)) {
                result = BlackjackHandResult.Loss
                stats = stats.copy(handsLost = stats.handsLost + 1)
            } else if (dealerValue > 21 || playerValue > dealerValue) {
                result = BlackjackHandResult.Win
                payout = hand.bet * 2
                stats = stats.copy(handsWon = stats.handsWon + 1)
            } else {
                result = BlackjackHandResult.Push
                payout = hand.bet
                stats = stats.copy(pushes = stats.pushes + 1)
            }
            
            hands[i] = hand.copy(result = result)
            totalPayout += payout
            
            if (!isFreePlay) {
                val newCredits = _state.value.sessionCredits + payout
                _state.value = _state.value.copy(sessionCredits = newCredits)
                
                stats = stats.copy(totalPaidOut = stats.totalPaidOut + payout)
                if (result != BlackjackHandResult.Push) {
                    stats = stats.copy(biggestPayout = max(stats.biggestPayout, payout))
                }
            }
        }
        
        val lastNetResult = totalPayout - totalWagered
        
        val anyBJ = hands.any { it.result == BlackjackHandResult.Blackjack }
        val anyWin = hands.any { it.result == BlackjackHandResult.Win || it.result == BlackjackHandResult.Blackjack }
        val allPush = hands.isNotEmpty() && hands.all { it.result == BlackjackHandResult.Push }
        val playerBust = hands.isNotEmpty() && hands.all { it.isBust }
        
        val outcome = when {
            anyBJ -> BlackjackRoundOutcome.Blackjack
            anyWin -> BlackjackRoundOutcome.Win
            allPush -> BlackjackRoundOutcome.Push
            playerBust -> BlackjackRoundOutcome.Bust
            else -> BlackjackRoundOutcome.Loss
        }
        if (outcome == BlackjackRoundOutcome.Blackjack || outcome == BlackjackRoundOutcome.Win) {
            com.leah.honeycomb.audio.UISound.play("victory")
        }
        
        _state.value = _state.value.copy(
            playerHands = hands,
            lastNetResult = lastNetResult,
            resultOutcome = outcome
        )
        
        val roundWon = hands.any { it.result == BlackjackHandResult.Win || it.result == BlackjackHandResult.Blackjack }
        val roundLost = hands.any { it.result == BlackjackHandResult.Loss || it.result == BlackjackHandResult.Bust }
        
        if (roundWon && !roundLost) {
            stats = stats.copy(
                currentStreak = stats.currentStreak + 1,
                longestStreak = max(stats.longestStreak, stats.currentStreak + 1)
            )
        } else if (roundLost) {
            stats = stats.copy(currentStreak = 0)
        }
        
        _statistics.value = stats
        persistStatistics()
    }

    fun resetIfRoundOver() {
        if (_state.value.phase != BlackjackPhase.Result) return
        _state.value = _state.value.copy(
            playerHands = emptyList(),
            activeHandIndex = 0,
            dealerCards = emptyList(),
            resultOutcome = BlackjackRoundOutcome.None,
            lastNetResult = 0,
            phase = BlackjackPhase.Betting
        )
    }

    fun startNewGame() {
        handGeneration++
        _state.value = BlackjackState(
            sessionCredits = _options.value.startingCredits,
            currentBet = 1
        )
        _statistics.value = _statistics.value.copy(currentStreak = 0)
        persistStatistics()
    }
}
