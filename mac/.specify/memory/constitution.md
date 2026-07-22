<!--
SYNC IMPACT REPORT
- Version Change: v0.0.0 → v1.0.0 (First official ratification of SoliBee project principles)
- List of Modified Principles:
  - [PRINCIPLE_1_NAME] → I. MVVM Boundaries
  - [PRINCIPLE_2_NAME] → II. Programmatic UI & Vector Themes
  - [PRINCIPLE_3_NAME] → III. Test-Driven Verification
  - [PRINCIPLE_4_NAME] → IV. Persistent Configurations
  - [PRINCIPLE_5_NAME] → V. Sound & Victory Cascade Animations
- Added Sections:
  - Core Principles
  - Additional Constraints
  - Development Workflow and Quality Gates
  - Governance
- Removed Sections: None
- Templates Requiring Updates:
  - .specify/templates/plan-template.md (✅ aligned / no changes required)
  - .specify/templates/spec-template.md (✅ aligned / no changes required)
  - .specify/templates/tasks-template.md (✅ aligned / no changes required)
- Follow-up TODOs: None
-->

# SoliBee Constitution

## Core Principles

### I. MVVM Boundaries
The application MUST strictly adhere to the Model-View-ViewModel (MVVM) design pattern. SwiftUI Views MUST only render UI based on state properties exposed by the ViewModel and MUST NOT directly mutate model state. The ViewModel (`GameViewModel`) MUST encapsulate all core game business logic, game loop interactions, autocomplete rules, hint calculations, statistics updates, and persistence triggers. Core data models (`Card`, `Pile`, `GameState`, `GameOptions`, `GameStatistics`) MUST remain pure data-holding structures and MUST NOT import SwiftUI or execute view presentation logic.
- **Rationale**: Keeps UI code decoupled from game logic, allowing the game rules and solvers to be tested independently of macOS rendering and window lifecycles.

### II. Programmatic UI & Vector Themes
All game visual components—including card faces, suits, card backs (e.g. Vulpera, Moogle, Dingwall themes), board felts, empty slots, and pile borders—MUST be rendered programmatically using SwiftUI shapes, paths, and vector gradients. External raster image assets (like PNGs or JPGs) MUST NOT be used for game-playing components (except for reference mockups or static assets placed in non-playing directories). Card layouts, spacing, and sizing MUST scale dynamically using responsive layouts to support resizable macOS window sizes.
- **Rationale**: Eliminates blurred pixelation on Retina displays, keeps the application binary size small, and allows seamless runtime switching of themes.

### III. Test-Driven Verification
Core game state transitions, rule evaluations (e.g., standard vs. Vegas scoring, recycle limits, draw-1 vs. draw-3 rules), and ViewModel state behaviors MUST have comprehensive unit test coverage in `SoliBeeTests`. Any regression or bug fix MUST have an accompanying unit test proving the fix before integration. Continuous Integration or local developer checks MUST run the test suite via `make test` and pass with 100% success before any branch merge.
- **Rationale**: Standardizes game verification and prevents regression bugs when expanding features like Freecell (Beecell).

### IV. Persistent Configurations
Game preferences (such as card back themes, background colors, and recycle draw limits), game statistics (wins, losses, streaks), and separate high scores for Standard and Vegas modes MUST be persisted across application launches. Persistence MUST utilize standard macOS APIs (`UserDefaults` or file-based serialization) and must load preferences on ViewModel initialization. Persistence operations MUST NOT block the main thread; saving state updates should be performed asynchronously or on low-priority background queues.
- **Rationale**: Ensures player achievements, preferences, and custom styling options are seamlessly saved and restored without impacting rendering performance.

### V. Sound & Victory Cascade Animations
The application MUST support classic gameplay audio cues for shuffling, card snapping, and victory. Sound files MUST be packaged locally and played using `AVFoundation`'s low-latency player APIs. A card-bouncing cascade animation MUST trigger immediately upon mathematically guaranteed game victory. Victory cascade cards MUST bounce realistically off the bounds of the viewport and MUST be removed from the view hierarchy once they move completely off-screen. Visual animations and sound cues MUST be toggleable via standard macOS menu items or settings options to support accessibility and quiet play.
- **Rationale**: Delivers the nostalgic feel of classic solitaire games while maintaining high performance and accessibility settings.

## Additional Constraints
- **Language & SDK**: Swift 6 with SwiftUI targeting macOS 14.0 or later. Cocoa or AppKit components MUST only be used when SwiftUI does not provide equivalent APIs (e.g., audio/video system level controls).
- **Tooling and Automation**: The project build pipeline MUST be managed via the root `Makefile` exposing `make build`, `make run`, `make test`, and `make clean` commands. Dependency management MUST be handled through Swift Package Manager (`Package.swift`).

## Development Workflow and Quality Gates
- **Spec Kit Flow**: All new features and amendments MUST follow the Spec Kit process: first write/update the feature specification, then design the implementation plan, generate the task list, and finally execute the tasks.
- **Pre-Commit Gate**: No code is to be pushed to main unless `make build` and `make test` both pass cleanly on Xcode 15+ compatible toolchains.
- **Architecture Validation**: Code reviews and developer checks MUST explicitly check that View files do not hold game state or perform mutations on core Models directly.

## Governance
- **Authority**: This constitution is the single source of truth for architectural constraints, styling guidelines, and engineering processes. Any deviation must be explicitly justified and approved.
- **Amendments**: Amending this constitution requires:
  1. Proposing changes to principles in `constitution.md`.
  2. Updating dependent files, such as spec, plan, and tasks templates.
  3. Incrementing the version tag using semantic versioning.
  4. Updating the `Last Amended` date to the day of ratification.
- **Compliance Reviews**: Spec Kit tasks and plans must include a "Constitution Check" verification step ensuring the proposed design complies with all principles.

**Version**: 1.0.0 | **Ratified**: 2026-06-20 | **Last Amended**: 2026-06-20
