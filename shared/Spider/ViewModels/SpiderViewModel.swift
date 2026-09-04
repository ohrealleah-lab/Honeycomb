import Foundation
import Observation

@Observable
public final class SpiderViewModel {
    public var state: SpiderState
    private let gameTimer = GameTimer()

    // Bumped on every fresh deal (startNewGame/restartCurrentGame) — lets the view
    // recompute its fit-to-window scale against the newly-dealt tableau's real column
    // depths, since tableau.count never changes for Spider (always 10 columns) and can't
    // serve as that signal the way it does for Klondike/Beecell.
    public private(set) var gameGeneration: Int = 0

    // True single source of truth for isSoundEnabled/noStressMode/honeyMode/
    // manuallyDismissBanners/hideHintButton — same instance AppCoordinator and every
    // other game ViewModel hold. See SharedGameOptions.swift.
    public let sharedOptions: SharedGameOptions

    public var options: SpiderOptions {
        didSet {
            saveOptions()
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
    
    public var averageWinningTime: Double {
        currentModeStats.averageWinningTime
    }
    
    public var shortestWinTime: Int {
        currentModeStats.shortestWinTime
    }
    
    // Total across every suit-count mode, not just currentModeStats — "10 wins" for a
    // milestone should mean the game overall, not one specific mode.
    private var totalGamesWon: Int { statistics.statsBySuits.values.reduce(0) { $0 + $1.gamesWon } }
    private var totalGamesPlayed: Int { statistics.statsBySuits.values.reduce(0) { $0 + $1.gamesPlayed } }

    // FIFO queue of banner texts (milestones, loading flavor) — mirrors the Honeycomb
    // port's bannerQueue/enqueueBanner/advanceBannerQueue.
    private var bannerQueue: [String] = []
    public var flashBanner: String? { bannerQueue.first }
    public var flashBannerTrigger: Int = 0

    private func enqueueBanner(_ text: String) {
        bannerQueue.append(text)
        if bannerQueue.count == 1 {
            flashBannerTrigger += 1
        }
    }

    public func advanceBannerQueue() {
        guard !bannerQueue.isEmpty else { return }
        bannerQueue.removeFirst()
        if !bannerQueue.isEmpty {
            flashBannerTrigger += 1
        }
    }

    // Fires once, exactly on the win that crosses a threshold — not "totalGamesWon >=
    // threshold", which would fire on every subsequent win too.
    private func checkWinMilestones() {
        let thresholds: [(Int, BannerID)] = [
            (10, .milestonesPlayerReaches10TotalWins),
            (100, .milestonesPlayerReaches100TotalWins),
            (1000, .milestonesPlayerReaches1000TotalWins),
        ]
        for (threshold, id) in thresholds where totalGamesWon == threshold {
            if case .message(let text) = BannerCatalog.shared.fire(id) {
                enqueueBanner(text)
            }
        }
    }

    // Fires once per app session, the first time this game's view actually appears
    // (called from SpiderView's .onAppear — a "loading" banner belongs to a screen
    // transition, not a gameplay action, so switching to this game for the first
    // time this session fires it; switching back to it later doesn't).
    private var hasFiredLoadingBannerThisSession = false

    public func checkLoadingBanner() {
        guard !hasFiredLoadingBannerThisSession else { return }
        hasFiredLoadingBannerThisSession = true
        if case .message(let text) = BannerCatalog.shared.fire(BannerCatalog.loadingBannerID()) {
            enqueueBanner(text)
        }
    }

    // Ambiance/Idle nudge: fires if a full minute passes with no move. Re-armed via a
    // generation-token so an already-scheduled check from before the last move sees a
    // mismatch and silently no-ops instead of firing late. Mirrors the Honeycomb port's
    // scheduleIdleCheck (shared/Honeycomb/ViewModels/HoneycombViewModel.swift) — called
    // from SpiderView's .onChange(of: viewModel.state.movesCount) and from
    // startNewGame()/restartCurrentGame().
    private var idleCheckGeneration: Int = 0
    private static let idleToastDelay: TimeInterval = 60

    public func scheduleIdleActionCheck() {
        idleCheckGeneration += 1
        let generation = idleCheckGeneration
        guard !UISound.isHeadlessMode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleToastDelay) { [weak self] in
            guard let self, self.idleCheckGeneration == generation, !self.state.hasWon else { return }
            if case .message(let text) = BannerCatalog.shared.fire(.idleActionNoActionTakenForOneMinute) {
                self.enqueueBanner(text)
            }
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

    // Point Highlights: transient "+N"/"-N" popup over the card responsible for a score
    // change — not part of `state`/undo snapshots, same precedent as isAutoplayRunning.
    // No popup for the stock deal's flat -1 (no single card to anchor it to).
    public var pointPopup: CardPointPopup? = nil
    private var pointPopupGeneration: Int = 0

    private func showPointPopup(cardId: UUID, displayText: String, isPositive: Bool) {
        guard sharedOptions.honeyMode, !isAutoplayRunning else { return }
        pointPopupGeneration += 1
        let generation = pointPopupGeneration
        pointPopup = CardPointPopup(cardId: cardId, displayText: displayText, isPositive: isPositive)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.pointPopupGeneration == generation else { return }
            self.pointPopup = nil
        }
    }

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
    
    // Reacts to No Stress Mode toggling. Called only by AppCoordinator, and only for
    // whichever game is currently active (see AppCoordinator.init's
    // sharedOptions.onNoStressModeChange registration) — sharedOptions is one instance
    // shared by every game, so a naive per-ViewModel self-registration here would fire
    // for backgrounded games too, spuriously resuming a stopped timer on an abandoned
    // hand nobody is looking at (the exact bug this replaced, see git history:
    // testBackgroundGameTimerDoesNotResumeFromAnotherGamesOptionsSync).
    public func reactToNoStressModeChange() {
        if effectiveTimed() {
            if state.movesCount > 0 && !state.hasWon {
                startTimerIfNeeded()
            }
        } else if state.isTimerActive {
            // Only reset elapsed time when we're actually stopping a running timer
            // (this game was the foreground one). A shared-option change (e.g. No
            // Stress Mode toggled elsewhere) can reach a backgrounded game whose timer
            // is already stopped — its saved elapsed time shouldn't be wiped just
            // because it received the update.
            stopTimer()
            state.timerSeconds = 0
        }
    }

    private func handleOptionsChanged(oldValue: SpiderOptions) {
        if options.suitCount != oldValue.suitCount {
            // options has already flipped to the NEW suitCount by the time this didSet
            // fires — pass the OLD value explicitly so the abandoned-game streak reset
            // below targets the mode that was actually being played.
            startNewGame(abandonedSuitCount: oldValue.suitCount)
        }
    }
    
    private func saveStatistics() {
        if let encoded = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(encoded, forKey: "spider_statistics")
        }
    }
    
    public func playSound(named name: String) {
        UISound.play(named: name, enabled: sharedOptions.isSoundEnabled)
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
        checkWinMilestones()
    }

    public init(state: SpiderState = SpiderState(stock: Pile(id: "stock", type: .stock), foundations: [], tableau: [], score: 500, movesCount: 0, timerSeconds: 0, isTimerActive: false, hasWon: false), sharedOptions: SharedGameOptions = SharedGameOptions()) {
        self.state = state
        self.sharedOptions = sharedOptions

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

        startNewGame()
    }

    deinit {
        stopTimer()
    }

    // MARK: - Game Setup
    
    // abandonedSuitCount: which suit-count mode's streak to reset for the game being
    // abandoned by this call. Defaults to options.suitCount (the common case). See
    // Beecell's analogous startNewGame(abandonedModeKey:) for why handleOptionsChanged
    // needs to pass the OLD value explicitly instead.
    public func startNewGame(abandonedSuitCount: Int? = nil) {
        stopTimer()

        // totalGamesPlayed only grows via the increment below, so checking it here,
        // before that increment, is this game's equivalent of "is this the very
        // first deal ever."
        if totalGamesPlayed == 0, case .message(let text) = BannerCatalog.shared.fire(.milestonesFirstLaunchEver) {
            enqueueBanner(text)
        }

        if state.movesCount > 0 && !state.hasWon {
            var stats = statistics
            let suitCount = abandonedSuitCount ?? options.suitCount
            var modeStats = stats.statsBySuits[suitCount] ?? SpiderModeStats()
            modeStats.currentStreak = 0
            stats.statsBySuits[suitCount] = modeStats
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
        scheduleIdleActionCheck()
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
        scheduleIdleActionCheck()
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

        // Dealing changes what's on top of every tableau column — an active hint may
        // reference a card that's about to be buried. Matches moveCards/undoLastAction/
        // startNewGame's own unconditional clearHint() for the same reason.
        clearHint()

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
        // Autocomplete-availability must be recomputed before stuck-detection, since
        // checkStuckState's guard reads isAutocompleteAvailable — checking in the other
        // order tests the *previous* move's flag instead of the one for the board state
        // that was just produced (matches the Windows port's call order).
        checkAutocompleteState()
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
        // Any move can change which card is actually on top of a pile — an active hint
        // (still showing, not yet auto-cleared) may reference a card that's no longer
        // that pile's accessible top card once this move lands, e.g. a card that used
        // to be a valid hint target getting buried by a different card the player just
        // placed on top of it. Matches undoLastAction/startNewGame's own unconditional
        // clearHint() for the same reason (board state changed under the hint).
        clearHint()
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
        if let anchorCard = cards.last {
            showPointPopup(cardId: anchorCard.id, displayText: "-1", isPositive: false)
        }

        checkCompletedRuns()
        // See the matching comment in drawFromStock — autocomplete-availability must be
        // recomputed before stuck-detection reads it.
        checkAutocompleteState()
        checkStuckState()
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
                // Anchored to the completed run's Ace (subrange.last), the card that
                // visually lands in the foundation — wins over any "-1" popup from the
                // move that triggered this sweep, since it fires after that in the same
                // call chain (moveCards → checkCompletedRuns).
                if let anchorCard = subrange.last {
                    showPointPopup(cardId: anchorCard.id, displayText: "+100", isPositive: true)
                }
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
    private func effectiveTimed() -> Bool {
        !sharedOptions.noStressMode
    }

    public func startTimerIfNeeded() {
        guard effectiveTimed() else { return }
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
        // Undo is disallowed once the win sequence has committed: checkWinState() calls
        // recordWin() which immediately persists gamesWon/currentStreak to disk. Rolling
        // back past that point would leave the saved stats permanently inflated while
        // the board shows a pre-win state. The undo stack is cleared on win so this
        // guard is a safety net, not the primary mechanism.
        guard !state.hasWon else { return }
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
        pointPopup = nil
        clearHint()
        clearKeyboardCursor()
        checkWinState()
        // See the matching comment in drawFromStock — autocomplete-availability must be
        // recomputed before stuck-detection reads it.
        checkAutocompleteState()
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

        isAutocompleteAvailable = !state.hasWon && canSimulateAutocompleteWin()
    }

    private func canSimulateAutocompleteWin() -> Bool {
        guard state.stock.isEmpty else { return false }
        
        var simTableau = state.tableau
        var didMove = true
        
        while didMove {
            didMove = false
            var nextMove: (cards: [Card], sourceIdx: Int, targetIdx: Int)? = nil
            var fallbackMove: (cards: [Card], sourceIdx: Int, targetIdx: Int)? = nil

            // Must mirror findNextAutocompleteMove() exactly, including which function it
            // calls to judge a landing spot — isValidMove() only requires the target's top
            // card to be exactly one rank higher, suit doesn't matter. This loop used to
            // hand-roll that check with an extra `topCard.suit == firstCard.suit` condition
            // that isValidMove() doesn't have, and never considered an empty column as a
            // landing spot at all. Either gap alone could make this simulation report a
            // dead end (isAutocompleteAvailable == false) on a board the real executor
            // would actually complete successfully.
            for srcIdx in 0..<simTableau.count where !simTableau[srcIdx].cards.isEmpty {
                let source = simTableau[srcIdx]
                let seq = getLongestValidSequence(in: source)
                if seq.isEmpty { continue }

                var matchedThisSource = false
                for tgtIdx in 0..<simTableau.count where tgtIdx != srcIdx {
                    let target = simTableau[tgtIdx]
                    if !target.isEmpty, isValidMove(cards: seq, to: target) {
                        nextMove = (seq, srcIdx, tgtIdx)
                        matchedThisSource = true
                        break
                    }
                }
                if matchedThisSource { break }

                // Fallback: park a partial sequence (never the whole column, which would
                // just relocate which column is empty) on an empty column when no matching
                // top card exists anywhere.
                if fallbackMove == nil, seq.count < source.cards.count {
                    for tgtIdx in 0..<simTableau.count where tgtIdx != srcIdx && simTableau[tgtIdx].cards.isEmpty {
                        fallbackMove = (seq, srcIdx, tgtIdx)
                        break
                    }
                }
            }

            if let move = nextMove ?? fallbackMove {
                didMove = true
                let cardIDs = Set(move.cards.map { $0.id })
                simTableau[move.sourceIdx].cards.removeAll { cardIDs.contains($0.id) }
                
                if !simTableau[move.sourceIdx].cards.isEmpty && !simTableau[move.sourceIdx].cards.last!.faceUp {
                    simTableau[move.sourceIdx].cards[simTableau[move.sourceIdx].cards.count - 1].faceUp = true
                }
                
                simTableau[move.targetIdx].cards.append(contentsOf: move.cards)
                
                var completedRunFound = false
                repeat {
                    completedRunFound = false
                    for i in 0..<simTableau.count {
                        let cards = simTableau[i].cards
                        guard cards.count >= 13 else { continue }
                        let subrange = Array(cards.suffix(13))
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
                            completedRunFound = true
                            let completedIDs = Set(subrange.map { $0.id })
                            simTableau[i].cards.removeAll { completedIDs.contains($0.id) }
                            if !simTableau[i].cards.isEmpty && !simTableau[i].cards.last!.faceUp {
                                simTableau[i].cards[simTableau[i].cards.count - 1].faceUp = true
                            }
                            break
                        }
                    }
                } while completedRunFound
            }
        }
        
        return simTableau.allSatisfy { $0.cards.isEmpty }
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
        var fallbackSource: Pile? = nil
        var fallbackCards: [Card]? = nil
        var fallbackTarget: Pile? = nil

        for source in state.tableau {
            let seq = getLongestValidSequence(in: source)
            if seq.isEmpty { continue }
            
            for target in state.tableau {
                if target.id == source.id || target.cards.isEmpty { continue }
                if isValidMove(cards: seq, to: target) {
                    return (seq, source, target)
                }
            }
            
            if fallbackSource == nil && seq.count < source.cards.count {
                for target in state.tableau {
                    if target.id == source.id || !target.cards.isEmpty { continue }
                    fallbackSource = source
                    fallbackCards = seq
                    fallbackTarget = target
                    break
                }
            }
        }
        
        if let fs = fallbackSource, let fc = fallbackCards, let ft = fallbackTarget {
            return (fc, fs, ft)
        }
        return nil
    }

    private func getLongestValidSequence(in pile: Pile) -> [Card] {
        guard !pile.cards.isEmpty, let lastCard = pile.cards.last, lastCard.faceUp else { return [] }
        var result = [lastCard]
        if pile.cards.count == 1 { return result }
        
        for i in stride(from: pile.cards.count - 2, through: 0, by: -1) {
            let card = pile.cards[i]
            let prevCard = pile.cards[i + 1]
            if card.faceUp, card.suit == prevCard.suit, card.rank == prevCard.rank + 1 {
                result.insert(card, at: 0)
            } else {
                break
            }
        }
        return result
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

    @discardableResult
    public func findHint() -> Bool {
        hintClearTask?.cancel()
        return HintCycling.findHint(
            activeHint: &activeHint,
            hintQueue: &hintQueue,
            hintQueueIndex: &hintQueueIndex,
            collectHints: collectHints,
            label: { labeled($0, index: $1, total: $2) },
            noHintFallback: {
                SpiderHintMove(card: Card(suit: .spades, rank: 1, faceUp: false),
                    sourcePileId: "", targetPileId: "", description: "No moves available. Replay or deal a new game!")
            },
            scheduleClear: scheduleHintClear
        )
    }

    private func labeled(_ hint: SpiderHintMove, index: Int, total: Int) -> SpiderHintMove {
        let prefix = total > 1 ? "[\(index + 1)/\(total)] " : ""
        return SpiderHintMove(card: hint.card, sourcePileId: hint.sourcePileId,
            targetPileId: hint.targetPileId, description: prefix + hint.description)
    }

    public var debugBannerRequest: DebugBannerKind? = nil

    private func evaluateImmediateMoves(depth: Int = 0) -> [(SpiderHintMove, Int)] {
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
                for k in minValidK...(col.cards.count - 1) {
                    let dragStack = Array(col.cards[k...])
                    let faceDownBelow = k == firstFaceUpIdx ? firstFaceUpIdx : 0
                    let freesColumn = k == 0

                    if targetCol.isEmpty {
                        // Moving to empty column: only worthwhile if it exposes a face-down card
                        if faceDownBelow > 0 {
                            // The move only ever flips the single new top card, regardless
                            // of how many face-down cards sit below it — faceDownBelow here
                            // is just the depth-weighted score bonus, not how many actually flip.
                            let label = "Reveal 1 face-down card."
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) to empty column — \(label)"),
                                350 + faceDownBelow * 150))
                            break
                        } else if !freesColumn {
                            let breaksCrossSuit = k > 0 && col.cards[k-1].faceUp && col.cards[k-1].suit != dragStack.first!.suit
                            let score = breaksCrossSuit ? 150 : 50
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) sequence to empty column."), score))
                            break
                        }
                    } else if let topCard = targetCol.topCard, topCard.rank == dragStack.first!.rank + 1 {
                        // Check for lateral move: if the card we are breaking from is identical to the target
                        if k > 0 && col.cards[k-1].faceUp && col.cards[k-1].suit == topCard.suit && col.cards[k-1].rank == topCard.rank {
                            continue
                        }
                        
                        let sameSuit = topCard.suit == dragStack.first!.suit
                        let faceDownBonus = faceDownBelow * 150
                        let vacateBonus = freesColumn ? 250 : 0
                        
                        var targetIsClean = true
                        let faceUpTargetCards = targetCol.cards.filter { $0.faceUp }
                        if faceUpTargetCards.count > 1 {
                            for i in 0..<faceUpTargetCards.count - 1 {
                                if faceUpTargetCards[i].suit != faceUpTargetCards[i+1].suit {
                                    targetIsClean = false
                                    break
                                }
                            }
                        }
                        let cleanStackPenalty = (!sameSuit && targetIsClean) ? -100 : 0

                        if sameSuit {
                            // Best: extends a same-suit run
                            let score = faceDownBelow > 0 ? 1000 + faceDownBonus + vacateBonus : 900 + vacateBonus
                            // Always reveals exactly 1 card (the new top), regardless of
                            // faceDownBelow — see note above.
                            let label = faceDownBelow > 0 ? " — Reveal 1 face-down card." : "."
                            scored.append((SpiderHintMove(card: dragStack.first!, sourcePileId: col.id, targetPileId: targetCol.id,
                                description: "Move \(dragStack.first!.rankString)\(dragStack.first!.suit.symbol) onto \(topCard.rankString)\(topCard.suit.symbol)\(label)"), score))
                        } else {
                            // Cross-suit build
                            let score = faceDownBelow > 0 ? 600 + faceDownBonus + vacateBonus + cleanStackPenalty : 400 + vacateBonus + cleanStackPenalty
                            let label = faceDownBelow > 0 ? " — Reveal 1 face-down card." : "."
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

        if depth == 0 {
            var enhancedScores: [(SpiderHintMove, Int)] = []
            let originalState = self.state
            
            for (move, baseScore) in scored {
                if move.sourcePileId.isEmpty || move.sourcePileId == state.stock.id {
                    enhancedScores.append((move, baseScore))
                    continue
                }
                
                guard let srcIdx = self.state.tableau.firstIndex(where: { $0.id == move.sourcePileId }) else {
                    enhancedScores.append((move, baseScore))
                    continue
                }
                guard let tgtIdx = self.state.tableau.firstIndex(where: { $0.id == move.targetPileId }) else {
                    enhancedScores.append((move, baseScore))
                    continue
                }
                
                if let cardIdx = self.state.tableau[srcIdx].cards.firstIndex(where: { $0.id == move.card.id }) {
                    let dragStack = Array(self.state.tableau[srcIdx].cards[cardIdx...])
                    self.state.tableau[srcIdx].cards.removeSubrange(cardIdx...)
                    if let last = self.state.tableau[srcIdx].cards.last, !last.faceUp {
                        self.state.tableau[srcIdx].cards[self.state.tableau[srcIdx].cards.count - 1].faceUp = true
                    }
                    self.state.tableau[tgtIdx].cards.append(contentsOf: dragStack)
                    
                    let nextLevel = evaluateImmediateMoves(depth: 1)
                    if let bestNext = nextLevel.max(by: { $0.1 < $1.1 }) {
                        let futureScore = Int(Double(bestNext.1) * 0.8)
                        enhancedScores.append((move, baseScore + futureScore))
                    } else {
                        enhancedScores.append((move, baseScore))
                    }
                    
                    self.state = originalState
                } else {
                    enhancedScores.append((move, baseScore))
                }
            }
            scored = enhancedScores
        }

        return scored
    }

    private func collectHints() -> [SpiderHintMove] {
        let scored = evaluateImmediateMoves(depth: 0)

        let filtered = scored.filter { (hint, _) in
            guard let src = lastMoveSourceId, let tgt = lastMoveTargetId else { return true }
            return !(hint.sourcePileId == tgt && hint.targetPileId == src)
        }
        let candidates = filtered.isEmpty ? scored : filtered
        return candidates.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    private func scheduleHintClear() {
        hintClearTask?.cancel()

        let clearTask = DispatchWorkItem { [weak self] in
            self?.activeHint = nil
            self?.hintQueue = []
            self?.hintQueueIndex = 0
        }
        hintClearTask = clearTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: clearTask)
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
        statistics.statsBySuits[options.suitCount] = SpiderModeStats()
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
