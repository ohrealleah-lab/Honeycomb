# Technical Research: Solitaire SoliBee (macOS App)

## 1. Standalone macOS `.app` Bundle Structure and Build Pipeline

### Decision:
Compile the Swift source code directly using the command line Swift compiler (`swiftc`) and package it manually into a macOS application bundle (`SoliBee.app`).

### Rationale:
Using full Xcode project generation (e.g., via XcodeProj or CMake) introduces a lot of heavy workspace configuration files. Packaging a macOS app manually is lightweight, fully scriptable in a `Makefile`, and highly transparent.

### Bundle Layout:
A macOS application bundle has the following minimum structure:
```text
SoliBee.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   └── SoliBee  (compiled binary)
    └── Resources/
        └── AppIcon.icns (optional, fallback to default system executable icon)
```

### Info.plist:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SoliBee</string>
    <key>CFBundleIdentifier</key>
    <string>com.leah.SoliBee</string>
    <key>CFBundleName</key>
    <string>SoliBee</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

### Build Command:
```bash
swiftc -o SoliBee.app/Contents/MacOS/SoliBee -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 src/**/*.swift
```
*Note: We can use `xcrun --show-sdk-path` to resolve the macOS SDK location automatically. We'll target `arm64-apple-macos14.0` (or `x86_64` depending on the host architecture; a universal binary can be compiled or we can default to the host architecture).*

---

## 2. Programmatic Retro Card Assets in SwiftUI

### Decision:
Draw all playing cards, ranks, suits, and the custom Bee card back programmatically using SwiftUI drawing primitives (`Shape`, `Path`, and standard text elements with monospaced retro fonts).

### Rationale:
- Zero asset file dependencies: No need to bundle external `.png` or `.svg` files, making compilation cleaner.
- Pixel-perfect resizing: Programmatic shapes scale beautifully on high-DPI (Retina) screens.
- Customizable Bee card backing: We can draw a repeating diagonal crosshatch pattern (reminiscent of the Bee brand) combined with a retro bee icon in the center using SwiftUI vectors.

### Drawing Details:
- **Card shape**: `RoundedRectangle(cornerRadius: 8)` with border.
- **Suits**: 
  - ♥ (Heart) and ♦ (Diamond) rendered in retro red (`Color(red: 0.8, green: 0.0, blue: 0.0)`).
  - ♠ (Spade) and ♣ (Club) rendered in dark charcoal black (`Color(red: 0.1, green: 0.1, blue: 0.1)`).
- **Custom Bee Card Back**:
  - Main background color: Deep blue or classic red.
  - Crosshatch pattern: Drawn using a custom shape that loops lines across a grid.
  - Bee emblem: Drawn using a custom SVG path or simplified vector shape representing a stylized bee at the center.

---

## 3. Classic Victory Cascading Card Animation

### Decision:
Implement the classic card cascading animation using SwiftUI's `TimelineView` (available in macOS 12.0+) driving a custom canvas-based particle engine.

### Rationale:
Classic Windows Solitaire victory involves card stacks bouncing off the screen.
- Starting at the top of each Foundation pile (starting from Kings downwards), we instantiate a "bouncing card" particle.
- The bouncing card has position `(x, y)` and velocity `(vx, vy)`.
- On every frame (driven by `TimelineView` at 60 FPS):
  - `x += vx`
  - `y += vy`
  - `vy += gravity` (downward acceleration)
  - If `y` exceeds the screen height, it bounces: `y = screenHeight`, `vy = -vy * elasticity` (elasticity ~ 0.85).
  - If a card bounces off the left or right screen boundary, it is deleted.
- **Card Trails**: Instead of clearing the canvas, each particle stores its past 40 positions. We draw these past positions sequentially (or with decreasing opacity) to recreate the signature Windows trailing effect.

---

## 4. MVVM Architecture and State Management

### Decision:
Use the standard MVVM design pattern.
- **Model**: `Card`, `Pile`, and `GameState` structures represent the pure game rules, cards arrangement, and movement validations. They have no dependency on SwiftUI.
- **ViewModel**: `GameViewModel` is an `Observable` class (using the new `@Observable` macro in Swift 6/SwiftUI) that holds the `GameState`, implements rule checkers, performs move validation, tracks scores, runs timers, highlights hints, and triggers the autocomplete sequence.
- **View**: SwiftUI views (`GameView`, `CardView`, `PileView`) observe the View Model. Drag and drop is implemented using SwiftUI's custom gesture systems (`DragGesture`), which communicate positions directly to the View Model.
