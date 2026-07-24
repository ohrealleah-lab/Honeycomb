import Foundation

public struct HoneycombStats: Codable, Equatable {
    public var gamesPlayed: Int = 0
    public var matchesWon: Int = 0
    public var matchesLost: Int = 0
    public var matchesDrawn: Int = 0
    public var cardsCaptured: Int = 0

    public var currentWinStreak: Int = 0
    public var longestWinStreak: Int = 0
    public var flawlessVictories: Int = 0
    public var samePlusTriggers: Int = 0
    // Added after the initial Codable rollout — decoded via decodeIfPresent so older
    // saved stats (missing this key) don't fail to decode and silently reset to zero.
    public var ultraHardWins: Int = 0
    public var timesStartedOver: Int = 0
    public var easyWins: Int = 0
    public var mediumWins: Int = 0
    public var hardWins: Int = 0
    public var cardsStolen: Int = 0
    public var fallenAces: Int = 0
    public var suddenDeathCount: Int = 0

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case gamesPlayed, matchesWon, matchesLost, matchesDrawn, cardsCaptured
        case currentWinStreak, longestWinStreak, flawlessVictories, samePlusTriggers
        case ultraHardWins, timesStartedOver
        case easyWins, mediumWins, hardWins
        case cardsStolen, fallenAces, suddenDeathCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        matchesWon = try container.decodeIfPresent(Int.self, forKey: .matchesWon) ?? 0
        matchesLost = try container.decodeIfPresent(Int.self, forKey: .matchesLost) ?? 0
        matchesDrawn = try container.decodeIfPresent(Int.self, forKey: .matchesDrawn) ?? 0
        cardsCaptured = try container.decodeIfPresent(Int.self, forKey: .cardsCaptured) ?? 0
        currentWinStreak = try container.decodeIfPresent(Int.self, forKey: .currentWinStreak) ?? 0
        longestWinStreak = try container.decodeIfPresent(Int.self, forKey: .longestWinStreak) ?? 0
        flawlessVictories = try container.decodeIfPresent(Int.self, forKey: .flawlessVictories) ?? 0
        samePlusTriggers = try container.decodeIfPresent(Int.self, forKey: .samePlusTriggers) ?? 0
        ultraHardWins = try container.decodeIfPresent(Int.self, forKey: .ultraHardWins) ?? 0
        timesStartedOver = try container.decodeIfPresent(Int.self, forKey: .timesStartedOver) ?? 0
        easyWins = try container.decodeIfPresent(Int.self, forKey: .easyWins) ?? 0
        mediumWins = try container.decodeIfPresent(Int.self, forKey: .mediumWins) ?? 0
        hardWins = try container.decodeIfPresent(Int.self, forKey: .hardWins) ?? 0
        cardsStolen = try container.decodeIfPresent(Int.self, forKey: .cardsStolen) ?? 0
        fallenAces = try container.decodeIfPresent(Int.self, forKey: .fallenAces) ?? 0
        suddenDeathCount = try container.decodeIfPresent(Int.self, forKey: .suddenDeathCount) ?? 0
    }

    public mutating func recordGame(won: Bool, drawn: Bool, captures: Int, sessionCombos: Int, flawless: Bool, difficulty: HoneycombDifficulty? = nil, fallenAceCaptures: Int = 0) {
        gamesPlayed += 1
        cardsCaptured += captures
        samePlusTriggers += sessionCombos
        fallenAces += fallenAceCaptures

        if drawn {
            matchesDrawn += 1
            currentWinStreak = 0
        } else if won {
            matchesWon += 1
            currentWinStreak += 1
            if currentWinStreak > longestWinStreak {
                longestWinStreak = currentWinStreak
            }
            if flawless {
                flawlessVictories += 1
            }
            switch difficulty {
            case .easy: easyWins += 1
            case .medium: mediumWins += 1
            case .hard: hardWins += 1
            case .ultraHard: ultraHardWins += 1
            case nil: break
            }
        } else {
            matchesLost += 1
            currentWinStreak = 0
        }
    }
}
