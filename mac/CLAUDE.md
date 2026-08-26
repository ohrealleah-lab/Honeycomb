# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tools

Use the Context7 MCP server automatically for any question involving library or framework API usage, documentation, or version-specific behavior (e.g., SwiftUI). Don't wait to be asked — reach for it whenever current/accurate docs would help, instead of relying on training data.

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
The single source of truth for which game is active. Holds all six ViewModels (`klondikeViewModel`, `beecellViewModel`, `spiderViewModel`, `videoPokerViewModel`, `blackjackViewModel`, `honeycombViewModel`) alive simultaneously. Fields that are genuinely shared across every game — `isSoundEnabled`, `noStressMode`, `honeyMode`, `manuallyDismissBanners`, `hideHintButton` — live as single-source `@Observable` properties directly on `AppCoordinator` (own UserDefaults key, `didSet` persists + calls `applySharedCommonOptionsToAllGames()` to mirror the value into every game's own `options.X`). There's no per-outgoing-game sync on `gameMode` switch — that used to exist (`syncSharedOptions`) and had a real bug (switching games could silently overwrite these fields with whichever game you'd last left); it was removed once every shared field had its own coordinator property.

### Per-game structure (repeated for Klondike / Beecell / Spider)
Each game follows the same three-layer pattern:
- **Model**: `GameOptions` / `BeecellOptions` / `SpiderOptions` — `Codable` structs persisted as JSON to `UserDefaults` (`"solitaire_options"`, `"beecell_options"`, `"spider_options"`). Always use `decodeIfPresent ?? default` in `init(from:)` so new fields survive old saves without migration. Theme fields (felt color, card back, custom card colors, felt vignette, custom background) do **not** live here — see "App-wide theme" below. Each struct still carries its own copy of the coordinator-owned shared fields (`isSoundEnabled`, `noStressMode`, `honeyMode`, `manuallyDismissBanners`, `hideHintButton` where the game has that concept) for `Codable`/backward-compat and because some game logic reads `options.X` directly — but `AppCoordinator` is the only thing allowed to set them; never assign them from within a game's own Options view except by also pushing the edit through `coordinator.X` (see below).
- **ViewModel**: `GameViewModel` / `BeecellViewModel` / `SpiderViewModel` — `@Observable` classes. `options.didSet` saves options for that game's own (non-theme) settings.
- **View**: `GameView` / `BeecellView` / `SpiderView` — owns the game board and an inline `OptionsView` / `BeecellOptionsView` / `SpiderOptionsView` sheet. Options sheets use local `@State` vars initialized from `viewModel.options` for that game's own settings, then build an `updatedOpts` struct and assign it on OK — for the coordinator-owned shared fields, the OK handler *also* assigns `coordinator.X = X` right after, which is what actually makes the edit apply everywhere (skipping this step means the edit gets silently reverted the next time any game switch calls `applySharedCommonOptionsToAllGames()`). Theme controls in the sheet's Themes sub-panel bind directly to `AppCoordinator` instead.

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
2. If it's genuinely shared across most/all games (like `isSoundEnabled`/`noStressMode`/`hideHintButton`) rather than one-game-specific, follow the `honeyMode` pattern instead of this one: add a single-source `@Observable` property directly to `AppCoordinator` (own UserDefaults key, `didSet` → `applySharedCommonOptionsToAllGames()`), still add the field to every relevant game's Options struct (step 1) for `Codable`/backward-compat, and add it to `applySharedCommonOptionsToAllGames()`'s broadcast list for whichever games have it. One-game-specific fields (e.g. `drawMode`, `startingCredits`) skip the coordinator step entirely; theme fields never go here regardless.
3. Add `@State` + init + `updatedOpts` assignment in that game's Options view. For a coordinator-owned shared field, also assign `coordinator.<field> = <field>` in the `onOK` handler right after `viewModel.options = updatedOpts` — this is what makes the edit actually apply everywhere instead of getting reverted by the next `applySharedCommonOptionsToAllGames()` call.

### Banner/toast content pipeline
Honeycomb's in-game banner/toast messages (loading tips, achievement flavor text, idle nudges, etc.) are content-authored, not hand-coded. Source of truth is the **`BannerFlavorText`** sheet inside `tools/Honeycomb_Localization.xlsx` (columns: `Category, Trigger, Message, Type, Location, Spanish`) — the same workbook used for UI-chrome/help-text localization, so there's one file for translators to review, not two. (An earlier, now-retired version of this pipeline used a separate `Honeycomb_Fun_Messages.xlsx` workbook — deleted 2026-08-14 in favor of this merged sheet.)

To add messages to an **existing** trigger: append rows to the `BannerFlavorText` sheet with the exact same (Category, Trigger) text as the existing rows (must match byte-for-byte or it becomes a new entry), then run `python3 tools/generate_banner_catalog.py` (no args — defaults to the repo copy). This regenerates `shared/Honeycomb/Resources/HoneycombBannerCatalog.json` and rewrites `BannerID.swift`/`BannerId.cs` (Windows gets its own JSON copy since it can't reference the shared resource bundle). Never hand-edit any of those generated files — they're overwritten wholesale on every run.

To add a **brand new trigger**: just add the spreadsheet row with new trigger text and regenerate — IDs are auto-derived by slugifying `Category_Trigger` (see `slugify()` in the script), so the new enum case appears automatically in both `BannerID.swift` and `BannerId.cs`. The spreadsheet insert is separate from wiring the trigger into code — a new time-slot/event trigger still needs its condition-checking logic added at the call site (e.g. `loadingBannerID()` in `BannerCatalog.swift`/`BannerCatalog.cs`).

Rebuild + test both platforms after regenerating (`make build && make test` here; `dotnet build && dotnet test` on Windows).

### Dark mode card colors
- Red suits (hearts/diamonds): `Color(red: 1.0, green: 0.267, blue: 0.267)` — #FF4444
- Black suits (spades/clubs): `Color(red: 0.753, green: 0.753, blue: 0.753)` — #C0C0C0
- Card face background: `Color(red: 0.118, green: 0.118, blue: 0.118)` — #1E1E1E
- Card border: `Color(red: 0.3, green: 0.3, blue: 0.3)`

The dark mode letter PNGs (`dark_*_red.png`, `dark_*_grey.png`) in the project root were generated by cropping `DarkModeletters.png` and recoloring to match the above values. If regenerating, use the Python/PIL script pattern from the session history and update the Makefile `cp` block to include them in the bundle.
