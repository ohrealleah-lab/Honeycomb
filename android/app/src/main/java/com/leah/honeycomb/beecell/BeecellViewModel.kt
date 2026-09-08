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
import kotlinx.coroutines.Job
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

    private fun updateModeStats(modeKey: Int, transform: (BeecellModeStats) -> BeecellModeStats) {
        val stats = _statistics.value
        val newStatsMap = stats.statsByFreeCells.toMutableMap()
        val modeStats = newStatsMap[modeKey] ?: BeecellModeStats()
        newStatsMap[modeKey] = transform(modeStats)
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

    // Ported from shared/Beecell/ViewModels/BeecellViewModel.swift:804-1013 — ranked/
    // scored hint candidates with 1-ply lookahead, cycling through the ranked queue on
    // repeated taps (via the shared HintCycling engine), auto-clearing after 2s.
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

    // The underlying search is O(free cells × foundations + tableau² × supermove-length)
    // with a 1-ply lookahead, so it's backgrounded on Dispatchers.Default rather than run
    // on the UI thread from onClick. hintGeneration guards against a slow search landing
    // after the board changed underneath it.
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
                    HintMove(Card(suit = Suit.Spades, rank = 1, faceUp = true), "", "", "No moves available. Try restarting or starting a new game.")
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

    // Android is 1-deck only (see the port plan §3) — the "2 opposite-color foundations
    // per deck" iOS formula (`2 * options.deckCount`) collapses to the 1-deck constant 2,
    // since BeecellOptions.kt has no deckCount field to multiply by.
    private fun isSafeFoundationMoveForHint(card: Card, foundations: List<Pile>): Boolean {
        if (card.rank <= 2) return true
        val isRed = card.suit == Suit.Hearts || card.suit == Suit.Diamonds
        val reqRank = card.rank - 1
        var safeCount = 0
        for (foundation in foundations) {
            val top = foundation.topCard
            if (top != null) {
                val topIsRed = top.suit == Suit.Hearts || top.suit == Suit.Diamonds
                if (topIsRed != isRed && top.rank >= reqRank) safeCount++
            }
        }
        return safeCount == 2
    }

    // Ported from evaluateImmediateMoves(depth:) — free-cell/tableau-to-foundation, a
    // supermove-length search (maxDraggable via the descending alternating-color run,
    // trying lengths longest-first), free-cell-to-tableau, tableau-to-free-cell as a
    // scored last resort, 1-ply lookahead at depth 0.
    private fun evaluateImmediateMoves(depth: Int = 0, stateOverride: BeecellState? = null): List<Pair<HintMove, Int>> {
        val st = stateOverride ?: _state.value
        var scored = mutableListOf<Pair<HintMove, Int>>()

        for (cell in st.freeCells) {
            val top = cell.topCard ?: continue
            for (foundation in st.foundations) {
                if (isValidMove(listOf(top), foundation)) {
                    val score = if (isSafeFoundationMoveForHint(top, st.foundations)) 1000 else 200
                    scored.add(HintMove(top, cell.id, foundation.id, "Move ${top.rankString}${top.suit.symbol} from Free Cell to Foundation.") to score)
                }
            }
        }
        for (col in st.tableau) {
            val top = col.topCard ?: continue
            for (foundation in st.foundations) {
                if (isValidMove(listOf(top), foundation)) {
                    val score = if (isSafeFoundationMoveForHint(top, st.foundations)) 1000 else 200
                    scored.add(HintMove(top, col.id, foundation.id, "Move ${top.rankString}${top.suit.symbol} to Foundation.") to score)
                }
            }
        }

        for (sourceCol in st.tableau) {
            if (sourceCol.isEmpty) continue

            var maxDraggable = 1
            for (i in (1 until sourceCol.cards.size).reversed()) {
                if (sourceCol.cards[i].rank == sourceCol.cards[i - 1].rank - 1 && sourceCol.cards[i].isRed != sourceCol.cards[i - 1].isRed) {
                    maxDraggable++
                } else break
            }

            val stEmptyFreeCells = st.freeCells.count { it.isEmpty }
            val stEmptyTableauColumns = st.tableau.count { it.isEmpty }
            for (targetCol in st.tableau) {
                if (targetCol.id == sourceCol.id) continue
                for (len in maxDraggable downTo 1) {
                    val dragStack = sourceCol.cards.subList(sourceCol.cards.size - len, sourceCol.cards.size)
                    if (!isValidMove(dragStack, targetCol, stEmptyFreeCells, stEmptyTableauColumns)) continue
                    if (!isProgressiveMove(dragStack, sourceCol, targetCol)) continue
                    val freesColumn = dragStack.size == sourceCol.cards.size
                    val score = if (freesColumn) 700 else 400 + dragStack.size * 20
                    scored.add(HintMove(dragStack.first(), sourceCol.id, targetCol.id, "Move ${dragStack.first().rankString}${dragStack.first().suit.symbol} sequence to Tableau.") to score)
                    break
                }
            }
        }

        for (cell in st.freeCells) {
            val top = cell.topCard ?: continue
            for (targetCol in st.tableau) {
                if (isValidMove(listOf(top), targetCol)) {
                    scored.add(HintMove(top, cell.id, targetCol.id, "Move ${top.rankString}${top.suit.symbol} from Free Cell to Tableau.") to 500)
                }
            }
        }

        for (sourceCol in st.tableau) {
            val top = sourceCol.topCard ?: continue
            val emptyCell = st.freeCells.firstOrNull { it.isEmpty }
            if (emptyCell != null) {
                scored.add(HintMove(top, sourceCol.id, emptyCell.id, "Move ${top.rankString}${top.suit.symbol} to Free Cell to clear space.") to 100)
            }
        }

        if (depth == 0) {
            val originalState = _state.value
            val enhanced = mutableListOf<Pair<HintMove, Int>>()

            for ((move, baseScore) in scored) {
                var validSource = false
                var dragStack: List<Card> = emptyList()
                var working = originalState

                val cellIdx = working.freeCells.indexOfFirst { it.id == move.sourcePileId }
                if (cellIdx != -1) {
                    val cellTop = working.freeCells[cellIdx].cards.lastOrNull()
                    if (cellTop != null && cellTop.id == move.card.id) {
                        dragStack = listOf(cellTop)
                        val newCells = working.freeCells.toMutableList()
                        newCells[cellIdx] = newCells[cellIdx].copy(cards = newCells[cellIdx].cards.dropLast(1))
                        working = working.copy(freeCells = newCells)
                        validSource = true
                    }
                } else {
                    val srcIdx = working.tableau.indexOfFirst { it.id == move.sourcePileId }
                    if (srcIdx != -1) {
                        val cardIdx = working.tableau[srcIdx].cards.indexOfFirst { it.id == move.card.id }
                        if (cardIdx != -1) {
                            dragStack = working.tableau[srcIdx].cards.subList(cardIdx, working.tableau[srcIdx].cards.size)
                            val newTableau = working.tableau.toMutableList()
                            newTableau[srcIdx] = newTableau[srcIdx].copy(cards = newTableau[srcIdx].cards.subList(0, cardIdx))
                            working = working.copy(tableau = newTableau)
                            validSource = true
                        }
                    }
                }

                if (!validSource) {
                    enhanced.add(move to baseScore)
                    continue
                }

                val tgtTabIdx = working.tableau.indexOfFirst { it.id == move.targetPileId }
                working = if (tgtTabIdx != -1) {
                    val newTableau = working.tableau.toMutableList()
                    newTableau[tgtTabIdx] = newTableau[tgtTabIdx].copy(cards = newTableau[tgtTabIdx].cards + dragStack)
                    working.copy(tableau = newTableau)
                } else {
                    val tgtFoundIdx = working.foundations.indexOfFirst { it.id == move.targetPileId }
                    if (tgtFoundIdx != -1) {
                        val newFoundations = working.foundations.toMutableList()
                        newFoundations[tgtFoundIdx] = newFoundations[tgtFoundIdx].copy(cards = newFoundations[tgtFoundIdx].cards + dragStack)
                        working.copy(foundations = newFoundations)
                    } else {
                        val tgtCellIdx = working.freeCells.indexOfFirst { it.id == move.targetPileId }
                        if (tgtCellIdx != -1) {
                            val newCells = working.freeCells.toMutableList()
                            newCells[tgtCellIdx] = newCells[tgtCellIdx].copy(cards = newCells[tgtCellIdx].cards + dragStack)
                            working.copy(freeCells = newCells)
                        } else working
                    }
                }

                val nextLevel = evaluateImmediateMoves(depth = 1, stateOverride = working)

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
        startNewGame()
    }
    
    fun updateOptions(newOptions: BeecellOptions) {
        val oldOptions = _options.value
        _options.value = newOptions
        saveOptions(newOptions)
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

    fun startNewGame() {
        stopTimer()
        clearHint()

        val currentState = _state.value
        if (currentState.movesCount > 0 && !currentState.hasWon) {
            
            updateModeStats(4) { it.copy(currentStreak = 0) }
        }

        updateModeStats(4) { it.copy(gamesPlayed = it.gamesPlayed + 1) }

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
        for (i in 0 until 4) {
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
        clearHint()
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
        
    fun maxMoveLimit(toEmptyTableau: Boolean, emptyFreeCells: Int = emptyFreeCellsCount, emptyTableauColumns: Int = emptyTableauColumnsCount): Int {
        val e = emptyFreeCells
        val c = emptyTableauColumns
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
    
    fun isValidMove(
        cards: List<Card>,
        targetPile: Pile,
        emptyFreeCells: Int = emptyFreeCellsCount,
        emptyTableauColumns: Int = emptyTableauColumnsCount
    ): Boolean {
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
                val limit = maxMoveLimit(toEmptyTableau = isTargetEmpty, emptyFreeCells = emptyFreeCells, emptyTableauColumns = emptyTableauColumns)
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
        return true
    }
    
    fun doubleClickMove(card: Card, sourcePile: Pile): Boolean {
        if (sourcePile.topCard?.id != card.id) return false
        
        val foundations = _state.value.foundations
        for (f in foundations) {
            if (isValidMove(listOf(card), f)) {
                return moveCards(listOf(card), sourcePile, f)
            }
        }
        
        val freeCells = _state.value.freeCells
        for (cell in freeCells) {
            if (cell.isEmpty && isValidMove(listOf(card), cell)) {
                return moveCards(listOf(card), sourcePile, cell)
            }
        }
        
        val tableau = _state.value.tableau
        for (col in tableau) {
            if (isValidMove(listOf(card), col)) {
                return moveCards(listOf(card), sourcePile, col)
            }
        }
        return false
    }
    
    private fun checkWinState() {
        val totalFoundationCards = _state.value.foundations.sumOf { it.cards.size }
        if (WinDetection.hasWon(totalFoundationCards, 52, _state.value.hasWon)) {
            _state.update { it.copy(hasWon = true) }
            stopTimer()
            com.leah.honeycomb.audio.UISound.play("victory")

            val timeInSeconds = _state.value.timerSeconds
            val finalScore = _state.value.score
            updateModeStats(4) { stats ->
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
        if (_state.value.hasWon || _isAutocompleteAvailable.value) {
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
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }
}
