import Foundation
import Observation

@Observable
public final class GameViewModel {
    public var state: GameState
    private let gameTimer = GameTimer()
    
    public var options: GameOptions {
        didSet {
            saveOptions()
            UISound.isEnabled = options.isSoundEnabled
            handleOptionsChanged(oldValue: oldValue)
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

    // Point Highlights: transient "+N"/"-N" popup over the card responsible for a score
    // change — not part of `state`/undo snapshots, same precedent as isAutoplayRunning.
    public var pointPopup: CardPointPopup? = nil
    private var pointPopupGeneration: Int = 0

    // Stuck / stock exhaustion
    public var isStuck: Bool = false
    public var isStockExhausted: Bool = false
    public var recycleCountAtStuck: Int? = nil

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
    private var undoStack = UndoStack<GameState>()

    // Initial state for game replay
    private var initialState: GameState?
    
    public var canUndo: Bool {
        !undoStack.isEmpty && !state.hasWon
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
    

    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: "solitaire_options")
        }
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
            startNewGame(countAsNewGame: false)
        }
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: "solitaire_statistics")
        }
    }
    
    public func playSound(named name: String) {
        UISound.play(named: name, enabled: options.isSoundEnabled)
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
           let decoded = try? JSONDecoder().decode(GameOptions.self, from: data) {
            self.options = decoded
        } else {
            self.options = GameOptions()
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

        UISound.isEnabled = self.options.isSoundEnabled

        self.state.drawMode = self.options.drawMode
        startNewGame()
    }

    deinit {
        stopTimer()
    }

    // MARK: - Game Setup
    
    // `countAsNewGame: false` is for options-driven re-deals (e.g. toggling Vegas
    // Scoring) that reshuffle the board without the player actually finishing or
    // abandoning a game — those shouldn't count toward gamesPlayed or break a streak.
    public func startNewGame(countAsNewGame: Bool = true) {
        stopTimer()

        if countAsNewGame {
            if state.movesCount > 0 && !state.hasWon {
                var stats = statistics
                stats.currentStreak = 0
                statistics = stats
            }
            gamesPlayed += 1
        } else {
            // Re-dealing because of an option change, not a player-initiated new game.
            // If Vegas mode is active, the initial state.score is -5200, but we shouldn't
            // double-charge their cumulative bankroll for this re-deal.
            if options.isVegasScoring && state.movesCount > 0 {
                vegasBankroll -= -5200 // Refund the cost of the aborted layout
            }
        }

        undoStack.removeAll()
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
            // Refund the previous start cost if the game was abandoned without making a single move
            if state.movesCount == 0 && gameGeneration > 0 {
                vegasBankroll -= -5200
            }
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
        recycleCountAtStuck = nil
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
        recycleCountAtStuck = nil
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

            // Foundations aren't suit-locked to a fixed slot — any empty foundation can
            // start with any suit's Ace (whichever slot the player picks), and from then
            // on it's locked to whatever suit its own top card actually is.
            if targetPile.isEmpty {
                return firstCard.rank == 1 // Only an Ace can start an empty foundation
            } else {
                guard let topCard = targetPile.topCard else { return false }
                return firstCard.suit == topCard.suit && firstCard.rank == topCard.rank + 1
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
        var revealedFaceDownCard = false
        var revealedCardId: UUID? = nil

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
                    revealedFaceDownCard = true
                    revealedCardId = state.tableau[idx].cards.last!.id
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
        adjustScore(from: sourcePile.type, to: targetPile.type, revealedFaceDownCard: revealedFaceDownCard)
        updatePointPopup(anchorCard: cards.last, source: sourcePile.type, target: targetPile.type,
                         revealedFaceDownCard: revealedFaceDownCard, revealedCardId: revealedCardId)

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
    
    private func adjustScore(from source: Pile.PileType, to target: Pile.PileType, revealedFaceDownCard: Bool = false) {
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
                state.score -= 15
            }
            if revealedFaceDownCard {
                state.score += 5
            }
        }
    }

    // Point Highlights: mirrors adjustScore's branching (move-type events take
    // precedence over the reveal-only case, since a single moveCards call can trigger
    // both — e.g. a tableau→foundation move that also reveals the card underneath —
    // and the popup's one slot can only show one at a time; the moved card's own event
    // is the more relevant one to show).
    private func updatePointPopup(anchorCard: Card?, source: Pile.PileType, target: Pile.PileType, revealedFaceDownCard: Bool, revealedCardId: UUID?) {
        guard options.showPointHighlights, !isAutoplayRunning else { return }
        let popup: CardPointPopup?
        if options.isVegasScoring {
            if target == .foundation, let anchorCard {
                popup = CardPointPopup(cardId: anchorCard.id, displayText: Self.currencyString(cents: 500), isPositive: true)
            } else if source == .foundation && target == .tableau, let anchorCard {
                popup = CardPointPopup(cardId: anchorCard.id, displayText: Self.currencyString(cents: -500), isPositive: false)
            } else {
                popup = nil
            }
        } else {
            if target == .foundation, let anchorCard {
                popup = CardPointPopup(cardId: anchorCard.id, displayText: "+10", isPositive: true)
            } else if (source == .stock || source == .waste) && target == .tableau, let anchorCard {
                popup = CardPointPopup(cardId: anchorCard.id, displayText: "+5", isPositive: true)
            } else if source == .foundation && target == .tableau, let anchorCard {
                popup = CardPointPopup(cardId: anchorCard.id, displayText: "-15", isPositive: false)
            } else if revealedFaceDownCard, let revealedCardId {
                popup = CardPointPopup(cardId: revealedCardId, displayText: "+5", isPositive: true)
            } else {
                popup = nil
            }
        }
        guard let popup else { return }
        pointPopupGeneration += 1
        let generation = pointPopupGeneration
        pointPopup = popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.pointPopupGeneration == generation else { return }
            self.pointPopup = nil
        }
    }

    // Point Highlights only ever deals in whole-dollar amounts (±$5 today), so this
    // skips cents entirely rather than always showing "+$5.00".
    private static func currencyString(cents: Int) -> String {
        let dollars = Int(cents / 100)
        return dollars >= 0 ? "+$\(dollars)" : "-$\(abs(dollars))"
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
        // Game is won when all 4 foundations have 13 cards (total 52 cards)
        let totalFoundationCards = state.foundations.reduce(0) { $0 + $1.cards.count }
        if WinDetection.hasWon(foundationCardCount: totalFoundationCards, totalCards: 52, alreadyWon: state.hasWon) {
            state.hasWon = true
            stopTimer()
            recordWin(timeInSeconds: state.timerSeconds)
            playSound(named: "victory")
            if !options.isVegasScoring && state.timerSeconds > 0 {
                // Standard-mode time scoring (Microsoft Solitaire rules), applied once on win:
                // deduct 2 points for every 10 seconds elapsed, then add the 700,000 / seconds bonus.
                state.score -= 2 * (state.timerSeconds / 10)
                state.score += 700000 / state.timerSeconds
            }
            if state.score > highScore {
                highScore = state.score
            }
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

    // Simulates drawing a stock all the way through in `state.drawMode`-sized batches
    // (mirrors drawCard()'s popLast()-per-card, append-in-pop-order behavior exactly),
    // recording every card that becomes the top of waste along the way. In Draw Three
    // this is NOT every card: within each batch of 3, only the last card popped (the one
    // that ends up on top of that batch's contribution) ever becomes visible/selectable —
    // the other two are only ever seen fanned out behind it. Returns the resulting waste
    // pile too, so a caller can chain a simulated recycle afterward.
    private func simulateDrawThrough(stock: [Card], waste: [Card]) -> (waste: [Card], reachable: [Card]) {
        let batchSize = state.drawMode == .drawOne ? 1 : 3
        var simStock = stock
        var simWaste = waste
        var reachable: [Card] = []
        while !simStock.isEmpty {
            let take = min(batchSize, simStock.count)
            var drawn: [Card] = []
            for _ in 0..<take {
                if let c = simStock.popLast() { drawn.append(c) }
            }
            simWaste.append(contentsOf: drawn)
            if let top = simWaste.last { reachable.append(top) }
        }
        return (simWaste, reachable)
    }

    // Cards reachable by continuing to draw the current stock, no recycle needed.
    private func hasPlayableStockCard() -> Bool {
        let targets: [Pile] = state.foundations + state.tableau
        let (_, reachable) = simulateDrawThrough(stock: state.stock.cards, waste: state.waste.cards)
        return reachable.contains { card in targets.contains { isValidMove(cards: [card], to: $0) } }
    }

    // Cards reachable only by recycling the waste back into the stock and drawing again.
    // Recycling reverses the ENTIRE waste pile, not per-batch, so a full draw-through
    // followed by one recycle is its own inverse (reverse(reverse(x)) == x) — it exactly
    // reconstructs the pre-draw stock order. That means a second recycle would rediscover
    // nothing new, so simulating a single recycle+redraw here is always sufficient.
    private func hasPlayableWasteCard() -> Bool {
        guard canRecycleStock else { return false }
        let targets: [Pile] = state.foundations + state.tableau
        let (finalWaste, _) = simulateDrawThrough(stock: state.stock.cards, waste: state.waste.cards)
        let (_, reachable) = simulateDrawThrough(stock: Array(finalWaste.reversed()), waste: [])
        return reachable.contains { card in targets.contains { isValidMove(cards: [card], to: $0) } }
    }

    private func hasValidMoves() -> Bool {
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

        // No board move exists. The game is only un-stuck if a card still waiting in the
        // stock, or (if a fresh pass is still allowed) buried in the waste, can actually
        // be played — merely having cards left in the stock is not enough.
        if hasPlayableStockCard() { return true }
        if canRecycleStock && hasPlayableWasteCard() { return true }
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
            recycleCountAtStuck = nil
            return
        }
        isStockExhausted = state.stock.isEmpty && !canRecycleStock
        
        let hasMoves = hasValidMoves()
        if hasMoves {
            isStuck = false
            recycleCountAtStuck = nil
        } else {
            if isStockExhausted {
                isStuck = true
            } else if options.isVegasScoring {
                isStuck = false
            } else {
                if recycleCountAtStuck == nil {
                    recycleCountAtStuck = state.recyclesCount
                }
                
                if let stuckAt = recycleCountAtStuck, state.recyclesCount > stuckAt {
                    isStuck = true
                } else {
                    isStuck = false
                }
            }
        }
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

        // Waste to tableau
        if let topWaste = state.waste.topCard {
            for targetCol in state.tableau where isValidMove(cards: [topWaste], to: targetCol) {
                scored.append((HintMove(card: topWaste, sourcePileId: state.waste.id, targetPileId: targetCol.id,
                    description: "Move \(topWaste.rankString)\(topWaste.suit.symbol) from Waste to Tableau."), 300))
            }
        }

        // Tableau-to-tableau — tries every sub-run starting position within the face-up
        // portion of the column (matching hasValidMoves()'s search exactly), not just the
        // entire face-up run. Without this, a board whose only progressive move is a
        // partial sub-run (e.g. peeling off the bottom few cards of a run to expose a
        // card mid-column) would show no hint at all, even though hasValidMoves() — which
        // does check every sub-run — correctly knows a move exists.
        for col in state.tableau {
            guard let firstFaceUpIdx = col.cards.firstIndex(where: { $0.faceUp }) else { continue }
            for startIdx in firstFaceUpIdx..<col.cards.count {
                let dragStack = Array(col.cards[startIdx...])
                var valid = true
                for i in 0..<dragStack.count - 1 {
                    if dragStack[i].rank != dragStack[i+1].rank + 1 || dragStack[i].isRed == dragStack[i+1].isRed { valid = false; break }
                }
                guard valid else { continue }

                for targetCol in state.tableau where targetCol.id != col.id && isValidMove(cards: dragStack, to: targetCol) {
                    guard isProgressiveMove(cards: dragStack, source: col, target: targetCol) else { continue }

                    if startIdx == firstFaceUpIdx && firstFaceUpIdx > 0 {
                        let faceDownCount = firstFaceUpIdx
                        let label = faceDownCount == 1 ? "Reveal 1 face-down card." : "Reveal \(faceDownCount) face-down cards."
                        scored.append((HintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                            description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) — \(label)"), 500 + faceDownCount * 100))
                    } else if !targetCol.isEmpty {
                        scored.append((HintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                            description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to \(targetCol.topCard!.rankString)\(targetCol.topCard!.suit.symbol)."), 150))
                    } else {
                        scored.append((HintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                            description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to an empty column."), 150))
                    }
                }
            }
        }

        // Stock / recycle — only suggest an action that can actually reach a playable
        // card, otherwise Hint would loop on "Draw from Stock" forever once every
        // remaining stock/waste card is a dead end.
        if !state.stock.isEmpty && hasPlayableStockCard() {
            scored.append((HintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                sourcePileId: state.stock.id, targetPileId: state.waste.id, description: "Draw from Stock pile."), 50))
        } else if canRecycleStock && hasPlayableWasteCard() {
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
        undoStack.push(state)
    }

    public func undoLastAction() {
        guard let previous = undoStack.pop() else { return }
        // The timer must keep running forward through an undo, not rewind to whatever it
        // read when the undone move's snapshot was saved.
        let currentTimerSeconds = state.timerSeconds
        let currentIsTimerActive = state.isTimerActive
        let scoreBeforeUndo = state.score
        state = previous
        state.timerSeconds = currentTimerSeconds
        state.isTimerActive = currentIsTimerActive
        // Standard-mode undo penalty: deducts the points the undone move(s) earned, on
        // top of the natural reversion the state restore above already did. Since the timer
        // no longer drains score mid-game, the difference between the pre-undo score and
        // the restored snapshot score equals exactly what the move(s) earned — no separate
        // scoreDeltaStack needed. Clamped to 0 so undoing a move that already COST points
        // (e.g. a foundation retreat) can't turn into a net reward.
        if !options.isVegasScoring {
            let pointsEarnedByUndoneMove = scoreBeforeUndo - state.score
            state.score -= max(0, pointsEarnedByUndoneMove)
        }
        // vegasBankroll isn't part of `state`, but it always tracks state.score 1:1 via
        // adjustScore()'s +500/-500 branches — recompute it to match the restored score
        // rather than leaving it stranded at its pre-undo value.
        if options.isVegasScoring, let initial = initialState {
            vegasBankroll = vegasBankrollAtGameStart + (state.score - initial.score)
        }
        isAutoplayRunning = false
        isStuck = false
        pointPopup = nil
        clearHint()
        clearKeyboardCursor()
        checkWinState()
        checkAutocompleteState()
        checkStuckState()
    }
    
    // MARK: - Board scale
    // No longer a manual, user-set value — GameView.recomputeScale() continuously derives
    // this from the window's current size to fit the board to it, replacing the old
    // manual zoom system entirely. Not persisted: it's purely a function of window size,
    // recomputed fresh every launch from whatever size the window opens at.
    public var zoomScale: CGFloat = 1.0

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
