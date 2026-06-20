# Implementation Plan: Solitaire SoliBee (macOS App)

**Branch**: `001-solitaire-game` | **Date**: 2026-06-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-solitaire-game/spec.md`

## Summary

The objective is to build a retro-styled Klondike Solitaire game named **SoliBee** as a standalone macOS `.app` bundle. The tech stack consists of **Swift 6**, **SwiftUI**, and the **MVVM** architecture. The application will be compiled directly from source and packaged into a macOS application bundle. Visual assets (cards, background, suits, custom Bee backing) will be drawn programmatically using SwiftUI shapes and paths to ensure crisp resolution and independence from external image files. Bouncing cards, hints, scoring, and autocomplete systems will be integrated into the Core MVVM engine.

## Technical Context

**Language/Version**: Swift 6

**Primary Dependencies**: SwiftUI, Foundation, AppKit (for window/app lifecycle wrappers if needed)

**Storage**: In-memory (state reset on restart)

**Testing**: Swift Testing (standard testing framework for Swift 6)

**Target Platform**: macOS (macOS 14.0+) packaged as a standalone `SoliBee.app` bundle.

**Project Type**: Desktop Application

**Performance Goals**: 60 fps for the win bouncing animation, sub-10ms logic calculations, sub-30ms drag and drop responsiveness.

**Constraints**: Standalone `.app` bundle, no external asset dependencies, strictly MVVM.

**Scale/Scope**: Single window solitaire game application.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- No constitutional violations found. Standard principles (Clean Architecture, MVVM separation, Unit Testable Model logic) will be fully respected.

## Project Structure

### Documentation (this feature)

```text
specs/001-solitaire-game/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Technical research & decisions
├── data-model.md        # State structures & transition definitions
├── quickstart.md        # Validation & build guides
└── tasks.md             # Tasks checklist (created next)
```

### Source Code (repository root)

We will structure the Swift source files directly under `src/` to make compilation straightforward using the Swift compiler (`swiftc`).

```text
src/
├── SoliBeeApp.swift          # Main entry point (App lifecycle)
├── Models/
│   ├── Card.swift            # Rank, suit, colors, and faceUp status
│   ├── Pile.swift            # Generic pile structure (Stock, Waste, Tableau, Foundation)
│   └── GameState.swift       # Aggregate board state
├── ViewModels/
│   └── GameViewModel.swift   # Solitaire VM handling interactions, rules, hints, autocomplete
└── Views/
    ├── GameView.swift        # Main board screen (Green felt background, Layout)
    ├── CardView.swift        # Card visual component (front with rank/suit, custom back with Bee)
    ├── PileView.swift        # Container views for piles (Stock, Waste, Tableau, Foundation)
    └── WinAnimationView.swift# Custom canvas/animation view for victory bounces

SoliBeeTests/
├── GameStateTests.swift      # Model unit tests
└── GameViewModelTests.swift  # VM unit tests and rule enforcement tests

Makefile                      # Automates compilation and packaging into SoliBee.app
```

**Structure Decision**: A flat-ish directory layout with separate directories for Models, ViewModels, Views, and Tests. This keeps it organized and enables compiling the source folder in one command: `swiftc -o SoliBee.app/Contents/MacOS/SoliBee -sdk $(xcrun --show-sdk-path) -target x86_64-apple-macos14.0 src/**/*.swift` (supporting both x86_64 and arm64).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*(No violations)*
