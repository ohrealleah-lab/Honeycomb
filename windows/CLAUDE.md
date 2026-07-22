# SoliBee Windows Port — CLAUDE.md

## Project overview
Avalonia UI 11.0.10 / .NET 8 solitaire suite (Klondike, Beecell, Spider). Active branch: `004-windows-port`. Ported from a Mac-original codebase.

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
  Models/       Card.cs, GameOptions.cs, FaceCardSlot.cs, GameState.cs, Pile.cs, …
  Services/     SettingsService.cs, FaceCardArtService.cs, StatsService.cs
  ViewModels/   GameViewModel.cs, BeecellViewModel.cs, SpiderViewModel.cs, AppCoordinator.cs
SoliBee.Desktop/
  Views/        CardView, GameView, MainWindow, PreferencesView, BeecellView, SpiderView, …
  Assets/       Images, WAV files (chocobo.png, tonberry.png, moogle.png, J/Q/K PNGs, …)
  Properties/PublishProfiles/win-x64.pubxml
```

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

## Face card art system (8-slot custom art)
- **`FaceCardSlot` enum**: BlackAce, RedAce, BlackJack, RedJack, BlackQueen, RedQueen, BlackKing, RedKing
- **`FaceCardArtService`** (static singleton, `_loaded` flag): loads art config from JSON; `GetArt(slot)` returns `CustomFaceArt?`
- **`CustomFaceArt`**: `RelativePath` (filename in art dir), `Scale`, `OffsetX`, `OffsetY`, `IsEnabled`
- **`_customBitmapCache`** (static dict in `CardView`): cleared by `CardView.InvalidateFaceArtCache()`; populated lazily by `GetCachedFaceArtBitmap(path)`

## Pointer / async gotcha
`PointerPressed` + `async void` + `ShowDialog` leaves implicit pointer capture on the element. Always call `e.Pointer.Capture(null)` before awaiting, and guard with an `_isOpen` bool field to prevent re-entry. See `PreferencesView.axaml.cs` → `CardBackPreview_Click` for the pattern.

## Options page previews
The tile previews in `FaceCardArtSectionView` are 60 × 85 scaled-down card thumbnails. The center art image in each tile is 29 × 25 with `ClipToBounds=true` on the container. **Do not apply Scale/Offset transforms in the tile preview** — even the user's own offset values will push art outside the tiny ClipToBounds area.
