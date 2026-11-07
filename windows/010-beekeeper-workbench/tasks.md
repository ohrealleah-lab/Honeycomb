# Tasks: Beekeeper stage 2 (Windows)

Push only when Leah says "push". Placeholder numbers are fine (tuning comes later).

## Phase 1: Rules
- [x] T101 Config: every new number and the upgrade list (placeholders marked).
- [x] T102 State v2: new fields; approaching wasp not saved; log entries get a second value.
- [x] T103 Engine: crafting, Hippies, sage, repellent unlock, upgrades (storage, wax, burn effects).
- [x] T104 Engine: wasp time, arrival, countdown, raid, throw, bribe, light a candle, wasp leaves.
- [x] T105 Engine: open The Workbench on load for old saves with 2+ combs.
- [x] T106 Engine tests: one per acceptance scenario that the engine owns.

## Phase 2: Saving
- [x] T110 Save version 2; sanity checks; a version 1 file loads with nothing lost (test).

## Phase 3: View model
- [x] T120 Commands, `IsWatched`, `NoteActivity()`, wasp-time rules (on screen, active, No Stress Mode, sleep gaps).
- [x] T121 View-model tests: wasp only while watched and active, leaves when not, No Stress Mode, away time never brings wasps.

## Phase 4: Screen and words
- [x] T130 Hive rows: beeswax candles, repellent candles, sage.
- [x] T131 The Workbench card; the Hippies card.
- [x] T132 Shop: upgrade rows with mixed costs; bought ones disappear.
- [x] T133 Wasp card: countdown, Throw a shoe, Bribe with honey, Light a candle; burn time left.
- [x] T134 The screen reports on-screen and activity to the view model.
- [x] T135 Words in the workbook (English + Spanish draft), generator, Help page section.
- [x] T136 Debug menu: Call a wasp.
- **Hand-test (Leah):** steps come with the build.

## Phase 5: Check
- [ ] T140 Full test run; build; hand-test steps for Leah.
