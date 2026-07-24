import Foundation
import SwiftUI

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

// Felt theme colors. Lives with the enum (not in a View file) because AppCoordinator's
// currentFeltColor resolves through primaryColor on every platform.
extension FeltColorTheme {
    public var primaryColor: Color {
        switch self {
        case .feltGreen:
            return Color(red: 0.0, green: 0.5, blue: 0.0)
        case .crimson:
            return Color(red: 0.55, green: 0.05, blue: 0.15)
        case .royalBlue:
            return Color(red: 0.1, green: 0.2, blue: 0.5)
        case .charcoal:
            return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .desert:
            return Color(red: 0.76, green: 0.59, blue: 0.48)
        case .custom:
            let r = UserDefaults.standard.double(forKey: "custom_felt_red")
            let g = UserDefaults.standard.double(forKey: "custom_felt_green")
            let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
            if r == 0 && g == 0 && b == 0 {
                return Color(red: 0.35, green: 0.15, blue: 0.45)
            }
            return Color(red: r, green: g, blue: b)
        }
    }

    public var statusBarColor: Color {
        switch self {
        case .feltGreen:
            return Color(red: 0.0, green: 0.45, blue: 0.0)
        case .crimson:
            return Color(red: 0.48, green: 0.03, blue: 0.12)
        case .royalBlue:
            return Color(red: 0.08, green: 0.16, blue: 0.42)
        case .charcoal:
            return Color(red: 0.14, green: 0.14, blue: 0.14)
        case .desert:
            return Color(red: 0.71, green: 0.54, blue: 0.43)
        case .custom:
            let r = UserDefaults.standard.double(forKey: "custom_felt_red")
            let g = UserDefaults.standard.double(forKey: "custom_felt_green")
            let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
            if r == 0 && g == 0 && b == 0 {
                return Color(red: 0.3, green: 0.12, blue: 0.38)
            }
            return Color(red: max(0, r - 0.05), green: max(0, g - 0.05), blue: max(0, b - 0.05))
        }
    }
}
