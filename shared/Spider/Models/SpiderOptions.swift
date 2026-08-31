import Foundation

public struct SpiderOptions: Codable, Equatable {
    public var suitCount: Int = 1 // 1, 2, or 4 suits
    public var isTimed: Bool = true

    enum CodingKeys: String, CodingKey {
        case suitCount
        case isTimed
    }

    public init(
        suitCount: Int = 1,
        isTimed: Bool = true
    ) {
        self.suitCount = suitCount
        self.isTimed = isTimed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.suitCount = try container.decodeIfPresent(Int.self, forKey: .suitCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
    }
}
