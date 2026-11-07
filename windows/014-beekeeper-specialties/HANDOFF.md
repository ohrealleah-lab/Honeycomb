# Beekeeper stage 6: handoff to a build session

**Where we are (2026-11-07):** stages 1–5 are built and committed (stage 5: `d690603`). A planning session settled stage 6: plants give the hive **specialties** instead of counts of forager and guard bees; the Hive card is **grouped**; raids take **only honey**; the **wasp emissary** comes after 5 bribes in total, ends raids for good and opens a **paper-for-honey** trade; repellent candles retire after the emissary; **No Stress Mode no longer applies to Beekeeper**. Every decision is Leah's; every number is a placeholder in `BeekeeperConfig`.

## Read first
1. `windows/014-beekeeper-specialties/spec.md`: what to build.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Build roadmap" and "Decisions made": the why, and what is left for stage 7 (more seeds, several plants, nursing, the poplar, propolis, uses for paper).
3. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits). They all still apply.
4. `windows/CLAUDE.md` for build and test commands.

## Where the code is
`BeekeeperConfig.cs` (plants, `BeekeeperBees`), `BeekeeperState.cs` (save version 5 → 6), `BeekeeperEngine.cs` (`GrowGarden`/`Attract`, `HiveMultiplier`, `Raid`, `Bribe`, `AdvanceWaspTime`, `HasGuards`), `BeekeeperSaveService.cs`, `BeekeeperViewModel.cs` (the `_noStressMode` check before `AdvanceWaspTime`), `BeekeeperView.axaml(.cs)` (the Hive card's ~15 named rows, the Trading card's `TradeRows`), `BeekeeperText.cs`, `HelpWindow` (the Beekeeper Workbench paragraph mentions No Stress Mode), `MainWindow` (debug menu: Banners → Beekeeper), tests in `windows/tests/SoliBee.Tests/`.

## Comment out, don't delete (Leah's rule)
Everything this stage cuts stays in the code, commented out with a short `// Cut in stage 6 (spec 014): …` note, so it can come back: the forager and guard counts and their growth, `HasGuards` and the bees-fly-off part of a raid, the No Stress Mode check in the Beekeeper view model, the old plant fields (`Bee`, `BeesPerMinute`), the old raid and sprout log lines. Saved fields that old files still contain (`ForagerBees`, `GuardBees`) stay as properties so the files load; mark them obsolete in a comment. Repellent candles are retired by **hiding** after the emissary; their stock stays in the save.

## The tricky parts
- **Pollen gets simpler:** today it's the area under a growing forager line. Now it is `rate × seconds`, where the rate is the sum of the foraging plants' pollen per minute. Keep the split at the moment a seed sprouts.
- **Guarding goes into the honey multiplier.** Put it with `HiveMultiplier` so everything that reads honey per second (`Produce`, the queen's growing-hive formula from stage 5, the raid size, the hover rates, the trade agreement's overflow) picks it up without separate code. Extend the live-vs-away equality test with foraging, guarding and a laying queen.
- **The Hive card becomes a list of groups.** Today each row is named in the markup. Replace them with groups of rows built in the view model (label, value, visible, optional hover text) and drawn by the screen, so later stages add one entry. Keep the title at the top and the move-hive row at the bottom. Keep every existing hover rate working. This is the biggest piece of screen work in the stage: do it after the engine and view model are done.
- **The emissary is a one-way switch.** After it, the wasp timer never runs, `DebugCallWasp` does nothing, any approaching wasp ends, and the Wasp card never shows, whatever No Stress Mode says.
- **Old saves:** derive specialties from the saved plant list; show the "settle into the hive's daily work" line once if either old count was above zero; bribes start at 0.

## Order of work
Engine (specialties, pollen, guarding multiplier, honey-only raids, bribe count, emissary, wasp trade and paper, repellent retired, save version 6 with sanity checks) → view model (grouped Hive rows, the Wasps on the Trading card, No Stress check commented out, debug commands) → screen and words (grouped Hive card, Garden card text, workbook + generator, Help) → tests (engine + view model; quick filter while working, full suite once before the final commit).

## Working with Leah
- She tests by eye; finish with the spec's hand-test steps, adjusted to what was actually built.
- Before starting, recommend a model and effort and wait for her OK. Don't launch or drive the app yourself: build to confirm it compiles, then let her test.
- Flag real rule conflicts; don't stop for tuning questions.
- Ignore the intermittent Honeycomb card-game test failures.
- Remind her to start a fresh session at the end of the stage.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 6 (specialties and the wasp emissary) in the Honeycomb monorepo, Windows only.

Read first:
1. windows/014-beekeeper-specialties/HANDOFF.md (this handoff: the tricky parts, order of work, how we work)
2. windows/014-beekeeper-specialties/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Build roadmap" and "Decisions made"
4. windows/012-beekeeper-garden/HANDOFF.md, "How things are done here" (conventions that still apply)
5. windows/CLAUDE.md

Build in this order: engine, view model, screen and words, tests. Keep every number in BeekeeperConfig. Comment out anything that is cut instead of deleting it. Live play and time away must agree with foraging, guarding and a laying queen. Save version goes to 6; older saves load with nothing lost that matters.

Do not build anything listed for stage 7 or later (more seeds, several plants at once, nursing, the poplar, propolis, uses for paper).

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
