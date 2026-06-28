import Foundation

public enum GameMode: String, Codable, CaseIterable, Identifiable {
    case klondike = "Klondike Solitaire"
    case beecell = "Freecell"
    case spider = "Spider Solitaire"
    case videoPoker = "Video Poker"
    case blackjack  = "Video Blackjack"

    public var id: String { self.rawValue }
}
