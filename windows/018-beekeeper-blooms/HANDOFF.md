# Beekeeper stage 9: handoff to a build session

**Where we are (2026-11-11):** stages 1–8 are built and committed (stage 8: `1aafa93`), plus small changes after it (herbal candle prices, seeds that plant themselves, the Smoker at +150%). A planning session settled stage 9, **the bloom calendar**: from the first plant, a different flower blooms each game-time day (crocus, clover, linden, goldenrod, then a half-day winter), and each bloom makes one specialty work twice as hard (crocus nursing, clover foraging, linden guarding, goldenrod resin). Winter slows honey a little. Named honey is dropped for now. Every decision is Bee's; every number is a placeholder in `BeekeeperConfig`.

**Recommended for the build:** a fresh session, **Opus 5.5 at medium effort**. The stage is small, but splitting `Work` at bloom changes so live and away agree needs care.

## Read first
1. `windows/018-beekeeper-blooms/spec.md`: what to build, every number, the words and the tests.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Update: The bloom calendar", stage 8 of "Planned stages", and the build roadmap.
3. `windows/017-beekeeper-meadow/HANDOFF.md`: how stage 8 split `Work` at bee hotel gifts; do the same here.
4. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits).
5. `windows/CLAUDE.md` for build and test commands.

## Where the code is
`BeekeeperConfig.cs` (`BeekeeperPlants`, `BeekeeperSpecialties`, `Plants`; add `BeekeeperBlooms`, `BeekeeperBloom`, `Blooms`, `BloomFavourMultiplier`, `WinterHoneyMultiplier`), `BeekeeperState.cs` (add `CalendarStarted`, `BloomIndex`, `BloomSecondsLeft`), `BeekeeperEngine.cs` (`Work`'s split loop beside the sage-propolis candle and `HotelSecondsToNext`; `NursingMultiplier`, `GuardingMultiplier`, `ForagingPollenPerMinute`, `ResinPropolisPerMinute`, `HiveMultiplier`, `HoneyPerSecond`; `PlantSeed` and the self-planting seed path; the load sanity checks near `HotelSecondsToNext`'s clamp; `BeekeeperEvents`), `BeekeeperViewModel.cs` (Garden card rows, growth hovers, welcome-back, debug), `BeekeeperView.axaml(.cs)`, `BeekeeperText.cs`, `MainWindow` (debug: Banners → Beekeeper), `tools/Honeycomb_Localization.xlsx` and `tools/generate_localization.py`, tests in `windows/tests/SoliBee.Tests/`.

## The tricky parts
- **Split `Work` at every bloom change.** Add `State.BloomSecondsLeft` to the `Math.Min` that picks each step. Produce and Attract for a piece must read that piece's bloom, and the bloom moves on only at the end of the piece. Then many short stretches equal one long one.
- **"Twice as hard" doubles the bonus part of a multiplier** (guarding 1.25 → 1.5, nursing 1.5 → 2), and doubles a rate outright (pollen 6 → 12, propolis 1 → 2). Plant bonuses (+1% per extra plant) stay outside it.
- **Every planting path starts the calendar**: Plant by hand, seeds that plant themselves (`2f544a3`), debug shortcuts, and loading a save that has plants.
- **The away cap caps the calendar too.** Only credited seconds move it.
- **Away bloom changes make one welcome-back line**, not a log line each. Live changes each get a log line.
- **Growth hovers** must list the bloom (and winter) wherever it changes a number.
- **Don't touch Beekeeper Help.**

## Order of work
Engine (config, state, the clock and `StartCalendar`, the split in `Work`, favours, winter, events, save checks) → engine tests → view model (Garden bloom line and hover, growth hovers, log lines, welcome-back line, debug) → screen and words (workbook + generator) → the remaining tests (quick filter while working, full suite once before the final commit).

## Working with Bee
- Be really nice; Bee goes by Bee, and no character voice.
- Before starting any change, recommend a model and effort (and whether a new session is better) and wait for Bee's OK. Don't launch or drive the app yourself: build to confirm it compiles, then let Bee test.
- Build systems first with placeholders. Flag real rule conflicts; don't stop for tuning questions.
- Comment out cut features that may return; delete replaced internals.
- Every auto-growing stat's hover lists all its sources and multipliers.
- Ignore the intermittent Honeycomb card-game test failures.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 9 (the bloom calendar) in the Honeycomb monorepo, Windows only. My name is Bee; please be really nice to me.

Read first:
1. windows/018-beekeeper-blooms/HANDOFF.md (this handoff: the tricky parts, order of work, how we work)
2. windows/018-beekeeper-blooms/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Update: The bloom calendar" and the build roadmap
4. windows/017-beekeeper-meadow/HANDOFF.md and windows/012-beekeeper-garden/HANDOFF.md, "How things are done here"
5. windows/CLAUDE.md

Before any file changes, recommend a model and effort and wait for my OK.
Build in this order: engine, engine tests, view model, screen and words, remaining tests. Keep every number in BeekeeperConfig. Live play and time away must agree across bloom changes. Don't touch Beekeeper Help.

Do not build anything listed for later stages (named honey, bloom facts, new buyers, the honey house, bottles, paper labels, better frames, bee hotel upgrades, new meadow plants, batch comb building, the swarm), and don't retune old prices.

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
