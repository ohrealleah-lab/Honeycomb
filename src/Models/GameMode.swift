import Foundation

public enum GameMode: String, Codable, CaseIterable, Identifiable {
    case klondike = "Klondike Solibee"
    case beecell = "Beecell"
    case spider = "Spider Solibee"
    
    public var id: String { self.rawValue }
}
