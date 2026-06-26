import Foundation

public struct TejasPlayer: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var sessionChips: Int
    public var holeCards: [Card]
    public var currentBet: Int
    public var totalBetThisRound: Int
    public var isFolded: Bool
    public var isAllIn: Bool
    public var isAI: Bool
    public var aiDifficulty: AIDifficulty
    public var isDealer: Bool

    public init(id: UUID = UUID(), name: String, sessionChips: Int,
                isAI: Bool, aiDifficulty: AIDifficulty = .medium) {
        self.id = id
        self.name = name
        self.sessionChips = sessionChips
        self.holeCards = []
        self.currentBet = 0
        self.totalBetThisRound = 0
        self.isFolded = false
        self.isAllIn = false
        self.isAI = isAI
        self.aiDifficulty = aiDifficulty
        self.isDealer = false
    }
}

public struct TejasGameState {
    public enum Phase: String, Codable, Equatable {
        case waiting, preFlop, flop, turn, river, showdown, handOver
    }

    public var players: [TejasPlayer]
    public var deck: [Card]
    public var communityCards: [Card]
    public var pot: Int
    public var sidePots: [SidePot]
    public var currentPhase: Phase
    public var activePlayerIndex: Int
    public var dealerIndex: Int
    public var minimumBet: Int
    public var lastRaiseAmount: Int
    public var handNumber: Int
    public var timerSeconds: Int
    public var isTimerActive: Bool
    public var lastWinnerName: String?
    public var lastWinningHand: String?
    public var actedThisRound: Set<UUID>   // tracks who has acted in current betting round

    public init() {
        self.players = []
        self.deck = []
        self.communityCards = []
        self.pot = 0
        self.sidePots = []
        self.currentPhase = .waiting
        self.activePlayerIndex = 0
        self.dealerIndex = 0
        self.minimumBet = 0
        self.lastRaiseAmount = 0
        self.handNumber = 0
        self.timerSeconds = 0
        self.isTimerActive = false
        self.lastWinnerName = nil
        self.lastWinningHand = nil
        self.actedThisRound = []
    }

    public var activePlayers: [TejasPlayer] {
        players.filter { !$0.isFolded && !$0.isAllIn }
    }

    public var contestingPlayers: [TejasPlayer] {
        players.filter { !$0.isFolded }
    }

    public var humanPlayer: TejasPlayer? {
        players.first { !$0.isAI }
    }

    public var humanPlayerIndex: Int? {
        players.firstIndex { !$0.isAI }
    }

    public var isHumanTurn: Bool {
        guard !players.isEmpty, activePlayerIndex < players.count else { return false }
        return !players[activePlayerIndex].isAI &&
               !players[activePlayerIndex].isFolded &&
               !players[activePlayerIndex].isAllIn
    }

    // Build side pots from all-in players
    public mutating func buildSidePots() {
        sidePots.removeAll()
        let allInPlayers = contestingPlayers.filter { $0.isAllIn }.sorted { $0.totalBetThisRound < $1.totalBetThisRound }
        guard !allInPlayers.isEmpty else { return }

        var remaining = contestingPlayers
        var covered: Int = 0

        for allInPlayer in allInPlayers {
            let level = allInPlayer.totalBetThisRound - covered
            if level <= 0 { continue }
            let eligible = Set(remaining.filter { $0.totalBetThisRound >= allInPlayer.totalBetThisRound }.map { $0.id })
            let amount = level * eligible.count
            sidePots.append(SidePot(amount: amount, eligiblePlayerIDs: eligible))
            covered = allInPlayer.totalBetThisRound
            remaining = remaining.filter { !allInPlayers.map { $0.id }.contains($0.id) || $0.totalBetThisRound > covered }
        }
    }
}
