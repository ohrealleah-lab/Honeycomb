import Foundation

public struct GameOptions: Codable, Equatable {
    public var isTimed: Bool = true
    public var isStatusBarVisible: Bool = true
    public var isSoundEnabled: Bool = true
    public var isVegasScoring: Bool = false
    public var isDrawConstraintsEnabled: Bool = false
    public var hideHintButton: Bool = false
    public var noStressMode: Bool = false
    public var deckCount: Int = 1
    public var showPointHighlights: Bool = true

    public var drawMode: GameState.DrawMode = .drawThree

    public init(
        isTimed: Bool = true,
        isStatusBarVisible: Bool = true,
        isSoundEnabled: Bool = true,
        isVegasScoring: Bool = false,
        isDrawConstraintsEnabled: Bool = false,
        hideHintButton: Bool = false,
        noStressMode: Bool = false,
        deckCount: Int = 1,
        showPointHighlights: Bool = true,
        drawMode: GameState.DrawMode = .drawThree
    ) {
        self.isTimed = isTimed
        self.isStatusBarVisible = isStatusBarVisible
        self.isSoundEnabled = isSoundEnabled
        self.isVegasScoring = isVegasScoring
        self.isDrawConstraintsEnabled = isDrawConstraintsEnabled
        self.hideHintButton = hideHintButton
        self.noStressMode = noStressMode
        self.deckCount = deckCount
        self.showPointHighlights = showPointHighlights
        self.drawMode = drawMode
    }

    private enum CodingKeys: String, CodingKey {
        case isTimed
        case isStatusBarVisible
        case isSoundEnabled
        case isVegasScoring
        case isDrawConstraintsEnabled
        case hideHintButton
        case noStressMode
        case deckCount
        case showPointHighlights
        case drawMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isTimed = (try? container.decode(Bool.self, forKey: .isTimed)) ?? true
        self.isStatusBarVisible = (try? container.decode(Bool.self, forKey: .isStatusBarVisible)) ?? true
        self.isSoundEnabled = (try? container.decode(Bool.self, forKey: .isSoundEnabled)) ?? true
        self.isVegasScoring = (try? container.decode(Bool.self, forKey: .isVegasScoring)) ?? false
        self.isDrawConstraintsEnabled = (try? container.decode(Bool.self, forKey: .isDrawConstraintsEnabled)) ?? false
        self.hideHintButton = (try? container.decode(Bool.self, forKey: .hideHintButton)) ?? false
        self.noStressMode = (try? container.decode(Bool.self, forKey: .noStressMode)) ?? false
        self.deckCount = (try? container.decode(Int.self, forKey: .deckCount)) ?? 1
        self.showPointHighlights = (try? container.decode(Bool.self, forKey: .showPointHighlights)) ?? true
        self.drawMode = (try? container.decode(GameState.DrawMode.self, forKey: .drawMode)) ?? .drawThree
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
