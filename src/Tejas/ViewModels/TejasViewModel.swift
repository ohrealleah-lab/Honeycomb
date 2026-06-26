import Foundation
import Observation
import AppKit

@Observable
public final class TejasViewModel {
    public var options: TejasOptions {
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

    public var state: TejasGameState
    public var statistics: TejasStatistics {
        didSet { saveStatistics() }
    }

    public var sessionChips: Int   // in-memory only

    public var zoomScale: CGFloat = 1.0
    public var defaultZoomScale: CGFloat = 1.0

    // MARK: - Init

    public init() {
        self.state = TejasGameState()
        self.options = TejasOptions()
        self.statistics = TejasStatistics()
        self.sessionChips = 1000

        if let data = UserDefaults.standard.data(forKey: "tejas_options"),
           var decoded = try? JSONDecoder().decode(TejasOptions.self, from: data) {
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
            self.options = TejasOptions(feltColor: globalFelt, cardBackTheme: globalCardBack)
        }

        if let data = UserDefaults.standard.data(forKey: "tejas_statistics"),
           let decoded = try? JSONDecoder().decode(TejasStatistics.self, from: data) {
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
            UserDefaults.standard.set(data, forKey: "tejas_options")
        }
    }

    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "tejas_statistics")
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
        state = TejasGameState()
        state.handNumber = statistics.handsPlayed + 1

        // Build players
        var players: [TejasPlayer] = []
        players.append(TejasPlayer(name: "You", sessionChips: sessionChips, isAI: false))
        let aiCount = max(1, options.seatCount - 1)
        for i in 0..<aiCount {
            players.append(TejasPlayer(
                name: "AI \(i + 1)",
                sessionChips: options.startingChips,
                isAI: true,
                aiDifficulty: options.aiDifficulty
            ))
        }

        // Rotate dealer
        state.dealerIndex = (state.dealerIndex + 1) % players.count
        players[state.dealerIndex].isDealer = true
        state.players = players

        // Post blinds (skipped in no-bet mode)
        if options.noBetMode {
            state.minimumBet = 0
            state.lastRaiseAmount = 0
        } else {
            let sbIdx = (state.dealerIndex + 1) % players.count
            let bbIdx = (state.dealerIndex + 2) % players.count

            let sbAmount = min(options.smallBlind, state.players[sbIdx].sessionChips)
            state.players[sbIdx].sessionChips -= sbAmount
            state.players[sbIdx].currentBet = sbAmount
            state.players[sbIdx].totalBetThisRound = sbAmount
            state.pot += sbAmount

            let bbAmount = min(options.bigBlind, state.players[bbIdx].sessionChips)
            state.players[bbIdx].sessionChips -= bbAmount
            state.players[bbIdx].currentBet = bbAmount
            state.players[bbIdx].totalBetThisRound = bbAmount
            state.pot += bbAmount

            state.minimumBet = bbAmount
            state.lastRaiseAmount = bbAmount
        }

        // Sync human chips
        if let humanIdx = state.humanPlayerIndex {
            sessionChips = state.players[humanIdx].sessionChips
        }

        // Shuffle and deal hole cards
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 {
                deck.append(Card(suit: suit, rank: rank, faceUp: false))
            }
        }
        deck.shuffle()
        state.deck = deck

        // Deal 2 hole cards per player, human cards face-up
        for j in 0..<state.players.count {
            for _ in 0..<2 {
                var card = state.deck.removeFirst()
                card = Card(id: card.id, suit: card.suit, rank: card.rank, faceUp: !state.players[j].isAI)
                state.players[j].holeCards.append(card)
            }
        }

        playSound(named: "shuffle")
        statistics.handsPlayed += 1
        state.currentPhase = .preFlop

        // Under the gun acts first
        let utgIdx = (state.dealerIndex + 3) % state.players.count
        state.activePlayerIndex = utgIdx
        state.actedThisRound = []

        if state.players[state.activePlayerIndex].isAI {
            triggerAITurn()
        }
    }

    // MARK: - Betting Action

    public func act(_ action: PokerAction) {
        guard state.isHumanTurn else { return }
        applyAction(action, playerIndex: state.activePlayerIndex)
    }

    private func applyAction(_ action: PokerAction, playerIndex: Int) {
        guard playerIndex < state.players.count else { return }
        let player = state.players[playerIndex]

        switch action {
        case .fold:
            state.players[playerIndex].isFolded = true
            state.actedThisRound.insert(player.id)

        case .check:
            state.actedThisRound.insert(player.id)

        case .call:
            let owed = state.minimumBet - player.currentBet
            let paid = min(owed, player.sessionChips)
            state.players[playerIndex].sessionChips -= paid
            state.players[playerIndex].currentBet += paid
            state.players[playerIndex].totalBetThisRound += paid
            state.pot += paid
            if paid >= player.sessionChips {
                state.players[playerIndex].isAllIn = true
                state.buildSidePots()
            }
            syncHumanChips(playerIndex: playerIndex)
            state.actedThisRound.insert(player.id)

        case .raise(let amount):
            let callOwed = state.minimumBet - player.currentBet
            let total = callOwed + amount
            let paid = min(total, player.sessionChips)
            state.players[playerIndex].sessionChips -= paid
            state.players[playerIndex].currentBet += paid
            state.players[playerIndex].totalBetThisRound += paid
            state.pot += paid
            state.minimumBet = state.players[playerIndex].currentBet
            state.lastRaiseAmount = amount
            if state.players[playerIndex].sessionChips == 0 {
                state.players[playerIndex].isAllIn = true
                state.buildSidePots()
            }
            syncHumanChips(playerIndex: playerIndex)
            // Re-open action to all active players
            state.actedThisRound = [player.id]

        case .discard:
            break  // Tejas doesn't use discards
        }

        if state.contestingPlayers.count == 1 {
            awardPotToLastPlayer()
            return
        }

        if isBettingRoundComplete() {
            advanceStreet()
        } else {
            state.activePlayerIndex = nextActivePlayerIndex(after: playerIndex)
            if state.players[state.activePlayerIndex].isAI {
                triggerAITurn()
            }
        }
    }

    private func syncHumanChips(playerIndex: Int) {
        if !state.players[playerIndex].isAI {
            sessionChips = state.players[playerIndex].sessionChips
        }
    }

    private func isBettingRoundComplete() -> Bool {
        let eligible = state.players.filter { !$0.isFolded && !$0.isAllIn }
        guard !eligible.isEmpty else { return true }
        let allActed = eligible.allSatisfy { state.actedThisRound.contains($0.id) }
        let allMatched = eligible.allSatisfy { $0.currentBet == state.minimumBet }
        return allActed && allMatched
    }

    private func nextActivePlayerIndex(after current: Int) -> Int {
        var next = (current + 1) % state.players.count
        var checked = 0
        while (state.players[next].isFolded || state.players[next].isAllIn) && checked < state.players.count {
            next = (next + 1) % state.players.count
            checked += 1
        }
        return next
    }

    // MARK: - Street Advancement

    private func advanceStreet() {
        // Reset per-round bets and acted set
        for i in 0..<state.players.count {
            state.players[i].currentBet = 0
            state.players[i].totalBetThisRound = 0
        }
        state.minimumBet = 0
        state.actedThisRound = []

        switch state.currentPhase {
        case .preFlop:
            dealCommunityCards(count: 3, burnFirst: true)
            state.currentPhase = .flop
            playSound(named: "snap")
        case .flop:
            dealCommunityCards(count: 1, burnFirst: true)
            state.currentPhase = .turn
            playSound(named: "snap")
        case .turn:
            dealCommunityCards(count: 1, burnFirst: true)
            state.currentPhase = .river
            playSound(named: "snap")
        case .river:
            showdown()
            return
        default:
            return
        }

        // Set first-to-act to left of dealer
        let firstIdx = (state.dealerIndex + 1) % state.players.count
        state.activePlayerIndex = firstActingPlayer(from: firstIdx)
        if state.players[state.activePlayerIndex].isAI {
            triggerAITurn()
        }
    }

    private func firstActingPlayer(from start: Int) -> Int {
        var idx = start
        var checked = 0
        while (state.players[idx].isFolded || state.players[idx].isAllIn) && checked < state.players.count {
            idx = (idx + 1) % state.players.count
            checked += 1
        }
        return idx
    }

    // MARK: - Community Cards

    public func dealCommunityCards(count: Int, burnFirst: Bool) {
        if burnFirst && !state.deck.isEmpty {
            state.deck.removeFirst()   // burn card
        }
        for _ in 0..<count {
            guard !state.deck.isEmpty else { break }
            var card = state.deck.removeFirst()
            card = Card(id: card.id, suit: card.suit, rank: card.rank, faceUp: true)
            state.communityCards.append(card)
        }
    }

    // MARK: - AI Turn

    private func triggerAITurn() {
        let idx = state.activePlayerIndex
        guard idx < state.players.count, state.players[idx].isAI else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.6...1.4)) { [weak self] in
            guard let self = self else { return }
            guard [TejasGameState.Phase.preFlop, .flop, .turn, .river].contains(self.state.currentPhase) else { return }
            let player = self.state.players[idx]

            // No-bet mode: AI always checks
            if self.options.noBetMode {
                self.applyAction(.check, playerIndex: idx)
                return
            }

            let callAmt = self.state.minimumBet - player.currentBet
            let minRaise = max(self.state.lastRaiseAmount, self.options.bigBlind)
            let action = PokerAI.decideAction(
                hand: player.holeCards,
                communityCards: self.state.communityCards,
                pot: self.state.pot,
                callAmount: callAmt,
                difficulty: player.aiDifficulty
            )
            // Enforce minimum raise
            let resolvedAction: PokerAction
            if case .raise(let amt) = action {
                resolvedAction = .raise(max(amt, minRaise))
            } else {
                resolvedAction = action
            }
            self.applyAction(resolvedAction, playerIndex: idx)
        }
    }

    // MARK: - Showdown

    public func showdown() {
        state.currentPhase = .showdown

        // Flip AI hole cards
        for i in 0..<state.players.count {
            if state.players[i].isAI {
                for j in 0..<state.players[i].holeCards.count {
                    state.players[i].holeCards[j] = Card(
                        id: state.players[i].holeCards[j].id,
                        suit: state.players[i].holeCards[j].suit,
                        rank: state.players[i].holeCards[j].rank,
                        faceUp: true
                    )
                }
            }
        }

        let contenders = state.players.filter { !$0.isFolded }
        guard !contenders.isEmpty else { state.currentPhase = .handOver; return }

        // Evaluate each player
        var playerResults: [(player: TejasPlayer, result: PokerHandResult)] = []
        for player in contenders {
            guard player.holeCards.count == 2 && state.communityCards.count >= 3 else { continue }
            let allCards = player.holeCards + state.communityCards
            let result: PokerHandResult
            if allCards.count >= 7 {
                result = PokerHandEvaluator.bestFiveOfSeven(hole: player.holeCards, community: state.communityCards)
            } else {
                let five = Array(allCards.prefix(5))
                result = five.count == 5 ? PokerHandEvaluator.evaluate(five) : PokerHandResult(rank: .highCard, kickers: [])
            }
            playerResults.append((player, result))
        }

        guard !playerResults.isEmpty else { state.currentPhase = .handOver; return }

        // Main pot winner
        let bestResult = playerResults.map { $0.result }.max()!
        let winners = playerResults.filter { $0.result == bestResult }.map { $0.player }

        // Award side pots first
        for sidePot in state.sidePots {
            let potWinners = playerResults.filter { sidePot.eligiblePlayerIDs.contains($0.player.id) }
            guard !potWinners.isEmpty else { continue }
            let potBest = potWinners.map { $0.result }.max()!
            let potWinnerPlayers = potWinners.filter { $0.result == potBest }.map { $0.player }
            let share = sidePot.amount / potWinnerPlayers.count
            for w in potWinnerPlayers {
                if let idx = state.players.firstIndex(where: { $0.id == w.id }) {
                    state.players[idx].sessionChips += share
                    if !state.players[idx].isAI {
                        sessionChips = state.players[idx].sessionChips
                    }
                }
            }
        }

        // Remaining main pot
        let sideTotal = state.sidePots.reduce(0) { $0 + $1.amount }
        let mainPot = state.pot - sideTotal
        let mainShare = mainPot / max(1, winners.count)
        for winner in winners {
            if let idx = state.players.firstIndex(where: { $0.id == winner.id }) {
                state.players[idx].sessionChips += mainShare
                if !state.players[idx].isAI {
                    sessionChips = state.players[idx].sessionChips
                    statistics.handsWon += 1
                    statistics.biggestPotWon = max(statistics.biggestPotWon, mainShare)
                }
            }
        }

        state.lastWinnerName = winners.count == 1 ? winners[0].name : "Split pot"
        state.lastWinningHand = bestResult.rank.displayName
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

    private func awardPotToLastPlayer() {
        guard let winner = state.contestingPlayers.first,
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
        statistics = TejasStatistics()
    }

    // MARK: - AppCoordinator compatibility stubs

    public func zoomIn()  {}
    public func zoomOut() {}
    public func resetZoom() {}
    public func makeCurrentZoomDefault() {}
    public var canUndo: Bool { false }
    public func undoLastAction() {}
    public func restartCurrentGame() { startNewHand() }
    public func startNewGame() { startNewHand() }
}
