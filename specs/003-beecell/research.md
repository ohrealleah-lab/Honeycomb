# Research: Beecell (Freecell Solitaire)

This document outlines the research behind Freecell constraints, sequence calculations, and code reuse opportunities from the SoliBee codebase.

## 1. Sequence Movement Calculation
In standard Freecell, moving a sequence of cards (e.g., Red 7, Black 6, Red 5) from one tableau column to another is technically a shortcut for moving cards one-by-one using empty Free Cells and Tableau columns as temporary storage.

The maximum sequence size `S` that can be legally moved is:
```swift
let maxMove = (1 + emptyFreeCells) * (1 << emptyTableauColumns)
```
*Note*: If moving a sequence to an *empty* tableau column, that column cannot be used as temporary storage for the move, so it must be subtracted from the exponent in the calculation:
```swift
let maxMoveToEmpty = (1 + emptyFreeCells) * (1 << max(0, emptyTableauColumns - 1))
```

## 2. Code Reuse (SoliBee Integration)
To avoid introducing bugs previously resolved in SoliBee, Beecell should directly share:
1. **Programmatic Card Rendering**:
   - `CardView` and card suit styling shapes/drawings from `CardView.swift`.
   - Programmatic card backing themes (`Vulpera`, `Moogle`, `Dingwall`).
2. **Theme Preferences**:
   - Background board felt themes (`FeltColorTheme` enums & styling extension).
   - Empty slot background drawing filled with `feltColor.statusBarColor` (resolving the empty slot color bug).
3. **Sound System**:
   - Playing snap and shuffle sound cues using the unified audio player in `GameViewModel`.
4. **Win Cascades**:
   - Shared bouncing card win cascade animations (`WinAnimationView.swift`).
