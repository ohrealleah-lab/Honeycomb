# Tasks: Enhanced Solitaire Features

**Input**: Design documents from `/specs/002-enhanced-solitaire-features/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Tests**: Tests are OPTIONAL - only include them if explicitly requested in the feature specification or if TDD is requested. Since tests were not explicitly requested for these features, we focus on code correctness, manual e2e validation scenarios defined in `quickstart.md`, and compiling standard unit tests.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Option configuration initialization and settings/audio structure setup

- [X] T001 Create settings model folder for options configuration in `src/Models/`
- [X] T002 Configure system sound references or prepare bundle file layout for audio resources

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model infrastructure and state schemas that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Create `GameOptions` data model managing customizations and rule flags in `src/Models/GameOptions.swift`
- [X] T004 Create `GameStatistics` data model managing lifetime win ratios and streaks in `src/Models/GameStatistics.swift`
- [X] T005 [P] Integrate optional settings and streak properties inside `GameState` in `src/Models/GameState.swift`
- [X] T006 Add state initialization and loading/saving hooks for options and stats in `src/ViewModels/GameViewModel.swift`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Retro Themes, Colors & Customization (Priority: P1) 🎯 MVP

**Goal**: Deliver card back vectors and table felt background selections

**Independent Test**: Cycle through felt green, crimson, royal blue, charcoal backgrounds, and card back vectors (Blue Rose, Spooky Castle, Palm Tree, Aquarium Fish) to verify rendering is dynamic and correct.

### Implementation for User Story 1

- [X] T007 [P] [US1] Implement programmatic vectors for "Blue Rose" card backing in `src/Views/CardView.swift`
- [X] T008 [P] [US1] Implement programmatic vectors for "Spooky Castle" card backing in `src/Views/CardView.swift`
- [X] T009 [P] [US1] Implement programmatic vectors for "Palm Tree" card backing in `src/Views/CardView.swift`
- [X] T010 [P] [US1] Implement programmatic vectors for "Aquarium Fish" card backing in `src/Views/CardView.swift`
- [X] T011 [US1] Update board felt rendering block in `src/Views/GameView.swift` to dynamically color-bind felt color selection
- [X] T012 [US1] Update application menu and control panels in `src/Views/GameView.swift` to select new card backs and felt colors

**Checkpoint**: At this point, User Story 1 (Themes & Colors Customization) is fully functional and testable independently.

---

## Phase 4: User Story 2 - Legacy Preferences Dialog & Options (Priority: P2)

**Goal**: Toggle Timed, Status bar visibility, Sound, constraints, and Vegas options via sheet modal

**Independent Test**: Toggle options in the sheet, confirm Status Bar toggles visibility and Timed game halts/starts the clock.

### Implementation for User Story 2

- [X] T013 [P] [US2] Add toggle property observers and settings update handlers in `src/ViewModels/GameViewModel.swift`
- [X] T014 [US2] Implement the Options sheet layout view (Timed, Status bar, Sound, Constraints, Vegas) in `src/Views/GameView.swift`
- [X] T015 [US2] Bind the Status Bar visibility toggle to the top panel layout element in `src/Views/GameView.swift`
- [X] T016 [US2] Implement Timer stop/start logic checking based on timed option state in `src/ViewModels/GameViewModel.swift`

**Checkpoint**: At this point, User Stories 1 AND 2 are both functional and testable.

---

## Phase 5: User Story 3 - Vegas Scoring & Draw Constraints (Priority: P2)

**Goal**: Implement Vegas scoring rules, dollar formatting, and optional stock recycle lockouts

**Independent Test**: Play a game in Vegas mode starting at `-$52.00`, confirm foundation payouts, and verify draw recycles disable when limit is reached.

### Implementation for User Story 3

- [X] T017 [US3] Add Vegas currency formatting logic and cent-based score updates in `src/ViewModels/GameViewModel.swift`
- [X] T018 [US3] Implement score rules payouts and deductions modifications in `src/ViewModels/GameViewModel.swift`
- [X] T019 [US3] Implement stock recycle counters and limits check in `src/ViewModels/GameViewModel.swift`
- [X] T020 [US3] Update `StockPileView` in `src/Views/PileView.swift` to render empty slot and ignore gesture inputs when recycle limit is hit

**Checkpoint**: All user stories up to P2 are complete.

---

## Phase 6: User Story 4 - Nostalgic Sound Effects (Priority: P3)

**Goal**: Play retro auditory cues on shuffle, slide/drop, and victory cascades

**Independent Test**: Perform draws and drops with sound enabled and verify audio feedback. Turn off sound in Options and verify silent operation.

### Implementation for User Story 4

- [X] T021 [P] [US4] Bundle public domain retro audio clips for shuffle, card snap, and victory tune
- [X] T022 [US4] Create helper class or extensions using AppKit's `NSSound` to play sound files in `src/ViewModels/GameViewModel.swift`
- [X] T023 [US4] Bind deck shuffling audio cue to game deal and Stock recycle operations in `src/ViewModels/GameViewModel.swift`
- [X] T024 [US4] Bind snapping audio cue to valid drag-and-drop placements in `src/ViewModels/GameViewModel.swift`
- [X] T025 [US4] Bind victory fanfare tune to the start of bouncing win cascades in `src/Views/WinAnimationView.swift` or `src/Views/GameView.swift`

**Checkpoint**: Sound effects are fully integrated.

---

## Phase 7: User Story 5 - Keyboard Shortcuts & Statistics Panel (Priority: P3)

**Goal**: Bind standard Command keyboard shortcuts and show lifetime statistics metrics

**Independent Test**: Trigger undo/new game via shortcuts, and check that win percentages, averages, and streaks persist and show up correctly in the stats modal.

### Implementation for User Story 5

- [X] T026 [P] [US5] Implement lifetime streak calculations and save methods in `src/ViewModels/GameViewModel.swift`
- [X] T027 [US5] Bind Cmd keyboard shortcuts (`Cmd+Z`, `Cmd+N`, `Cmd+H`, `Cmd+1`, `Cmd+3`) to layout view actions in `src/Views/GameView.swift`
- [X] T028 [US5] Implement the Statistics summary sheet layout view in `src/Views/GameView.swift`

**Checkpoint**: All user stories are now independently functional.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Fine-tuning, code formatting, compile verification, and manual E2E validation

- [X] T029 Refactor settings variables and format UserDefaults keys to prevent data contamination
- [X] T030 Perform memory leakage and CPU usage analysis on programmatic vector assets
- [X] T031 Run quickstart.md validation checklist and confirm 100% of scenarios pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed sequentially in priority order (P1 → P2 → P3) or in parallel.
- **Polish (Final Phase)**: Depends on all user stories being complete

### Parallel Opportunities

- Card back vector drawing tasks (T007-T010) can run in parallel by different developers.
- Settings variables and stats calculation tasks (T013, T026) can run concurrently.
- Sound effects integration (Phase 6) and Statistics/Shortcuts (Phase 7) can run in parallel since they target distinct files.

---

## Parallel Example: User Story 1

```bash
# Developer A:
Task: "Implement programmatic vectors for 'Blue Rose' card backing in src/Views/CardView.swift"

# Developer B:
Task: "Implement programmatic vectors for 'Spooky Castle' card backing in src/Views/CardView.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (Cosmetics MVP)
4. **STOP and VALIDATE**: Test felt color swaps and card backings on the board

### Incremental Delivery

1. Setup + Foundation → Core structures ready
2. Add US 1 (Cosmetics) → Demo visually
3. Add US 2 (Options Sheet) → Demo toggles
4. Add US 3 (Vegas Rules) → Demo scoring + constraints
5. Add US 4 (Sound SFX) → Demo auditory feedback
6. Add US 5 (Shortcuts & Stats) → Demo full production app
