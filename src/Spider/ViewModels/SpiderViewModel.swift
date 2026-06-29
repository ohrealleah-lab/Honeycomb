import Foundation
import Observation
import AppKit

@Observable
public final class SpiderViewModel {
    public var state: SpiderState
    public var timer: Timer?
    
    public var options: SpiderOptions {
        didSet {
            saveOptions()
            handleOptionsChanged(oldValue: oldValue)
            if options.feltColor != oldValue.feltColor || options.customFeltColorRevision != oldValue.customFeltColorRevision {
                UserDefaults.standard.set(options.feltColor.rawValue, forKey: "global_felt_color")
                NotificationCenter.default.post(name: .feltColorDidChange, object: self, userInfo: [
                    "feltColor": options.feltColor,
                    "customFeltColorRevision": options.customFeltColorRevision
                ])
            }
            if options.cardBackTheme != oldValue.cardBackTheme {
                UserDefaults.standard.set(options.cardBackTheme, forKey: "cardBackTheme")
                NotificationCenter.default.post(name: .cardBackThemeDidChange, object: self, userInfo: ["cardBackTheme": options.cardBackTheme])
            }
            if options.showFeltVignette != oldValue.showFeltVignette {
                UserDefaults.standard.set(options.showFeltVignette, forKey: "showFeltVignette")
                NotificationCenter.default.post(name: .feltVignetteDidChange, object: self, userInfo: ["showFeltVignette": options.showFeltVignette])
            }
            if options.customCardColors != oldValue.customCardColors {
                if let encoded = try? JSONEncoder().encode(options.customCardColors) {
                    UserDefaults.standard.set(encoded, forKey: "customCardColors")
                }
                NotificationCenter.default.post(name: .customCardColorsDidChange, object: self, userInfo: ["customCardColors": options.customCardColors])
            }
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
    private var undoStack: [SpiderState] = []
    
    // Initial state for game replay
    private var initialState: SpiderState?
    
    public var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    public var defaultZoomScale: CGFloat = 1.0
    
    // Zoom implementation
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            UserDefaults.standard.set(Double(zoomScale), forKey: "spider_zoomScale")
        }
    }
    
    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: "spider_options")
        }
        UserDefaults.standard.set(options.cardBackTheme, forKey: "cardBackTheme")
    }
    
    private func handleOptionsChanged(oldValue: SpiderOptions) {
        if options.isTimed != oldValue.isTimed {
            if options.isTimed {
                if state.movesCount > 0 && !state.hasWon {
                    startTimerIfNeeded()
                }
            } else {
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
        guard options.isSoundEnabled else { return }
        
        if let soundURL = Bundle.main.url(forResource: name, withExtension: "aiff") {
            if let sound = NSSound(contentsOf: soundURL, byReference: true) {
                sound.play()
                return
            }
        }
        
        let systemName: String
        switch name {
        case "shuffle": systemName = "Blow"
        case "snap": systemName = "Tink"
        case "victory": systemName = "Hero"
        default: systemName = name
        }
        
        if let sound = NSSound(named: NSSound.Name(systemName)) {
            sound.play()
        }
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
           var decoded = try? JSONDecoder().decode(SpiderOptions.self, from: data) {
            if let legacyTheme = UserDefaults.standard.string(forKey: "cardBackTheme") {
                decoded.cardBackTheme = legacyTheme
            }
            if let globalFeltStr = UserDefaults.standard.string(forKey: "global_felt_color"),
               let globalFelt = FeltColorTheme(rawValue: globalFeltStr) {
                decoded.feltColor = globalFelt
            }
            if UserDefaults.standard.object(forKey: "showFeltVignette") != nil {
                decoded.showFeltVignette = UserDefaults.standard.bool(forKey: "showFeltVignette")
            }
            if let dataColors = UserDefaults.standard.data(forKey: "customCardColors"),
               let colors = try? JSONDecoder().decode(CustomCardColorGroup.self, from: dataColors) {
                decoded.customCardColors = colors
            }
            self.options = decoded
        } else {
            let legacyTheme = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Vulpera"
            let globalFeltStr = UserDefaults.standard.string(forKey: "global_felt_color") ?? FeltColorTheme.feltGreen.rawValue
            let globalFelt = FeltColorTheme(rawValue: globalFeltStr) ?? .feltGreen
            var opts = SpiderOptions(feltColor: globalFelt, cardBackTheme: legacyTheme)
            if UserDefaults.standard.object(forKey: "showFeltVignette") != nil {
                opts.showFeltVignette = UserDefaults.standard.bool(forKey: "showFeltVignette")
            }
            if let dataColors = UserDefaults.standard.data(forKey: "customCardColors"),
               let colors = try? JSONDecoder().decode(CustomCardColorGroup.self, from: dataColors) {
                opts.customCardColors = colors
            }
            self.options = opts
        }
        
        // Load statistics
        if let data = UserDefaults.standard.data(forKey: "spider_statistics"),
           let decoded = try? JSONDecoder().decode(SpiderStatistics.self, from: data) {
            self.statistics = decoded
        } else {
            self.statistics = SpiderStatistics()
        }
        
        // Load default zoom setting
        if let savedDefault = UserDefaults.standard.value(forKey: "spider_defaultZoomScale") as? Double {
            self.defaultZoomScale = CGFloat(savedDefault)
        } else {
            self.defaultZoomScale = 1.0
        }
        
        // Load saved zoom setting
        if let savedZoom = UserDefaults.standard.value(forKey: "spider_zoomScale") as? Double {
            self.zoomScale = CGFloat(savedZoom)
        } else {
            self.zoomScale = self.defaultZoomScale
        }
        
        // Register for global preferences notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleFeltColorNotification), name: .feltColorDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCardBackThemeNotification), name: .cardBackThemeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCustomCardColorsNotification), name: .customCardColorsDidChange, object: nil)
        
        startNewGame()
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleFeltColorNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let theme = notification.userInfo?["feltColor"] as? FeltColorTheme else { return }
        let rev = notification.userInfo?["customFeltColorRevision"] as? Int ?? 0
        if self.options.feltColor != theme || self.options.customFeltColorRevision != rev {
            var newOpts = self.options
            newOpts.feltColor = theme
            newOpts.customFeltColorRevision = rev
            self.options = newOpts
        }
    }
    
    @objc private func handleCardBackThemeNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let theme = notification.userInfo?["cardBackTheme"] as? String else { return }
        if self.options.cardBackTheme != theme {
            self.options.cardBackTheme = theme
        }
    }
    
    @objc private func handleCustomCardColorsNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let colors = notification.userInfo?["customCardColors"] as? CustomCardColorGroup else { return }
        if self.options.customCardColors != colors {
            self.options.customCardColors = colors
        }
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
    }

    public func restartCurrentGame() {
        guard let initial = initialState else { return }
        stopTimer()
        undoStack.removeAll()
        state = initial
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
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
    }

    public func doubleClickMove(card: Card, from sourcePile: Pile) {
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
                // Completed run detected!
                completedRunFound = true
                
                // Only remove from tableau if a foundation slot is available
                guard let fdnIdx = state.foundations.firstIndex(where: { $0.isEmpty }) else { continue }

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
        if totalFoundationCards == 104 && !state.hasWon {
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
    
    public func startTimerIfNeeded() {
        guard options.isTimed else { return }
        guard !state.isTimerActive else { return }
        state.isTimerActive = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.state.timerSeconds += 1
        }
    }
    
    public func stopTimer() {
        timer?.invalidate()
        timer = nil
        state.isTimerActive = false
    }
    
    // MARK: - Undo Implementation
    
    private func saveStateForUndo() {
        guard !isAutoplayRunning else { return }
        undoStack.append(state)
        if undoStack.count > 100 {
            undoStack.removeFirst()
        }
    }
    
    public func undoLastAction() {
        guard !undoStack.isEmpty else { return }
        state = undoStack.removeLast()
        isAutoplayRunning = false
        isStuck = false
        clearHint()
        checkWinState()
        checkStuckState()
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
        guard !state.hasWon else { isStuck = false; return }
        isStuck = !hasValidMoves()
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

    private func collectHints() -> [SpiderHintMove] {
        var scored: [(SpiderHintMove, Int)] = []

        for colIdx in 0..<state.tableau.count {
            let col = state.tableau[colIdx]
            guard !col.isEmpty else { continue }

            for k in (0..<col.cards.count).reversed() {
                let dragStack = Array(col.cards[k...])
                guard isValidDragSequence(dragStack) else { break }

                let faceDownBelow = k  // cards below drag start that are face-down
                let freesColumn = k == 0  // moving all cards out of this column

                for targetIdx in 0..<state.tableau.count {
                    let targetCol = state.tableau[targetIdx]
                    guard targetCol.id != col.id else { continue }

                    if targetCol.isEmpty {
                        // Moving to empty column: only worthwhile if it exposes a face-down card
                        if faceDownBelow > 0 {
                            let label = faceDownBelow == 1 ? "Reveal 1 face-down card." : "Reveal \(faceDownBelow) face-down cards."
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to empty column — \(label)"),
                                350 + faceDownBelow * 50))
                        } else if !freesColumn {
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) sequence to empty column."), 200))
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: task)
    }

    public func clearHint() {
        hintClearTask?.cancel()
        activeHint = nil
        hintQueue = []
        hintQueueIndex = 0
        lastMoveSourceId = nil
        lastMoveTargetId = nil
    }
    
    // MARK: - Zoom Controls
    
    public func zoomIn() {
        zoomScale = min(2.0, zoomScale + 0.1)
    }
    
    public func zoomOut() {
        zoomScale = max(0.5, zoomScale - 0.1)
    }
    
    public func resetZoom() {
        zoomScale = defaultZoomScale
    }
    
    public func makeCurrentZoomDefault() {
        defaultZoomScale = zoomScale
        UserDefaults.standard.set(Double(defaultZoomScale), forKey: "spider_defaultZoomScale")
    }
    
    public func resetStatistics() {
        gamesWon = 0
        gamesPlayed = 0
    }
}
