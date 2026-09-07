package com.leah.honeycomb.honeycomb

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.PreferencesHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

@kotlinx.serialization.Serializable
data class HoneycombOptions(
    val difficulty: HoneycombDifficulty = HoneycombDifficulty.Easy,
    val activeDeckIndex: Int = 0,
    val selectedRules: Set<HoneycombRule> = emptySet(),
    val forceNormalMode: Boolean = false,
    val bannedRules: Set<String> = emptySet()
)

data class PendingSteal(
    val boardIndex: Int,
    val cardName: String
)

data class HoneycombState(
    val board: HoneycombBoard = HoneycombBoard(),
    val playerHand: List<HoneycombCard> = emptyList(),
    val playerStartingDeck: List<HoneycombCard> = emptyList(),
    val opponentHand: List<HoneycombCard> = emptyList(),
    val openOpponentCardIds: Set<String> = emptySet(),
    val openPlayerCardIds: Set<String> = emptySet(),
    val activeRules: List<HoneycombRule> = emptyList(),
    val ascensionDescensionSuits: Set<String> = emptySet(),
    val gameState: HoneycombGameState = HoneycombGameState.Setup,
    val isPlayerTurn: Boolean = true,
    val showPostGamePrompt: Boolean = false,
    val matchOutcome: HoneycombMatchOutcome = HoneycombMatchOutcome.None,
    val matchResult: String = "",
    val matchResultFlavorText: String? = null,
    val pendingSteal: PendingSteal? = null,
    val mandatedPlayerHandIndex: Int? = null,
    val mandatedOpponentHandIndex: Int? = null,
    val chaosPlayerIndex: Int? = null,
    val chaosOpponentIndex: Int? = null
)

class HoneycombViewModel(
    val sharedOptions: SharedGameOptions,
    val database: HoneycombDatabase,
    val profileManager: HoneycombProfileManager,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(HoneycombState())
    val state: StateFlow<HoneycombState> = _state.asStateFlow()

    private val _options = MutableStateFlow(loadOptions())
    val options: StateFlow<HoneycombOptions> = _options.asStateFlow()

    fun updateOptions(newOptions: HoneycombOptions) {
        _options.value = newOptions
        saveOptions(newOptions)
    }

    private fun loadOptions(): HoneycombOptions =
        PreferencesHelper.getObjectSync(dataStore, "honeycomb_options", HoneycombOptions.serializer(), HoneycombOptions())

    private fun saveOptions(options: HoneycombOptions) {
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "honeycomb_options", HoneycombOptions.serializer(), options)
        }
    }

    // Bad-luck protection for Roulette (see rollRouletteOnce below): re-rolling a draw
    // that exactly repeats the previous match's result, up to a small retry cap.
    private var lastRouletteSignature: String? = null

    private fun rouletteSignature(rules: List<HoneycombRule>, suits: Set<String>): String {
        val ruleNames = rules.map { it.name }.sorted().joinToString(",")
        val suitNames = suits.sorted().joinToString(",")
        return "$ruleNames|$suitNames"
    }

    // Weighted draw from `pool` using each rule's HoneycombRule.weight.
    private fun weightedRandomRule(pool: List<HoneycombRule>): HoneycombRule {
        val totalWeight = pool.sumOf { it.weight }
        var randomValue = (0 until totalWeight).random()
        for (rule in pool) {
            randomValue -= rule.weight
            if (randomValue < 0) return rule
        }
        return pool.last()
    }

    // One independent roulette draw — rule set plus (if applicable) Ascension/Descension
    // suit. Ported from Swift's rollRouletteOnce(): a flat per-draw stop probability
    // (not scaled by how much exclusivity has shrunk the pool), a difficulty-scaled slot
    // count (Hard/UltraHard can roll extra rules), and mutual-exclusivity pool-pruning
    // as each rule is drawn.
    private fun rollRouletteOnce(opts: HoneycombOptions): Pair<List<HoneycombRule>, Set<String>> {
        var pool = HoneycombRule.entries.toMutableList()
        pool.removeAll { opts.bannedRules.contains(it.name) }

        if (opts.difficulty == HoneycombDifficulty.Easy) {
            pool.removeAll { it == HoneycombRule.Ascension || it == HoneycombRule.Descension || it == HoneycombRule.FallenAce }
        }

        val normalBanned = opts.bannedRules.contains("Normal Mode")

        val originalPoolSize = pool.size
        val stopProbabilityFirst = 1.0 / (originalPoolSize + 1)
        val targetSingleRuleRate = 1.0 / 3.0
        val stopProbabilitySecond = targetSingleRuleRate / (1.0 - stopProbabilityFirst)

        var maxSlots = 2
        var forceMustPickAll = false

        if (opts.difficulty == HoneycombDifficulty.UltraHard) {
            val roll = Math.random()
            maxSlots = when {
                roll < 0.25 -> 4
                roll < 0.70 -> 3
                roll < 0.95 -> 2
                roll < 0.99 -> 1
                else -> 0
            }
            if (maxSlots == 0 && normalBanned) maxSlots = 1
            forceMustPickAll = true
        } else if (opts.difficulty == HoneycombDifficulty.Hard) {
            val hardRoll = Math.random()
            if (hardRoll < 0.01) {
                maxSlots = 4
                forceMustPickAll = true
            } else if (hardRoll < 0.26) {
                maxSlots = 3
                forceMustPickAll = true
            }
        }

        val rules = mutableListOf<HoneycombRule>()
        for (slot in 0 until maxSlots) {
            if (pool.isEmpty()) break
            val mustPick = (slot == 0 && normalBanned) || forceMustPickAll
            val stopProbability = if (slot == 0) stopProbabilityFirst else stopProbabilitySecond
            if (!mustPick && Math.random() < stopProbability) break

            val randomRule = weightedRandomRule(pool)
            rules.add(randomRule)
            pool.removeAll { it == randomRule }
            if (randomRule == HoneycombRule.Ascension) pool.removeAll { it == HoneycombRule.Descension }
            if (randomRule == HoneycombRule.Descension) pool.removeAll { it == HoneycombRule.Ascension }
            if (randomRule == HoneycombRule.Order) pool.removeAll { it == HoneycombRule.Chaos }
            if (randomRule == HoneycombRule.Chaos) pool.removeAll { it == HoneycombRule.Order }
            if (randomRule == HoneycombRule.AllOpen) pool.removeAll { it == HoneycombRule.ThreeOpen }
            if (randomRule == HoneycombRule.ThreeOpen) pool.removeAll { it == HoneycombRule.AllOpen }
            if (randomRule == HoneycombRule.AllOpen || randomRule == HoneycombRule.ThreeOpen) {
                pool.removeAll { it == HoneycombRule.BombShelter }
            }
            if (randomRule == HoneycombRule.BombShelter) {
                pool.removeAll { it == HoneycombRule.AllOpen || it == HoneycombRule.ThreeOpen }
            }
        }

        val suits = if (rules.contains(HoneycombRule.Ascension) || rules.contains(HoneycombRule.Descension)) {
            setOf(listOf("S", "H", "D", "C").random())
        } else {
            emptySet()
        }
        return Pair(rules, suits)
    }

    private var rematchOpponentDeck: List<HoneycombCardData> = emptyList()
    private var rematchActiveRules: List<HoneycombRule> = emptyList()
    private var rematchAscensionDescensionSuits: Set<String> = emptySet()

    private var isRematchMatch: Boolean = false
    private var consecutiveNoStealWins: Int = 0
    private var stealProtectionActive: Boolean = false
    private var hasStolenThisMatch: Boolean = false
    private var starterStreak: Int = 0
    private var lastMatchStarterWasPlayer: Boolean? = null
    
    private var aiMoveGeneration: Int = 0

    init {
        loadOptions()
    }

    fun startNewGame() {
        aiMoveGeneration++
        isRematchMatch = false
        consecutiveNoStealWins = 0
        stealProtectionActive = false
        hasStolenThisMatch = false

        var rolledRules = emptyList<HoneycombRule>()
        var rolledSuits = emptySet<String>()
        val opts = _options.value

        if (opts.forceNormalMode) {
            // Explicitly locked to zero rules — a real "Normal" match, as opposed to
            // an empty selectedRules (which means "let roulette decide" below).
        } else if (opts.selectedRules.isEmpty()) {
            // Auto: let roulette decide, with bad-luck protection against repeating the
            // exact same outcome (rules + suit) as the previous match.
            var attempt: Pair<List<HoneycombRule>, Set<String>>
            var attempts = 0
            do {
                attempt = rollRouletteOnce(opts)
                attempts++
            } while (rouletteSignature(attempt.first, attempt.second) == lastRouletteSignature && attempts < 5)
            rolledRules = attempt.first
            rolledSuits = attempt.second
            lastRouletteSignature = rouletteSignature(rolledRules, rolledSuits)
        } else {
            rolledRules = opts.selectedRules.toList()
        }

        if (rolledRules.contains(HoneycombRule.Ascension) || rolledRules.contains(HoneycombRule.Descension)) {
            rolledSuits = setOf(listOf("S", "H", "D", "C").random())
        }
        
        val deck = rollOpponentDeck(opts.difficulty, rolledRules, rolledSuits)
        
        rematchOpponentDeck = deck
        rematchActiveRules = rolledRules
        rematchAscensionDescensionSuits = rolledSuits

        val opponentHand = deck.map { HoneycombCard(it, CardOwner.Opponent) }

        _state.update { 
            it.copy(
                board = HoneycombBoard().apply { ascensionDescensionSuits = rolledSuits },
                activeRules = rolledRules,
                ascensionDescensionSuits = rolledSuits,
                opponentHand = opponentHand,
                gameState = HoneycombGameState.Playing,
                showPostGamePrompt = false
            )
        }
        setupPlayerHand()
        finishMatchSetup()
    }

    fun rematch() {
        if (rematchOpponentDeck.isEmpty()) {
            startNewGame()
            return
        }
        isRematchMatch = true
        aiMoveGeneration++
        hasStolenThisMatch = false
        
        val opponentHand = rematchOpponentDeck.map { HoneycombCard(it, CardOwner.Opponent) }
        
        _state.update {
            it.copy(
                board = HoneycombBoard().apply { ascensionDescensionSuits = rematchAscensionDescensionSuits },
                activeRules = rematchActiveRules,
                ascensionDescensionSuits = rematchAscensionDescensionSuits,
                opponentHand = opponentHand,
                gameState = HoneycombGameState.Playing,
                showPostGamePrompt = false
            )
        }
        setupPlayerHand()
        finishMatchSetup(forceAlternateStarter = true)
    }

    private fun setupPlayerHand() {
        val activeDeckIndex = _options.value.activeDeckIndex
        val savedDecks = profileManager.savedDecks.value
        val deckIds = if (activeDeckIndex in savedDecks.indices) savedDecks[activeDeckIndex].cardIds else emptyList()
        
        val pDeckData = deckIds.mapNotNull { database.card(it) }
        val pDeck = pDeckData.map { HoneycombCard(it, CardOwner.Player) }
        
        val openPlayerCardIds = if (rematchActiveRules.contains(HoneycombRule.AllOpen) || rematchActiveRules.contains(HoneycombRule.ThreeOpen)) pDeckData.map { it.id.toString() }.toSet() else emptySet()
        _state.update { it.copy(playerHand = pDeck, playerStartingDeck = pDeck, openPlayerCardIds = openPlayerCardIds) }
    }

    private fun rollOpponentDeck(difficulty: HoneycombDifficulty, rules: List<HoneycombRule>, suits: Set<String>): List<HoneycombCardData> {
        val preferLowStats = rules.contains(HoneycombRule.Reverse)
        val composition = if (preferLowStats) {
            when (difficulty) {
                HoneycombDifficulty.Easy -> listOf(Pair(1, 3), Pair(2, 1), Pair(if (Math.random() < 0.2) 3 else 2, 1))
                HoneycombDifficulty.Medium -> listOf(Pair(1, 1), Pair(2, 2), Pair(3, 1), Pair(if (Math.random() < 0.2) 4 else 3, 1))
                HoneycombDifficulty.Hard -> listOf(Pair(1, 2), Pair(2, 3))
                HoneycombDifficulty.UltraHard -> listOf(Pair(1, 5))
            }
        } else {
            when (difficulty) {
                HoneycombDifficulty.Easy -> listOf(Pair(1, 3), Pair(2, 1), Pair(if (Math.random() < 0.2) 3 else 2, 1))
                HoneycombDifficulty.Medium -> listOf(Pair(1, 1), Pair(2, 2), Pair(3, 1), Pair(if (Math.random() < 0.2) 4 else 3, 1))
                HoneycombDifficulty.Hard -> listOf(Pair(2, 2), Pair(3, 3))
                HoneycombDifficulty.UltraHard -> listOf(Pair(3, 2), Pair(4, 1), Pair(5, 2))
            }
        }
        
        val deck = mutableListOf<HoneycombCardData>()
        for ((stars, count) in composition) {
            deck.addAll(database.rulesAwareCards(stars, count, preferLowStats))
        }
        
        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")
        
        return deck
    }

    private fun finishMatchSetup(forceAlternateStarter: Boolean = false) {
        val playerStarts = if (forceAlternateStarter && lastMatchStarterWasPlayer != null) {
            !lastMatchStarterWasPlayer!!
        } else if (starterStreak >= 3 && lastMatchStarterWasPlayer != null) {
            !lastMatchStarterWasPlayer!!
        } else {
            Math.random() < 0.5
        }

        if (lastMatchStarterWasPlayer == playerStarts) {
            starterStreak++
        } else {
            starterStreak = 1
        }
        lastMatchStarterWasPlayer = playerStarts

        _state.update { 
            it.copy(
                isPlayerTurn = playerStarts,
                chaosPlayerIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.playerHand.isNotEmpty()) (0 until it.playerHand.size).random() else null,
                chaosOpponentIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.opponentHand.isNotEmpty()) (0 until it.opponentHand.size).random() else null,
            )
        }

        if (!playerStarts) {
            viewModelScope.launch {
                delay(2500)
                aiPlayTurn()
            }
        }
    }

    fun playerPlayCard(handIndex: Int, boardIndex: Int): Boolean {
        val st = _state.value
        if (st.gameState != HoneycombGameState.Playing || !st.isPlayerTurn) return false
        if (handIndex !in 0 until st.playerHand.size) return false
        if (st.board.cells[boardIndex].card != null) return false
        if (st.mandatedPlayerHandIndex != null && st.mandatedPlayerHandIndex != handIndex) return false

        val newPlayerHand = st.playerHand.toMutableList()
        val card = newPlayerHand.removeAt(handIndex)

        val newBoard = st.board.copy(cells = st.board.cells.map { it.copy(card = it.card?.copy()) })
        newBoard.placeCard(card, boardIndex, st.activeRules)

        _state.update {
            it.copy(
                playerHand = newPlayerHand,
                board = newBoard,
                isPlayerTurn = false,
                chaosPlayerIndex = null,
                chaosOpponentIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.opponentHand.isNotEmpty()) (0 until it.opponentHand.size).random() else null,
            )
        }

        checkWinCondition()

        if (_state.value.gameState == HoneycombGameState.Playing) {
            viewModelScope.launch {
                delay(2500)
                aiPlayTurn()
            }
        }
        return true
    }

    fun aiPlayTurn() {
        val st = _state.value
        if (st.gameState != HoneycombGameState.Playing || st.isPlayerTurn) return

        val gen = ++aiMoveGeneration
        val difficulty = _options.value.difficulty
        val board = st.board
        val opponentDeckData = st.opponentHand.map { it.data }
        val playerDeckData = st.playerHand.filter { st.openPlayerCardIds.contains(it.id) }.map { it.data }
        val unknownPlayerCardCount = st.playerHand.size - playerDeckData.size
        
        val eligibleHands = if (st.mandatedOpponentHandIndex != null) listOf(st.mandatedOpponentHandIndex) else st.opponentHand.indices.toList()
        val empties = board.cells.indices.filter { board.cells[it].card == null }
        val rules = st.activeRules

        viewModelScope.launch {
            // Hard/UltraHard use 5-6 ply minimax with alpha-beta search — run it off the
            // main thread so board-wide UI doesn't freeze while the AI "thinks", matching
            // Swift's DispatchQueue.global(qos: .userInitiated) offload.
            val move = withContext(Dispatchers.Default) {
                HoneycombAI.computeMove(
                    difficulty = difficulty,
                    board = board,
                    opponentDeck = opponentDeckData,
                    playerDeck = playerDeckData,
                    unknownPlayerCardCount = unknownPlayerCardCount,
                    eligibleHands = eligibleHands,
                    empties = empties,
                    rules = rules
                )
            }

            if (aiMoveGeneration != gen) return@launch

            if (move != null) {
                val newOpponentHand = _state.value.opponentHand.toMutableList()
                val cardToPlay = newOpponentHand.removeAt(move.first)
                
                val newBoard = _state.value.board.copy(cells = _state.value.board.cells.map { it.copy(card = it.card?.copy()) })
                newBoard.placeCard(cardToPlay, move.second, _state.value.activeRules)

                _state.update {
                    it.copy(
                        opponentHand = newOpponentHand,
                        board = newBoard,
                        isPlayerTurn = true,
                        chaosOpponentIndex = null,
                        chaosPlayerIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.playerHand.isNotEmpty()) (0 until it.playerHand.size).random() else null,
                    )
                }
                checkWinCondition()
            }
        }
    }
    
    private fun checkWinCondition() {
        val st = _state.value
        if (st.board.isFull) {
            settleMatch()
        }
    }

    private fun settleMatch() {
        val st = _state.value
        val pScore = st.board.playerScore + st.playerHand.size
        val oScore = st.board.opponentScore + st.opponentHand.size

        if (pScore > oScore) {
            _state.update {
                it.copy(
                    matchResult = "You Win!",
                    matchOutcome = HoneycombMatchOutcome.Win,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
        } else if (oScore > pScore) {
            _state.update {
                it.copy(
                    matchResult = "You Lose",
                    matchOutcome = HoneycombMatchOutcome.Loss,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
        } else if (st.activeRules.contains(HoneycombRule.SuddenDeath)) {
             _state.update {
                it.copy(
                    matchResult = "Sudden Death",
                    matchOutcome = HoneycombMatchOutcome.SuddenDeathPending,
                    gameState = HoneycombGameState.SuddenDeath,
                )
            }
        } else {
            _state.update {
                it.copy(
                    matchResult = "Draw",
                    matchOutcome = HoneycombMatchOutcome.Draw,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
        }
    }

    fun requestSteal(boardIndex: Int) {
        if (hasStolenThisMatch) return
        val card = _state.value.board.cells[boardIndex].card ?: return
        
        if (card.owner != CardOwner.Player || card.originalOwner != CardOwner.Opponent) return
        
        _state.update { 
            it.copy(pendingSteal = PendingSteal(boardIndex = boardIndex, cardName = card.data.name)) 
        }
    }

    fun confirmPendingSteal() {
        val pending = _state.value.pendingSteal ?: return
        
        val card = _state.value.board.cells[pending.boardIndex].card ?: return
        hasStolenThisMatch = true
        _state.update { it.copy(pendingSteal = null) }
    }

    fun startOver() {
        updateOptions(_options.value.copy(activeDeckIndex = 0))
    }
}
