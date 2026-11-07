# Feature Specification: Beekeeper, stage 6: specialties and the wasp emissary

**Feature Branch**: `014-beekeeper-specialties`
**Created**: 2026-11-07
**Status**: Draft v1 (2026-11-07), from Leah's decisions in the planning session. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009 (first build), 010 (Workbench, candles, wasps), 011 (tools, slice, Smoker), 012 (Garden, foragers, guards, pollen, bee bread, wooden hive), 013 (queen, pantry, slice cap, trade agreement).

**Why now**: with no bee limit, counts of forager and guard bees mean nothing; the Hive card is a long flat list that can't take many more stages; and the wasps have no ending, so No Stress Mode was their only off switch. Leah's answers (2026-11-07):
- **Plants give the hive a specialty, not a count of bees.** Wildflowers give foraging (steady pollen); bramble gives guarding, "the hive feels safe" (a production boost).
- **The emissary comes after 5 bribes in total.** Raids stop for good; the wasps become a trading partner who swaps paper for honey.
- **No Stress Mode no longer applies to Beekeeper** (it still applies to the other games).
- **Raids take only honey from now on**, never bees.
- **Repellent candles go once the emissary has come.** The growing wasp threat (gangs, bullies, horde, shoe upgrades) is dropped.
- **Comment out, don't delete**: everything cut here stays in the code, commented out, so it can come back.

**In this build**: specialties (foraging, guarding); old saves' bee counts turned into specialties; the Hive card in groups; raids that take only honey; the bribe count and the emissary; the wasps on the Trading card (reputation, honey for paper); paper; repellent candles retired after the emissary; No Stress Mode ignored by Beekeeper.
**Not in this build**: more seeds and several plants growing at once, nursing, the poplar, resin and propolis, uses for paper, the wasps' reputation giving anything beyond paper (all stage 7); the meadow and the honey house (stage 8).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Foraging (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the wildflowers have sprouted, **Then** the hive has the **foraging** specialty and gathers **3 pollen a minute** *(placeholder)*, steadily, live and while away (up to the 3-day limit). It does not grow over time.
2. **Given** foraging, **When** the player hovers the **Pollen** row, **Then** it shows pollen per second (e.g. "+0.05 pollen/s").
3. **Given** the plant data, **Then** the pollen rate belongs to the plant's specialty in config, so a later plant or bloom can add to it without new rules. (3 a minute is chosen to beat the queen's 2 pollen a minute, so the pantry can be kept up.)
4. **Given** the wildflowers sprout part-way through a stretch of time, **Then** pollen counts only from the moment they sprouted (as today).

### User Story 2 - Guarding: "the hive feels safe" (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the bramble has sprouted, **Then** the hive has the **guarding** specialty and every honeybee makes **25% more honey** *(placeholder)*. It multiplies with the wooden hive (1.25 × 1.25). Wax follows the honey, as always.
2. **Given** guarding, **Then** it counts live and while away the same (it is a lasting effect, not a live-only boost like the Smoker).
3. **Given** guarding, **When** the player hovers **Honey**, **Then** the honey-per-second shown includes it.
4. **Given** a raid, **Then** guarding plays no part in it (see User Story 4).

### User Story 3 - Old saves: counts become specialties (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a save from stage 4 or 5 with wildflowers and/or bramble, **When** it loads, **Then** it has the foraging and/or guarding specialty. The forager and guard counts are no longer used or shown.
2. **Given** such a save, **Then** pollen, bee bread, seeds, plants, a seed still growing (with its time left), the queen and everything else are unchanged.
3. **Given** such a save, **Then** the log says once: **"The foragers and guards settle into the hive's daily work."** (only if the save had either count above zero).
4. **Given** a save from stages 1 to 3, **Then** it loads with nothing lost, as before.
5. **Given** bribes were never counted before, **Then** old saves start at 0 bribes toward the emissary.

### User Story 4 - Raids take only honey (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a wasp raid (the countdown ran out, or a thrown shoe missed), **Then** it takes honey (3 minutes' worth, as today) and **no bees fly off**, with or without guarding.
2. **Given** a raid, **Then** the log says: **"The wasp helps itself to {honey} honey."** The bees-fly-off line and the "guards keep every bee safe" line are commented out, not deleted.
3. **Given** the shoe, a bribe or a candle, **Then** they still save the honey, as today.

### User Story 5 - Counting bribes (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player bribes a wasp, **Then** the total bribe count goes up by one (in total, not in a row; throws, candles and raids in between don't reset it).
2. **Given** the **3rd** bribe *(placeholder)*, **Then** the log adds a hint: **"The wasp pockets the honey. It seems to be taking notes."**
3. **Given** the bribe cost, **Then** it stays 25% of stored honey (at least 1) *(placeholder)*.

### User Story 6 - The emissary (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the **5th** bribe in total *(placeholder)*, **Then** the wasp leaves as usual and, straight after, the log says: **"The wasp nest sends an emissary. 'No more raids. We make paper, you make honey. Shall we trade?'"** It happens on its own; there is no button to press.
2. **Given** the emissary has come, **Then** **no wasp ever comes again**: no wasp timer, no countdown, no raids, and the Wasp card never shows.
3. **Given** the emissary has come, **Then** the Trading card shows **The Wasps** (below the bear and the Hippies) with their trade count (their reputation) and one trade (User Story 7).
4. **Given** a save loaded with 5 or more bribes but no emissary (shouldn't happen, but for safety), **Then** the emissary comes on load, with its log line.

### User Story 7 - Paper (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the wasps on the Trading card, **Then** they offer **50 honey for 1 paper** *(placeholder)*, with **x10** and **x100** buttons hidden until affordable (the batch standard).
2. **Given** a trade, **Then** honey goes down, paper goes up, and the wasps' trade count goes up by one per click (a x10 trade counts as 1, like Sell All).
3. **Given** paper, **Then** it shows on the Hive card under Trade goods. Paper doesn't change on its own, so it has no hover rate.
4. **Given** paper, **Then** it has no use yet (stage 7). The Help paragraph says the wasps' paper "will be useful soon".

### User Story 8 - Repellent candles retire after the emissary (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the emissary has come, **Then** the repellent candle recipe at The Workbench, the **Light a repellent candle** button, the **Repellent candles** row on the Hive card and the **Stronger Candles** upgrade in the Shop (if not bought) are all hidden.
2. **Given** a repellent candle was burning, **Then** it simply stops mattering (there are no more wasps).
3. **Given** leftover repellent candles, **Then** they stay in the save, unseen, so they can come back later; nothing is refunded.
4. **Given** beeswax candles, **Then** nothing changes (the Hippies still buy them).
5. All of this is done by hiding, with the code kept (commented out where it is removed).

### User Story 9 - The Hive card, in groups (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the Hive card, **Then** its rows are in groups, each with a small heading:

   | Group | Rows |
   |---|---|
   | **Bees** | Honeybees, Queen, one row per specialty (e.g. "Foraging: 3 pollen a minute", "Guarding: the hive feels safe, +25% honey") |
   | **The hive** | Honey, Wax, Combs (and the "full" line) |
   | **Garden** | Seeds, Pollen, Bee bread |
   | **Crafts** | Beeswax candles, Repellent candles |
   | **Trade goods** | Beebits, Sage, Paper |

2. **Given** a group with no row showing yet, **Then** its heading is hidden too.
3. **Given** the title ("A WOODEN HIVE IN THE GARDEN") and the move-hive row, **Then** they stay where they are (title on top, move row at the bottom).
4. **Given** later stages, **Then** a new row is one new entry in a group list in the view model, not another hand-placed row in the screen (FR-505).
5. **Given** the existing hover rates (honey, wax, bees, bee bread), **Then** they still work.

### User Story 10 - The Garden card says what each plant gives (Priority: P2)
1. **Given** a sprouted plant, **Then** the Garden card shows the plant and its specialty: **"Wildflowers: foraging. A steady trickle of pollen."** and **"Bramble: guarding. The hive feels safe and makes more honey."**
2. **Given** the sprout log lines, **Then** they change to: **"Wildflowers! The hive takes up foraging."** and **"A bramble! The hive feels safe behind its thorns."**

### User Story 11 - No Stress Mode no longer applies to Beekeeper (Priority: P1)
1. **Given** No Stress Mode is on, **Then** wasps still come in Beekeeper (during active play only, as always) until the emissary. The check is commented out, not deleted.
2. **Given** No Stress Mode, **Then** the other six games behave exactly as before.
3. **Given** Help, **Then** the Beekeeper paragraph drops "No Stress Mode in Options keeps wasps away", and the No Stress Mode description (Help and Options, if it mentions Beekeeper) no longer mentions it.

### User Story 12 - Saving (Priority: P1)
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** the specialties (derived from the plants), the bribe count, the emissary, the wasps' trade count and paper are restored.
2. **Given** saves from stages 1 to 5, **Then** they load with nothing lost that matters (User Story 3).

## Reveal order (adds to earlier tables)
| Trigger | Appears |
|---|---|
| Wildflowers sprout (or loaded with them) | Foraging row in Bees; pollen |
| Bramble sprouts (or loaded with it) | Guarding row in Bees |
| 3rd bribe | the hint in the log |
| 5th bribe | the emissary; The Wasps on the Trading card; wasps stop; repellent candles retire |
| First paper | Paper row in Trade goods |

## Functional Requirements
- **FR-501**: Every number (foraging pollen per minute, guarding honey multiplier, bribes for the hint, bribes for the emissary, honey per paper) lives in `BeekeeperConfig`.
- **FR-502**: **Plants are data with a specialty.** `BeekeeperPlant` gets a specialty id and a strength (pollen per minute for foraging, honey multiplier for guarding) in place of the bee kind and bees per minute; the old fields are commented out. Specialty ids go in a `BeekeeperSpecialties` class (`Foraging`, `Guarding`); `BeekeeperBees.Forager`/`Guard` are commented out. Several plants of the same specialty add up (pollen) or multiply (honey), so stage 7 only adds entries.
- **FR-503**: Pollen is now a straight line in time (rate × seconds), still worked out in one step for any span, split where a seed sprouts. Guarding goes into `HiveMultiplier` (or next to it) so `HoneyPerSecond`, `Produce`, the queen's growing-hive formula, the raid size and the hover rates all see it.
- **FR-504**: **Live and away agree.** Extend the equality test: foraging and guarding, with a laying queen, many 1-second `Advance` calls equal one `AdvanceAway`.
- **FR-505**: The Hive card is built from a list of groups of rows in the view model (label, value, visible, optional hover text). The screen draws the list. The old named rows are removed from the screen markup; keep the commented-out Forager and Guard rows nowhere visible (comment them out in the view model, not the markup).
- **FR-506**: Raids: the bees-fly-off part (`RaidBeeShare`, `HasGuards`) is commented out; a raid's event carries honey only.
- **FR-507**: The emissary: once it has come, `AdvanceWaspTime` and `DebugCallWasp` do nothing and any approaching wasp is ended. No Stress Mode is no longer read by the Beekeeper view model (comment out the check; keep the constructor parameter or comment it out, whichever keeps tests simplest).
- **FR-508**: Save version 6. `ForagerBees` and `GuardBees` are still read (so old files load) but not used; mark them obsolete in a comment. New saved fields: bribes in total, emissary come, wasp trades, paper, "old counts announced" (so the load line shows once). Sanity checks: no negative paper, bribes or trades.
- **FR-509**: New words through the localization workbook (English + Spanish draft) and the generator; Help's Garden and Workbench paragraphs updated (specialties, raids take only honey, bribes bring the emissary, paper); no betting or gambling words; bees "fly off", never die.
- **FR-510**: Debug menu: **"Bribes to 4"** (one more bribe brings the emissary), **"Bring the emissary"** (at once), **"+500 honey"** if not already there (to try the paper trade). The existing "Call a wasp", "Give a seed", "Finish growing", "+10 pollen" and "Spend 8 hours away" stay.

## Key Entities (additions)
Specialty (foraging, guarding; derived from the sprouted plants, not saved), Bribes in total (saved), Emissary come (saved), Wasp trades (saved), Paper (saved), Old counts announced (saved).

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Old save loaded | "The foragers and guards settle into the hive's daily work." |
| Wildflowers sprout | "Wildflowers! The hive takes up foraging." |
| Bramble sprouts | "A bramble! The hive feels safe behind its thorns." |
| Raid | "The wasp helps itself to {honey} honey." |
| 3rd bribe | "The wasp pockets the honey. It seems to be taking notes." |
| Emissary | "The wasp nest sends an emissary. 'No more raids. We make paper, you make honey. Shall we trade?'" |
| First paper | "The wasps hand over a sheet of paper, thin and grey and strong." |

## Decided (Leah, 2026-11-07)
1. Specialties, not counts: wildflowers give foraging (steady pollen), bramble gives guarding (a production boost). Guarding no longer protects bees.
2. Old saves: the counts become specialties.
3. The Hive card in groups so it can grow.
4. The emissary after 5 bribes in total; raids stop; the wasps' reputation and the paper trade.
5. No Stress Mode no longer applies to Beekeeper.
6. Raids take only honey from now on.
7. Repellent candles are dropped after the emissary.
8. The wasps trade paper for honey.
9. The growing wasp threat (gangs, bullies, horde, shoe-throw upgrades) is dropped.

## Still open (placeholders in place; none blocks building)
1. Foraging 3 pollen a minute; guarding +25% honey; 50 honey per paper; bribe cost 25%; the hint at the 3rd bribe.
2. What paper is for and what the wasps' reputation gives beyond paper (stage 7).

## Success Criteria
- **SC-501**: Every acceptance scenario has an engine or view-model test; Leah has hand-test steps with debug shortcuts.
- **SC-502**: Live and away agree with foraging, guarding and a laying queen.
- **SC-503**: Saves from stages 1 to 5 load with nothing lost that matters.
- **SC-504**: After the emissary, no wasp ever appears, with No Stress Mode on or off.

## Hand-test (Leah) — debug build, Banners menu in the toolbar
1. Load your current game. The log says the foragers and guards settled into the hive's work. The Hive card is in groups (Bees, The hive, Garden, Crafts, Trade goods); there are no Forager bees or Guard bees rows; Bees shows Foraging and Guarding.
2. Hover **Pollen**: about +0.05/s. Hover **Honey**: higher than before if you have the bramble.
3. **Skip 10 minutes**: pollen goes up by about 30, the same every time (not faster and faster).
4. Turn **No Stress Mode** on in Options, then **Call a wasp**: it still comes. Let it raid: the log says only honey was taken, and the bee count doesn't drop.
5. **Call a wasp** and bribe it until the 3rd bribe: the log hints the wasp is taking notes.
6. **Bribes to 4**, **Call a wasp**, bribe once more: the emissary's line appears. The Trading card shows The Wasps; the repellent candle recipe, its Hive row, the light button and Stronger Candles (if not bought) are gone.
7. **Call a wasp**: nothing comes. Play a few minutes: no wasps.
8. With 500+ honey, trade for paper (x10 appears once you have 500): Paper shows under Trade goods and the wasps' trade count goes up.
9. **Spend 8 hours away**: about 1,440 pollen added.
10. Close and reopen: the specialties, the emissary, the wasps' trades and paper are still there; still no wasps.
11. Switch to Klondike with No Stress Mode on: it behaves as before (no timer).
