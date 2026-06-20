import Foundation

public struct GameOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var isTimed: Bool = true
    public var isStatusBarVisible: Bool = true
    public var isSoundEnabled: Bool = true
    public var isVegasScoring: Bool = false
    public var isDrawConstraintsEnabled: Bool = false
    
    public init(
        feltColor: FeltColorTheme = .feltGreen,
        cardBackTheme: String = "Vulpera",
        isTimed: Bool = true,
        isStatusBarVisible: Bool = true,
        isSoundEnabled: Bool = true,
        isVegasScoring: Bool = false,
        isDrawConstraintsEnabled: Bool = false
    ) {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.isTimed = isTimed
        self.isStatusBarVisible = isStatusBarVisible
        self.isSoundEnabled = isSoundEnabled
        self.isVegasScoring = isVegasScoring
        self.isDrawConstraintsEnabled = isDrawConstraintsEnabled
    }
}

public enum FeltColorTheme: String, Codable, CaseIterable {
    case feltGreen
    case crimson
    case royalBlue
    case charcoal
}
