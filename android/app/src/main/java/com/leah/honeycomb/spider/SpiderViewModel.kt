package com.leah.honeycomb.spider

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.Job
import java.util.UUID

@OptIn(kotlinx.coroutines.FlowPreview::class)
class SpiderViewModel(
    val sharedOptions: SharedGameOptions,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>
) : ViewModel() {

    private val _state = MutableStateFlow(SpiderState())
    val state: StateFlow<SpiderState> = _state.asStateFlow()

    private fun loadOptions(): SpiderOptions =
        PreferencesHelper.getObjectSync(dataStore, "spider_options", SpiderOptions.serializer(), SpiderOptions())

    private fun saveOptions(options: SpiderOptions) {
        PreferencesHelper.saveObjectAsync(dataStore, "spider_options", SpiderOptions.serializer(), options)
    }

    private val _options = MutableStateFlow(loadOptions())
    val options: StateFlow<SpiderOptions> = _options.asStateFlow()

    private val _statistics = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "spider_statistics", SpiderStatistics.serializer(), SpiderStatistics())
    )
    val statistics: StateFlow<SpiderStatistics> = _statistics.asStateFlow()

    private fun updateModeStats(suitCount: Int, transform: (SpiderModeStats) -> SpiderModeStats) {
        val stats = _statistics.value
        val newStatsMap = stats.statsBySuits.toMutableMap()
        val modeStats = newStatsMap[suitCount] ?: SpiderModeStats()
        newStatsMap[suitCount] = transform(modeStats)
        val newStats = stats.copy(statsBySuits = newStatsMap)
        _statistics.value = newStats
        PreferencesHelper.saveObjectAsync(dataStore, "spider_statistics", SpiderStatistics.serializer(), newStats)
    }

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

    // Ported from shared/Spider/ViewModels/SpiderViewModel.swift:938-1162 — ranked/scored
    // hint candidates with 1-ply lookahead, cycling through the ranked queue on repeated
    // taps (via the shared HintCycling engine), auto-clearing after 2s.
    data class HintMove(
        val card: Card,
        val sourcePileId: String,
        val targetPileId: String,
        val description: String
    )

    private val _activeHint = MutableStateFlow<HintMove?>(null)
    val activeHint: StateFlow<HintMove?> = _activeHint.asStateFlow()

    private var hintQueue: List<HintMove> = emptyList()
    private var hintQueueIndex: Int = 0
    private var hintClearJob: Job? = null
    private var lastMoveSourceId: String? = null
    private var lastMoveTargetId: String? = null
    private var hintGeneration = 0

    // The underlying search is O(columns² × drag-lengths) with a 1-ply lookahead, so it's
    // backgrounded on Dispatchers.Default rather than run on the UI thread from onClick.
    // hintGeneration guards against a slow search landing after the board changed underneath it.
    fun findHint() {
        hintClearJob?.cancel()
        val generation = ++hintGeneration
        val currentActiveHint = _activeHint.value
        val currentQueue = hintQueue
        val currentIndex = hintQueueIndex
        viewModelScope.launch(kotlinx.coroutines.Dispatchers.Default) {
            val cycled = HintCycling.findHint(
                current = HintCycleState(activeHint = currentActiveHint, hintQueue = currentQueue, hintQueueIndex = currentIndex),
                collectHints = { collectHints() },
                label = { hint, index, total -> labeled(hint, index, total) },
                noHintFallback = {
                    HintMove(Card(suit = Suit.Spades, rank = 1, faceUp = false), "", "", "No moves available. Replay or deal a new game!")
                }
            )
            if (generation != hintGeneration) return@launch
            _activeHint.value = cycled.activeHint
            hintQueue = cycled.hintQueue
            hintQueueIndex = cycled.hintQueueIndex
            scheduleHintClear()
        }
    }

    fun clearHint() {
        hintClearJob?.cancel()
        hintGeneration++
        _activeHint.value = null
        hintQueue = emptyList()
        hintQueueIndex = 0
        lastMoveSourceId = null
        lastMoveTargetId = null
    }

    private fun scheduleHintClear() {
        hintClearJob?.cancel()
        hintClearJob = viewModelScope.launch {
            delay(2000)
            _activeHint.value = null
            hintQueue = emptyList()
            hintQueueIndex = 0
        }
    }

    private fun labeled(hint: HintMove, index: Int, total: Int): HintMove {
        val prefix = if (total > 1) "[${index + 1}/$total] " else ""
        return hint.copy(description = prefix + hint.description)
    }

    // Ported from evaluateImmediateMoves(depth:) — same-suit run extension scoring,
    // cross-suit build with a clean-stack penalty, empty-column priority (only worthwhile
    // if it reveals a face-down card), stock-deal fallback, 1-ply lookahead at depth 0.
    private fun evaluateImmediateMoves(depth: Int = 0, stateOverride: SpiderState? = null): List<Pair<HintMove, Int>> {
        val st = stateOverride ?: _state.value
        var scored = mutableListOf<Pair<HintMove, Int>>()

        for (col in st.tableau) {
            if (col.isEmpty) continue

            val firstFaceUpIdx = col.cards.indexOfFirst { it.faceUp }.let { if (it == -1) col.cards.size else it }

            var minValidK = col.cards.size - 1
            while (minValidK > 0 && isValidDragSequence(col.cards.subList(minValidK - 1, col.cards.size))) {
                minValidK--
            }

            for (targetCol in st.tableau) {
                if (targetCol.id == col.id) continue

                for (k in minValidK until col.cards.size) {
                    val dragStack = col.cards.subList(k, col.cards.size)
                    val faceDownBelow = if (k == firstFaceUpIdx) firstFaceUpIdx else 0
                    val freesColumn = k == 0
                    val first = dragStack.first()

                    if (targetCol.isEmpty) {
                        if (faceDownBelow > 0) {
                            scored.add(HintMove(first, col.id, targetCol.id, "Move ${first.rankString}${first.suit.symbol} to empty column — Reveal 1 face-down card.") to (350 + faceDownBelow * 150))
                            break
                        } else if (!freesColumn) {
                            val breaksCrossSuit = k > 0 && col.cards[k - 1].faceUp && col.cards[k - 1].suit != first.suit
                            val score = if (breaksCrossSuit) 150 else 50
                            scored.add(HintMove(first, col.id, targetCol.id, "Move ${first.rankString}${first.suit.symbol} sequence to empty column.") to score)
                            break
                        }
                    } else {
                        val topCard = targetCol.topCard
                        if (topCard != null && topCard.rank == first.rank + 1) {
                            if (k > 0 && col.cards[k - 1].faceUp && col.cards[k - 1].suit == topCard.suit && col.cards[k - 1].rank == topCard.rank) {
                                continue
                            }

                            val sameSuit = topCard.suit == first.suit
                            val faceDownBonus = faceDownBelow * 150
                            val vacateBonus = if (freesColumn) 250 else 0

                            var targetIsClean = true
                            val faceUpTargetCards = targetCol.cards.filter { it.faceUp }
                            if (faceUpTargetCards.size > 1) {
                                for (i in 0 until faceUpTargetCards.size - 1) {
                                    if (faceUpTargetCards[i].suit != faceUpTargetCards[i + 1].suit) {
                                        targetIsClean = false
                                        break
                                    }
                                }
                            }
                            val cleanStackPenalty = if (!sameSuit && targetIsClean) -100 else 0

                            if (sameSuit) {
                                val score = if (faceDownBelow > 0) 1000 + faceDownBonus + vacateBonus else 900 + vacateBonus
                                val label = if (faceDownBelow > 0) " — Reveal 1 face-down card." else "."
                                scored.add(HintMove(first, col.id, targetCol.id, "Move ${first.rankString}${first.suit.symbol} onto ${topCard.rankString}${topCard.suit.symbol}$label") to score)
                            } else {
                                val score = if (faceDownBelow > 0) 600 + faceDownBonus + vacateBonus + cleanStackPenalty else 400 + vacateBonus + cleanStackPenalty
                                val label = if (faceDownBelow > 0) " — Reveal 1 face-down card." else "."
                                scored.add(HintMove(first, col.id, targetCol.id, "Move ${first.rankString}${first.suit.symbol} to ${topCard.rankString}${topCard.suit.symbol}$label") to score)
                            }
                            break
                        }
                    }
                }
            }
        }

        if (!st.stock.isEmpty) {
            if (st.tableau.any { it.isEmpty }) {
                scored.add(HintMove(Card(suit = Suit.Spades, rank = 1, faceUp = false), "", "", "Fill all empty columns before dealing cards.") to 25)
            } else {
                scored.add(HintMove(Card(suit = Suit.Spades, rank = 1, faceUp = false), st.stock.id, "", "Deal cards from the Stock pile.") to 50)
            }
        }

        if (depth == 0) {
            val originalState = _state.value
            val enhanced = mutableListOf<Pair<HintMove, Int>>()

            for ((move, baseScore) in scored) {
                if (move.sourcePileId.isEmpty() || move.sourcePileId == st.stock.id) {
                    enhanced.add(move to baseScore)
                    continue
                }
                val srcIdx = originalState.tableau.indexOfFirst { it.id == move.sourcePileId }
                val tgtIdx = originalState.tableau.indexOfFirst { it.id == move.targetPileId }
                if (srcIdx == -1 || tgtIdx == -1) {
                    enhanced.add(move to baseScore)
                    continue
                }

                val cardIdx = originalState.tableau[srcIdx].cards.indexOfFirst { it.id == move.card.id }
                if (cardIdx == -1) {
                    enhanced.add(move to baseScore)
                    continue
                }

                val dragStack = originalState.tableau[srcIdx].cards.subList(cardIdx, originalState.tableau[srcIdx].cards.size)
                val newTableau = originalState.tableau.toMutableList()
                var remaining = newTableau[srcIdx].cards.subList(0, cardIdx).toMutableList()
                if (remaining.isNotEmpty() && !remaining.last().faceUp) {
                    remaining[remaining.size - 1] = remaining.last().copy(faceUp = true)
                }
                newTableau[srcIdx] = newTableau[srcIdx].copy(cards = remaining)
                newTableau[tgtIdx] = newTableau[tgtIdx].copy(cards = newTableau[tgtIdx].cards + dragStack)

                val nextLevel = evaluateImmediateMoves(depth = 1, stateOverride = originalState.copy(tableau = newTableau))

                val bestNext = nextLevel.maxByOrNull { it.second }
                if (bestNext != null) {
                    enhanced.add(move to (baseScore + (bestNext.second * 0.8).toInt()))
                } else {
                    enhanced.add(move to baseScore)
                }
            }
            scored = enhanced
        }

        return scored
    }

    private fun collectHints(): List<HintMove> {
        val scored = evaluateImmediateMoves(depth = 0)
        val src = lastMoveSourceId
        val tgt = lastMoveTargetId
        val filtered = if (src != null && tgt != null) {
            scored.filter { (hint, _) -> !(hint.sourcePileId == tgt && hint.targetPileId == src) }
        } else scored
        val candidates = filtered.ifEmpty { scored }
        return candidates.sortedByDescending { it.second }.map { it.first }
    }

    init {
        val defaultState = SpiderState()
        val savedState = PreferencesHelper.getObjectSync(
            dataStore, "spider_saved_state", SpiderState.serializer(), defaultState
        )
        val savedInitialState = PreferencesHelper.getObjectSync(
            dataStore, "spider_saved_initial_state", SpiderState.serializer(), defaultState
        )

        if (savedState != defaultState && !savedState.hasWon) {
            val restoredState = savedState.copy(isTimerActive = false)
            _state.value = restoredState
            initialState = if (savedInitialState != defaultState) savedInitialState else restoredState
        } else {
            startNewGame()
        }

        viewModelScope.launch {
            _state.debounce(500).collect { currentState ->
                val toSave = if (currentState.hasWon) defaultState else currentState
                PreferencesHelper.saveObjectAsync(
                    dataStore, "spider_saved_state", SpiderState.serializer(), toSave
                )
            }
        }
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

    // Reacts to No Stress Mode toggling mid-game — only starts/stops the timer, never
    // touches the board. Matches Klondike's reactToNoStressModeChange / Swift's original.
    fun reactToNoStressModeChange() {
        if (!sharedOptions.noStressMode.value) {
            if (_state.value.movesCount > 0 && !_state.value.hasWon) {
                startTimerIfNeeded()
            }
        } else if (_state.value.isTimerActive) {
            stopTimer()
            _state.update { it.copy(timerSeconds = 0) }
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopTimer()
    }

    fun startNewGame(abandonedSuitCount: Int? = null) {
        stopTimer()

        val currentState = _state.value
        if (currentState.movesCount > 0 && !currentState.hasWon) {
            val abandonedCount = abandonedSuitCount ?: _options.value.suitCount
            updateModeStats(abandonedCount) { it.copy(currentStreak = 0) }
        }

        updateModeStats(_options.value.suitCount) { it.copy(gamesPlayed = it.gamesPlayed + 1) }

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
        
        PreferencesHelper.saveObjectAsync(
            dataStore, "spider_saved_initial_state", SpiderState.serializer(), newState
        )
        
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

    fun drawFromStock(): Boolean {
        val currentState = _state.value
        if (currentState.stock.isEmpty || hasEmptyTableauColumn) return false

        clearHint()
        saveStateForUndo()
        startTimerIfNeeded()
        com.leah.honeycomb.audio.UISound.play("shuffle")

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
        checkAutocompleteState()
        checkStuckState()
        return true
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

    fun moveCards(cards: List<Card>, sourcePile: Pile, targetPile: Pile): Boolean {
        if (!isValidMove(cards, targetPile)) return false

        com.leah.honeycomb.audio.UISound.play("snap")
        saveStateForUndo()
        clearHint()
        lastMoveSourceId = sourcePile.id
        lastMoveTargetId = targetPile.id
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
        checkAutocompleteState()
        checkStuckState()
        return true
    }

    fun doubleClickMove(card: Card, sourcePile: Pile): Boolean {
        val currentState = _state.value
        val tableau = currentState.tableau
        val colIdx = tableau.indexOfFirst { it.id == sourcePile.id }
        if (colIdx == -1) return false
        
        val col = tableau[colIdx]
        val cardIdx = col.cards.indexOfFirst { it.id == card.id }
        if (cardIdx == -1) return false
        
        val dragStack = col.cards.subList(cardIdx, col.cards.size)
        if (!isValidDragSequence(dragStack)) return false
        
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
            return moveCards(dragStack, sourcePile, targetCol)
        }
        return false
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
            com.leah.honeycomb.audio.UISound.play("victory")

            val timeInSeconds = _state.value.timerSeconds
            val finalScore = _state.value.score
            updateModeStats(_options.value.suitCount) { stats ->
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

    private fun checkStuckState() {
        if (_state.value.hasWon || _isAutocompleteAvailable.value) {
            _isStuck.value = false
            return
        }
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

    fun checkAutocompleteState() {
        val totalFoundationCards = _state.value.foundations.sumOf { it.cards.size }
        if (totalFoundationCards >= 104 || !_state.value.stock.isEmpty) {
            _isAutocompleteAvailable.value = false
            return
        }
        _isAutocompleteAvailable.value = !_state.value.hasWon && canSimulateAutocompleteWin()
    }

    private fun getLongestValidSequence(pile: Pile): List<Card> {
        if (pile.cards.isEmpty()) return emptyList()
        val last = pile.cards.last()
        if (!last.faceUp) return emptyList()
        var start = pile.cards.size - 1
        while (start > 0) {
            val card = pile.cards[start - 1]
            val prevCard = pile.cards[start]
            if (card.faceUp && card.suit == prevCard.suit && card.rank == prevCard.rank + 1) {
                start--
            } else break
        }
        return pile.cards.subList(start, pile.cards.size)
    }

    // Simulates forward using only tableau-to-tableau moves (mirroring isValidMove()'s
    // rank-only landing rule, and a same-suit-descending fallback park onto an empty
    // column) to answer "does the rest of this game play itself out automatically from
    // here," without mutating any real state. Ported from Swift's
    // canSimulateAutocompleteWin().
    private fun canSimulateAutocompleteWin(): Boolean {
        if (!_state.value.stock.isEmpty) return false
        var simTableau = _state.value.tableau.map { it.copy(cards = it.cards.toList()) }
        var didMove = true

        while (didMove) {
            didMove = false
            var nextMove: Triple<List<Card>, Int, Int>? = null
            var fallbackMove: Triple<List<Card>, Int, Int>? = null

            outer@ for (srcIdx in simTableau.indices) {
                if (simTableau[srcIdx].cards.isEmpty()) continue
                val seq = getLongestValidSequence(simTableau[srcIdx])
                if (seq.isEmpty()) continue

                for (tgtIdx in simTableau.indices) {
                    if (tgtIdx == srcIdx) continue
                    val target = simTableau[tgtIdx]
                    if (!target.isEmpty && isValidMove(seq, target)) {
                        nextMove = Triple(seq, srcIdx, tgtIdx)
                        break@outer
                    }
                }

                if (fallbackMove == null && seq.size < simTableau[srcIdx].cards.size) {
                    for (tgtIdx in simTableau.indices) {
                        if (tgtIdx != srcIdx && simTableau[tgtIdx].cards.isEmpty()) {
                            fallbackMove = Triple(seq, srcIdx, tgtIdx)
                            break
                        }
                    }
                }
            }

            val move = nextMove ?: fallbackMove
            if (move != null) {
                didMove = true
                val (cards, srcIdx, tgtIdx) = move
                val cardIds = cards.map { it.id }.toSet()
                val tableau = simTableau.toMutableList()

                var srcCards = tableau[srcIdx].cards.filterNot { it.id in cardIds }
                if (srcCards.isNotEmpty() && !srcCards.last().faceUp) {
                    srcCards = srcCards.dropLast(1) + srcCards.last().copy(faceUp = true)
                }
                tableau[srcIdx] = tableau[srcIdx].copy(cards = srcCards)
                tableau[tgtIdx] = tableau[tgtIdx].copy(cards = tableau[tgtIdx].cards + cards)

                var completedRunFound: Boolean
                do {
                    completedRunFound = false
                    for (i in tableau.indices) {
                        val cards2 = tableau[i].cards
                        if (cards2.size < 13) continue
                        val subrange = cards2.takeLast(13)
                        if (subrange[0].rank != 13) continue
                        val suit = subrange[0].suit
                        val isValidRun = (0 until 13).all { j -> subrange[j].rank == 13 - j && subrange[j].suit == suit && subrange[j].faceUp }
                        if (isValidRun) {
                            completedRunFound = true
                            val completedIds = subrange.map { it.id }.toSet()
                            var newCards = cards2.filterNot { it.id in completedIds }
                            if (newCards.isNotEmpty() && !newCards.last().faceUp) {
                                newCards = newCards.dropLast(1) + newCards.last().copy(faceUp = true)
                            }
                            tableau[i] = tableau[i].copy(cards = newCards)
                            break
                        }
                    }
                } while (completedRunFound)

                simTableau = tableau
            }
        }

        return simTableau.all { it.cards.isEmpty() }
    }

    private fun findNextAutocompleteMove(): Triple<List<Card>, Pile, Pile>? {
        var fallbackSource: Pile? = null
        var fallbackCards: List<Card>? = null
        var fallbackTarget: Pile? = null

        for (source in _state.value.tableau) {
            val seq = getLongestValidSequence(source)
            if (seq.isEmpty()) continue

            for (target in _state.value.tableau) {
                if (target.id == source.id || target.cards.isEmpty()) continue
                if (isValidMove(seq, target)) {
                    return Triple(seq, source, target)
                }
            }

            if (fallbackSource == null && seq.size < source.cards.size) {
                for (target in _state.value.tableau) {
                    if (target.id == source.id || !target.cards.isEmpty()) continue
                    fallbackSource = source
                    fallbackCards = seq
                    fallbackTarget = target
                    break
                }
            }
        }

        return if (fallbackSource != null && fallbackCards != null && fallbackTarget != null) {
            Triple(fallbackCards, fallbackSource, fallbackTarget)
        } else null
    }

    fun runAutocomplete() {
        if (!_isAutocompleteAvailable.value || _isAutoplayRunning.value) return
        saveStateForUndo()
        _isAutoplayRunning.value = true
        animateNextAutocompleteMove()
    }

    private fun animateNextAutocompleteMove() {
        if (!_isAutoplayRunning.value) return
        val nextMove = findNextAutocompleteMove()
        if (nextMove != null) {
            moveCards(nextMove.first, nextMove.second, nextMove.third)
            viewModelScope.launch {
                delay(150)
                animateNextAutocompleteMove()
            }
        } else {
            _isAutoplayRunning.value = false
            checkWinState()
        }
    }

    fun undoLastAction(): Boolean {
        if (_state.value.hasWon) return false
        if (!undoStack.canUndo) return false
        
        val previous = undoStack.pop() ?: return false
        val currentTimer = _state.value.timerSeconds
        val currentActive = _state.value.isTimerActive
        _state.value = previous.copy(
            timerSeconds = currentTimer,
            isTimerActive = currentActive
        )
        _isAutoplayRunning.value = false
        _isStuck.value = false
        _pointPopup.value = null
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
        return true
    }
}
