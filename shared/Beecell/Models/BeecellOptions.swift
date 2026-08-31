import Foundation

public struct BeecellOptions: Codable, Equatable {
    public var deckCount: Int = 1 // 1 or 2
    public var isTimed: Bool = true

    enum CodingKeys: String, CodingKey {
        case deckCount
        case isTimed
    }

    public init(
        deckCount: Int = 1,
        isTimed: Bool = true
    ) {
        self.deckCount = deckCount
        self.isTimed = isTimed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deckCount = try container.decodeIfPresent(Int.self, forKey: .deckCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
    }
}
