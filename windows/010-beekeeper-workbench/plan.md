# Implementation Plan: Beekeeper stage 2 (The Workbench, candles, Hippies, wasps)

**Spec**: `spec.md` (v3) in this folder | **Builds on**: `windows/009-beekeeper/plan.md`
**Stack**: unchanged (Avalonia 12 / .NET 10, `CommunityToolkit.Mvvm`, xUnit).

## Approach in one paragraph
Everything new is a rule, so it goes in the engine, with every number in `BeekeeperConfig` (placeholders, tuned later). The engine still has no clock: the view model tells it how many seconds of "wasp time" passed. Wasp time only counts while Beekeeper is on screen, the player has clicked or pressed a key in the last 5 minutes, and No Stress Mode is off; away time never counts. The screen reports the two things only it knows (on screen, and player activity) to the view model. Upgrades are a list in the config, so the Shop draws them without code for each one.

## Changes by file

**Core**
| File | Change |
|---|---|
| `Models/BeekeeperConfig.cs` | Candle costs, Hippie rate and trigger, Workbench comb count, wasp interval (4–8 min), countdown (60 s), hit chance (60%), raid size (3 min honey, 15% bees), bribe share (25%), burn time (15 min), idle limit (5 min), and the upgrade list (`BeekeeperUpgrade`: id, Beebits, wax, sage, what it needs). |
| `Models/BeekeeperState.cs` | Version 2. Beeswax and repellent candles, candles crafted, sage, Hippie trades, reveals (Workbench, Hippies, sage, repellent), upgrades owned, burn time left, seconds until the next wasp. The approaching wasp is not saved (`[JsonIgnore]`). Log entries get a second value (raids report honey and bees). |
| `Models/BeekeeperEngine.cs` | `CraftBeeswax`, `CraftRepellent`, `TradeTenCandles`, `TradeAllCandles`, `BuyUpgrade(id)`, `LightRepellent`, `ThrowShoe`, `Bribe`, `AdvanceWaspTime(s)` (burns candle time or brings the next wasp), `AdvanceWaspCountdown(s)` (raid at zero), `WaspLeaves()`, `RevealOnLoad()` (opens the Workbench for old saves with 2+ combs). `HoneyStorage` and wax per batch read the upgrades. |
| `Services/BeekeeperSaveService.cs` | `CurrentVersion = 2`; sanity checks for the new amounts. Version 1 files load as they are (new fields default to zero). |
| `ViewModels/BeekeeperViewModel.cs` | New commands; `IsWatched` and `NoteActivity()`; each tick decides what counts as wasp time; a gap over 2 s (sleep) sends an approaching wasp away and never counts as wasp time; debug "call a wasp". |

**Desktop**
| File | Change |
|---|---|
| `Views/BeekeeperView.axaml(.cs)` | Hive rows for candles and sage; The Workbench and Hippies cards in the centre column; upgrade rows in the Shop (bought ones disappear); a Wasp card above the story log (countdown, Throw a shoe, Bribe, Light a candle, burn time left). Reports on-screen and activity to the view model. |
| `Views/BeekeeperText.cs` | The new words. |
| `Views/HelpWindow.*` | A "Workbench & Wasps" part in the Beekeeper section. |
| `Views/MainWindow.*` | Debug menu: "Call a wasp". |

**Words**: new rows in `tools/Honeycomb_Localization.xlsx` (English + Spanish draft), then the generator.

## Decisions worth knowing
1. **Wasp time vs real time.** The next-wasp timer and candle burn time run only on wasp time. An approaching wasp's 1-minute countdown runs on real time while the player is watching; if they leave Beekeeper, go idle, or the computer sleeps, the wasp leaves without raiding.
2. **No Stress Mode** stops wasp time (no new wasps, candle paused) but an approaching wasp still plays out, as the spec says.
3. **Raids and bribes** are worked out from the hive at that moment: raid honey = min(stored, honey per second × 180); bees = floor(15%); bribe = floor(25% of honey), at least 1.
4. **Upgrade effects** are looked up by id in the engine (storage ×1.5 / ×2, wax per batch ×1.5, burn ×1.5). Adding an upgrade with a new kind of effect needs one engine line; the Shop needs none.
5. **The Shop card** shows once the Shop or The Workbench is revealed, so upgrades are never invisible.

## Risks
| Risk | Handling |
|---|---|
| Old saves | Test that a version 1 file loads, keeps everything, and opens The Workbench with 2+ combs. |
| Wasps firing while the player can't respond | Engine only moves on wasp time; view-model tests cover off-screen, idle, No Stress Mode and sleep gaps. |
| Shop buttons rebuilt under the mouse each tick | Same signature trick as now, extended with the upgrade set. |
