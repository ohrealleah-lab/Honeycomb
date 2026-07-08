import Foundation

public struct GameOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var isTimed: Bool = true
    public var isStatusBarVisible: Bool = true
    public var isSoundEnabled: Bool = true
    public var isVegasScoring: Bool = false
    public var isDrawConstraintsEnabled: Bool = false
    public var hideHintButton: Bool = false
    public var noStressMode: Bool = false
    public var deckCount: Int = 1

    public var customFeltColorRevision: Int = 0
    public var drawMode: GameState.DrawMode = .drawThree
    public var showFeltVignette: Bool = true
    public var customCardColors: CustomCardColorGroup = CustomCardColorGroup()

    public init(
        feltColor: FeltColorTheme = .feltGreen,
        cardBackTheme: String = "Vulpera",
        isTimed: Bool = true,
        isStatusBarVisible: Bool = true,
        isSoundEnabled: Bool = true,
        isVegasScoring: Bool = false,
        isDrawConstraintsEnabled: Bool = false,
        hideHintButton: Bool = false,
        noStressMode: Bool = false,
        deckCount: Int = 1,
        customFeltColorRevision: Int = 0,
        drawMode: GameState.DrawMode = .drawThree,
        showFeltVignette: Bool = true,
        customCardColors: CustomCardColorGroup = CustomCardColorGroup()
    ) {
        self.feltColor = feltColor
        self.cardBackTheme = cardBackTheme
        self.isTimed = isTimed
        self.isStatusBarVisible = isStatusBarVisible
        self.isSoundEnabled = isSoundEnabled
        self.isVegasScoring = isVegasScoring
        self.isDrawConstraintsEnabled = isDrawConstraintsEnabled
        self.hideHintButton = hideHintButton
        self.noStressMode = noStressMode
        self.deckCount = deckCount
        self.customFeltColorRevision = customFeltColorRevision
        self.drawMode = drawMode
        self.showFeltVignette = showFeltVignette
        self.customCardColors = customCardColors
    }

    private enum CodingKeys: String, CodingKey {
        case feltColor
        case cardBackTheme
        case isTimed
        case isStatusBarVisible
        case isSoundEnabled
        case isVegasScoring
        case isDrawConstraintsEnabled
        case hideHintButton
        case noStressMode
        case deckCount
        case customFeltColorRevision
        case drawMode
        case showFeltVignette
        case customCardColors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.feltColor = (try? container.decode(FeltColorTheme.self, forKey: .feltColor)) ?? .feltGreen
        self.cardBackTheme = (try? container.decode(String.self, forKey: .cardBackTheme)) ?? "Vulpera"
        self.isTimed = (try? container.decode(Bool.self, forKey: .isTimed)) ?? true
        self.isStatusBarVisible = (try? container.decode(Bool.self, forKey: .isStatusBarVisible)) ?? true
        self.isSoundEnabled = (try? container.decode(Bool.self, forKey: .isSoundEnabled)) ?? true
        self.isVegasScoring = (try? container.decode(Bool.self, forKey: .isVegasScoring)) ?? false
        self.isDrawConstraintsEnabled = (try? container.decode(Bool.self, forKey: .isDrawConstraintsEnabled)) ?? false
        self.hideHintButton = (try? container.decode(Bool.self, forKey: .hideHintButton)) ?? false
        self.noStressMode = (try? container.decode(Bool.self, forKey: .noStressMode)) ?? false
        self.deckCount = (try? container.decode(Int.self, forKey: .deckCount)) ?? 1
        self.customFeltColorRevision = (try? container.decode(Int.self, forKey: .customFeltColorRevision)) ?? 0
        self.drawMode = (try? container.decode(GameState.DrawMode.self, forKey: .drawMode)) ?? .drawThree
        self.showFeltVignette = (try? container.decode(Bool.self, forKey: .showFeltVignette)) ?? true
        self.customCardColors = (try? container.decode(CustomCardColorGroup.self, forKey: .customCardColors)) ?? CustomCardColorGroup()
    }
}

public enum FeltColorTheme: String, Codable, CaseIterable {
    case feltGreen
    case crimson
    case royalBlue
    case charcoal
    case desert
    case custom
}

extension Notification.Name {
    public static let feltColorDidChange = Notification.Name("feltColorDidChange")
    public static let cardBackThemeDidChange = Notification.Name("cardBackThemeDidChange")
    public static let feltVignetteDidChange = Notification.Name("feltVignetteDidChange")
    public static let customCardColorsDidChange = Notification.Name("customCardColorsDidChange")
}
