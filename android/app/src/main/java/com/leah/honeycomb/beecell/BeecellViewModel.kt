package com.leah.honeycomb.beecell

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.UUID
import kotlin.math.max

class BeecellViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(BeecellState())
    val state: StateFlow<BeecellState> = _state.asStateFlow()

    private fun loadOptions(): BeecellOptions =
        PreferencesHelper.getObjectSync(dataStore, "beecell_options", BeecellOptions.serializer(), BeecellOptions())

    private fun saveOptions(options: BeecellOptions) {
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "beecell_options", BeecellOptions.serializer(), options)
        }
    }

    private val _options = MutableStateFlow(loadOptions())
    val options: StateFlow<BeecellOptions> = _options.asStateFlow()

    private val _statistics = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "beecell_statistics", BeecellStatistics.serializer(), BeecellStatistics())
    )
    val statistics: StateFlow<BeecellStatistics> = _statistics.asStateFlow()

    private fun updateModeStats(freeCellCount: Int, transform: (BeecellModeStats) -> BeecellModeStats) {
        val stats = _statistics.value
        val newStatsMap = stats.statsByFreeCells.toMutableMap()
        val modeStats = newStatsMap[freeCellCount] ?: BeecellModeStats()
        newStatsMap[freeCellCount] = transform(modeStats)
        val newStats = stats.copy(statsByFreeCells = newStatsMap)
        _statistics.value = newStats
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "beecell_statistics", BeecellStatistics.serializer(), newStats)
        }
    }

    private val _isAutocompleteAvailable = MutableStateFlow(false)
    val isAutocompleteAvailable: StateFlow<Boolean> = _isAutocompleteAvailable.asStateFlow()

    private val _isAutoplayRunning = MutableStateFlow(false)
    val isAutoplayRunning: StateFlow<Boolean> = _isAutoplayRunning.asStateFlow()

    private val _isStuck = MutableStateFlow(false)
    val isStuck: StateFlow<Boolean> = _isStuck.asStateFlow()

    private val _pointPopup = MutableStateFlow<CardPointPopup?>(null)
    val pointPopup: StateFlow<CardPointPopup?> = _pointPopup.asStateFlow()

    private val undoStack = UndoStack<BeecellState>()
    private var initialState: BeecellState? = null

    private val gameTimer = GameTimer(viewModelScope)

    var gameGeneration = 0
        private set

    val canUndo: Boolean
        get() = undoStack.canUndo && !_state.value.hasWon

    private val _hintSourceId = MutableStateFlow<String?>(null)
    val hintSourceId: StateFlow<String?> = _hintSourceId.asStateFlow()
    private val _hintTargetId = MutableStateFlow<String?>(null)
    val hintTargetId: StateFlow<String?> = _hintTargetId.asStateFlow()

    fun findHint() {
        val st = _state.value
        val targets = st.foundations + st.freeCells + st.tableau
        val sources = st.freeCells + st.tableau
        for (source in sources) {
            val top = source.topCard ?: continue
            val target = targets.firstOrNull { it.id != source.id && isValidMove(listOf(top), it) }
            if (target != null) {
                _hintSourceId.value = source.id
                _hintTargetId.value = target.id
                return
            }
        }
        _hintSourceId.value = null
        _hintTargetId.value = null
    }

    fun clearHint() {
        _hintSourceId.value = null
        _hintTargetId.value = null
    }

    init {
        startNewGame()
    }
    
    fun updateOptions(newOptions: BeecellOptions) {
        val oldOptions = _options.value
        _options.value = newOptions
        saveOptions(newOptions)
        if (oldOptions.freeCellCount != newOptions.freeCellCount) {
            startNewGame(abandonedModeKey = oldOptions.freeCellCount)
        }
    }

    private fun saveStateForUndo() {
        if (_isAutoplayRunning.value) return
        undoStack.push(_state.value)
    }

    fun startTimerIfNeeded() {
        if (sharedOptions.noStressMode.value) return
        gameTimer.start(
            checkActive = { _state.value.isTimerActive },
            onSetActive = { active -> _state.update { it.copy(isTimerActive = active) } },
            tick = { _state.update { it.copy(timerSeconds = it.timerSeconds + 1) } }
        )
    }

    fun stopTimer() {
        gameTimer.stop(onSetActive = { active -> _state.update { it.copy(isTimerActive = active) } })
    }

    override fun onCleared() {
        super.onCleared()
        stopTimer()
    }

    fun startNewGame(abandonedModeKey: Int? = null) {
        stopTimer()

        val currentState = _state.value
        if (currentState.movesCount > 0 && !currentState.hasWon) {
            val abandonedCount = abandonedModeKey ?: _options.value.freeCellCount
            updateModeStats(abandonedCount) { it.copy(currentStreak = 0) }
        }

        updateModeStats(_options.value.freeCellCount) { it.copy(gamesPlayed = it.gamesPlayed + 1) }

        undoStack.clear()
        
        val deck = mutableListOf<Card>()
        for (suit in Suit.values()) {
            for (rank in 1..13) {
                deck.add(Card(suit = suit, rank = rank, faceUp = true))
            }
        }
        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")

        val tableau = mutableListOf<Pile>()
        for (i in 0 until 8) {
            tableau.add(Pile(id = "tableau_$i", type = PileType.Tableau, cards = emptyList()))
        }
        
        var cardIndex = 0
        while (cardIndex < deck.size) {
            val colIndex = cardIndex % 8
            val col = tableau[colIndex]
            val newCards = col.cards.toMutableList().apply { add(deck[cardIndex]) }
            tableau[colIndex] = col.copy(cards = newCards)
            cardIndex++
        }

        val freeCells = mutableListOf<Pile>()
        for (i in 0 until _options.value.freeCellCount) {
            freeCells.add(Pile(id = "freecell_$i", type = PileType.FreeCell, cards = emptyList()))
        }

        val foundations = mutableListOf<Pile>()
        for (i in 0 until 4) {
            foundations.add(Pile(id = "foundation_$i", type = PileType.Foundation, cards = emptyList()))
        }

        val newState = BeecellState(
            freeCells = freeCells,
            foundations = foundations,
            tableau = tableau,
            score = 0,
            movesCount = 0,
            timerSeconds = 0,
            isTimerActive = false,
            hasWon = false
        )
        
        _state.value = newState
        initialState = newState
        
        _isAutocompleteAvailable.value = false
        _isAutoplayRunning.value = false
        _isStuck.value = false
        gameGeneration += 1
    }

    fun restartCurrentGame() {
        val initial = initialState ?: return
        stopTimer()
        undoStack.clear()
        _state.value = initial
        _isAutocompleteAvailable.value = false
        _isAutoplayRunning.value = false
        _isStuck.value = false
        gameGeneration += 1
    }
    
    val emptyFreeCellsCount: Int
        get() = _state.value.freeCells.count { it.isEmpty }
        
    val emptyTableauColumnsCount: Int
        get() = _state.value.tableau.count { it.isEmpty }
        
    fun maxMoveLimit(toEmptyTableau: Boolean): Int {
        val e = emptyFreeCellsCount
        val c = emptyTableauColumnsCount
        return if (toEmptyTableau) {
            (e + 1) * (1 shl max(0, c - 1))
        } else {
            (e + 1) * (1 shl c)
        }
    }
    
    fun isValidDragSequence(cards: List<Card>): Boolean {
        if (cards.isEmpty()) return false
        if (cards.size == 1) return true
        for (i in 0 until cards.size - 1) {
            val upper = cards[i]
            val lower = cards[i + 1]
            if (upper.rank != lower.rank + 1 || upper.suit.isRed == lower.suit.isRed) {
                return false
            }
        }
        return true
    }
    
    fun isValidMove(cards: List<Card>, targetPile: Pile): Boolean {
        val firstCard = cards.firstOrNull() ?: return false
        if (!isValidDragSequence(cards)) return false
        
        when (targetPile.type) {
            PileType.FreeCell -> {
                return cards.size == 1 && targetPile.isEmpty
            }
            PileType.Foundation -> {
                if (cards.size != 1) return false
                if (targetPile.isEmpty) {
                    return firstCard.rank == 1
                } else {
                    val topCard = targetPile.topCard ?: return false
                    return firstCard.suit == topCard.suit && firstCard.rank == topCard.rank + 1
                }
            }
            PileType.Tableau -> {
                val isTargetEmpty = targetPile.isEmpty
                val limit = maxMoveLimit(toEmptyTableau = isTargetEmpty)
                if (cards.size > limit) return false
                
                if (isTargetEmpty) {
                    return true
                } else {
                    val topCard = targetPile.topCard ?: return false
                    return firstCard.rank == topCard.rank - 1 && firstCard.suit.isRed != topCard.suit.isRed
                }
            }
            else -> return false
        }
    }
    
    fun moveCards(cards: List<Card>, sourcePile: Pile, targetPile: Pile) {
        if (!isValidMove(cards, targetPile)) return

        saveStateForUndo()
        clearHint()
        startTimerIfNeeded()
        
        val cardIds = cards.map { it.id }.toSet()
        val currentState = _state.value
        val freeCells = currentState.freeCells.toMutableList()
        val foundations = currentState.foundations.toMutableList()
        val tableau = currentState.tableau.toMutableList()
        
        fun removeFrom(piles: MutableList<Pile>) {
            val idx = piles.indexOfFirst { it.id == sourcePile.id }
            if (idx != -1) {
                val newCards = piles[idx].cards.toMutableList()
                newCards.removeAll { it.id in cardIds }
                piles[idx] = piles[idx].copy(cards = newCards)
            }
        }
        
        fun addTo(piles: MutableList<Pile>) {
            val idx = piles.indexOfFirst { it.id == targetPile.id }
            if (idx != -1) {
                val newCards = piles[idx].cards.toMutableList()
                newCards.addAll(cards)
                piles[idx] = piles[idx].copy(cards = newCards)
            }
        }
        
        when (sourcePile.type) {
            PileType.FreeCell -> removeFrom(freeCells)
            PileType.Foundation -> removeFrom(foundations)
            PileType.Tableau -> removeFrom(tableau)
            else -> {}
        }
        
        when (targetPile.type) {
            PileType.FreeCell -> addTo(freeCells)
            PileType.Foundation -> addTo(foundations)
            PileType.Tableau -> addTo(tableau)
            else -> {}
        }
        
        val scoreDelta = when {
            targetPile.type == PileType.Foundation && sourcePile.type != PileType.Foundation -> 10
            sourcePile.type == PileType.Foundation && targetPile.type != PileType.Foundation -> -15
            else -> 0
        }

        _state.value = currentState.copy(
            freeCells = freeCells,
            foundations = foundations,
            tableau = tableau,
            score = maxOf(0, currentState.score + scoreDelta),
            movesCount = currentState.movesCount + 1
        )

        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }
    
    fun doubleClickMove(card: Card, sourcePile: Pile) {
        if (sourcePile.topCard?.id != card.id) return
        
        val foundations = _state.value.foundations
        for (f in foundations) {
            if (isValidMove(listOf(card), f)) {
                moveCards(listOf(card), sourcePile, f)
                return
            }
        }
        
        val freeCells = _state.value.freeCells
        for (cell in freeCells) {
            if (cell.isEmpty && isValidMove(listOf(card), cell)) {
                moveCards(listOf(card), sourcePile, cell)
                return
            }
        }
        
        val tableau = _state.value.tableau
        for (col in tableau) {
            if (isValidMove(listOf(card), col)) {
                moveCards(listOf(card), sourcePile, col)
                return
            }
        }
    }
    
    private fun checkWinState() {
        val totalFoundationCards = _state.value.foundations.sumOf { it.cards.size }
        if (WinDetection.hasWon(totalFoundationCards, 52, _state.value.hasWon)) {
            _state.update { it.copy(hasWon = true) }
            stopTimer()

            val timeInSeconds = _state.value.timerSeconds
            val finalScore = _state.value.score
            updateModeStats(_options.value.freeCellCount) { stats ->
                val newStreak = stats.currentStreak + 1
                var updated = stats.copy(
                    gamesWon = stats.gamesWon + 1,
                    currentStreak = newStreak,
                    longestStreak = maxOf(stats.longestStreak, newStreak),
                    highScore = maxOf(stats.highScore, finalScore)
                )
                if (timeInSeconds > 0) {
                    val newShortest = if (stats.shortestWinTime == 0) timeInSeconds else minOf(stats.shortestWinTime, timeInSeconds)
                    updated = updated.copy(
                        totalWinningTime = updated.totalWinningTime + timeInSeconds,
                        winningGamesCount = updated.winningGamesCount + 1,
                        shortestWinTime = newShortest
                    )
                }
                updated
            }
        }
    }
    
    private fun isProgressiveMove(cards: List<Card>, source: Pile, target: Pile): Boolean {
        if (source.type == PileType.Foundation) return false
        if (target.type == PileType.Foundation) return true
        if (source.type == PileType.FreeCell) return true
        if (target.type == PileType.FreeCell) return true
        if (source.type == PileType.Tableau) {
            val remaining = source.cards.size - cards.size
            if (remaining == 0) return !target.isEmpty
            return true
        }
        return false
    }
    
    private fun checkStuckState() {
        if (_state.value.hasWon) {
            _isStuck.value = false
            return
        }
        
        val allPiles = _state.value.freeCells + _state.value.foundations + _state.value.tableau
        var hasValid = false
        
        outer@ for (source in allPiles) {
            val topCard = source.topCard ?: continue
            for (target in allPiles) {
                if (target.id == source.id) continue
                if (isValidMove(listOf(topCard), target) && isProgressiveMove(listOf(topCard), source, target)) {
                    hasValid = true
                    break@outer
                }
            }
            
            if (source.type == PileType.Tableau) {
                var seqStart = source.cards.size - 1
                while (seqStart > 0) {
                    val upper = source.cards[seqStart - 1]
                    val lower = source.cards[seqStart]
                    if (upper.rank == lower.rank + 1 && upper.suit.isRed != lower.suit.isRed) {
                        seqStart--
                    } else break
                }
                for (idx in seqStart until source.cards.size) {
                    val seq = source.cards.subList(idx, source.cards.size)
                    for (target in _state.value.tableau) {
                        if (target.id == source.id) continue
                        if (isValidMove(seq, target) && isProgressiveMove(seq, source, target)) {
                            hasValid = true
                            break@outer
                        }
                    }
                }
            }
        }
        
        _isStuck.value = !hasValid
    }
    
    private fun checkAutocompleteState() {
        _isAutocompleteAvailable.value = !_state.value.hasWon && canAutocompleteToCompletion()
    }

    // A card ranked 1-2 is always safe to send to its foundation immediately. A higher
    // card is safe only once both opposite-color foundations have climbed to at least
    // (this card's rank - 2) — otherwise sending it up now could strand a lower
    // opposite-color card that still needs it as a landing spot in the tableau. Android
    // is 1-deck only (see plan §3), so each suit has exactly one foundation pile.
    private fun minFoundationRank(suit: Suit, foundations: List<Pile>): Int {
        return foundations.firstOrNull { it.topCard?.suit == suit }?.topCard?.rank ?: 0
    }

    private fun isSafeFoundationMove(card: Card, foundations: List<Pile>): Boolean {
        if (card.rank <= 2) return true
        val oppositeSuits = if (card.isRed) listOf(Suit.Spades, Suit.Clubs) else listOf(Suit.Hearts, Suit.Diamonds)
        for (suit in oppositeSuits) {
            if (minFoundationRank(suit, foundations) < card.rank - 2) return false
        }
        return true
    }

    private fun isValidFoundationMove(card: Card, foundation: Pile): Boolean {
        return if (foundation.isEmpty) {
            card.rank == 1
        } else {
            val top = foundation.topCard ?: return false
            card.suit == top.suit && card.rank == top.rank + 1
        }
    }

    // Simulates forward from `simState` using only safe foundation moves, to answer
    // "does the rest of this game play itself out automatically from here" without
    // mutating any real state. Ported from Swift's canAutocompleteToCompletion().
    private fun canAutocompleteToCompletion(): Boolean {
        var freeCells = _state.value.freeCells
        var tableau = _state.value.tableau
        var foundations = _state.value.foundations
        val expectedCards = 52

        if (foundations.sumOf { it.cards.size } == expectedCards) return false

        while (true) {
            if (foundations.sumOf { it.cards.size } == expectedCards) return true

            var moved = false
            for ((idx, cell) in freeCells.withIndex()) {
                val top = cell.topCard ?: continue
                val fIdx = foundations.indexOfFirst { isValidFoundationMove(top, it) && isSafeFoundationMove(top, foundations) }
                if (fIdx != -1) {
                    freeCells = freeCells.toMutableList().also { it[idx] = it[idx].copy(cards = it[idx].cards.dropLast(1)) }
                    foundations = foundations.toMutableList().also { it[fIdx] = it[fIdx].copy(cards = it[fIdx].cards + top) }
                    moved = true
                    break
                }
            }
            if (moved) continue

            for ((idx, col) in tableau.withIndex()) {
                val top = col.topCard ?: continue
                val fIdx = foundations.indexOfFirst { isValidFoundationMove(top, it) && isSafeFoundationMove(top, foundations) }
                if (fIdx != -1) {
                    tableau = tableau.toMutableList().also { it[idx] = it[idx].copy(cards = it[idx].cards.dropLast(1)) }
                    foundations = foundations.toMutableList().also { it[fIdx] = it[fIdx].copy(cards = it[fIdx].cards + top) }
                    moved = true
                    break
                }
            }
            if (!moved) return false
        }
    }

    // Real (non-simulated) version of the same search, used move-by-move while actually
    // executing the autoplay below.
    private fun findNextFoundationMove(): Triple<Card, Pile, Pile>? {
        for (cell in _state.value.freeCells) {
            val top = cell.topCard ?: continue
            for (foundation in _state.value.foundations) {
                if (isValidFoundationMove(top, foundation) && isSafeFoundationMove(top, _state.value.foundations)) {
                    return Triple(top, cell, foundation)
                }
            }
        }
        for (col in _state.value.tableau) {
            val top = col.topCard ?: continue
            for (foundation in _state.value.foundations) {
                if (isValidFoundationMove(top, foundation) && isSafeFoundationMove(top, _state.value.foundations)) {
                    return Triple(top, col, foundation)
                }
            }
        }
        return null
    }

    fun runAutocomplete() {
        if (!_isAutocompleteAvailable.value || _isAutoplayRunning.value) return
        saveStateForUndo()
        _isAutoplayRunning.value = true
        animateNextAutocompleteMove()
    }

    private fun animateNextAutocompleteMove() {
        if (!_isAutoplayRunning.value) return
        val nextMove = findNextFoundationMove()
        if (nextMove != null) {
            moveCards(listOf(nextMove.first), nextMove.second, nextMove.third)
            viewModelScope.launch {
                delay(150)
                animateNextAutocompleteMove()
            }
        } else {
            _isAutoplayRunning.value = false
            checkWinState()
        }
    }

    fun undoLastAction() {
        if (_state.value.hasWon) return
        if (!undoStack.canUndo) return
        
        val previous = undoStack.pop() ?: return
        val currentTimer = _state.value.timerSeconds
        val currentActive = _state.value.isTimerActive
        _state.value = previous.copy(
            timerSeconds = currentTimer,
            isTimerActive = currentActive
        )
        _isStuck.value = false
        checkStuckState()
    }
}
