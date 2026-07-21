import Foundation

public enum HoneycombDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case ultraHard = "Ultra Hard"
}

public enum HoneycombGameState: String, Codable, Equatable {
    case setup
    case playing
    case gameOver
    case suddenDeath
}

public struct SimplifiedCard: Codable {
    public var name: String
    public var owner: String
    public var stats: [Int]

    public init(card: HoneycombCard) {
        self.name = card.data.name
        self.owner = card.owner == .player ? "player" : "opponent"
        self.stats = (0..<4).map { card.stat(at: $0) }
    }

    public init(name: String, owner: String, stats: [Int]) {
        self.name = name
        self.owner = owner
        self.stats = stats
    }
}

public struct HoneycombLegalMove: Codable {
    public var action: String
    public var handIndex: Int?
    public var boardIndex: Int?
    public var replaceHandIndex: Int?
}

public struct HoneycombState: Codable {
    public var gameState: HoneycombGameState
    public var isPlayerTurn: Bool
    public var activeRules: [HoneycombRule]
    public var playerHand: [SimplifiedCard]
    public var opponentHand: [SimplifiedCard]
    public var board: [SimplifiedCard?]
    public var playerScore: Int
    public var opponentScore: Int
    public var matchResult: String
    public var showPostGamePrompt: Bool
    public var legalMoves: [HoneycombLegalMove]
}
