# Implementation Plan: Solitaire Enhancements

**Branch**: `002-enhanced-solitaire-features` | **Date**: 2026-06-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-enhanced-solitaire-features/spec.md`

## Summary
The goal is to build on top of the SoliBee codebase to add retro customizations (themes, backgrounds, preference panels), Vegas rules/scoring, optional draw recycles constraints, keyboard shortcuts, and sound effects using macOS standard libraries (`AppKit`/`NSSound`, `SwiftUI`). All card backs will be drawn programmatically using SwiftUI shapes to ensure native resolution, maintaining the zero-external-assets layout design.

## Technical Context

**Language/Version**: Swift 6 (native macOS compilation target)

**Primary Dependencies**: SwiftUI, AppKit (`NSSound` for audio)

**Storage**: Persistent settings and statistics stored in `UserDefaults`

**Testing**: Standard Unit Tests in `SoliBeeTests/`

**Target Platform**: macOS 14.0+

**Project Type**: Desktop Application (`SoliBee.app` bundle)

**Performance Goals**: Sub-20ms theme rendering switch, sub-40ms sound playback latency, sub-15ms keyboard shortcuts VM command processing.

**Constraints**: Standalone `.app` bundle, no external asset dependencies (all graphics drawn programmatically), strictly MVVM structure.

**Scale/Scope**: Single window solitaire game application.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- No constitutional violations found. Standard principles (MVVM boundaries, testability of model states) are respected.

## Project Structure

### Documentation (this feature)

```text
specs/002-enhanced-solitaire-features/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 data structure schema
└── quickstart.md        # E2E validation script
```

### Source Code

We will modify the existing files under `src/`:

```text
src/
├── Models/
│   ├── Card.swift            # Standard Card model
│   ├── GameState.swift       # Track Vegas score state and recycle limits
│   └── GameOptions.swift     # NEW: Settings struct (Sound, Timed, Vegas, Constraints)
├── ViewModels/
│   └── GameViewModel.swift   # Handle Vegas scoring rules, Options toggles, Stats calculation, Sound triggers
└── Views/
    ├── GameView.swift        # Add Options/Stats sheets, felt backgrounds, bind keyboard shortcuts
    ├── CardView.swift        # Draw card backs (Vulpera, Moogle, Dingwall, etc.)
    └── PileView.swift        # Restrict Stock recycle clicks when limit is reached
```

**Structure Decision**: Flat directory layout with separate directories under `src/`. Swapping options and statistics dynamically via SwiftUI Sheets and UserDefaults.

## Complexity Tracking

*(No violations)*
