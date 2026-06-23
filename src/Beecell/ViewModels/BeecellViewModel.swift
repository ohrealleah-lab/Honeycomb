import Foundation
import Observation
import AppKit

@Observable
public final class BeecellViewModel {
    public var state: BeecellState
    public var timer: Timer?
    
    public var options: BeecellOptions {
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
    
    // Undo stack
    private var undoStack: [BeecellState] = []
    
    // Initial state for game replay
    private var initialState: BeecellState?
    
    public var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    public var currentModeKey: String {
        let mode = options.isVegasScoring ? "vegas" : "standard"
        let deck = options.deckCount == 1 ? "1deck" : "2deck"
        return "\(mode)_\(deck)"
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
    
    public var highScoreString: String {
        if options.isVegasScoring {
            let dollars = Double(highScore) / 100.0
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
        } else {
            return String(highScore)
        }
    }
    
    public var scoreString: String {
        if options.isVegasScoring {
            let dollars = Double(state.score) / 100.0
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "$"
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
        } else {
            return String(state.score)
        }
    }
    
    public var cardBackTheme: String {
        get { options.cardBackTheme }
        set {
            var newOpts = options
            newOpts.cardBackTheme = newValue
            options = newOpts
        }
    }
    
    // Zoom implementation
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            UserDefaults.standard.set(Double(zoomScale), forKey: "beecell_zoomScale")
        }
    }
    public var defaultZoomScale: CGFloat = 1.0
    
    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: "beecell_options")
        }
    }
    
    private func handleOptionsChanged(oldValue: BeecellOptions) {
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
        
        if options.isVegasScoring != oldValue.isVegasScoring || options.deckCount != oldValue.deckCount {
            startNewGame()
        }
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: "beecell_statistics")
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
        var modeStats = stats.statsByMode[currentModeKey] ?? ModeStats()
        modeStats.gamesWon += 1
        modeStats.currentStreak += 1
        modeStats.longestStreak = max(modeStats.longestStreak, modeStats.currentStreak)
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
        self.defaultZoomScale = 1.0
        self.zoomScale = 1.0
        
        // Load options
        if let data = UserDefaults.standard.data(forKey: "beecell_options"),
           var decoded = try? JSONDecoder().decode(BeecellOptions.self, from: data) {
            if let globalCardBack = UserDefaults.standard.string(forKey: "cardBackTheme") {
                decoded.cardBackTheme = globalCardBack
            }
            if let globalFeltStr = UserDefaults.standard.string(forKey: "global_felt_color"),
               let globalFelt = FeltColorTheme(rawValue: globalFeltStr) {
                decoded.feltColor = globalFelt
            }
            self.options = decoded
        } else {
            let globalCardBack = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Vulpera"
            let globalFeltStr = UserDefaults.standard.string(forKey: "global_felt_color") ?? FeltColorTheme.feltGreen.rawValue
            let globalFelt = FeltColorTheme(rawValue: globalFeltStr) ?? .feltGreen
            self.options = BeecellOptions(feltColor: globalFelt, cardBackTheme: globalCardBack)
        }
        
        // Load statistics
        if let data = UserDefaults.standard.data(forKey: "beecell_statistics"),
           let decoded = try? JSONDecoder().decode(BeecellStatistics.self, from: data) {
            self.statistics = decoded
        }
        
        // Load zoom settings
        if let savedDefault = UserDefaults.standard.value(forKey: "beecell_defaultZoomScale") as? Double {
            self.defaultZoomScale = CGFloat(savedDefault)
        }
        
        if let savedZoom = UserDefaults.standard.value(forKey: "beecell_zoomScale") as? Double {
            self.zoomScale = CGFloat(savedZoom)
        } else {
            self.zoomScale = self.defaultZoomScale
        }
        
        // Register for global preferences notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleFeltColorNotification), name: .feltColorDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCardBackThemeNotification), name: .cardBackThemeDidChange, object: nil)
        
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
        let initialScore = options.isVegasScoring ? (-5200 * options.deckCount) : 0
        
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
        initialState = state
        clearHint()
    }
    
    public func restartCurrentGame() {
        guard let initial = initialState else { return }
        stopTimer()
        undoStack.removeAll()
        state = initial
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        clearHint()
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
    }
    
    public func doubleClickMove(card: Card, from sourcePile: Pile) {
        guard sourcePile.topCard?.id == card.id else { return }
        
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
    }
    
    private func adjustScore(from source: Pile.PileType, to target: Pile.PileType) {
        if options.isVegasScoring {
            if target == .foundation {
                state.score += 500
            } else if source == .foundation {
                state.score -= 500
            }
        } else {
            if target == .foundation {
                state.score += 10
            } else if source == .foundation {
                state.score = max(0, state.score - 15)
            }
        }
        
        if state.score > highScore {
            highScore = state.score
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
    
    // MARK: - Victory Verification
    
    public func checkWinState() {
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        let expectedCards = options.deckCount * 52
        
        if totalFoundationCards == expectedCards && !state.hasWon {
            state.hasWon = true
            stopTimer()
            recordWin(timeInSeconds: state.timerSeconds)
            playSound(named: "victory")
        }
    }
    
    // MARK: - Autocomplete & Hint
    
    public func checkAutocompleteState() {
        let expectedCards = options.deckCount * 52
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        
        if totalFoundationCards == expectedCards {
            isAutocompleteAvailable = false
            return
        }
        
        // Autocomplete is safe and available if:
        // 1. All free cells are empty
        // 2. All tableau piles are sorted in descending alternating order
        let freeCellsEmpty = state.freeCells.allSatisfy { $0.cards.isEmpty }
        
        let tableauSorted = state.tableau.allSatisfy { pile in
            guard pile.cards.count > 1 else { return true }
            for i in 0..<(pile.cards.count - 1) {
                let upper = pile.cards[i]
                let lower = pile.cards[i+1]
                if upper.rank != lower.rank + 1 || upper.isRed == lower.isRed {
                    return false
                }
            }
            return true
        }
        
        isAutocompleteAvailable = freeCellsEmpty && tableauSorted && !state.hasWon
    }
    
    public struct HintMove: Equatable {
        public let card: Card
        public let sourcePileId: String
        public let targetPileId: String
        public let description: String
    }
    
    public var activeHint: HintMove? = nil
    
    public func findHint() {
        activeHint = nil
        
        // 1. Foundations priority
        // Check free cells to foundation
        for cell in state.freeCells {
            if let topCard = cell.topCard {
                for foundation in state.foundations {
                    if isValidMove(cards: [topCard], to: foundation) {
                        activeHint = HintMove(
                            card: topCard,
                            sourcePileId: cell.id,
                            targetPileId: foundation.id,
                            description: "Move \(topCard.rankString)\(topCard.suit.symbol) from Free Cell to Foundation."
                        )
                        return
                    }
                }
            }
        }
        // Check tableau top cards to foundation
        for column in state.tableau {
            if let topCard = column.topCard {
                for foundation in state.foundations {
                    if isValidMove(cards: [topCard], to: foundation) {
                        activeHint = HintMove(
                            card: topCard,
                            sourcePileId: column.id,
                            targetPileId: foundation.id,
                            description: "Move \(topCard.rankString)\(topCard.suit.symbol) from Tableau to Foundation."
                        )
                        return
                    }
                }
            }
        }
        
        // 2. Tableau to Tableau sequence moves
        for sourceCol in state.tableau {
            // Find longest valid sequence from top of sourceCol
            guard !sourceCol.isEmpty else { continue }
            
            // Go backwards from bottom to find the start of the sorted sequence
            var seqStartIdx = sourceCol.cards.count - 1
            while seqStartIdx > 0 {
                let upper = sourceCol.cards[seqStartIdx - 1]
                let lower = sourceCol.cards[seqStartIdx]
                if upper.rank == lower.rank + 1 && upper.isRed != lower.isRed {
                    seqStartIdx -= 1
                } else {
                    break
                }
            }
            
            // Try to move sequences of various lengths
            for idx in seqStartIdx..<sourceCol.cards.count {
                let dragStack = Array(sourceCol.cards[idx..<sourceCol.cards.count])
                
                for targetCol in state.tableau {
                    if targetCol.id != sourceCol.id && isValidMove(cards: dragStack, to: targetCol) {
                        // Avoid moving single card to empty column unless it exposes something or is useful
                        if targetCol.isEmpty && dragStack.count == 1 && idx == 0 {
                            continue
                        }
                        
                        activeHint = HintMove(
                            card: dragStack.first!,
                            sourcePileId: sourceCol.id,
                            targetPileId: targetCol.id,
                            description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) sequence to Tableau."
                        )
                        return
                    }
                }
            }
        }
        
        // 3. Free cell to Tableau
        for cell in state.freeCells {
            if let topCard = cell.topCard {
                for targetCol in state.tableau {
                    if isValidMove(cards: [topCard], to: targetCol) {
                        activeHint = HintMove(
                            card: topCard,
                            sourcePileId: cell.id,
                            targetPileId: targetCol.id,
                            description: "Move \(topCard.rankString)\(topCard.suit.symbol) from Free Cell to Tableau."
                        )
                        return
                    }
                }
            }
        }
        
        // 4. Tableau to Free Cell (as a last resort to open space)
        for sourceCol in state.tableau {
            if let topCard = sourceCol.topCard {
                for cell in state.freeCells {
                    if cell.isEmpty {
                        activeHint = HintMove(
                            card: topCard,
                            sourcePileId: sourceCol.id,
                            targetPileId: cell.id,
                            description: "Move \(topCard.rankString)\(topCard.suit.symbol) to Free Cell to clear space."
                        )
                        return
                    }
                }
            }
        }
        
        activeHint = HintMove(
            card: Card(suit: .spades, rank: 1, faceUp: true),
            sourcePileId: "",
            targetPileId: "",
            description: "No moves available. Try restarting or starting a new game."
        )
    }
    
    public func clearHint() {
        activeHint = nil
    }
    
    public func runAutocomplete() {
        guard isAutocompleteAvailable && !isAutoplayRunning else { return }
        saveStateForUndo()
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
                        return (topCard, cell, foundation)
                    }
                }
            }
        }
        // Tableau second
        for column in state.tableau {
            if let topCard = column.topCard {
                for foundation in state.foundations {
                    if isValidMove(cards: [topCard], to: foundation) {
                        return (topCard, column, foundation)
                    }
                }
            }
        }
        return nil
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
        clearHint()
        checkWinState()
        checkAutocompleteState()
    }
    
    // MARK: - Zoom Actions
    
    public func zoomIn() {
        zoomScale = min(2.0, zoomScale + 0.1)
    }
    
    public func zoomOut() {
        zoomScale = max(0.6, zoomScale - 0.1)
    }
    
    public func resetZoom() {
        zoomScale = defaultZoomScale
    }
    
    public func makeCurrentZoomDefault() {
        defaultZoomScale = zoomScale
        UserDefaults.standard.set(Double(defaultZoomScale), forKey: "beecell_defaultZoomScale")
    }
    
    public func resetStatistics() {
        statistics = BeecellStatistics()
    }
}
