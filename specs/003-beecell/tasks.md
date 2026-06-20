# Development Tasks: Beecell (Freecell Solitaire)

## Milestone 1: Models & Core Mechanics
- [ ] Task 1.1: Create `BeecellOptions.swift` settings struct, referencing `FeltColorTheme` and supporting `deckCount: Int` (1 or 2).
- [ ] Task 1.2: Create `BeecellState.swift` model to manage Free Cells, Foundations, Tableau columns, current score, and moves count.
- [ ] Task 1.3: Create initialization and dealing logic in `BeecellViewModel.swift` to shuffle and deal card collections (1-deck or 2-decks) face-up.

## Milestone 2: Move Validation & Core Rules
- [ ] Task 2.1: Implement single card move validation (alternating colors, descending rank) in `BeecellViewModel`.
- [ ] Task 2.2: Implement Freecell sequence movement limits calculation based on vacant free cells and columns.
- [ ] Task 2.3: Implement double-click automatic foundation/free cell movement shortcuts.
- [ ] Task 2.4: Implement command-based Undo mechanism for single and sequence card moves.

## Milestone 3: Interface & Layout Views
- [ ] Task 3.1: Build `BeecellView.swift` top panel for buttons (Undo to the right of Restart Game).
- [ ] Task 3.2: Render Free Cells and Foundations in the top row, incorporating `feltColor.statusBarColor` for vacant placeholders.
- [ ] Task 3.3: Render Tableau columns with custom stacking spacing to fit 1-deck (8 columns) and 2-deck (10 columns) screens.
- [ ] Task 3.4: Add drag-and-drop gesture bindings for card stacks.

## Milestone 4: Sound, Options & Statistics Persistence
- [ ] Task 4.1: Bind sound playing triggers to card draws, drops, and shuffling events (reusing the sound engine).
- [ ] Task 4.2: Build preferences sheet to let players configure timer, sounds, deck count, felt colors, and Vegas scoring.
- [ ] Task 4.3: Implement `UserDefaults` loading/saving of high scores and gameplay statistics separated by mode combinations.

## Milestone 5: Autocomplete & Win Cascade
- [ ] Task 5.1: Implement autocomplete solver logic to sweep cards to foundations when no cards are blocked.
- [ ] Task 5.2: Integrate the bouncing card cascade animation when all cards reach foundations.
