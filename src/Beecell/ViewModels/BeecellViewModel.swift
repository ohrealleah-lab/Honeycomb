import Foundation
import Observation
import AppKit

@Observable
public final class BeecellViewModel {
    public var state: BeecellState
    private let gameTimer = GameTimer()
    
    public var options: BeecellOptions {
        didSet {
            saveOptions()
            UISound.isEnabled = options.isSoundEnabled
            handleOptionsChanged(oldValue: oldValue)
        }
    }

    public var statistics: BeecellStatistics {
        didSet {
            saveStatistics()
        }
    }
    
    // Auto-complete status
    public var isAutocompleteAvailable: Bool = false
    public var isAutoplayRunning: Bool = false

    // Stuck detection
    public var isStuck: Bool = false
    
    // Undo stack
    private var undoStack = UndoStack<BeecellState>()
    
    // Initial state for game replay
    private var initialState: BeecellState?
    
    public var canUndo: Bool {
        !undoStack.isEmpty && !state.hasWon
    }
    
    public var currentModeKey: String {
        options.deckCount == 1 ? "1deck" : "2deck"
    }
    
    public var currentModeStats: ModeStats {
        statistics.statsByMode[currentModeKey] ?? ModeStats()
    }
    
    public var highScore: Int {
        get { currentModeStats.highScore }
        set {
            var stats = statistics
            var modeStats = stats.statsByMode[currentModeKey] ?? ModeStats()
            modeStats.highScore = newValue
            stats.statsByMode[currentModeKey] = modeStats
            statistics = stats
        }
    }
    
    public var highScoreString: String { String(highScore) }

    public var scoreString: String { String(state.score) }
    
    // Board scale — no longer manual; BeecellView.recomputeScale() continuously derives
    // this from the window's current size. Not persisted, purely a function of window size.
    public var zoomScale: CGFloat = 1.0

    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: "beecell_options")
        }
    }
    
    private func handleOptionsChanged(oldValue: BeecellOptions) {
        if effectiveTimed(options) != effectiveTimed(oldValue) {
            if effectiveTimed(options) {
                if state.movesCount > 0 && !state.hasWon {
                    startTimerIfNeeded()
                }
            } else if state.isTimerActive {
                // Only reset elapsed time when we're actually stopping a running timer
                // (this game was the foreground one). A shared-option change (e.g. No
                // Stress Mode toggled elsewhere and synced in via AppCoordinator) can
                // reach a backgrounded game whose timer is already stopped — its saved
                // elapsed time shouldn't be wiped just because it received the update.
                stopTimer()
                state.timerSeconds = 0
            }
        }

        if options.deckCount != oldValue.deckCount {
            startNewGame()
        }
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: "beecell_statistics")
        }
    }
    
    public func playSound(named name: String) {
        UISound.play(named: name, enabled: options.isSoundEnabled)
    }
    
    public func recordWin(timeInSeconds: Int) {
        var stats = statistics
        var modeStats = stats.statsByMode[currentModeKey] ?? ModeStats()
        modeStats.gamesWon += 1
        modeStats.currentStreak += 1
        modeStats.longestStreak = max(modeStats.longestStreak, modeStats.currentStreak)
        if timeInSeconds > 0 {
            modeStats.totalWinningTime += timeInSeconds
            modeStats.winningGamesCount += 1
            if modeStats.shortestWinTime == 0 || timeInSeconds < modeStats.shortestWinTime {
                modeStats.shortestWinTime = timeInSeconds
            }
        }
        stats.statsByMode[currentModeKey] = modeStats
        statistics = stats
    }
    
    public init() {
        // Initialize all stored properties first with defaults
        self.state = BeecellState(
            freeCells: [],
            foundations: [],
            tableau: [],
            score: 0,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            hasWon: false
        )
        self.options = BeecellOptions()
        self.statistics = BeecellStatistics()
        self.zoomScale = 1.0

        // Load options
        if let data = UserDefaults.standard.data(forKey: "beecell_options"),
           let decoded = try? JSONDecoder().decode(BeecellOptions.self, from: data) {
            self.options = decoded
        } else {
            self.options = BeecellOptions()
        }
        
        // Load statistics
        if let data = UserDefaults.standard.data(forKey: "beecell_statistics"),
           let decoded = try? JSONDecoder().decode(BeecellStatistics.self, from: data) {
            self.statistics = decoded
        }

        UISound.isEnabled = self.options.isSoundEnabled

        startNewGame()
    }

    deinit {
        stopTimer()
    }

    // MARK: - Game Setup
    
    public func startNewGame() {
        stopTimer()
        
        // Record loss / reset streak if they abandoned an active game
        if state.movesCount > 0 && !state.hasWon {
            var stats = statistics
            var modeStats = stats.statsByMode[currentModeKey] ?? ModeStats()
            modeStats.currentStreak = 0
            stats.statsByMode[currentModeKey] = modeStats
            statistics = stats
        }
        
        undoStack.removeAll()
        
        var stats = statistics
        var modeStats = stats.statsByMode[currentModeKey] ?? ModeStats()
        modeStats.gamesPlayed += 1
        stats.statsByMode[currentModeKey] = modeStats
        statistics = stats
        
        playSound(named: "shuffle")
        
        // 1. Create decks
        var deck: [Card] = []
        for _ in 0..<options.deckCount {
            for suit in Card.Suit.allCases {
                for rank in 1...13 {
                    // Freecell cards are always dealt face-up
                    deck.append(Card(suit: suit, rank: rank, faceUp: true))
                }
            }
        }
        
        // 2. Shuffle deck
        deck.shuffle()
        
        // 3. Setup pile sizes based on deck count
        let numTableaus = options.deckCount == 1 ? 8 : 10
        let numFreeCells = options.deckCount == 1 ? 4 : 8
        let numFoundations = options.deckCount == 1 ? 4 : 8
        
        // 4. Deal Tableau columns
        var tableau: [Pile] = []
        for i in 0..<numTableaus {
            tableau.append(Pile(id: "tableau_\(i)", type: .tableau, cards: []))
        }
        
        var cardIndex = 0
        while cardIndex < deck.count {
            let colIndex = cardIndex % numTableaus
            tableau[colIndex].cards.append(deck[cardIndex])
            cardIndex += 1
        }
        
        // 5. Initialize Free Cells and Foundations
        var freeCells: [Pile] = []
        for i in 0..<numFreeCells {
            freeCells.append(Pile(id: "freecell_\(i)", type: .freeCell, cards: []))
        }
        
        var foundations: [Pile] = []
        for i in 0..<numFoundations {
            foundations.append(Pile(id: "foundation_\(i)", type: .foundation, cards: []))
        }
        
        // 6. Scoring
        let initialScore = 0
        
        state = BeecellState(
            freeCells: freeCells,
            foundations: foundations,
            tableau: tableau,
            score: initialScore,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            hasWon: false
        )
        
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
        initialState = state
        clearHint()
        clearKeyboardCursor()
    }

    public func restartCurrentGame() {
        guard let initial = initialState else { return }
        stopTimer()
        undoStack.removeAll()
        state = initial
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
        clearHint()
        clearKeyboardCursor()
    }
    
    // MARK: - Sequence Limits
    
    public var emptyFreeCellsCount: Int {
        state.freeCells.filter { $0.cards.isEmpty }.count
    }
    
    public var emptyTableauColumnsCount: Int {
        state.tableau.filter { $0.cards.isEmpty }.count
    }
    
    public func maxMoveLimit(toEmptyTableau: Bool) -> Int {
        let E = emptyFreeCellsCount
        let C = emptyTableauColumnsCount
        
        if toEmptyTableau {
            // If moving to an empty column, that column doesn't count as temporary storage
            return (E + 1) * (1 << max(0, C - 1))
        } else {
            return (E + 1) * (1 << C)
        }
    }
    
    // MARK: - Move Validation & Execution
    
    public func isValidMove(cards: [Card], to targetPile: Pile) -> Bool {
        guard let firstCard = cards.first else { return false }
        
        // Verify that the dragged cards form a valid descending alternating color sequence
        if cards.count > 1 {
            for i in 0..<(cards.count - 1) {
                let upper = cards[i]
                let lower = cards[i+1]
                if upper.rank != lower.rank + 1 || upper.isRed == lower.isRed {
                    return false
                }
            }
        }
        
        switch targetPile.type {
        case .freeCell:
            // Free Cells only accept a single card at a time and must be vacant
            return cards.count == 1 && targetPile.isEmpty
            
        case .foundation:
            // Foundations only accept a single card at a time
            guard cards.count == 1 else { return false }
            
            if targetPile.isEmpty {
                return firstCard.rank == 1 // Only Ace starts an empty foundation
            } else {
                guard let topCard = targetPile.topCard else { return false }
                return firstCard.suit == topCard.suit && firstCard.rank == topCard.rank + 1
            }
            
        case .tableau:
            let isTargetEmpty = targetPile.isEmpty
            let limit = maxMoveLimit(toEmptyTableau: isTargetEmpty)
            guard cards.count <= limit else { return false }
            
            if isTargetEmpty {
                return true // Any card/sequence can start an empty tableau column
            } else {
                guard let topCard = targetPile.topCard else { return false }
                return firstCard.rank == topCard.rank - 1 && firstCard.isRed != topCard.isRed
            }
            
        case .stock, .waste:
            return false
        }
    }
    
    public func moveCards(_ cards: [Card], from sourcePile: Pile, to targetPile: Pile) {
        guard isValidMove(cards: cards, to: targetPile) else { return }
        lastMoveSourceId = sourcePile.id
        lastMoveTargetId = targetPile.id
        saveStateForUndo()
        startTimerIfNeeded()
        playSound(named: "snap")
        
        let cardIDs = Set(cards.map { $0.id })
        
        // 1. Remove from source
        if sourcePile.type == .freeCell {
            if let idx = state.freeCells.firstIndex(where: { $0.id == sourcePile.id }) {
                state.freeCells[idx].cards.removeAll { cardIDs.contains($0.id) }
            }
        } else if sourcePile.type == .foundation {
            if let idx = state.foundations.firstIndex(where: { $0.id == sourcePile.id }) {
                state.foundations[idx].cards.removeAll { cardIDs.contains($0.id) }
            }
        } else if sourcePile.type == .tableau {
            if let idx = state.tableau.firstIndex(where: { $0.id == sourcePile.id }) {
                state.tableau[idx].cards.removeAll { cardIDs.contains($0.id) }
            }
        }
        
        // 2. Add to target
        if targetPile.type == .freeCell {
            if let idx = state.freeCells.firstIndex(where: { $0.id == targetPile.id }) {
                state.freeCells[idx].cards.append(contentsOf: cards)
            }
        } else if targetPile.type == .foundation {
            if let idx = state.foundations.firstIndex(where: { $0.id == targetPile.id }) {
                state.foundations[idx].cards.append(contentsOf: cards)
            }
        } else if targetPile.type == .tableau {
            if let idx = state.tableau.firstIndex(where: { $0.id == targetPile.id }) {
                state.tableau[idx].cards.append(contentsOf: cards)
            }
        }
        
        // 3. Scoring
        adjustScore(from: sourcePile.type, to: targetPile.type)
        
        state.movesCount += 1
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }

    public func doubleClickMove(card: Card, from sourcePile: Pile) {
        guard sourcePile.topCard?.id == card.id else { return }
        // Match the drag-start convention: any direct mouse move relinquishes keyboard
        // focus/selection so a pending selection can't act on a pile this move changes.
        clearKeyboardCursor()

        // Try foundation first
        for foundation in state.foundations {
            if isValidMove(cards: [card], to: foundation) {
                moveCards([card], from: sourcePile, to: foundation)
                return
            }
        }
        
        // Try empty free cells second
        for cell in state.freeCells {
            if cell.isEmpty && isValidMove(cards: [card], to: cell) {
                moveCards([card], from: sourcePile, to: cell)
                return
            }
        }
        
        // Try tableau columns third
        for col in state.tableau {
            if isValidMove(cards: [card], to: col) {
                moveCards([card], from: sourcePile, to: col)
                return
            }
        }
    }
    
    private func adjustScore(from source: Pile.PileType, to target: Pile.PileType) {
        if target == .foundation {
            state.score += 10
        } else if source == .foundation {
            // Penalize leaving a foundation regardless of destination (tableau or free
            // cell) — otherwise cycling a card foundation -> free cell -> foundation
            // nets a free +10 every round trip since only the tableau case was covered.
            state.score = max(0, state.score - 15)
        }
    }
    
    // MARK: - Timer Handling

    // `isTimed` has no UI control anymore (the old "Timed Game" toggle was replaced by
    // No Stress Mode) so it's intentionally not consulted here — honoring a persisted
    // `false` from before that change would permanently strand upgrading users with no
    // way to turn the timer back on.
    private func effectiveTimed(_ o: BeecellOptions) -> Bool {
        !o.noStressMode
    }

    public func startTimerIfNeeded() {
        guard effectiveTimed(options) else { return }
        gameTimer.start(
            isActive: { state.isTimerActive },
            setActive: { state.isTimerActive = $0 },
            tick: { [weak self] in self?.state.timerSeconds += 1 }
        )
    }

    public func stopTimer() {
        gameTimer.stop(setActive: { state.isTimerActive = $0 })
    }

    // MARK: - Victory Verification

    public func checkWinState() {
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        let expectedCards = options.deckCount * 52

        if WinDetection.hasWon(foundationCardCount: totalFoundationCards, totalCards: expectedCards, alreadyWon: state.hasWon) {
            state.hasWon = true
            stopTimer()
            recordWin(timeInSeconds: state.timerSeconds)
            playSound(named: "victory")
            if state.score > highScore {
                highScore = state.score
            }
        }
    }
    
    // MARK: - Stuck Detection

    private func isProgressiveMove(cards: [Card], source: Pile, target: Pile) -> Bool {
        // Retreating a card off a foundation is never a real way to become unstuck —
        // collectHints() never suggests it either, so without this guard hasValidMoves()
        // would keep the game from ever declaring itself stuck as long as any free cell
        // is open and any foundation holds a card, even when no other move exists.
        if source.type == .foundation { return false }
        if target.type == .foundation { return true }
        if source.type == .freeCell { return true }
        if target.type == .freeCell { return true }
        if source.type == .tableau {
            let remainingCount = source.cards.count - cards.count
            if remainingCount == 0 {
                // Moving a full column onto an empty target just relocates which column
                // is empty — net zero progress unless the target was actually occupied.
                return !target.isEmpty
            }
            // Any other tableau-to-tableau move builds/extends a legal sequence without
            // fully emptying the source column — ordinary, genuine progress.
            return true
        }
        return false
    }

    private func hasValidMoves() -> Bool {
        let allPiles: [Pile] = state.freeCells + state.foundations + state.tableau

        // Check every face-up top card against every possible target
        for source in allPiles {
            guard let topCard = source.topCard else { continue }

            // Try single card to all targets
            for target in allPiles where target.id != source.id {
                if isValidMove(cards: [topCard], to: target),
                   isProgressiveMove(cards: [topCard], source: source, target: target) {
                    return true
                }
            }

            // Try sequences from tableau columns — every sub-run length, not just the
            // longest. Beecell's supermove cap (maxMoveLimit, based on empty free cells/
            // columns) can block the full run while a shorter suffix of that same run is
            // still legal and progressive, so collectHints() already tries every length;
            // this must match or isStuck can fire while Hint still finds a real move.
            if source.type == .tableau {
                var seqStart = source.cards.count - 1
                while seqStart > 0 {
                    let upper = source.cards[seqStart - 1]
                    let lower = source.cards[seqStart]
                    if upper.rank == lower.rank + 1 && upper.isRed != lower.isRed { seqStart -= 1 } else { break }
                }
                for idx in seqStart..<source.cards.count {
                    let seq = Array(source.cards[idx...])
                    for target in state.tableau where target.id != source.id {
                        if isValidMove(cards: seq, to: target),
                           isProgressiveMove(cards: seq, source: source, target: target) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    public func checkStuckState() {
        guard !state.hasWon && !isAutocompleteAvailable else {
            isStuck = false
            return
        }
        isStuck = !hasValidMoves()
    }

    // MARK: - Autocomplete & Hint

    public func checkAutocompleteState() {
        let expectedCards = options.deckCount * 52
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        
        if totalFoundationCards == expectedCards {
            isAutocompleteAvailable = false
            return
        }
        
        isAutocompleteAvailable = !state.hasWon && canAutocompleteToCompletion()
    }
    
    private func canAutocompleteToCompletion() -> Bool {
        var tempState = self.state
        let expectedCards = options.deckCount * 52
        
        let initialFoundationCount = tempState.foundations.reduce(0) { $0 + $1.cards.count }
        if initialFoundationCount == expectedCards {
            return false
        }
        
        while true {
            let foundationCount = tempState.foundations.reduce(0) { $0 + $1.cards.count }
            if foundationCount == expectedCards {
                return true
            }
            
            if let nextMove = findNextFoundationMove(in: tempState) {
                // Apply the move to tempState
                if let cellIdx = tempState.freeCells.firstIndex(where: { $0.id == nextMove.sourceId }) {
                    tempState.freeCells[cellIdx].cards.removeAll { $0.id == nextMove.card.id }
                } else if let tabIdx = tempState.tableau.firstIndex(where: { $0.id == nextMove.sourceId }) {
                    tempState.tableau[tabIdx].cards.removeAll { $0.id == nextMove.card.id }
                }
                
                if let fndIdx = tempState.foundations.firstIndex(where: { $0.id == nextMove.targetId }) {
                    tempState.foundations[fndIdx].cards.append(nextMove.card)
                }
            } else {
                return false
            }
        }
    }
    
    private func minFoundationRank(for suit: Card.Suit, in foundations: [Pile]) -> Int {
        let foundationsOfSuit = foundations.filter { $0.topCard?.suit == suit }
        let nonEmptyRanks = foundationsOfSuit.map { $0.topCard?.rank ?? 0 }
        
        var ranks = nonEmptyRanks
        let expectedCount = options.deckCount
        while ranks.count < expectedCount {
            ranks.append(0)
        }
        
        return ranks.min() ?? 0
    }
    
    private func isSafeFoundationMove(_ card: Card, in foundations: [Pile]) -> Bool {
        if card.rank <= 2 {
            return true
        }
        
        let oppositeSuits: [Card.Suit] = card.isRed ? [.spades, .clubs] : [.hearts, .diamonds]
        
        for suit in oppositeSuits {
            let minRank = minFoundationRank(for: suit, in: foundations)
            if minRank < card.rank - 2 {
                return false
            }
        }
        
        return true
    }

    private func findNextFoundationMove(in simState: BeecellState) -> (card: Card, sourceId: String, targetId: String)? {
        // Free cells first
        for cell in simState.freeCells {
            if let topCard = cell.topCard {
                for foundation in simState.foundations {
                    if isValidFoundationMove(card: topCard, to: foundation) {
                        if isSafeFoundationMove(topCard, in: simState.foundations) {
                            return (topCard, cell.id, foundation.id)
                        }
                    }
                }
            }
        }
        // Tableau second
        for column in simState.tableau {
            if let topCard = column.topCard {
                for foundation in simState.foundations {
                    if isValidFoundationMove(card: topCard, to: foundation) {
                        if isSafeFoundationMove(topCard, in: simState.foundations) {
                            return (topCard, column.id, foundation.id)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func isValidFoundationMove(card: Card, to foundation: Pile) -> Bool {
        if foundation.isEmpty {
            return card.rank == 1
        } else {
            guard let topCard = foundation.topCard else { return false }
            return card.suit == topCard.suit && card.rank == topCard.rank + 1
        }
    }
    
    public struct HintMove: Equatable {
        public let card: Card
        public let sourcePileId: String
        public let targetPileId: String
        public let description: String
    }

    public var activeHint: HintMove? = nil
    private var hintClearTask: DispatchWorkItem?
    private var hintQueue: [HintMove] = []
    private var hintQueueIndex: Int = 0
    private var lastMoveSourceId: String? = nil
    private var lastMoveTargetId: String? = nil

    public func findHint() {
        hintClearTask?.cancel()

        if !hintQueue.isEmpty && activeHint != nil {
            hintQueueIndex = (hintQueueIndex + 1) % hintQueue.count
            activeHint = labeled(hintQueue[hintQueueIndex], index: hintQueueIndex, total: hintQueue.count)
            scheduleHintClear()
            return
        }

        hintQueue = collectHints()
        hintQueueIndex = 0

        guard !hintQueue.isEmpty else {
            activeHint = HintMove(card: Card(suit: .spades, rank: 1, faceUp: true),
                sourcePileId: "", targetPileId: "", description: "No moves available. Try restarting or starting a new game.")
            scheduleHintClear()
            return
        }

        activeHint = labeled(hintQueue[0], index: 0, total: hintQueue.count)
        scheduleHintClear()
    }

    private func labeled(_ hint: HintMove, index: Int, total: Int) -> HintMove {
        let prefix = total > 1 ? "[\(index + 1)/\(total)] " : ""
        return HintMove(card: hint.card, sourcePileId: hint.sourcePileId,
            targetPileId: hint.targetPileId, description: prefix + hint.description)
    }

    public var hasHintsAvailable: Bool { !collectHints().isEmpty }

    public var debugBannerRequest: DebugBannerKind? = nil

    private func collectHints() -> [HintMove] {
        var scored: [(HintMove, Int)] = []

        // Foundation moves (highest value)
        for cell in state.freeCells {
            guard let top = cell.topCard else { continue }
            for foundation in state.foundations where isValidMove(cards: [top], to: foundation) {
                scored.append((HintMove(card: top, sourcePileId: cell.id, targetPileId: foundation.id,
                    description: "Move \(top.rankString)\(top.suit.symbol) from Free Cell to Foundation."), 1000))
            }
        }
        for col in state.tableau {
            guard let top = col.topCard else { continue }
            for foundation in state.foundations where isValidMove(cards: [top], to: foundation) {
                scored.append((HintMove(card: top, sourcePileId: col.id, targetPileId: foundation.id,
                    description: "Move \(top.rankString)\(top.suit.symbol) to Foundation."), 1000))
            }
        }

        // Tableau-to-tableau: score higher if it frees a column or moves a longer sequence.
        // Tries each target's suffix lengths longest-first and stops at the first legal
        // one — against an empty target, isValidMove passes unconditionally for every
        // length up to the supermove cap, so without the longest-first + break here, a
        // single long run would generate one near-duplicate hint per suffix length.
        for sourceCol in state.tableau {
            guard !sourceCol.isEmpty else { continue }
            var seqStart = sourceCol.cards.count - 1
            while seqStart > 0 {
                let upper = sourceCol.cards[seqStart - 1], lower = sourceCol.cards[seqStart]
                if upper.rank == lower.rank + 1 && upper.isRed != lower.isRed { seqStart -= 1 } else { break }
            }
            for targetCol in state.tableau where targetCol.id != sourceCol.id {
                for idx in seqStart..<sourceCol.cards.count {
                    let dragStack = Array(sourceCol.cards[idx...])
                    guard isValidMove(cards: dragStack, to: targetCol) else { continue }
                    if targetCol.isEmpty && dragStack.count == 1 && idx == 0 { continue }
                    let freesColumn = dragStack.count == sourceCol.cards.count
                    let score = freesColumn ? 700 : 400 + dragStack.count * 20
                    scored.append((HintMove(card: dragStack.first!, sourcePileId: sourceCol.id, targetPileId: targetCol.id,
                        description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) sequence to Tableau."), score))
                    break
                }
            }
        }

        // Free cell to tableau
        for cell in state.freeCells {
            guard let top = cell.topCard else { continue }
            for targetCol in state.tableau where isValidMove(cards: [top], to: targetCol) {
                scored.append((HintMove(card: top, sourcePileId: cell.id, targetPileId: targetCol.id,
                    description: "Move \(top.rankString)\(top.suit.symbol) from Free Cell to Tableau."), 400))
            }
        }

        // Tableau to free cell (last resort)
        for sourceCol in state.tableau {
            guard let top = sourceCol.topCard else { continue }
            for cell in state.freeCells where cell.isEmpty {
                scored.append((HintMove(card: top, sourcePileId: sourceCol.id, targetPileId: cell.id,
                    description: "Move \(top.rankString)\(top.suit.symbol) to Free Cell to clear space."), 100))
                break
            }
        }

        let filtered = scored.filter { (hint, _) in
            guard let src = lastMoveSourceId, let tgt = lastMoveTargetId else { return true }
            return !(hint.sourcePileId == tgt && hint.targetPileId == src)
        }
        let candidates = filtered.isEmpty ? scored : filtered
        return candidates.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    private func scheduleHintClear() {
        let task = DispatchWorkItem { [weak self] in
            self?.activeHint = nil
            self?.hintQueue = []
            self?.hintQueueIndex = 0
        }
        hintClearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    public func clearHint() {
        hintClearTask?.cancel()
        activeHint = nil
        hintQueue = []
        hintQueueIndex = 0
        lastMoveSourceId = nil
        lastMoveTargetId = nil
    }
    
    public func runAutocomplete() {
        guard isAutocompleteAvailable && !isAutoplayRunning else { return }
        saveStateForUndo()
        // Autoplay moves cards without further cursor navigation, so a pending keyboard
        // selection could otherwise act on a pile autoplay has already changed.
        clearKeyboardCursor()
        isAutoplayRunning = true
        animateNextAutocompleteMove()
    }
    
    private func animateNextAutocompleteMove() {
        guard isAutoplayRunning else { return }
        
        if let nextMove = findNextFoundationMove() {
            moveCards([nextMove.card], from: nextMove.source, to: nextMove.target)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.animateNextAutocompleteMove()
            }
        } else {
            isAutoplayRunning = false
            checkWinState()
        }
    }
    
    public func findNextFoundationMove() -> (card: Card, source: Pile, target: Pile)? {
        // Free cells first
        for cell in state.freeCells {
            if let topCard = cell.topCard {
                for foundation in state.foundations {
                    if isValidMove(cards: [topCard], to: foundation) {
                        if isSafeFoundationMove(topCard, in: state.foundations) {
                            return (topCard, cell, foundation)
                        }
                    }
                }
            }
        }
        // Tableau second
        for column in state.tableau {
            if let topCard = column.topCard {
                for foundation in state.foundations {
                    if isValidMove(cards: [topCard], to: foundation) {
                        if isSafeFoundationMove(topCard, in: state.foundations) {
                            return (topCard, column, foundation)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // MARK: - Undo Implementation
    
    private func saveStateForUndo() {
        guard !isAutoplayRunning else { return }
        undoStack.push(state)
    }

    public func undoLastAction() {
        guard let previous = undoStack.pop() else { return }
        // The timer must keep running forward through an undo, not rewind to whatever it
        // read when the undone move's snapshot was saved.
        let currentTimerSeconds = state.timerSeconds
        let currentIsTimerActive = state.isTimerActive
        state = previous
        state.timerSeconds = currentTimerSeconds
        state.isTimerActive = currentIsTimerActive
        isAutoplayRunning = false
        isStuck = false
        clearHint()
        clearKeyboardCursor()
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }

    public func resetStatistics() {
        statistics = BeecellStatistics()
    }

    // MARK: - Keyboard Navigation
    public var activeCursor: KeyboardCursor?
    public var selectedCardsSource: String?
    
    // Internal coordinate tracking
    private var cursorColumn: Int = 0 // tableau column
    private var topRowColumn: Int = 0 // combined free cell + foundation column
    private var cursorRow: Int = 0 // 0 = Top (Cells/Foundations), 1 = Tableau

    public func enableKeyboardCursorIfNeeded() {
        if activeCursor == nil {
            activeCursor = KeyboardCursor(pileId: state.freeCells[0].id)
            topRowColumn = 0
            cursorRow = 0
        }
    }

    public func clearKeyboardCursor() {
        activeCursor = nil
        selectedCardsSource = nil
        // Reset coordinate trackers too — enableKeyboardCursorIfNeeded() only re-inits
        // topRowColumn/cursorRow, so a stale cursorColumn from a larger board (e.g.
        // 2-deck mode's 10 tableau columns) could otherwise survive into a smaller one
        // and index out of bounds.
        cursorColumn = 0
        topRowColumn = 0
        cursorRow = 0
    }

    public func moveCursorLeft() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            let maxCol = state.freeCells.count + state.foundations.count - 1
            var newCol = topRowColumn - 1
            if newCol < 0 { newCol = maxCol }
            topRowColumn = newCol
        } else {
            let maxCol = state.tableau.count - 1
            var newCol = cursorColumn - 1
            if newCol < 0 { newCol = maxCol }
            cursorColumn = newCol
        }
        updateCursorFromCoordinates()
    }

    public func moveCursorRight() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            let maxCol = state.freeCells.count + state.foundations.count - 1
            var newCol = topRowColumn + 1
            if newCol > maxCol { newCol = 0 }
            topRowColumn = newCol
        } else {
            let maxCol = state.tableau.count - 1
            var newCol = cursorColumn + 1
            if newCol > maxCol { newCol = 0 }
            cursorColumn = newCol
        }
        updateCursorFromCoordinates()
    }

    public func moveCursorUp() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 1 {
            cursorRow = 0
            updateCursorFromCoordinates()
        }
    }

    public func moveCursorDown() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            cursorRow = 1
            updateCursorFromCoordinates()
        }
    }

    private func updateCursorFromCoordinates() {
        if cursorRow == 0 {
            if topRowColumn < state.freeCells.count {
                activeCursor = KeyboardCursor(pileId: state.freeCells[topRowColumn].id)
            } else {
                activeCursor = KeyboardCursor(pileId: state.foundations[topRowColumn - state.freeCells.count].id)
            }
        } else {
            let pileId = state.tableau[cursorColumn].id
            activeCursor = KeyboardCursor(pileId: pileId)
        }
    }
    
    public func performSpaceAction() {
        enableKeyboardCursorIfNeeded()
        guard let cursor = activeCursor else { return }
        
        if let sourceId = selectedCardsSource {
            if sourceId == cursor.pileId {
                selectedCardsSource = nil
                return
            }
            
            // Find target pile
            let targetPile: Pile?
            if let cellIdx = state.freeCells.firstIndex(where: { $0.id == cursor.pileId }) { targetPile = state.freeCells[cellIdx] }
            else if let fIdx = state.foundations.firstIndex(where: { $0.id == cursor.pileId }) { targetPile = state.foundations[fIdx] }
            else if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { targetPile = state.tableau[tIdx] }
            else { targetPile = nil }
            
            // Find source pile
            let sourcePile: Pile?
            if let cellIdx = state.freeCells.firstIndex(where: { $0.id == sourceId }) { sourcePile = state.freeCells[cellIdx] }
            else if let fIdx = state.foundations.firstIndex(where: { $0.id == sourceId }) { sourcePile = state.foundations[fIdx] }
            else if let tIdx = state.tableau.firstIndex(where: { $0.id == sourceId }) { sourcePile = state.tableau[tIdx] }
            else { sourcePile = nil }
            
            guard let target = targetPile, let source = sourcePile else {
                selectedCardsSource = nil
                return
            }
            
            let cardsToMove: [Card]
            if source.type == .tableau {
                if let top = source.topCard {
                    var seq = [top]
                    if source.cards.count > 1 {
                        for i in stride(from: source.cards.count - 2, to: -1, by: -1) {
                            let card = source.cards[i]
                            let prev = seq.first!
                            if card.faceUp && card.rank == prev.rank + 1 && card.isRed != prev.isRed {
                                seq.insert(card, at: 0)
                            } else {
                                break
                            }
                        }
                    }
                    cardsToMove = seq
                } else {
                    cardsToMove = []
                }
            } else {
                cardsToMove = source.topCard != nil ? [source.topCard!] : []
            }
            
            if !cardsToMove.isEmpty && isValidMove(cards: cardsToMove, to: target) {
                moveCards(cardsToMove, from: source, to: target)
            }
            selectedCardsSource = nil
        } else {
            let sourcePile: Pile?
            if let cellIdx = state.freeCells.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.freeCells[cellIdx] }
            else if let fIdx = state.foundations.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.foundations[fIdx] }
            else if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.tableau[tIdx] }
            else { sourcePile = nil }
            
            guard let source = sourcePile, !source.isEmpty else { return }
            selectedCardsSource = cursor.pileId
        }
    }
    
    public func autoMoveFocusedCardToFoundations() {
        enableKeyboardCursorIfNeeded()
        guard let cursor = activeCursor else { return }
        
        let sourcePile: Pile?
        if let cellIdx = state.freeCells.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.freeCells[cellIdx] }
        else if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.tableau[tIdx] }
        else { sourcePile = nil }
        
        guard let source = sourcePile, let topCard = source.topCard else { return }
        
        for foundation in state.foundations {
            if isValidMove(cards: [topCard], to: foundation) {
                moveCards([topCard], from: source, to: foundation)
                break
            }
        }
    }
    
    public func autoMoveFocusedCardToFreeCell() {
        enableKeyboardCursorIfNeeded()
        guard let cursor = activeCursor else { return }
        
        let sourcePile: Pile?
        if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.tableau[tIdx] }
        else { sourcePile = nil }
        
        guard let source = sourcePile, let topCard = source.topCard else { return }
        
        for cell in state.freeCells {
            if cell.isEmpty && isValidMove(cards: [topCard], to: cell) {
                moveCards([topCard], from: source, to: cell)
                break
            }
        }
    }
}
