# Beekeeper stage 7: handoff to a build session

**Where we are (2026-11-07):** stages 1–6 are built and committed (stage 6: `2d63047`). A planning session settled stage 7: seeds get **names**; the garden has **two beds** (a third from the Shop); three new seeds, each slower: the **willow** (1 h, **nursing**: the queen lays faster), the **poplar** (6 h, **resin**: **propolis**; its seed comes from the **wasps**) and **clover** (12 h, more foraging); the **bee-boost candle** (live-only boost) and the **sage-propolis candle** (slow boost that burns while away); paper buys the **Beekeeper's Notebook**, which brings back the **Bees card**; the **Third Bed** and **Propolis Seal** upgrades. Every decision is Leah's; every number is a placeholder in `BeekeeperConfig`.

## Read first
1. `windows/015-beekeeper-seeds/spec.md`: what to build.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Build roadmap" and "Decisions made".
3. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits). They all still apply.
4. `windows/014-beekeeper-specialties/HANDOFF.md`: how stage 6 was shaped (specialties, grouped Hive card, "comment out, don't delete").
5. `windows/CLAUDE.md` for build and test commands.

## Where the code is
`BeekeeperConfig.cs` (`BeekeeperPlant`, `Plants`, `GrowSeconds`, `BeekeeperSpecialties`, `BeekeeperUpgrade`, `Upgrades`), `BeekeeperState.cs` (save version 6 → 7; `Seeds`, `SeedsPlanted`, `SeedsGiven`, `GrowSecondsLeft`), `BeekeeperEngine.cs` (`Work`, `Produce`, `GrowGarden`, `Attract`, `GiveSeedIfDue`, `PlantSeed`, `IsGrowing`/`GrowingPlant`, `QueenRatePerMinute`/`LayingBeesPerMinute`, `HiveMultiplier`, `HoneyStorage`, `Advance` and its calm split, `AdvanceAway` and the welcome-back lines, `TradeForPaper`, `BuyUpgrade`/`CanBuyUpgrade`, crafting), `BeekeeperSaveService.cs`, `BeekeeperViewModel.cs` (Hive card groups, Garden card, Workbench, Shop, debug), `BeekeeperView.axaml(.cs)`, `BeekeeperText.cs`, `HelpWindow`, `MainWindow` (debug menu: Banners → Beekeeper), tests in `windows/tests/SoliBee.Tests/`. The old Bees card is in commit `f196a8a` (`git show f196a8a -- windows/src/SoliBee.Desktop/Views/BeekeeperView.axaml`, plus its view model and words).

## Comment out, don't delete (Leah's rule)
Cut code stays, commented out with `// Cut in stage 7 (spec 015): …`: the "Nth seed is the Nth plant" rule in `GiveSeedIfDue`/`PlantSeed`/`GrowingPlant`, the single `GrowSeconds`, the unnamed seed log lines. Old saved fields (`Seeds`, `SeedsPlanted`, `SeedsGiven`, `GrowSecondsLeft`) stay as properties so files load; mark them obsolete in a comment.

## The tricky parts
- **Splitting `Work` at every change.** Today it splits once, at the one sprout. Now: loop — find the soonest event among all growing beds and the sage-propolis candle burning out, `Produce` + garden up to it, apply it (sprout → plant joins the garden, bed frees; candle out → boost ends, event), repeat. Ties in the same instant are fine in any order. Keep each piece exact so live and away agree; extend the equality test (FR-606).
- **Two boosts, two paths.** The bee-boost is live-only, like calm: `Advance` already splits at calm ending; make it split at whichever of calm / bee-boost ends first, pass the product of active live boosts into `Work`. The sage-propolis candle belongs in the multiplier used by `Produce` in both paths and burns down inside `Work`'s loop. `HoneyPerSecondNow` and the hover rates should include whichever boosts are on.
- **Nursing** multiplies the queen's rate; the pantry maths in `Produce` already uses `perMinute`, so putting it into `QueenRatePerMinute` covers the brood, bee bread use and the welcome-back.
- **Named seeds and old saves.** Old order was plant N = seed N, so on load: the sprouted plants are already in `State.Plants`; if `GrowSecondsLeft > 0`, the last planted (`Plants[SeedsPlanted - 1]`) goes into bed 1 with its time left; `[SeedsPlanted, SeedsGiven)` → seeds in hand; `[0, SeedsGiven)` → seeds given. Then run the seed-giving check so old saves past the new trade counts receive the willow/clover/poplar seeds, with log lines.
- **Seed giving from two sources.** Check the Hippies' plants after a Hippie trade and the wasps' plants after a wasp trade (and on load). Each plant given once (by id).
- **The Bees card** comes back from `f196a8a` but its content is new (specialty notes, queen note), shown only after the Notebook. Build it as a list in the view model like the grouped Hive card.
- **Shop prices** gain paper and propolis with defaults of 0, so existing upgrade entries don't change.

## Order of work
Engine (plant data, named seeds, beds and the split loop, nursing, resin and propolis, clover, seed giving from both sources, the two candles and boosts, upgrade prices and the three upgrades, save version 7 with old-save conversion and sanity checks) → view model (Garden card beds and seed list, Hive rows for nursing/resin/propolis/burning candles, Workbench recipes and light buttons, Shop prices, Bees card list, debug commands) → screen and words (Garden card, Bees card from `f196a8a`, workbook + generator, Help) → tests (engine + view model; quick filter while working, full suite once before the final commit).

## Working with Leah
- She tests by eye; finish with the spec's hand-test steps, adjusted to what was actually built.
- Before starting, recommend a model and effort and wait for her OK. Don't launch or drive the app yourself: build to confirm it compiles, then let her test.
- Flag real rule conflicts; don't stop for tuning questions.
- Ignore the intermittent Honeycomb card-game test failures.
- Remind her to start a fresh session at the end of the stage.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 7 (more seeds, the poplar and propolis) in the Honeycomb monorepo, Windows only.

Read first:
1. windows/015-beekeeper-seeds/HANDOFF.md (this handoff: the tricky parts, order of work, how we work)
2. windows/015-beekeeper-seeds/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Build roadmap" and "Decisions made"
4. windows/012-beekeeper-garden/HANDOFF.md, "How things are done here" (conventions that still apply)
5. windows/CLAUDE.md

Build in this order: engine, view model, screen and words, tests. Keep every number in BeekeeperConfig. Comment out anything that is cut instead of deleting it. Live play and time away must agree with two beds, nursing, resin, clover and a sage-propolis candle burning out part-way; the bee-boost candle is live-only. Save version goes to 7; older saves load with nothing lost that matters.

Do not build anything listed for stage 8 or later (the meadow, the honey house, paper labels, batch comb building, blooms, new buyers).

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
