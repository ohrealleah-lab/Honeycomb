import Foundation

public struct BeecellOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var deckCount: Int = 1 // 1 or 2
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var isVegasScoring: Bool = false
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    
    public var customFeltColorRevision: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case feltColor
        case cardBackTheme
        case deckCount
        case isTimed
        case isSoundEnabled
        case isVegasScoring
        case hideHintButton
        case hideStatsButton
        case customFeltColorRevision
    }
    
    public init(
        feltColor: FeltColorTheme = .feltGreen,
        cardBackTheme: String = "Vulpera",
        deckCount: Int = 1,
        isTimed: Bool = true,
        isSoundEnabled: Bool = true,
        isVegasScoring: Bool = false,
        hideHintButton: Bool = false,
        hideStatsButton: Bool = false,
        customFeltColorRevision: Int = 0
    ) {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.deckCount = deckCount
        self.isTimed = isTimed
        self.isSoundEnabled = isSoundEnabled
        self.isVegasScoring = isVegasScoring
        self.hideHintButton = hideHintButton
        self.hideStatsButton = hideStatsButton
        self.customFeltColorRevision = customFeltColorRevision
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.feltColor = try container.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor) ?? .feltGreen
        self.cardBackTheme = try container.decodeIfPresent(String.self, forKey: .cardBackTheme) ?? "Vulpera"
        self.deckCount = try container.decodeIfPresent(Int.self, forKey: .deckCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        self.isVegasScoring = try container.decodeIfPresent(Bool.self, forKey: .isVegasScoring) ?? false
        self.hideHintButton = try container.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        self.hideStatsButton = try container.decodeIfPresent(Bool.self, forKey: .hideStatsButton) ?? false
        self.customFeltColorRevision = try container.decodeIfPresent(Int.self, forKey: .customFeltColorRevision) ?? 0
    }
}
