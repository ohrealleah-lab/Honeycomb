# Data Model & State Transitions: Pokerbee & Tejas Hold'em

## 1. Shared Models (src/Models/)

### PokerHandRank
```swift
public enum PokerHandRank: Int, Comparable, CaseIterable {
    case highCard = 0
    case onePair
    case twoPair
    case threeOfAKind
    case straight
    case flush
    case fullHouse
    case fourOfAKind
    case straightFlush
    case royalFlush

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
```

### PokerHandResult
```swift
public struct PokerHandResult: Comparable {
    public let rank: PokerHandRank
    public let kickers: [Int]   // up to 5 card ranks, descending

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.kickers.lexicographicallyPrecedes(rhs.kickers)
    }
}
```

### PokerHandEvaluator
```swift
public struct PokerHandEvaluator {
    // Evaluate exactly 5 cards (Pokerbee showdown)
    public static func evaluate(_ five: [Card]) -> PokerHandResult

    // Best 5-of-7: try all C(7,5)=21 combinations, return highest (Tejas showdown)
    public static func bestFiveOfSeven(hole: [Card], community: [Card]) -> PokerHandResult
}
```

### PokerAI
```swift
public enum AIDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard
}

public enum PokerAction {
    case fold, check, call, raise(Int), discard([Int])  // discard: indices to replace
}

public struct PokerAI {
    public static func decideAction(
        hand: [Card],
        communityCards: [Card],   // empty for Pokerbee pre-draw
        pot: Int,
        callAmount: Int,
        difficulty: AIDifficulty
    ) -> PokerAction

    // Pokerbee draw phase only
    public static func decideDiscards(hand: [Card], difficulty: AIDifficulty) -> [Int]
}
```

### SidePot (Tejas only)
```swift
public struct SidePot {
    public var amount: Int
    public var eligiblePlayerIDs: Set<UUID>
}
```

---

## 2. Pokerbee Models

### PokerbeeOptions
```swift
public struct PokerbeeOptions: Codable, Equatable {
    public var seatCount: Int = 3              // 2–6 total (human + AI)
    public var startingChips: Int = 1000
    public var ante: Int = 10
    public var aiDifficulty: AIDifficulty = .medium
    public var noBidMode: Bool = false
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    public var isDarkMode: Bool = false
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var customFeltColorRevision: Int = 0

    // CodingKeys: one case per property
    // init(from:): decodeIfPresent ?? default for every field
}
```

### PokerbeePlayer
```swift
public struct PokerbeePlayer: Identifiable {
    public let id: UUID
    public var name: String
    public var sessionChips: Int
    public var hand: [Card]           // 5 cards when dealt
    public var currentBet: Int
    public var isFolded: Bool
    public var isAI: Bool
    public var aiDifficulty: AIDifficulty
}
```

### PokerbeeGameState
```swift
public struct PokerbeeGameState {
    public enum Phase {
        case waiting
        case dealing
        case preDrawBetting        // skipped when noBidMode == true
        case drawing
        case postDrawBetting       // skipped when noBidMode == true
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
}
```

### State Transitions — Pokerbee

**Deal**
1. Shuffle 52-card deck.
2. Deal 5 cards to each non-folded player in clockwise order from dealerIndex+1.
3. Collect ante from each player → add to pot (skipped in noBidMode).
4. Transition to `.preDrawBetting` (or `.drawing` if noBidMode).

**Pre-Draw Betting**
- Turn order: clockwise from dealerIndex+1.
- Legal actions: Fold, Check (if no bet), Call, Raise.
- Round ends when all active players have matched the highest bet.
- Transition to `.drawing`.

**Draw Phase**
- Human selects 0–5 cards to discard; replacement cards dealt from remaining deck.
- Each AI calls `PokerAI.decideDiscards` then receives replacement cards.
- Transition to `.postDrawBetting` (or `.showdown` if noBidMode).

**Post-Draw Betting** — same rules as pre-draw.

**Showdown**
- Remaining players reveal hands.
- Each hand evaluated via `PokerHandEvaluator.evaluate(_:)`.
- Highest `PokerHandResult` wins the pot. Tied results split the pot.
- Transition to `.handOver`; dealer index advances.

---

## 3. Tejas Hold'em Models

### TejasOptions
```swift
public struct TejasOptions: Codable, Equatable {
    public var seatCount: Int = 4              // 2–6 total
    public var startingChips: Int = 1000
    public var smallBlind: Int = 10
    public var bigBlind: Int = 20
    public var aiDifficulty: AIDifficulty = .medium
    public var isTimed: Bool = true
    public var isSoundEnabled: Bool = true
    public var hideHintButton: Bool = false
    public var hideStatsButton: Bool = false
    public var isDarkMode: Bool = false
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var customFeltColorRevision: Int = 0

    // CodingKeys: one case per property
    // init(from:): decodeIfPresent ?? default for every field
}
```

### TejasPlayer
```swift
public struct TejasPlayer: Identifiable {
    public let id: UUID
    public var name: String
    public var sessionChips: Int
    public var holeCards: [Card]      // exactly 2 when dealt
    public var currentBet: Int
    public var isFolded: Bool
    public var isAllIn: Bool
    public var isAI: Bool
    public var aiDifficulty: AIDifficulty
    public var isDealer: Bool
}
```

### TejasGameState
```swift
public struct TejasGameState {
    public enum Phase: String, Codable {
        case waiting, preFlop, flop, turn, river, showdown, handOver
    }

    public var players: [TejasPlayer]
    public var deck: [Card]
    public var communityCards: [Card]       // 0–5
    public var pot: Int
    public var sidePots: [SidePot]
    public var currentPhase: Phase
    public var activePlayerIndex: Int
    public var dealerIndex: Int
    public var minimumBet: Int              // current round minimum raise
    public var lastRaiseAmount: Int
    public var handNumber: Int
}
```

### State Transitions — Tejas Hold'em

**Deal (preFlop)**
1. Rotate dealerIndex.
2. Post small blind (dealer+1) and big blind (dealer+2); deduct from player chips.
3. Shuffle 52-card deck; deal 2 hole cards per player clockwise from dealer+1.
4. Set activePlayerIndex to dealer+3 (under-the-gun).
5. Transition to `.preFlop`.

**Betting Round (all streets)**
- Each active (non-folded, non-allIn) player acts in turn.
- Legal actions: Fold, Check (if currentBet == 0), Call, Raise (min = lastRaiseAmount × 2 or bigBlind).
- If a player's chips < callAmount: they go all-in; trigger side pot creation.
- Round ends when all active players have matched the highest bet or are all-in.

**Flop**: burn 1 card, deal 3 face-up to communityCards → new betting round.  
**Turn**: burn 1, deal 1 face-up → new betting round.  
**River**: burn 1, deal 1 face-up → final betting round.

**Showdown**
- Remaining players reveal hole cards.
- Each player's best hand: `PokerHandEvaluator.bestFiveOfSeven(hole:community:)`.
- Award main pot to best hand; distribute side pots to eligible winners.
- Transition to `.handOver`; advance dealerIndex.

**Side Pot Construction**
When player P goes all-in for amount A:
- A new SidePot is created covering A × (eligible player count).
- All bets above A from other players overflow into the next pot.
- P is eligible only for the pot(s) created at or below their all-in amount.

---

## 4. Statistics

### PokerbeeStatistics / TejasStatistics (same shape)
```swift
public struct PokerStatistics: Codable {
    public var handsPlayed: Int = 0
    public var handsWon: Int = 0
    public var biggestPotWon: Int = 0
    public var netSessionChips: Int = 0    // chips gained or lost this session
    public var rebuyCount: Int = 0

    // init(from:): decodeIfPresent ?? default for every field
}
```

Saved to UserDefaults under `"pokerbee_statistics"` and `"tejas_statistics"`.  
`netSessionChips` is reset to 0 on each app launch (session-scoped, like chip balance).
