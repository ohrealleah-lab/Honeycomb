# Feature Specification: SoliBee Solitaire Suite

**Feature Branch**: `004-solibee-suite`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: "create a new speckit for the game as it currently exists"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Multi-Game Solitaire Options and Core Gameplay Rules (Priority: P1)

The player can play three distinct solitaire variants: Classic Klondike (Standard and Vegas modes), Beecell (Freecell), and Spider, selecting them via the app navigation. The games enforce standard rules, track scores, handle waste piles, and allow multi-step undos.

**Why this priority**: Standard game rules, move validations, and variant selections form the fundamental gameplay engine of the SoliBee suite.

**Independent Test**: Cycle through Klondike, Beecell, and Spider Solitaire, deal cards, perform valid moves, verify that invalid moves are rejected, and test the undo/redo triggers.

**Acceptance Scenarios**:

1. **Given** Klondike is selected, **When** drawing cards, **Then** standard Draw-1 or Draw-3 rules are followed, waste cards are displayed, and tableau piles allow alternating color sequences (e.g., Red 5 on Black 6).
2. **Given** Beecell is selected, **When** playing, **Then** 8 tableau piles are dealt, and cards can be moved into 4 open free cells or placed in foundations.
3. **Given** Spider is selected, **When** playing, **Then** cards can stack in descending order regardless of suit, but only complete descending same-suit runs (King to Ace) can be swept to the foundations.
4. **Given** the player clicks "Undo" after a sequence of draws and placements, **When** the state is restored, **Then** the previous positions, visibility, score, and moves are precisely restored.

---

### User Story 2 - Programmatic Vector UI & Responsive Board Layouts (Priority: P1)

The game board, table felts, card faces, ranks, suits, borders, and card backs are rendered programmatically using vector paths and shapes. As the user resizes the macOS window, the board scales dynamically without losing crispness.

**Why this priority**: Natively drawn visual layouts eliminate external image assets, optimize rendering speeds, and support high-resolution screens (Retina) at any scale factor.

**Independent Test**: Resize the window to verify that board spacing, card scales, and column layout fan spacing adjust dynamically and smoothly without layout overflow or visual glitches.

**Acceptance Scenarios**:

1. **Given** the game window is resized, **When** rendering columns, **Then** the cards and layout scale dynamically to fit the window bounds without clipping.
2. **Given** the card elements are viewed on a high-DPI Retina screen, **When** rendered, **Then** vector ranks, suits, and card borders remain sharp and clear.

---

### User Story 3 - Visual Customization, Felt Themes, and Custom Card Backs (Priority: P2)

The player can choose from standard themes (Vulpera, Moogle, Dingwall, ) and custom card backs. Players can import their own images and adjust their positioning vertically, horizontally, and in scale using sliders in an editor sheet. Selected table felt colors sync globally.

**Why this priority**: Cosmetic personalization is a key visual feature of SoliBee, allowing custom card back centering offsets and board adjustments.

**Independent Test**: Open the deck selector, click "Add Custom", select an image, adjust the scale, horizontal position, and vertical position sliders to align the image, save it, and verify it renders with offsets in both the carousel and the game.

**Acceptance Scenarios**:

1. **Given** the user adds a custom card back, **When** they adjust the Horizontal Position and Vertical Position sliders, **Then** the preview card shifts the image dynamically in real-time.
2. **Given** a custom card back is saved with custom scale and offsets, **When** cards are dealt face-down, **Then** the custom backing renders with the exact saved offset and scale factor applied.
3. **Given** a custom card back is selected, **When** viewed in the selection carousel, **Then** the preview card scales the offset proportionally (`60.0 / 128.0` scale) to look aligned inside the smaller frame.
4. **Given** the user changes the board felt color (Felt Green, Crimson, Royal Blue, Charcoal, Desert) in one game, **When** switching to another variant, **Then** the board felt theme updates instantly across all views.

---

### User Story 4 - Low-Latency Sound Effects and Victory Cascade Animations (Priority: P2)

The player hears audio effects for shuffling, card snapping, and victory. On completion, a full-screen cascade of bouncing cards animates, bouncing realistically off screen edges. Audio and animations can be muted/toggled.

**Why this priority**: Sound effects and victory cascades recreate the iconic retro desktop solitaire experience.

**Independent Test**: Complete a game (or trigger autocomplete), verify that the victory sequence begins with cascading cards bouncing off window borders, and test that muting options silent audio feedback immediately.

**Acceptance Scenarios**:

1. **Given** a victory state is detected, **When** autocomplete triggers, **Then** the game automatically moves remaining cards to foundations, plays the victory audio cue, and initiates the bouncing cascade animation.
2. **Given** the victory cascade is active, **When** a cascading card bounces completely out of window bounds, **Then** its resources are cleaned up to prevent memory leakage.
3. **Given** the sound toggle is switched off, **When** performing card moves, **Then** all sound effects are silenced.

---

### User Story 5 - Persistent Configurations and Statistics (Priority: P3)

The application automatically persists all configurations, custom card back assets, and game statistics across sessions. Statistics track separate scores and streaks for standard and Vegas rules.

**Why this priority**: Ensures player history, preferences, and custom imported assets are retained between application restarts.

**Independent Test**: Change felt color and card back themes, win a game to increment stats, restart the app, and verify that stats and preferences load exactly as they were left.

**Acceptance Scenarios**:

1. **Given** the app restarts, **When** the launch sequence completes, **Then** the previously selected card back, board felt, and game settings are loaded.
2. **Given** the user is viewing statistics, **When** selecting Standard vs Vegas mode stats, **Then** separate scores, win/loss counts, and streaks are displayed.

---

### Edge Cases

- **Corrupted Settings File**: If the persistent options database in UserDefaults is corrupted or contains invalid data, the app must gracefully reset configurations to default values (Felt Green, Vulpera card back) instead of crashing.
- **Victory Cascade Interruption**: If the user starts a new game, changes options, or closes the window while a high-intensity victory cascade animation is running, the timeline and render engines must stop immediately to release processor resources.
- **Missing Custom Image Assets**: If a custom card back PNG file is deleted from the App Support directory, the manager must fall back to showing standard placeholder indicators or default backings instead of throwing runtime exceptions.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The application MUST strictly implement the Model-View-ViewModel (MVVM) architecture to isolate rules logic from presentation layers.
- **FR-002**: The suite MUST support three variants: Klondike (Standard/Vegas scoring), Beecell (1-deck/2-deck modes), and Spider (1, 2, or 4 suits).
- **FR-003**: Card elements, suits, and board felts MUST be programmatically rendered via SwiftUI vector paths.
- **FR-004**: The system MUST support standard felt colors: Felt Green, Crimson, Royal Blue, Charcoal, and Desert (sandy/tan).
- **FR-005**: The system MUST allow adding custom card back images (`.png` and `.jpg`) and allow adjusting their Horizontal Position, Vertical Position, and Scale Factor using sliders.
- **FR-006**: Custom card backs, files, scaling factors, and offsets MUST be persisted in application support and UserDefaults.
- **FR-007**: Autocomplete MUST activate when all cards on the board are revealed and deterministic moves can complete the foundations.
- **FR-008**: Audio feedback (shuffle, card snap, victory) MUST play using low-latency player APIs and allow global muting.

### Key Entities

- **Card**: Rank, suit, face-up state, and position metrics.
- **Pile**: Group of cards (Stock, Waste, Foundation, Tableau, Freecell) obeying variant-specific rules.
- **CustomCardBack**: Custom name, relative filename path, scale multiplier, horizontal offset (`offsetX`), and vertical offset (`offsetY`).
- **GameOptions**: Persistent settings managing active deck theme, felt color, sound enabled, recycle draw limits, and variant-specific options.
- **GameStatistics**: Historical score tracking (wins, losses, streaks, best times) separated by game and scoring variant.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Custom card back editor adjustments (scale, vertical offset, horizontal offset) refresh the preview immediately in under 16ms.
- **SC-002**: Board layouts and tableau card stacks resize responsively during window drag operations without layout clipping.
- **SC-003**: App load sequence retrieves persistent statistics, options, and custom card backs from storage in under 200ms.
- **SC-004**: Automated unit tests execute and pass in under 5 seconds.

## Assumptions

- **Target Platforms**: macOS 14.0 or later desktop environments.
- **Standard Inputs**: Responsive to trackpad/mouse pointer gesture events for drag-and-drop actions.
- **Storage Limits**: Local disk storage has adequate space to save custom PNG assets inside the App Support directory.
