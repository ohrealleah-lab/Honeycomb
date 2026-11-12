# Beekeeper stage 10: handoff to a build session

**Where we are (2026-11-12):** stages 1–9 are built and committed (stage 9: `4d9cec5`). A planning session settled stage 10, **the core trade loops**. The Bear buys honey for Beebits again and is the only one who pays Beebits. The game starts with 3 clay jars and an opening story card. Honey + a jar makes potted honey, on the Hive card, which only the Bear buys, at a better rate. The beeswax candle comes back, and the Hippies trade beeswax candles for clay jars, with an herb every 5th trade. Herbs leave the Shop. The new buyers (Hummingbirds, Badgers, the orchard) move to stage 10.5. Every decision is Bee's; every number is a placeholder in `BeekeeperConfig`.

**Recommended for the build:** a fresh session, **Opus 5.5 at medium effort**. The new parts are small, but this stage swaps how the Bear and the Hippies pay, and many older tests assume today's trades.

## Read first
1. `windows/019-beekeeper-trade/spec.md`: what to build, every number, the words and the tests. Its "Conflicts" table is what changes from today.
2. `Beekeeper/LONG_TERM_DESIGN.md`, "Update: The core trade loops" and the build roadmap.
3. `windows/012-beekeeper-garden/HANDOFF.md`, "How things are done here": the conventions (engine first, events not sentences, localization workbook and generator, building while `Honeycomb.exe` is open, test filters, commits).
4. `windows/CLAUDE.md` for build and test commands.
5. Commit `36685aa` (herbs replace sage, the bear trades herbs, herbal candles replace beeswax candles): the shape of the Bear's Beebit pay and the beeswax candle before they were cut. Most of it is still in comments.

## Where the code is
`BeekeeperConfig.cs` (Trading: `HoneyPerTrade`, `BetterHoneyPerTrade`, `HerbsPerTrade` and the commented `BeebitsPerTrade`; the Hippies: `HippieBeebitsPerCandle`; `Upgrades` herb parts; `BeekeeperStories`; `HerbalCandleWax`; `HippieSeedChance`), `BeekeeperState.cs` (`Herbs`, `HerbsRevealed`, `RepellentCandles` = herbal candles, story fields), `BeekeeperEngine.cs` (`Sell`, `HerbsPerTradeNow`, `BeebitsPerCandleNow`, `WithTradeHerb`, `CountCandleCrafted`, `TradeCandles`, `CraftRepellent`, `CandleWax`, `StoryDue` / `AdvanceStoryTime` / `PutOnGloves`, the new-game setup near `StartingBeebits`, the leafcutter's gift, the load sanity checks), `BeekeeperViewModel.cs` (Bear and Hippie commands, Hive card rows, hovers, debug), `BeekeeperView.axaml(.cs)`, `BeekeeperText.cs`, `MainWindow` (debug: Banners → Beekeeper), `tools/Honeycomb_Localization.xlsx` and `tools/generate_localization.py`, tests in `windows/tests/SoliBee.Tests/`.

## The tricky parts
- **Swap, don't stack.** The Bear's herb pay and the Hippies' Beebit pay are commented out (dated `// Cut (Bee, 2026-11-12)`), not kept beside the new pay.
- **"Repellent" means the herbal candle** in names (`RepellentCandles`, `CraftRepellent`, `RepellentUnlocked`). Don't rename them; add the beeswax candle as its own names (`BeeswaxCandles`, `CraftBeeswax`).
- **The first herb opens the herbal recipe, whoever gives it**: the 5th Hippie trade or the leafcutter. Today only the Bear's first sale does it.
- **Per-jar trades.** A Hippie batch loops once per jar: trade count, seed join points, seed roll, and the 5th-trade herb. One log line for the batch's seeds, one for its herbs.
- **The opening card** is first in `BeekeeperStories.Order`. It must leave on its button or the first bee caught, so it never holds up "Ouch!" (which needs 10 bees caught).
- **Older saves**: `StartingJarsGiven == false` on load gives the jars and marks the opening card done.
- **Older tests**: many tests sell honey expecting herbs or trade candles expecting Beebits. Update them to the new trades and keep what they check. Run the full Beekeeper filter before the final commit.
- **Growth hovers** must list every source (Beebits, herbs, clay jars).
- **Don't touch Beekeeper Help.**

## Order of work
Engine (config, state, the Bear's pay, potted honey, jars and the opening card, the beeswax candle, the Hippies' jar trade, the 5th-trade herb, herbs out of the Shop, events, save checks) → engine tests and the older tests → view model (Hive rows and Pot honey, Bear and Hippie buttons, Workbench recipe, hovers, log lines, debug) → screen and words (workbook + generator) → the remaining tests (quick filter while working, full suite once before the final commit).

## Working with Bee
- Be really nice; Bee goes by Bee, and no character voice.
- Before starting any change, recommend a model and effort (and whether a new session is better) and wait for Bee's OK. Don't launch or drive the app yourself: build to confirm it compiles, then let Bee test.
- Build systems first with placeholders. Flag real rule conflicts; don't stop for tuning questions.
- Comment out cut features that may return; delete replaced internals.
- Every auto-growing stat's hover lists all its sources and multipliers.
- Make buttons are earned: no Make 10 for potting.
- Ignore the intermittent Honeycomb card-game test failures.

## Starting prompt (paste into the new build session)

```
You are building Beekeeper stage 10 (the core trade loops) in the Honeycomb monorepo, Windows only. My name is Bee; please be really nice to me.

Read first:
1. windows/019-beekeeper-trade/HANDOFF.md (this handoff: the tricky parts, order of work, how we work)
2. windows/019-beekeeper-trade/spec.md (what to build; all decisions are mine, all numbers are placeholders)
3. Beekeeper/LONG_TERM_DESIGN.md, "Update: The core trade loops" and the build roadmap
4. windows/012-beekeeper-garden/HANDOFF.md, "How things are done here"
5. windows/CLAUDE.md

Before any file changes, recommend a model and effort and wait for my OK.
Build in this order: engine, engine tests and older tests, view model, screen and words, remaining tests. Keep every number in BeekeeperConfig. Comment out the Bear's herb pay and the Hippies' Beebit pay; don't delete them. Don't touch Beekeeper Help.

Do not build anything listed for later stages (Hummingbirds, Badgers, the orchard, named honey, bottles and the honey house, paper labels, a Make 10 for potting, herb kinds, new leafcutter rules, the swarm), and don't retune old prices beyond taking herbs out of the Shop.

When it compiles and the Beekeeper tests pass, give me short numbered hand-test steps using the debug menu, commit, and remind me to start a fresh session.
```
