# Feature Specification: Beekeeper, stage 8: seeds, wood and the meadow

**Feature Branch**: `017-beekeeper-meadow`
**Created**: 2026-11-11
**Status**: Specced 2026-11-11, not built. From Bee's decisions in the planning session. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009–016 and the commits after 016 (story cards, herbs, the Smoker click boost, reps that arrive). Design: `Beekeeper/LONG_TERM_DESIGN.md`, "Update: Seeds, plants and the meadow" and "Decisions made".

**Why now**: seeds come once each on a set trade, plants then wait 10 minutes to 12 hours in a bed, and nothing grows past one of each. Free bees have no sink, Beebits run out of things to buy, and stage 7.5's walls have nothing past them. In this stage **the Hippies give seeds at random, plants grow at once, you collect many of each, the willow brings the carpenter bee and wood, wood buys expansions, and 50 wildflowers and 50 clover buy the meadow.** Bee's decisions (2026-11-11):
- Each Hippie trade has a **20% chance** to give a seed. A miss is a normal trade. Every Hippie seed comes through the roll, the willow and clover included.
- Seed types join the roll at different points in the game, so they are paced out.
- **Plants grow as soon as they are planted.** No waiting (the wait "introduces weird complexity"). The instant-sprout formula idea is dropped.
- You can have many of each plant. **The first plant of a kind gives its specialty**; every one after it adds only a **tiny production bonus**.
- **The meadow is bought with 50 wildflowers and 50 clover** (small flowering plants, not trees), not with bees.
- **The carpenter bee** is summoned when the first willow is planted. It collects **wood**. Wood is for **further expansions**, not paper (paper stays the wasps' trade).
- **Honey Supers cost wood, not Beebits.**
- Wood buys **wooden frames** (one time: half the wax for new combs, combs only; later stages add better frames), **wooden candle molds** (one time), the **dipping rack** (one time: candles cost **half the wax**; Bee, 2026-11-11, replacing a Make 10 button) and the **bee hotel** (rare bees who now and then bring back rare resources; later upgrades make them come more often).
- **Make buttons are earned**: a new batch button comes from an upgrade, not from the start. This is the pattern from now on. This stage adds no new batch buttons, and the ones already built stay as they are.
- **The Bees tab** lists every bee the hive has, what it does in the game, and a short real fact about it.

**In this build**: the seed roll; seed pacing; instant planting (beds commented out); many plants and their tiny bonuses; specialties from the first plant of a kind; the carpenter bee and wood; the four wood upgrades; the bee hotel and its rare bees; the meadow; the Bees tab and bee facts; words, Help, debug, tests.
**Not in this build** (later stages): the honey house, bottles of honey, paper labels, better frames, bee hotel upgrades past the first, new meadow plants, batch comb building, blooms, new buyers, the swarm. This stage does not retune old prices.

## Conflicts with what is already built
1. **Honey Supers move from Beebits to wood** *(settled, Bee, 2026-11-11: "honey supers will no longer cost beebits")*. Stage 7.5 built them as a repeatable Workbench row bought with Beebits only (+1,000 honey room each). They now cost **wood only**, so they need the carpenter bee, and they are wood's repeatable sink. Stage 7.5's reason for Beebits ("a player can always pay past a wall by selling honey") still holds for wax walls through the Wax Tray, which stays on Beebits. Today there are no honey walls (stage 7.5 found none), so nothing is stranded. Before the carpenter bee, honey room grows only from combs and Technologies. Supers already bought stay.
2. **Batch buttons already exist without an upgrade** *(settled, Bee, 2026-11-11)*. Herbal candles, bee bread and the wasps' paper trade have x10 and x100, each shown once the whole batch is affordable. The dipping rack was going to bring candles' Make 10; instead it **halves the wax of every candle**. So nothing moves behind an upgrade: the existing batch buttons stay exactly as they are, and "make buttons are earned" applies to new batch buttons from here on.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Hippies give seeds at random (Priority: P1)
1. **Given** a Hippie trade (one herbal candle), **Then** there is a **20% chance** *(placeholder)* it also gives a seed. A miss is a normal trade with nothing else changed.
2. **Given** a hit, **Then** the seed is one of the seeds unlocked so far, each with an **equal chance**.
3. **Given** Trade All, **Then** every candle is a trade and rolls on its own, so 30 candles give about 6 seeds. The log gives one line for the whole batch ("The Hippies tuck 6 seeds in with the Beebits."), not one per seed.
4. **Given** no seeds unlocked yet, **Then** there is no roll.
5. **Given** the first seed ever, **Then** the Garden appears, as today.

### User Story 2 - Seeds are paced by progress (Priority: P1)
1. **Given** a seed's unlock point, **Then** from that Hippie trade on, the seed joins the roll *(placeholders, today's give points)*: **wildflowers from trade 1, bramble from 40, the willow from 200, clover from 400**.
2. **Given** a seed joins the roll, **Then** the log says so once ("The Hippies have a new kind of seed: clover.").
3. **Given** the poplar, **Then** it stays the wasps' gift: from their **20th** trade, each wasp trade has a **20% chance** to give a poplar seed *(placeholders)*. A wasp batch counts as one trade and rolls once, as it counts today.

### User Story 3 - Plants grow at once (Priority: P1)
1. **Given** a seed in hand, **When** Plant is pressed, **Then** the plant is in the garden right away: no bed, no timer.
2. **Given** several seeds of one kind, **Then** the Garden card shows one row per kind with the count in hand ("Wildflower seeds ×12") and a Plant button that plants one. *(A batch Plant button would follow the earned-buttons rule; not in this build.)*
3. **Given** the Garden card, **Then** it lists each plant kind with how many are growing ("Wildflowers 23") and what they give.
4. **Given** a save with a seed still growing in a bed, **Then** on load it sprouts at once.

### User Story 4 - Many of each plant (Priority: P1)
1. **Given** the first plant of a kind, **Then** the hive gains its specialty at today's strength (wildflowers: foraging, 3 pollen a minute; bramble: guarding, +25% honey; the willow: nursing, the queen lays 50% faster; the poplar: resin, 1 propolis a minute; clover: foraging, 3 more pollen a minute).
2. **Given** more plants of the same kind, **Then** the specialty does not grow. 50 brambles give +25% honey once, not 1.25⁵⁰.
3. **Given** each plant after the first of its kind, **Then** it adds **+1%** *(placeholder)*, added up, never multiplied: wildflowers and bramble to **honey**, clover to **wax**, the willow to **wood**, the poplar to **propolis**. So 50 wildflowers add +49% honey.
4. **Given** a hover on honey, wax, wood or propolis, **Then** it lists the plant bonus with the count ("Wildflowers ×49: +49%"), as every growth hover does.
5. **Given** two kinds with the same specialty (wildflowers and clover both forage), **Then** each kind counts once: 6 pollen a minute, as today.

### User Story 5 - The carpenter bee and wood (Priority: P1)
1. **Given** the first willow is planted, **Then** the carpenter bee arrives, with a log line, and the Wood row appears.
2. **Given** the carpenter bee, **Then** wood comes in at **1 a minute** *(placeholder)* × (1 + 1% for each willow after the first), live and away, a straight line in time like pollen and propolis.
3. **Given** wood, **Then** it has no cap *(default)*.
4. **Given** wood is first held, **Then** the wood upgrades show in the Shop with a wood part in their price.

### User Story 6 - Wood upgrades (Priority: P1)
All in the Shop, needing the carpenter bee, each bought once *(prices placeholders)*:

| Upgrade | Price | Does |
|---|---|---|
| **Wooden Frames** | 50 wood | New combs cost **half the wax**, rounded down (combs only, not candles or anything else). Bee price unchanged. |
| **Candle Molds** | 30 wood | Every candle craft makes **2 candles** for one price (all three candle kinds). |
| **Dipping Rack** | 40 wood | Every candle costs **half the wax**, rounded down (herbal 10 → 5, bee-boost and sage-propolis 20 → 10). Other parts of the price don't change. |
| **Bee Hotel** | 100 wood | Rare bees come to stay and bring back rare resources (User Story 7). |

And one repeatable row, at The Workbench where it is today:

| Upgrade | Price | Does |
|---|---|---|
| **Honey Super** | **10 wood**, +50% each, rounded down *(was 75 Beebits, +50%)* | +1,000 honey room, as today. |

5. **Given** no carpenter bee yet, **Then** the Honey Super row is hidden (its price can't be paid). It appears with the first wood.

1. **Given** Wooden Frames, **Then** the comb row's wax price halves at once, and a wall that was only the comb's wax may go away by itself. The engine still never lowers a price *because of a wall*: this is a bought discount.
2. **Given** Candle Molds and the Dipping Rack, **Then** both apply: one herbal candle craft costs 5 wax and 1 herb and makes 2 candles.
3. **Given** the herbal candle's x10 and x100, **Then** they work as today, at the price of the moment (molds and rack included), shown once the whole batch is affordable.
4. **Given** the Dipping Rack, **Then** every candle's price text and any wax wall on a candle row update at once.

### User Story 7 - The bee hotel (Priority: P1)
1. **Given** the Bee Hotel, **Then** every **30 minutes** of time *(placeholder)*, live or away, one rare bee brings back a gift. Which bee, and so which gift, is picked at random.
2. **Given** the rare bees *(placeholders; real bees that nest in bee hotels)*:

   | Bee | Brings |
   |---|---|
   | **Mason bee** | 1 seed, from the seeds unlocked so far |
   | **Leafcutter bee** | 2 herbs |
   | **Wool carder bee** | 5 propolis |

   They bring things the game already has, so nothing new needs a use yet *(default; "rare resources" of their own are a later stage)*.
3. **Given** a rare bee's first gift, **Then** that bee joins the Bees tab, with a log line.
4. **Given** time away, **Then** the welcome-back message names the gifts. Many short stretches equal one long one: the number of gifts is set by time, and only which bee comes is random.
5. **Given** later upgrades *(not in this build)*, **Then** they shorten the 30 minutes. The interval is one config value so they are easy to add.

### User Story 8 - The meadow (Priority: P1)
1. **Given** at least 1 wildflower and 1 clover planted, **Then** the Hive card offers the meadow, with its price: **50 wildflowers and 50 clover** *(placeholder)*, showing how many you have ("Wildflowers 23 / 50").
2. **Given** enough of both, **When** the meadow is bought, **Then** the hive upgrades to a meadow. The plants move into the meadow and **keep working**: specialties and plant bonuses stay *(default)*.
3. **Given** the meadow, **Then** it works like one giant comb: it makes **5 honey a second** *(placeholder; 25 combs' worth)*, and adds **+25,000 honey room** and **+250 wax room** *(placeholders)*. Every honey boost applies to it as to the combs.
4. **Given** the meadow, **Then** it is bought once, the wooden hive and the queen stay, and the queen's laying doesn't change *(default)*.
5. **Given** the meadow, **Then** it takes no bees *(default; the old plan took "tons of bees")*.

### User Story 9 - The Bees tab (Priority: P1)
1. **Given** the hive has a bee, **Then** the Bees tab lists it with **what it does in the game** and **one short real fact**.
2. The list grows as bees come: **honeybees** (from the first bee caught), **the queen** (once settled), **the carpenter bee**, and each **rare bee** after its first gift.
3. **Given** the facts, **Then** each bee picks one from its own list at random each time the tab opens *(the lists are short for now; Bee adds more later)*.
4. **Given** the Notebook's notes on the specialties, **Then** they stay as they are *(default: the Bees tab is the bees; the Notebook is the specialties)*. Where the tab sits on screen follows today's Bees card.

### User Story 10 - Time away (Priority: P1)
1. **Given** any stretch, **Then** many 1-second `Advance` calls equal one `AdvanceAway`, now including wood, plant bonuses, the meadow's honey and both caps, and bee hotel gifts part-way (their count; which bee may differ, since that's random).

## Reveal order (additions)
| Trigger | Appears |
|---|---|
| First seed (by roll) | the Garden, as today |
| A seed's unlock point reached | it joins the roll; a log line |
| First willow planted | the carpenter bee; the Wood row; the Bees tab row |
| First wood | the four wood upgrades in the Shop |
| Bee Hotel bought | rare bee gifts begin |
| A rare bee's first gift | its Bees tab row |
| 1 wildflower and 1 clover planted | the meadow offer on the Hive card |

## Functional Requirements
- **FR-801**: Every number lives in `BeekeeperConfig`.
- **FR-802**: **The seed roll.** `HippieSeedChance` (0.2) and `WaspSeedChance` (0.2). `BeekeeperPlant.SeedAtTrade` keeps its name and now means "joins the roll at this trade" (say so in its comment). `GiveSeedsIfDue` is commented out and replaced by a roll per counted trade, using the engine's `IRandomSource` so tests can fix it. `SeedsGivenIds` keeps working as "seeds that have joined the roll" for the once-only log line, or a new `SeedsUnlocked` list replaces it; either way an older save's list must not block rolls.
- **FR-803**: **Instant planting.** `PlantSeed` adds the plant to `State.Plants` at once and raises the usual sprout events. `GrowBeds`, `BedCount`, `FreeBeds`, `IsGrowing`, `StartingBeds`, `ThirdBedBeds`, the Third Bed upgrade and every plant's `GrowSeconds` are commented out (`// Cut in stage 8 (spec 017): …`). `Work` no longer splits at sprouts. On load, any `State.Beds` entry sprouts at once and the list empties.
- **FR-804**: **Many plants.** `State.Plants` and `State.SeedsInHand` may hold an id many times. Add `PlantCount(id)`. Every specialty reads **distinct kinds**: `NursingMultiplier`, `GuardingMultiplier`, `ResinPropolisPerMinute` and `ForagingPollenPerMinute` take each plant kind once.
- **FR-805**: **Plant bonuses.** Each `BeekeeperPlant` gains `BonusTarget` (honey, wax, wood or propolis) and `BonusPerExtra` (0.01). The bonus is 1 + `BonusPerExtra` × max(0, count − 1), summed across kinds with the same target, and it multiplies that resource's rate. Honey's goes into the honey multiplier with the other boosts; wax's into the wax rate; wood's and propolis's into theirs. None depends on what is stored, so live and away still agree.
- **FR-806**: **The carpenter bee.** `State.CarpenterBeeCame` (sticky) is set when the first willow is planted. `State.Wood` (fractional; shown rounded down). `WoodPerMinute` in config. Wood is gathered in `Attract` beside pollen and propolis, so it is a straight line in time.
- **FR-807**: **Wood prices.** `BeekeeperUpgrade` gains `decimal Wood = 0m`, like `Paper`. The price text gains a wood part. The four upgrades are entries in `Config.Upgrades`, needing the carpenter bee.
- **FR-807a**: **Honey Supers on wood.** `HoneySuperBaseCost` becomes 10 (wood) and `HoneySuperCost` is a wood price; `CanBuyHoneySuper` and `BuyHoneySuper` read and spend `State.Wood`, not Beebits, and need the carpenter bee. The old Beebit price is commented out (`// Cut in stage 8 (spec 017): …`). `HoneySupers` levels already saved stay. The Wax Tray is untouched. The Workbench row shows a wood price.
- **FR-808**: **Wooden Frames.** `CombCost`'s wax part is multiplied by `FramesWaxMultiplier` (0.5) when owned, then rounded down. Nothing else's wax changes. Walls read the new price, as they read every price.
- **FR-809**: **Candle Molds.** Every `Craft…` method adds `CandlesPerCraft` (2 with the molds, else 1) per craft for one price. `CandlesCrafted` counts candles made.
- **FR-810**: **Dipping Rack.** One `CandleWax(decimal baseWax)` helper: × `RackWaxMultiplier` (0.5) when owned, rounded down. Every `CanCraft…`, `Craft…` and the price text read it, so batches and walls follow. Batch buttons are untouched.
- **FR-811**: **The bee hotel.** `HotelGiftSeconds` (1,800) and `State.HotelSecondsToNext`. In `Work`, a stretch that crosses the next gift splits there (as it split at sprouts), the gift is rolled, and the timer resets. Rare bees are config entries (id, gift kind, amount). `State.RareBeesMet` lists bees that have brought a gift. A seed gift picks from the seeds unlocked so far; with none unlocked, the mason bee brings herbs instead.
- **FR-812**: **The meadow.** `State.HasMeadow`. `MeadowWildflowers` and `MeadowClover` (50 each), `MeadowHoneyPerSecond` (5), `MeadowHoneyCap` (25,000), `MeadowWaxCap` (250). Plants are counted, not spent *(default)*. `HoneyPerSecond` adds the meadow to the combs before the multipliers; both caps add its room before the Technology multiplier. The offer is a Hive card row, on the pattern of `MoveToWoodenHive`.
- **FR-813**: **The Bees tab.** The view model exposes `BeesMet`, an ordered list of bee ids (honeybees, queen, carpenter bee, then rare bees in the order met). Each bee's words are a name, a "what it does" line and a list of facts in the workbook. The view picks a fact at random.
- **FR-814**: **Save.** New fields load as empty or zero (as story cards did), so no version bump is needed: `Wood`, `CarpenterBeeCame`, `HotelSecondsToNext`, `RareBeesMet`, `HasMeadow` (plus `SeedsUnlocked` if used). Beds on load: FR-803. Sanity checks: no negative wood or timer.
- **FR-815**: **Comment out, don't delete.** Beds, grow times, the Third Bed, `GiveSeedsIfDue` and the once-each seed rule, and the bed rows on the Garden card. Their words stay in the workbook.
- **FR-816**: **Words** through `tools/Honeycomb_Localization.xlsx` (English + Spanish draft) with a small openpyxl script, then `python tools/generate_localization.py`. Help: Garden (no beds, no waiting, many plants, seed roll), the Shop (wood), the meadow, the Bees tab.
- **FR-817**: **Debug menu.** Add **"+10 of every seed"**, **"+50 wildflowers and +50 clover planted"**, **"+100 wood"**, **"Summon the carpenter bee"** and **"Bee hotel gift now"**. "Give seed" and "Give every seed" become "unlock the next seed" and "unlock every seed".

## Placeholder numbers (all in `BeekeeperConfig`)
| Setting | Value |
|---|---|
| `HippieSeedChance` / `WaspSeedChance` | 0.2 / 0.2 |
| Seed unlock trades (`SeedAtTrade`) | wildflowers 1 (was 5), bramble 40, willow 200, clover 400; poplar 20 wasp trades |
| `BonusPerExtra` (every plant) | 0.01 |
| `WoodPerMinute` | 1 |
| Wooden Frames / Candle Molds / Dipping Rack / Bee Hotel | 50 / 30 / 40 / 100 wood |
| `HoneySuperBaseCost` / `HoneySuperCostGrowth` | 10 wood / 1.5 (was 75 Beebits / 1.5) |
| `FramesWaxMultiplier` | 0.5 |
| `CandlesPerCraft` with molds | 2 |
| `RackWaxMultiplier` (candle wax) | 0.5 |
| `HotelGiftSeconds` | 1,800 (30 min) |
| Rare bee gifts | mason bee 1 seed; leafcutter 2 herbs; wool carder 5 propolis |
| `MeadowWildflowers` / `MeadowClover` | 50 / 50 |
| `MeadowHoneyPerSecond` / `MeadowHoneyCap` / `MeadowWaxCap` | 5 / 25,000 / 250 |

**Pacing, roughly:** clover joins the roll at trade 400, and from then on 1 trade in 20 gives clover (20% × 1 of 4 kinds). The meadow needs about 1,000 more trades after that, unless the mason bee helps. Whether that's days or weeks depends on candle trades a day; the simulator (`Beekeeper/tools/simulate_first_hour.py`) should be extended with the roll before tuning.

## To-dos for later stages
1. **More uses for wood** past Honey Supers: bee hotel upgrades, better frames and building upgrades belong here.
2. **Free bees still have no sink**, now that the meadow costs plants. Batch comb building or a later purchase belongs here.
3. **Time away still tops out at a few hours of honey**: the honey house.
4. **Rare resources of their own** for the bee hotel's bees, once there is something to spend them on.
5. **More bee facts** for every bee (Bee).

## Draft story-log lines *(English; Bee to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Seed from the Hippies (one) | "The Hippies tuck a {plant} seed in with the Beebits." |
| Seeds from a batch | "The Hippies tuck {n} seeds in with the Beebits." |
| A seed joins the roll | "The Hippies have a new kind of seed: {plant}." |
| Poplar seed from the wasps | "The wasps leave a poplar seed with the paper." |
| Planted | "You plant the {plant}. It's growing already." |
| Carpenter bee | "A carpenter bee has moved into the willow. It's bringing back wood." |
| Wooden Frames | "The new combs get wooden frames. They need half the wax." |
| Candle Molds | "Wooden molds: two candles at a time." |
| Dipping Rack | "A dipping rack. The candles come out thinner, and need half the wax." |
| Bee Hotel | "You hang up a bee hotel. Maybe someone will move in." |
| Rare bee, first gift | "A {bee} has moved into the bee hotel, and brought you {gift}." |
| Rare bee, later gifts | "The {bee} brings back {gift}." |
| Meadow | "The hive spreads into the meadow. Wildflowers and clover as far as you can see." |
| Welcome back (gifts) | "The bee hotel's guests left {gifts}." |

## Draft bees and facts *(English; Bee to check and edit)*
| Bee | What it does | Fact |
|---|---|---|
| Honeybees | Caught by hand; free bees make wax and pay for combs. | A worker honeybee makes about a twelfth of a teaspoon of honey in her whole life. |
| The queen | Lays new honeybees when there is bee bread. | A queen can lay well over a thousand eggs a day in summer. |
| Carpenter bee | Brings back wood. | Carpenter bees don't eat wood. They chew tunnels in it to raise their young. |
| Mason bee | Brings back a seed. | Mason bees seal each nest cell with a wall of mud. |
| Leafcutter bee | Brings back herbs. | Leafcutter bees line their nests with neat circles cut from leaves. |
| Wool carder bee | Brings back propolis. | Wool carder bees comb the fuzz off leaves to line their nests. |

## Tests
- Fix the roll with a test `IRandomSource`: a hit gives a seed, a miss gives nothing else, only unlocked seeds come, Trade All rolls per candle, the poplar rolls on wasp trades from 20.
- Planting is instant; an old bed sprouts on load.
- Specialties count kinds: 2 brambles give +25%, not +56%; wildflowers + clover give 6 pollen a minute.
- Plant bonuses: 50 wildflowers give +49% honey; the hover sources match.
- The carpenter bee comes with the first willow; wood is a straight line; willow bonus applies.
- Honey Supers: cost wood and no Beebits, hidden before the carpenter bee, price grows per level, saved levels kept; the Wax Tray still costs Beebits. Update the stage 7.5 Honey Super tests.
- Each wood upgrade: frames halve the comb's wax (rounded down) and nothing else; molds double candles; the rack halves every candle's wax (rounded down) and nothing else; molds and rack together; herbal x10 and x100 use the price of the moment.
- Bee hotel: gifts every 30 minutes live and away; FR-811's split; the first gift adds the bee to `RareBeesMet`.
- The meadow: offered after 1 of each; not affordable at 49; plants are kept; honey and both caps go up; boosts apply to it.
- FR-814: an older save (no new fields) loads.
- Live and away agree (User Story 10).
- Existing tests that use beds, grow times, `GiveSeedsIfDue`, or the Third Bed: comment out with `// Cut in stage 8` and add a test of the new rule.

## Decided (Bee, 2026-11-11)
Every bullet under "Why now", and the placeholders in "Placeholder numbers" that were agreed in planning (the seed points, the 20% rolls, the poplar from the wasps, beds cut, +1% per extra plant, 1 wood a minute).

## Defaults taken in writing the spec (easy to change)
1. Honey Supers: 10 wood to start, +50% each (Bee settled wood; the numbers are placeholders).
2. The dipping rack halves the wax of all three candle kinds; existing batch buttons stay.
3. Plants move into the meadow and keep working; the meadow takes no bees.
4. Wood has no cap.
5. Rare bees bring things that already exist (a seed, herbs, propolis).
6. Gifts come on a timer, and only which bee comes is random.
7. Candle Molds double all three candle kinds.
8. The Bees tab holds the bees; the Notebook keeps the specialties.
9. Wildflowers join the roll from the first Hippie trade (was given at trade 5).
10. All wood prices, the meadow's rates and the gift timer.

## Success Criteria
- **SC-801**: Every acceptance scenario has an engine or view-model test; Bee has hand-test steps with debug shortcuts.
- **SC-802**: Live and away agree with wood, plant bonuses, the meadow and hotel gifts.
- **SC-803**: No screen text mentions beds or waiting for a seed to grow.
- **SC-804**: No specialty grows past its first plant of a kind.
- **SC-805**: A stage 7.5 save loads without losing anything; a growing bed sprouts.

## Hand-test (Bee) — debug build, Banners menu in the toolbar
1. Start a new game and get to the Hippies. Trade candles one at a time: now and then a seed comes, and most trades give only Beebits.
2. **Trade All** with plenty of candles: one log line names how many seeds came.
3. Plant a seed: it's in the garden at once. No beds, no timer.
4. **+10 of every seed**, plant them all. Pollen is 6 a minute (wildflowers and clover count once each). The honey hover lists "Wildflowers ×9: +9%" and the bramble's bonus; guarding is still +25%.
5. Plant a willow: the carpenter bee arrives, the Wood row appears, and the Bees tab gains a row with a fact.
6. **+100 wood**. Buy a Honey Super with wood: the honey cap rises, Beebits don't change, and the next one costs more wood. Buy Wooden Frames: the comb's wax price halves. Buy Candle Molds: one craft makes 2. Buy the Dipping Rack: every candle's wax price halves (herbal 10 → 5), and one craft still makes 2.
7. Buy the Bee Hotel and use **Bee hotel gift now** a few times: rare bees bring a seed, herbs or propolis, and each joins the Bees tab.
8. **+50 wildflowers and +50 clover planted**: buy the meadow. Honey a second jumps and both caps grow. The plants are still there.
9. Spend 8 hours away: wood, hotel gifts and the meadow's honey are all in the welcome-back message.
10. Close and reopen: seeds, plants, wood, the carpenter bee, the hotel's guests and the meadow are all still there.
