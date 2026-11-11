# Beekeeper stage 8: handoff to a build session

**Where we are (2026-11-11):** stages 1–7.5 are built and committed, plus story cards, herbs, the Smoker click boost and reps that arrive (`20984c4`). A planning session settled stage 8, **seeds, wood and the meadow**: the Hippies give seeds at random (20% a trade), plants grow at once and you collect many of each, the first plant of a kind gives its specialty and each one after it a tiny bonus, the willow brings the carpenter bee and wood, wood buys four expansions (frames: half the comb wax; candle molds: 2 candles a craft; the dipping rack: half the candle wax; the bee hotel) and Honey Supers (moved from Beebits), and 50 wildflowers and 50 clover buy the meadow. Every decision is Bee's; every number is a placeholder in `BeekeeperConfig`.

**Settled with Bee:** Honey Supers move from Beebits to wood; the dipping rack halves every candle's wax (it does not add batch buttons), and the batch buttons already built stay as they are. See "Conflicts with what is already built" in the spec.

## Read first
1. `windows/017-beekeeper-meadow/spec.md`: what to build, every number, the words and the tests.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Update: Seeds, plants and the meadow", "Decisions made" and the build roadmap.
3. `windows/016-beekeeper-combs/HANDOFF.md`: walls, caps and "getting stuck is intended" still apply.
4. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits).
5. `windows/CLAUDE.md` for build and test commands.

## Where the code is
`BeekeeperConfig.cs` (`BeekeeperPlant`, `Plants`, `BeekeeperUpgrade`, `Upgrades`, the stage 7 bed settings), `BeekeeperState.cs` (`Plants`, `SeedsInHand`, `SeedsGivenIds`, `Beds`), `BeekeeperEngine.cs` (`GiveSeedsIfDue`, `GiveSeed`, `PlantSeed`, `GrowBeds`, `BedCount`, `FreeBeds`, `SproutedPlants`, `NursingMultiplier`, `GuardingMultiplier`, `ResinPropolisPerMinute`, `ForagingPollenPerMinute`, `Attract`, `Work`, `TradeCandles`, the `Craft…` methods, `CombCost`, `HoneyPerSecond`, `HoneyStorage`, `WaxStorage`, `MoveToWoodenHive`, the debug seed methods; `IRandomSource` for the rolls), `BeekeeperViewModel.cs` (Garden rows, `BeekeeperBedView`, batch helpers, the Notebook and Bees card, debug), `BeekeeperView.axaml(.cs)`, `BeekeeperText.cs`, `HelpWindow`, `MainWindow` (debug: Banners → Beekeeper), `tools/Honeycomb_Localization.xlsx` and `tools/generate_localization.py`, tests in `windows/tests/SoliBee.Tests/`.

## The tricky parts
- **Specialties must count kinds, not plants.** Today `GuardingMultiplier` and `NursingMultiplier` multiply over every sprouted plant. With many plants that runs away. Take each kind once (FR-804).
- **The roll needs the engine's `IRandomSource`.** Never `Random.Shared` directly, or tests can't fix it.
- **Trade All rolls once per candle**, since each candle counts as a trade. Keep the log to one line for the batch.
- **Beds go, but saves may hold a growing bed.** Sprout it on load (FR-803).
- **Hotel gifts and live/away.** Split `Work` at each gift, as it split at sprouts, so the number of gifts depends only on time.
- **Frames are a bought discount, not a wall fix.** The "never lower a price because of a wall" rule still stands.
- **Plants and seeds are now repeated ids in lists.** Anything that used `Contains` to mean "has this plant" is still right; anything that counted the list to mean "kinds" is wrong now.

## Order of work
Engine (config, state, the roll, instant planting and beds commented out, kinds for specialties, plant bonuses, the carpenter bee and wood, wood prices, the four upgrades, the hotel, the meadow, save, comment-outs) → engine tests → view model (Garden rows with counts, wood row, Honey Super on wood, candle prices with the rack, meadow offer, Bees tab, debug) → screen and words (workbook + generator, Help) → the remaining tests (quick filter while working, full suite once before the final commit).

## Working with Bee
- Be really nice; Bee goes by Bee, and no character voice.
- Before starting any change, recommend a model and effort (and whether a new session is better) and wait for Bee's OK. Don't launch or drive the app yourself: build to confirm it compiles, then let Bee test.
- Build systems first with placeholders. Flag real rule conflicts; don't stop for tuning questions.
- Comment out cut features that may return; delete replaced internals.
- Every auto-growing stat's hover lists all its sources and multipliers.
- Ignore the intermittent Honeycomb card-game test failures.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 8 (seeds, wood and the meadow) in the Honeycomb monorepo, Windows only. My name is Bee; please be really nice to me.

Read first:
1. windows/017-beekeeper-meadow/HANDOFF.md (this handoff: the tricky parts, order of work, how we work)
2. windows/017-beekeeper-meadow/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Update: Seeds, plants and the meadow" and the build roadmap
4. windows/016-beekeeper-combs/HANDOFF.md and windows/012-beekeeper-garden/HANDOFF.md, "How things are done here"
5. windows/CLAUDE.md

Before any file changes, recommend a model and effort and wait for my OK. 
Build in this order: engine, engine tests, view model, screen and words, remaining tests. Keep every number in BeekeeperConfig. Comment out anything that is cut instead of deleting it. Live play and time away must agree with wood, plant bonuses, the meadow and bee hotel gifts.

Do not build anything listed for later stages (the honey house, bottles, paper labels, better frames, more bee hotel upgrades, new meadow plants, batch comb building, blooms, new buyers, the swarm), and don't retune old prices.

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
