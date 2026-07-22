# Tasks: Windows Desktop Port

**Input**: Design documents from `/specs/004-windows-port/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic solution structure

- [x] T001 Create C# Solution file `SoliBee.sln` at the root of the Windows project directory
- [x] T002 Initialize core logic project `src/SoliBee.Core/SoliBee.Core.csproj` as a .NET 8 library
- [x] T003 Initialize Windows UI project `src/SoliBee.Desktop/SoliBee.Desktop.csproj` with WinUI 3 (Windows App SDK) or WPF templates
- [x] T004 Initialize unit test project `tests/SoliBee.Tests/SoliBee.Tests.csproj referencing the xUnit framework and the `SoliBee.Core` library

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core game models that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 [P] Create `CardSuit` enum and `Card` record model in `src/SoliBee.Core/Models/Card.cs`
- [x] T006 [P] Create `PileType` enum and `Pile` class in `src/SoliBee.Core/Models/Pile.cs`
- [x] T007 [P] Create `FeltColorTheme` enum and `GameOptions` data structure in `src/SoliBee.Core/Models/GameOptions.cs`
- [x] T008 [P] Create `GameStatistics` class in `src/SoliBee.Core/Models/GameStatistics.cs`
- [x] T009 Create `GameState` parameters model in `src/SoliBee.Core/Models/GameState.cs`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Desktop Board & Vector Layout (Priority: P1) 🎯 MVP

**Goal**: Renders the green felt game board, empty card slots, and supports responsive layouts for different window sizes.

**Independent Test**: Build and launch the `SoliBee.Desktop` project. Verify that the window displays the card piles layout correctly and coordinates resize on window size adjustments.

### Implementation for User Story 1

- [x] T010 [P] [US1] Define XAML layouts for the main dashboard window in `src/SoliBee.Desktop/Views/MainWindow.xaml`
- [x] T011 [US1] Create the Board felt control in `src/SoliBee.Desktop/Views/GameView.xaml` supporting dynamic resizing
- [x] T012 [P] [US1] Implement programmatic drawing of empty slots and outlines in `src/SoliBee.Desktop/Views/PileView.xaml`
- [x] T013 [US1] Code card suit shapes and front/back card representations using vector paths in `src/SoliBee.Desktop/Views/CardView.xaml`

**Checkpoint**: At this point, the game board and static card assets render dynamically at arbitrary window sizes.

---

## Phase 4: User Story 2 - MVVM Game Loop and Rules (Priority: P1)

**Goal**: Execute and validate standard Klondike card rules, fanning stacks, undo capabilities, and scoring systems.

**Independent Test**: Run unit tests in `SoliBee.Tests` verifying rule moves validation, stack draws, and state rolls.

### Tests for User Story 2

- [x] T014 [US2] Write unit tests for card move permissions (color alternate, rank sequences) in `tests/SoliBee.Tests/Core/MoveRulesTests.cs`
- [x] T015 [US2] Write unit tests for stock draw cycles (Draw-1, Draw-3, recycles) in `tests/SoliBee.Tests/Core/DrawRulesTests.cs`
- [x] T016 [US2] Write unit tests for the undo stack behavior in `tests/SoliBee.Tests/ViewModels/UndoTests.cs`

### Implementation for User Story 2

- [x] T017 [US2] Implement game rules engine and move validation inside `src/SoliBee.Core/ViewModels/GameViewModel.cs`
- [x] T018 [US2] Connect card dragging gestures in `src/SoliBee.Desktop/Views/CardView.xaml.cs` to trigger MVVM commands in the ViewModel
- [x] T019 [US2] Bind game board timer, score counters, and undo action buttons in `src/SoliBee.Desktop/Views/MainWindow.xaml`

**Checkpoint**: Core card play mechanics, standard rules, scores, and undo operations are fully functional.

---

## Phase 5: User Story 3 - Sounds & Victory Cascade (Priority: P2)

**Goal**: Play audio feedback cues during card actions and run a fast card-bouncing cascade animation upon winning.

**Independent Test**: Complete a game (or trigger the mock success command) and check that cards cascade down the window bouncing off layout boundaries.

### Implementation for User Story 3

- [x] T020 [P] [US3] Integrate the Windows `MediaPlayer` in `src/SoliBee.Desktop/Services/SoundService.cs` to trigger low-latency playbacks
- [x] T021 [US3] Implement hardware-accelerated bouncing card cascade renderer in `src/SoliBee.Desktop/Views/WinAnimationView.xaml`
- [x] T022 [US3] Hook game status check to trigger victory cascade when all cards are face up and stock/waste are clear

**Checkpoint**: Sound effects and the card bouncing cascade animation enhance gameplay presentation.

---

## Phase 6: User Story 4 - Persistent Configurations & Stats (Priority: P3)

**Goal**: Persist all statistics, custom preferences, and scoring configurations across application restarts.

**Independent Test**: Modify the options, launch the application, verify options match the selections.

### Implementation for User Story 4

- [x] T023 [US4] Implement options loading and setting synchronization using LocalSettings inside `src/SoliBee.Core/Services/SettingsService.cs`
- [x] T024 [US4] Write JSON statistic serializers in `src/SoliBee.Core/Services/StatsService.cs`
- [x] T025 [US4] Bind options sheet sliders and toggles inside the desktop preferences views in `src/SoliBee.Desktop/Views/PreferencesView.xaml` (including the Desert color scheme)
- [x] T025b [US4] Implement global preferences synchronization across the three game view models and force immediate UI redraw tracking using CustomFeltColorRevision

**Checkpoint**: Preference configurations (including the Desert scheme and instant redrawing), statistics, and high scores persist reliably.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Performance optimizations and final verification

- [x] T026 Optimize memory allocation by recycling Win2D canvas objects during cascades
- [x] T027 Run the `quickstart.md` verification flows to ensure end-to-end correctness
- [x] T028 Update API documentation comments for public methods across SoliBee libraries

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories.
- **User Stories (Phases 3+)**: All depend on Foundational phase completion. They can run in parallel.
- **Polish (Phase 7)**: Depends on all user stories being complete.
