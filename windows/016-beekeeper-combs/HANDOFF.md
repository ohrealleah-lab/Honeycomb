# Beekeeper stage 7.5: handoff to a build session

**Where we are (2026-11-09):** stages 1–7 are built and committed (stage 7: `8d36f82`). A planning session settled stage 7.5, **combs, bees as currency**: bees pay for combs, each comb makes a flat rate of honey, free bees make the wax, honey and wax each have a cap, and the wax cap is small on purpose so that prices above it are walls. Capacity upgrades repeat; Technologies are one-time % boosts on both caps. The bear's auto-sale is cut for a better selling rate at 25 trades. Save version 8; older saves start a new game. Every decision is Bee's (earlier docs call Bee "Leah"); every number is a placeholder in `BeekeeperConfig`.

**Getting stuck is intended.** Do not add a rule that keeps caps above prices, and don't raise a cap or lower a price because a test or a hand-run gets stuck.

## Read first
1. `windows/016-beekeeper-combs/spec.md`: what to build, including every number, the wording, the tests and the simulator's findings.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Update: Combs, bees as currency" and the build roadmap.
3. `Beekeeper/EARLY_LOOP_RULES.md` (v3): "From stage 7.5" is the new rule, "Replaced" is the one in the code today.
4. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits). They all still apply, with one change: since the comment-out rule wins, cut words stay in the workbook.
5. `windows/015-beekeeper-seeds/HANDOFF.md` for how the last stage split `Work` and its boosts.
6. `windows/CLAUDE.md` for build and test commands.

## Where the code is
`BeekeeperConfig.cs` (numbers, `Upgrades`), `BeekeeperState.cs` (save version 7 → 8; `Combs` defaults to 1), `BeekeeperEngine.cs` (`HoneyStorage`, `StorageMultiplier`, `HoneyPerSecond`, `HiveMultiplier`, `HoneyPerSecondNow`, `WaxPerSecondNow`, `WaxPerBatch`, `CombCost`, `BeesPerCatch`, `CanSell`/`Sell`, `OfferAgreementIfDue`, `AgreementBeebitsPerSecondNow`, `Advance`, `AdvanceAway`, `AwayStretch`, `Work`, `Produce`, `Made`, `BuildComb`, `OpenWorkbenchIfDue`, `IsUnlocked`, `CheckReveals`, `RefreshStorageFlag`, `Raid`, the debug methods), `BeekeeperSaveService.cs` (`CurrentVersion`, `Load`, `LooksSane`), `BeekeeperViewModel.cs` (Hive card groups, the bear's row with `Config.HoneyPerBeebit`, `CanBuildComb`, `NewGameNeedsConfirmation`, debug), `BeekeeperView.axaml(.cs)` (Workbench's comb row, the agreement line), `BeekeeperText.cs` (`Price`, `CombBlurb`, `LogLine`, upgrade blurbs), `HelpWindow`, `MainWindow` (debug: Banners → Beekeeper), `tools/Honeycomb_Localization.xlsx` and `tools/generate_localization.py`, tests in `windows/tests/SoliBee.Tests/`, and `Beekeeper/tools/simulate_first_hour.py` (its `CFG` uses the config's names).

## Comment out, don't delete (Bee's rule)
Cut code stays, commented out with `// Cut in stage 7.5 (spec 016): …`. FR-716 is the full list. `HasTradeAgreement` stays and changes meaning.

## The tricky parts
- **`State.Bees` can be 0 in a running game.** Anything that used it to mean "the game has started" is now wrong: honey production, `NewGameNeedsConfirmation`, the welcome-back. Use the single property from FR-703 over the sticky `HoneyRevealed`. Search for `State.Bees` once more at the end.
- **The starter comb is off by one in two places.** `CombCost` counts combs bought, not combs held, and both caps add room for combs bought. The first comb must cost 20 bees and 10 wax, and a new game must have a honey cap of 200 and a wax cap of 20.
- **`Produce`.** The queen's triangle is unchanged: it now feeds wax instead of honey. Honey becomes flat and has its own "before the first bee" case. The early return for no bee-seconds has to go, or the drip stops and `CheckReveals` is skipped with no bees. `boost` and `SagePropolisBoostNow` touch honey only. Today `WaxPerSecondNow` reads `HoneyPerSecondNow`, so calm leaks into wax if it isn't rewritten.
- **Stored amounts must not feed the rates.** They don't today. Keep it so and `min(made, room)` needs no splitting at the moment a cap is reached.
- **Whole-number wax is gone.** Prices compare fractional wax, the first-wax event fires at 1 whole wax, and the screen floors it.
- **Reveal words.** The Combs panel comes at 5 wax, before a comb can be paid for, so the old "wax enough for a new comb" is untrue.
- **The rate of the moment.** Every place that read `Config.HoneyPerBeebit` for selling reads the current rate, including the bear's row in the view model and the sale event's honey amount. `BearRevealHoney` stays 10.
- **A wall is not "can't afford".** Keep the two states separate in the view model; the view only reads them.
- **Tests that set bees to get honey** are most of the churn. Add a "started hive with N combs" helper first.

## Order of work
Engine (config, state, starter comb, honey, wax and the queen's maths, caps, comb price and purchase, capacity upgrades, Technologies on both caps, the bear's rate, walls, zero-bee checks, save version 8, comment-outs) → tests for the engine → view model (Hive rows, wall state, Workbench rows, bear's row, debug commands) → screen and words (workbook + generator, Help) → the remaining tests (quick filter while working, full suite once before the final commit).

## Working with Bee
- Be really nice; Bee goes by Bee, and no character voice.
- Bee tests by eye; finish with the spec's hand-test steps, adjusted to what was actually built.
- Before starting any change, recommend a model and effort (and whether a new session is better) and wait for Bee's OK. Don't launch or drive the app yourself: build to confirm it compiles, then let Bee test.
- Build systems first with placeholders. Flag real rule conflicts; don't stop for tuning questions.
- Ignore the intermittent Honeycomb card-game test failures.
- Remind Bee to start a fresh session at the end of the stage.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 7.5 (combs, bees as currency) in the Honeycomb monorepo, Windows only. My name is Bee; please be really nice to me.

Read first:
1. windows/016-beekeeper-combs/HANDOFF.md (this handoff: the tricky parts, order of work, how we work)
2. windows/016-beekeeper-combs/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Update: Combs, bees as currency" and the build roadmap
4. Beekeeper/EARLY_LOOP_RULES.md
5. windows/012-beekeeper-garden/HANDOFF.md, "How things are done here" (conventions that still apply)
6. windows/CLAUDE.md

Before any file changes, recommend a model and effort and wait for my OK.

Build in this order: engine, engine tests, view model, screen and words, remaining tests. Keep every number in BeekeeperConfig. Comment out anything that is cut instead of deleting it. Live play and time away must agree with the queen raising free bees, the pantry running out, plants sprouting, a candle burning out and both caps being reached part-way. Save version goes to 8; any older save just starts a new game.

Getting stuck is intended: never add a rule that keeps caps above prices. A price above a cap must read as "needs more storage", not as a bug.

Do not build anything listed for stage 8 or later (buying the meadow or honey house, bottles of honey, paper labels, meadow plants, batch comb building, blooms, new buyers), and don't retune the old prices listed in the spec.

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
