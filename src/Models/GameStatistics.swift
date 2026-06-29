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
}
