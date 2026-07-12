import Foundation
import Observation
import AppKit

@Observable
public final class GameViewModel {
    public var state: GameState
    public var timer: Timer?
    
    public var options: GameOptions {
        didSet {
            saveOptions()
            UISound.isEnabled = options.isSoundEnabled
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

    public var statistics: GameStatistics {
        didSet {
            saveStatistics()
        }
    }
    
    public var gamesWon: Int {
        get { statistics.gamesWon }
        set {
            var newStats = statistics
            newStats.gamesWon = newValue
            statistics = newStats
            UserDefaults.standard.set(newValue, forKey: "gamesWon")
        }
    }
    
    public var gamesPlayed: Int {
        get { statistics.gamesPlayed }
        set {
            var newStats = statistics
            newStats.gamesPlayed = newValue
            statistics = newStats
            UserDefaults.standard.set(newValue, forKey: "gamesPlayed")
        }
    }
    
    public var highScore: Int = 0 {
        didSet {
            if options.isVegasScoring {
                UserDefaults.standard.set(highScore, forKey: "highScoreVegas")
            } else {
                UserDefaults.standard.set(highScore, forKey: "highScore")
            }
        }
    }

    // Vegas bankroll — cumulative score within a session only; resets on app launch
    public var vegasBankroll: Int = 0
    private var vegasBankrollAtGameStart: Int = 0

    public func resetVegasBankroll() {
        vegasBankroll = 0
    }

    public var vegasBankrollString: String {
        let dollars = Double(vegasBankroll) / 100.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
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
    
    // Auto-complete status
    public var isAutocompleteAvailable: Bool = false
    public var isAutoplayRunning: Bool = false

    // Stuck / stock exhaustion
    public var isStuck: Bool = false
    public var isStockExhausted: Bool = false

    // Tracks whether the player has drawn/recycled the stock at least once this game —
    // drives the idle "hint" nudge on the stock pile for a player who hasn't dealt yet.
    public var hasDrawnFromStockThisGame: Bool = false
    // The idle stock nudge only ever plays once per game, even if the player keeps
    // idling without drawing afterward.
    public var hasShownIdleStockHintThisGame: Bool = false
    // Increments on every startNewGame()/restartCurrentGame() so the View can reliably
    // re-arm the idle stock hint even when movesCount happens to stay at 0 across the
    // reset (e.g. clicking New Game again before making a single move).
    public private(set) var gameGeneration: Int = 0

    // Undo stack
    private var undoStack: [GameState] = []
    
    // Initial state for game replay
    private var initialState: GameState?
    
    public var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    public var maxRecycles: Int? {
        if options.isVegasScoring {
            return state.drawMode == .drawThree ? 2 : 0
        }
        return nil
    }
    
    public var canRecycleStock: Bool {
        guard !state.waste.isEmpty else { return false }
        if let maxRec = maxRecycles {
            return state.recyclesCount < maxRec
        }
        return true
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
    
    public var defaultZoomScale: CGFloat = 1.0
    public var cardBackTheme: String {
        get { options.cardBackTheme }
        set {
            var newOpts = options
            newOpts.cardBackTheme = newValue
            options = newOpts
            UserDefaults.standard.set(newValue, forKey: "cardBackTheme")
        }
    }
    
    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: "solitaire_options")
        }
        UserDefaults.standard.set(options.cardBackTheme, forKey: "cardBackTheme")
    }
    
    private func handleOptionsChanged(oldValue: GameOptions) {
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

        if options.isVegasScoring != oldValue.isVegasScoring {
            if options.isVegasScoring {
                if UserDefaults.standard.object(forKey: "highScoreVegas") != nil {
                    self.highScore = UserDefaults.standard.integer(forKey: "highScoreVegas")
                } else {
                    self.highScore = -5200
                }
                vegasBankroll = 0  // fresh bankroll when entering Vegas mode
            } else {
                self.highScore = UserDefaults.standard.integer(forKey: "highScore")
                vegasBankroll = 0
            }
            startNewGame()
        }
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: "solitaire_statistics")
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
        stats.gamesWon += 1
        stats.currentStreak += 1
        stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
        stats.winningGamesCount += 1
        stats.totalWinningTime += timeInSeconds
        if timeInSeconds > 0 && (stats.shortestWinTime == 0 || timeInSeconds < stats.shortestWinTime) {
            stats.shortestWinTime = timeInSeconds
        }
        statistics = stats
        
        UserDefaults.standard.set(stats.gamesWon, forKey: "gamesWon")
    }
    
    public init(state: GameState = GameState()) {
        self.state = state
        if let data = UserDefaults.standard.data(forKey: "solitaire_options"),
           var decoded = try? JSONDecoder().decode(GameOptions.self, from: data) {
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
            var opts = GameOptions()
            let legacyTheme = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Moogle"
            let globalFeltStr = UserDefaults.standard.string(forKey: "global_felt_color") ?? FeltColorTheme.feltGreen.rawValue
            opts.cardBackTheme = legacyTheme
            opts.feltColor = FeltColorTheme(rawValue: globalFeltStr) ?? .feltGreen
            if UserDefaults.standard.object(forKey: "showFeltVignette") != nil {
                opts.showFeltVignette = UserDefaults.standard.bool(forKey: "showFeltVignette")
            }
            if let dataColors = UserDefaults.standard.data(forKey: "customCardColors"),
               let colors = try? JSONDecoder().decode(CustomCardColorGroup.self, from: dataColors) {
                opts.customCardColors = colors
            }
            self.options = opts
        }

        // Load statistics and synchronize with legacy keys
        let legacyWon = UserDefaults.standard.integer(forKey: "gamesWon")
        let legacyPlayed = UserDefaults.standard.integer(forKey: "gamesPlayed")
        if let data = UserDefaults.standard.data(forKey: "solitaire_statistics"),
           var decoded = try? JSONDecoder().decode(GameStatistics.self, from: data) {
            decoded.gamesPlayed = legacyPlayed
            decoded.gamesWon = legacyWon
            self.statistics = decoded
        } else {
            self.statistics = GameStatistics(gamesPlayed: legacyPlayed, gamesWon: legacyWon)
        }
        
        if self.options.isVegasScoring {
            if UserDefaults.standard.object(forKey: "highScoreVegas") != nil {
                self.highScore = UserDefaults.standard.integer(forKey: "highScoreVegas")
            } else {
                self.highScore = -5200
            }
        } else {
            self.highScore = UserDefaults.standard.integer(forKey: "highScore")
        }

        self.vegasBankroll = 0
        
        // Load default zoom setting
        if let savedDefault = UserDefaults.standard.value(forKey: "defaultZoomScale") as? Double {
            self.defaultZoomScale = CGFloat(savedDefault)
        } else {
            self.defaultZoomScale = 1.0
        }
        
        // Load saved zoom setting
        if let savedZoom = UserDefaults.standard.value(forKey: "zoomScale") as? Double {
            self.zoomScale = CGFloat(savedZoom)
        } else {
            self.zoomScale = self.defaultZoomScale
        }

        // Load default window size setting
        if let savedWidth = UserDefaults.standard.value(forKey: "defaultWindowWidth") as? Double,
           let savedHeight = UserDefaults.standard.value(forKey: "defaultWindowHeight") as? Double {
            self.defaultWindowSize = CGSize(width: savedWidth, height: savedHeight)
        }

        UISound.isEnabled = self.options.isSoundEnabled

        // Register for global preferences notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleFeltColorNotification), name: .feltColorDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCardBackThemeNotification), name: .cardBackThemeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCustomCardColorsNotification), name: .customCardColorsDidChange, object: nil)
        
        self.state.drawMode = self.options.drawMode
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
            stats.currentStreak = 0
            statistics = stats
        }
        
        undoStack.removeAll()
        gamesPlayed += 1
        playSound(named: "shuffle")
        
        // 1. Create a 52-card deck
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 {
                deck.append(Card(suit: suit, rank: rank, faceUp: false))
            }
        }
        
        // 2. Shuffle deck
        deck.shuffle()
        
        // 3. Deal Tableau (7 columns)
        var tableau: [Pile] = []
        var deckIndex = 0
        for i in 0..<7 {
            var cards: [Card] = []
            for j in 0...i {
                var card = deck[deckIndex]
                deckIndex += 1
                if j == i {
                    card.faceUp = true
                }
                cards.append(card)
            }
            tableau.append(Pile(id: "tableau_\(i)", type: .tableau, cards: cards))
        }
        
        // 4. Place remainder in Stock
        var stockCards: [Card] = []
        while deckIndex < deck.count {
            stockCards.append(deck[deckIndex])
            deckIndex += 1
        }
        let stock = Pile(id: "stock", type: .stock, cards: stockCards)
        
        // 5. Initialize Piles
        let waste = Pile(id: "waste", type: .waste, cards: [])
        let foundationSuits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
        let foundations = foundationSuits.map { suit in
            Pile(id: "foundation_\(suit.rawValue)", type: .foundation, cards: [])
        }
        
        // 6. Set State
        let initialScore = options.isVegasScoring ? -5200 : 0
        if options.isVegasScoring {
            vegasBankroll += initialScore
            vegasBankrollAtGameStart = vegasBankroll
        }
        state = GameState(
            stock: stock,
            waste: waste,
            foundations: foundations,
            tableau: tableau,
            score: initialScore,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            drawMode: state.drawMode,
            hasWon: false,
            recyclesCount: 0
        )
        
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
        isStockExhausted = false
        hasDrawnFromStockThisGame = false
        hasShownIdleStockHintThisGame = false
        gameGeneration += 1
        initialState = state
        clearHint()
        clearKeyboardCursor()
    }

    public func restartCurrentGame() {
        guard let initial = initialState else { return }
        stopTimer()
        undoStack.removeAll()
        // Restore bankroll to pre-game value — restart replays the same deal, no re-deal charge
        if options.isVegasScoring { vegasBankroll = vegasBankrollAtGameStart }
        state = initial
        isAutocompleteAvailable = false
        isAutoplayRunning = false
        isStuck = false
        isStockExhausted = false
        hasDrawnFromStockThisGame = false
        hasShownIdleStockHintThisGame = false
        gameGeneration += 1
        clearHint()
        clearKeyboardCursor()
    }
    
    // MARK: - Core Interactions
    
    public func drawCard() {
        if state.stock.isEmpty {
            guard canRecycleStock else { return }
            recycleStock()
        } else {
            saveStateForUndo()
        }

        guard !state.stock.isEmpty else { return }
        hasDrawnFromStockThisGame = true

        startTimerIfNeeded()
        
        let count = state.drawMode == .drawOne ? 1 : min(3, state.stock.cards.count)
        var drawn: [Card] = []
        
        for _ in 0..<count {
            if var card = state.stock.cards.popLast() {
                card.faceUp = true
                drawn.append(card)
            }
        }
        
        // Drawn cards go on the waste pile
        state.waste.cards.append(contentsOf: drawn)
        state.wasteDisplayCount = drawn.count

        state.movesCount += 1

        checkAutocompleteState()
        checkStuckState()
    }

    public func recycleStock() {
        guard state.stock.isEmpty && !state.waste.isEmpty else { return }
        guard canRecycleStock else { return }
        
        saveStateForUndo()
        state.recyclesCount += 1
        playSound(named: "shuffle")
        
        let recycled = state.waste.cards.map { card in
            var c = card
            c.faceUp = false
            return c
        }.reversed()
        
        state.stock.cards = Array(recycled)
        state.waste.cards.removeAll()
        state.wasteDisplayCount = 0
        state.movesCount += 1
        hasDrawnFromStockThisGame = true
    }
    
    // MARK: - Move Validation & Execution
    
    public func isValidMove(cards: [Card], to targetPile: Pile) -> Bool {
        guard let firstCard = cards.first else { return false }
        
        switch targetPile.type {
        case .tableau:
            if targetPile.isEmpty {
                return firstCard.rank == 13 // Only Kings
            } else {
                guard let topCard = targetPile.topCard else { return false }
                return firstCard.rank == topCard.rank - 1 && firstCard.isRed != topCard.isRed
            }
        case .foundation:
            // Foundations can only accept a single card at a time
            guard cards.count == 1 else { return false }
            
            guard let suitString = targetPile.id.components(separatedBy: "_").last,
                  let suit = Card.Suit(rawValue: suitString) else {
                return false
            }
            
            guard firstCard.suit == suit else { return false }
            
            if targetPile.isEmpty {
                return firstCard.rank == 1 // Only Ace starts an empty foundation
            } else {
                guard let topCard = targetPile.topCard else { return false }
                return firstCard.rank == topCard.rank + 1
            }
        case .stock, .waste, .freeCell:
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
        
        // Remove cards from source
        let cardIDs = Set(cards.map { $0.id })
        
        if sourcePile.type == .stock {
            state.stock.cards.removeAll { cardIDs.contains($0.id) }
        } else if sourcePile.type == .waste {
            state.waste.cards.removeAll { cardIDs.contains($0.id) }
            state.wasteDisplayCount = max(0, state.wasteDisplayCount - cardIDs.count)
            // If the current batch is fully played but older waste cards remain,
            // re-expose the previous layer so they are visible and playable.
            if state.wasteDisplayCount == 0 && !state.waste.cards.isEmpty {
                state.wasteDisplayCount = state.drawMode == .drawOne ? 1 : min(3, state.waste.cards.count)
            }
        } else if sourcePile.type == .tableau {
            if let idx = state.tableau.firstIndex(where: { $0.id == sourcePile.id }) {
                state.tableau[idx].cards.removeAll { cardIDs.contains($0.id) }
                
                // Auto-flip next card if face down
                if !state.tableau[idx].cards.isEmpty && !state.tableau[idx].cards.last!.faceUp {
                    state.tableau[idx].cards[state.tableau[idx].cards.count - 1].faceUp = true
                }
            }
        } else if sourcePile.type == .foundation {
            if let idx = state.foundations.firstIndex(where: { $0.id == sourcePile.id }) {
                state.foundations[idx].cards.removeAll { cardIDs.contains($0.id) }
            }
        }
        
        // Add to target
        if targetPile.type == .tableau {
            if let idx = state.tableau.firstIndex(where: { $0.id == targetPile.id }) {
                state.tableau[idx].cards.append(contentsOf: cards)
            }
        } else if targetPile.type == .foundation {
            if let idx = state.foundations.firstIndex(where: { $0.id == targetPile.id }) {
                state.foundations[idx].cards.append(contentsOf: cards)
            }
        }
        
        // Score adjustments
        adjustScore(from: sourcePile.type, to: targetPile.type)

        state.movesCount += 1
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }
    
    public func doubleClickMoveToFoundation(card: Card, from sourcePile: Pile) {
        guard sourcePile.topCard?.id == card.id else { return }
        // Match the drag-start convention: any direct mouse move relinquishes keyboard
        // focus/selection so a stale cached cardIndex can't outlive the pile it pointed
        // into if this move shrinks it.
        clearKeyboardCursor()

        for foundation in state.foundations {
            if isValidMove(cards: [card], to: foundation) {
                moveCards([card], from: sourcePile, to: foundation)
                break
            }
        }
    }
    
    private func adjustScore(from source: Pile.PileType, to target: Pile.PileType) {
        if options.isVegasScoring {
            if target == .foundation {
                state.score += 500
                vegasBankroll += 500
            } else if source == .foundation && target == .tableau {
                state.score -= 500
                vegasBankroll -= 500
            }
        } else {
            if target == .foundation {
                state.score += 10
            } else if (source == .stock || source == .waste) && target == .tableau {
                state.score += 5
            } else if source == .foundation && target == .tableau {
                state.score = max(0, state.score - 15)
            }
        }
        
        if state.score > highScore {
            highScore = state.score
        }
    }
    
    // MARK: - Timer Handling

    // `isTimed` has no UI control anymore (the old "Timed Game" toggle was replaced by
    // No Stress Mode) so it's intentionally not consulted here — honoring a persisted
    // `false` from before that change would permanently strand upgrading users with no
    // way to turn the timer back on.
    private func effectiveTimed(_ o: GameOptions) -> Bool {
        !o.noStressMode
    }

    public func startTimerIfNeeded() {
        guard effectiveTimed(options) else { return }
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
        // Game is won when all 4 foundations have 13 cards (total 52 cards)
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        if totalFoundationCards == 52 && !state.hasWon {
            state.hasWon = true
            stopTimer()
            recordWin(timeInSeconds: state.timerSeconds)
            playSound(named: "victory")
        }
    }
    
    // MARK: - Autocomplete & Hints Check
    
    public func checkAutocompleteState() {
        // Autocomplete is available when:
        // 1. Stock and Waste piles are empty
        // 2. All cards in Tableau columns are faceUp (no faceDown cards)
        let stockEmpty = state.stock.isEmpty
        let wasteEmpty = state.waste.isEmpty
        
        let allTableauFaceUp = state.tableau.allSatisfy { pile in
            pile.cards.allSatisfy { $0.faceUp }
        }
        
        let allCardsCount = state.tableau.reduce(0) { $0 + $1.cards.count } +
                             state.foundations.reduce(0) { $0 + $1.cards.count }
        
        isAutocompleteAvailable = stockEmpty && wasteEmpty && allTableauFaceUp && allCardsCount == 52 && !state.hasWon
    }
    
    // MARK: - Stuck Detection

    private func hasValidMoves() -> Bool {
        // Can draw from stock or recycle waste?
        if !state.stock.isEmpty || canRecycleStock { return true }

        // Stock is empty and no recycling is available — no new cards can ever be drawn.
        // Only count moves that make real progress; pure tableau reorganization of fully
        // face-up columns (e.g. kings shuffling between empty slots) cannot advance the
        // game and must not prevent stuck detection.
        let allSources: [Pile] = (state.waste.topCard != nil ? [state.waste] : []) + state.tableau
        let targets: [Pile] = state.foundations + state.tableau

        for source in allSources {
            guard let topCard = source.topCard else { continue }
            for target in targets where target.id != source.id {
                if isValidMove(cards: [topCard], to: target),
                   isProgressiveMove(cards: [topCard], source: source, target: target) {
                    return true
                }
            }
            // Try multi-card tableau sequences
            if source.type == .tableau {
                guard let colIdx = state.tableau.firstIndex(where: { $0.id == source.id }) else { continue }
                let col = state.tableau[colIdx]
                for startIdx in 0..<col.cards.count where col.cards[startIdx].faceUp {
                    let seq = Array(col.cards[startIdx...])
                    // Validate sequence
                    var valid = true
                    for i in 0..<seq.count - 1 {
                        if seq[i].rank != seq[i+1].rank + 1 || seq[i].isRed == seq[i+1].isRed { valid = false; break }
                    }
                    guard valid else { continue }
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

    // A move is progressive if it advances toward the win condition:
    // - Moving to a foundation pile, OR
    // - Placing the waste top card onto the tableau (it's a new card entering play), OR
    // - Revealing a face-down card in the source tableau column, OR
    // - Fully clearing a tableau column onto a NON-empty target, creating a genuinely
    //   new empty column, OR
    // - Exposing an already-face-up card that can immediately move to a foundation
    //   (it was blocked, not hidden, but freeing it is still real progress).
    // Pure tableau-to-tableau reorganization that does none of the above is not progressive.
    private func isProgressiveMove(cards: [Card], source: Pile, target: Pile) -> Bool {
        if target.type == .foundation { return true }
        if source.type == .waste { return true }
        if source.type == .tableau {
            guard let colIdx = state.tableau.firstIndex(where: { $0.id == source.id }) else { return false }
            let col = state.tableau[colIdx]
            let remainingCount = col.cards.count - cards.count
            if remainingCount == 0 {
                // Only a King-led run can move onto an empty target, so if the target is
                // ALSO empty this just relocates that King from one empty column to
                // another — net zero progress (and, left unguarded, a move that's always
                // available whenever a lone King and an empty column coexist, which would
                // make the game seem never stuck). Only count it as progress when the
                // target was occupied, so a genuinely new empty column is created.
                return !target.isEmpty
            }
            let exposedCard = col.cards[remainingCount - 1]
            if !exposedCard.faceUp { return true }
            if state.foundations.contains(where: { isValidMove(cards: [exposedCard], to: $0) }) {
                return true
            }
        }
        return false
    }

    public func checkStuckState() {
        guard !state.hasWon && !isAutocompleteAvailable else {
            isStuck = false
            isStockExhausted = false
            return
        }
        isStockExhausted = state.stock.isEmpty && !canRecycleStock
        isStuck = !hasValidMoves()
    }

    // MARK: - Hints & Autocomplete Execution

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

        // Cycle through existing queue if hint is still visible
        if !hintQueue.isEmpty && activeHint != nil {
            hintQueueIndex = (hintQueueIndex + 1) % hintQueue.count
            activeHint = labeled(hintQueue[hintQueueIndex], index: hintQueueIndex, total: hintQueue.count)
            scheduleHintClear()
            return
        }

        hintQueue = collectHints()
        hintQueueIndex = 0

        guard !hintQueue.isEmpty else {
            activeHint = HintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                sourcePileId: "", targetPileId: "", description: "No such luck, friend! Try a new game!")
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

        // Foundation moves
        if let topWaste = state.waste.topCard {
            for foundation in state.foundations where isValidMove(cards: [topWaste], to: foundation) {
                scored.append((HintMove(card: topWaste, sourcePileId: state.waste.id, targetPileId: foundation.id,
                    description: "Move \(topWaste.rankString)\(topWaste.suit.symbol) from Waste to Foundation."), 1000))
            }
        }
        for col in state.tableau {
            guard let top = col.topCard else { continue }
            for foundation in state.foundations where isValidMove(cards: [top], to: foundation) {
                scored.append((HintMove(card: top, sourcePileId: col.id, targetPileId: foundation.id,
                    description: "Move \(top.rankString)\(top.suit.symbol) to Foundation."), 1000))
            }
        }

        // Reveal face-down cards (scored by number hidden below)
        for col in state.tableau {
            guard let firstFaceUpIdx = col.cards.firstIndex(where: { $0.faceUp }),
                  firstFaceUpIdx > 0 else { continue }
            let faceDownCount = firstFaceUpIdx
            let dragStack = Array(col.cards[firstFaceUpIdx...])
            for targetCol in state.tableau where targetCol.id != col.id && isValidMove(cards: dragStack, to: targetCol) {
                let label = faceDownCount == 1 ? "Reveal 1 face-down card." : "Reveal \(faceDownCount) face-down cards."
                scored.append((HintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                    description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) — \(label)"), 500 + faceDownCount * 100))
            }
        }

        // Waste to tableau
        if let topWaste = state.waste.topCard {
            for targetCol in state.tableau where isValidMove(cards: [topWaste], to: targetCol) {
                scored.append((HintMove(card: topWaste, sourcePileId: state.waste.id, targetPileId: targetCol.id,
                    description: "Move \(topWaste.rankString)\(topWaste.suit.symbol) from Waste to Tableau."), 300))
            }
        }

        // Tableau-to-tableau (all face-up columns — reorganization)
        for col in state.tableau {
            guard let firstFaceUpIdx = col.cards.firstIndex(where: { $0.faceUp }),
                  firstFaceUpIdx == 0, !col.isEmpty else { continue }
            let dragStack = Array(col.cards[firstFaceUpIdx...])
            for targetCol in state.tableau where targetCol.id != col.id && !targetCol.isEmpty && isValidMove(cards: dragStack, to: targetCol) {
                scored.append((HintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                    description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to \(targetCol.topCard!.rankString)\(targetCol.topCard!.suit.symbol)."), 150))
            }
        }

        // Stock / recycle
        if !state.stock.isEmpty {
            scored.append((HintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                sourcePileId: state.stock.id, targetPileId: state.waste.id, description: "Draw from Stock pile."), 50))
        } else if canRecycleStock && !state.waste.isEmpty {
            scored.append((HintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                sourcePileId: state.waste.id, targetPileId: state.stock.id, description: "Recycle Waste pile to Stock."), 20))
        }

        // Filter reversal of the last move made, then sort best-first
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
        // Autoplay moves cards without further cursor navigation, so a cached keyboard
        // cursor/selection could otherwise go stale (pointing past the end of a column
        // autoplay just drained) and crash on the next Space/arrow press.
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
        if let topWaste = state.waste.topCard {
            for foundation in state.foundations {
                if isValidMove(cards: [topWaste], to: foundation) {
                    return (topWaste, state.waste, foundation)
                }
            }
        }
        
        for tableauColumn in state.tableau {
            if let topTab = tableauColumn.topCard {
                for foundation in state.foundations {
                    if isValidMove(cards: [topTab], to: foundation) {
                        return (topTab, tableauColumn, foundation)
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
        // vegasBankroll isn't part of `state`, but it always tracks state.score 1:1 via
        // adjustScore()'s +500/-500 branches — recompute it to match the restored score
        // rather than leaving it stranded at its pre-undo value.
        if options.isVegasScoring, let initial = initialState {
            vegasBankroll = vegasBankrollAtGameStart + (state.score - initial.score)
        }
        isAutoplayRunning = false
        isStuck = false
        clearHint()
        clearKeyboardCursor()
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }
    
    // MARK: - Zoom Implementation
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            UserDefaults.standard.set(Double(zoomScale), forKey: "zoomScale")
        }
    }
    
    public func zoomIn() {
        zoomScale = min(2.0, zoomScale + 0.1)
    }
    
    public func zoomOut() {
        zoomScale = max(0.6, zoomScale - 0.1)
    }
    
    public func resetZoom() {
        zoomScale = defaultZoomScale
        defaultWindowSize = nil
        UserDefaults.standard.removeObject(forKey: "defaultWindowWidth")
        UserDefaults.standard.removeObject(forKey: "defaultWindowHeight")
    }

    public func makeCurrentZoomDefault() {
        defaultZoomScale = zoomScale
        UserDefaults.standard.set(Double(defaultZoomScale), forKey: "defaultZoomScale")
    }

    // MARK: - Default Window Size
    public var defaultWindowSize: CGSize?

    public func makeCurrentWindowSizeDefault(_ size: CGSize) {
        defaultWindowSize = size
        UserDefaults.standard.set(Double(size.width), forKey: "defaultWindowWidth")
        UserDefaults.standard.set(Double(size.height), forKey: "defaultWindowHeight")
    }

    public func resetStatistics() {
        gamesWon = 0
        gamesPlayed = 0
        highScore = options.isVegasScoring ? -5200 : 0
    }

    // MARK: - Keyboard Navigation
    public var activeCursor: KeyboardCursor?
    public var selectedCardsSource: String?
    public var selectedCardsIndex: Int?
    
    // Internal coordinate tracking
    private var cursorColumn: Int = 0 // tableau column
    private var topRowColumn: Int = 0 // stock/waste/foundation column
    private var cursorRow: Int = 0 // 0 = Top, 1 = Tableau

    public func enableKeyboardCursorIfNeeded() {
        if activeCursor == nil {
            activeCursor = KeyboardCursor(pileId: state.stock.id)
            topRowColumn = 0
            cursorRow = 0
        }
    }

    public func clearKeyboardCursor() {
        activeCursor = nil
        selectedCardsSource = nil
        selectedCardsIndex = nil
        // Reset coordinate trackers too, so a stale tableau column can't survive into a
        // freshly re-engaged cursor and cause a drifted/out-of-bounds focus placement.
        cursorColumn = 0
        topRowColumn = 0
        cursorRow = 0
    }

    public func moveCursorLeft() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            var newCol = topRowColumn - 1
            if newCol < 0 { newCol = 6 }
            // Skip blank space in top row (column 2)
            if newCol == 2 { newCol = 1 }
            topRowColumn = newCol
        } else {
            var newCol = cursorColumn - 1
            if newCol < 0 { newCol = 6 }
            cursorColumn = newCol
        }
        updateCursorFromCoordinates()
    }

    public func moveCursorRight() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            var newCol = topRowColumn + 1
            if newCol > 6 { newCol = 0 }
            // Skip blank space in top row (column 2)
            if newCol == 2 { newCol = 3 }
            topRowColumn = newCol
        } else {
            var newCol = cursorColumn + 1
            if newCol > 6 { newCol = 0 }
            cursorColumn = newCol
        }
        updateCursorFromCoordinates()
    }
    
    public func moveCursorUp() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 1 {
            // Check if we can move focus to a card higher in the tableau column
            if let active = activeCursor,
               let colIdx = state.tableau.firstIndex(where: { $0.id == active.pileId }),
               let cardIdx = active.cardIndex,
               cardIdx > 0 {
                // Find previous card in the column (only move up if it's faceUp)
                let prevIdx = cardIdx - 1
                if state.tableau[colIdx].cards[prevIdx].faceUp {
                    activeCursor?.cardIndex = prevIdx
                    return
                }
            }
            // If we can't move up further in tableau, move to top row
            cursorRow = 0
            // Adjust top column if we were on column 2 (empty space)
            topRowColumn = cursorColumn == 2 ? 1 : cursorColumn
            updateCursorFromCoordinates()
        }
    }
    
    public func moveCursorDown() {
        enableKeyboardCursorIfNeeded()
        if cursorRow == 0 {
            cursorRow = 1
            updateCursorFromCoordinates()
        } else {
            // Check if we can move focus to a card lower in the tableau column
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
            switch topRowColumn {
            case 0: activeCursor = KeyboardCursor(pileId: state.stock.id)
            case 1: activeCursor = KeyboardCursor(pileId: state.waste.id)
            case 3: activeCursor = KeyboardCursor(pileId: state.foundations[0].id)
            case 4: activeCursor = KeyboardCursor(pileId: state.foundations[1].id)
            case 5: activeCursor = KeyboardCursor(pileId: state.foundations[2].id)
            case 6: activeCursor = KeyboardCursor(pileId: state.foundations[3].id)
            default: break
            }
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
            
            // Find target pile
            let targetPile: Pile?
            if cursor.pileId == state.stock.id { targetPile = state.stock }
            else if cursor.pileId == state.waste.id { targetPile = state.waste }
            else if let fIdx = state.foundations.firstIndex(where: { $0.id == cursor.pileId }) { targetPile = state.foundations[fIdx] }
            else if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { targetPile = state.tableau[tIdx] }
            else { targetPile = nil }
            
            // Find source pile
            let sourcePile: Pile?
            if sourceId == state.stock.id { sourcePile = state.stock }
            else if sourceId == state.waste.id { sourcePile = state.waste }
            else if let fIdx = state.foundations.firstIndex(where: { $0.id == sourceId }) { sourcePile = state.foundations[fIdx] }
            else if let tIdx = state.tableau.firstIndex(where: { $0.id == sourceId }) { sourcePile = state.tableau[tIdx] }
            else { sourcePile = nil }
            
            guard let target = targetPile, let source = sourcePile else {
                selectedCardsSource = nil
                selectedCardsIndex = nil
                return
            }
            
            let cardsToMove: [Card]
            if source.type == .tableau {
                if let selIdx = selectedCardsIndex {
                    cardsToMove = Array(source.cards[selIdx..<source.cards.count])
                } else {
                    cardsToMove = source.topCard != nil ? [source.topCard!] : []
                }
            } else {
                cardsToMove = source.topCard != nil ? [source.topCard!] : []
            }
            
            if !cardsToMove.isEmpty && isValidMove(cards: cardsToMove, to: target) {
                moveCards(cardsToMove, from: source, to: target)
                if target.type == .tableau {
                    cursorRow = 1
                    updateCursorFromCoordinates()
                }
            }
            selectedCardsSource = nil
            selectedCardsIndex = nil
        } else {
            if cursor.pileId == state.stock.id {
                if state.stock.isEmpty {
                    recycleStock()
                } else {
                    drawCard()
                }
            } else {
                let sourcePile: Pile?
                if cursor.pileId == state.waste.id { sourcePile = state.waste }
                else if let fIdx = state.foundations.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.foundations[fIdx] }
                else if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.tableau[tIdx] }
                else { sourcePile = nil }
                
                guard let source = sourcePile, !source.isEmpty else { return }
                
                if source.type == .tableau {
                    if let cardIdx = cursor.cardIndex {
                        if source.cards[cardIdx].faceUp {
                            selectedCardsSource = cursor.pileId
                            selectedCardsIndex = cardIdx
                        }
                    }
                } else {
                    selectedCardsSource = cursor.pileId
                    selectedCardsIndex = source.cards.count - 1
                }
            }
        }
    }
    
    public func autoMoveFocusedCardToFoundations() {
        enableKeyboardCursorIfNeeded()
        guard let cursor = activeCursor else { return }
        
        let sourcePile: Pile?
        if cursor.pileId == state.waste.id { sourcePile = state.waste }
        else if let tIdx = state.tableau.firstIndex(where: { $0.id == cursor.pileId }) { sourcePile = state.tableau[tIdx] }
        else { sourcePile = nil }
        
        guard let source = sourcePile, let topCard = source.topCard else { return }
        
        for foundation in state.foundations {
            if isValidMove(cards: [topCard], to: foundation) {
                moveCards([topCard], from: source, to: foundation)
                selectedCardsSource = nil
                selectedCardsIndex = nil
                if source.type == .tableau {
                    updateCursorFromCoordinates()
                }
                break
            }
        }
    }
}
