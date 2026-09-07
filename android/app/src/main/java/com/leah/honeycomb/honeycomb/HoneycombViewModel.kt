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
    val chaosPlayerIndex: Int? = null,
    val chaosOpponentIndex: Int? = null,
    val showSuddenDeathBanner: Boolean = false
) {
    val mandatedPlayerHandIndex: Int?
        get() {
            if (activeRules.contains(HoneycombRule.Order) && playerHand.isNotEmpty()) return 0
            if (activeRules.contains(HoneycombRule.Chaos)) return chaosPlayerIndex
            return null
        }
    val mandatedOpponentHandIndex: Int?
        get() {
            if (activeRules.contains(HoneycombRule.Order) && opponentHand.isNotEmpty()) return 0
            if (activeRules.contains(HoneycombRule.Chaos)) return chaosOpponentIndex
            return null
        }
}

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
    val canRematch: Boolean get() = rematchOpponentDeck.isNotEmpty()
    private var rematchActiveRules: List<HoneycombRule> = emptyList()
    private var rematchAscensionDescensionSuits: Set<String> = emptySet()

    private var isRematchMatch: Boolean = false
    private var consecutiveNoStealWins: Int = 0
    var stealProtectionActive: Boolean = false
        private set
    private val _statistics = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "honeycomb_statistics", HoneycombStats.serializer(), HoneycombStats())
    )
    val statistics: StateFlow<HoneycombStats> = _statistics.asStateFlow()

    private fun updateStatistics(transform: (HoneycombStats) -> HoneycombStats) {
        val newStats = transform(_statistics.value)
        _statistics.value = newStats
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "honeycomb_statistics", HoneycombStats.serializer(), newStats)
        }
    }

    // Cumulative capture-flip count for the current match — mirrors Swift's
    // sessionCardsCaptured, incremented by each placeCard() call's flip count and reset
    // at the start of every new match/rematch.
    private var sessionCardsCaptured: Int = 0

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
        sessionCardsCaptured = 0

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
        sessionCardsCaptured = 0
        
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
        val pDeck = pDeckData.map { HoneycombCard(it, CardOwner.Player) }.toMutableList()
        
        val oDeck = _state.value.opponentHand.toMutableList()
        
        if (rematchActiveRules.contains(HoneycombRule.Swap) && pDeck.isNotEmpty() && oDeck.isNotEmpty()) {
            val pIdx = pDeck.indices.random()
            val oIdx = oDeck.indices.random()
            
            val pCard = pDeck[pIdx]
            val oCard = oDeck[oIdx]
            
            pDeck[pIdx] = HoneycombCard(oCard.data, CardOwner.Player, CardOwner.Opponent, oCard.id)
            oDeck[oIdx] = HoneycombCard(pCard.data, CardOwner.Opponent, CardOwner.Player, pCard.id)
        }
        
        var openOppIds = emptySet<String>()
        if (rematchActiveRules.contains(HoneycombRule.AllOpen)) {
            openOppIds = oDeck.map { it.id }.toSet()
        } else if (rematchActiveRules.contains(HoneycombRule.ThreeOpen)) {
            openOppIds = oDeck.shuffled().take(3).map { it.id }.toSet()
        }
        
        var openPlayerIds = emptySet<String>()
        if (rematchActiveRules.contains(HoneycombRule.AllOpen)) {
            openPlayerIds = pDeck.map { it.id }.toSet()
        } else if (rematchActiveRules.contains(HoneycombRule.ThreeOpen)) {
            openPlayerIds = pDeck.shuffled().take(3).map { it.id }.toSet()
        }
        
        _state.update { it.copy(
            playerHand = pDeck, 
            playerStartingDeck = pDeck, 
            openPlayerCardIds = openPlayerIds,
            opponentHand = oDeck,
            openOpponentCardIds = openOppIds
        ) }
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

    // Snapshotted right before a player move, popped on undo — reverts both the
    // player's move and the AI's subsequent response in one step, since undo is only
    // ever available again once it's the player's turn (matching Swift's
    // `canUndo: !undoStack.isEmpty && gameState == .playing && isPlayerTurn`).
    private val undoHistory = ArrayDeque<HoneycombState>()

    private fun snapshotForUndo() {
        val st = _state.value
        undoHistory.addLast(
            st.copy(
                board = st.board.copy(cells = st.board.cells.map { it.copy(card = it.card?.copy()) }),
                playerHand = st.playerHand.map { it.copy() },
                opponentHand = st.opponentHand.map { it.copy() }
            )
        )
    }

    val canUndo: Boolean
        get() = undoHistory.isNotEmpty() && _state.value.gameState == HoneycombGameState.Playing && _state.value.isPlayerTurn

    fun undoLastAction() {
        if (!canUndo) return
        aiMoveGeneration++ // invalidate any pending delayed AI-turn closure from the move being undone
        _state.value = undoHistory.removeLast()
    }

    val hasHintsAvailable: Boolean
        get() = _state.value.gameState == HoneycombGameState.Playing && _state.value.isPlayerTurn && _state.value.playerHand.isNotEmpty()

    private val _hintMove = MutableStateFlow<Pair<Int, Int>?>(null)
    val hintMove: StateFlow<Pair<Int, Int>?> = _hintMove.asStateFlow()

    // Suggests the player's best move by reusing the same minimax search the AI opponent
    // uses, framed with the player's own hand passed as the "deck to move" — the board
    // evaluation itself has no notion of which side is "the AI," so this is a legitimate
    // reuse rather than a hack specific to hinting.
    fun findHint() {
        if (!hasHintsAvailable) return
        val st = _state.value
        val eligibleHands = if (st.mandatedPlayerHandIndex != null) listOfNotNull(st.mandatedPlayerHandIndex) else st.playerHand.indices.toList()
        val empties = st.board.cells.indices.filter { st.board.cells[it].card == null }
        viewModelScope.launch {
            val move = withContext(Dispatchers.Default) {
                HoneycombAI.computeMove(
                    difficulty = HoneycombDifficulty.Hard,
                    board = st.board,
                    opponentDeck = st.playerHand.map { it.data },
                    playerDeck = st.opponentHand.map { it.data },
                    unknownPlayerCardCount = 0,
                    eligibleHands = eligibleHands,
                    empties = empties,
                    rules = st.activeRules
                )
            }
            _hintMove.value = move
        }
    }

    fun clearHint() {
        _hintMove.value = null
    }

    fun quitMatch() {
        aiMoveGeneration++
        undoHistory.clear()
        _hintMove.value = null
        _state.value = HoneycombState()
    }

    fun playerPlayCard(handIndex: Int, boardIndex: Int): Boolean {
        val st = _state.value
        if (st.gameState != HoneycombGameState.Playing || !st.isPlayerTurn) return false
        if (handIndex !in 0 until st.playerHand.size) return false
        if (st.board.cells[boardIndex].card != null) return false
        if (st.mandatedPlayerHandIndex != null && st.mandatedPlayerHandIndex != handIndex) return false

        snapshotForUndo()
        clearHint()

        val newPlayerHand = st.playerHand.toMutableList()
        val card = newPlayerHand.removeAt(handIndex)

        val isFirstCard = st.board.cells.all { it.card == null }
        if (st.activeRules.contains(HoneycombRule.BombShelter) && isFirstCard) {
            card.isFaceDown = true
            card.bombShelterTurnsRemaining = 3
        }

        val newBoard = st.board.copy(cells = st.board.cells.map { it.copy(card = it.card?.copy()) })
        sessionCardsCaptured += newBoard.placeCard(card, boardIndex, st.activeRules).size
        processBombShelter(newBoard, boardIndex, st.activeRules)

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
        
        val eligibleHands = if (st.mandatedOpponentHandIndex != null) listOfNotNull(st.mandatedOpponentHandIndex) else st.opponentHand.indices.toList()
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
                
                val isFirstCard = _state.value.board.cells.all { it.card == null }
                if (_state.value.activeRules.contains(HoneycombRule.BombShelter) && isFirstCard) {
                    cardToPlay.isFaceDown = true
                    cardToPlay.bombShelterTurnsRemaining = 3
                }

                val newBoard = _state.value.board.copy(cells = _state.value.board.cells.map { it.copy(card = it.card?.copy()) })
                sessionCardsCaptured += newBoard.placeCard(cardToPlay, move.second, _state.value.activeRules).size
                processBombShelter(newBoard, move.second, _state.value.activeRules)

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
            updateStatistics {
                it.recordGame(
                    won = true, drawn = false,
                    captures = sessionCardsCaptured,
                    sessionCombos = st.board.sessionSamePlusTriggers,
                    flawless = oScore == 0,
                    difficulty = _options.value.difficulty,
                    fallenAceCaptures = st.board.sessionFallenAceCaptures
                )
            }
            applyStealProtection()
        } else if (oScore > pScore) {
            _state.update {
                it.copy(
                    matchResult = "You Lose",
                    matchOutcome = HoneycombMatchOutcome.Loss,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
            updateStatistics {
                it.recordGame(
                    won = false, drawn = false,
                    captures = sessionCardsCaptured,
                    sessionCombos = st.board.sessionSamePlusTriggers,
                    flawless = false,
                    fallenAceCaptures = st.board.sessionFallenAceCaptures
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
            // Entering Sudden Death is not itself a decisive result — do not call
            // recordGame here; only the eventual win/loss/draw resolution records stats.
            // suddenDeathCount is incremented in triggerSuddenDeath() instead, once the
            // overtime round actually begins (matches Swift/C# reference timing) — not
            // here, since a quit/new-game during the delay below should not count it.
            val gen = aiMoveGeneration
            viewModelScope.launch {
                delay(2500)
                if (aiMoveGeneration != gen) return@launch
                _state.update { it.copy(showSuddenDeathBanner = true) }
                delay(1500)
                if (aiMoveGeneration != gen) return@launch
                _state.update { it.copy(showSuddenDeathBanner = false) }
                triggerSuddenDeath()
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
            updateStatistics {
                it.recordGame(
                    won = false, drawn = true,
                    captures = sessionCardsCaptured,
                    sessionCombos = st.board.sessionSamePlusTriggers,
                    flawless = false,
                    fallenAceCaptures = st.board.sessionFallenAceCaptures
                )
            }
        }
    }

    // Ported from Swift's triggerSuddenDeath()/C#'s TriggerSuddenDeathAsync() — a tied
    // match with the Sudden Death rule active continues into overtime rather than
    // ending in a draw. This is NOT rematch(): it keeps the same match (same
    // activeRules/ascensionDescensionSuits, no fresh opponent deck) and every card
    // either side currently owns — whether still in hand or captured on the board —
    // becomes that side's new hand for the next round. Can repeat indefinitely if the
    // overtime round ties again.
    private fun triggerSuddenDeath() {
        updateStatistics { it.copy(suddenDeathCount = it.suddenDeathCount + 1) }
        undoHistory.clear()

        val st = _state.value
        val playerCards = (st.board.cells.mapNotNull { it.card }.filter { it.owner == CardOwner.Player } + st.playerHand)
            .map { it.copy(modifier = 0) }
        val opponentCards = (st.board.cells.mapNotNull { it.card }.filter { it.owner == CardOwner.Opponent } + st.opponentHand)
            .map { it.copy(modifier = 0) }

        val newBoard = HoneycombBoard().apply { ascensionDescensionSuits = st.ascensionDescensionSuits }
        val nextPlayerTurn = !st.isPlayerTurn

        aiMoveGeneration++
        _state.update {
            it.copy(
                playerHand = playerCards,
                opponentHand = opponentCards,
                board = newBoard,
                gameState = HoneycombGameState.Playing,
                isPlayerTurn = nextPlayerTurn,
                matchOutcome = HoneycombMatchOutcome.None,
                matchResult = "",
                chaosPlayerIndex = null,
                chaosOpponentIndex = null
            )
        }

        if (!nextPlayerTurn) {
            viewModelScope.launch {
                delay(2500)
                aiPlayTurn()
            }
        }
    }

    fun isStealEligible(card: HoneycombCard): Boolean {
        if (profileManager.unlockedCardIds.value.contains(card.data.id)) return false
        if (stealProtectionActive) return true
        return card.originalOwner == CardOwner.Opponent && card.owner == CardOwner.Player
    }

    val hasStealableCard: Boolean
        get() = _state.value.board.cells.any { cell -> cell.card?.let { isStealEligible(it) } ?: false }

    val canStealCard: Boolean
        get() = _state.value.matchOutcome == HoneycombMatchOutcome.Win
            && !sharedOptions.noStressMode.value
            && !hasStolenThisMatch
            && !profileManager.isCardBankFull
            && hasStealableCard

    // Covers a rematch chain whose frozen opponent deck happens to include a card
    // that's realistically never capturable — without this, the player could keep
    // winning against that exact opponent forever with no legitimate shot at
    // unlocking it. Mirrors iOS's applyStealProtection(): only wins count as
    // evidence of being stuck, only within a rematch chain, and once tripped it
    // stays active until startNewGame() resets it.
    private fun applyStealProtection() {
        if (!isRematchMatch) return
        if (stealProtectionActive) return
        if (hasStealableCard) {
            consecutiveNoStealWins = 0
            return
        }
        consecutiveNoStealWins += 1
        if (consecutiveNoStealWins < 2) return
        consecutiveNoStealWins = 0
        stealProtectionActive = true
    }

    fun requestSteal(boardIndex: Int) {
        if (hasStolenThisMatch) return
        val card = _state.value.board.cells[boardIndex].card ?: return
        if (!isStealEligible(card)) return

        _state.update {
            it.copy(pendingSteal = PendingSteal(boardIndex = boardIndex, cardName = card.data.name))
        }
    }

    fun cancelPendingSteal() {
        _state.update { it.copy(pendingSteal = null) }
    }

    fun confirmPendingSteal() {
        val pending = _state.value.pendingSteal ?: return
        _state.update { it.copy(pendingSteal = null) }

        val card = _state.value.board.cells[pending.boardIndex].card ?: return
        if (!isStealEligible(card)) return
        hasStolenThisMatch = true

        viewModelScope.launch {
            profileManager.unlockCard(card.data.id)
        }

        updateStatistics { it.copy(cardsStolen = it.cardsStolen + 1) }
    }

    fun startOver() {
        updateOptions(_options.value.copy(activeDeckIndex = 0))
        updateStatistics { it.copy(timesStartedOver = it.timesStartedOver + 1) }
    }

    private fun processBombShelter(board: HoneycombBoard, justPlacedIndex: Int, rules: List<HoneycombRule>) {
        val pendingReveals = mutableListOf<Int>()
        for (i in board.cells.indices) {
            if (i == justPlacedIndex) continue
            val card = board.cells[i].card ?: continue
            if (!card.isFaceDown || card.bombShelterTurnsRemaining == null) continue
            
            val newRemaining = card.bombShelterTurnsRemaining!! - 1
            if (newRemaining <= 0) {
                pendingReveals.add(i)
            } else {
                card.bombShelterTurnsRemaining = newRemaining
            }
        }
        
        for (i in pendingReveals) {
            val card = board.cells[i].card ?: continue
            card.bombShelterTurnsRemaining = null
            val flips = board.revealFaceDownCard(i, rules)
            if (card.owner == CardOwner.Player) {
                sessionCardsCaptured += flips.size
            }
        }
    }
}