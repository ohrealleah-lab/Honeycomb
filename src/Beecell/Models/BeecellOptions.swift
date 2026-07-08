import Foundation

public struct BeecellOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var deckCount: Int = 1 // 1 or 2
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var noStressMode: Bool = false

    public var customFeltColorRevision: Int = 0
    public var showFeltVignette: Bool = true
    public var customCardColors: CustomCardColorGroup = CustomCardColorGroup()

    enum CodingKeys: String, CodingKey {
        case feltColor
        case cardBackTheme
        case deckCount
        case isTimed
        case isSoundEnabled
        case hideHintButton
        case noStressMode
        case customFeltColorRevision
        case showFeltVignette
        case customCardColors
    }

    public init(
        feltColor: FeltColorTheme = .feltGreen,
        cardBackTheme: String = "Vulpera",
        deckCount: Int = 1,
        isTimed: Bool = true,
        isSoundEnabled: Bool = true,
        hideHintButton: Bool = false,
        noStressMode: Bool = false,
        customFeltColorRevision: Int = 0,
        showFeltVignette: Bool = true,
        customCardColors: CustomCardColorGroup = CustomCardColorGroup()
    ) {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.deckCount = deckCount
        self.isTimed = isTimed
        self.isSoundEnabled = isSoundEnabled
        self.hideHintButton = hideHintButton
        self.noStressMode = noStressMode
        self.customFeltColorRevision = customFeltColorRevision
        self.showFeltVignette = showFeltVignette
        self.customCardColors = customCardColors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.feltColor = try container.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor) ?? .feltGreen
        self.cardBackTheme = try container.decodeIfPresent(String.self, forKey: .cardBackTheme) ?? "Vulpera"
        self.deckCount = try container.decodeIfPresent(Int.self, forKey: .deckCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        self.hideHintButton = try container.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        self.noStressMode = try container.decodeIfPresent(Bool.self, forKey: .noStressMode) ?? false
        self.customFeltColorRevision = try container.decodeIfPresent(Int.self, forKey: .customFeltColorRevision) ?? 0
        self.showFeltVignette = try container.decodeIfPresent(Bool.self, forKey: .showFeltVignette) ?? true
        self.customCardColors = try container.decodeIfPresent(CustomCardColorGroup.self, forKey: .customCardColors) ?? CustomCardColorGroup()
    }
}
