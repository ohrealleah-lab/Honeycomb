import Foundation

public enum GameMode: String, Codable, CaseIterable, Identifiable {
    case klondike = "Klondike Solibee"
    case beecell = "Beecell"
    case spider = "Spider Solibee"
    case videoPoker = "Video Poker"

    public var id: String { self.rawValue }
}
