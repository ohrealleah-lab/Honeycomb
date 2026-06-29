import Foundation

public struct GameStatistics: Codable, Equatable {
    public var gamesPlayed: Int = 0
    public var gamesWon: Int = 0
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var totalWinningTime: Int = 0
    public var winningGamesCount: Int = 0
    public var shortestWinTime: Int = 0

    public init(
        gamesPlayed: Int = 0,
        gamesWon: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalWinningTime: Int = 0,
        winningGamesCount: Int = 0,
        shortestWinTime: Int = 0
    ) {
        self.gamesPlayed = gamesPlayed
        self.gamesWon = gamesWon
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalWinningTime = totalWinningTime
        self.winningGamesCount = winningGamesCount
        self.shortestWinTime = shortestWinTime
    }
    
    public var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return (Double(gamesWon) / Double(gamesPlayed)) * 100.0
    }
    
    public var averageWinningTime: Double {
        guard winningGamesCount > 0 else { return 0.0 }
        return Double(totalWinningTime) / Double(winningGamesCount)
    }

    enum CodingKeys: String, CodingKey {
        case gamesPlayed, gamesWon, currentStreak, longestStreak
        case totalWinningTime, winningGamesCount, shortestWinTime
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed       = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed)       ?? 0
        gamesWon          = try c.decodeIfPresent(Int.self, forKey: .gamesWon)           ?? 0
        currentStreak     = try c.decodeIfPresent(Int.self, forKey: .currentStreak)      ?? 0
        longestStreak     = try c.decodeIfPresent(Int.self, forKey: .longestStreak)      ?? 0
        totalWinningTime  = try c.decodeIfPresent(Int.self, forKey: .totalWinningTime)   ?? 0
        winningGamesCount = try c.decodeIfPresent(Int.self, forKey: .winningGamesCount)  ?? 0
        shortestWinTime   = try c.decodeIfPresent(Int.self, forKey: .shortestWinTime)    ?? 0
    }
}
