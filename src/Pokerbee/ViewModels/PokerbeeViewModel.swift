import Foundation
import Observation
import AppKit

@Observable
public final class PokerbeeViewModel {
    public var options: PokerbeeOptions {
        didSet {
            saveOptions()
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
            if options.isDarkMode != oldValue.isDarkMode {
                UserDefaults.standard.set(options.isDarkMode, forKey: "isDarkMode")
                NotificationCenter.default.post(name: .darkModeDidChange, object: self, userInfo: ["isDarkMode": options.isDarkMode])
            }
        }
    }

    public var state: PokerbeeGameState
    public var statistics: PokerbeeStatistics {
        didSet { saveStatistics() }
    }

    public var sessionChips: Int   // in-memory only, never persisted
    private var aiChipStacks: [Int] = []  // persists AI stacks across hands

    public var zoomScale: CGFloat = 1.0
    public var defaultZoomScale: CGFloat = 1.0

    // MARK: - Init

    public init() {
        self.state = PokerbeeGameState()
        self.options = PokerbeeOptions()
        self.statistics = PokerbeeStatistics()
        self.sessionChips = 1000

        if let data = UserDefaults.standard.data(forKey: "pokerbee_options"),
           var decoded = try? JSONDecoder().decode(PokerbeeOptions.self, from: data) {
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
            self.options = PokerbeeOptions(feltColor: globalFelt, cardBackTheme: globalCardBack)
        }

        if let data = UserDefaults.standard.data(forKey: "pokerbee_statistics"),
           let decoded = try? JSONDecoder().decode(PokerbeeStatistics.self, from: data) {
            self.statistics = decoded
        }

        self.sessionChips = options.startingChips

        NotificationCenter.default.addObserver(self, selector: #selector(handleFeltColorNotification), name: .feltColorDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCardBackThemeNotification), name: .cardBackThemeDidChange, object: nil)

        startNewHand()
    }

    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Persistence

    private func saveOptions() {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: "pokerbee_options")
        }
    }

    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "pokerbee_statistics")
        }
    }

    // MARK: - Notification handlers

    @objc private func handleFeltColorNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let theme = notification.userInfo?["feltColor"] as? FeltColorTheme else { return }
        let rev = notification.userInfo?["customFeltColorRevision"] as? Int ?? 0
        if options.feltColor != theme || options.customFeltColorRevision != rev {
            var o = options
            o.feltColor = theme
            o.customFeltColorRevision = rev
            options = o
        }
    }

    @objc private func handleCardBackThemeNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let theme = notification.userInfo?["cardBackTheme"] as? String else { return }
        if options.cardBackTheme != theme {
            options.cardBackTheme = theme
        }
    }

    // MARK: - Sound

    public func playSound(named name: String) {
        guard options.isSoundEnabled else { return }
        if let soundURL = Bundle.main.url(forResource: name, withExtension: "aiff"),
           let sound = NSSound(contentsOf: soundURL, byReference: true) {
            sound.play()
            return
        }
        let systemName: String
        switch name {
        case "shuffle": systemName = "Blow"
        case "snap":    systemName = "Tink"
        case "victory": systemName = "Hero"
        default:        systemName = name
        }
        NSSound(named: NSSound.Name(systemName))?.play()
    }

    // MARK: - New Hand

    public func startNewHand() {
        stopTimer()
        // Save AI chip stacks before clearing state
        let savedAIStacks = state.players.filter { $0.isAI }.map { $0.sessionChips }
        state = PokerbeeGameState()
        state.handNumber = statistics.handsPlayed + 1

        // Build players
        var players: [PokerbeePlayer] = []
        // Human is always seat 0
        players.append(PokerbeePlayer(name: "You", sessionChips: sessionChips, isAI: false))
        let aiCount = max(1, options.seatCount - 1)
        for i in 0..<aiCount {
            let chips = i < savedAIStacks.count ? savedAIStacks[i] : options.startingChips
            players.append(PokerbeePlayer(
                name: "AI \(i + 1)",
                sessionChips: chips,
                isAI: true,
                aiDifficulty: options.aiDifficulty
            ))
        }
        state.players = players

        // Shuffle deck
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 {
                deck.append(Card(suit: suit, rank: rank, faceUp: true))
            }
        }
        deck.shuffle()
        state.deck = deck

        // Advance dealer
        state.dealerIndex = (state.dealerIndex + 1) % players.count

        // Deal 5 cards to each player
        for i in 0..<5 {
            for j in 0..<state.players.count {
                let card = state.deck.removeFirst()
                state.players[j].hand.append(card)
                _ = i  // suppress warning
            }
        }

        playSound(named: "shuffle")

        if options.noBidMode {
            state.currentPhase = .drawing
            applyAIDiscardCards()   // AI draws before human sees the draw UI
        } else {
            // Collect antes
            for i in 0..<state.players.count {
                let ante = min(options.ante, state.players[i].sessionChips)
                state.players[i].sessionChips -= ante
                state.players[i].currentBet = ante
                state.pot += ante
            }
            // Sync human session chips
            if let humanIdx = state.humanPlayerIndex {
                sessionChips = state.players[humanIdx].sessionChips
            }
            state.currentPhase = .preDrawBetting
            state.activePlayerIndex = (state.dealerIndex + 1) % state.players.count
            statistics.handsPlayed += 1
            advanceToNextActivePlayer()
        }

        if options.noBidMode {
            statistics.handsPlayed += 1
        }
    }

    // MARK: - Betting Actions

    public func act(_ action: PokerAction) {
        guard state.isHumanTurn else { return }
        applyAction(action, playerIndex: state.activePlayerIndex)
    }

    private func applyAction(_ action: PokerAction, playerIndex: Int) {
        guard playerIndex < state.players.count else { return }

        switch action {
        case .fold:
            state.players[playerIndex].isFolded = true

        case .check:
            break

        case .call:
            let owed = state.currentBetAmount - state.players[playerIndex].currentBet
            let paid = min(owed, state.players[playerIndex].sessionChips)
            state.players[playerIndex].sessionChips -= paid
            state.players[playerIndex].currentBet += paid
            state.pot += paid
            if !state.players[playerIndex].isAI {
                sessionChips = state.players[playerIndex].sessionChips
            }

        case .raise(let amount):
            let owed = state.currentBetAmount - state.players[playerIndex].currentBet
            let total = owed + amount
            let paid = min(total, state.players[playerIndex].sessionChips)
            state.players[playerIndex].sessionChips -= paid
            state.players[playerIndex].currentBet += paid
            state.pot += paid
            state.currentBetAmount = state.players[playerIndex].currentBet
            state.lastRaiseAmount = amount
            if !state.players[playerIndex].isAI {
                sessionChips = state.players[playerIndex].sessionChips
            }

        case .discard:
            // Drawing handled separately — submitDiscards / applyAIDiscardCards manage phase transitions
            return
        }

        // Mark this player as having acted in the current round
        state.actedThisRound.insert(state.players[playerIndex].id)

        // A raise reopens action — everyone else must act again
        if case .raise = action {
            state.actedThisRound = [state.players[playerIndex].id]
        }

        if state.activePlayers.count == 1 {
            awardPotToLastPlayer()
            return
        }

        advanceTurn(from: playerIndex)
    }

    private func advanceTurn(from currentIndex: Int) {
        let phaseEnd = isBettingRoundComplete()

        if phaseEnd {
            advancePhase()
        } else {
            state.activePlayerIndex = nextActivePlayerIndex(after: currentIndex)
            if state.players[state.activePlayerIndex].isAI {
                triggerAITurn()
            }
        }
    }

    private func isBettingRoundComplete() -> Bool {
        let active = state.players.filter { !$0.isFolded }
        guard active.count > 1 else { return true }
        let allActed = active.allSatisfy { state.actedThisRound.contains($0.id) }
        let betsEqual = active.allSatisfy { $0.currentBet == state.currentBetAmount || $0.sessionChips == 0 }
        return allActed && betsEqual
    }

    private func nextActivePlayerIndex(after current: Int) -> Int {
        var next = (current + 1) % state.players.count
        var checked = 0
        while state.players[next].isFolded && checked < state.players.count {
            next = (next + 1) % state.players.count
            checked += 1
        }
        return next
    }

    private func advanceToNextActivePlayer() {
        if state.players[state.activePlayerIndex].isAI {
            triggerAITurn()
        }
    }

    private func advancePhase() {
        // Reset per-round bets and acted tracking
        for i in 0..<state.players.count {
            state.players[i].currentBet = 0
        }
        state.currentBetAmount = 0
        state.actedThisRound = []

        switch state.currentPhase {
        case .preDrawBetting:
            state.currentPhase = .drawing
            state.selectedDiscardIndices = []
            // AI players discard immediately
            triggerAIDiscards()

        case .postDrawBetting:
            showdown()

        case .drawing:
            // submitDiscards handles the .drawing → .postDrawBetting/.showdown transition directly;
            // this case is only reached in normal mode when all players folded during pre-draw betting.
            state.currentPhase = .postDrawBetting
            state.activePlayerIndex = nextActivePlayerIndex(after: state.dealerIndex)
            if state.players[state.activePlayerIndex].isAI {
                triggerAITurn()
            }

        default:
            break
        }
    }

    // MARK: - Draw Phase

    public func submitDiscards(_ indices: [Int]) {
        guard state.currentPhase == .drawing,
              let humanIdx = state.humanPlayerIndex else { return }
        // Apply human's card replacements directly
        let newCards = Array(state.deck.prefix(indices.count))
        state.deck.removeFirst(min(indices.count, state.deck.count))
        for (offset, idx) in indices.sorted().enumerated() {
            if idx < state.players[humanIdx].hand.count && offset < newCards.count {
                state.players[humanIdx].hand[idx] = newCards[offset]
            }
        }
        state.selectedDiscardIndices = []
        playSound(named: "snap")
        // Own the phase transition — never go through advanceTurn for draws
        if options.noBidMode {
            showdown()
        } else {
            state.currentPhase = .postDrawBetting
            state.activePlayerIndex = nextActivePlayerIndex(after: state.dealerIndex)
            if state.players[state.activePlayerIndex].isAI {
                triggerAITurn()
            }
        }
    }

    // Applies card replacements for all AI players without touching phase state.
    // Must be called before the human draw phase so AI hands are set when the human draws.
    private func applyAIDiscardCards() {
        for i in 0..<state.players.count {
            guard state.players[i].isAI && !state.players[i].isFolded else { continue }
            let discards = PokerAI.decideDiscards(hand: state.players[i].hand, difficulty: state.players[i].aiDifficulty)
            let newCards = Array(state.deck.prefix(discards.count))
            state.deck.removeFirst(min(discards.count, state.deck.count))
            for (offset, idx) in discards.sorted().enumerated() {
                if idx < state.players[i].hand.count && offset < newCards.count {
                    state.players[i].hand[idx] = newCards[offset]
                }
            }
        }
    }

    private func triggerAIDiscards() {
        applyAIDiscardCards()
        // In noBidMode the human still needs to draw — stay in .drawing
        guard !options.noBidMode else { return }
        state.currentPhase = .postDrawBetting
        state.activePlayerIndex = nextActivePlayerIndex(after: state.dealerIndex)
        if state.players[state.activePlayerIndex].isAI {
            triggerAITurn()
        }
    }

    // MARK: - AI Turn

    private func triggerAITurn() {
        let idx = state.activePlayerIndex
        guard idx < state.players.count, state.players[idx].isAI else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...1.2)) { [weak self] in
            guard let self = self else { return }
            guard self.state.currentPhase == .preDrawBetting || self.state.currentPhase == .postDrawBetting else { return }
            let player = self.state.players[idx]
            let callAmt = self.state.currentBetAmount - player.currentBet
            let action = PokerAI.decideAction(
                hand: player.hand,
                communityCards: [],
                pot: self.state.pot,
                callAmount: callAmt,
                difficulty: player.aiDifficulty
            )
            self.applyAction(action, playerIndex: idx)
        }
    }

    // MARK: - Showdown

    public func showdown() {
        state.currentPhase = .showdown

        let contenders = state.players.filter { !$0.isFolded }
        guard !contenders.isEmpty else {
            state.currentPhase = .handOver
            return
        }

        var bestResult: PokerHandResult? = nil
        var winners: [PokerbeePlayer] = []

        for player in contenders {
            guard player.hand.count == 5 else { continue }
            let result = PokerHandEvaluator.evaluate(player.hand)
            if bestResult == nil || result > bestResult! {
                bestResult = result
                winners = [player]
            } else if result == bestResult! {
                winners.append(player)
            }
        }

        let share = winners.isEmpty ? 0 : state.pot / winners.count

        for winner in winners {
            if let idx = state.players.firstIndex(where: { $0.id == winner.id }) {
                state.players[idx].sessionChips += share
                if !state.players[idx].isAI {
                    sessionChips = state.players[idx].sessionChips
                    statistics.handsWon += 1
                    statistics.biggestPotWon = max(statistics.biggestPotWon, share)
                }
            }
        }

        state.lastWinnerName = winners.count == 1 ? winners[0].name : "Split pot"
        state.lastWinningHand = bestResult?.rank.displayName
        state.pot = 0
        state.currentPhase = .handOver
        playSound(named: "victory")
    }

    // MARK: - Rebuy

    public func rebuy() {
        sessionChips += options.startingChips
        statistics.rebuyCount += 1
        if let idx = state.humanPlayerIndex {
            state.players[idx].sessionChips = sessionChips
        }
    }

    // MARK: - Pot award when everyone else folds

    private func awardPotToLastPlayer() {
        guard let winner = state.activePlayers.first,
              let idx = state.players.firstIndex(where: { $0.id == winner.id }) else { return }
        state.players[idx].sessionChips += state.pot
        if !state.players[idx].isAI {
            sessionChips = state.players[idx].sessionChips
            statistics.handsWon += 1
        }
        state.lastWinnerName = winner.name
        state.lastWinningHand = "All others folded"
        state.pot = 0
        state.currentPhase = .handOver
    }

    // MARK: - Timer

    private var timer: Timer?

    public func startTimerIfNeeded() {
        guard options.isTimed, !state.isTimerActive else { return }
        state.isTimerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.state.timerSeconds += 1
        }
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
        state.isTimerActive = false
    }

    // MARK: - Statistics

    public func resetStatistics() {
        statistics = PokerbeeStatistics()
    }

    // MARK: - Zoom (stubbed for AppCoordinator compatibility)

    public func zoomIn()  {}
    public func zoomOut() {}
    public func resetZoom() {}
    public func makeCurrentZoomDefault() {}
    public var canUndo: Bool { false }
    public func undoLastAction() {}
    public func restartCurrentGame() { startNewHand() }
    public func startNewGame() { startNewHand() }
}
