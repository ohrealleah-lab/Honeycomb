import Foundation

public enum VideoPokerVariant: String, Codable, CaseIterable, Equatable {
    case jacksOrBetter = "Jacks or Better"
    case deucesWild    = "Deuces Wild"
    case bonusPoker    = "Bonus Poker"
}

public struct VideoPokerOptions: Codable, Equatable {
    public var variant: VideoPokerVariant = .jacksOrBetter
    public var startingCredits: Int = 1000
    public var betPerHand: Int = 1          // 1–5 coins
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    public var isDarkMode: Bool = false
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var customFeltColorRevision: Int = 0
    public var showFeltVignette: Bool = true
    public var customCardColors: CustomCardColorGroup = CustomCardColorGroup()

    enum CodingKeys: String, CodingKey {
        case variant, startingCredits, betPerHand
        case isTimed, isSoundEnabled, hideHintButton, hideStatsButton, isDarkMode
        case feltColor, cardBackTheme, customFeltColorRevision, showFeltVignette, customCardColors
    }

    public init(feltColor: FeltColorTheme = .feltGreen, cardBackTheme: String = "Vulpera") {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.customCardColors = CustomCardColorGroup()
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        variant        = try c.decodeIfPresent(VideoPokerVariant.self, forKey: .variant) ?? .jacksOrBetter
        startingCredits = try c.decodeIfPresent(Int.self, forKey: .startingCredits) ?? 1000
        betPerHand     = try c.decodeIfPresent(Int.self, forKey: .betPerHand) ?? 1
        isTimed        = try c.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        isSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        hideHintButton = try c.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        hideStatsButton = try c.decodeIfPresent(Bool.self, forKey: .hideStatsButton) ?? false
        isDarkMode     = try c.decodeIfPresent(Bool.self, forKey: .isDarkMode) ?? false
        feltColor      = try c.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor) ?? .feltGreen
        cardBackTheme  = try c.decodeIfPresent(String.self, forKey: .cardBackTheme) ?? "Vulpera"
        customFeltColorRevision = try c.decodeIfPresent(Int.self, forKey: .customFeltColorRevision) ?? 0
        showFeltVignette = try c.decodeIfPresent(Bool.self, forKey: .showFeltVignette) ?? true
        customCardColors = try c.decodeIfPresent(CustomCardColorGroup.self, forKey: .customCardColors) ?? CustomCardColorGroup()
    }
}
