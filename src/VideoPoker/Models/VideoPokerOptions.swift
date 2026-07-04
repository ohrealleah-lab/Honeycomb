import Foundation

public enum VideoPokerVariant: String, Codable, CaseIterable, Equatable {
    case jacksOrBetter = "Jacks or Better"
    case deucesWild    = "Deuces Wild"
    case bonusPoker    = "Bonus Poker"
}

public struct VideoPokerOptions: Codable, Equatable {
    public var variant: VideoPokerVariant = .jacksOrBetter
    public var startingCredits: Int = 100
    public var betPerHand: Int = 1          // 1–5 coins
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    public var hideBetBoard: Bool = false
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var customFeltColorRevision: Int = 0
    public var showFeltVignette: Bool = true
    public var customCardColors: CustomCardColorGroup = CustomCardColorGroup()

    enum CodingKeys: String, CodingKey {
        case variant, startingCredits, betPerHand
        case isSoundEnabled, hideHintButton, hideStatsButton, hideBetBoard
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
        startingCredits = try c.decodeIfPresent(Int.self, forKey: .startingCredits) ?? 100
        betPerHand     = try c.decodeIfPresent(Int.self, forKey: .betPerHand) ?? 1
        isSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        hideHintButton = try c.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        hideStatsButton = try c.decodeIfPresent(Bool.self, forKey: .hideStatsButton) ?? false
        hideBetBoard   = try c.decodeIfPresent(Bool.self, forKey: .hideBetBoard) ?? false
        feltColor      = try c.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor) ?? .feltGreen
        cardBackTheme  = try c.decodeIfPresent(String.self, forKey: .cardBackTheme) ?? "Vulpera"
        customFeltColorRevision = try c.decodeIfPresent(Int.self, forKey: .customFeltColorRevision) ?? 0
        showFeltVignette = try c.decodeIfPresent(Bool.self, forKey: .showFeltVignette) ?? true
        customCardColors = try c.decodeIfPresent(CustomCardColorGroup.self, forKey: .customCardColors) ?? CustomCardColorGroup()
    }
}
