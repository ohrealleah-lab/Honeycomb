# Implementation Plan: Beekeeper (Windows first)

**Spec**: `spec.md` (v3) in this folder | **Design**: `Beekeeper/archive/UI_SPEC.md` + `mockup_*.html` (archived 2026-11-07; the built screen is now the reference) | **Future**: `Beekeeper/LONG_TERM_DESIGN.md`
**Stack**: Avalonia 12 / .NET 10, `CommunityToolkit.Mvvm`, xUnit. Same layout as the other six Windows games.

## Approach in one paragraph
Keep all rules in a plain engine class with no UI and no clock, so it can be unit-tested. A view model owns the engine, measures real time, runs a one-second timer, saves, and credits time away. The view only draws what the view model says. The app coordinator owns the Beekeeper view model, so it keeps ticking while the player is in another game.

## What gets added (new files)

**Core** (`src/SoliBee.Core/`)
| File | Job |
|---|---|
| `Models/BeekeeperConfig.cs` | Every tuning number in one place (FR-002), including the placeholders. |
| `Models/BeekeeperState.cs` | Everything that is saved: bees, honey, wax, wax progress, Beebits, tool level, Wax-Catcher, combs, trades, bear name, reveal flags, story log (as event keys + values), saved-at time. Has a `Version` number. |
| `Models/BeekeeperEngine.cs` | The rules: `Catch`, `Advance(seconds)`, `AdvanceAway(seconds)` (same maths in one step for long gaps), `SellTen`, `SellAll`, `BuyTool`, `BuyWaxCatcher`, `BuildComb`, plus "what is revealed". Takes an injected random source. Returns events (e.g. "Stung", "StorageFull", "ShopOpened"). |
| `Services/BeekeeperSaveService.cs` | Load and save JSON through `AtomicFile` into `AppPaths.DataDirectory`. A bad or missing file means a new game. |
| `Services/NumberFormatter.cs` | Short big-number text (1.2K, 3.4M), language-aware (FR-011). |
| `ViewModels/BeekeeperViewModel.cs` | Commands, the 1-second timer, away-time credit, autosave every 5 s, popups, the story log, the "Start over?" flow. |

**Desktop** (`src/SoliBee.Desktop/Views/`): `BeekeeperView.axaml(.cs)`, the 3-column layout.

**Tests** (`tests/SoliBee.Tests/`): `BeekeeperEngineTests.cs`, `BeekeeperSaveTests.cs`, `BeekeeperViewModelTests.cs`, `NumberFormatterTests.cs`.

**Tuning tool** (`Beekeeper/tools/simulate_first_hour.py` or similar, not shipped): a small script that plays the first hour at a chosen click speed and prints when each milestone arrives, so placeholder numbers are tuned from data (T006).

## What gets changed (existing files)
- `AppCoordinator.cs`: add `BeekeeperViewModel`, `SwitchToBeekeeper()`, and the `"Beekeeper"` case in last-mode loading. The Beekeeper timer is NOT paused on game switch.
- `MainWindow.axaml(.cs)`: 7th picker entry (`Tag="Beekeeper"`), toolbar shows only New Game and Options, status bar swaps to BEES · HONEY (with storage) · WAX · BEEBITS, `SetupBeekeeperMode()`. Save on window close.
- Localization: new keys in `tools/Honeycomb_Localization.xlsx`, then `python3 tools/generate_localization.py`.
- Themes: read the felt and accent from `ThemeService`; add nothing new.

## Decisions worth knowing
1. **Numbers are `decimal`.** Exact for 0.01 steps and big enough for the first stages (up to about 7.9 × 10^28). If the weeks-long game ever outgrows it, we switch the engine's number type in one place; the formatter already copes with huge values.
2. **Wax is driven by a counter of honey produced and stored**, so selling never costs wax progress, and buying the Wax-Catcher mid-game just changes what each 50 honey gives.
3. **Time away, one rule for everything.** The view model compares "now" with the last time it ran or saved. A gap over 2 seconds is "away": it is cut to 3 days (259,200 s), ignored if negative, and credited by `AdvanceAway` as one calculation (no loop over hundreds of thousands of steps). This covers closing the app, laptop sleep and a frozen window alike. Gaps under 2 seconds are normal ticks.
4. **Storage limits what away time earns.** Production stops when honey storage is full, in the live game and away alike. `AdvanceAway` works out the exact moment storage fills, and wax follows the honey actually stored.
5. **Autosave** every 5 seconds and on window close and on New Game; each save stores the time.
6. **Sting roll** happens only for Bare Hands.
7. **The Workshop, roles, Smoker, special bees** are not built, but the centre column leaves a gap for the Workshop and roles, and the right column for the wasp panel.
8. **Help window**: a short Beekeeper "How to play" page, so Help describes what the code does.
9. **Story log is stored as keys plus values** (for example `shop_opened`, `bear_arrives {name}`), turned into sentences only when shown, so changing language re-translates old lines.
10. **Statistics and Reset Statistics** menu entries are disabled for Beekeeper.

## Risks and how we handle them
| Risk | Handling |
|---|---|
| Many `switch`/`is` checks in `MainWindow` and the coordinator assume six games | Search every place that mentions the other game modes and add Beekeeper deliberately (T020). |
| Strings generator also writes Mac/iOS/Android files | Extra keys are harmless; check the diff before committing. |
| Idle-nudge, undo, stats plumbing doesn't apply | Checked in T021. |
| Spanish text longer than English; Spanish number style | Wrapping layout; formatter tests; hand-check (T043). |
| No bee limit makes early growth fast and prices wrong | Simulation first (T006), then play-test with the co-designer. All numbers in the config. |
| Clock tricks (setting the clock forward) give 3 days at most | Accepted for a single-player game; the 3-day cap is the limit. |
| Away calculation differs from live ticking | A test runs both routes over the same span and requires the same result (T005). |

## Questions for Leah (answered)
Help page yes · no Beekeeper options · no sound · desktop saving is a deliberate exception · New Game asks only with bees · story log re-translates · no bee limit, combs store honey · offline earnings capped at 3 days.
Offline rate: 100% (confirmed). Nothing left to confirm before Phase 1.

## Not in this plan
Mac, iOS, Android ports; everything listed as out of scope in the spec. See `LONG_TERM_DESIGN.md`.

## MainWindow audit (done in T020; edits happen in T036 with the screen)
`src/SoliBee.Desktop/Views/MainWindow.axaml(.cs)` mentions the games by name in many places. Each needs a deliberate Beekeeper decision (line numbers as of 2026-11-06):

| Where | What to decide for Beekeeper |
|---|---|
| `.axaml` ~line 33 | Add the 7th picker entry `Tag="Beekeeper"` (name is a proper noun, like Honeycomb). |
| `.cs` 95, 265, 1574–1589 | "Is this a card game?" checks: Beekeeper is not; hide Hint, Undo, Score, Moves; show only New Game + Options. Stats bar becomes BEES · HONEY · WAX · BEEBITS. |
| `.cs` 449–451, 510–531 | "Game in progress" and Undo/Hint routing: Beekeeper is never "in progress" in the quit-match sense. |
| `.cs` 629–642, 939–1022 | Statistics and Reset Statistics: disabled for Beekeeper (no stats in this build). |
| `.cs` 1107–1136 | Options: Beekeeper opens the shared Preferences (themes etc.), nothing of its own. |
| `.cs` 1351–1352 | Picker index map: add Beekeeper as index 6. |
| `.cs` 1473–1505 | Game switch: call `SwitchToBeekeeper()` and create `BeekeeperView` with `DataContext = _coordinator.BeekeeperViewModel`. |
| `.cs` 1871–1889, 1973–1974, 2006–2012 | Per-game window size memory and minimum size: needs new `BeekeeperWidth/Height/Maximized` settings and a minimum size (the 3 columns are 340 + fluid + 260 wide). |
| `.cs` 2181–2226 | Board-size and layout rules: Beekeeper is a wide 3-column screen, not a stacked or card board. |
| `.cs` 2304–2337 | New Game menu item: asks "Start over?" only when `NewGameNeedsConfirmation`. |
| `.cs` 150 | Already done: saving Beekeeper when the window closes. |

Already handled in `AppCoordinator` (T020, T021): Beekeeper is created on first open, remembered as the last game, never paused on a game switch, has no Undo, no statistics reset and no idle nudge.
