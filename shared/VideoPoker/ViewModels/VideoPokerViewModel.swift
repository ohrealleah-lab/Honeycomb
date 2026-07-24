import Foundation
import Observation

@Observable
public final class VideoPokerViewModel {

    public var options: VideoPokerOptions {
        didSet {
            saveOptions()
            UISound.isEnabled = options.isSoundEnabled
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
           let decoded = try? JSONDecoder().decode(VideoPokerOptions.self, from: data) {
            self.options = decoded
        } else {
            self.options = VideoPokerOptions()
        }

        if let data = UserDefaults.standard.data(forKey: "videopoker_statistics"),
           let decoded = try? JSONDecoder().decode(VideoPokerStatistics.self, from: data) {
            self.statistics = decoded
        }

        if !VideoPokerPlayMode.tripleEnabled && options.playMode == .triple {
            options.playMode = .single
        }

        state.sessionCredits = options.startingCredits
        state.currentBet = options.betPerHand

        UISound.isEnabled = self.options.isSoundEnabled
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

    // MARK: - Sound

    public func playSound(named name: String) {
        UISound.play(named: name, enabled: options.isSoundEnabled)
    }

    // MARK: - Game flow

    public var totalBet: Int {
        state.currentBet * (options.playMode == .triple ? 3 : 1)
    }

    public var isFreePlay: Bool {
        options.noStressMode
    }

    // Options can only be opened between hands — changing variant/play mode mid-hand
    // would evaluate an already-dealt hand under different rules.
    public var canOpenOptions: Bool {
        state.phase == .deal || state.phase == .result
    }

    public func deal() {
        guard state.phase == .deal || state.phase == .result else { return }
        guard isFreePlay || state.sessionCredits >= totalBet else { return }

        if !isFreePlay {
            state.sessionCredits -= totalBet
            statistics.totalWagered += totalBet
        }
        statistics.handsPlayed += options.playMode == .triple ? 3 : 1
        state.handsDealt += 1
        state.lastPayout = 0
        state.lastHandName = ""
        state.heldIndices = []
        state.triplePlayHands = []
        state.triplePlayHandNames = ["", "", ""]
        state.triplePlayPayouts = [0, 0, 0]

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

        if options.playMode == .triple {
            drawTriplePlay()
            playSound(named: "snap")
            evaluateTriplePlay()
        } else {
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
        }
        state.phase = .result
    }

    // MARK: - Triple Play

    private static func freshDeck(excluding hand: [Card]) -> [Card] {
        let excluded = Set(hand.map { "\($0.suit.rawValue)-\($0.rank)" })
        var deck: [Card] = []
        for suit in Card.Suit.allCases {
            for rank in 1...13 where !excluded.contains("\(suit.rawValue)-\(rank)") {
                deck.append(Card(suit: suit, rank: rank, faceUp: true))
            }
        }
        deck.shuffle()
        return deck
    }

    private func drawTriplePlay() {
        let baseHand = state.hand
        let held = state.heldIndices

        var hands: [[Card]] = []
        for handIndex in 0..<3 {
            var hand = baseHand
            if handIndex == 2 {
                // Bottom/base hand: draws from the deck already dealt alongside the base hand.
                for i in 0..<5 where !held.contains(i) {
                    if let replacement = state.deck.first {
                        hand[i] = replacement
                        state.deck.removeFirst()
                    }
                }
            } else {
                var deck = Self.freshDeck(excluding: baseHand)
                for i in 0..<5 where !held.contains(i) {
                    hand[i] = deck.removeFirst()
                }
            }
            hands.append(hand)
        }

        state.triplePlayHands = hands
        state.hand = hands[2]
    }

    private func evaluateTriplePlay() {
        state.triplePlayHandNames = Array(repeating: "", count: 3)
        state.triplePlayPayouts = Array(repeating: 0, count: 3)

        var totalPayout = 0
        var anyWin = false
        var winCount = 0
        var maxSingle = 0
        var royalCount = 0

        for i in 0..<3 {
            let (name, payout, rank) = evaluateHand(state.triplePlayHands[i])
            state.triplePlayHandNames[i] = name
            state.triplePlayPayouts[i] = payout
            totalPayout += payout
            if rank != nil { anyWin = true }
            if payout > 0 {
                winCount += 1
                maxSingle = max(maxSingle, payout)
                if rank == .royalFlush { royalCount += 1 }
            }
        }

        state.lastHandName = ""
        state.lastPayout = totalPayout
        if !isFreePlay {
            state.sessionCredits += totalPayout
        }

        if anyWin {
            statistics.currentStreak += 1
            statistics.longestStreak = max(statistics.longestStreak, statistics.currentStreak)
        } else {
            statistics.currentStreak = 0
        }
        if totalPayout > 0 {
            statistics.handsWon += winCount
            statistics.royalFlushCount += royalCount
            if !isFreePlay {
                statistics.totalPaidOut += totalPayout
                statistics.biggestPayout = max(statistics.biggestPayout, maxSingle)
            }
            playSound(named: "victory")
        }
    }

    // MARK: - Hand evaluation against pay table

    private func evaluateHand(_ hand: [Card]) -> (name: String, payout: Int, rank: PokerHandRank?) {
        // PokerHandEvaluator requires exactly 5 cards; guard here so every caller
        // (single-hand evaluate() and each triple-play sub-hand) is protected, rather
        // than relying on each call site to check first.
        guard hand.count == 5 else { return ("No Win", 0, nil) }
        let result = options.variant == .deucesWild
            ? PokerHandEvaluator.evaluateWithDeuces(hand)
            : PokerHandEvaluator.evaluate(hand)

        // Walk the pay table from top (best) to bottom and find first match
        for entry in payTable where matches(result: result, hand: hand, entry: entry) {
            return (entry.handName, entry.payout(bet: state.currentBet), entry.rank)
        }
        return ("No Win", 0, nil)
    }

    private func evaluate() {
        guard state.hand.count == 5 else { return }

        let (name, payout, rank) = evaluateHand(state.hand)
        state.lastHandName = name
        state.lastPayout = payout

        if rank != nil {
            statistics.currentStreak += 1
            statistics.longestStreak = max(statistics.longestStreak, statistics.currentStreak)
            if payout > 0 {
                statistics.handsWon += 1
                if rank == .royalFlush { statistics.royalFlushCount += 1 }
                if !isFreePlay {
                    state.sessionCredits += payout
                    statistics.totalPaidOut += payout
                    statistics.biggestPayout = max(statistics.biggestPayout, payout)
                }
                playSound(named: "victory")
            }
        } else {
            statistics.currentStreak = 0
        }
    }

    private func matches(result: PokerHandResult, hand: [Card], entry: VideoPokerPayEntry) -> Bool {
        guard result.rank == entry.rank else { return false }

        switch entry.qualifier {
        case .none:
            if options.variant == .deucesWild && entry.rank == .royalFlush {
                return !hand.contains { $0.rank == 2 }
            }
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
                return result.kickers.count == 2 && result.kickers[1] == 15
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
        guard state.phase == .deal || state.phase == .result else { return }
        state.currentBet = min(5, state.currentBet + 1)
    }

    public func decreaseBet() {
        guard state.phase == .deal || state.phase == .result else { return }
        state.currentBet = max(1, state.currentBet - 1)
    }

    public func maxBet() {
        guard state.phase == .deal || state.phase == .result else { return }
        let divisor = options.playMode == .triple ? 3 : 1
        state.currentBet = max(1, min(5, state.sessionCredits / divisor))
        deal()
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

    public var debugBannerRequest: DebugBannerKind? = nil

    public func debugSetupBannerState(_ kind: DebugBannerKind) {
        let royalFlush: [Card] = [
            Card(suit: .hearts, rank: 1,  faceUp: true),
            Card(suit: .hearts, rank: 13, faceUp: true),
            Card(suit: .hearts, rank: 12, faceUp: true),
            Card(suit: .hearts, rank: 11, faceUp: true),
            Card(suit: .hearts, rank: 10, faceUp: true),
        ]
        let rags: [Card] = [
            Card(suit: .hearts,   rank: 2, faceUp: true),
            Card(suit: .spades,   rank: 5, faceUp: true),
            Card(suit: .diamonds, rank: 9, faceUp: true),
            Card(suit: .clubs,    rank: 3, faceUp: true),
            Card(suit: .hearts,   rank: 7, faceUp: true),
        ]
        switch kind {
        case .win:
            state.hand = royalFlush
            state.lastHandName = "Royal Flush"
            state.lastPayout = 250
        case .loss:
            state.hand = rags
            state.lastHandName = "No Win"
            state.lastPayout = 0
        default: break
        }
    }

    // Clears the last-dealt hand/result display without touching credits or the
    // bet, so committing a Variant/Play Mode change from Options (allowed mid-round
    // at the .result phase) doesn't leave stale cards from the old mode on screen.
    public func resetHandDisplay() {
        state.phase = .deal
        state.hand = []
        state.heldIndices = []
        state.lastPayout = 0
        state.lastHandName = ""
        state.triplePlayHands = []
        state.triplePlayHandNames = []
        state.triplePlayPayouts = []
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

    // Board scale — no longer manual; VideoPokerView.recomputeScale() continuously
    // derives this from the window's current size. Not persisted, purely a function of
    // window size.
    public var zoomScale: CGFloat = 1.0
}
