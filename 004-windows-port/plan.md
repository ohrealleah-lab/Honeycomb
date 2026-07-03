# Implementation Plan: Windows Desktop Port

**Branch**: `004-windows-port` | **Date**: 2026-06-23 | **Spec**: [spec.md](file:///Users/leah/SoliBee/specs/004-windows-port/spec.md)

**Input**: Feature specification from `/specs/004-windows-port/spec.md`

## Summary

The goal is to port the SoliBee Solitaire suite (Classic Solitaire, Beecell, Spider) from macOS (Swift/SwiftUI) to the Windows platform. The game will be built using modern .NET 8 and C# 12, leveraging the MVVM CommunityToolkit for architecture and WinUI 3 / WPF for programmatic UI rendering. The port must preserve 100% of the game logic, scoring behaviors, vector theme styling, persistent preferences, and sound effect integrations.

## Technical Context

**Language/Version**: C# 12 / .NET 8.0+

**Primary Dependencies**: Microsoft.WindowsAppSDK (WinUI 3) or WPF, CommunityToolkit.Mvvm (for MVVM support)

**Storage**: `Windows.Storage.ApplicationData` (LocalSettings) for options, shared global registry keys for synced background themes/felts, and JSON files in local application data for statistics

**Testing**: xUnit or MS Test

**Target Platform**: Windows 10 (1809) and Windows 11

**Project Type**: Windows Desktop Application

**Performance Goals**: Sub-200ms application launch, stable 60 FPS rendering during dragging and card cascade animations, sub-10ms logic loop execution

**Constraints**: Strict MVVM separation (Views only bind to ViewModels), no raster images for cards or card back patterns (drawn dynamically via XAML Paths/Canvas vectors), immediate settings updates trigger across all active view modules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I (MVVM Boundaries)**: COMPLIANT. View-ViewModel-Model boundaries will be maintained in C#. All logic (autocomplete, hints) is isolated in ViewModels, Models remain pure C# classes, and XAML Views only bind to ViewModels.
- **Principle II (Programmatic UI / Vector Themes)**: COMPLIANT. XAML Vector paths (`PathGeometry`, `Canvas` shapes) will be used to render card faces, card backs, and board felts natively at any scale without external PNG/JPG dependencies. Includes standard "Desert" theme assets.
- **Principle III (Test-Driven Verification)**: COMPLIANT. A separate test project utilizing xUnit will cover all rule engines, scoring adjustments, and ViewModel transitions.
- **Principle IV (Persistent Configurations)**: COMPLIANT. Uses the native Windows `LocalSettings` store to persist options and JSON file serialization for detailed statistics. Integrates cross-game options synchronization on modification, utilizing property-changed events or notification broadcasts to trigger immediate visual redrawing.
- **Principle V (Sound & Animations)**: COMPLIANT. Card bouncing animations will use the XAML Composition layer / Win2D canvas, and sounds will use low-latency Windows media APIs.

## Project Structure

### Documentation (this feature)

```text
specs/004-windows-port/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (C# SoliBee Solution)

```text
src/
├── SoliBee.Core/        # Shared Portable Class Library (.NET Standard / .NET 8)
│   ├── Models/          # Card, Pile, GameState, GameOptions, GameStatistics
│   └── ViewModels/      # GameViewModel, BeecellViewModel, SpiderViewModel, AppCoordinator
├── SoliBee.Desktop/     # Platform Platform Executable (WinUI 3 / WPF)
│   ├── Views/           # MainWindow, GameView, BeecellView, SpiderView, CardView, PileView
│   ├── Assets/          # Audio files (shuffle.wav, snap.wav, victory.wav)
│   └── App.xaml
tests/
└── SoliBee.Tests/       # Unit testing project (xUnit)
    ├── Core/            # Tests for game states, logic solvers, and validation
    └── ViewModels/      # Tests for VM commands, undo stack, and rules
```

**Structure Decision**: A multi-project solution structure separating the pure .NET 8 game core (`SoliBee.Core`) from the native presentation layer (`SoliBee.Desktop`) and the test suite (`SoliBee.Tests`).

## Complexity Tracking

*(No violations)*
