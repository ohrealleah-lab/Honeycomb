import Foundation

public struct BeecellOptions: Codable, Equatable {
    public var deckCount: Int = 1 // 1 or 2
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var noStressMode: Bool = false
    public var honeyMode: Bool = true

    enum CodingKeys: String, CodingKey {
        case deckCount
        case isTimed
        case isSoundEnabled
        case hideHintButton
        case noStressMode
        case honeyMode
    }

    public init(
        deckCount: Int = 1,
        isTimed: Bool = true,
        isSoundEnabled: Bool = true,
        hideHintButton: Bool = false,
        noStressMode: Bool = false,
        honeyMode: Bool = true
    ) {
        self.deckCount = deckCount
        self.isTimed = isTimed
        self.isSoundEnabled = isSoundEnabled
        self.hideHintButton = hideHintButton
        self.noStressMode = noStressMode
        self.honeyMode = honeyMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deckCount = try container.decodeIfPresent(Int.self, forKey: .deckCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        self.hideHintButton = try container.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        self.noStressMode = try container.decodeIfPresent(Bool.self, forKey: .noStressMode) ?? false
        self.honeyMode = try container.decodeIfPresent(Bool.self, forKey: .honeyMode) ?? true
    }
}

extension BeecellOptions: HasCommonGameOptions {
    public var commonOptions: CommonGameOptions {
        get {
            CommonGameOptions(
                isSoundEnabled: isSoundEnabled,
                noStressMode: noStressMode,
                hideHintButton: hideHintButton,
                isTimed: isTimed
            )
        }
        set {
            isSoundEnabled = newValue.isSoundEnabled
            noStressMode = newValue.noStressMode
            if let v = newValue.hideHintButton { hideHintButton = v }
            if let v = newValue.isTimed { isTimed = v }
        }
    }
}
