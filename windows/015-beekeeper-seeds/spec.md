# Feature Specification: Beekeeper, stage 7: more seeds, the poplar and propolis

**Feature Branch**: `015-beekeeper-seeds`
**Created**: 2026-11-07
**Status**: Built (2026-11-07), from Leah's decisions in the planning session. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009–014 (014: specialties, the grouped Hive card, the emissary, paper).

**Why now**: after the bramble, discovery stops; the queen's laying never changes; paper has no use; Beebits have little to buy after the Smoker; and nothing takes longer than 10 minutes. Leah's answers (2026-11-07):
- **Two garden beds**, so two seeds can grow at once; a **third bed** is a Shop upgrade.
- **Three new seeds**, each slower than the last: the **willow** (1 hour: **nursing**, the queen lays faster), the **poplar** (6 hours: **resin**, the bees gather **propolis**) and **clover** (overnight: a second **foraging** plant, more pollen to feed a faster queen).
- **The Hippies give the willow and clover seeds; the wasps give the poplar seed** (they chew poplar wood for their paper). This is the first thing the wasps' reputation gives beyond paper.
- **Paper's first uses**: a **Beekeeper's Notebook**, bought with paper, brings back the Bees card as notes on the hive's specialties; new Shop upgrades also cost some paper.
- **The bee-boost candle** (wax and propolis): more honey for a while, **live play only** (it waits while the app is closed, like the Smoker).
- **The sage-propolis candle** (wax, sage and propolis): a smaller honey boost that burns for hours **and keeps burning while the app is closed**: a reward for time away. (It was planned as a wasp repellent; the wasps are gone after the emissary.)
- **Propolis** goes into the two candles and one Shop upgrade, the **Propolis Seal** (more honey storage).

**In this build**: seeds known by name; two beds and the Third Bed upgrade; per-plant grow times; the willow, poplar and clover; nursing and resin; propolis; the wasps' poplar seed; the bee-boost and sage-propolis candles; the Notebook and the Bees card; the Propolis Seal; Shop upgrades priced in paper and propolis; save version 7.
**Not in this build**: the meadow, meadow plants, the honey house, paper as labels, batch comb building (stage 8); blooms and named honeys (stage 9); new buyers (stage 10). Repellent candles stay retired.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Seeds have names (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a seed is given, **Then** it is a seed of a known plant (e.g. "a willow seed"), not just "a seed". The log says who gave it: **"The Hippies press a willow seed into your hand."** / **"The wasps leave a poplar seed on the hive roof."**
2. **Given** seeds in hand, **Then** the Garden card lists each one with a **Plant** button (enabled while a bed is free). The player chooses which to plant.
3. **Given** the wildflowers and bramble, **Then** they still come from the Hippies at 5 and 10 trades, as today; they are now named too ("a wildflower seed", "a bramble seed").
4. **Given** the plant data, **Then** each plant says who gives its seed (the Hippies or the wasps), at which trade count, its grow time, its specialty and its strength (FR-602).

### User Story 2 - Two beds, then three (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the Garden card, **Then** it shows **2 beds**, each either empty ("An empty bed") or growing ("Willow: growing, about 40 minutes left"). Beds are only for growing: when a seed sprouts, the plant moves out of its bed into **the garden** (the list of sprouted plants under the beds, as today) and the bed is free again. So "two beds" means two seeds grow at the same time; any number of plants can have sprouted.
2. **Given** two seeds and two free beds, **When** both are planted, **Then** both grow at once, each on its own timer, live and while away.
3. **Given** the **Third Bed** upgrade is bought (User Story 9), **Then** a third bed appears.
4. **Given** a seed sprouts part-way through a stretch of time (live or away), **Then** its specialty counts only from that moment, as today, even when several beds sprout in the same stretch (FR-603).
5. **Given** time left, **Then** it is shown roughly: "about 40 minutes", "about 5 hours", "about 11 hours" (whole minutes under an hour, whole hours above).

### User Story 3 - Grow times (Priority: P1)
1. **Given** each plant, **Then** it takes its own time to sprout *(placeholders)*: wildflowers **10 minutes**, bramble **10 minutes**, willow **1 hour**, poplar **6 hours**, clover **12 hours** ("overnight").
2. **Given** the Garden card, **Then** a planted seed says how long it takes before it is planted: the Plant button's hover text says "Takes about 6 hours to grow."

### User Story 4 - The willow: nursing (Priority: P1)
1. **Given** the Hippies' **20th** trade *(placeholder)*, **Then** they give a willow seed.
2. **Given** the willow sprouts, **Then** the hive takes up **nursing**: the queen lays **50% faster** *(placeholder)* (20 → 30 bees a minute in the wooden hive). She eats bee bread at the same rate per bee, so the pantry empties 50% faster.
3. **Given** nursing, **Then** it counts live and away the same, and the queen's hover rate and the welcome-back line include it.
4. **Given** the skep (no brood), **Then** nursing does nothing until the wooden hive.
5. Log line: **"The willow catkins open. The nurse bees fuss over the brood."**

### User Story 5 - The poplar: resin and propolis (Priority: P1)
1. **Given** the emissary has come and the wasps' **10th** trade *(placeholder)*, **Then** the wasps give a poplar seed (User Story 1). Old saves already past 10 wasp trades get it on load.
2. **Given** the poplar sprouts, **Then** the hive takes up **resin** and gathers **1 propolis a minute** *(placeholder)*, steadily, live and away (up to the 3-day limit), like foraging's pollen.
3. **Given** propolis, **Then** it shows in the Garden group of the Hive card with a hover rate ("+0.017 propolis/s"), and the welcome-back message says how much was gathered.
4. Log line: **"The poplar's sticky buds catch the light. The bees start bringing home resin."**

### User Story 6 - Clover: more foraging (Priority: P1)
1. **Given** the Hippies' **35th** trade *(placeholder)*, **Then** they give a clover seed.
2. **Given** clover sprouts, **Then** foraging gathers **3 more pollen a minute** *(placeholder)*: 6 in all with the wildflowers (several foraging plants add up, as built in stage 6). This keeps up with a nursing queen (30 bees a minute eat 3 pollen a minute's worth of bee bread).
3. **Given** the Bees group, **Then** there is still one Foraging row, showing the total ("Foraging: 6 pollen a minute").
4. Log line: **"Clover carpets the garden. The foragers hardly know where to start."**

### User Story 7 - The bee-boost candle (Priority: P1)
1. **Given** the poplar has sprouted, **Then** The Workbench shows the **bee-boost candle** recipe: **20 wax + 2 propolis** *(placeholder)*, crafted instantly, with x10/x100 hidden until affordable (the batch standard).
2. **Given** a bee-boost candle, **When** the player clicks **Light a bee-boost candle**, **Then** the bees make **20% more honey** *(placeholder)* for **10 minutes** *(placeholder)* of live play.
3. **Given** one is already burning, **Then** lighting another adds 10 minutes, up to **60 minutes** left *(placeholder)*; the button is disabled at the cap.
4. **Given** the app is closed or the player is away, **Then** the candle waits: it neither burns nor boosts (like the Smoker's calm). Time away earns nothing extra from it.
5. **Given** the Smoker's calm and a bee-boost together, **Then** they multiply (2 × 1.2), and both multiply with guarding and the wooden hive.
6. **Given** a burning candle, **Then** the Crafts group shows "Bee-boost: burning, 7 minutes left" and the Honey hover rate includes it. When it burns out: **"The bee-boost candle gutters out."**
7. Crafting it counts toward candles crafted (as every candle does). The Hippies don't buy it.

### User Story 8 - The sage-propolis candle (Priority: P1)
1. **Given** the poplar has sprouted, **Then** The Workbench shows the **sage-propolis candle** recipe: **20 wax + 1 sage + 5 propolis** *(placeholder)*.
2. **Given** one, **When** the player clicks **Light a sage-propolis candle**, **Then** the bees make **10% more honey** *(placeholder)* for **4 hours** *(placeholder)*, and it **keeps burning while the app is closed**.
3. **Given** one is already burning, **Then** lighting another adds 4 hours, up to **24 hours** left *(placeholder)*.
4. **Given** it burns out part-way through a stretch (live or away), **Then** the boost counts only up to that moment (FR-604). If it burned out while away, the welcome-back message says so: **"The sage-propolis candle burned down while you were away."**
5. **Given** it and a bee-boost and calm together, **Then** all multiply.
6. **Given** a burning candle, **Then** the Crafts group shows "Sage-propolis: burning, about 3 hours left".

### User Story 9 - New Shop upgrades: paper and propolis (Priority: P1)
1. **Given** the Shop, **Then** upgrades can now also cost **paper** and **propolis** (as well as Beebits, wax and sage). Prices show only the parts that are above zero.
2. New upgrades *(all prices placeholders)*:

   | Upgrade | Price | Shows once | Does |
   |---|---|---|---|
   | **Beekeeper's Notebook** | 20 paper, 100 Beebits | the first paper | brings back the Bees card (User Story 10) |
   | **Third Bed** | 1,500 Beebits, 200 wax, 10 paper | the Garden is open and the first paper | a third garden bed |
   | **Propolis Seal** | 1,000 Beebits, 150 wax, 30 propolis | the first propolis | +25% honey storage, multiplies with Bigger Combs |

3. **Given** a bought upgrade, **Then** it disappears from the Shop, as always.

### User Story 10 - The Bees card returns, as the Notebook (Priority: P2)
1. **Given** the Notebook is bought, **Then** a **Bees** card appears (its layout and code come back from commit `f196a8a`), titled **"THE BEEKEEPER'S NOTEBOOK"**.
2. **Given** the card, **Then** it has one short note per thing the hive has: the queen (once settled) and each specialty (foraging, guarding, nursing, resin), each with a real bee fact. A note appears when its specialty does. Draft notes are in the table below; Leah edits them.
3. **Given** it can be collapsed like the other cards, **Then** it can (if the other cards can).

### User Story 11 - Saving and old saves (Priority: P1)
1. **Given** a game in progress, **When** closed and reopened, **Then** the beds (which plant, time left), named seeds in hand, which seeds have been given, propolis, both candle stocks, both burn times and the new upgrades are restored.
2. **Given** a stage 4–6 save, **Then** it loads with nothing lost: its seeds in hand and its growing seed (with its time left, in bed 1) become named, using the old order (seed N was plant N).
3. **Given** an old save already past the willow's or clover's Hippie trade count, or past the wasps' poplar count, **Then** those seeds are given on load, with their log lines.

## Reveal order (adds to earlier tables)
| Trigger | Appears |
|---|---|
| A named seed in hand | it is listed on the Garden card with a Plant button |
| 20th Hippie trade | willow seed |
| Wasps' 10th trade | poplar seed |
| 35th Hippie trade | clover seed |
| Willow sprouts | Nursing row in Bees |
| Poplar sprouts | Resin row in Bees; Propolis in Garden; the two new candle recipes at The Workbench |
| First paper | Notebook in the Shop; Third Bed (if the Garden is open) |
| First propolis | Propolis Seal in the Shop |
| A candle burning | its "burning" row in Crafts |
| Notebook bought | the Bees card |

## Functional Requirements
- **FR-601**: Every number (trade counts for seeds, grow times, nursing multiplier, propolis per minute, clover's pollen, candle prices, boosts, burn times and caps, upgrade prices, storage bonus, bed count) lives in `BeekeeperConfig`.
- **FR-602**: **Plants are data.** `BeekeeperPlant` gets who gives it (`Hippies` / `Wasps`), at which trade, and its grow seconds, as well as its specialty and strength. The old "Nth seed is the Nth plant" rule goes (comment it out). New specialty ids `Nursing` and `Resin` in `BeekeeperSpecialties`. Nursing plants multiply the queen's rate; resin plants add up to propolis a minute. Given seeds are tracked by plant id so each is given once.
- **FR-603**: **Beds.** The state holds a list of beds (plant id or empty, seconds left) and a list of seed ids in hand. `Work` splits the stretch at **every** moment something changes: each sprout (soonest first) and the sage-propolis candle burning out. Between splits, `Produce` and the garden (pollen and propolis, straight lines) run as today. Keep it exact for any span so live and away agree.
- **FR-604**: **Two kinds of boost.** The bee-boost candle is a live-only boost like calm: `Advance` splits at calm ending and at the bee-boost ending, and passes the combined boost into `Work`. The sage-propolis candle is part of the honey multiplier for both live and away, and burns down inside `Work`.
- **FR-605**: Nursing goes into `QueenRatePerMinute` (or `LayingBeesPerMinute`) so the brood maths, the pantry, the hover rate and the welcome-back all see it. The Propolis Seal goes into `HoneyStorage`.
- **FR-606**: **Live and away agree.** Extend the equality test: two beds sprouting at different moments, nursing, resin, clover and a sage-propolis candle burning out part-way: many 1-second `Advance` calls equal one `AdvanceAway` (the bee-boost candle is left out, being live-only; add a separate test that it does not burn or boost in `AdvanceAway`).
- **FR-607**: `BeekeeperUpgrade` gains paper and propolis prices (default 0, so existing entries don't change). New "needs" names: first paper, first propolis, Garden open.
- **FR-608**: The Bees card is brought back from `f196a8a` (markup, view model rows, words), adapted to specialties: one note per specialty the hive has and one for the queen, shown only once the Notebook is bought. Any part not needed stays out; nothing else from that commit returns.
- **FR-609**: Save version 7. Old `Seeds`, `SeedsPlanted`, `SeedsGiven` and `GrowSecondsLeft` are still read so old files load and are turned into named seeds and beds on load, then no longer used (mark obsolete in a comment). New saved fields: beds, seeds in hand, seeds given (ids), propolis, bee-boost candles, sage-propolis candles, bee-boost seconds left, sage-propolis seconds left. Sanity checks: no negative amounts or times; no more beds than owned; unknown plant ids dropped.
- **FR-610**: New words through the localization workbook (English + Spanish draft) and the generator; Help's Garden and Workbench paragraphs updated (beds, named seeds and who gives them, nursing, propolis, the two candles, the Notebook). No betting or gambling words; bees "fly off", never die.
- **FR-611**: Debug menu: **"Give every seed"**, **"Finish growing"** (now finishes every bed), **"+50 propolis"**, **"+20 paper"**, **"Hippie trades to 19"** (one more brings the willow). Existing commands stay.

## Key Entities (additions)
Bed (plant id or empty, seconds left; saved), Seeds in hand (plant ids; saved), Seeds given (plant ids; saved), Propolis (saved), Bee-boost candles and Sage-propolis candles (saved), Bee-boost seconds left (live time; saved), Sage-propolis seconds left (saved), Nursing and Resin (specialties, derived from the plants).

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Hippies give a seed | "The Hippies press a {plant} seed into your hand." |
| Wasps give the poplar seed | "The wasps leave a poplar seed on the hive roof. 'For the resin. You'll see.'" |
| Seed planted | "You plant the {plant} seed." |
| Willow sprouts | "The willow catkins open. The nurse bees fuss over the brood." |
| Poplar sprouts | "The poplar's sticky buds catch the light. The bees start bringing home resin." |
| Clover sprouts | "Clover carpets the garden. The foragers hardly know where to start." |
| First propolis | "The bees seal a crack with propolis, sticky and sweet-smelling." |
| Bee-boost lit | "You light a bee-boost candle. The bees hum a little faster." |
| Bee-boost out | "The bee-boost candle gutters out." |
| Sage-propolis lit | "You light a sage-propolis candle. It will burn for hours." |
| Sage-propolis out | "The sage-propolis candle burns down." |
| Sage-propolis out while away (welcome back) | "The sage-propolis candle burned down while you were away." |
| Propolis while away (welcome back) | "The bees gathered {propolis} propolis." |
| Notebook bought | "You start a beekeeper's notebook." |
| Third Bed bought | "You dig a third garden bed." |
| Propolis Seal bought | "The bees seal the combs with propolis. They hold more now." |

## Draft Notebook notes *(Leah to edit)*
| Note | Text |
|---|---|
| Queen | "The queen: she can lay well over a thousand eggs a day in high summer." |
| Foraging | "Foraging: a forager may visit a few thousand flowers in a day." |
| Guarding | "Guarding: guards at the entrance know their hive's smell and turn strangers away." |
| Nursing | "Nursing: young bees feed the larvae, checking on each one many times a day." |
| Resin | "Resin: propolis is tree resin mixed with wax; bees use it to seal and clean the hive." |

## Decided (Leah, 2026-11-07)
1. Two beds; a third from the Shop.
2. Willow (nursing, 1 h), poplar (resin and propolis, 6 h), clover (more foraging, overnight).
3. The Hippies give the willow and clover seeds; the wasps give the poplar seed.
4. Paper buys the Notebook (the Bees card returns) and is part of new Shop prices.
5. The bee-boost candle is a live-only honey boost (wax and propolis).
6. The sage-propolis candle is a slow, smaller honey boost that burns while away.
7. Propolis goes into the two candles and the Propolis Seal.

## Still open (placeholders in place; none blocks building)
1. Every number: trade counts (willow 20, clover 35, poplar 10 wasp trades), grow times (1 h, 6 h, 12 h), nursing +50%, propolis 1 a minute, clover +3 pollen, candle prices, boosts (+20%, +10%), burn times (10 min, 4 h) and caps (60 min, 24 h), upgrade prices, Propolis Seal +25%.
2. The candle names on screen ("sage-propolis candle" may want a friendlier name).
3. The Notebook's notes and whether it later holds more (e.g. bloom notes in stage 9).

## Success Criteria
- **SC-601**: Every acceptance scenario has an engine or view-model test; Leah has hand-test steps with debug shortcuts.
- **SC-602**: Live and away agree with two beds, nursing, resin, clover and a sage-propolis candle that burns out part-way.
- **SC-603**: Saves from stages 1 to 6 load with nothing lost that matters; a seed growing in an old save keeps its time left.
- **SC-604**: The bee-boost candle neither burns nor boosts while away.

## Hand-test (Leah) — debug build, Banners menu in the toolbar
1. Load your current game. The Garden card shows 2 beds; any seed you held is named; anything growing kept its time.
2. **Hippie trades to 19**, trade once with the Hippies: a willow seed. Plant it: "about 60 minutes left".
3. **Give every seed**: plant a second seed while the willow grows. Both beds are busy; the third seed's Plant button is disabled.
4. **Finish growing**: both sprout. Bees shows Nursing (and Resin or Foraging, whichever you planted). Hover the queen: faster than before.
5. Plant the rest and **Finish growing**: Propolis appears in Garden; Foraging shows 6 pollen a minute with clover.
6. **+50 propolis**, then at The Workbench craft a bee-boost and a sage-propolis candle. Light both: Crafts shows both burning; hover Honey: higher.
7. **Spend 8 hours away**: the welcome-back message mentions propolis and that the sage-propolis candle burned down; the bee-boost still has its minutes left.
8. **+20 paper**: the Shop shows the Notebook and Third Bed (and the Propolis Seal). Buy the Notebook: the Bees card appears with notes. Buy Third Bed: a third bed.
9. Buy the Propolis Seal: the Combs hover/storage is 25% bigger.
10. Close and reopen: beds, seeds, propolis, candles, burn times and upgrades are all still there.
