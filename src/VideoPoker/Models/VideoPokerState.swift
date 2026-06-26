import Foundation

public enum VideoPokerPhase: Equatable {
    case deal       // waiting for player to hit Deal
    case holding    // cards dealt, player selecting holds
    case result     // draw complete, showing outcome + payout
}

public struct VideoPokerPayEntry {
    public let handName: String
    public let rank: PokerHandRank
    public let qualifier: VideoPokerQualifier
    public let multipliers: [Int]   // index 0 = 1-coin, 4 = 5-coin (max bet)

    public func payout(bet: Int) -> Int {
        let idx = min(max(bet - 1, 0), 4)
        return multipliers[idx] * bet
    }
}

public enum VideoPokerQualifier: Equatable {
    case none
    case jacksOrBetter          // pair must be J Q K A
    case deucesWild             // 2s are wild
    case bonusFours(rank: Int)  // four-of-a-kind bonus for specific rank
}

public struct VideoPokerState {
    public var phase: VideoPokerPhase = .deal
    public var deck: [Card] = []
    public var hand: [Card] = []            // always 5 cards after deal
    public var heldIndices: Set<Int> = []   // indices the player chose to keep
    public var sessionCredits: Int = 1000
    public var currentBet: Int = 1
    public var lastPayout: Int = 0
    public var lastHandName: String = ""
    public var handsDealt: Int = 0
    public var timerSeconds: Int = 0
    public var isTimerActive: Bool = false
}
