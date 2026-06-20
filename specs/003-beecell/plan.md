# Implementation Plan: Beecell (Freecell Solitaire)

**Branch**: `003-beecell` | **Date**: 2026-06-20 | **Spec**: [spec.md](./spec.md)

## Summary
The goal is to build on top of the existing SoliBee codebase structure to add **Beecell**, a native macOS Freecell Solitaire game, supporting standard 1-deck and 2-deck modes. Beecell will fully leverage the programmatic card designs, card backs, felt themes, sound player, preferences sheet system, and bouncing card animations of SoliBee, ensuring that previously fixed bugs (such as theme lags, empty slot background colors, and undo glitches) are not re-introduced.

## Technical Context
* **Language/Version**: Swift 6 (native macOS compilation)
* **Primary Dependencies**: SwiftUI, AppKit (for audio)
* **Storage**: Settings and Statistics tracked independently via standard `UserDefaults` keys
* **Architectural Pattern**: MVVM

## Project Structure (For Beecell additions)

We will implement Beecell by introducing new structures and classes that follow the patterns in SoliBee:

```text
src/
├── Models/
│   ├── BeecellState.swift      # Freecell-specific state (Tableau columns, Free Cells, Foundations)
│   └── BeecellOptions.swift    # Settings struct (1-Deck or 2-Decks, Felt Color, sound, Vegas scoring)
├── ViewModels/
│   └── BeecellViewModel.swift  # Game loop, sequence move validation, hint engine, autocomplete, undo stack
└── Views/
    ├── BeecellView.swift       # Freecell board grid layout (Freecells, Foundations, Tableaus)
    └── BeecellViews.swift      # Specific cell and column renderers (FreeCellView, BeecellFoundationView, etc.)
```

## Phased Implementation Plan

### Phase 1: Models and Core State (`BeecellState.swift` & `BeecellOptions.swift`)
* Define standard card layouts (Card model is shared with SoliBee).
* Create data model for Freecell piles (Free Cells, Foundation Piles, Tableau Columns).
* Standard Play (1-Deck): 8 Tableaus, 4 Free Cells, 4 Foundations.
* Two-Deck Mode: 10 Tableaus, 8 Free Cells, 8 Foundations.
* Set initial deal state deterministically (all cards face-up).

### Phase 2: Sequence Move Validation and ViewModel (`BeecellViewModel.swift`)
* Implement descending alternating colors rule for tableau card drops.
* Implement sequence validation limit algorithm to prevent bugs:
  `Limit = (1 + Empty Free Cells) * 2 ^ (Empty Tableau Columns)`
* Handle card transitions to/from Free Cells and Foundations.
* Implement Double-Click automatic movements (Foundation first, then empty Free Cell).

### Phase 3: Core UI Grid Layout (`BeecellView.swift`)
* Build responsive top row for Free Cells and Foundations.
* Build bottom row for Tableau columns.
* Bind the card back rendering, borders, and felt themes.
* Integrate card snapping sounds and victory fanfare sounds.
* Inherit the environment-driven empty slot coloring fix (using `statusBarColor` behind empty cells).

### Phase 4: Undo Stack & Statistics
* Implement command pattern undo stack for Freecell moves (including full multi-card moves).
* Persist stats (Games Played, Won, Streaks, Standard & Vegas High Scores) to separate `UserDefaults` keys to avoid mixing with SoliBee statistics.

### Phase 5: Autocomplete & Win Cascade
* Implement card sorting analysis to trigger autocompletion safely when all cards are unblocked.
* Fire victory card cascade animation (reusing SoliBee's bouncing card mechanics).
