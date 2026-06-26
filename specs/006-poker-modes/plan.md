# Implementation Plan: Pokerbee & Tejas Hold'em

**Branch**: `006-poker-modes` | **Date**: 2026-06-24 | **Spec**: [spec.md](./spec.md)

## Summary

Two new game modes grafted into the existing SoliBee app following the established three-layer pattern. Every file mirrors its Beecell counterpart in structure — the Beecell trio (`BeecellOptions`, `BeecellViewModel`, `BeecellView`) is the direct template for each new mode. The hand evaluator (shared between Pokerbee and Tejas) is the only genuinely new algorithmic work; the rest is plumbing that follows patterns already in the codebase.

## Technical Context

**Language**: Swift 6 / SwiftUI  
**Build**: `make build` (unchanged — new files are picked up automatically by SPM)  
**Architecture**: identical MVVM to existing games  
**Storage**: `UserDefaults` JSON under keys `"pokerbee_options"`, `"tejas_options"`, `"pokerbee_statistics"`, `"tejas_statistics"`  
**Chip balance**: in-memory only; initialized from `options.startingChips` on ViewModel init; never written to UserDefaults  

## New Files

```
src/
├── Models/
│   ├── GameMode.swift              MODIFY — add .pokerbee, .tejas cases
│   ├── PokerHandRank.swift         NEW — enum + PokerHandResult struct
│   ├── PokerHandEvaluator.swift    NEW — best-5-of-N evaluator (shared)
│   └── SidePot.swift               NEW — used by Tejas only
│
├── Pokerbee/
│   ├── Models/
│   │   ├── PokerbeeOptions.swift   NEW
│   │   ├── PokerbeeState.swift     NEW — PokerbeeGameState + PokerbeePlayer
│   │   └── PokerbeeStatistics.swift NEW
│   ├── ViewModels/
│   │   └── PokerbeeViewModel.swift NEW
│   └── Views/
│       ├── PokerbeeView.swift      NEW — game board + inline PokerbeeOptionsView
│       └── PokerbeeViews.swift     NEW — sub-views (player seat, pot display, etc.)
│
├── Tejas/
│   ├── Models/
│   │   ├── TejasOptions.swift      NEW
│   │   ├── TejasState.swift        NEW — TejasGameState + TejasPlayer
│   │   └── TejasStatistics.swift   NEW
│   ├── ViewModels/
│   │   └── TejasViewModel.swift    NEW
│   └── Views/
│       ├── TejasView.swift         NEW — game board + inline TejasOptionsView
│       └── TejasViews.swift        NEW — sub-views (community cards, seats, etc.)
│
└── ViewModels/
    └── AppCoordinator.swift        MODIFY — add pokerbeeViewModel, tejasViewModel,
                                             extend syncSharedOptions to 5 modes
```

## Key Architecture Decisions

### Template: Beecell, not Klondike
Klondike (`GameViewModel`) has Vegas scoring, draw mode, and a larger options surface. Beecell is the cleaner template: a mode picker at the top of options, then the shared toggle block, then felt/art. The poker modes replace the Beecell deck-count picker with their own game-specific section.

### Hand Evaluator (shared)
`PokerHandEvaluator.swift` in `src/Models/` is used by both ViewModels. It evaluates the best 5-card hand from N cards (5 for Pokerbee showdown, 7 for Tejas showdown). Pokerbee passes 5 cards directly; Tejas passes 2 hole + 5 community and the evaluator finds the best 5-of-7.

```swift
public enum PokerHandRank: Int, Comparable, CaseIterable {
    case highCard, onePair, twoPair, threeOfAKind,
         straight, flush, fullHouse, fourOfAKind, straightFlush, royalFlush
}

public struct PokerHandResult: Comparable {
    public let rank: PokerHandRank
    public let kickers: [Int]   // descending, for tiebreaking
}

public struct PokerHandEvaluator {
    public static func best(from cards: [Card]) -> PokerHandResult
    public static func bestFiveOfSeven(hole: [Card], community: [Card]) -> PokerHandResult
}
```

### AI Strategy
Both modes share a common `PokerAI` helper (also in `src/Models/`) that takes a hand, pot odds, and difficulty level and returns a recommended action. Difficulty maps to bluff frequency and hand-strength threshold:

| Difficulty | Bluff rate | Fold threshold |
|---|---|---|
| Easy | 3% | Folds anything below one pair |
| Medium | 8% | Folds below pair + pot-odds check |
| Hard | 18% | Full pot-odds + draw-out estimation |

### Session Chip Balance
Each ViewModel owns `var sessionChips: Int` initialized to `options.startingChips` in `init()`. It is never saved to UserDefaults — resets to `options.startingChips` on next app launch. Rebuy adds `options.startingChips` to `sessionChips` and increments `statistics.rebuyCount`.

### AppCoordinator Extension
`syncSharedOptions` grows to handle 5 cases. The shared fields (`isTimed`, `isSoundEnabled`, `hideHintButton`, `hideStatsButton`, `isDarkMode`) are copied from the outgoing mode to all four other modes — identical to the existing 3-mode pattern.

```swift
// GameMode enum after this feature
public enum GameMode: String, Codable, CaseIterable, Identifiable {
    case klondike = "Klondike Solibee"
    case beecell  = "Beecell"
    case spider   = "Spider Solibee"
    case pokerbee = "Pokerbee"
    case tejas    = "Tejas Hold'em"
}
```

### Options View Structure
Both options views follow this exact layout (mirroring Beecell):

```
"Preferences" title
Divider
ScrollView {
    // ── Poker-specific section (replaces Beecell's deck-count picker) ──
    Picker("Players:", selection: $seatCount)          // 2–6 segmented
    Picker("AI Difficulty:", selection: $aiDifficulty) // Easy/Medium/Hard segmented
    TextField / Stepper for startingChips
    TextField / Stepper for ante (Pokerbee) or smallBlind + bigBlind (Tejas)
    Toggle("No Bid Mode", isOn: $noBidMode)            // Pokerbee only
    Divider

    // ── Shared toggle block (identical to Beecell) ──
    Toggle("Timed Game", ...)
    Toggle("Sound Effects", ...)
    Toggle("Hide Hint button", ...)
    Toggle("Hide Stats button", ...)
    Toggle("Dark Mode Cards", ...)
    Divider

    // ── Felt color (identical to Beecell) ──
    Picker("Felt Color:", ...)
    [Custom color picker if .custom]
    Divider

    // ── Custom card art panel (identical to Beecell) ──
    CustomArtPanelView(...)
}
OK / Cancel / View Stats buttons
```

## Constitution Check

No violations. All game logic in Models/ViewModels; Views are pure layout. New files follow existing naming and folder conventions exactly.
