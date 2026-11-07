# Beekeeper stage 5: handoff to a build session (DONE: stage 5 built in `d690603`; kept for reference)

**Where we are (2026-11-07):** stages 1–4 are built and hand-tested. A planning session found that time away barely grows anything (honeybees only come from clicking), so stage 5 adds the queen: bee bread feeds her and she raises honeybees, live and away. It also caps the slice and adds the bear's trade agreement. Every decision is Leah's; every number is a placeholder in `BeekeeperConfig`.

## Read first
1. `windows/013-beekeeper-brood/spec.md`: what to build.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Build roadmap" and "Decisions made": the why, and what is deliberately left for stage 6 (nurse bees, more seeds, the emissary, No Stress Mode).
3. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits). They all still apply.
4. `windows/CLAUDE.md` for build and test commands.

## Where the code is
Same files as stage 4: `BeekeeperConfig.cs`, `BeekeeperState.cs` (save version 4 → 5), `BeekeeperEngine.cs`, `BeekeeperSaveService.cs`, `BeekeeperViewModel.cs`, `BeekeeperView.axaml(.cs)`, `BeekeeperText.cs`, `HelpWindow`, `MainWindow` (debug menu: Banners → Beekeeper), tests in `windows/tests/SoliBee.Tests/`.

## The hard part: a hive that grows during a stretch of time
- Today `Produce(seconds)` assumes the bee count stays the same over the stretch. With a laying queen, bees grow in a straight line, so honey made = `rate × (bees × t + layPerSecond × t² / 2)`. Pollen in `GrowGarden` already does this; follow it.
- Split each stretch at the moment the pantry runs out (`beeBread / (layPerSecond × beeBreadPerBee)`): growth before, flat after.
- `Advance` already splits the stretch into a calm part and a normal part; the calm part comes first, so the hive grows across both. Make sure the order is applied consistently.
- Storage: honey made beyond the room left is overflow. With the trade agreement it becomes Beebits at 20 honey each (fractions kept); without it, it is lost as today. Wax still follows all honey made.
- Keep live and away in agreement (FR-403): extend the existing equality test. Because each 1-second tick uses the exact formula, the sum of ticks equals one long stretch, to within rounding.

## Order of work
Engine (queen, pantry, slice cap, agreement, welcome-back events, save version 5 with sanity checks) → view model (Queen row, hover rates, agreement line, debug commands) → screen and words (workbook + generator, Help paragraph) → tests (engine + view model; quick filter while working, full suite once before the final commit).

## Working with Leah
- She tests by eye; finish with the spec's hand-test steps, adjusted to what was actually built.
- Before starting, recommend a model and effort and wait for her OK. Don't launch or drive the app yourself: build to confirm it compiles, then let her test.
- Flag real rule conflicts; don't stop for tuning questions.
- Remind her to start a fresh session at the end of the stage.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 5 (the queen, the brood and the trade agreement) in the Honeycomb monorepo, Windows only.

Read first:
1. windows/013-beekeeper-brood/HANDOFF.md (this handoff: the hard part, order of work, how we work)
2. windows/013-beekeeper-brood/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Build roadmap" and "Decisions made"
4. windows/012-beekeeper-garden/HANDOFF.md, "How things are done here" (conventions that still apply)
5. windows/CLAUDE.md

Build in this order: engine, view model, screen and words, tests. Keep every number in BeekeeperConfig. Live play and time away must agree, including a pantry that runs out partway. Save version goes to 5; older saves load with nothing lost.

Do not build anything listed for stage 6 or later (nurse bees, more seeds, the emissary, No Stress Mode changes).

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
