package com.leah.honeycomb.klondike

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.Card
import com.leah.honeycomb.Suit





import com.leah.honeycomb.CardPointPopup





import com.leah.honeycomb.GameTimer
import com.leah.honeycomb.Pile
import com.leah.honeycomb.PileType
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.UndoStack
import com.leah.honeycomb.WinDetection
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.UUID

class GameViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(GameState())
    val state: StateFlow<GameState> = _state.asStateFlow()

    fun updateOptions(newOptions: GameOptions) {
        val oldOptions = _options.value
        _options.value = newOptions
        saveOptions(newOptions)
        // Only Vegas Scoring toggling actually invalidates the current deal (it changes
        // what the score even means) — unrelated settings like Draw Mode or Timed Match
        // must not discard an in-progress game. Matches Swift's handleOptionsChanged.
        if (newOptions.isVegasScoring != oldOptions.isVegasScoring) {
            if (newOptions.isVegasScoring) {
                _highScore.value = com.leah.honeycomb.PreferencesHelper.getObjectSync(
                    dataStore, "high_score_vegas", kotlinx.serialization.serializer(), -5200
                )
            } else {
                _highScore.value = com.leah.honeycomb.PreferencesHelper.getObjectSync(
                    dataStore, "high_score", kotlinx.serialization.serializer(), 0
                )
            }
            _vegasBankroll.value = 0
            startNewGame(countAsNewGame = false)
        }
    }

    private fun loadOptions(): GameOptions =
        com.leah.honeycomb.PreferencesHelper.getObjectSync(dataStore, "solitaire_options", GameOptions.serializer(), GameOptions())

    private fun saveOptions(options: GameOptions) {
        viewModelScope.launch {
            com.leah.honeycomb.PreferencesHelper.setObject(dataStore, "solitaire_options", GameOptions.serializer(), options)
        }
    }

    private val _options = MutableStateFlow(loadOptions())
    val options: StateFlow<GameOptions> = _options.asStateFlow()

    private val _statistics = MutableStateFlow(
        com.leah.honeycomb.PreferencesHelper.getObjectSync(dataStore, "klondike_statistics", GameStatistics.serializer(), GameStatistics())
    )
    val statistics: StateFlow<GameStatistics> = _statistics.asStateFlow()

    private fun updateStatistics(transform: (GameStatistics) -> GameStatistics) {
        val newStats = transform(_statistics.value)
        _statistics.value = newStats
        viewModelScope.launch {
            com.leah.honeycomb.PreferencesHelper.setObject(dataStore, "klondike_statistics", GameStatistics.serializer(), newStats)
        }
    }

    // Vegas and non-Vegas high scores are tracked separately (Vegas floors at -5200,
    // the buy-in for a fresh deal, rather than 0) — matches Swift's init.
    private val _highScore = MutableStateFlow(
        if (_options.value.isVegasScoring) {
            com.leah.honeycomb.PreferencesHelper.getObjectSync(dataStore, "high_score_vegas", kotlinx.serialization.serializer(), -5200)
        } else {
            com.leah.honeycomb.PreferencesHelper.getObjectSync(dataStore, "high_score", kotlinx.serialization.serializer(), 0)
        }
    )
    val highScore: StateFlow<Int> = _highScore.asStateFlow()

    private fun saveHighScore(value: Int) {
        val key = if (_options.value.isVegasScoring) "high_score_vegas" else "high_score"
        viewModelScope.launch {
            com.leah.honeycomb.PreferencesHelper.setObject(dataStore, key, kotlinx.serialization.serializer(), value)
        }
    }

    private val _vegasBankroll = MutableStateFlow(0)
    val vegasBankroll: StateFlow<Int> = _vegasBankroll.asStateFlow()

    private var vegasBankrollAtGameStart = 0

    private val _isAutocompleteAvailable = MutableStateFlow(false)
    val isAutocompleteAvailable: StateFlow<Boolean> = _isAutocompleteAvailable.asStateFlow()

    private val _isAutoplayRunning = MutableStateFlow(false)
    val isAutoplayRunning: StateFlow<Boolean> = _isAutoplayRunning.asStateFlow()

    private val _isStuck = MutableStateFlow(false)
    val isStuck: StateFlow<Boolean> = _isStuck.asStateFlow()

    private val _isStockExhausted = MutableStateFlow(false)
    val isStockExhausted: StateFlow<Boolean> = _isStockExhausted.asStateFlow()

    private val _pointPopup = MutableStateFlow<CardPointPopup?>(null)
    val pointPopup: StateFlow<CardPointPopup?> = _pointPopup.asStateFlow()
    private var pointPopupGeneration: Int = 0

    private val undoStack = UndoStack<GameState>()
    private var initialState: GameState? = null

    private val gameTimer = GameTimer(viewModelScope)
    
    private var recycleCountAtStuck: Int? = null
    var hasDrawnFromStockThisGame = false
    var hasShownIdleStockHintThisGame = false
    var gameGeneration = 0
        private set

    val canUndo: Boolean
        get() = undoStack.canUndo && !_state.value.hasWon

    // Highlights one legal move (source + target pile id) rather than porting Swift's
    // full ranked/cycling HintCycling system — a real, useful hint, just not a ranked
    // sequence of alternatives on repeated taps.
    private val _hintSourceId = MutableStateFlow<String?>(null)
    val hintSourceId: StateFlow<String?> = _hintSourceId.asStateFlow()
    private val _hintTargetId = MutableStateFlow<String?>(null)
    val hintTargetId: StateFlow<String?> = _hintTargetId.asStateFlow()

    fun findHint() {
        val st = _state.value
        val targets = st.foundations + st.tableau
        val topWaste = st.waste.topCard
        if (topWaste != null) {
            val target = targets.firstOrNull { isValidMove(listOf(topWaste), it) }
            if (target != null) {
                _hintSourceId.value = st.waste.id
                _hintTargetId.value = target.id
                return
            }
        }
        for (col in st.tableau) {
            val top = col.topCard ?: continue
            if (!top.faceUp) continue
            val target = targets.firstOrNull { it.id != col.id && isValidMove(listOf(top), it) }
            if (target != null) {
                _hintSourceId.value = col.id
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

    val maxRecycles: Int?
        get() = if (_options.value.isVegasScoring) {
            if (_state.value.drawMode == DrawMode.DrawThree) 2 else 0
        } else null

    val canRecycleStock: Boolean
        get() {
            if (_state.value.waste.isEmpty) return false
            val maxRec = maxRecycles
            return if (maxRec != null) _state.value.recyclesCount < maxRec else true
        }

    init {
        // Assume loaded from DataStore via AppContainer or similar...
        // For now start immediately
        startNewGame()
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

    fun startNewGame(countAsNewGame: Boolean = true) {
        stopTimer()

        val currentState = _state.value
        if (currentState.movesCount > 0 && !currentState.hasWon) {
            updateStatistics { it.copy(currentStreak = 0) }
        }

        if (countAsNewGame) {
            updateStatistics { it.copy(gamesPlayed = it.gamesPlayed + 1) }
        } else {
            if (_options.value.isVegasScoring && currentState.movesCount > 0) {
                _vegasBankroll.update { it - -5200 }
            }
        }

        undoStack.clear()

        val deck = mutableListOf<Card>()
        for (suit in Suit.entries) {
            for (rank in 1..13) {
                deck.add(Card(id = UUID.randomUUID(), suit = suit, rank = rank, faceUp = false))
            }
        }
        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")

        val tableau = mutableListOf<Pile>()
        var deckIndex = 0
        for (i in 0 until 7) {
            val cards = mutableListOf<Card>()
            for (j in 0..i) {
                var card = deck[deckIndex++]
                if (j == i) card = card.copy(faceUp = true)
                cards.add(card)
            }
            tableau.add(Pile(id = "tableau_$i", type = PileType.Tableau, cards = cards))
        }

        val stockCards = mutableListOf<Card>()
        while (deckIndex < deck.size) {
            stockCards.add(deck[deckIndex++])
        }
        val stock = Pile(id = "stock", type = PileType.Stock, cards = stockCards)
        val waste = Pile(id = "waste", type = PileType.Waste, cards = emptyList())
        val foundations = listOf(
            Pile(id = "foundation_Spades", type = PileType.Foundation, cards = emptyList()),
            Pile(id = "foundation_Clubs", type = PileType.Foundation, cards = emptyList()),
            Pile(id = "foundation_Diamonds", type = PileType.Foundation, cards = emptyList()),
            Pile(id = "foundation_Hearts", type = PileType.Foundation, cards = emptyList())
        )

        val initialScore = if (_options.value.isVegasScoring) -5200 else 0
        if (_options.value.isVegasScoring) {
            _vegasBankroll.update { it + initialScore }
            vegasBankrollAtGameStart = _vegasBankroll.value
        }

        val newState = GameState(
            stock = stock,
            waste = waste,
            foundations = foundations,
            tableau = tableau,
            score = initialScore,
            movesCount = 0,
            timerSeconds = 0,
            isTimerActive = false,
            drawMode = _options.value.drawMode,
            hasWon = false,
            recyclesCount = 0
        )
        
        _state.value = newState
        initialState = newState
        
        _isAutocompleteAvailable.value = false
        _isAutoplayRunning.value = false
        _isStuck.value = false
        _isStockExhausted.value = false
        recycleCountAtStuck = null
        hasDrawnFromStockThisGame = false
        hasShownIdleStockHintThisGame = false
        gameGeneration += 1
    }

    fun restartCurrentGame() {
        val initial = initialState ?: return
        stopTimer()
        undoStack.clear()
        if (_options.value.isVegasScoring) {
            _vegasBankroll.value = vegasBankrollAtGameStart
        }
        _state.value = initial
        _isAutocompleteAvailable.value = false
        _isAutoplayRunning.value = false
        _isStuck.value = false
        _isStockExhausted.value = false
        recycleCountAtStuck = null
        hasDrawnFromStockThisGame = false
        hasShownIdleStockHintThisGame = false
        gameGeneration += 1
    }

    fun drawCard() {
        if (_state.value.stock.isEmpty) {
            if (!canRecycleStock) return
            recycleStock()
            return
        }

        saveStateForUndo()
        hasDrawnFromStockThisGame = true
        startTimerIfNeeded()

        val currentState = _state.value
        val count = if (currentState.drawMode == DrawMode.DrawOne) 1 else minOf(3, currentState.stock.cards.size)
        val drawn = mutableListOf<Card>()

        val stockCards = currentState.stock.cards.toMutableList()
        for (i in 0 until count) {
            if (stockCards.isNotEmpty()) {
                val card = stockCards.removeLast().copy(faceUp = true)
                drawn.add(card)
            }
        }

        val wasteCards = currentState.waste.cards.toMutableList()
        wasteCards.addAll(drawn)

        _state.value = currentState.copy(
            stock = currentState.stock.copy(cards = stockCards),
            waste = currentState.waste.copy(cards = wasteCards),
            wasteDisplayCount = drawn.size,
            movesCount = currentState.movesCount + 1
        )

        checkAutocompleteState()
        checkStuckState()
    }

    fun recycleStock() {
        val currentState = _state.value
        if (!currentState.stock.isEmpty || currentState.waste.isEmpty) return
        if (!canRecycleStock) return

        saveStateForUndo()

        val recycled = currentState.waste.cards.map { it.copy(faceUp = false) }.reversed()
        _state.value = currentState.copy(
            stock = currentState.stock.copy(cards = recycled),
            waste = currentState.waste.copy(cards = emptyList()),
            wasteDisplayCount = 0,
            movesCount = currentState.movesCount + 1,
            recyclesCount = currentState.recyclesCount + 1
        )
        hasDrawnFromStockThisGame = true
        checkStuckState()
    }

    fun isValidMove(cards: List<Card>, targetPile: Pile): Boolean {
        val firstCard = cards.firstOrNull() ?: return false

        if (cards.size > 1) {
            for (i in 0 until cards.size - 1) {
                if (cards[i].rank != cards[i+1].rank + 1 || cards[i].isRed == cards[i+1].isRed) {
                    return false
                }
            }
        }

        return when (targetPile.type) {
            PileType.Tableau -> {
                if (targetPile.isEmpty) {
                    firstCard.rank == 13
                } else {
                    val topCard = targetPile.topCard ?: return false
                    firstCard.rank == topCard.rank - 1 && firstCard.isRed != topCard.isRed
                }
            }
            PileType.Foundation -> {

                if (cards.size != 1) return false
                if (targetPile.isEmpty) {
                    firstCard.rank == 1
                } else {
                    val topCard = targetPile.topCard ?: return false
                    firstCard.suit == topCard.suit && firstCard.rank == topCard.rank + 1
                }
            }
            else -> false
        }
    }

    fun moveCards(cards: List<Card>, sourcePile: Pile, targetPile: Pile) {
        if (!isValidMove(cards, targetPile)) return
        saveStateForUndo()
        clearHint()
        startTimerIfNeeded()

        val cardIds = cards.map { it.id }.toSet()
        var revealedFaceDownCard = false
        var revealedCardId: UUID? = null

        val currentState = _state.value
        val stockCards = currentState.stock.cards.toMutableList()
        val wasteCards = currentState.waste.cards.toMutableList()
        val tableau = currentState.tableau.toMutableList()
        val foundations = currentState.foundations.toMutableList()
        var newWasteDisplayCount = currentState.wasteDisplayCount

        when (sourcePile.type) {
            PileType.Stock -> stockCards.removeAll { it.id in cardIds }
            PileType.Waste -> {
                wasteCards.removeAll { it.id in cardIds }
                newWasteDisplayCount = maxOf(0, newWasteDisplayCount - cardIds.size)
                if (newWasteDisplayCount == 0 && wasteCards.isNotEmpty()) {
                    newWasteDisplayCount = if (currentState.drawMode == DrawMode.DrawOne) 1 else minOf(3, wasteCards.size)
                }
            }
            PileType.Tableau -> {
                val idx = tableau.indexOfFirst { it.id == sourcePile.id }
                if (idx != -1) {
                    val colCards = tableau[idx].cards.toMutableList()
                    colCards.removeAll { it.id in cardIds }
                    if (colCards.isNotEmpty() && !colCards.last().faceUp) {
                        colCards[colCards.size - 1] = colCards.last().copy(faceUp = true)
                        revealedFaceDownCard = true
                        revealedCardId = colCards.last().id
                    }
                    tableau[idx] = tableau[idx].copy(cards = colCards)
                }
            }
            PileType.Foundation -> {

                val idx = foundations.indexOfFirst { it.id == sourcePile.id }
                if (idx != -1) {
                    val fCards = foundations[idx].cards.toMutableList()
                    fCards.removeAll { it.id in cardIds }
                    foundations[idx] = foundations[idx].copy(cards = fCards)
                }
            }
            else -> {}
        }

        when (targetPile.type) {
            PileType.Tableau -> {
                val idx = tableau.indexOfFirst { it.id == targetPile.id }
                if (idx != -1) {
                    val colCards = tableau[idx].cards.toMutableList()
                    colCards.addAll(cards)
                    tableau[idx] = tableau[idx].copy(cards = colCards)
                }
            }
            PileType.Foundation -> {

                val idx = foundations.indexOfFirst { it.id == targetPile.id }
                if (idx != -1) {
                    val fCards = foundations[idx].cards.toMutableList()
                    fCards.addAll(cards)
                    foundations[idx] = foundations[idx].copy(cards = fCards)
                }
            }
            else -> {}
        }

        _state.value = currentState.copy(
            stock = currentState.stock.copy(cards = stockCards),
            waste = currentState.waste.copy(cards = wasteCards),
            wasteDisplayCount = newWasteDisplayCount,
            tableau = tableau,
            foundations = foundations,
            movesCount = currentState.movesCount + 1
        )

        adjustScore(sourcePile.type, targetPile.type, revealedFaceDownCard)
        updatePointPopup(cards.lastOrNull(), sourcePile.type, targetPile.type, revealedFaceDownCard, revealedCardId)
        
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }

    fun doubleClickMoveToFoundation(card: Card, sourcePile: Pile) {
        if (sourcePile.topCard?.id != card.id) return
        for (foundation in _state.value.foundations) {
            if (isValidMove(listOf(card), foundation)) {
                moveCards(listOf(card), sourcePile, foundation)
                break
            }
        }
    }

    private fun adjustScore(source: PileType, target: PileType, revealedFaceDownCard: Boolean) {
        var scoreDelta = 0
        var vegasDelta = 0

        if (_options.value.isVegasScoring) {
            if (target == PileType.Foundation && source != PileType.Foundation) {
                scoreDelta = 500; vegasDelta = 500
            } else if (source == PileType.Foundation && target == PileType.Tableau) {
                scoreDelta = -500; vegasDelta = -500
            }
        } else {
            if (target == PileType.Foundation && source != PileType.Foundation) {
                scoreDelta = 10
            } else if ((source == PileType.Stock || source == PileType.Waste) && target == PileType.Tableau) {
                scoreDelta = 5
            } else if (source == PileType.Foundation && target == PileType.Tableau) {
                scoreDelta = -15
            }
            if (revealedFaceDownCard) {
                scoreDelta += 5
            }
        }

        if (scoreDelta != 0) {
            _state.update { it.copy(score = it.score + scoreDelta) }
        }
        if (vegasDelta != 0) {
            _vegasBankroll.update { it + vegasDelta }
        }
    }

    private fun updatePointPopup(anchorCard: Card?, source: PileType, target: PileType, revealedFaceDownCard: Boolean, revealedCardId: UUID?) {
        if (!sharedOptions.honeyMode.value || _isAutoplayRunning.value) return
        val popup: CardPointPopup? = if (_options.value.isVegasScoring) {
            if (target == PileType.Foundation && source != PileType.Foundation && anchorCard != null) {
                CardPointPopup(anchorCard.id, "+$5", true)
            } else if (source == PileType.Foundation && target == PileType.Tableau && anchorCard != null) {
                CardPointPopup(anchorCard.id, "-$5", false)
            } else null
        } else {
            if (target == PileType.Foundation && source != PileType.Foundation && anchorCard != null) {
                CardPointPopup(anchorCard.id, "+10", true)
            } else if ((source == PileType.Stock || source == PileType.Waste) && target == PileType.Tableau && anchorCard != null) {
                CardPointPopup(anchorCard.id, "+5", true)
            } else if (source == PileType.Foundation && target == PileType.Tableau && anchorCard != null) {
                CardPointPopup(anchorCard.id, "-15", false)
            } else if (revealedFaceDownCard && revealedCardId != null) {
                CardPointPopup(revealedCardId, "+5", true)
            } else null
        }

        if (popup != null) {
            pointPopupGeneration += 1
            val generation = pointPopupGeneration
            _pointPopup.value = popup
            viewModelScope.launch {
                delay(1000)
                if (pointPopupGeneration == generation) {
                    _pointPopup.value = null
                }
            }
        }
    }

    fun checkWinState() {
        val totalFoundationCards = _state.value.foundations.sumOf { it.cards.size }
        if (WinDetection.hasWon(totalFoundationCards, 52, _state.value.hasWon)) {
            _state.update { it.copy(hasWon = true) }
            stopTimer()
            
            val timeInSeconds = _state.value.timerSeconds
            if (!_options.value.isVegasScoring && timeInSeconds > 0) {
                val scorePenalty = 2 * (timeInSeconds / 10)
                var newScore = maxOf(0, _state.value.score - scorePenalty)
                newScore += 700000 / timeInSeconds
                _state.update { it.copy(score = newScore) }
            }
            if (_state.value.score > _highScore.value) {
                _highScore.value = _state.value.score
                saveHighScore(_highScore.value)
            }

            // Gate the time fields on timeInSeconds > 0 so a No-Stress zero-time win
            // doesn't skew averageWinningTime/shortestWinTime — matches iOS.
            updateStatistics { stats ->
                val newStreak = stats.currentStreak + 1
                var updated = stats.copy(
                    gamesWon = stats.gamesWon + 1,
                    currentStreak = newStreak,
                    longestStreak = maxOf(stats.longestStreak, newStreak)
                )
                if (timeInSeconds > 0) {
                    val newShortest = if (stats.winningGamesCount == 0) timeInSeconds else minOf(stats.shortestWinTime, timeInSeconds)
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

    fun checkAutocompleteState() {
        val stockEmpty = _state.value.stock.isEmpty
        val wasteEmpty = _state.value.waste.isEmpty
        val allTableauFaceUp = _state.value.tableau.all { pile -> pile.cards.all { it.faceUp } }
        val allCardsCount = _state.value.tableau.sumOf { it.cards.size } + _state.value.foundations.sumOf { it.cards.size }
        _isAutocompleteAvailable.value = stockEmpty && wasteEmpty && allTableauFaceUp && allCardsCount == 52 && !_state.value.hasWon
    }

    fun checkStuckState() {
        if (_state.value.hasWon || _isAutocompleteAvailable.value) {
            _isStuck.value = false
            _isStockExhausted.value = false
            recycleCountAtStuck = null
            return
        }

        _isStockExhausted.value = _state.value.stock.isEmpty && !canRecycleStock

        val hasMoves = hasValidMoves()
        if (hasMoves) {
            _isStuck.value = false
            recycleCountAtStuck = null
        } else {
            if (_isStockExhausted.value) {
                _isStuck.value = true
            } else if (_options.value.isVegasScoring) {
                _isStuck.value = false
            } else {
                if (recycleCountAtStuck == null) recycleCountAtStuck = _state.value.recyclesCount
                if (_state.value.recyclesCount > (recycleCountAtStuck ?: 0)) {
                    _isStuck.value = true
                } else {
                    _isStuck.value = false
                }
            }
        }
    }

    fun undoLastAction() {
        val previous = undoStack.pop() ?: return
        val currentTimerSeconds = _state.value.timerSeconds
        val currentIsTimerActive = _state.value.isTimerActive
        val scoreBeforeUndo = _state.value.score

        var restoredState = previous.copy(
            timerSeconds = currentTimerSeconds,
            isTimerActive = currentIsTimerActive
        )

        if (!_options.value.isVegasScoring) {
            val pointsEarned = scoreBeforeUndo - restoredState.score
            restoredState = restoredState.copy(score = restoredState.score - maxOf(0, pointsEarned))
        }

        if (_options.value.isVegasScoring) {
            val initial = initialState
            if (initial != null) {
                _vegasBankroll.value = vegasBankrollAtGameStart + (restoredState.score - initial.score)
            }
        }

        _state.value = restoredState
        _isAutoplayRunning.value = false
        _isStuck.value = false
        _pointPopup.value = null
        
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }
    
    // Autocomplete Logic
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

    private fun findNextFoundationMove(): Triple<Card, Pile, Pile>? {
        val topWaste = _state.value.waste.topCard
        if (topWaste != null) {
            for (f in _state.value.foundations) {
                if (isValidMove(listOf(topWaste), f)) return Triple(topWaste, _state.value.waste, f)
            }
        }
        for (col in _state.value.tableau) {
            val topTab = col.topCard
            if (topTab != null) {
                for (f in _state.value.foundations) {
                    if (isValidMove(listOf(topTab), f)) return Triple(topTab, col, f)
                }
            }
        }
        return null
    }

    // Advanced Stuck Detection logic
    private fun simulateDrawThrough(stock: List<Card>, waste: List<Card>): Pair<List<Card>, List<Card>> {
        val batchSize = if (_state.value.drawMode == DrawMode.DrawOne) 1 else 3
        val simStock = stock.toMutableList()
        val simWaste = waste.toMutableList()
        val reachable = mutableListOf<Card>()

        while (simStock.isNotEmpty()) {
            val take = minOf(batchSize, simStock.size)
            val drawn = mutableListOf<Card>()
            for (i in 0 until take) {
                if (simStock.isNotEmpty()) drawn.add(simStock.removeLast())
            }
            simWaste.addAll(drawn)
            simWaste.lastOrNull()?.let { reachable.add(it) }
        }
        return Pair(simWaste, reachable)
    }

    private fun hasPlayableStockCard(): Boolean {
        val targets = _state.value.foundations + _state.value.tableau
        val (_, reachable) = simulateDrawThrough(_state.value.stock.cards, _state.value.waste.cards)
        return reachable.any { card -> targets.any { isValidMove(listOf(card), it) } }
    }

    private fun hasPlayableWasteCard(): Boolean {
        if (!canRecycleStock) return false
        val targets = _state.value.foundations + _state.value.tableau
        val (finalWaste, _) = simulateDrawThrough(_state.value.stock.cards, _state.value.waste.cards)
        val (_, reachable) = simulateDrawThrough(finalWaste.reversed(), emptyList())
        return reachable.any { card -> targets.any { isValidMove(listOf(card), it) } }
    }

    private fun isProgressiveMove(cards: List<Card>, source: Pile, target: Pile): Boolean {
        if (target.type == PileType.Foundation) return true
        if (source.type == PileType.Waste) return true
        if (source.type == PileType.Tableau) {
            val col = _state.value.tableau.find { it.id == source.id } ?: return false
            val remainingCount = col.cards.size - cards.size
            if (remainingCount == 0) return !target.isEmpty
            val exposedCard = col.cards[remainingCount - 1]
            if (!exposedCard.faceUp) return true
            if (_state.value.foundations.any { isValidMove(listOf(exposedCard), it) }) return true
        }
        return false
    }

    private fun hasValidMoves(): Boolean {
        val allSources = mutableListOf<Pile>()
        if (_state.value.waste.topCard != null) allSources.add(_state.value.waste)
        allSources.addAll(_state.value.tableau)
        val targets = _state.value.foundations + _state.value.tableau

        for (source in allSources) {
            val topCard = source.topCard ?: continue
            for (target in targets) {
                if (target.id != source.id && isValidMove(listOf(topCard), target) && isProgressiveMove(listOf(topCard), source, target)) {
                    return true
                }
            }
            if (source.type == PileType.Tableau) {
                val col = _state.value.tableau.find { it.id == source.id } ?: continue
                for (startIdx in col.cards.indices) {
                    if (col.cards[startIdx].faceUp) {
                        val seq = col.cards.subList(startIdx, col.cards.size)
                        for (target in _state.value.tableau) {
                            if (target.id != source.id && isValidMove(seq, target) && isProgressiveMove(seq, source, target)) {
                                return true
                            }
                        }
                    }
                }
            }
        }

        if (hasPlayableStockCard()) return true
        if (canRecycleStock && hasPlayableWasteCard()) return true
        return false
    }
}
