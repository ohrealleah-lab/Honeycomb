# Data Model & State Transitions: Solitaire SoliBee

## 1. Data Structures

### Card
Represents an individual playing card.
```swift
struct Card: Identifiable, Equatable, Codable {
    enum Suit: String, CaseIterable, Codable {
        case hearts, diamonds, spades, clubs
        
        var isRed: Bool {
            self == .hearts || self == .diamonds
        }
    }
    
    let id: UUID
    let suit: Suit
    let rank: Int // 1 (Ace) to 13 (King)
    var faceUp: Bool
    
    var isRed: Bool { suit.isRed }
    var isBlack: Bool { !suit.isRed }
}
```

### GameState
Aggregates the entire board state.
```swift
struct GameState: Codable {
    var stock: [Card]
    var waste: [Card]
    var foundations: [Card.Suit: [Card]]
    var tableau: [[Card]] // 7 columns, containing face-down and face-up cards
    
    var score: Int
    var timerSeconds: Int
    var isTimerActive: Bool
    var drawMode: DrawMode
    
    enum DrawMode: String, Codable {
        case drawOne
        case drawThree
    }
}
```

---

## 2. Validation Rules

### Tableau to Tableau Move
A sequence of face-up cards $C$ starting with $C_0$ can be moved onto a Tableau pile $T$ if and only if:
1. $T$ is empty and $C_0.rank == 13$ (King).
2. $T$ is not empty, and $C_0.rank == T.last.rank - 1$, and $C_0.isRed \neq T.last.isRed$ (opposite colors, descending rank).

### Waste to Tableau Move
A waste card $W$ can be moved onto a Tableau pile $T$ if and only if:
1. $T$ is empty and $W.rank == 13$ (King).
2. $T$ is not empty, and $W.rank == T.last.rank - 1$, and $W.isRed \neq T.last.isRed$.

### Move to Foundation
A card $C$ can be moved onto a Foundation pile $F$ for suit $S$ if and only if:
1. $F$ is empty and $C.rank == 1$ (Ace) and $C.suit == S$.
2. $F$ is not empty, and $C.suit == S$, and $C.rank == F.last.rank + 1$.

---

## 3. State Transitions

### Initial Setup
1. Instantiate a deck of 52 cards (ranks 1-13 for each of the 4 suits).
2. Shuffle the deck.
3. Deal into 7 Tableau columns:
   - Column 0 gets 1 card, Column 1 gets 2 cards, ..., Column 6 gets 7 cards.
   - The top card of each column is set to `faceUp = true`. All other cards are `faceUp = false`.
4. Place the remaining 24 cards into the `stock` pile (`faceUp = false`).
5. Initialize `waste` as empty.
6. Initialize `foundations` for all four suits as empty.
7. Set `score = 0` and `timerSeconds = 0`.

### Draw Card
- **1-Card Draw**:
  - Pop 1 card from `stock`, set its `faceUp = true`, and append to `waste`.
- **3-Card Draw**:
  - Pop up to 3 cards from `stock` (or all remaining if $< 3$), set their `faceUp = true`, and append to `waste`.

### Recycle Stock
- If `stock` is empty, click the empty stock spot:
  - Reverse the entire `waste` pile, set all cards `faceUp = false`, assign to `stock`, and set `waste` as empty.

### Auto-Flip Tableau
- If a card move from Tableau column $T$ leaves a face-down card as the new top card of $T$, automatically set `card.faceUp = true`.

### Autocomplete Check
- Triggered when:
  - `stock` is empty and `waste` is empty.
  - All Tableau columns contain 0 face-down cards.
  - At least one card is playable to a Foundation.
