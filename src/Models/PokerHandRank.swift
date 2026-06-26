import Foundation

public enum PokerHandRank: Int, Comparable, CaseIterable {
    case highCard = 0
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush
    case royalFlush

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .highCard:     return "High Card"
        case .onePair:      return "One Pair"
        case .twoPair:      return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight:     return "Straight"
        case .flush:        return "Flush"
        case .fullHouse:    return "Full House"
        case .fourOfAKind:  return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush:   return "Royal Flush"
        }
    }
}

public struct PokerHandResult: Comparable {
    public let rank: PokerHandRank
    public let kickers: [Int]   // up to 5 card ranks, descending

    public init(rank: PokerHandRank, kickers: [Int]) {
        self.rank = rank
        self.kickers = kickers
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.kickers.lexicographicallyPrecedes(rhs.kickers)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rank == rhs.rank && lhs.kickers == rhs.kickers
    }
}
