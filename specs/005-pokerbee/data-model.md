# Data Model & State Transitions: PokerBee Suite

## 1. Shared Models (PokerBeeCore)

### Card (identical to SoliBee)
```swift
public struct Card: Identifiable, Equatable, Codable {
    public enum Suit: String, CaseIterable, Codable {
        case hearts, diamonds, spades, clubs
        public var isRed: Bool { self == .hearts || self == .diamonds }
        public var symbol: String { /* ♥ ♦ ♠ ♣ */ }
    }
    public let id: UUID
    public let suit: Suit
    public let rank: Int       // 1 (Ace) to 13 (King)
    public var faceUp: Bool
    public var isRed: Bool { suit.isRed }
}
```

### Deck
```swift
public struct Deck {
    public var cards: [Card]
    public let deckCount: Int  // 1 for poker, 1–8 for blackjack

    public mutating func shuffle()
    public mutating func deal() -> Card?          // pop top card
    public var remainingCount: Int { cards.count }
}
```

---

## 2. Texas Hold 'Em Models

### Player
```swift
public struct HoldemPlayer: Identifiable {
    public let id: UUID
    public var name: String
    public var chipBalance: Int
    public var holeCards: [Card]          // always 2 when dealt
    public var currentBet: Int
    public var isFolded: Bool
    public var isAllIn: Bool
    public var isDealer: Bool             // has dealer button
    public var isAI: Bool
    public var bluffFrequency: Double     // 0.0–1.0, AI only
}
```

### PokerHandResult
```swift
public struct PokerHandResult: Comparable {
    public let rank: PokerHandRank
    public let kickers: [Int]             // up to 5 values, descending

    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        return lhs.kickers.lexicographicallyPrecedes(rhs.kickers)
    }
}

public enum PokerHandRank: Int, Comparable, CaseIterable {
    case highCard, onePair, twoPair, threeOfAKind,
         straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush
}
```

### SidePot
```swift
public struct SidePot {
    public var amount: Int
    public var eligiblePlayerIDs: Set<UUID>
}
```

### HoldemGameState
```swift
public struct HoldemGameState {
    public enum Phase: String, Codable {
        case waiting, preFlop, flop, turn, river, showdown, handOver
    }

    public var players: [HoldemPlayer]
    public var deck: Deck
    public var communityCards: [Card]     // 0–5
    public var pot: Int
    public var sidePots: [SidePot]
    public var currentPhase: Phase
    public var activePlayerIndex: Int
    public var dealerIndex: Int
    public var minimumBet: Int
    public var lastRaiseAmount: Int
    public var handNumber: Int
}
```

### State Transitions

**Deal Phase (preFlop)**
1. Rotate dealer button.
2. Post small blind (dealer+1) and big blind (dealer+2).
3. Shuffle fresh deck.
4. Deal 2 hole cards to each non-folded player, clockwise from dealer+1.
5. Set `activePlayerIndex` to dealer+3 (under-the-gun).
6. Transition to `.preFlop`.

**Betting Round**
- For each active (non-folded, non-allIn) player in turn order:
  - Legal actions: Fold, Check (if no bet to call), Call, Raise (min = lastRaise × 2 or BB).
  - Round ends when all active players have matched the highest bet or are all-in.

**Community Card Reveals**
- Flop: burn 1, deal 3 face-up to communityCards.
- Turn: burn 1, deal 1 face-up.
- River: burn 1, deal 1 face-up.

**Showdown**
- Remaining players reveal hole cards.
- Each player's best 5-card hand evaluated from any combination of their 2 hole + 5 community.
- Award main pot to winner; distribute side pots to eligible winners.
- Transition to `.handOver`.

---

## 3. Blackjack Models

### BlackjackHand
```swift
public struct BlackjackHand {
    public var cards: [Card]
    public var bet: Int
    public var isDoubledDown: Bool
    public var isSplit: Bool

    public var total: Int {         // best total ≤ 21, or lowest bust value
        var sum = 0, aces = 0
        for card in cards {
            let v = min(card.rank, 10)
            if card.rank == 1 { aces += 1 }
            sum += v
        }
        while sum + 10 <= 21 && aces > 0 { sum += 10; aces -= 1 }
        return sum
    }

    public var isBust: Bool   { total > 21 }
    public var isBlackjack: Bool { cards.count == 2 && total == 21 }
    public var isSoft: Bool   { /* has usable ace */ }
}
```

### BlackjackGameState
```swift
public struct BlackjackGameState {
    public enum Phase: String, Codable {
        case waiting, playerTurn, dealerTurn, resolved
    }

    public var shoe: Deck
    public var playerHands: [BlackjackHand]   // index 0 is primary; >1 on split
    public var activeHandIndex: Int
    public var dealerHand: BlackjackHand
    public var currentPhase: Phase
    public var insuranceBet: Int               // 0 if not taken
    public var chipBalance: Int
}
```

### State Transitions

**Deal**
1. Player places bet → stored in `playerHands[0].bet`.
2. Deal: player card 1 (face-up), dealer card 1 (face-up), player card 2 (face-up), dealer card 2 (face-down / hole card).
3. If player has Blackjack: check dealer up-card. If dealer shows Ace, offer Insurance. Then reveal dealer hole card. If dealer also BJ → push; else player wins 3:2.
4. Transition to `.playerTurn`.

**Player Actions**
- **Hit**: deal 1 card to activeHand. If bust → resolve that hand.
- **Stand**: move to next hand or dealerTurn if all hands resolved.
- **Double Down**: double bet, deal exactly 1 card, stand.
- **Split** (same-rank pair only): split into 2 hands, deal 1 card to each, act on hand 0 first.
- **Insurance** (dealer shows Ace): side bet = half main bet. Resolved when dealer hole card revealed.

**Dealer Turn**
- Reveal hole card.
- Draw until total ≥ 17 (stand on hard 17, stand on soft 17).
- Compare dealer total to each player hand:
  - Dealer bust or player total higher → player wins 1:1.
  - Equal totals → push.
  - Dealer higher → player loses bet.

---

## 4. Shared Options

### PokerBeeOptions (shared across both games — mirrors SoliBee GameOptions)
```swift
public struct PokerBeeOptions: Codable, Equatable {
    public var feltColor: FeltColorTheme = .feltGreen
    public var cardBackTheme: String = "Vulpera"
    public var isSoundEnabled: Bool = true
    public var isDarkMode: Bool = false
    public var customFeltColorRevision: Int = 0

    // Game-specific options live in HoldemOptions / BlackjackOptions
}
```

### HoldemOptions
```swift
public struct HoldemOptions: Codable, Equatable {
    public var seatCount: Int = 4          // 2–6
    public var startingChips: Int = 1000
    public var bigBlind: Int = 20
    public var aiBluffFrequency: Double = 0.08
    public var isTimed: Bool = false
    // + inherited PokerBeeOptions fields via composition
}
```

### BlackjackOptions
```swift
public struct BlackjackOptions: Codable, Equatable {
    public var deckCount: Int = 6
    public var startingChips: Int = 1000
    public var minimumBet: Int = 10
    public var maximumBet: Int = 500
    public var isTimed: Bool = false
    // + inherited PokerBeeOptions fields via composition
}
```

All init(from:) implementations use `decodeIfPresent ?? default` for every field.
