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
    
    public init(
        gamesPlayed: Int = 0,
        gamesWon: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        highScore: Int = 0
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
