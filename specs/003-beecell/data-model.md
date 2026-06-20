# Data Model: Beecell

This document defines the schemas and structures used to manage Beecell configurations, stats, and gameplay state.

## 1. Game Options (`BeecellOptions`)
Persistent options saved in `UserDefaults` under key `"beecell_options"`.

```swift
public struct BeecellOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var deckCount: Int = 1 // 1 or 2
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var isVegasScoring: Bool = false
}
```

## 2. Gameplay State (`BeecellState`)
Encapsulates a snapshot of an active game, stored in the undo stack.

```swift
public struct BeecellState: Codable, Equatable {
    public var freeCells: [Pile]        // 4 (1-deck) or 8 (2-decks) cells
    public var foundations: [Pile]     // 4 (1-deck) or 8 (2-decks) foundations
    public var tableau: [Pile]         // 8 (1-deck) or 10 (2-decks) columns
    public var score: Int
    public var movesCount: Int
    public var timerSeconds: Int
    public var isTimerActive: Bool
    public var hasWon: Bool
}
```

## 3. Game Statistics (`BeecellStatistics`)
Tracked separately from SoliBee stats, persisted under key `"beecell_statistics"`.

```swift
public struct BeecellStatistics: Codable, Equatable {
    // Dictionary mapping keys (e.g. "standard_1deck", "vegas_2decks") to gamesPlayed, gamesWon, streaks
    public var statsByMode: [String: ModeStats] = [:]
}

public struct ModeStats: Codable, Equatable {
    public var gamesPlayed: Int = 0
    public var gamesWon: Int = 0
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var highScore: Int = 0
}
```
