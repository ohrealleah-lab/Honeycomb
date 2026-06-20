# Feature Specification: Enhanced Solitaire Features

**Feature Branch**: `002-enhanced-solitaire-features`

**Created**: 2026-06-20

**Status**: Draft

**Input**: User description:
```text
- Retro Themes & Customization: Legacy Card Backs (Blue Rose, Spooky Castle, Palm Tree, Aquarium Fish), Varying Felt Colors (Deep Crimson, Royal Blue, Charcoal), Legacy Option Dialog (Timed game, Status bar visibility, Sound, Draw Constraints, Vegas Scoring Mode).
- Scoring & Rules Configurations: Vegas Scoring Mode (starts at -$52, foundation awards +$5), Draw Constraints (Limit stock recycles to 3 in Draw Three, Vegas allows 1/no recycles; optional).
- Sound Effects (SFX): Card Movement SFX (sliding/snapping), Deck Shuffling SFX (new game or recycle), Victory / Fanfare Sound (victory cascade).
- Interactive Help & Controls: Keyboard Shortcuts (Cmd+Z, Cmd+N, Cmd+H, Cmd+1, Cmd+3), Statistics Panel (win percentages, average times, highest streaks).
```

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Retro Themes, Colors & Customization (Priority: P1)

The player can customize their game board felt color and choose from classic retro card back graphics to recreate their favorite operating system aesthetic.

**Why this priority**: Custom themes provide immediate visual value and personalization, forming the foundation of the updated SoliBee cosmetic options.

**Independent Test**: Use the menu controls to cycle through all card back styles and board felt backgrounds, verifying that graphics and contrast adjust dynamically.

**Acceptance Scenarios**:
1. **Given** the game is running, **When** the player clicks the Board Color menu, **Then** they can choose from "Felt Green", "Deep Crimson", "Royal Blue", and "Charcoal", and the board background updates instantly.
2. **Given** the game is running, **When** the player opens the Card Deck menu, **Then** they see options for the new classic card backs: "Blue Rose", "Spooky Castle", "Palm Tree", and "Aquarium Fish", in addition to existing backs.
3. **Given** the player selects "Blue Rose" card back, **When** cards are dealt face-down, **Then** they display the high-fidelity blue rose graphic.

---

### User Story 2 - Legacy Preferences Dialog & Options (Priority: P2)

The player can open a dedicated options panel to configure game rules, score tracking, time limits, and audio behaviors.

**Why this priority**: Consolidates setting toggles into a unified modal panel, enabling clean configuration of rule variations before starting a match.

**Independent Test**: Trigger the Options modal, toggle different constraints and modes, and confirm the changes apply immediately to the gameplay state.

**Acceptance Scenarios**:
1. **Given** the player clicks the "Options" menu item or button, **When** the modal displays, **Then** it presents toggles for: "Timed Game", "Status Bar Visible", "Enable Sound", "Limit Stock Recycles", and "Vegas Scoring Mode".
2. **Given** the player toggles off "Status Bar Visible", **When** they close the options, **Then** the header bar showing scores, moves, and timer is hidden, expanding the playing field.
3. **Given** the player toggles off "Timed Game", **When** the game continues, **Then** the timer remains stopped and does not accumulate seconds or count down.

---

### User Story 3 - Vegas Scoring & Draw Constraints (Priority: P2)

The player can play with standard Vegas rules where they "buy" the deck and play cards to foundations for cash payouts, with optional limits on stock recycling.

**Why this priority**: Introduces high-stakes gameplay rules that change the strategy and win conditions of standard Klondike.

**Independent Test**: Start a game in Vegas mode, track the score adjustments for draws and moves, and verify stock recycle lockouts once limits are reached.

**Acceptance Scenarios**:
1. **Given** Vegas Scoring is enabled in Options, **When** a new game starts, **Then** the score displays as a currency value starting at `-$52.00`.
2. **Given** a Vegas game is active, **When** the player moves a card to a Foundation, **Then** the score increases by `+$5.00` (e.g., from `-$52.00` to `-$47.00`).
3. **Given** a Vegas game with Draw Three and Draw Constraints enabled, **When** the player recycles the waste pile, **Then** the system allows exactly 1 recycle, and disables subsequent draws/recycles once the stock becomes empty a second time.
4. **Given** Draw Constraints are enabled in standard scoring mode with Draw Three, **When** the player recycles, **Then** they are allowed exactly 3 recycles, after which the stock pile displays as permanently empty and disabled.

---

### User Story 4 - Nostalgic Sound Effects (Priority: P3)

The game plays crisp, retro-style audio cues when cards are shuffled, moved, or when a victory is achieved.

**Why this priority**: Sound effects complete the sensory nostalgic experience, giving tactile feedback to player actions.

**Independent Test**: Perform draws, moves, and complete a game, confirming that correct sound effects play at appropriate times without latency.

**Acceptance Scenarios**:
1. **Given** "Enable Sound" is active in options, **When** a new game is dealt or the Waste is recycled, **Then** a clean deck-shuffling sound effect plays.
2. **Given** a card is successfully placed on a pile, **When** it snaps into place, **Then** a quick, soft card-sliding/snapping sound plays.
3. **Given** the final card is placed on a foundation, **When** the bouncing card cascade begins, **Then** a retro victory fanfare/tune plays.

---

### User Story 5 - Keyboard Shortcuts & Statistics Panel (Priority: P3)

The player can monitor their long-term Sol solitaire performance stats and play faster using native macOS keyboard shortcuts.

**Why this priority**: Improves power-user efficiency and provides progression trackers for repeat players.

**Independent Test**: Trigger hints and undo via keyboard shortcuts. Open the statistics window and check that win rate and streaks calculate correctly.

**Acceptance Scenarios**:
1. **Given** the app is active, **When** the player presses `Cmd+Z`, `Cmd+N`, or `Cmd+H`, **Then** the action triggers Undo, New Game, or Hint respectively.
2. **When** the player presses `Cmd+1` or `Cmd+3`, **Then** the draw mode switches to Draw One or Draw Three respectively, and restarts/prompts to restart the game.
3. **Given** the player clicks "Statistics", **When** the modal opens, **Then** it displays: Games Played, Games Won, Win Percentage, Average Winning Time, and Current/Longest Winning Streak.

---

### Edge Cases

- **Undo in Vegas Mode**: Under traditional rules, Undo is disabled in Vegas mode to prevent cheating. The system must restrict Undo or penalize the score when Undo is clicked in Vegas mode.
- **Toggling Draw Mode Mid-Game**: If the player changes the Draw Mode (`Cmd+1` / `Cmd+3`) during an active game, the system must warn them that this will forfeit the current match and start a new game.
- **Sound System Availability**: If system audio output is unavailable or muted, the app must fail silently without lagging the UI or throwing unhandled exceptions.
- **Recycle Limits and Undo**: If a player reaches their recycle limit, and then undos a move that brings cards back into the stock, the recycle counter must correctly decrement to prevent locking the player out of valid moves.

## Requirements *(mandatory)*

### Functional Requirements

#### Customization & Options
- **FR-029**: The system MUST allow the user to select the board background color from four themes: "Felt Green" (default), "Deep Crimson", "Royal Blue", and "Charcoal".
- **FR-030**: The system MUST support three card back designs: "Vulpera" (default), "Moogle", and "Dingwall".
- **FR-031**: The system MUST provide an "Options" dialog (as a sheet or modal) to configure gameplay parameters. Card deck and felt color selections MUST NOT take effect until the user selects "OK" in the options dialog.
- **FR-033**: The system MUST support disabling the timer ("Timed Game" toggle) so that the game can be played in an untimed mode.

#### Rules & Scoring
- **FR-034**: The system MUST support "Vegas Scoring" rules, where the starting score is set to `-$52.00` and each card moved to a foundation awards `+$5.00`.
- **FR-035**: In Vegas mode, the score MUST be formatted and displayed as a currency value (e.g., `-$52.00`, `$15.00`).
- **FR-036**: The system MUST implement optional "Draw Constraints" (recycle limits) on the Stock pile.
- **FR-037**: In Draw Three mode with Draw Constraints active, the Stock pile MUST allow at most 3 recycles (4 passes through the deck total) in Standard scoring.
- **FR-038**: In Vegas mode with Draw Constraints active, the Stock pile MUST allow at most 1 recycle in Draw Three, or 0 recycles in Draw One.

#### Sound Effects (SFX)
- **FR-039**: The system MUST play a shuffling sound effect when a new game is started or when the Stock pile is recycled.
- **FR-040**: The system MUST play a card sliding/snapping sound effect when a card or stack is dropped onto a valid pile.
- **FR-041**: The system MUST play a victory fanfare sound effect when the final card is placed on a foundation and the win animation starts.
- **FR-042**: The system MUST respect the "Enable Sound" setting in the Options dialog, silencing all audio cues when unchecked.

#### Shortcuts & Statistics
- **FR-043**: The system MUST support the following keyboard shortcuts:
  - `Cmd+Z`: Undo last move
  - `Cmd+N`: New Game
  - `Cmd+H`: Highlight Hint
  - `Cmd+1`: Switch to 1-Card Draw
  - `Cmd+3`: Switch to 3-Card Draw
- **FR-044**: The system MUST record and persist long-term statistics and high scores: Games Played, Games Won, Win Percentage, High Score (tracked separately for Standard and Vegas scoring modes), Average Winning Time, and Current/Longest Winning Streak.
- **FR-045**: The system MUST display these statistics and the high score in a clean, dedicated Statistics modal sheet.

### Key Entities

- **GameOptions**: Holds user configuration settings.
  - `feltColor`: FeltGreen, Crimson, Blue, Charcoal.
  - `cardBackTheme`: Vulpera, Moogle, Dingwall.
  - `isTimed`: Boolean.
  - `isSoundEnabled`: Boolean.
  - `isVegasScoring`: Boolean.
  - `isDrawConstraintsEnabled`: Boolean.
- **GameStatistics**: Tracks lifetime statistics.
  - `gamesPlayed`: Integer.
  - `gamesWon`: Integer.
  - `currentStreak`: Integer.
  - `longestStreak`: Integer.
  - `highScore`: Integer (Standard high score).
  - `highScoreVegas`: Integer (Vegas high score in cents).
  - `winningTimes`: Array of double (elapsed seconds).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-006**: Changing board felt color or card back themes updates all rendered views in under 20ms without layout glitching.
- **SC-007**: Audio cue latency (delay between card snap and sound playback) is under 40ms.
- **SC-008**: User performance statistics are correctly computed, updated, and saved to persistent storage (UserDefaults) within 50ms of game completion or reset.
- **SC-009**: Keyboard shortcuts respond instantly (triggering VM actions in under 15ms).

## Assumptions

- Sound effects are implemented using Apple's built-in `NSSound` system or standard platform audio frameworks.
- Retro card backs ("Blue Rose", "Spooky Castle", "Palm Tree", "Aquarium Fish") are drawn programmatically using SwiftUI shapes, lines, and gradients to ensure high-fidelity resolution and avoid external asset bundling dependencies.
- Lifetime statistics are persisted securely via standard `UserDefaults` keys and survive application termination.
