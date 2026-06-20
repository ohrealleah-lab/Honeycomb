# Feature Specification: Klondike Solitaire (SoliBee)

**Feature Branch**: `001-solitaire-game`

**Created**: 2026-06-19

**Status**: Draft

**Input**: User description:
```text
specify init SoliBee --ai agy
/specify 1. Project Overview
The objective is to develop a faithful digital recreation of the classic Klondike Solitaire game as seen in legacy Windows operating systems (e.g., Windows 95/XP). The game must preserve the traditional rules, deterministic behaviors, layout, and visual charm of the original, with specific configurations for card drawing and aesthetics.

2. Core Game Specifications & Rules
... [detailed rules and configurations for card drawing, assets, state, AI autocomplete, and legacy UX polish]
```

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Gameplay & Draw Modes (Priority: P1)

The player can play standard Klondike Solitaire under standard rules with choices of 1-Card Draw and 3-Card Draw modes. 

**Why this priority**: This is the core MVP of the solitaire game. Without drawing, layout, and basic move rules, the game cannot be played.

**Independent Test**: Initialize the game in both draw modes, drag cards between tableau piles, move cards to foundations, and draw cards from the stock to waste.

**Acceptance Scenarios**:

1. **Given** the game is in 1-Card Draw mode, **When** the player clicks the Stock pile, **Then** exactly 1 card is flipped face-up to the Waste pile.
2. **Given** the game is in 3-Card Draw mode, **When** the player clicks the Stock pile, **Then** up to 3 cards are flipped to the Waste pile and fanned out, with only the top card fully visible and playable.
3. **Given** the game is in 3-Card Draw mode and fewer than 3 cards remain in the Stock, **When** the player clicks the Stock pile, **Then** all remaining cards (1 or 2) are flipped to the Waste pile.
4. **Given** a Tableau pile contains a face-up Red 7, **When** the player drags a Black 6 onto it, **Then** the card is stacked successfully on the Red 7.
5. **Given** a Tableau column is empty, **When** the player attempts to drag a card to it, **Then** only a King (or a sequence starting with a King) is accepted.
6. **Given** a Tableau pile has a face-up card on top of a face-down card, **When** the player moves the face-up card away, **Then** the topmost face-down card automatically flips face-up.
7. **Given** an Ace is available on the Tableau or Waste, **When** the player moves it to an empty Foundation slot, **Then** it initializes that suit's Foundation pile.
8. **Given** the Stock pile is completely empty, **When** the player clicks the empty Stock spot, **Then** the entire Waste pile is recycled back into the Stock pile face-down, preserving order.

---

### User Story 2 - AI Autocomplete & Hint Systems (Priority: P2)

The player can ask the AI engine to suggest moves (hints) or automatically complete the game (autocomplete) when victory is guaranteed.

**Why this priority**: Hints assist stuck players, and autocomplete avoids tedious manual clicks at the end of the game, completing the modern-legacy UX expectation.

**Independent Test**: Trigger hints in different board states to verify correct prioritization, and play a game to the point where all tableau cards are face-up and Stock/Waste are empty, verifying the autocomplete option works.

**Acceptance Scenarios**:

1. **Given** multiple moves are possible, **When** the player requests a Hint, **Then** the AI highlights a move prioritizing:
   1. Tableau/Waste to Foundation (safe advances).
   2. Revealing a face-down Tableau card.
   3. Moving a Tableau sequence to clear columns or organize.
   4. Drawing from the Stock pile.
2. **Given** all face-down cards in the Tableau are revealed, and the Stock and Waste piles are completely empty, **When** this state is reached, **Then** an "Autocomplete Game" prompt appears.
3. **Given** the "Autocomplete Game" prompt is visible, **When** the player clicks the button, **Then** all remaining cards are automatically animated and moved to their respective Foundation piles until the game is won.

---

### User Story 3 - Legacy UI/UX Polish, Themes & Scoring (Priority: P3)

The game provides a nostalgic retro visual style, custom card back art, standard scoring, double-click shortcuts, and the iconic card-bouncing victory animation.

**Why this priority**: Elevates the game from a bare implementation to a high-quality, polished recreation of the nostalgic legacy Windows Solitaire experience.

**Independent Test**: Complete a game (or simulate completion) to verify bouncing card graphics. Test double-clicking cards and tracking scores.

**Acceptance Scenarios**:

1. **Given** a face-up card can legally be moved to a Foundation, **When** the player double-clicks the card, **Then** the card automatically flies to the correct Foundation pile.
2. **Given** standard scoring is active:
   - **When** a card is moved to the Foundation, **Then** +10 points are awarded.
   - **When** a card is moved from Stock/Waste to the Tableau, **Then** +5 points are awarded.
   - **When** a card is moved from the Foundation back to the Tableau, **Then** -15 points are deducted.
3. **Given** the final card is placed on a Foundation (game won), **When** the victory state triggers, **Then** cards cascade and bounce off the Foundation piles one by one, leaving a trail of card images on the green canvas.

### Edge Cases

- **Drag and Drop Interruptions**: If the user drops a card in an invalid area or is interrupted, the card must snap back smoothly to its original position without state corruption.
- **Empty Stock & Waste**: If both Stock and Waste are empty, clicking the Stock spot should do nothing, and no further draws or recycles should occur.
- **Multiple Possible Hints**: If multiple moves share the same priority rank, the system chooses the move that exposes the longest face-down stack or, if equal, a deterministic default.
- **Autocomplete State Verification**: Autocomplete should immediately halt if an unexpected invalid state occurs (e.g., if a user somehow interacts with the screen during autocomplete, though controls should be disabled during the automation).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST support standard Klondike Solitaire rules with a 52-card deck.
- **FR-002**: The system MUST support switching between 1-Card Draw (Easy) and 3-Card Draw (Standard) modes via a Game/Options menu.
- **FR-003**: In 3-Card Draw mode, the system MUST show the Waste pile fanned out, exposing up to three cards, with only the top card being draggable.
- **FR-004**: The system MUST automatically flip a face-down Tableau card face-up when it becomes the top card of its column.
- **FR-005**: The system MUST restrict empty Tableau slots to accept only Kings or sequences starting with a King.
- **FR-006**: The system MUST support double-clicking a card to automatically move it to a valid Foundation pile.
- **FR-007**: The system MUST feature a legacy green background (#008000 or #007B00) and card layouts that resemble the retro Windows 95/XP style.
- **FR-008**: The card back art MUST display a custom stylized portrait of the Priest character ('priest.png' or 'priest.jpg') scaled to fill the card back, with no traditional solitaire patterns or ornate borders.
- **FR-009**: The system MUST track and display Game Score, Moves Count, and a Timer (elapsed seconds).
- **FR-010**: The system MUST compute valid moves and highlight them when requested, adhering to the prioritization rules.
- **FR-011**: The system MUST display an "Autocomplete Game" button/modal once there are no face-down cards in the Tableau and Stock/Waste are empty.
- **FR-012**: The system MUST render the classic cascading card-bouncing animation upon game completion.
- **FR-013**: The system MUST align the card rank and suit symbol horizontally in the top-left and bottom-right corners in a compact size to maximize center card art space.
- **FR-014**: Numbered cards (2–10) MUST display their suit symbol in the center as many times as matching the rank, positioned programmatically in standard symmetrical card grid coordinates.
- **FR-015**: Face cards (Jack, Queen, King) MUST render distinct, programmatic vector art outlines and shapes: a Shield for Jack, a Tiara for Queen, and a Crown for King.
- **FR-016**: The outline borders of all playing cards MUST have a precise stroke thickness of `0.75`.
- **FR-017**: When selecting and dragging cards from the Tableau columns or the Waste pile, the selected cards in their source piles MUST fade to `0.0` opacity, exposing the card or empty slot underneath.
- **FR-018**: The 4 foundations MUST be initialized and displayed in the fixed order Spades, Clubs, Diamonds, and Hearts (from left to right).
- **FR-019**: Each foundation slot MUST enforce suit restriction even when empty.
- **FR-021**: The system MUST provide a `"Reset Statistics"` menu item under the File menu to reset the games played and games won counters to zero and persist this change.
- **FR-022**: The system MUST support restarting the current game to its initial layout and state (allowing the user to replay the exact same card deck from the start) via a `"Restart Game"` button in the header bar and a menu item under the File menu (with keyboard shortcut Cmd+R).
- **FR-023**: The system MUST persist and display the lifetime highest score (`"BEST"`) directly above the current `"SCORE"` in the header panel.
- **FR-024**: The system MUST provide a `"Card Deck"` button in the control panel to the right of the `"Undo"` button.
- **FR-025**: Clicking the `"Card Deck"` button MUST open a dropdown menu (using SwiftUI's Menu element) displaying card back art options: `"Vulpera"` (priest character), `"Moogle"` (moogle character), and `"Dingwall"` (bass guitar).
- **FR-026**: The chosen card backing theme MUST persist using UserDefaults across application relaunches.
- **FR-027**: Card drawing from Stock to Waste pile MUST perform a smooth horizontal slide transition using ease-out/easeInOut animation.
- **FR-028**: Stock recycling MUST trigger a slide transition from Waste to Stock combined with a physical spring wiggle/flutter on the Stock pile card view.


### Key Entities *(include if feature involves data)*

- **Card**: Represents an individual playing card.
  - `id`: Unique string (e.g., "AH" for Ace of Hearts, "10S" for 10 of Spades).
  - `suit`: Spades, Hearts, Diamonds, Clubs.
  - `rank`: 1 (Ace) to 13 (King).
  - `color`: Red (Hearts/Diamonds) or Black (Spades/Clubs).
  - `faceUp`: Boolean.
- **Tableau Pile**: One of 7 columns on the board.
  - `index`: 0 to 6.
  - `cards`: List of Cards (both face-down and face-up).
- **Foundation Pile**: One of 4 suit piles.
  - `suit`: The designated suit of the foundation pile.
  - `cards`: List of Cards stacked in ascending rank.
- **Stock Pile**: Face-down cards remaining to draw from.
- **Waste Pile**: Face-up cards drawn from Stock.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% adherence to movement rules (0 invalid moves allowed by the engine).
- **SC-002**: UI interaction latency (dragging start/stop, card selection) is under 30ms.
- **SC-003**: The AI Hint engine calculates and displays the highlighted move in under 100ms.
- **SC-004**: Autocomplete runs to completion in under 5 seconds, placing all remaining cards in their respective foundations.
- **SC-005**: Bouncing win animation runs smoothly at 60 FPS on standard modern desktop browsers.

## Assumptions

- The game is developed as a native macOS application bundle using Swift 6, SwiftUI, and the Observation framework.
- Responsive layout fits screen dimensions from 1024x768 upwards, scaling card visuals cleanly.
- Sound effects are out of scope.
- Games Played, Games Won, and Zoom settings are saved and persisted via UserDefaults across relaunches.
