import Foundation
import Observation
import AppKit

@Observable
public final class BlackjackViewModel {

    public var options: BlackjackOptions {
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

    public var state: BlackjackState
    public var statistics: BlackjackStatistics {
        didSet { saveStatistics() }
    }
    public var consecutiveWins: Int = 0

    // MARK: - Init

    public init() {
        self.state = BlackjackState()
        self.options = BlackjackOptions()
        self.statistics = BlackjackStatistics()

        if let data = UserDefaults.standard.data(forKey: "blackjack_options"),
           var decoded = try? JSONDecoder().decode(BlackjackOptions.self, from: data) {
            if let back = UserDefaults.standard.string(forKey: "cardBackTheme") { decoded.cardBackTheme = back }
            if let feltStr = UserDefaults.standard.string(forKey: "global_felt_color"),
               let felt = FeltColorTheme(rawValue: feltStr) { decoded.feltColor = felt }
            if UserDefaults.standard.object(forKey: "showFeltVignette") != nil {
                decoded.showFeltVignette = UserDefaults.standard.bool(forKey: "showFeltVignette")
            }
            if let dataColors = UserDefaults.standard.data(forKey: "customCardColors"),
               let colors = try? JSONDecoder().decode(CustomCardColorGroup.self, from: dataColors) {
                decoded.customCardColors = colors
            }
            self.options = decoded
        } else {
            let back = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Vulpera"
            let feltStr = UserDefaults.standard.string(forKey: "global_felt_color") ?? FeltColorTheme.feltGreen.rawValue
            let felt = FeltColorTheme(rawValue: feltStr) ?? .feltGreen
            var opts = BlackjackOptions(feltColor: felt, cardBackTheme: back)
            if UserDefaults.standard.object(forKey: "showFeltVignette") != nil {
                opts.showFeltVignette = UserDefaults.standard.bool(forKey: "showFeltVignette")
            }
            if let dataColors = UserDefaults.standard.data(forKey: "customCardColors"),
               let colors = try? JSONDecoder().decode(CustomCardColorGroup.self, from: dataColors) {
                opts.customCardColors = colors
            }
            self.options = opts
        }

        if let data = UserDefaults.standard.data(forKey: "blackjack_statistics"),
           let decoded = try? JSONDecoder().decode(BlackjackStatistics.self, from: data) {
            self.statistics = decoded
        }

        state.sessionCredits = options.startingCredits
        state.currentBet = options.betPerHand

        NotificationCenter.default.addObserver(self, selector: #selector(handleFeltColorNotification), name: .feltColorDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCardBackThemeNotification), name: .cardBackThemeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCustomCardColorsNotification), name: .customCardColorsDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Persistence

    private func saveOptions() {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: "blackjack_options")
        }
    }

    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "blackjack_statistics")
        }
    }

    // MARK: - Notification handlers

    @objc private func handleFeltColorNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let theme = notification.userInfo?["feltColor"] as? FeltColorTheme else { return }
        let rev = notification.userInfo?["customFeltColorRevision"] as? Int ?? 0
        if options.feltColor != theme || options.customFeltColorRevision != rev {
            var o = options; o.feltColor = theme; o.customFeltColorRevision = rev; options = o
        }
    }

    @objc private func handleCardBackThemeNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let theme = notification.userInfo?["cardBackTheme"] as? String else { return }
        if options.cardBackTheme != theme { options.cardBackTheme = theme }
    }

    @objc private func handleCustomCardColorsNotification(_ notification: Notification) {
        guard let sender = notification.object as? AnyObject, sender !== self else { return }
        guard let colors = notification.userInfo?["customCardColors"] as? CustomCardColorGroup else { return }
        if self.options.customCardColors != colors {
            self.options.customCardColors = colors
        }
    }

    // MARK: - Computed properties

    public var canSplit: Bool {
        state.playerHands.count == 1
        && state.playerHands[0].cards.count == 2
        && state.playerHands[0].cards[0].rank == state.playerHands[0].cards[1].rank
        && state.sessionCredits >= state.currentBet
    }

    public var canDouble: Bool {
        guard state.activeHandIndex < state.playerHands.count else { return false }
        let hand = state.playerHands[state.activeHandIndex]
        return hand.cards.count == 2 && state.sessionCredits >= hand.bet
    }

    public var activeHand: BlackjackHand? {
        guard state.activeHandIndex < state.playerHands.count else { return nil }
        return state.playerHands[state.activeHandIndex]
    }

    // MARK: - Deck helpers

    private func freshDeck() -> [Card] {
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 {
                deck.append(Card(suit: suit, rank: rank, faceUp: true))
            }
        }
        deck.shuffle()
        return deck
    }

    private func popCard(faceUp: Bool = true) -> Card? {
        guard !state.deck.isEmpty else { return nil }
        var card = state.deck[state.deck.count - 1]
        state.deck.removeLast()
        card = Card(id: card.id, suit: card.suit, rank: card.rank, faceUp: faceUp)
        return card
    }

    // MARK: - Game flow

    public func deal() {
        guard state.phase == .betting || state.phase == .result else { return }
        guard state.sessionCredits >= state.currentBet else { return }

        state.sessionCredits -= state.currentBet
        statistics.totalWagered += state.currentBet
        statistics.handsPlayed += 1
        state.handsDealt += 1

        state.deck = freshDeck()
        playSound(named: "shuffle")

        // Deal: player card, dealer card, player card, dealer hole card (face-down)
        guard let p1 = popCard(faceUp: true),
              let d1 = popCard(faceUp: true),
              let p2 = popCard(faceUp: true),
              let d2 = popCard(faceUp: false) else { return }

        state.playerHands = [BlackjackHand(cards: [p1, p2], bet: state.currentBet)]
        state.dealerCards = [d1, d2]
        state.activeHandIndex = 0
        state.lastResultSummary = ""
        state.phase = .playing

        // Check for player blackjack — delay so the player can see their cards first
        if state.playerHands[0].isBlackjack {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.executeDealerTurn()
            }
        }
    }

    public func hit() {
        guard state.phase == .playing else { return }
        guard state.activeHandIndex < state.playerHands.count else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        guard let card = popCard(faceUp: true) else { return }

        playSound(named: "snap")
        state.playerHands[state.activeHandIndex].cards.append(card)

        if state.playerHands[state.activeHandIndex].isBust {
            advanceHand()
        }
    }

    public func stand() {
        guard state.phase == .playing else { return }
        guard state.activeHandIndex < state.playerHands.count else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        advanceHand()
    }

    public func doubleDown() {
        guard state.phase == .playing else { return }
        guard canDouble else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        let hand = state.playerHands[state.activeHandIndex]
        state.sessionCredits -= hand.bet
        statistics.totalWagered += hand.bet
        state.playerHands[state.activeHandIndex].bet *= 2
        state.playerHands[state.activeHandIndex].isDoubled = true

        if let card = popCard(faceUp: true) {
            playSound(named: "snap")
            state.playerHands[state.activeHandIndex].cards.append(card)
        }
        advanceHand()
    }

    public func split() {
        guard state.phase == .playing, canSplit else { return }
        guard !(state.playerHands.count == 1 && state.playerHands[0].isBlackjack) else { return }
        let originalBet = state.playerHands[0].bet
        state.sessionCredits -= originalBet
        statistics.totalWagered += originalBet

        let card0 = state.playerHands[0].cards[0]
        let card1 = state.playerHands[0].cards[1]

        // Draw a second card for each split hand
        let extra0 = popCard(faceUp: true) ?? card0
        let extra1 = popCard(faceUp: true) ?? card1

        state.playerHands = [
            BlackjackHand(cards: [card0, extra0], bet: originalBet),
            BlackjackHand(cards: [card1, extra1], bet: originalBet)
        ]
        state.activeHandIndex = 0
        playSound(named: "snap")
    }

    public func maxBet() {
        state.currentBet = max(1, min(5, state.sessionCredits))
        if state.phase == .betting || state.phase == .result { deal() }
    }

    public func increaseBet() {
        guard state.phase == .betting || state.phase == .result else { return }
        state.currentBet = min(5, state.currentBet + 1)
    }

    public func decreaseBet() {
        guard state.phase == .betting || state.phase == .result else { return }
        state.currentBet = max(1, state.currentBet - 1)
    }

    public func rebuy() {
        state.sessionCredits += options.startingCredits
        statistics.rebuyCount += 1
    }

    private func advanceHand() {
        let next = state.activeHandIndex + 1
        if next < state.playerHands.count {
            state.activeHandIndex = next
        } else {
            executeDealerTurn()
        }
    }

    public func executeDealerTurn() {
        state.phase = .dealerTurn

        // Reveal hole card
        if state.dealerCards.indices.contains(1) {
            let c = state.dealerCards[1]
            state.dealerCards[1] = Card(id: c.id, suit: c.suit, rank: c.rank, faceUp: true)
        }

        // Dealer hits until 17+
        while BlackjackState.handValue(state.dealerCards) < 17 {
            if let card = popCard(faceUp: true) {
                state.dealerCards.append(card)
                playSound(named: "snap")
            } else { break }
        }

        evaluateAllHands()
        state.phase = .result
    }

    private func evaluateAllHands() {
        let dealerValue = BlackjackState.handValue(state.dealerCards)
        let dealerBJ = state.dealerCards.count == 2 && dealerValue == 21
        var summaryParts: [String] = []
        var totalPayout = 0
        var totalWagered = 0

        for i in 0..<state.playerHands.count {
            let hand = state.playerHands[i]
            totalWagered += hand.bet
            let playerValue = hand.value
            let playerBJ = hand.isBlackjack && state.playerHands.count == 1  // BJ only counts on unsplit hand

            let result: BlackjackHandResult
            var payout = 0

            if playerBJ && dealerBJ {
                // Both have blackjack — push
                result = .push
                payout = hand.bet
                statistics.pushes += 1
            } else if playerBJ {
                // Blackjack pays 3:2
                result = .blackjack
                payout = hand.bet + Int(Double(hand.bet) * 1.5)
                statistics.blackjacks += 1
                statistics.handsWon += 1
                playSound(named: "victory")
            } else if hand.isBust {
                result = .bust
                statistics.handsLost += 1
            } else if dealerBJ || (!hand.isBust && dealerValue > playerValue && dealerValue <= 21) {
                result = .loss
                statistics.handsLost += 1
            } else if dealerValue > 21 || playerValue > dealerValue {
                result = .win
                payout = hand.bet * 2
                statistics.handsWon += 1
                if totalPayout == 0 { playSound(named: "victory") }
            } else {
                result = .push
                payout = hand.bet  // return original bet
                statistics.pushes += 1
            }

            state.playerHands[i].result = result
            state.sessionCredits += payout
            totalPayout += payout
            statistics.totalPaidOut += payout
            statistics.biggestPayout = max(statistics.biggestPayout, payout)

            let label: String
            switch result {
            case .blackjack: label = "Blackjack! 🃏"
            case .win:       label = state.playerHands.count > 1 ? "Hand \(i+1): Win" : "You Win!"
            case .loss:      label = state.playerHands.count > 1 ? "Hand \(i+1): Loss" : "Dealer Wins"
            case .push:      label = state.playerHands.count > 1 ? "Hand \(i+1): Push" : "Push"
            case .bust:      label = state.playerHands.count > 1 ? "Hand \(i+1): Bust" : "Bust!"
            }
            summaryParts.append(label)
        }

        state.lastResultSummary = summaryParts.joined(separator: "  ·  ")
        state.lastNetResult = totalPayout - totalWagered
        
        let roundWon = state.playerHands.contains { $0.result == .win || $0.result == .blackjack }
        let roundLost = state.playerHands.contains { $0.result == .loss || $0.result == .bust }
        if roundWon && !roundLost {
            consecutiveWins += 1
        } else if roundLost {
            consecutiveWins = 0
        }
    }


    // MARK: - Sound

    public func playSound(named name: String) {
        guard options.isSoundEnabled else { return }
        if let url = Bundle.main.url(forResource: name, withExtension: "aiff"),
           let sound = NSSound(contentsOf: url, byReference: true) { sound.play(); return }
        let sys: String
        switch name {
        case "shuffle": sys = "Blow"
        case "snap":    sys = "Tink"
        case "victory": sys = "Hero"
        default:        sys = name
        }
        NSSound(named: NSSound.Name(sys))?.play()
    }

    // MARK: - Statistics / AppCoordinator stubs

    public func resetStatistics() {
        statistics = BlackjackStatistics()
    }

    public func startNewGame() {
        state = BlackjackState()
        state.sessionCredits = options.startingCredits
        state.currentBet = options.betPerHand
        consecutiveWins = 0
    }

    public func restartCurrentGame() { startNewGame() }
    public func undoLastAction() {}
    public var canUndo: Bool { false }
    public func zoomIn() {}
    public func zoomOut() {}
    public func resetZoom() {}
    public func makeCurrentZoomDefault() {}
}
