import Foundation
import Observation
import AppKit

@Observable
public final class SpiderViewModel {
    public var state: SpiderState
    private let gameTimer = GameTimer()

    // Bumped on every fresh deal (startNewGame/restartCurrentGame) — lets the view
    // recompute its fit-to-window scale against the newly-dealt tableau's real column
    // depths, since tableau.count never changes for Spider (always 10 columns) and can't
    // serve as that signal the way it does for Klondike/Beecell.
    public private(set) var gameGeneration: Int = 0
    
    public var options: SpiderOptions {
        didSet {
            saveOptions()
            UISound.isEnabled = options.isSoundEnabled
            handleOptionsChanged(oldValue: oldValue)
        }
    }

    public var statistics: SpiderStatistics {
        didSet {
            saveStatistics()
        }
    }
    
    public var currentModeStats: SpiderModeStats {
        statistics.statsBySuits[options.suitCount] ?? SpiderModeStats()
    }
    
    public var highScore: Int {
        get { currentModeStats.highScore }
        set {
            var stats = statistics
            var modeStats = stats.statsBySuits[options.suitCount] ?? SpiderModeStats()
            modeStats.highScore = newValue
            stats.statsBySuits[options.suitCount] = modeStats
            statistics = stats
        }
    }
    
    public var gamesWon: Int {
        get { currentModeStats.gamesWon }
        set {
            var stats = statistics
            var modeStats = stats.statsBySuits[options.suitCount] ?? SpiderModeStats()
            modeStats.gamesWon = newValue
            stats.statsBySuits[options.suitCount] = modeStats
            statistics = stats
        }
    }
    
    public var gamesPlayed: Int {
        get { currentModeStats.gamesPlayed }
        set {
            var stats = statistics
            var modeStats = stats.statsBySuits[options.suitCount] ?? SpiderModeStats()
            modeStats.gamesPlayed = newValue
            stats.statsBySuits[options.suitCount] = modeStats
            statistics = stats
        }
    }
    
    public var highScoreString: String {
        return String(highScore)
    }
    
    public var scoreString: String {
        return String(state.score)
    }
    
    // Auto-complete status
    public var isAutocompleteAvailable: Bool = false
    public var isAutoplayRunning: Bool = false

    // Stuck detection
    public var isStuck: Bool = false
    
    // Undo stack
    private var undoStack = UndoStack<SpiderState>()
    
    // Initial state for game replay
    private var initialState: SpiderState?
    
    public var canUndo: Bool {
        !undoStack.isEmpty && !state.hasWon
    }
    
    // Board scale — no longer manual; SpiderView.recomputeScale() continuously derives
    // this from the window's current size. Not persisted, purely a function of window size.
    public var zoomScale: CGFloat = 1.0

    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: "spider_options")
        }
    }
    
    private func handleOptionsChanged(oldValue: SpiderOptions) {
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

        if options.suitCount != oldValue.suitCount {
            startNewGame()
        }
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: "spider_statistics")
        }
    }
    
    public func playSound(named name: String) {
        UISound.play(named: name, enabled: options.isSoundEnabled)
    }
    
    public func recordWin(timeInSeconds: Int) {
        var stats = statistics
        var modeStats = stats.statsBySuits[options.suitCount] ?? SpiderModeStats()
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
        stats.statsBySuits[options.suitCount] = modeStats
        statistics = stats
    }
    
    public init(state: SpiderState = SpiderState(stock: Pile(id: "stock", type: .stock), foundations: [], tableau: [], score: 500, movesCount: 0, timerSeconds: 0, isTimerActive: false, hasWon: false)) {
        self.state = state
        
        // Load options
        if let data = UserDefaults.standard.data(forKey: "spider_options"),
           let decoded = try? JSONDecoder().decode(SpiderOptions.self, from: data) {
            self.options = decoded
        } else {
            self.options = SpiderOptions()
        }
        
        // Load statistics
        if let data = UserDefaults.standard.data(forKey: "spider_statistics"),
           let decoded = try? JSONDecoder().decode(SpiderStatistics.self, from: data) {
            self.statistics = decoded
        } else {
            self.statistics = SpiderStatistics()
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
        
        if state.movesCount > 0 && !state.hasWon {
            var stats = statistics
            var modeStats = stats.statsBySuits[options.suitCount] ?? SpiderModeStats()
            modeStats.currentStreak = 0
            stats.statsBySuits[options.suitCount] = modeStats
            statistics = stats
        }
        
        undoStack.removeAll()
        gamesPlayed += 1
        playSound(named: "shuffle")
        
        // 1. Generate 104 cards depending on suit count
        var deck: [Card] = []
        let suits: [Card.Suit]
        switch options.suitCount {
        case 1:
            suits = [.spades] // All Spades (8 sets of A-K)
        case 2:
            suits = [.spades, .hearts] // 4 sets of Spades, 4 sets of Hearts
        default:
            suits = [.spades, .hearts, .diamonds, .clubs] // 2 sets of each
        }
        
        let totalSets = 8
        let setsPerSuit = totalSets / suits.count
        
        for suit in suits {
            for _ in 0..<setsPerSuit {
                for rank in 1...13 {
                    deck.append(Card(suit: suit, rank: rank, faceUp: false))
                }
            }
        }
        
        // 2. Shuffle deck
        deck.shuffle()
        
        // 3. Deal Tableau (10 columns)
        // First 4 columns: 6 cards each (5 down, 1 up)
        // Next 6 columns: 5 cards each (4 down, 1 up)
        var tableau: [Pile] = []
        var deckIndex = 0
        
        for i in 0..<10 {
            let cardCount = i < 4 ? 6 : 5
            var cards: [Card] = []
            for j in 0..<cardCount {
                var card = deck[deckIndex]
                deckIndex += 1
                if j == cardCount - 1 {
                    card.faceUp = true
                }
                cards.append(card)
            }
            tableau.append(Pile(id: "tableau_\(i)", type: .tableau, cards: cards))
        }
        
        // 4. Place remainder in Stock (50 cards)
        var stockCards: [Card] = []
        while deckIndex < deck.count {
            stockCards.append(deck[deckIndex])
            deckIndex += 1
        }
        let stock = Pile(id: "stock", type: .stock, cards: stockCards)
        
        // 5. Initialize Piles
        let foundations = (0..<8).map { i in
            Pile(id: "foundation_\(i)", type: .foundation, cards: [])
        }
        
        // 6. Set State
        state = SpiderState(
            stock: stock,
            foundations: foundations,
            tableau: tableau,
            score: 500,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            hasWon: false
        )
        
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
        initialState = state
        clearKeyboardCursor()
        gameGeneration += 1
    }

    public func restartCurrentGame() {
        guard let initial = initialState else { return }
        stopTimer()
        undoStack.removeAll()
        state = initial
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
        clearKeyboardCursor()
        gameGeneration += 1
    }
    
    // MARK: - Core Interactions
    
    public var hasEmptyTableauColumn: Bool {
        state.tableau.contains(where: { $0.isEmpty })
    }
    
    public func drawFromStock() {
        guard !state.stock.isEmpty else { return }
        
        // Standard Spider Solitaire rule: Cannot deal from stock if any column is empty
        if hasEmptyTableauColumn {
            return
        }
        
        saveStateForUndo()
        startTimerIfNeeded()
        playSound(named: "shuffle")
        
        // Deal 1 card face up to each column
        for i in 0..<10 {
            if var card = state.stock.cards.popLast() {
                card.faceUp = true
                state.tableau[i].cards.append(card)
            }
        }
        
        state.score = max(0, state.score - 1)
        state.movesCount += 1

        checkCompletedRuns()
        checkStuckState()
        checkAutocompleteState()
    }

    // MARK: - Move Validation & Execution
    
    public func isValidDragSequence(_ cards: [Card]) -> Bool {
        guard !cards.isEmpty else { return false }
        
        // All cards must be face up
        guard cards.allSatisfy({ $0.faceUp }) else { return false }
        
        // All cards must be of the same suit, and in descending numerical order
        let suit = cards[0].suit
        for i in 1..<cards.count {
            if cards[i].suit != suit || cards[i].rank != cards[i-1].rank - 1 {
                return false
            }
        }
        return true
    }
    
    public func isValidMove(cards: [Card], to targetPile: Pile) -> Bool {
        guard let firstCard = cards.first else { return false }
        guard targetPile.type == .tableau else { return false }
        
        if targetPile.isEmpty {
            return true // Empty column accepts any card/sequence
        } else {
            guard let topCard = targetPile.topCard else { return false }
            return firstCard.rank == topCard.rank - 1 // Must be 1 rank lower, suit doesn't matter
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
        
        // Remove from source
        if let srcIdx = state.tableau.firstIndex(where: { $0.id == sourcePile.id }) {
            state.tableau[srcIdx].cards.removeAll { cardIDs.contains($0.id) }
            
            // Flip the next top card face up if it is face down
            if !state.tableau[srcIdx].cards.isEmpty && !state.tableau[srcIdx].cards.last!.faceUp {
                state.tableau[srcIdx].cards[state.tableau[srcIdx].cards.count - 1].faceUp = true
            }
        }
        
        // Add to target
        if let tgtIdx = state.tableau.firstIndex(where: { $0.id == targetPile.id }) {
            state.tableau[tgtIdx].cards.append(contentsOf: cards)
        }
        
        state.score = max(0, state.score - 1)
        state.movesCount += 1

        checkCompletedRuns()
        checkStuckState()
        checkAutocompleteState()
    }

    public func doubleClickMove(card: Card, from sourcePile: Pile) {
        // Match the drag-start convention: any direct mouse move relinquishes keyboard
        // focus/selection so a stale cached index can't outlive the pile it pointed
        // into if this move shrinks it.
        clearKeyboardCursor()

        // Find if this card is part of a valid sequence up to the top of the pile
        guard let colIdx = state.tableau.firstIndex(where: { $0.id == sourcePile.id }) else { return }
        guard let cardIdx = state.tableau[colIdx].cards.firstIndex(where: { $0.id == card.id }) else { return }
        
        let dragStack = Array(state.tableau[colIdx].cards[cardIdx..<state.tableau[colIdx].cards.count])
        guard isValidDragSequence(dragStack) else { return }
        
        // Check if there is any empty tableau column or valid target column
        // Standard rule: double-click moves it to the first valid tableau target (preferring non-empty columns first to build)
        var targetCol: Pile? = nil
        
        // Look for matching suit build first
        for col in state.tableau {
            if col.id != sourcePile.id && !col.isEmpty {
                if let topCard = col.topCard, topCard.rank == card.rank + 1 && topCard.suit == card.suit {
                    targetCol = col
                    break
                }
            }
        }
        
        // Look for any rank-only build next
        if targetCol == nil {
            for col in state.tableau {
                if col.id != sourcePile.id && !col.isEmpty {
                    if let topCard = col.topCard, topCard.rank == card.rank + 1 {
                        targetCol = col
                        break
                    }
                }
            }
        }
        
        // Look for an empty column last
        if targetCol == nil {
            for col in state.tableau {
                if col.id != sourcePile.id && col.isEmpty {
                    targetCol = col
                    break
                }
            }
        }
        
        if let target = targetCol {
            moveCards(dragStack, from: sourcePile, to: target)
        }
    }
    
    // MARK: - Completed Runs Verification
    
    private func checkCompletedRuns() {
        var completedRunFound = false
        
        for i in 0..<10 {
            let cards = state.tableau[i].cards
            guard cards.count >= 13 else { continue }
            
            // Check the last 13 cards in the pile
            let subrange = Array(cards.suffix(13))
            
            // Must start with K (13) down to A (1)
            guard subrange[0].rank == 13 else { continue }
            
            var isValidRun = true
            let suit = subrange[0].suit
            for j in 0..<13 {
                if subrange[j].rank != 13 - j || subrange[j].suit != suit || !subrange[j].faceUp {
                    isValidRun = false
                    break
                }
            }
            
            if isValidRun {
                // Only remove from tableau if a foundation slot is available
                guard let fdnIdx = state.foundations.firstIndex(where: { $0.isEmpty }) else { continue }
                
                // Completed run detected!
                completedRunFound = true

                let completedCardIDs = Set(subrange.map { $0.id })
                state.tableau[i].cards.removeAll { completedCardIDs.contains($0.id) }

                // Flip top card if face down
                if !state.tableau[i].cards.isEmpty && !state.tableau[i].cards.last!.faceUp {
                    state.tableau[i].cards[state.tableau[i].cards.count - 1].faceUp = true
                }

                state.foundations[fdnIdx].cards = subrange
                
                state.score += 100
                break // check one run per cycle to be safe, loops will trigger next clears on next moves anyway
            }
        }
        
        if completedRunFound {
            playSound(named: "victory")
            checkWinState()
            checkCompletedRuns() // recursively clear other complete runs if any
        }
    }
    
    public func checkWinState() {
        // Game is won when all 8 foundations are completed (8 * 13 = 104 cards)
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        if WinDetection.hasWon(foundationCardCount: totalFoundationCards, totalCards: 104, alreadyWon: state.hasWon) {
            state.hasWon = true
            stopTimer()
            recordWin(timeInSeconds: state.timerSeconds)
            playSound(named: "victory")
            
            if state.score > highScore {
                highScore = state.score
            }
        }
    }
    
    // MARK: - Timer Handling

    // `isTimed` has no UI control anymore (the old "Timed Game" toggle was replaced by
    // No Stress Mode) so it's intentionally not consulted here — honoring a persisted
    // `false` from before that change would permanently strand upgrading users with no
    // way to turn the timer back on.
    private func effectiveTimed(_ o: SpiderOptions) -> Bool {
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
        checkStuckState()
        checkAutocompleteState()
    }
    
    // MARK: - Stuck Detection

    private func hasValidMoves() -> Bool {
        if !state.stock.isEmpty && !hasEmptyTableauColumn { return true }

        let hasEmpty = state.tableau.contains { $0.isEmpty }

        for colIdx in 0..<state.tableau.count {
            let col = state.tableau[colIdx]
            guard !col.isEmpty else { continue }

            // Find start of the longest same-suit descending run (movable as a group)
            var seqStart = col.cards.count - 1
            while seqStart > 0 {
                let upper = col.cards[seqStart - 1]
                let lower = col.cards[seqStart]
                if upper.faceUp && upper.rank == lower.rank + 1 && upper.suit == lower.suit {
                    seqStart -= 1
                } else { break }
            }

            // Test every sub-sequence from seqStart up to the top card
            for start in seqStart..<col.cards.count {
                let seq = Array(col.cards[start...])
                // Any face-up card can move to an empty column
                if hasEmpty && seq.first?.faceUp == true { return true }
                for tgtIdx in 0..<state.tableau.count where tgtIdx != colIdx {
                    let target = state.tableau[tgtIdx]
                    if isValidMove(cards: seq, to: target) { return true }
                }
            }
        }
        return false
    }

    public func checkStuckState() {
        guard !state.hasWon && !isAutocompleteAvailable else { isStuck = false; return }
        isStuck = !hasValidMoves()
    }

    // MARK: - Autocomplete

    public func checkAutocompleteState() {
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        guard totalFoundationCards < 104, state.stock.isEmpty else {
            isAutocompleteAvailable = false
            return
        }

        // Autocomplete is safe and available whenever there is at least one safe
        // move found by findNextAutocompleteMove.
        isAutocompleteAvailable = !state.hasWon && findNextAutocompleteMove() != nil
    }

    public func runAutocomplete() {
        guard isAutocompleteAvailable && !isAutoplayRunning else { return }
        saveStateForUndo()
        // Autoplay moves cards without further cursor navigation, so a cached keyboard
        // cursor/selection could otherwise go stale and crash on the next Space/arrow.
        clearKeyboardCursor()
        isAutoplayRunning = true
        animateNextAutocompleteMove()
    }

    private func animateNextAutocompleteMove() {
        guard isAutoplayRunning else { return }

        if let nextMove = findNextAutocompleteMove() {
            moveCards(nextMove.cards, from: nextMove.source, to: nextMove.target)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.animateNextAutocompleteMove()
            }
        } else {
            isAutoplayRunning = false
            checkWinState()
        }
    }

    private func findNextAutocompleteMove() -> (cards: [Card], source: Pile, target: Pile)? {
        for source in state.tableau where !source.cards.isEmpty {
            guard isValidDragSequence(source.cards), let firstCard = source.cards.first else { continue }
            for target in state.tableau where target.id != source.id {
                if let topCard = target.topCard, topCard.suit == firstCard.suit, topCard.rank == firstCard.rank + 1 {
                    return (source.cards, source, target)
                }
            }
        }
        return nil
    }

    // MARK: - Hints

    public struct SpiderHintMove: Equatable {
        public let card: Card
        public let sourcePileId: String
        public let targetPileId: String
        public let description: String
    }

    public var activeHint: SpiderHintMove? = nil
    private var hintClearTask: DispatchWorkItem?
    private var hintQueue: [SpiderHintMove] = []
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
            activeHint = SpiderHintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                sourcePileId: "", targetPileId: "", description: "No moves available. Replay or deal a new game!")
            scheduleHintClear()
            return
        }

        activeHint = labeled(hintQueue[0], index: 0, total: hintQueue.count)
        scheduleHintClear()
    }

    private func labeled(_ hint: SpiderHintMove, index: Int, total: Int) -> SpiderHintMove {
        let prefix = total > 1 ? "[\(index + 1)/\(total)] " : ""
        return SpiderHintMove(card: hint.card, sourcePileId: hint.sourcePileId,
            targetPileId: hint.targetPileId, description: prefix + hint.description)
    }

    public var hasHintsAvailable: Bool { !collectHints().isEmpty }

    public var debugBannerRequest: DebugBannerKind? = nil

    private func collectHints() -> [SpiderHintMove] {
        var scored: [(SpiderHintMove, Int)] = []

        for colIdx in 0..<state.tableau.count {
            let col = state.tableau[colIdx]
            guard !col.isEmpty else { continue }

            // The true face-down/face-up boundary — only a drag that starts exactly here
            // reveals a hidden card when it moves away. A drag that starts further up
            // (even if it's a legal same-suit run) just re-exposes cards that are already
            // face-up, so it reveals nothing, regardless of how many cards sit below it.
            let firstFaceUpIdx = col.cards.firstIndex(where: { $0.faceUp }) ?? col.cards.count

            // The deepest legal drag-start position (longest same-suit descending run
            // anchored at the bottom of the column) — validity only ever breaks once as
            // you grow the stack upward, so this can be found once per column instead of
            // per target.
            var minValidK = col.cards.count - 1
            while minValidK > 0 && isValidDragSequence(Array(col.cards[(minValidK - 1)...])) {
                minValidK -= 1
            }

            for targetIdx in 0..<state.tableau.count {
                let targetCol = state.tableau[targetIdx]
                guard targetCol.id != col.id else { continue }

                // Try every legal length longest-first and stop at the first one that
                // scores a hint for this target — otherwise a long run with an empty
                // column available (any length is legal onto an empty target) would
                // generate one near-duplicate entry per length.
                for k in (minValidK...(col.cards.count - 1)).reversed() {
                    let dragStack = Array(col.cards[k...])
                    let faceDownBelow = k == firstFaceUpIdx ? firstFaceUpIdx : 0
                    let freesColumn = k == 0

                    if targetCol.isEmpty {
                        // Moving to empty column: only worthwhile if it exposes a face-down card
                        if faceDownBelow > 0 {
                            let label = faceDownBelow == 1 ? "Reveal 1 face-down card." : "Reveal \(faceDownBelow) face-down cards."
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to empty column — \(label)"),
                                350 + faceDownBelow * 50))
                            break
                        } else if !freesColumn {
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) sequence to empty column."), 200))
                            break
                        }
                    } else if let topCard = targetCol.topCard, topCard.rank == dragStack.first!.rank + 1 {
                        let sameSuit = topCard.suit == dragStack.first!.suit
                        let faceDownBonus = faceDownBelow * 100
                        if sameSuit {
                            // Best: extends a same-suit run
                            let score = faceDownBelow > 0 ? 1000 + faceDownBonus : 900
                            let label = faceDownBelow > 0 ? " — Reveal \(faceDownBelow) face-down card\(faceDownBelow > 1 ? "s" : "")." : "."
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) onto \(topCard.rankString)\(topCard.suit.symbol)\(label)"), score))
                        } else {
                            // Cross-suit build
                            let score = faceDownBelow > 0 ? 600 + faceDownBonus : 400
                            let label = faceDownBelow > 0 ? " — Reveal \(faceDownBelow) face-down card\(faceDownBelow > 1 ? "s" : "")." : "."
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to \(topCard.rankString)\(topCard.suit.symbol)\(label)"), score))
                        }
                        break
                    }
                }
            }
        }

        // Draw from stock
        if !state.stock.isEmpty {
            if hasEmptyTableauColumn {
                scored.append((SpiderHintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                    sourcePileId: "", targetPileId: "", description: "Fill all empty columns before dealing cards."), 25))
            } else {
                scored.append((SpiderHintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                    sourcePileId: state.stock.id, targetPileId: "", description: "Deal cards from the Stock pile."), 50))
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
    
    public func resetStatistics() {
        gamesWon = 0
        gamesPlayed = 0
    }

    // MARK: - Keyboard Navigation
    public var activeCursor: KeyboardCursor?
    public var selectedCardsSource: String?
    public var selectedCardsIndex: Int?
    
    // Internal coordinate tracking
    private var cursorColumn: Int = 0
    private var cursorRow: Int = 0 // 0 = Stock, 1 = Tableau
    
    public func enableKeyboardCursorIfNeeded() {
        if activeCursor == nil {
            activeCursor = KeyboardCursor(pileId: state.stock.id)
            cursorColumn = 0
            cursorRow = 0
        }
    }
    
    public func clearKeyboardCursor() {
        activeCursor = nil
        selectedCardsSource = nil
        selectedCardsIndex = nil
        cursorColumn = 0
        cursorRow = 0
    }
    
    public func moveCursorLeft() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 1 {
            var newCol = cursorColumn - 1
            if newCol < 0 { newCol = 9 }
            cursorColumn = newCol
            updateCursorFromCoordinates()
        }
    }
    
    public func moveCursorRight() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 1 {
            var newCol = cursorColumn + 1
            if newCol > 9 { newCol = 0 }
            cursorColumn = newCol
            updateCursorFromCoordinates()
        }
    }
    
    public func moveCursorUp() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 1 {
            if let active = activeCursor,
               let colIdx = state.tableau.firstIndex(where: { $0.id == active.pileId }),
               let cardIdx = active.cardIndex,
               cardIdx > 0 {
                let prevIdx = cardIdx - 1
                if state.tableau[colIdx].cards[prevIdx].faceUp {
                    activeCursor?.cardIndex = prevIdx
                    return
                }
            }
            cursorRow = 0
            updateCursorFromCoordinates()
        }
    }
    
    public func moveCursorDown() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            cursorRow = 1
            updateCursorFromCoordinates()
        } else {
            if let active = activeCursor,
               let colIdx = state.tableau.firstIndex(where: { $0.id == active.pileId }),
               let cardIdx = active.cardIndex {
                let col = state.tableau[colIdx]
                if cardIdx + 1 < col.cards.count {
                    activeCursor?.cardIndex = cardIdx + 1
                }
            }
        }
    }
    
    private func updateCursorFromCoordinates() {
        if cursorRow == 0 {
            activeCursor = KeyboardCursor(pileId: state.stock.id)
        } else {
            let pileId = state.tableau[cursorColumn].id
            let col = state.tableau[cursorColumn]
            if col.isEmpty {
                activeCursor = KeyboardCursor(pileId: pileId, cardIndex: nil)
            } else {
                activeCursor = KeyboardCursor(pileId: pileId, cardIndex: col.cards.count - 1)
            }
        }
    }
    
    public func performSpaceAction() {
        enableKeyboardCursorIfNeeded()
        guard let cursor = activeCursor else { return }
        
        if let sourceId = selectedCardsSource {
            if sourceId == cursor.pileId {
                selectedCardsSource = nil
                selectedCardsIndex = nil
                return
            }
            
            let targetPile = state.tableau.first(where: { $0.id == cursor.pileId })
            let sourcePile = state.tableau.first(where: { $0.id == sourceId })
            
            guard let target = targetPile, let source = sourcePile else {
                selectedCardsSource = nil
                selectedCardsIndex = nil
                return
            }
            
            let cardsToMove: [Card]
            if let selIdx = selectedCardsIndex {
                cardsToMove = Array(source.cards[selIdx..<source.cards.count])
            } else {
                cardsToMove = source.topCard != nil ? [source.topCard!] : []
            }
            
            if !cardsToMove.isEmpty && isValidDragSequence(cardsToMove) && isValidMove(cards: cardsToMove, to: target) {
                moveCards(cardsToMove, from: source, to: target)
                cursorRow = 1
                updateCursorFromCoordinates()
            }
            selectedCardsSource = nil
            selectedCardsIndex = nil
        } else {
            if cursor.pileId == state.stock.id {
                drawFromStock()
            } else {
                let sourcePile = state.tableau.first(where: { $0.id == cursor.pileId })
                guard let source = sourcePile, !source.isEmpty else { return }
                
                if let cardIdx = cursor.cardIndex {
                    let sequence = Array(source.cards[cardIdx..<source.cards.count])
                    if isValidDragSequence(sequence) {
                        selectedCardsSource = cursor.pileId
                        selectedCardsIndex = cardIdx
                    }
                }
            }
        }
    }
}
