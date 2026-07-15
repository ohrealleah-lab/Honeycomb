import Foundation

public struct SpiderOptions: Codable, Equatable {
    public var suitCount: Int = 1 // 1, 2, or 4 suits
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var noStressMode: Bool = false

    enum CodingKeys: String, CodingKey {
        case suitCount
        case isTimed
        case isSoundEnabled
        case hideHintButton
        case noStressMode
    }

    public init(
        suitCount: Int = 1,
        isTimed: Bool = true,
        isSoundEnabled: Bool = true,
        hideHintButton: Bool = false,
        noStressMode: Bool = false
    ) {
        self.suitCount = suitCount
        self.isTimed = isTimed
        self.isSoundEnabled = isSoundEnabled
        self.hideHintButton = hideHintButton
        self.noStressMode = noStressMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.suitCount = try container.decodeIfPresent(Int.self, forKey: .suitCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        self.hideHintButton = try container.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        self.noStressMode = try container.decodeIfPresent(Bool.self, forKey: .noStressMode) ?? false
    }
}
