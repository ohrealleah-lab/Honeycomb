# Feature Specification: Freecell Solitaire (Beecell)

**Feature Branch**: `003-beecell`

**Created**: 2026-06-20

**Status**: Draft

**Input**: User description:
```text
Create speckit for a game of Freecell called "Beecell" using standard Freecell rules. There should be options for standard play, or playing a game with two decks. The speckit should be based off the spec for Solibee so that card designs, animations, previously handled bugs, etc, are not introduced in Beecell.
```

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Freecell Gameplay & Layout (Priority: P1)
The player can play a game of Freecell under standard rules using a single 52-card deck, with 4 open temporary storage cells (Free Cells), 4 foundation piles, and 8 tableau columns.

**Why this priority**: Represents the MVP core ruleset of Freecell. Drag-and-drop mechanics, pile setups, and simple move validations must exist for the game to function.

**Independent Test**: Initialize a standard 1-deck game, verify all 52 cards are dealt face-up across 8 columns, move cards to free cells, build cards on foundations, and verify tableau movement rules (descending alternating colors).

**Acceptance Scenarios**:
1. **Given** a new 1-deck game starts, **When** cards are dealt, **Then** all 52 cards are distributed face-up: columns 1-4 contain 7 cards each, columns 5-8 contain 6 cards each.
2. **Given** a card is at the top of a tableau column, **When** the player drags it to an empty Free Cell, **Then** the card is placed in the Free Cell and that Free Cell is marked as occupied.
3. **Given** a Free Cell contains a card, **When** the player attempts to drag another card into it, **Then** the move is rejected.
4. **Given** a card is in a Free Cell or at the top of a tableau column, **When** it is a red 7, and the destination tableau column has a black 8 on top, **Then** the red 7 stacks legally on the black 8.
5. **Given** an Ace of Hearts is available on the tableau or in a Free Cell, **When** the player drags or double-clicks it, **Then** it moves to an empty foundation pile to start building that suit's foundation.
6. **Given** an empty tableau column, **When** the player drags any single card onto it, **Then** the card is successfully placed in the empty column.

---

### User Story 2 - Double-Deck Play Option (Priority: P2)
The player can select a "Two Decks" option to play a double-deck Freecell game (104 cards, 8 open Free Cells, 8 foundation piles, and 10 tableau columns).

**Why this priority**: Extends the game to support the two-deck mode requirement, creating a larger, more challenging strategic layout.

**Independent Test**: Toggle the game mode to Two Decks in the options menu, verify layout boundaries, and confirm correct starting deals and foundation piles.

**Acceptance Scenarios**:
1. **Given** the player selects "Two Decks" in options and starts a game, **When** cards are dealt, **Then** 104 cards (two combined standard decks) are dealt face-up: columns 1-4 contain 11 cards, columns 5-10 contain 10 cards.
2. **Given** a Two-Decks game is active, **When** foundations are initialized, **Then** 8 foundation piles are displayed (two for each suit: hearts, clubs, diamonds, spades), each building from Ace to King.
3. **Given** a Two-Decks game is active, **When** the player views the top control bar, **Then** 8 open Free Cells are displayed.

---

### User Story 3 - Multi-Card Sequence Movement Limits (Priority: P2)
The player can drag a valid descending, alternating-color card sequence between tableau columns, provided they have enough empty Free Cells and/or empty tableau columns to make the move possible card-by-card.

**Why this priority**: Avoids a common Freecell bug where players are allowed to move long card stacks regardless of available temporary cells, violating standard Freecell rules.

**Acceptance Scenarios**:
1. **Given** a player drags a sequence of `N` cards, **When** the move is evaluated, **Then** the maximum size `N` of a sequence that can be moved to a non-empty tableau column is calculated as:
   `Max Sequence Length = (1 + Empty Free Cells) * 2 ^ (Empty Tableau Columns)`
2. **Given** the destination tableau column is empty, **When** a sequence is moved, **Then** that empty column does not count toward the exponent of the calculation (since it is the destination). The limit formula becomes:
   `Max Sequence Length = (1 + Empty Free Cells) * 2 ^ (Empty Tableau Columns - 1)` (if `Empty Tableau Columns > 0`).

---

### User Story 4 - Theme, Scoring & Autocomplete Integration (Priority: P3)
The game inherits SoliBee's retro aesthetics, customizable felt themes, programmatic card decks, audio cues, keyboard shortcuts, stats tracking, and automatic completion triggers.

**Why this priority**: Ensures visual consistency and shares the polished features of SoliBee.

**Acceptance Scenarios**:
1. **Given** standard scoring is active, **When** a card is successfully moved to a foundation, **Then** the player receives `+10` points.
2. **Given** Vegas scoring is active, **When** a new game starts, **Then** the score starts at `-$52.00` (for 1-deck) or `-$104.00` (for 2-decks), and each card moved to a foundation awards `+$5.00`.
3. **Given** the options menu is opened, **When** the user changes the Felt Color or Card Deck, **Then** the changes are only applied when they click "OK".
4. **Given** all face-down or hidden cards do not exist in Freecell, **When** all cards on the tableau are sorted such that they can be moved to foundations automatically without blocking other suits, **Then** the "Autocomplete Game" option triggers.
5. **When** a victory is achieved, **Then** the cards cascade and bounce off the foundation piles individually (matching the classic card-bouncing animation).

### Edge Cases

- **Double-Click Shortcuts**: Double-clicking a card at the top of a column or in a free cell must automatically move it to a foundation if legal, or to an empty free cell if no foundation move exists.
- **Empty Slot Coloring**: Empty free cells, empty foundations, and empty tableau slots must display a card outline with a background filled with `feltColor.statusBarColor` (inheriting SoliBee's dynamic felt coloring fix) rather than a hardcoded green color.
- **Undo/Redo Limits**: Undoing sequence moves must correctly restore the exact positions of all moved cards and keep the undo stack count matching the number of moves.

## Requirements *(mandatory)*

### Functional Requirements

#### Customization & Options
- **FR-050**: The system MUST support two game modes: "Standard (1-Deck)" and "Two Decks (2-Decks)".
- **FR-051**: The system MUST reuse SoliBee's background themes: "Felt Green", "Deep Crimson", "Royal Blue", and "Charcoal". Empty slot backgrounds MUST be filled with the theme's `statusBarColor`.
- **FR-052**: The system MUST reuse SoliBee's card back themes ("Vulpera", "Moogle", "Dingwall") and programmatic card designs.
- **FR-053**: The system MUST present an "Options" panel where mode, deck style, felt color, timed options, sound toggles, and Vegas scoring can be configured. Selections MUST NOT apply until "OK" is pressed.

#### Rules & Scoring
- **FR-054**: Tableau columns MUST build down in alternating colors (e.g. Red Queen on Black King).
- **FR-055**: Foundations MUST build up from Ace to King by suit (4 piles for 1-deck, 8 piles for 2-decks).
- **FR-056**: The system MUST validate sequence dragging, restricting the sequence size based on the number of empty Free Cells (`E`) and empty Tableau columns (`C`):
  `Max Length = (1 + E) * 2^C` (when moving to occupied column) or `(1 + E) * 2^(C-1)` (when moving to empty column).
- **FR-057**: The starting score for Vegas scoring MUST be `-$52.00` for 1-deck and `-$104.00` for 2-decks, with foundation moves awarding `+$5.00`.

#### Sounds & Animations
- **FR-058**: The system MUST play snap, shuffle, and victory sound effects, respecting the "Enable Sound" toggle.
- **FR-059**: The system MUST trigger the iconic card bouncing victory cascade when the final foundation card is placed.

#### Shortcuts & Statistics
- **FR-060**: The system MUST support the keyboard shortcuts:
  - `Cmd+Z`: Undo last action
  - `Cmd+N`: New Game
  - `Cmd+H`: Highlight Hint
  - `Cmd+1`: Switch to 1-Deck Freecell (prompts restart)
  - `Cmd+2`: Switch to 2-Deck Freecell (prompts restart)
- **FR-061**: The system MUST track separate high scores and games statistics for:
  - Standard 1-Deck
  - Vegas 1-Deck
  - Standard 2-Deck
  - Vegas 2-Deck
- **FR-062**: The control panel MUST place the **Undo** button immediately to the right of the **Restart Game** button.

### Key Entities

- **BeecellOptions**: Holds user configuration settings.
  - `feltColor`: FeltGreen, Crimson, Blue, Charcoal.
  - `cardBackTheme`: Vulpera, Moogle, Dingwall.
  - `deckCount`: Integer (1 or 2).
  - `isTimed`: Boolean.
  - `isSoundEnabled`: Boolean.
  - `isVegasScoring`: Boolean.
- **BeecellStatistics**: Tracks lifetime statistics independently for each mode.
  - `gamesPlayed`: Integer.
  - `gamesWon`: Integer.
  - `currentStreak`: Integer.
  - `longestStreak`: Integer.
  - `highScores`: Dictionary mapping mode combinations to Integer scores.

## Success Criteria *(mandatory)*

### Measurable Outcomes
- **SC-010**: Selecting 1-deck vs 2-deck layout switches grids and layouts in under 20ms.
- **SC-011**: Sequence move validations execute in under 1ms, preventing illegal stack drops before cards are placed.
- **SC-012**: High scores are written and persisted to `UserDefaults` under separate keys to prevent value pollution.
