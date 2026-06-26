import Foundation

public struct PokerbeePlayer: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var sessionChips: Int
    public var hand: [Card]
    public var currentBet: Int
    public var isFolded: Bool
    public var isAI: Bool
    public var aiDifficulty: AIDifficulty

    public init(id: UUID = UUID(), name: String, sessionChips: Int,
                isAI: Bool, aiDifficulty: AIDifficulty = .medium) {
        self.id = id
        self.name = name
        self.sessionChips = sessionChips
        self.hand = []
        self.currentBet = 0
        self.isFolded = false
        self.isAI = isAI
        self.aiDifficulty = aiDifficulty
    }
}

public struct PokerbeeGameState {
    public enum Phase: Equatable {
        case waiting
        case dealing
        case preDrawBetting
        case drawing
        case postDrawBetting
        case showdown
        case handOver
    }

    public var players: [PokerbeePlayer]
    public var deck: [Card]
    public var pot: Int
    public var currentPhase: Phase
    public var activePlayerIndex: Int
    public var dealerIndex: Int
    public var handNumber: Int
    public var currentBetAmount: Int
    public var lastRaiseAmount: Int
    public var timerSeconds: Int
    public var isTimerActive: Bool
    public var lastWinnerName: String?
    public var lastWinningHand: String?
    public var selectedDiscardIndices: Set<Int>

    public init() {
        self.players = []
        self.deck = []
        self.pot = 0
        self.currentPhase = .waiting
        self.activePlayerIndex = 0
        self.dealerIndex = 0
        self.handNumber = 0
        self.currentBetAmount = 0
        self.lastRaiseAmount = 0
        self.timerSeconds = 0
        self.isTimerActive = false
        self.lastWinnerName = nil
        self.lastWinningHand = nil
        self.selectedDiscardIndices = []
    }

    public var activePlayers: [PokerbeePlayer] {
        players.filter { !$0.isFolded }
    }

    public var humanPlayer: PokerbeePlayer? {
        players.first { !$0.isAI }
    }

    public var humanPlayerIndex: Int? {
        players.firstIndex { !$0.isAI }
    }

    public var isHumanTurn: Bool {
        guard !players.isEmpty else { return false }
        return activePlayerIndex < players.count &&
               !players[activePlayerIndex].isAI &&
               !players[activePlayerIndex].isFolded
    }
}
