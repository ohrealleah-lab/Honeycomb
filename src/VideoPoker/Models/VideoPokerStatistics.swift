import Foundation

public struct VideoPokerStatistics: Codable {
    public var handsPlayed: Int = 0
    public var handsWon: Int = 0
    public var biggestPayout: Int = 0
    public var totalWagered: Int = 0
    public var totalPaidOut: Int = 0
    public var royalFlushCount: Int = 0
    public var rebuyCount: Int = 0
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0

    enum CodingKeys: String, CodingKey {
        case handsPlayed, handsWon, biggestPayout, totalWagered, totalPaidOut, royalFlushCount, rebuyCount
        case currentStreak, longestStreak
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        handsPlayed     = try c.decodeIfPresent(Int.self, forKey: .handsPlayed)     ?? 0
        handsWon        = try c.decodeIfPresent(Int.self, forKey: .handsWon)        ?? 0
        biggestPayout   = try c.decodeIfPresent(Int.self, forKey: .biggestPayout)   ?? 0
        totalWagered    = try c.decodeIfPresent(Int.self, forKey: .totalWagered)    ?? 0
        totalPaidOut    = try c.decodeIfPresent(Int.self, forKey: .totalPaidOut)    ?? 0
        royalFlushCount = try c.decodeIfPresent(Int.self, forKey: .royalFlushCount) ?? 0
        rebuyCount      = try c.decodeIfPresent(Int.self, forKey: .rebuyCount)      ?? 0
        currentStreak   = try c.decodeIfPresent(Int.self, forKey: .currentStreak)   ?? 0
        longestStreak   = try c.decodeIfPresent(Int.self, forKey: .longestStreak)   ?? 0
    }

    public var returnToPlayer: Double {
        totalWagered > 0 ? Double(totalPaidOut) / Double(totalWagered) : 0
    }

    public var winRate: Double {
        handsPlayed > 0 ? Double(handsWon) / Double(handsPlayed) : 0
    }
}
