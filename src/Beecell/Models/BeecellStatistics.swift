import Foundation

public struct BeecellStatistics: Codable, Equatable {
    public var statsByMode: [String: ModeStats] = [:]
    
    public init(statsByMode: [String: ModeStats] = [:]) {
        self.statsByMode = statsByMode
    }
}

public struct ModeStats: Codable, Equatable {
    public var gamesPlayed: Int = 0
    public var gamesWon: Int = 0
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var highScore: Int = 0
    public var shortestWinTime: Int = 0

    public init(
        gamesPlayed: Int = 0,
        gamesWon: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        highScore: Int = 0,
        shortestWinTime: Int = 0
    ) {
        self.gamesPlayed = gamesPlayed
        self.gamesWon = gamesWon
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.highScore = highScore
        self.shortestWinTime = shortestWinTime
    }
    
    public var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return (Double(gamesWon) / Double(gamesPlayed)) * 100.0
    }

    enum CodingKeys: String, CodingKey {
        case gamesPlayed, gamesWon, currentStreak, longestStreak, highScore, shortestWinTime
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed     = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed)     ?? 0
        gamesWon        = try c.decodeIfPresent(Int.self, forKey: .gamesWon)         ?? 0
        currentStreak   = try c.decodeIfPresent(Int.self, forKey: .currentStreak)    ?? 0
        longestStreak   = try c.decodeIfPresent(Int.self, forKey: .longestStreak)    ?? 0
        highScore       = try c.decodeIfPresent(Int.self, forKey: .highScore)         ?? 0
        shortestWinTime = try c.decodeIfPresent(Int.self, forKey: .shortestWinTime)  ?? 0
    }
}
