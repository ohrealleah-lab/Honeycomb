import Foundation

public struct SpiderOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var suitCount: Int = 1 // 1, 2, or 4 suits
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var isVegasScoring: Bool = false
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case feltColor
        case cardBackTheme
        case suitCount
        case isTimed
        case isSoundEnabled
        case isVegasScoring
        case hideHintButton
        case hideStatsButton
    }
    
    public init(
        feltColor: FeltColorTheme = .feltGreen,
        cardBackTheme: String = "Vulpera",
        suitCount: Int = 1,
        isTimed: Bool = true,
        isSoundEnabled: Bool = true,
        isVegasScoring: Bool = false,
        hideHintButton: Bool = false,
        hideStatsButton: Bool = false
    ) {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.suitCount = suitCount
        self.isTimed = isTimed
        self.isSoundEnabled = isSoundEnabled
        self.isVegasScoring = isVegasScoring
        self.hideHintButton = hideHintButton
        self.hideStatsButton = hideStatsButton
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.feltColor = try container.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor) ?? .feltGreen
        self.cardBackTheme = try container.decodeIfPresent(String.self, forKey: .cardBackTheme) ?? "Vulpera"
        self.suitCount = try container.decodeIfPresent(Int.self, forKey: .suitCount) ?? 1
        self.isTimed = try container.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        self.isVegasScoring = try container.decodeIfPresent(Bool.self, forKey: .isVegasScoring) ?? false
        self.hideHintButton = try container.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        self.hideStatsButton = try container.decodeIfPresent(Bool.self, forKey: .hideStatsButton) ?? false
    }
}
