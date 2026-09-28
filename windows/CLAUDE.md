# Honeycomb Windows Port — CLAUDE.md

## Tools

Use the Context7 MCP server automatically for any question involving library or framework API usage, documentation, or version-specific behavior (e.g., Avalonia UI, .NET). Don't wait to be asked — reach for it whenever current/accurate docs would help, instead of relying on training data.

## Project overview
Avalonia UI 11.0.10 / .NET 8 port of the **Honeycomb Card Suite** — all six games: Klondike, Freecell (called Beecell on Mac/iOS/Android), Spider, Video Poker, Blackjack, and Honeycomb (the card battle game). Lives in the monorepo's `windows/` folder alongside `mac/`, `ios/`, `android/` and the Swift `shared/` code. ("SoliBee" in namespaces/project names is legacy naming.)

**Parity: Mac is the source of truth.** Game rules, scoring, stats and AI must behave the same as Mac (`shared/` Swift code + `mac/src`); when Windows differs, align it to Mac. Cross-platform golden-vector tests enforce this for the deterministic engines — see "Parity tests" below. Deliberate, documented differences only (e.g. Windows keeps short internal names for two Deuces Wild pay-table rows because they double as stats keys).

## Build & run
```bash
# Debug build (runs on Mac for development)
dotnet build src/SoliBee.Desktop/SoliBee.Desktop.csproj

# Windows release executable (~118 MB self-contained)
dotnet publish src/SoliBee.Desktop/SoliBee.Desktop.csproj /p:PublishProfile=win-x64
# Output: src/SoliBee.Desktop/bin/publish/win-x64/Honeycomb.exe  (+ Assets/ folder)
```

WAV files (`shuffle.wav`, `snap.wav`, `victory.wav`) must sit in the same directory as the `.exe` — they're `Content` files copied to output, not embedded. Audio uses `winmm.dll` P/Invoke compiled in only when `WINDOWS` symbol is defined.

## Solution layout
```
SoliBee.Core/
  Models/       Card, Pile, GameState/GameStatistics/ModeStats (solitaire), Blackjack*, VideoPoker*,
                PokerHandEvaluator, Honeycomb* (Board, Card, AI, CardGenerator, Database, Deck, …)
  Services/     SettingsService, StatsService, AtomicFile, BannerCatalog, ThemeService,
                FaceCardArtService, CrashLogger, …
  ViewModels/   AppCoordinator, GameViewModel (Klondike), FreecellViewModel, SpiderViewModel,
                VideoPokerViewModel, BlackjackViewModel, HoneycombViewModel
SoliBee.Desktop/
  Views/        MainWindow, GameView/FreecellView/SpiderView, VideoPokerView, BlackjackView,
                HoneycombView (+ HoneycombRulesView, ManageDecksView, DeckBuilderView),
                PreferencesView, CardView, …
  Assets/       Card-back images, fonts (Apple Chancery, Parisienne), WAV files, banner catalog JSON
  Properties/PublishProfiles/win-x64.pubxml
tests/SoliBee.Tests/  xUnit — `dotnet test SoliBee.sln` from windows/
```

## Parity tests
Mac generates shared JSON test vectors (see `mac/CLAUDE.md` → "Honeycomb capture-rule parity vectors"); these tests replay them against the Windows engines and fail on any drift from Mac:
- `HoneycombGoldenVectorTests` — capture rules (Same/Plus/Fallen Ace/Reverse/Ascension/combos)
- `HoneycombAIVectorTests` — AI/hint search scores
- `VideoPokerVectorTests` — hand names + payouts per variant/bet
- `HoneycombCardDatabaseVectorTests` — card ids/names/stars/suits and tier rules

If one fails after a Windows change, Windows drifted — fix Windows. If it fails after pulling a Mac rules change with regenerated vectors, port that change here.

## Persistence
Everything persisted (settings, stats, card bank, decks, card-database seed, themes) is written through `AtomicFile.WriteAllText` (write temp, then replace) — never `File.WriteAllText` directly, since loaders fall back to defaults on a parse failure and a half-written file would silently wipe the data on the next save.

## Key architecture notes
- **MVVM** via `CommunityToolkit.Mvvm`; settings changes broadcast with `WeakReferenceMessenger` (`OptionsChangedMessage`, `FaceCardArtChangedMessage`)
- **SettingsService** reads/writes `GameOptions` to JSON; call `SettingsService.LoadOptions()` / `SaveOptions()` — loaded fresh each call (no singleton cache)
- **Static brush pool** in `CardView.axaml.cs` — never create `SolidColorBrush` per-render; add to the `_brush*` static fields instead
- **SkiaSharp 2.88.7** used for image processing (trim, background removal, scaling)

## Card layout dimensions
- `CardRoot` Grid: **128 × 181 px**
- `CardFace` Border: fills CardRoot, `Padding="4"` → inner usable area ~120 × 173
- `CenterGrid` (Grid inside CardFace): **Width=86, Height=138**, centered
- `SuitCanvas` (pip grid for numbered cards 2–10): 86 × 138, lives inside CenterGrid
- `FaceCardImage` (J/Q/K/A art): default AXAML 70 × 60; overridden in code per mode (see below)
- `CardBack` Border: `HorizontalAlignment=Stretch, VerticalAlignment=Stretch` (not fixed size — important for border stroke visibility)

## Face card art system (16-slot custom art — A/J/Q/K × 4 suits, same as Mac)
- **`FaceCardSlot` enum**: the original 8 `Black*`/`Red*` cases (Ace/Jack/Queen/King) are the **Spades**/**Hearts** slots (names kept so existing saved art still loads), followed by `Diamonds*` and `Clubs*` — 16 in total
- **`FaceCardArtService`** (static singleton, `_loaded` flag): loads art config from JSON; `GetArt(slot)` returns `CustomFaceArt?`
- **`CustomFaceArt`**: `RelativePath` (filename in art dir), `Scale`, `OffsetX`, `OffsetY`, `IsEnabled`
- **`_customBitmapCache`** (static dict in `CardView`): cleared by `CardView.InvalidateFaceArtCache()`; populated lazily by `GetCachedFaceArtBitmap(path)`

## Pointer / async gotcha
`PointerPressed` + `async void` + `ShowDialog` leaves implicit pointer capture on the element. Always call `e.Pointer.Capture(null)` before awaiting, and guard with an `_isOpen` bool field to prevent re-entry. See `PreferencesView.axaml.cs` → `CardBackPreview_Click` for the pattern.

## Options page previews
The tile previews in `FaceCardArtSectionView` are 78 × 111 scaled-down card thumbnails (`cardBorder`). The center art image in each tile is a 45 × 73 `Image` (`centerGrid`, `ClipToBounds=true`) — this matches `CardView`'s 74 × 119 face-art clip window scaled down by the tile's own ~0.61x factor. It reuses `CardView.GetCachedFaceArtBitmap(path, art.Scale, art.OffsetX, art.OffsetY)` directly, so it's the *same* baked bitmap the real card shows (already correctly cropped to the clip window) — keep this box's aspect ratio in sync with `CardView`'s `FaceArtCacheW`/`FaceArtCacheH` (currently 74:119) or the tile will letterbox/look disproportionate against a mismatched box.
