import Foundation

public struct SpiderModeStats: Codable, Equatable {
    public var gamesPlayed: Int = 0
    public var gamesWon: Int = 0
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var highScore: Int = 500
    
    public init(
        gamesPlayed: Int = 0,
        gamesWon: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        highScore: Int = 500
    ) {
        self.gamesPlayed = gamesPlayed
        self.gamesWon = gamesWon
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.highScore = highScore
    }
    
    public var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return (Double(gamesWon) / Double(gamesPlayed)) * 100.0
    }
}

public struct SpiderStatistics: Codable, Equatable {
    public var statsBySuits: [Int: SpiderModeStats] = [:]
    
    public init(statsBySuits: [Int: SpiderModeStats] = [:]) {
        self.statsBySuits = statsBySuits
    }
}
