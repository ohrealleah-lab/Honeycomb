# Tasks: Beekeeper (Windows first)

Each phase ends with a hand-test you can follow.
Nothing is committed until you say so; nothing is pushed unless you say "push".

## Phase 1: Rules engine (no screens yet)
- [x] T001 `BeekeeperConfig.cs`: all tuning numbers in one place, placeholders marked.
- [x] T002 `BeekeeperState.cs`: saved data, with a version number and saved-at time.
- [x] T003 `BeekeeperEngine.cs`: Catch (tool, sting, no cap), Advance (honey into storage, wax progress), SellTen, SellAll.
- [x] T004 `BeekeeperEngine.cs`: BuyTool (in order), BuyWaxCatcher, BuildComb (cost 50 × 1.25^N rounded down, +storage), reveal rules, `AdvanceAway`.
- [x] T005 `BeekeeperEngineTests.cs`: one test per acceptance scenario in the spec (sting only with bare hands, million-bee catch, storage clamp 199.5 → 200, Sell All 47 → 4 Beebits and 7 left, comb costs 50/62/78/97/122, wax unchanged by selling, Wax-Catcher mid-game, away 2 h = 7,200 honey, away 10 days cut to 3, storage full 1 h into an away period, **live ticking and `AdvanceAway` agree over the same span**).
- [x] T006 Simulation script for the first hour at 1, 3 and 5 clicks a second: when the Bear, Gloves, Net, Vacuum, first comb and storage-full moments arrive. Propose tuned placeholders to Leah before they go in the config.
- **Hand-test:** none needed. `dotnet test` from `windows/` passes. Leah reviews the T006 numbers.

## Phase 2: Saving
- [x] T010 `BeekeeperSaveService.cs` using `AtomicFile`.
- [x] T011 `BeekeeperSaveTests.cs`: round trip, corrupt file → new game, newer version number → safe fallback, saved-at time in the future → nothing credited.
- **Hand-test:** none yet (covered in Phase 4).

## Phase 3: View model and wiring
- [x] T020 `AppCoordinator.cs`: own `BeekeeperViewModel`, add `SwitchToBeekeeper()`, last-mode "Beekeeper"; audit every mode check in `AppCoordinator` and `MainWindow` so Beekeeper is handled on purpose.
- [x] T021 Make sure Undo, Hint, Restart, Statistics, Reset Statistics and the idle nudge are off for Beekeeper.
- [x] T022 `BeekeeperViewModel.cs`: 1-second timer; gaps over 2 s credited as time away (cut to 3 days, negative ignored); commands, popup text, story log stored as event keys + values (newest first, capped at 50), reveal flags, New Game (asks only when there are bees).
- [x] T023 Autosave every 5 s with the saved-at time; save on window close and New Game; welcome-back log line on launch.
- [x] T024 `BeekeeperViewModelTests.cs` + `BeekeeperCoordinatorTests.cs`: log lines, popups, confirm-then-reset (and no confirm on an empty hive), autosave trigger, away credit through the view model with a fake clock, the hive still ticking after the coordinator switches to another game (FR-005).
- [x] T025 `NumberFormatter.cs` and `NumberFormatterTests.cs`: 999, 1,000 → 1K, 1.2M, 3.4B…, English and Spanish number styles, huge values.
- **Hand-test:** none yet (no screen).

## Phase 4: The screen
- [x] T030 `BeekeeperView.axaml`: 3 columns (340 / fluid / 260), glass cards, tokens and fonts from the design. Art frame slot 170×102.
- [x] T031 Catch Bee button: 64px, popup text, coral sting popup with ±3px nudge. "Combs are full" state on the Hive card.
- [x] T032 Hive card: honey per second, honey storage, "Next wax: n/50", progress bar. Tool line.
- [x] T033 Bear panel, Shop panel, Combs panel (cost, "+200 honey storage", next cost) with the states in the mockups.
- [x] T034 Story log column with fading older lines.
- [x] T035 Stats bar (BEES · HONEY "45 / 200" · WAX · BEEBITS) and sticky reveal.
- [x] T036 `MainWindow`: 7th picker entry, toolbar = New Game + Options only, `SetupBeekeeperMode()`; follow the MainWindow audit table in plan.md (includes per-game window size settings).
- [x] T037 Themes: check every built-in theme. Passed (Leah, 2026-11-07).
- **Hand-test (Leah):** done and passed 2026-11-07.
  1. Open Honeycomb, pick **Beekeeper** from the game list. You should see only the art frame, Catch Bee, the tool line, the log and **BEES 0**.
  2. Click Catch Bee about 10 times. Some clicks should sting (coral text, no bee). The Hive card and HONEY appear after your first bee.
  3. Keep going until HONEY reaches 10. The Bear panel appears.
  4. Press Sell 10. BEEBITS appears.
  5. Switch to Klondike, wait a minute, switch back. Honey should have gone up.
  6. Close and reopen the app. Everything is as you left it.
  7. Close the app for 5 minutes, reopen. The log says how much honey the bees made while you were away.
  8. Keep the app open and let honey reach its storage limit. Honey stops at the limit and the log says the combs are full once.

## Phase 5: Words
- [x] T040 Add the Beekeeper strings and the approved story-log lines (English) to the localization workbook.
- [ ] T041 Spanish translations (Claude drafts, Leah reviews). Drafted 2026-11-07; waiting for Leah's review.
- [x] T042 Run `python3 tools/generate_localization.py` and review the diff on all platforms.
- [x] T043 Check Spanish in the screen for cut-off text. Passed (Leah, 2026-11-07).
- [x] T044 Help window: short "How to play Beekeeper".
- [x] T045 Scan every Beekeeper string, English and Spanish, for betting or gambling words (FR-009).
- [x] T046 Check that changing language mid-game re-translates the whole story log. Passed (Leah, 2026-11-07).
- **Hand-test (Leah):** done and passed 2026-11-07. Switch language to Spanish in Options; every Beekeeper word should be Spanish, big numbers follow Spanish style, and nothing is cut off.

## Phase 6: Whole-game check
- [x] T050 Run `/analyze` across spec, plan and tasks again against the finished code. Done 2026-11-07; open points below.
- [ ] T051 Play through to a second comb, using the debug route if one is needed to skip ahead (ask first).
- [x] T052 Hand-test sheet for the co-designer (Windows build). See `HAND_TEST.md`.
- [x] T053 Update `windows/CLAUDE.md` ("all six games" → seven), the repo README, and the product rules in `mac/CLAUDE.md` (exceptions: Beekeeper saves in progress on desktop and earns while away; Beekeeper's rules are Windows-referenced until Mac exists).
- [ ] T054 Windows release build (`dotnet publish`) and a smoke test. Release build made 2026-11-07 (`bin/Release/net10.0/win-x64/publish/Honeycomb.exe`); smoke test is Leah's.
- [ ] T055 Bring the design and Gemini files in line with v3: `UI_SPEC.md` (no bee capacity, honey storage, Combs panel text, bear names, Workshop hidden in this build, "Chronicle"/"Log" naming), the mockups (a small refresh), `README.md`, `csv/`, and the workbook. Ask Leah before editing Gemini's files.
- **Hand-test (Leah / co-designer):** play for 15 minutes; report anything confusing or unfair.

### T050 open points (waiting for Leah)
1. **Fixed 2026-11-07** (the log now compares every shown line). **Bug:** once the story log holds 50 lines, a line identical to the newest one (e.g. pressing Sell 10 twice) doesn't redraw the log, so the new line doesn't appear. Cause: `BeekeeperView.UpdateLog` only compares the line count and the newest line.
2. The Combs card shows the cost of the comb you can build now, not "next cost" as T033 lists. The current cost is probably what's wanted; T033's wording may just be loose.
3. The "Start over?" message says "Your hive and everything in it will be lost."; spec 5.8 says "Your hive will be lost."
4. The spec writes shop prices with "₿"; the screen says "beebits" (Leah: keep Beebits, no ₿). Fix the spec in T055.

## Later (own specs, not now)
See `Beekeeper/LONG_TERM_DESIGN.md`: Smoker and tool upgrades · hive roles · special bees and sites · wasps (steal honey) · candles + Workshop · reputations · seasons/blooms · swarming · Mac, iOS, Android.
