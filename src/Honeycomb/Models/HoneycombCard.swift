import Foundation

public struct HoneycombCardData: Codable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public let stars: Int
    public let stats: [Int] // 0: Top, 1: Right, 2: Bottom, 3: Left
    public let suit: String

    public static func suitDisplayName(_ code: String) -> String {
        switch code {
        case "S": return "Spades"
        case "H": return "Hearts"
        case "D": return "Diamonds"
        case "C": return "Clubs"
        default: return code
        }
    }
}

public enum CardOwner: String, Codable, Equatable {
    case player
    case opponent
}

public struct HoneycombCard: Codable, Identifiable, Equatable {
    public let id: String
    public let data: HoneycombCardData
    public var owner: CardOwner
    public let originalOwner: CardOwner
    public var modifier: Int = 0

    // originalOwner defaults to owner (the normal case), but the "Swap" rule needs to
    // construct a card whose current holder (owner, for battle purposes) differs from
    // its true owner (originalOwner) — it's played by whoever it was swapped to, but
    // reverts to its rightful owner for the "keep what you hold" win-unlock (and stays
    // stealable by that rightful owner if they don't recapture it themselves).
    public init(data: HoneycombCardData, owner: CardOwner, originalOwner: CardOwner? = nil, id: String = UUID().uuidString) {
        self.data = data
        self.owner = owner
        self.originalOwner = originalOwner ?? owner
        self.id = id
    }

    public func stat(at index: Int) -> Int {
        let val = data.stats[index] + modifier
        // Matches FFXIV Triple Triad: stats are clamped to the 1-10 (A) range in all
        // capture math, so an Ascension-boosted 8 behaves exactly as a 10, not an 11.
        return min(10, max(1, val))
    }
}
