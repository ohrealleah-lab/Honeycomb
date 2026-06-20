# Research & Technical Decisions: Solitaire Enhancements

This document outlines the technical investigations, architecture choices, and rationale for implementing the retro themes, scoring rules, sound effects, and controls.

## 1. Audio System (NSSound vs. AVFoundation)
* **Decision**: Use `NSSound` from the `AppKit` library.
* **Rationale**:
  - `NSSound` provides a simple, synchronous-to-start, lightweight API perfect for playing short sound effects (shuffle, card snap, victory).
  - It supports playing system sounds or custom `.wav`/`.mp3`/`.aiff` files bundled directly in the app resource directory.
  - Avoids the heavier overhead and complexity of configuring audio sessions in `AVFoundation` (e.g. `AVAudioPlayer`), which is typically geared towards multi-track audio playback or iOS-focused audio routing.
* **Implementation Pattern**:
  - Store `.wav` audio files in the application bundle resources folder.
  - Access sound resources using `Bundle.main.url(forResource:withExtension:)`.
  - Play sounds cleanly using `NSSound(contentsOf:byReference:).play()`.
* **Alternatives Considered**:
  - *AVAudioPlayer*: Rejected due to verbose initialization, handling audio session state, and delegation requirements which are unnecessary for simple retro sound triggers.

## 2. Programmatic Drawing of Retro Card Backs
* **Decision**: Programmatically draw the "Blue Rose", "Spooky Castle", "Palm Tree", and "Aquarium Fish" card backs using SwiftUI shapes (`Shape`, `Path`, gradients, and symbols) to align with our zero-external-assets goal.
* **Rationale**:
  - Keeps the codebase compact and ensures pixel-perfect sharpness across all display scale factors.
  - Follows the existing programmatic approach used for suits and vector face card elements (Shield, Tiara, Crown).
* **Themes Breakdown**:
  - *Blue Rose*: Programmatic rose petal path combined with a dark blue vignette background gradient.
  - *Spooky Castle*: Path outlining castle turrets against a full moon circle backdrop.
  - *Palm Tree*: Trunk/frond paths with a tropical sunset background gradient.
  - *Aquarium Fish*: Oval body, triangle fins, and bubbles against an underwater blue gradient.
* **Alternatives Considered**:
  - *Asset Images*: Rejected to keep the bundle clean and avoid copyright issues. Programmatic drawing is more creative and visually crisp.

## 3. Keyboard Shortcuts in SwiftUI
* **Decision**: Implement keyboard shortcuts using SwiftUI's `.keyboardShortcut(_:modifiers:)` modifier on buttons and menu items inside `GameView.swift`.
* **Rationale**:
  - Native integration with macOS menu bars and system shortcuts.
  - Automatically handles event routing when the application is active and focused.
* **Shortcut Bindings**:
  - Undo: `Cmd+Z` (`.keyboardShortcut("z", modifiers: .command)`)
  - New Game: `Cmd+N` (`.keyboardShortcut("n", modifiers: .command)`)
  - Hint: `Cmd+H` (`.keyboardShortcut("h", modifiers: .command)`)
  - Draw 1 Card: `Cmd+1` (`.keyboardShortcut("1", modifiers: .command)`)
  - Draw 3 Cards: `Cmd+3` (`.keyboardShortcut("3", modifiers: .command)`)

## 4. Game State Persistence (UserDefaults)
* **Decision**: Store long-term statistics and user options (Felt Color, Theme, Timed toggle, Sound toggle, Vegas toggle, Draw constraints) in `UserDefaults`.
* **Rationale**:
  - Standard, built-in macOS storage mechanism for simple key-value settings.
  - Lightweight and highly reliable.
  - Already used in the app for zoom and simple game stats.
* **Schema**:
  - `gamesPlayed`: Int
  - `gamesWon`: Int
  - `bestTime`: Int (seconds)
  - `totalWinningTime`: Int (for average calculation)
  - `winningGamesCount`: Int
  - `currentStreak`: Int
  - `longestStreak`: Int
  - `feltColorTheme`: String
  - `isSoundEnabled`: Bool
  - `isVegasMode`: Bool
  - `isDrawConstraintsEnabled`: Bool
  - `isStatusBarVisible`: Bool
  - `isTimedGame`: Bool
