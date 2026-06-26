import Foundation

public struct PokerbeeOptions: Codable, Equatable {
    public var seatCount: Int = 3
    public var startingChips: Int = 1000
    public var ante: Int = 10
    public var aiDifficulty: AIDifficulty = .medium
    public var noBidMode: Bool = false
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    public var isDarkMode: Bool = false
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var customFeltColorRevision: Int = 0

    enum CodingKeys: String, CodingKey {
        case seatCount, startingChips, ante, aiDifficulty, noBidMode
        case isTimed, isSoundEnabled, hideHintButton, hideStatsButton, isDarkMode
        case feltColor, cardBackTheme, customFeltColorRevision
    }

    public init(feltColor: FeltColorTheme = .feltGreen, cardBackTheme: String = "Vulpera") {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seatCount = try c.decodeIfPresent(Int.self, forKey: .seatCount) ?? 3
        startingChips = try c.decodeIfPresent(Int.self, forKey: .startingChips) ?? 1000
        ante = try c.decodeIfPresent(Int.self, forKey: .ante) ?? 10
        aiDifficulty = try c.decodeIfPresent(AIDifficulty.self, forKey: .aiDifficulty) ?? .medium
        noBidMode = try c.decodeIfPresent(Bool.self, forKey: .noBidMode) ?? false
        isTimed = try c.decodeIfPresent(Bool.self, forKey: .isTimed) ?? true
        isSoundEnabled = try c.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        hideHintButton = try c.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
        hideStatsButton = try c.decodeIfPresent(Bool.self, forKey: .hideStatsButton) ?? false
        isDarkMode = try c.decodeIfPresent(Bool.self, forKey: .isDarkMode) ?? false
        feltColor = try c.decodeIfPresent(FeltColorTheme.self, forKey: .feltColor) ?? .feltGreen
        cardBackTheme = try c.decodeIfPresent(String.self, forKey: .cardBackTheme) ?? "Vulpera"
        customFeltColorRevision = try c.decodeIfPresent(Int.self, forKey: .customFeltColorRevision) ?? 0
    }
}
