import Foundation

public enum GameMode: String, Codable, CaseIterable, Identifiable {
    case klondike = "Klondike Solitaire"
    case beecell = "Freecell"
    case spider = "Spider Solitaire"
    case videoPoker = "Video Poker"
    case blackjack  = "Video Blackjack"
    case honeycomb  = "Honeycomb"

    public var id: String { self.rawValue }

    // Shown in the Game Selection dropdown. Distinct from `rawValue` so the persisted
    // "last selected game" UserDefaults value (keyed off rawValue) isn't disturbed by a
    // label-only rename.
    public var displayName: String {
        switch self {
        case .klondike:   return "Klondike Solibee"
        case .beecell:    return "Beecell"
        case .spider:     return "Spider Solibee"
        case .videoPoker: return rawValue
        case .blackjack:  return rawValue
        case .honeycomb:  return "Honeycomb"
        }
    }
}
