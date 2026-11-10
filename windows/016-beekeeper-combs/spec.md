# Feature Specification: Beekeeper, stage 7.5: combs, bees as currency

**Feature Branch**: `016-beekeeper-combs`
**Created**: 2026-11-09
**Status**: Specced, not built, from Bee's decisions in the planning session (earlier docs call Bee "Leah"). **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009–015. Design: `Beekeeper/LONG_TERM_DESIGN.md`, "Update: Combs, bees as currency". Rules: `Beekeeper/EARLY_LOOP_RULES.md` v3.

**Why now**: honey came from every bee, so bees were both the income and the score, wax followed honey with no limit, and a fast clicker could outrun everything. In this stage **bees pay for combs, combs make the honey, free bees make the wax**, and a small wax cap makes walls that show where upgrades belong. Bee's decisions (2026-11-09):
- The queen stays; her bees arrive as free bees. The catch slice reads free bees only.
- Wax = a tiny base drip + free bees × rate, not multiplied by combs.
- The starter comb makes no honey until the first bee is caught. It counts as a comb, and the Workbench threshold moves to 3 so it opens at the same point (with the first wasp).
- New combs raise both caps. Each adds only a little wax room, so the rising comb price still outruns the wax cap.
- Capacity upgrades are repeatable flat increases. Technologies are one-time % boosts (the existing Bigger Combs and Propolis Seal), now on both caps.
- The trade agreement's auto-sale is commented out. In its place, the bear gives a better selling rate, at 25 trades instead of 100.
- Calm, candles, the wooden hive and guarding boost comb honey only. Wax-Catchers multiply the wax rate.
- "How many bees fit in a comb" is the comb's bee price, not a separate number.
- Old saves don't matter. Save version 8: any older save just starts a new game, with no conversion.
- The wax cap is small, drastically lower than you'd first guess.
- **Getting stuck is intended.** Do NOT add a rule that caps must stay above prices.

**In this build**: the starter comb; flat honey per comb; the new wax rate and wax cap; combs priced in bees and wax; repeatable capacity upgrades; Technologies on both caps; walls the screen explains; the better selling rate; zero-bee checks fixed; wording; save version 8.
**Not in this build** (stage 8 or later): buying the meadow or honey house, bottles of honey, paper labels, meadow plants, batch comb building, blooms, new buyers. Stage 7.5 also does not retune the old prices: it lists them ("Prices to look at again").

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One comb to start (Priority: P1)
1. **Given** a new game, **Then** the hive has 1 comb and 0 bees, and honey is not being made.
2. **Given** the first bee is caught, **Then** the starter comb starts making honey, from then on, even if free bees later go back to 0. A sting catches nothing and starts nothing.
3. **Given** a new game before any click, **Then** the wax drip is already running.

### User Story 2 - Combs make the honey (Priority: P1)
1. **Given** N combs, **Then** honey comes in at N × **0.2 a second** *(placeholder)*, however many bees there are.
2. **Given** calm, a bee-boost or sage-propolis candle, the wooden hive or guarding, **Then** honey is multiplied as before and wax is not.

### User Story 3 - Free bees make the wax (Priority: P1)
1. **Given** F free bees, **Then** wax per second = (**0.005** + F × **0.0001**) × the Wax-Catcher multiplier *(placeholders)*.
2. **Given** a Wax-Catcher, **Then** the whole rate doubles; with the Better Wax-Catcher it is ×3 (today's multipliers).
3. **Given** the number of combs changes, **Then** the wax rate does not.
4. **Given** the queen raises bees, **Then** they arrive as free bees, and the wax rate rises as they arrive.
5. **Given** wax is shown, **Then** it shows as a whole number, with fractions kept behind the scenes (as honey is).

### User Story 4 - A comb costs bees and wax (Priority: P1)
1. **Given** the Combs panel, **Then** the next comb's price shows both parts: **20 bees and 10 wax** at first *(placeholder)*.
2. **Given** n combs already bought (the starter does not count), **Then** the bee price is floor(20 × 1.4ⁿ) and the wax price floor(10 × 1.25ⁿ) *(placeholders)*.
3. **Given** a comb is bought, **Then** its bee price leaves the free-bee count for good, and the wax is spent. No per-comb bee count is kept.
4. **Given** the 3rd comb (2 bought), **Then** The Workbench opens and wasps can begin.
5. **Given** 5 wax is first held *(placeholder)*, **Then** the Combs panel appears and stays.

### User Story 5 - Honey and wax each have a cap (Priority: P1)
1. **Given** N combs, **Then** honey room = (**200** + (N−1) × **300** + supers × 1,000) × Technology multiplier, and wax room = (**20** + (N−1) × **2** + trays × 8) × Technology multiplier *(placeholders)*. The starting amounts include the starter comb.
2. **Given** honey is at its cap, **Then** honey stops. Nothing is wasted into wax and nothing is sold. "The combs are full" shows as today.
3. **Given** wax is at its cap, **Then** wax stops and a "wax is full" row shows.
4. **Given** the Hive card, **Then** wax reads "12 / 20", as honey does.

### User Story 6 - Capacity upgrades (Priority: P1)
1. **Given** the Shop has opened and the Combs panel has appeared, **Then** The Workbench card shows two rows that can be bought again and again, for Beebits only *(names and numbers placeholders)*:

   | Upgrade | Adds | First price | Each next |
   |---|---|---|---|
   | **Honey Super** | +1,000 honey room | 75 Beebits | +50%, rounded down |
   | **Wax Tray** | +8 wax room | 100 Beebits | +60%, rounded down |

2. **Given** a level is bought, **Then** the row stays and shows the new price and the level owned.
3. They are Beebits only so that a player can always pay past a wall by selling honey.

### User Story 7 - Technologies on both caps (Priority: P1)
1. **Given** Bigger Combs I, Bigger Combs II or the Propolis Seal, **Then** the same % applies to honey room and wax room (+50%, +100%, +25%; Bigger Combs II replaces I as today, and the Seal multiplies with them). Each is bought once and leaves the Shop.
2. Their blurbs say both honey and wax.

### User Story 8 - The screen makes a wall clear (Priority: P1)
1. **Given** a wax price above the wax cap, **Then** its row reads **"Needs more wax storage (holds 32)"** in the wall colour beside the price, and its button stays disabled. This is different from a price the player merely can't afford yet, which looks as it does today.
2. **Given** the first time any wall appears, **Then** the log says once: **"This needs more wax than the hive can hold. Time to make room."**
3. **Given** a hover on the disabled button, **Then** it names the ways past: "A Wax Tray, a new comb or a Technology makes more room."
4. **Given** the cap rises past the price, **Then** the wall text goes away by itself.
5. This covers every wax price the player can see: the comb, the wooden hive and Shop upgrades. A later honey price above the honey cap uses the same check and the same kind of words. x10 and x100 batch buttons stay hidden until affordable (the batch standard), so they are never walls.
6. **The engine never lowers a price or raises a cap because of a wall.** A wall with nothing built past it yet is acceptable; see "To-dos for later stages".

### User Story 9 - The bear's better rate (Priority: P1)
1. **Given** the 25th bear trade *(placeholder)*, **Then** the bear offers the trade agreement, and from the next sale **8 honey = 1 Beebit** *(placeholder)*.
2. **Given** selling, **Then** it stays in whole bundles at the rate of the moment: a bundle is 10 honey before the agreement and 8 after. The leftover stays. Every button, hover and log line shows the current bundle.
3. **Given** the combs are full, with or without the agreement, **Then** honey simply stops. There is no auto-sale, live or away.

### User Story 10 - Time away (Priority: P1)
1. **Given** any stretch, **Then** many 1-second `Advance` calls equal one `AdvanceAway`, including the queen raising bees part-way, the pantry running out, either cap being reached, and a plant sprouting part-way.
2. **Given** the first bee has been caught, **Then** the welcome-back message appears even with 0 free bees.
3. **Given** the first bee has not been caught, **Then** there is no welcome-back message, but the wax drip still counts.

### User Story 11 - New game and old saves (Priority: P1)
1. **Given** a hive with 0 free bees that has caught its first bee, **When** New Game is chosen, **Then** "Start over?" is asked.
2. **Given** a brand-new hive with no bee caught yet, **Then** it starts over silently.
3. **Given** a save older than version 8, **Then** it is moved aside like an unreadable file and a new game starts, with no conversion.

## Reveal order (changes to earlier tables)
| Trigger | Appears |
|---|---|
| New game | 1 comb; the wax drip |
| First bee caught | honey starts; the Honey row |
| 1 whole wax | the Wax row with its cap |
| **5 wax** (was 50) | the Combs panel |
| **3 combs, counting the starter** (was 2 combs built) | The Workbench; the first wasp can come |
| Shop open and Combs panel open | Honey Super and Wax Tray rows |
| Any visible wax price above the cap | its "needs more storage" text; the once-only log line |
| **25 bear trades** (was 100) | the trade agreement: the better selling rate |

## Functional Requirements
- **FR-701**: Every number below lives in `BeekeeperConfig`.
- **FR-702**: **The starter comb.** `BeekeeperState.Combs` defaults to `1` and is valid from 1 up. `CombCost` and the new bee price count combs **bought** (`Combs − 1`), and the caps add room for bought combs only: otherwise the first price and the starting caps are one comb off.
- **FR-703**: **Honey.** `HoneyPerSecond` = (first bee caught ? `Combs` × `HoneyPerCombPerSecond` × `HiveMultiplier` : 0). "First bee caught" is the existing sticky `State.HoneyRevealed`; expose it as one engine property (e.g. `HiveStarted`). Never test `State.Bees > 0` for this: paying for a comb can take free bees to 0.
- **FR-704**: **Free bees.** `State.Bees` keeps its name and now means free bees (say so in a comment). `BeesPerCatch` then reads free bees with no change.
- **FR-705**: **Wax.** `WaxPerSecondNow` = (`WaxBasePerSecond` + `State.Bees` × `WaxPerFreeBeePerSecond`) × `WaxMultiplier`, where `WaxMultiplier` is today's `WaxPerBatch` renamed. No calm, candle, wooden-hive or guarding term.
- **FR-706**: **`Produce` is rebuilt.** The bee-seconds maths stays exactly as it is and moves to wax: wax made = (`WaxBasePerSecond` × seconds + beeSeconds × `WaxPerFreeBeePerSecond`) × `WaxMultiplier`, stored up to the room left. Honey is a flat rate × seconds × boost × `SagePropolisBoostNow`, stored up to the room left, or 0 before the first bee. The early `if (beeSeconds <= 0m) return` goes, because wax drips and reveals run with no bees. Production never depends on what is stored, so `min(made, room)` keeps many short stretches equal to one long one.
- **FR-707**: **Caps.** `HoneyStorage` keeps its name; add `WaxStorage`. Both use the same `StorageMultiplier`. `WaxProgress` and `HoneyPerWax` are cut. Wax becomes fractional. Add `WaxFullAnnounced`, `IsWaxFull` and a `WaxFull` event, and extend `RefreshStorageFlag` to both.
- **FR-708**: **Comb purchase.** `CanBuildComb` needs both bees and wax. `BuildComb` takes both. `CombBuilt` carries the bees that moved in. `Combs` reveal uses `CombsRevealWax`; the words must not claim there is enough wax for a comb, since the reveal comes before the price.
- **FR-709**: **Capacity upgrades** are saved as two levels (`HoneySupers`, `WaxTrays`), with `HoneySuperCost`, `WaxTrayCost`, `CanBuy…` and `Buy…` in the engine, on the same pattern as `CombCost`. They are not entries in `Config.Upgrades`, since those leave the Shop once bought.
- **FR-710**: **Walls** are one engine check, e.g. `IsWaxWall(decimal wax) => wax > WaxStorage`, plus `FirstWallAnnounced` and a `FirstWall` event. The view model exposes the wall state for each row that has a wax price, and the view only reads it. Nothing may clamp a price or a cap.
- **FR-711**: **The bear.** Add `HoneyPerBeebitNow` (`BetterHoneyPerBeebit` under the agreement, else `HoneyPerBeebit`). `CanSell`, `Sell` and the bear row in the view model read it, including the event's honey amount. The sale that reaches 25 pays at the old rate. `BetterHoneyPerBeebit` is a new setting: the old `AgreementHoneyPerBeebit = 20` meant half price, the opposite.
- **FR-712**: **Comment out, don't delete** (FR-716 lists it).
- **FR-713**: **Zero-bee checks.** `NewGameNeedsConfirmation` and the `State.Bees > 0m` check in `AdvanceAway` both read the FR-703 property. The welcome-back honey is `m.Stored` alone.
- **FR-714**: **Save version 8.** `state.Version < CurrentVersion` goes through the same path as a too-new or damaged file (moved aside, new game). New saved fields: `HoneySupers`, `WaxTrays`, `WaxFullAnnounced`, `FirstWallAnnounced`. Sanity checks: `Combs >= 1`, no negative levels.
- **FR-715**: **Live and away.** Extend the equality test: combs, a queen laying part-way until the pantry empties, a plant sprouting, a sage-propolis candle burning out, the wax cap and the honey cap both reached part-way, the Wax-Catcher on. Many 1-second `Advance` calls equal one `AdvanceAway`. Add a test that calm changes honey and not wax.
- **FR-716**: **Cut, commented out with `// Cut in stage 7.5 (spec 016): …`:** `HoneyPerBeePerSecond`, `HoneyPerWax`, `StartingStorage`, `StoragePerComb` and `AgreementHoneyPerBeebit` in the config; the honey-to-wax and auto-sale blocks of `Produce`; `AgreementBeebitsPerSecondNow`; the `WelcomeBackBear` event, its line and the away field; `Made.Taken`, `Made.AgreementBeebits` and the matching result fields; `WaxProgress` and `AgreementHoneyProgress`; the view's agreement rate hover. Since older saves no longer load, also: `ConvertOldSeeds`, `AnnounceOldCountsIfDue`, `OldCountsAnnounced` and the obsolete stage 4–6 fields (`Seeds`, `SeedsPlanted`, `SeedsGiven`, `GrowSecondsLeft`, `ForagerBees`, `GuardBees`). `HasTradeAgreement` stays and now means the better rate. Cut words stay in the workbook so they are easy to bring back; comment out their use in `BeekeeperText` and the generated keys may stay.
- **FR-717**: **The screen.** The price text gains a bees part. The Workbench's comb row shows both prices and what a comb gives. Honey Super and Wax Tray rows follow it. Hive card: the bee row says "Free bees", the wax row shows its cap, and a wax-full row joins the combs-full row.
- **FR-718**: **Words** through `tools/Honeycomb_Localization.xlsx` (English + Spanish draft) with a small openpyxl script (pattern: `tools/add_beekeeper_stage7_words.py`), then `python tools/generate_localization.py`. No text may still say bees make honey. See "Wording to change". Numbers in Help read as in the config at build time.
- **FR-719**: **Tests.** See "Tests that name the old numbers".
- **FR-720**: **Debug menu.** Existing commands keep working: "Bear trades to almost agreement" reads the config, and +wax may go over the cap (like +honey). Add **"+5 combs"**, **"Fill wax to the cap"** and **"+10,000 free bees"**.

## Placeholder numbers (all in `BeekeeperConfig`)
| Setting | Value | Was |
|---|---|---|
| `HoneyPerCombPerSecond` | 0.2 | `HoneyPerBeePerSecond` 0.01 |
| `WaxBasePerSecond` | 0.005 | new |
| `WaxPerFreeBeePerSecond` | 0.0001 | 1 wax per 50 honey |
| `StartingHoneyCap` (includes the starter comb) | 200 | `StartingStorage` 200 |
| `HoneyCapPerComb` | 300 | `StoragePerComb` 200 |
| `StartingWaxCap` | 20 | none |
| `WaxCapPerComb` | 2 | none |
| `CombBaseBeeCost` / `CombBeeCostGrowth` | 20 / 1.4 | none |
| `CombBaseWaxCost` / `CombCostGrowth` | 10 / 1.25 | 50 / 1.25 |
| `HoneySuperCapacity` / `HoneySuperBaseCost` / `HoneySuperCostGrowth` | 1,000 / 75 / 1.5 | new |
| `WaxTrayCapacity` / `WaxTrayBaseCost` / `WaxTrayCostGrowth` | 8 / 100 / 1.6 | new |
| `BiggerCombs1Multiplier` / `BiggerCombs2Multiplier` / `PropolisSealStorageMultiplier` | 1.5 / 2 / 1.25, on both caps | honey only |
| `WaxCatcherMultiplier` / `BetterWaxCatcherBonus` | 2 / 1.5 (×3), on the wax rate | per 50 honey |
| `HoneyPerBeebit` / `BetterHoneyPerBeebit` | 10 / 8 | 10 / `AgreementHoneyPerBeebit` 20 |
| `AgreementTrades` | 25 | 100 |
| `CombsRevealWax` | 5 | 50 |
| `WorkbenchCombs` | 3 | 2 |

## What the simulator says
From `Beekeeper/tools/simulate_first_hour.py`, 2026-11-09, four weeks. **Read these as direction, not promises:** the players are simple greedy bots, the two propolis candles are left out, and every old price is unchanged. Players: **fast** 6 clicks a second, 3 h on day 1, then 2 × 45 min a day; **steady** 2 a second, 1 h, then 2 × 20 min; **idle** 0.2 a second, 10 min, then 2 × 5 min. The numbers in the spec were chosen with this tool.

### The walls (a visible wax price above the wax cap)
"Met" is when the player first saw it; "waited" is how long until it fit. Comb #8 is the 8th comb, counting the starter.

| Price | Wax | Cap when met | Fast: met, waited | Steady: met, waited | Idle: met, waited | What made it fit |
|---|---|---|---|---|---|---|
| Bigger Combs I | 100 | 24 | 4 min, 3 d | 8 min, 5.5 d | 1 d, 8 d | Wax Tray 8 |
| Comb #8 | 38 | 32 | 8 min, 45 min | 16 min, 44 min | no wall | Wax Tray 1 |
| Stronger Candles | 50 | 32 | 10 min, 1.3 h | 20 min, 1 d | no wall | Wax Tray 2 |
| **Wooden hive** | 200 | 32–78 | 26 min, 3 d | 39 min, 5.5 d | 5.5 d, 4 d | Propolis Seal |
| Third Bed | 200 | 32–70 | 34 min, 3 d | 38 min, 5.5 d | 4.5 d, 5 d | Propolis Seal |
| Comb #9 | 47 | 42 | 54 min, 35 min | 1 d, 15 min | 2.5 d, 12 h | Wax Tray 2 |
| Comb #10 | 59 | 52 | 1.5 h, 55 min | 1 d, 12 h | 3 d, 12 h | Wax Tray 3 |
| Comb #11 | 74 | 62 | 2.4 h, 1.4 d | 1.5 d, 1.5 d | 3.5 d, 2 d | Wax Tray 5 |
| Propolis Seal | 150 | 52–70 | 7.4 h, 2.7 d | 1.3 d, 4.2 d | 4.8 d, 4.7 d | Bigger Combs I |
| More Practice | 200 | 70–78 | 1 d, 2 d | 2.5 d, 3 d | 5.5 d, 4 d | Propolis Seal |
| Comb #12 | 93 | 80 | 1.5 d, 1 d | 3 d, 1.5 d | 5.5 d, 2.5 d | Wax Tray 7 |
| Comb #13 | 116 | 98 | 2.5 d, 12 h | 4.5 d, 1 d | 8 d, 1.5 d | Bigger Combs I |
| **Bigger Combs II** | 250 | 159 | 3 d, 4 d | 5.5 d, 5.5 d | 9.5 d, 7.5 d | Wax Tray 11 |
| Comb #15 | 181 | 165 | 3 d, 17 min | 5.5 d, moments | 9.5 d, moments | Propolis Seal |
| Comb #16 | 227 | 210 | 3 d, 2.5 d | 5.5 d, 3.5 d | 9.5 d, 5 d | Wax Tray 10 |
| Comb #17 | 284 | 244 | 5.5 d, 1.5 d | 9 d, 2 d | 14.5 d, 2.5 d | Bigger Combs II |
| Comb #18 | 355 | 350 | 7 d, 3 d | 11 d, 3.5 d | 17 d, 4.5 d | Wax Tray 12 |
| **Comb #19** | 444 | 375 | 10 d, still open | 14.5 d, still open | 21.5 d, still open | nothing yet: see the to-dos |

There are no honey walls with today's prices: bee bread (10 honey) and paper (50 honey) always fit.

### Fast clicker against idle player
| Day | Fast: combs, honey/s, wax cap | Steady | Idle |
|---|---|---|---|
| 1 | 10, 2.5, 62 | 7, 1.8, 40 | 1, 0.2, 20 |
| 7 | 16, 5.0, 244 | 15, 4.7, 210 | 11, 2.8, 80 |
| 14 | 18, 5.6, 395 | 17, 5.3, 350 | 15, 4.7, 225 |
| 21 | 18, 5.6, 415 | 18, 5.6, 395 | 17, 5.3, 350 |
| 28 | 18, 5.6, 435 | 18, 5.6, 415 | 18, 5.6, 395 |

The fast clicker is well ahead on day 1 (10 combs to 1, and 216× the Beebits) and the gap closes: 1.5× the combs and 7.9× the Beebits on day 7, 1.1× and 3.0× on day 21. **The small wax cap does its job:** free bees run to 2.3 billion for the fast clicker with no effect on combs. Wax is full 93–99% of the time, so a visit's wax is about one cap. Honey is full 74–85% of the time. Empty honey caps take about 15–50 minutes to fill on day 1, 1–2 hours on day 7 and about 2.5–3 hours by day 21, so a long absence earns no more than that.

### Does growth level off around week 3?
**Yes, for all three.** Honey a second grows: fast +12% (week 2), 0% (week 3), 0% (week 4); steady +13%, +6%, 0%; idle +70%, +13%, +6%. The fast clicker reaches its plateau early, at about day 14. All three stop at 18 combs because comb #19's wall stays open, so this is partly the content of stage 7.5 running out: it would need checking again once stage 8 exists.

### Prices to look at again
Stage 7.5 does not change these. Each was set for the old economy. Times are when the player first bought it.

| Price | Beebits | Wax | Other | Fast | Steady | Idle | Why |
|---|---|---|---|---|---|---|---|
| **Wooden hive** (brings the queen) | 0 | **200** | 10 bee bread | 3 d | 5.5 d | 9.5 d | Far above the cap when first seen. It waits on the Propolis Seal, so the queen waits on the poplar. |
| **Bigger Combs II** | 800 | **250** | 2 sage | 7 d | 11 d | 17 d | Above the cap at every stage until Wax Tray 11. |
| **Bigger Combs I** | 300 | **100** | | 3 d | 5.5 d | 9.5 d | Shows at the Workbench (cap 24), then stays a wall for days. |
| **More Practice** | 2,500 | **200** | 3 sage | 3.5 d | 6.5 d | 10.5 d | Above the cap. |
| **Third Bed** | 1,500 | **200** | 10 paper | 3.5 d | 6 d | 10 d | Above the cap. |
| **Propolis Seal** | 1,000 | **150** | 30 propolis | 3 d | 5.5 d | 9.5 d | Above the cap, and it is the way past the wooden hive's wall. |
| **Stronger Candles** | 200 | **50** | 2 sage | never | never | never | The emissary (34–38 min for active players) retires it before it can be afforded. |
| Practice | 600 | 50 | | 1 d | 2.5 d | 5.5 d | Fits, but uses a large share of the cap. |
| Smoker | 500 | 50 | | 1 d | 2.5 d | 4.5 d | Same. |
| Whistle | 15,000 | | | 9 d | 13 d | 20 d | Over 3 days after the Flower Cart for every player. |
| Flower Cart | 4,000 | | | 4 d | 7 d | 11.5 d | Over 3 days after the Lure for two of three. |
| Bee Lure | 1,000 | | | 1.5 d | 3.5 d | 6.5 d | Priced for an income that no longer exists. |
| Vacuum | 250 | | | 2 h | 1.5 d | 3.5 d | Same. |
| Net, Gloves | 75, 15 | | | 18 min, 8 min | 22 min, 10 min | 1.5 d, 1 d | Same; slower than the old 2–10 minutes. |
| Wax-Catcher | 150 | | | 1.3 h | 1 d | 2.5 d | Priced for the old income; it now multiplies a rate that often sits at the cap. |
| Better Wax-Catcher | 400 | | 1 sage | 1 d | 2 d | 4.5 d | Same. |
| Notebook | 100 | | 20 paper | 1 h | 1 d | 5 d | Check against the new income. |
| Beeswax / repellent candle | | 10 | | | | | Fit, but half of a starting cap. Candle demand is high: 50 candles for the wildflowers alone. |
| Bee-boost / sage-propolis candle | | 20 | | | | | Equal to the whole starting cap. |
| Bribe, raid, paper, bee bread | | | honey | | | | They read honey amounts, so they shift with the new honey rate. Paper's x100 batch (5,000 honey) needs a far bigger cap. |

## To-dos for later stages (walls with nothing built past them yet)
Acceptable in this stage; each marks where something belongs.
1. **Comb #19 and beyond:** the next Wax Tray costs 45,000–115,000 Beebits at day 28. The meadow is the larger purchase this points to.
2. **Free bees have no sink:** up to 2.3 billion against a 6,098-bee comb. The meadow's price ("tons of bees") is the place.
3. **Time away tops out at about 3 hours of honey:** the honey house holding tons of honey is the place.
4. **The last Technology** is Bigger Combs II: more belong here.
5. **Beebits after the Whistle** have only repeat upgrades to buy.
6. **Buying one comb at a time** at high counts: batch comb building (stage 8).
7. **The bear's bottles:** the honey house's paper-priced selling upgrades (stage 8).

## Key Entities (additions)
Free bees (`Bees`, meaning changes; saved), Combs (starts at 1; saved), Honey Supers and Wax Trays (levels; saved), Wax (fractional; saved), wax-full and first-wall announced flags (saved). Honey and wax caps and all rates are derived, never saved.

## Draft story-log lines *(English; Bee to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Comb built | "A new comb. {bees} bees move in." |
| Combs panel appears | "The wax is gathering. Enough of it makes a comb." |
| Wax full | "There's no more room for wax." |
| First wall | "This needs more wax than the hive can hold. Time to make room." |
| Honey Super bought | "You stack a honey super on top. More room for honey." |
| Wax Tray bought | "You slide in another wax tray." |
| Trade agreement | "{bear} offers a trade agreement: from now on, he pays more for your honey." |
| Welcome back | "While you were away, the combs filled with {honey} honey." |

## Wording to change (workbook)
| Key | Today | Draft |
|---|---|---|
| `beekeeper_hive_bees` | Honeybees | Free bees |
| `beekeeper_comb_blurb_fmt` | +%@ honey storage | +%@ honey a second, room for %@ honey and %@ wax |
| `beekeeper_log_combs_available` | There is wax enough for a new comb. | The line above |
| `beekeeper_log_comb_built_fmt` | A new comb. Room for %@ more honey. | The line above |
| `beekeeper_log_welcome_back_fmt` | While you were away, the bees made %@ honey. | The line above |
| `beekeeper_wooden_hive_blurb_fmt` | Every honeybee makes %@% more honey. | The combs make %@% more honey. |
| `beekeeper_upgrade_smoker_blurb` | Calm bees make double honey | With calm bees, the combs make double honey |
| Bigger Combs I and II blurbs | +%@% honey storage | +%@% honey and wax storage |
| `beekeeper_upgrade_propolis_seal_blurb` | The combs hold %@% more honey | The combs hold %@% more honey and wax |
| `beekeeper_agreement_line` | Trade agreement: extra honey at half price. | Trade agreement: a better price for honey. |
| `beekeeper_log_trade_agreement_fmt` | …he'll take the extra honey at half price. | The line above |
| Help: Objective, How to Play, Away, Workbench, Garden, Smoker, Queen | bees make honey; 50 honey = 1 wax; each comb holds 200; after your 2nd comb; every honeybee makes more honey; "wax keeps coming" when full; New Game "if you have bees to lose"; agreement at 100 trades, half price | Rewrite to these rules; the 2nd-comb line becomes "at your 3rd comb". |

New words: "Free bees", the wall text and hover (User Story 8), "wax is full", the two capacity upgrade names and blurbs, a price part for bees. Check `beekeeper_sell_hint` and any bear text that names 10 honey.

## Tests that name the old numbers
About 182 lines across 18 Beekeeper test files name the old numbers or set up honey through bees. By file (matching lines): `BeekeeperEngineTests` 34, `BeekeeperStage5Tests` 31 (agreement and the queen's triangle), `BeekeeperStage2Tests` 16 (Workbench at 2 combs), `BeekeeperViewModelTests` 14, `BeekeeperQueenViewModelTests` 14, `BeekeeperHardeningTests` 11, `BeekeeperStage6Tests` 10, `BeekeeperStage4Tests` 9, `BeekeeperStage3Tests` 8, `BeekeeperSaveTests` 8, `BeekeeperStage6ViewModelTests` 6, `BeekeeperLoadFixesTests` 5, `BeekeeperStage7Tests` 4, `BeekeeperCoordinatorTests` 4, and 2 each in `BeekeeperWaspViewModelTests`, `BeekeeperStage7ViewModelTests`, `BeekeeperGardenViewModelTests`, `BeekeeperGapTests`.
- Tests that set `Bees = 100m` to get honey need `HoneyRevealed = true` and combs instead. A helper for "a started hive with N combs" keeps this short.
- `new BeekeeperState()` now has 1 comb, so every `Combs` assertion and the Workbench tests shift.
- Rules that are gone (auto-sale, old-save conversions, honey-to-wax): comment the test out with the `// Cut in stage 7.5` note and add a test of the new rule.
- The save tests load old versions: they become "an older file starts a new game".
- New tests: starter comb and first bee; zero free bees still earn honey; first price and starting caps with the starter counted; wax rate with and without bees; calm leaves wax alone; both caps stop production; comb takes bees and wax; repeat prices; Technologies on both caps; a wall is reported and never changes a price; bundles before and after 25 trades, including the trade that reaches it; `NewGameNeedsConfirmation` and the welcome-back at zero bees; FR-715.

## Decided (Bee, 2026-11-09)
Every bullet under "Why now". Also: the meadow is one giant comb (stage 8); the honey house's later paper-priced upgrades automate selling through bottles of honey (stage 8).

## Defaults taken in planning (easy to change)
1. The wax drip runs from the start of the game, before the first bee.
2. The stage is called 7.5 so that stage 8 keeps its number.
3. Capacity upgrades cost Beebits only and sit at The Workbench under the comb row.
4. Wax-Catchers multiply the base drip as well as the bee part.
5. Honey Super (a real beekeeping word) and Wax Tray are placeholder names.

## Still open (placeholders in place; none blocks building)
1. Every number above, and the prices in "Prices to look at again".
2. The wording of the wall message.
3. Comb bee prices matter only in the first hours for active players; a steeper growth is an easy change later.
4. The Workbench and the first wasp come about 4–8 minutes in for active players, a little sooner than the old 6–12.

## Success Criteria
- **SC-701**: Every acceptance scenario has an engine or view-model test; Bee has hand-test steps with debug shortcuts.
- **SC-702**: Live and away agree with the queen, the pantry, sprouting, candles and both caps (FR-715).
- **SC-703**: No screen text says bees make honey; no code path sells honey automatically.
- **SC-704**: A price above a cap always reads as needing more storage, and no code changes a price or cap because of it.
- **SC-705**: A save older than version 8 starts a new game without crashing.

## Hand-test (Bee) — debug build, Banners menu in the toolbar
1. Start a new game. One comb, no honey. Wait: wax creeps up. Honey stays at 0.
2. Click until the first bee lands. Honey starts. Sell it with the bear in bundles of 10.
3. At 5 wax the Combs panel appears. Buy a comb: the bees and the wax go down, honey speeds up, both caps go up.
4. Buy until the 3rd comb. The Workbench opens and wasps can come.
5. **+5 combs** and **Fill wax to the cap**. The next comb's price is above the cap: it reads "Needs more wax storage", the log says so once, and the hover names the ways past.
6. **+Beebits**, buy a **Wax Tray**. The cap rises. Buy enough and the wall text goes away by itself.
7. Buy a **Honey Super**: the price rises and the row stays.
8. Buy Bigger Combs I: both caps grow by half.
9. Spend all free bees on a comb. Honey keeps coming. **Spend 8 hours away:** a welcome-back message appears even at 0 free bees, and both amounts stop at their caps.
10. **Bear trades to almost agreement**, sell once: the offer appears. The next bundle is 8 honey. Let the combs fill: honey stops, and no Beebits arrive by themselves.
11. New Game with 0 free bees: "Start over?" is asked. On a brand-new game it isn't.
12. Close and reopen: combs, levels, caps, flags and wax fractions are all still there.
