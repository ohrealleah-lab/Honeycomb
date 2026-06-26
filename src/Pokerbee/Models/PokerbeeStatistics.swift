import Foundation

public struct PokerbeeStatistics: Codable {
    public var handsPlayed: Int = 0
    public var handsWon: Int = 0
    public var biggestPotWon: Int = 0
    public var netSessionChips: Int = 0
    public var rebuyCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case handsPlayed, handsWon, biggestPotWon, netSessionChips, rebuyCount
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        handsPlayed = try c.decodeIfPresent(Int.self, forKey: .handsPlayed) ?? 0
        handsWon = try c.decodeIfPresent(Int.self, forKey: .handsWon) ?? 0
        biggestPotWon = try c.decodeIfPresent(Int.self, forKey: .biggestPotWon) ?? 0
        netSessionChips = 0   // always reset on launch
        rebuyCount = try c.decodeIfPresent(Int.self, forKey: .rebuyCount) ?? 0
    }

    public var winRate: Double {
        handsPlayed > 0 ? Double(handsWon) / Double(handsPlayed) : 0
    }
}
