package com.leah.honeycomb.spider

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

class SpiderViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(SpiderState())
    val state: StateFlow<SpiderState> = _state.asStateFlow()

    private fun loadOptions(): SpiderOptions =
        PreferencesHelper.getObjectSync(dataStore, "spider_options", SpiderOptions.serializer(), SpiderOptions())

    private fun saveOptions(options: SpiderOptions) {
        viewModelScope.launch {
            PreferencesHelper.setObject(dataStore, "spider_options", SpiderOptions.serializer(), options)
        }
    }

    private val _options = MutableStateFlow(loadOptions())
    val options: StateFlow<SpiderOptions> = _options.asStateFlow()

    private val _statistics = MutableStateFlow(SpiderStatistics())
    val statistics: StateFlow<SpiderStatistics> = _statistics.asStateFlow()

    private val _isAutocompleteAvailable = MutableStateFlow(false)
    val isAutocompleteAvailable: StateFlow<Boolean> = _isAutocompleteAvailable.asStateFlow()

    private val _isAutoplayRunning = MutableStateFlow(false)
    val isAutoplayRunning: StateFlow<Boolean> = _isAutoplayRunning.asStateFlow()

    private val _isStuck = MutableStateFlow(false)
    val isStuck: StateFlow<Boolean> = _isStuck.asStateFlow()

    private val _pointPopup = MutableStateFlow<CardPointPopup?>(null)
    val pointPopup: StateFlow<CardPointPopup?> = _pointPopup.asStateFlow()

    private val undoStack = UndoStack<SpiderState>()
    private var initialState: SpiderState? = null

    private val gameTimer = GameTimer(viewModelScope)

    var gameGeneration = 0
        private set

    val canUndo: Boolean
        get() = undoStack.canUndo && !_state.value.hasWon

    init {
        startNewGame()
    }
    
    fun updateOptions(newOptions: SpiderOptions) {
        val oldOptions = _options.value
        _options.value = newOptions
        saveOptions(newOptions)
        if (oldOptions.suitCount != newOptions.suitCount) {
            startNewGame(abandonedSuitCount = oldOptions.suitCount)
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

    fun startNewGame(abandonedSuitCount: Int? = null) {
        stopTimer()

        val currentState = _state.value
        if (currentState.movesCount > 0 && !currentState.hasWon) {
            val suitCount = abandonedSuitCount ?: _options.value.suitCount
            val stats = _statistics.value
            val newStatsMap = stats.statsBySuits.toMutableMap()
            val modeStats = newStatsMap[suitCount] ?: SpiderModeStats()
            newStatsMap[suitCount] = modeStats.copy(currentStreak = 0)
            _statistics.value = stats.copy(statsBySuits = newStatsMap)
        }

        undoStack.clear()

        val suitCount = _options.value.suitCount
        val suits = when (suitCount) {
            1 -> listOf(Suit.Spades)
            2 -> listOf(Suit.Spades, Suit.Hearts)
            else -> listOf(Suit.Spades, Suit.Hearts, Suit.Diamonds, Suit.Clubs)
        }
        
        val deck = mutableListOf<Card>()
        val setsPerSuit = 8 / suits.size
        for (suit in suits) {
            for (i in 0 until setsPerSuit) {
                for (rank in 1..13) {
                    deck.add(Card(suit = suit, rank = rank, faceUp = false))
                }
            }
        }
        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")

        var deckIndex = 0
        val tableau = mutableListOf<Pile>()
        for (i in 0 until 10) {
            val cardCount = if (i < 4) 6 else 5
            val cards = mutableListOf<Card>()
            for (j in 0 until cardCount) {
                var card = deck[deckIndex++]
                if (j == cardCount - 1) card = card.copy(faceUp = true)
                cards.add(card)
            }
            tableau.add(Pile(id = "tableau_$i", type = PileType.Tableau, cards = cards))
        }

        val stockCards = mutableListOf<Card>()
        while (deckIndex < deck.size) {
            stockCards.add(deck[deckIndex++])
        }
        val stock = Pile(id = "stock", type = PileType.Stock, cards = stockCards)

        val foundations = (0 until 8).map { i ->
            Pile(id = "foundation_$i", type = PileType.Foundation, cards = emptyList())
        }

        val newState = SpiderState(
            stock = stock,
            tableau = tableau,
            foundations = foundations,
            score = 500,
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

    val hasEmptyTableauColumn: Boolean
        get() = _state.value.tableau.any { it.isEmpty }

    fun drawFromStock() {
        val currentState = _state.value
        if (currentState.stock.isEmpty || hasEmptyTableauColumn) return

        saveStateForUndo()
        startTimerIfNeeded()

        val stockCards = currentState.stock.cards.toMutableList()
        val tableau = currentState.tableau.map { it.cards.toMutableList() }.toMutableList()

        for (i in 0 until 10) {
            if (stockCards.isNotEmpty()) {
                val card = stockCards.removeLast().copy(faceUp = true)
                tableau[i].add(card)
            }
        }

        val newTableauPiles = currentState.tableau.mapIndexed { index, pile ->
            pile.copy(cards = tableau[index])
        }

        _state.value = currentState.copy(
            stock = currentState.stock.copy(cards = stockCards),
            tableau = newTableauPiles,
            score = maxOf(0, currentState.score - 1),
            movesCount = currentState.movesCount + 1
        )

        checkCompletedRuns()
        checkStuckState()
    }

    fun isValidDragSequence(cards: List<Card>): Boolean {
        if (cards.isEmpty()) return false
        if (!cards.all { it.faceUp }) return false
        
        val suit = cards[0].suit
        for (i in 1 until cards.size) {
            if (cards[i].suit != suit || cards[i].rank != cards[i-1].rank - 1) {
                return false
            }
        }
        return true
    }

    fun isValidMove(cards: List<Card>, targetPile: Pile): Boolean {
        val firstCard = cards.firstOrNull() ?: return false
        if (targetPile.type != PileType.Tableau) return false
        
        if (targetPile.isEmpty) return true
        
        val topCard = targetPile.topCard ?: return false
        return firstCard.rank == topCard.rank - 1
    }

    fun moveCards(cards: List<Card>, sourcePile: Pile, targetPile: Pile) {
        if (!isValidMove(cards, targetPile)) return
        
        saveStateForUndo()
        startTimerIfNeeded()
        
        val cardIds = cards.map { it.id }.toSet()
        val currentState = _state.value
        val tableau = currentState.tableau.toMutableList()
        
        val srcIdx = tableau.indexOfFirst { it.id == sourcePile.id }
        if (srcIdx != -1) {
            val colCards = tableau[srcIdx].cards.toMutableList()
            colCards.removeAll { it.id in cardIds }
            if (colCards.isNotEmpty() && !colCards.last().faceUp) {
                colCards[colCards.size - 1] = colCards.last().copy(faceUp = true)
            }
            tableau[srcIdx] = tableau[srcIdx].copy(cards = colCards)
        }
        
        val tgtIdx = tableau.indexOfFirst { it.id == targetPile.id }
        if (tgtIdx != -1) {
            val colCards = tableau[tgtIdx].cards.toMutableList()
            colCards.addAll(cards)
            tableau[tgtIdx] = tableau[tgtIdx].copy(cards = colCards)
        }

        _state.value = currentState.copy(
            tableau = tableau,
            score = maxOf(0, currentState.score - 1),
            movesCount = currentState.movesCount + 1
        )

        checkCompletedRuns()
        checkStuckState()
    }

    fun doubleClickMove(card: Card, sourcePile: Pile) {
        val currentState = _state.value
        val tableau = currentState.tableau
        val colIdx = tableau.indexOfFirst { it.id == sourcePile.id }
        if (colIdx == -1) return
        
        val col = tableau[colIdx]
        val cardIdx = col.cards.indexOfFirst { it.id == card.id }
        if (cardIdx == -1) return
        
        val dragStack = col.cards.subList(cardIdx, col.cards.size)
        if (!isValidDragSequence(dragStack)) return
        
        var targetCol: Pile? = null
        
        // Match suit
        for (t in tableau) {
            if (t.id != sourcePile.id && !t.isEmpty) {
                val topCard = t.topCard
                if (topCard != null && topCard.rank == card.rank + 1 && topCard.suit == card.suit) {
                    targetCol = t
                    break
                }
            }
        }
        
        // Match rank
        if (targetCol == null) {
            for (t in tableau) {
                if (t.id != sourcePile.id && !t.isEmpty) {
                    val topCard = t.topCard
                    if (topCard != null && topCard.rank == card.rank + 1) {
                        targetCol = t
                        break
                    }
                }
            }
        }
        
        // Empty
        if (targetCol == null) {
            for (t in tableau) {
                if (t.id != sourcePile.id && t.isEmpty) {
                    targetCol = t
                    break
                }
            }
        }
        
        if (targetCol != null) {
            moveCards(dragStack, sourcePile, targetCol)
        }
    }

    private fun checkCompletedRuns() {
        var completedRunFound = false
        val currentState = _state.value
        val tableau = currentState.tableau.toMutableList()
        val foundations = currentState.foundations.toMutableList()
        var newScore = currentState.score

        for (i in 0 until 10) {
            val cards = tableau[i].cards
            if (cards.size < 13) continue
            
            val subrange = cards.takeLast(13)
            if (subrange[0].rank != 13) continue
            
            var isValidRun = true
            val suit = subrange[0].suit
            for (j in 0 until 13) {
                if (subrange[j].rank != 13 - j || subrange[j].suit != suit || !subrange[j].faceUp) {
                    isValidRun = false
                    break
                }
            }
            
            if (isValidRun) {
                val fdnIdx = foundations.indexOfFirst { it.isEmpty }
                if (fdnIdx == -1) continue
                
                completedRunFound = true
                val completedIds = subrange.map { it.id }.toSet()
                val colCards = tableau[i].cards.toMutableList()
                colCards.removeAll { it.id in completedIds }
                
                if (colCards.isNotEmpty() && !colCards.last().faceUp) {
                    colCards[colCards.size - 1] = colCards.last().copy(faceUp = true)
                }
                tableau[i] = tableau[i].copy(cards = colCards)
                
                val fdnCards = foundations[fdnIdx].cards.toMutableList()
                fdnCards.addAll(subrange)
                foundations[fdnIdx] = foundations[fdnIdx].copy(cards = fdnCards)
                
                newScore += 100
                break
            }
        }

        if (completedRunFound) {
            _state.value = currentState.copy(
                tableau = tableau,
                foundations = foundations,
                score = newScore
            )
            checkWinState()
            checkCompletedRuns()
        }
    }

    private fun checkWinState() {
        val totalFoundationCards = _state.value.foundations.sumOf { it.cards.size }
        if (WinDetection.hasWon(totalFoundationCards, 104, _state.value.hasWon)) {
            _state.update { it.copy(hasWon = true) }
            stopTimer()
            // In a real app we update statistics here
        }
    }

    private fun checkStuckState() {
        if (_state.value.hasWon) return
        var hasValidMove = false
        if (!_state.value.stock.isEmpty && !hasEmptyTableauColumn) {
            hasValidMove = true
        } else {
            val hasEmpty = hasEmptyTableauColumn
            outer@ for (colIdx in 0 until 10) {
                val col = _state.value.tableau[colIdx]
                if (col.isEmpty) continue
                
                var seqStart = col.cards.size - 1
                while (seqStart > 0) {
                    val upper = col.cards[seqStart - 1]
                    val lower = col.cards[seqStart]
                    if (upper.faceUp && upper.rank == lower.rank + 1 && upper.suit == lower.suit) {
                        seqStart--
                    } else break
                }
                
                for (start in seqStart until col.cards.size) {
                    val seq = col.cards.subList(start, col.cards.size)
                    if (hasEmpty && seq.first().faceUp) {
                        hasValidMove = true
                        break@outer
                    }
                    for (tgtIdx in 0 until 10) {
                        if (tgtIdx == colIdx) continue
                        val target = _state.value.tableau[tgtIdx]
                        if (isValidMove(seq, target)) {
                            hasValidMove = true
                            break@outer
                        }
                    }
                }
            }
        }
        _isStuck.value = !hasValidMove
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
        checkWinState()
        checkStuckState()
    }
}
