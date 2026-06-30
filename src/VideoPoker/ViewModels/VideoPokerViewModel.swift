import Foundation
import Observation
import AppKit

@Observable
public final class VideoPokerViewModel {

    public var options: VideoPokerOptions {
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

    public var state: VideoPokerState
    public var statistics: VideoPokerStatistics {
        didSet { saveStatistics() }
    }

    // MARK: - Pay table (Jacks or Better 9/6 full-pay by default)

    public var payTable: [VideoPokerPayEntry] {
        switch options.variant {
        case .jacksOrBetter: return Self.jacksOrBetterTable
        case .deucesWild:    return Self.deucesWildTable
        case .bonusPoker:    return Self.bonusPokerTable
        }
    }

    // Jacks or Better 9/6: multipliers for 1–5 coin bets
    private static let jacksOrBetterTable: [VideoPokerPayEntry] = [
        VideoPokerPayEntry(handName: "Royal Flush",      rank: .royalFlush,    qualifier: .none, multipliers: [250, 250, 250, 250, 800]),
        VideoPokerPayEntry(handName: "Straight Flush",   rank: .straightFlush, qualifier: .none, multipliers: [50,  50,  50,  50,  50 ]),
        VideoPokerPayEntry(handName: "Four of a Kind",   rank: .fourOfAKind,   qualifier: .none, multipliers: [25,  25,  25,  25,  25 ]),
        VideoPokerPayEntry(handName: "Full House",       rank: .fullHouse,     qualifier: .none, multipliers: [9,   9,   9,   9,   9  ]),
        VideoPokerPayEntry(handName: "Flush",            rank: .flush,         qualifier: .none, multipliers: [6,   6,   6,   6,   6  ]),
        VideoPokerPayEntry(handName: "Straight",         rank: .straight,      qualifier: .none, multipliers: [4,   4,   4,   4,   4  ]),
        VideoPokerPayEntry(handName: "Three of a Kind",  rank: .threeOfAKind,  qualifier: .none, multipliers: [3,   3,   3,   3,   3  ]),
        VideoPokerPayEntry(handName: "Two Pair",         rank: .twoPair,       qualifier: .none, multipliers: [2,   2,   2,   2,   2  ]),
        VideoPokerPayEntry(handName: "Jacks or Better",  rank: .onePair,       qualifier: .jacksOrBetter, multipliers: [1, 1, 1, 1, 1]),
    ]

    // Deuces Wild: 2s are wild; minimum paying hand is three-of-a-kind
    private static let deucesWildTable: [VideoPokerPayEntry] = [
        VideoPokerPayEntry(handName: "Natural Royal Flush",  rank: .royalFlush,    qualifier: .none, multipliers: [250, 250, 250, 250, 800]),
        VideoPokerPayEntry(handName: "Four Deuces",          rank: .fourOfAKind,   qualifier: .bonusFours(rank: 2), multipliers: [200, 200, 200, 200, 200]),
        VideoPokerPayEntry(handName: "Wild Royal Flush",     rank: .royalFlush,    qualifier: .deucesWild, multipliers: [25, 25, 25, 25, 25]),
        VideoPokerPayEntry(handName: "Five of a Kind",       rank: .fourOfAKind,   qualifier: .deucesWild, multipliers: [15, 15, 15, 15, 15]),
        VideoPokerPayEntry(handName: "Straight Flush",       rank: .straightFlush, qualifier: .none, multipliers: [9, 9, 9, 9, 9]),
        VideoPokerPayEntry(handName: "Four of a Kind",       rank: .fourOfAKind,   qualifier: .none, multipliers: [5, 5, 5, 5, 5]),
        VideoPokerPayEntry(handName: "Full House",           rank: .fullHouse,     qualifier: .none, multipliers: [3, 3, 3, 3, 3]),
        VideoPokerPayEntry(handName: "Flush",                rank: .flush,         qualifier: .none, multipliers: [2, 2, 2, 2, 2]),
        VideoPokerPayEntry(handName: "Straight",             rank: .straight,      qualifier: .none, multipliers: [2, 2, 2, 2, 2]),
        VideoPokerPayEntry(handName: "Three of a Kind",      rank: .threeOfAKind,  qualifier: .none, multipliers: [1, 1, 1, 1, 1]),
    ]

    // Bonus Poker: extra payouts for four aces / four 2-4s
    private static let bonusPokerTable: [VideoPokerPayEntry] = [
        VideoPokerPayEntry(handName: "Royal Flush",       rank: .royalFlush,    qualifier: .none, multipliers: [250, 250, 250, 250, 800]),
        VideoPokerPayEntry(handName: "Straight Flush",    rank: .straightFlush, qualifier: .none, multipliers: [50,  50,  50,  50,  50 ]),
        VideoPokerPayEntry(handName: "Four Aces",         rank: .fourOfAKind,   qualifier: .bonusFours(rank: 1),  multipliers: [80, 80, 80, 80, 80]),
        VideoPokerPayEntry(handName: "Four 2s–4s",        rank: .fourOfAKind,   qualifier: .bonusFours(rank: 4),  multipliers: [40, 40, 40, 40, 40]),
        VideoPokerPayEntry(handName: "Four of a Kind",    rank: .fourOfAKind,   qualifier: .none, multipliers: [25, 25, 25, 25, 25]),
        VideoPokerPayEntry(handName: "Full House",        rank: .fullHouse,     qualifier: .none, multipliers: [8,  8,  8,  8,  8 ]),
        VideoPokerPayEntry(handName: "Flush",             rank: .flush,         qualifier: .none, multipliers: [5,  5,  5,  5,  5 ]),
        VideoPokerPayEntry(handName: "Straight",          rank: .straight,      qualifier: .none, multipliers: [4,  4,  4,  4,  4 ]),
        VideoPokerPayEntry(handName: "Three of a Kind",   rank: .threeOfAKind,  qualifier: .none, multipliers: [3,  3,  3,  3,  3 ]),
        VideoPokerPayEntry(handName: "Two Pair",          rank: .twoPair,       qualifier: .none, multipliers: [2,  2,  2,  2,  2 ]),
        VideoPokerPayEntry(handName: "Jacks or Better",   rank: .onePair,       qualifier: .jacksOrBetter, multipliers: [1, 1, 1, 1, 1]),
    ]

    // MARK: - Init

    public init() {
        self.state = VideoPokerState()
        self.options = VideoPokerOptions()
        self.statistics = VideoPokerStatistics()

        if let data = UserDefaults.standard.data(forKey: "videopoker_options"),
           var decoded = try? JSONDecoder().decode(VideoPokerOptions.self, from: data) {
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
            var opts = VideoPokerOptions(feltColor: felt, cardBackTheme: back)
            if UserDefaults.standard.object(forKey: "showFeltVignette") != nil {
                opts.showFeltVignette = UserDefaults.standard.bool(forKey: "showFeltVignette")
            }
            if let dataColors = UserDefaults.standard.data(forKey: "customCardColors"),
               let colors = try? JSONDecoder().decode(CustomCardColorGroup.self, from: dataColors) {
                opts.customCardColors = colors
            }
            self.options = opts
        }

        if let data = UserDefaults.standard.data(forKey: "videopoker_statistics"),
           let decoded = try? JSONDecoder().decode(VideoPokerStatistics.self, from: data) {
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
            UserDefaults.standard.set(data, forKey: "videopoker_options")
        }
    }

    private func saveStatistics() {
        if let data = try? JSONEncoder().encode(statistics) {
            UserDefaults.standard.set(data, forKey: "videopoker_statistics")
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

    // MARK: - Game flow

    public func deal() {
        guard state.phase == .deal || state.phase == .result else { return }
        guard state.sessionCredits >= state.currentBet else { return }

        state.sessionCredits -= state.currentBet
        statistics.totalWagered += state.currentBet
        statistics.handsPlayed += 1
        state.handsDealt += 1
        state.lastPayout = 0
        state.lastHandName = ""
        state.heldIndices = []

        // Fresh shuffled deck
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 { deck.append(Card(suit: suit, rank: rank, faceUp: true)) }
        }
        deck.shuffle()
        state.deck = deck
        state.hand = Array(deck.prefix(5))
        state.deck.removeFirst(5)

        state.phase = .holding
        playSound(named: "shuffle")
    }

    public func toggleHold(at index: Int) {
        guard state.phase == .holding, index < 5 else { return }
        if state.heldIndices.contains(index) {
            state.heldIndices.remove(index)
        } else {
            state.heldIndices.insert(index)
        }
    }

    public func draw() {
        guard state.phase == .holding else { return }

        // Replace non-held cards
        for i in 0..<5 {
            if !state.heldIndices.contains(i) {
                if let replacement = state.deck.first {
                    state.hand[i] = replacement
                    state.deck.removeFirst()
                }
            }
        }

        playSound(named: "snap")
        evaluate()
        state.phase = .result
    }

    // MARK: - Hand evaluation against pay table

    private func evaluate() {
        guard state.hand.count == 5 else { return }

        let hand = state.hand
        let result = options.variant == .deucesWild
            ? PokerHandEvaluator.evaluateWithDeuces(hand)
            : PokerHandEvaluator.evaluate(hand)

        // Walk the pay table from top (best) to bottom and find first match
        for entry in payTable {
            if matches(result: result, hand: hand, entry: entry) {
                let payout = entry.payout(bet: state.currentBet)
                state.lastHandName = entry.handName
                state.lastPayout = payout
                if payout > 0 {
                    state.sessionCredits += payout
                    statistics.handsWon += 1
                    statistics.totalPaidOut += payout
                    statistics.biggestPayout = max(statistics.biggestPayout, payout)
                    if entry.rank == .royalFlush { statistics.royalFlushCount += 1 }
                    playSound(named: "victory")
                }
                return
            }
        }

        state.lastHandName = "No Win"
        state.lastPayout = 0
    }

    private func matches(result: PokerHandResult, hand: [Card], entry: VideoPokerPayEntry) -> Bool {
        guard result.rank == entry.rank else { return false }

        switch entry.qualifier {
        case .none:
            return true

        case .jacksOrBetter:
            // Pair must be J (11), Q (12), K (13), or A (1)
            guard result.rank == .onePair else { return false }
            let qualifyingRanks: Set<Int> = [1, 11, 12, 13]
            var freq: [Int: Int] = [:]
            hand.forEach { freq[$0.rank, default: 0] += 1 }
            return freq.contains { qualifyingRanks.contains($0.key) && $0.value >= 2 }

        case .deucesWild:
            // A wild royal flush contains at least one 2; natural royals are handled by .none above
            if entry.handName == "Five of a Kind" {
                return result.kickers.count == 1
            }
            return hand.contains { $0.rank == 2 }

        case .bonusFours(let bonusRank):
            guard result.rank == .fourOfAKind else { return false }
            var freq: [Int: Int] = [:]
            hand.forEach { freq[$0.rank, default: 0] += 1 }
            if bonusRank == 4 {
                // Bonus for fours of rank 2, 3, or 4
                return freq.contains { [2,3,4].contains($0.key) && $0.value == 4 }
            } else {
                return freq[bonusRank] == 4
            }
        }
    }

    // MARK: - Bet controls

    public func increaseBet() {
        state.currentBet = min(5, state.currentBet + 1)
    }

    public func decreaseBet() {
        state.currentBet = max(1, state.currentBet - 1)
    }

    public func maxBet() {
        state.currentBet = max(1, min(5, state.sessionCredits))
        if state.phase == .deal || state.phase == .result { deal() }
    }

    // MARK: - Rebuy

    public func rebuy() {
        state.sessionCredits += options.startingCredits
        statistics.rebuyCount += 1
    }

    // MARK: - Statistics

    public func resetStatistics() {
        statistics = VideoPokerStatistics()
    }

    // MARK: - AppCoordinator compatibility stubs

    public func startNewGame() {
        state = VideoPokerState()
        state.sessionCredits = options.startingCredits
        state.currentBet = options.betPerHand
    }

    public func restartCurrentGame() { startNewGame() }
    public func undoLastAction() {}
    public var canUndo: Bool { false }
    public func zoomIn() {}
    public func zoomOut() {}
    public func resetZoom() {}
    public func makeCurrentZoomDefault() {}
}
