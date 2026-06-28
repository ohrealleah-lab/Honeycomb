import Foundation

public struct BlackjackOptions: Codable, Equatable {
    public var startingCredits: Int = 100
    public var betPerHand: Int = 1
    public var isSoundEnabled: Bool = true
    public var isTimed: Bool = false
    public var isDarkMode: Bool = false
    public var feltColor: FeltColorTheme = .feltGreen
    public var customFeltColorRevision: Int = 0
    public var cardBackTheme: String = "Vulpera"
    public var hideStatsButton: Bool = false
    public var showFeltVignette: Bool = true
    public var customCardColors: CustomCardColorGroup = CustomCardColorGroup()

    enum CodingKeys: String, CodingKey {
        case startingCredits, betPerHand, isSoundEnabled, isTimed, isDarkMode
        case feltColor, customFeltColorRevision, cardBackTheme, hideStatsButton, showFeltVignette, customCardColors
    }

    public init(feltColor: FeltColorTheme = .feltGreen, cardBackTheme: String = "Vulpera") {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.customCardColors = CustomCardColorGroup()
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startingCredits        = try c.decodeIfPresent(Int.self,           forKey: .startingCredits)        ?? 100
        betPerHand             = try c.decodeIfPresent(Int.self,           forKey: .betPerHand)             ?? 1
        isSoundEnabled         = try c.decodeIfPresent(Bool.self,          forKey: .isSoundEnabled)         ?? true
        isTimed                = try c.decodeIfPresent(Bool.self,          forKey: .isTimed)                ?? false
        isDarkMode             = try c.decodeIfPresent(Bool.self,          forKey: .isDarkMode)             ?? false
        feltColor              = try c.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor)             ?? .feltGreen
        customFeltColorRevision = try c.decodeIfPresent(Int.self,          forKey: .customFeltColorRevision) ?? 0
        cardBackTheme          = try c.decodeIfPresent(String.self,        forKey: .cardBackTheme)          ?? "Vulpera"
        hideStatsButton        = try c.decodeIfPresent(Bool.self,          forKey: .hideStatsButton)        ?? false
        showFeltVignette       = try c.decodeIfPresent(Bool.self,          forKey: .showFeltVignette)       ?? true
        customCardColors       = try c.decodeIfPresent(CustomCardColorGroup.self, forKey: .customCardColors) ?? CustomCardColorGroup()
    }
}
