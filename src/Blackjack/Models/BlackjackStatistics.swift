import Foundation

public struct BlackjackStatistics: Codable {
    public var handsPlayed: Int = 0
    public var handsWon: Int = 0
    public var handsLost: Int = 0
    public var pushes: Int = 0
    public var blackjacks: Int = 0
    public var totalWagered: Int = 0
    public var totalPaidOut: Int = 0
    public var biggestPayout: Int = 0
    public var rebuyCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case handsPlayed, handsWon, handsLost, pushes, blackjacks
        case totalWagered, totalPaidOut, biggestPayout, rebuyCount
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        handsPlayed   = try c.decodeIfPresent(Int.self, forKey: .handsPlayed)   ?? 0
        handsWon      = try c.decodeIfPresent(Int.self, forKey: .handsWon)      ?? 0
        handsLost     = try c.decodeIfPresent(Int.self, forKey: .handsLost)     ?? 0
        pushes        = try c.decodeIfPresent(Int.self, forKey: .pushes)        ?? 0
        blackjacks    = try c.decodeIfPresent(Int.self, forKey: .blackjacks)    ?? 0
        totalWagered  = try c.decodeIfPresent(Int.self, forKey: .totalWagered)  ?? 0
        totalPaidOut  = try c.decodeIfPresent(Int.self, forKey: .totalPaidOut)  ?? 0
        biggestPayout = try c.decodeIfPresent(Int.self, forKey: .biggestPayout) ?? 0
        rebuyCount    = try c.decodeIfPresent(Int.self, forKey: .rebuyCount)    ?? 0
    }

    public var winRate: Double {
        handsPlayed > 0 ? Double(handsWon) / Double(handsPlayed) : 0
    }

    public var returnToPlayer: Double {
        totalWagered > 0 ? Double(totalPaidOut) / Double(totalWagered) : 0
    }
}
