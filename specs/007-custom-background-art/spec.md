# Feature Specification: Custom Background Art

**Feature Branch**: `007-custom-background-art`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "allow a user to add custom background art, instead of a felt color, using an image file from their computer, size and scale it on a mock interface, and save it."

## User Scenarios & Testing

### User Story 1 - Add Custom Background Art (Priority: P1)
As a player, I want to upload an image from my computer to use as the game board's background so that I can personalize my solitaire playing screen.

**Why this priority**: Core user goal that establishes custom background capability.

**Independent Test**: Verify that clicking "Add Custom Background" allows selecting an image, and once saved, renders that image behind the solitaire board.

**Acceptance Scenarios**:
1. **Given** the Themes & Options panel is open, **When** I click "Add Custom" and select a valid image file, **Then** I am presented with the background configuration editor.
2. **Given** I am in the background editor, **When** I click "Save", **Then** the image is copied to the application's local support directory and applied as the active board background.

---

### User Story 2 - Position and Scale Background (Priority: P1)
As a player, I want to adjust the scale and placement of my custom background image so that it fits nicely behind the game piles.

**Why this priority**: Ensures the user can control how their custom image aligns with the board layout.

**Independent Test**: Verify that shifting the sliders for Scale and Offsets updates the board preview in real-time.

**Acceptance Scenarios**:
1. **Given** the custom background editor is open, **When** I drag the scale slider or offset controls, **Then** the image preview updates immediately to match.

---

### User Story 3 - Manage Custom Backgrounds List (Priority: P2)
As a player, I want to save multiple custom backgrounds, switch between them from the dropdown, and delete them when no longer needed.

**Why this priority**: Enhances personalization, allowing players to build a library of backgrounds.

**Independent Test**: Verify that saved custom backgrounds appear in the dropdown list, show a small preview with an "X" to delete, and warn the user if a theme uses it.

**Acceptance Scenarios**:
1. **Given** I have saved multiple custom backgrounds, **When** I open the Options panel, **Then** I see my custom backgrounds in a dropdown list directly under "Felt Color".
2. **Given** a custom background is selected, **When** I click the "X" button on the background preview, **Then** a confirmation alert is shown. If approved, the background is deleted.
3. **Given** a custom background is currently referenced by a saved Theme, **When** I attempt to click the "X" button on its preview, **Then** the system displays the warning: `"This background is used by \"[Theme Name]\". Please delete the theme first."` and blocks the deletion.

---

### Edge Cases
- **Aspect Ratio Mismatch**: What happens when a vertical phone picture is uploaded for a horizontal Mac/PC game screen? The background is always rendered as Aspect Fill (cropping overflow) — the user can compensate with the scale and offset controls.
- **Huge Images**: What happens if the user uploads a file larger than 25MB? The application MUST reject the file and show a friendly error message to the user, preventing import.
- **Missing File**: If a custom background image file is manually deleted from the user's Application Support directory outside the app, the app falls back gracefully to standard "Felt Green".

---

## Requirements

### Functional Requirements
- **FR-001**: System MUST support selecting image files via a native file picker dialog.
- **FR-003**: System MUST support **static images only** (PNG, JPG, JPEG). Animated/GIF files are explicitly out of scope.
- **FR-004**: The existing shared Felt Vignette toggle (`AppCoordinator.showFeltVignette`) applies to custom backgrounds as-is. No per-background vignette field or remembered default is stored — the toggle works the same way regardless of whether a custom background or felt color is active.
- **FR-005**: System MUST save custom background assets under `Backgrounds/` inside `~/Library/Application Support/SoliBee/`, as a sibling to the existing `CardBacks/` and `FaceArt/` subdirectories established for custom card backs and custom face card art. (Windows/AppData support is explicitly out of scope for this spec — macOS only. A Windows port will be scoped separately once this ships.)
- **FR-006**: System MUST persist custom background metadata in the user's local settings profile.
- **FR-007**: The active custom background selection MUST be app-wide and live-shared across all game modes (Klondike, Freecell, Spider, Video Poker, Blackjack) — one background active for the whole app at a time, living on `AppCoordinator` alongside `feltColor`/`cardBackTheme`/`customCardColors`, not per-game-mode. Saved Themes MAY reference a custom background by name (mirroring how `SoliBeeTheme.cardBackTheme` already stores a name reference to a `CustomCardBack`); applying such a Theme pushes that reference into the shared `AppCoordinator` state the same way `cardBackTheme`/`feltColor` are pushed today.
- **FR-008**: UI Layout placement:
  - Saved background options dropdown MUST sit directly underneath "Felt Color" (occupying the grid space where "Felt Vignette" was previously located).
  - The "Felt Vignette" control MUST be moved to the right of "Felt Color".
  - A button to "Add Custom" background MUST be provided.
  - A small preview of the currently selected background MUST be shown, featuring an "X" button to delete it.
- **FR-009**: Deletion Safeguards:
  - System MUST show a confirmation dialog before deleting a custom background.
  - If a background is referenced by any saved Theme, the system MUST block deletion and show: `"This background is used by \"[Theme Name]\". Please delete the theme first."`

### Key Entities
- **CustomBackground**: Represents a user-uploaded background.
  - `name`: String (uniquely identifies the background)
  - `relativePath`: String (filename of the copied image inside `Backgrounds/`, resolved relative to `~/Library/Application Support/SoliBee/Backgrounds/`)
  - `scale`: Double (zoom multiplier)
  - `offsetX`, `offsetY`: Double (pixel shifts)

---

## Success Criteria

### Measurable Outcomes
- **SC-001**: Selecting and applying a custom background takes under 15 seconds.
- **SC-002**: Applying a high-resolution custom background (up to 4K resolution) does not drop the game's rendering frame rate below 60 FPS.
- **SC-003**: Deleting a custom background successfully cleans up its image file from the disk.

---

## Assumptions
- Custom background images are stored locally and do not sync to any cloud services.
- The default fallback background is always "Felt Green".
- This spec covers macOS only. Windows/AppData support is an explicit non-goal here and will be scoped as a separate follow-up once the macOS implementation ships.

