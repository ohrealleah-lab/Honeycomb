# Data Model Design: SoliBee Windows Port

This document details the C# data model definitions, relationships, and validation rules for the ported application.

## 1. Class Definitions & Schema

### Card
Represents a single playing card.
```csharp
public record Card(
    string Id,          // Unique ID, e.g., "spades_A"
    CardSuit Suit,      // Suit enum (Spades, Hearts, Diamonds, Clubs)
    int Rank,           // 1 (Ace) to 13 (King)
    bool IsFaceUp       // Visibility state
);
```

### CardSuit Enum
```csharp
public enum CardSuit { Spades, Hearts, Diamonds, Clubs }
```

### Pile
Represents an ordered list of cards with specific layout constraints.
```csharp
public class Pile
{
    public string Id { get; }
    public PileType Type { get; }
    public List<Card> Cards { get; } = new();

    public Pile(string id, PileType type)
    {
        Id = id;
        Type = type;
    }
}
```

### PileType Enum
```csharp
public enum PileType { Stock, Waste, Foundation, Tableau }
```

### GameState
Tracks active match parameters and score values.
```csharp
public class GameState
{
    public int Score { get; set; }
    public int MovesCount { get; set; }
    public int TimerSeconds { get; set; }
    public bool IsTimerActive { get; set; }
    public bool HasWon { get; set; }
    public int RecyclesCount { get; set; }
    public DrawMode Mode { get; set; }
}
```

### DrawMode Enum
```csharp
public enum DrawMode { DrawOne, DrawThree }
```

### GameOptions
Tracks user preferences across game modes.
```csharp
public class GameOptions
{
    public FeltColorTheme FeltColor { get; set; } = FeltColorTheme.FeltGreen;
    public string CardBackTheme { get; set; } = "Vulpera";
    public bool IsTimed { get; set; } = true;
    public bool IsSoundEnabled { get; set; } = true;
    public bool IsVegasScoring { get; set; } = false;
    public bool IsDrawConstraintsEnabled { get; set; } = false;
    public int CustomFeltColorRevision { get; set; } = 0;
}

public enum FeltColorTheme
{
    FeltGreen,
    Crimson,
    RoyalBlue,
    Charcoal,
    Desert,
    Custom
}
```

### GameStatistics
Cumulative history trackers.
```csharp
public class GameStatistics
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int VegasHighScore { get; set; }
    public int StandardHighScore { get; set; }
}
```

## 2. Serialization & Persistence Strategy

- **GameOptions**: Saved directly using Windows application settings API:
  - Key: `FeltColor` (String representation)
  - Key: `CardBackTheme` (String)
  - Key: `IsTimed` (Boolean)
  - Key: `IsSoundEnabled` (Boolean)
  - Key: `IsVegasScoring` (Boolean)
  - Key: `IsDrawConstraintsEnabled` (Boolean)
  - Key: `CustomFeltColorRevision` (Integer)
- **GameStatistics**: Serialized to a JSON file (`stats.json`) using `System.Text.Json` and stored in the local application folder:
  - Path: `Windows.Storage.ApplicationData.Current.LocalFolder`
