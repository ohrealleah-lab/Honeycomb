# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make build   # Compile (release), assemble Honeycomb.app bundle, codesign
make run     # build + open Honeycomb.app
make test    # Compile and run SoliBeeTests/
make clean   # Remove Honeycomb.app and .build/
```

`make build` is the only way to produce a runnable app — it compiles with `swift build -c release`, copies the binary and all resource files (images, audio, plist, icon) into `Honeycomb.app/Contents/`, and re-signs the bundle. Any new resource files added to the project root or `src/` must be manually added to the Makefile `cp` block.

Tests use a custom `TestRunner.swift` entry point (not XCTest) so the GUI `@main` is excluded from the test compile. Run individual tests by editing `TestRunner.swift` to call only the desired suite.

## Architecture

### Entry point and routing
`SoliBeeApp.swift` owns a single `@State private var coordinator = AppCoordinator()` and passes it into `AppRouterView`, which switches between `GameView` / `BeecellView` / `SpiderView` based on `coordinator.gameMode`. The coordinator is injected into the environment (`.environment(coordinator)`) so card views can read it.

### AppCoordinator (`src/ViewModels/AppCoordinator.swift`)
The single source of truth for which game is active. Holds all three ViewModels (`klondikeViewModel`, `beecellViewModel`, `spiderViewModel`) alive simultaneously. On `gameMode.didSet` it calls `syncSharedOptions(from:to:)` which copies shared preferences (`isTimed`, `isSoundEnabled`, `hideHintButton`, `hideStatsButton`, `isDarkMode`) from the outgoing game to the other two so settings stay in sync across mode switches.

### Per-game structure (repeated for Klondike / Beecell / Spider)
Each game follows the same three-layer pattern:
- **Model**: `GameOptions` / `BeecellOptions` / `SpiderOptions` — `Codable` structs persisted as JSON to `UserDefaults` (`"solitaire_options"`, `"beecell_options"`, `"spider_options"`). Always use `decodeIfPresent ?? default` in `init(from:)` so new fields survive old saves without migration. Theme fields (felt color, card back, custom card colors, felt vignette, custom background) do **not** live here — see "App-wide theme" below.
- **ViewModel**: `GameViewModel` / `BeecellViewModel` / `SpiderViewModel` — `@Observable` classes. `options.didSet` saves options for that game's own (non-theme) settings.
- **View**: `GameView` / `BeecellView` / `SpiderView` — owns the game board and an inline `OptionsView` / `BeecellOptionsView` / `SpiderOptionsView` sheet. Options sheets use local `@State` vars initialized from `viewModel.options` for that game's own settings, then build an `updatedOpts` struct and assign it on OK. Theme controls in the sheet's Themes sub-panel bind directly to `AppCoordinator` instead.

### App-wide theme (`AppCoordinator`)
`feltColor`, `cardBackTheme`, `customCardColors`, `showFeltVignette`, `customFeltRed`/`Green`/`Blue`, and `customBackgroundName` are live `@Observable` properties directly on `AppCoordinator` — a single shared value for the whole app, not per-game-mode and not synced via `NotificationCenter`. Each property's own `didSet` persists it to UserDefaults (`"global_felt_color"`, `"cardBackTheme"`, `"customCardColors"`, `"showFeltVignette"`, `"custom_felt_red"`/`"custom_felt_green"`/`"custom_felt_blue"`, `"custom_background_name"`). `AppCoordinator` is injected once at the app root (`.environment(coordinator)`) and read as a required (non-Optional) `@Environment(AppCoordinator.self)` everywhere it's needed, including inside each game's Options sheet (passed through as `@Bindable var coordinator: AppCoordinator`) so the Themes sub-panel can bind straight to it (`$coordinator.feltColor`, etc.) with no manual Optional-coalescing.

### Card rendering (`src/Views/CardView.swift`)
`CardView` reads `cardBackTheme` and `isDarkMode` by switching on `coordinator.gameMode` to reach the active ViewModel's options. `CardFrontView` computes a `color` from suit + dark mode and passes it down to `CardCenterSuitView`. For J/Q/K:
- **Light mode**: loads PNG images (`J.png`, `Q.png`, `K.png`, `red j.png`, etc.) from the app bundle via `FaceCardImageView` with `fillFrame: false` (height-62 constraint + clip).
- **Dark mode**: loads dedicated letter PNGs (`dark_k_red.png`, `dark_j_grey.png`, etc.) via `FaceCardImageView` with `fillFrame: true` (fits to full 77×122 frame).
- **Custom face card art** always takes priority over both paths.

### Custom art managers
`CustomCardBackManager`, `CustomFaceCardArtManager`, and `CustomBackgroundManager` are `@Observable` singletons (`shared`). They persist image files under `~/Library/Application Support/SoliBee/`, each in its own subfolder (`CardBacks/`, `FaceArt/`, `Backgrounds/` respectively) and store metadata in `UserDefaults`. Image caches (`imageCache`, `thumbnailCache`) are `@ObservationIgnored` to prevent SwiftUI from re-rendering all card views on every cache write. GIF card backs animate only on the stock pile (backgrounds are static images only). PNG encoding for imports is shared via `ImageEncoding.pngData(from:)`. All three managers' "is this asset referenced by a saved Theme" delete-safeguard checks go through `ThemeManager.themeReferencingCardBack(named:)` / `themeReferencingFaceArt(relativePath:)` / `themeReferencingBackground(named:)`.

### Adding a new app-wide theme field
1. Add the stored property to `AppCoordinator` with a `didSet` that persists it to UserDefaults, and load its initial value in `AppCoordinator.init()`.
2. Add it to `SoliBeeTheme` (with a sensible default so old saved themes still decode) if saved Theme presets should be able to reference/restore it, and update `AppCoordinator.applyTheme(_:)`.
3. Add a binding for it in each game's Options sheet's `ThemesOptionsView(...)` call (`$coordinator.<field>`) and revert it in that sheet's Cancel handler.

### Adding a new per-game (non-theme) option
1. Add the property to that one game's Options struct with a `decodeIfPresent ?? default` decoder line and a matching `CodingKeys` case.
2. If it should stay in sync across game modes on switch (like `isSoundEnabled`/`noStressMode`), add it to `syncSharedOptions` in `AppCoordinator` — this is only for genuinely per-game-struct fields; theme fields never go here.
3. Add `@State` + init + `updatedOpts` assignment in that game's Options view.

### Dark mode card colors
- Red suits (hearts/diamonds): `Color(red: 1.0, green: 0.267, blue: 0.267)` — #FF4444
- Black suits (spades/clubs): `Color(red: 0.753, green: 0.753, blue: 0.753)` — #C0C0C0
- Card face background: `Color(red: 0.118, green: 0.118, blue: 0.118)` — #1E1E1E
- Card border: `Color(red: 0.3, green: 0.3, blue: 0.3)`

The dark mode letter PNGs (`dark_*_red.png`, `dark_*_grey.png`) in the project root were generated by cropping `DarkModeletters.png` and recoloring to match the above values. If regenerating, use the Python/PIL script pattern from the session history and update the Makefile `cp` block to include them in the bundle.
