# Tasks: Solitaire SoliBee (macOS App)

**Input**: Design documents from `/specs/001-solitaire-game/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create project folders in repository root
- [X] T002 Configure basic macOS Info.plist in src/Info.plist

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core model infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Create card model representing card ranks, suits, colors and face-up state in src/Models/Card.swift
- [X] T004 Create pile models representing deck, stock, waste, tableau, foundation piles in src/Models/Pile.swift
- [X] T005 [P] Implement unit tests for core card and pile logic in SoliBeeTests/GameStateTests.swift

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Core Gameplay & Draw Modes (Priority: P1) 🎯 MVP

**Goal**: Implement standard Klondike Solitaire rules, Tableau building, stock/waste drawing, and stock recycling in 1-Card and 3-Card modes.

**Independent Test**: Build and run, verify starting state has correct number of cards in piles, drag cards validly between tableaus, flip stock to waste (1 vs 3 fanned out) and verify recycling.

### Implementation for User Story 1

- [X] T006 [P] [US1] Create core game state struct in src/Models/GameState.swift
- [X] T007 [US1] Implement game rules, drawing logic, and stock recycle in src/ViewModels/GameViewModel.swift
- [X] T008 [P] [US1] Add unit tests for rules (Tableau building, stock recycle, drawing) in SoliBeeTests/GameViewModelTests.swift
- [X] T009 [P] [US1] Implement CardView displaying card ranks/suits (front) and custom Bee back art in src/Views/CardView.swift
- [X] T010 [P] [US1] Implement PileView container for Stock, Waste, Tableau, and Foundation piles in src/Views/PileView.swift
- [X] T011 [US1] Implement main board view and drag-and-drop mechanics in src/Views/GameView.swift
- [X] T012 [US1] Create the SwiftUI app entry point in src/SoliBeeApp.swift

**Checkpoint**: At this point, User Story 1 is fully functional and testable independently (MVP ready!).

---

## Phase 4: User Story 2 - AI Autocomplete & Hint Systems (Priority: P2)

**Goal**: Calculate valid moves (hints) using priority matrix and automatically complete the game (autocomplete) when victory is guaranteed.

**Independent Test**: Play/cheat to a won state, check if Autocomplete button displays, click it, and verify that cards animate to foundations automatically. Click hint and check highlighted cards.

### Implementation for User Story 2

- [X] T013 [US2] Implement hint search algorithm (adhering to priorities 1-4) in src/ViewModels/GameViewModel.swift
- [X] T014 [US2] Implement autocomplete game-state checker and solver in src/ViewModels/GameViewModel.swift
- [X] T015 [P] [US2] Write unit tests for hints search and autocomplete trigger logic in SoliBeeTests/GameViewModelTests.swift
- [X] T016 [US2] Update main board UI to display the Hint button and Autocomplete overlay/button in src/Views/GameView.swift

**Checkpoint**: At this point, User Stories 1 AND 2 are both functional and testable.

---

## Phase 5: User Story 3 - Visuals, Theme, Scoring & Win Animation (Priority: P3)

**Goal**: Add visual polish (retro theme), standard Windows scoring/timer, and the signature bouncing card victory animation.

**Independent Test**: Complete a game and verify card-bouncing animation runs, score accumulates, double-clicking cards routes them to foundations.

### Implementation for User Story 3

- [X] T017 [US3] Add double-click automatic routing logic to VM in src/ViewModels/GameViewModel.swift
- [X] T018 [US3] Implement timer updates and standard Windows scoring in src/ViewModels/GameViewModel.swift
- [X] T019 [US3] Implement custom bouncing win canvas/view in src/Views/WinAnimationView.swift
- [X] T020 [US3] Integrate win animation, score, and timer into src/Views/GameView.swift

**Checkpoint**: All user stories are now independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T021 Code refactoring and Swift 6 compiler warning fixes across src/
- [X] T022 [P] Create Makefile automating build, clean, test, and package processes in Makefile
- [X] T023 Run end-to-end verification using specs/001-solitaire-game/quickstart.md and confirm all checklist items pass
- [X] T024 Add smooth horizontal transitions and shuffle animations to stock drawing and recycling in src/Views/PileView.swift and src/Views/GameView.swift


---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### Parallel Opportunities

- Setup tasks (T001-T002) can run in parallel.
- Card/Pile model files in Phase 2 can be developed in parallel (T003-T005).
- CardView and PileView (T009-T010) in Phase 3 can be built concurrently.
- Hint logic unit tests (T015) can run concurrently with VM update validations.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently using `SoliBee.app`
