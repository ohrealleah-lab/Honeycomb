# Feature Specification: Beekeeper, stage 2: The Workbench, candles, Hippies and the first wasps

**Feature Branch**: `010-beekeeper-workbench`
**Created**: 2026-11-07
**Status**: Draft v1. Every **[DECIDE n]** below is a proposal from Claude, waiting for Leah. The numbered list at the end collects them.
**Platform**: Windows only (Windows is the reference for Beekeeper until Mac exists).
**Builds on**: `windows/009-beekeeper/` (the first build: catch, honey, wax, bear, shop, combs, saving, offline).

**Sources** (Leah's notes win; the archived drafts in `Beekeeper/archive/` are not used):
- `Beekeeper/LONG_TERM_DESIGN.md`, stage 4 (candles, The Workbench, Hippies) and stage 6 (wasps, throw a shoe), Leah's notes of 2026-11-07
- `Beekeeper/EARLY_LOOP_RULES.md` for the first build's numbers

**Order note**: in `LONG_TERM_DESIGN.md` the Smoker (stage 2) and hive roles (stage 3) come before candles. Leah chose to build The Workbench next, so this spec does not depend on either. Guards (a hive role) are therefore not a wasp defence yet. **[DECIDE 1]** Confirm: build The Workbench before the Smoker and hive roles.

**In this build**: The Workbench (crafting and upgrades in one place), the beeswax candle, the wasp-repellent candle, the Hippies, sage, single wasps, throw a shoe, No Stress Mode for wasps.
**Not in this build**: wasp gangs, bullies and the horde; throw upgrades that hit more than one wasp (they only matter against gangs); the bee-boost candle; propolis and the bee upgrades that gather it; bribes; guards; the bears' 100-trade wasp perk; other buyers (Hummingbirds, Badgers); the Smoker; hive roles.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Workbench opens (Priority: P1)
After the second comb, a Workbench card appears where the player crafts candles (and, later, buys upgrades).

**Acceptance Scenarios**:
1. **Given** the player builds their 2nd comb, **Then** The Workbench card appears and stays for the rest of the game (saved), and the log says so.
2. **Given** an existing save from the first build with 2 or more combs already, **When** it is loaded, **Then** The Workbench is already open (no need to build another comb).
3. **Given** fewer than 2 combs, **Then** The Workbench is not shown and nothing in it can be used.

### User Story 2 - Craft candles (Priority: P1)
**Acceptance Scenarios**:
1. **Given** The Workbench and at least 10 wax, **When** "Make a beeswax candle" is pressed, **Then** wax drops by 10 and beeswax candles rise by 1, at once (crafting is instant).
2. **Given** less than 10 wax, **Then** the craft buttons are unavailable and pressing them does nothing.
3. **Given** The Workbench, **When** "Make a wasp-repellent candle" is pressed with at least 10 wax, **Then** wax drops by 10 and repellent candles rise by 1. **[DECIDE 2]** Proposal: the repellent candle also costs 10 wax and is available from the start, alongside the beeswax candle. (Leah: "first candles are 10".)
4. **Given** the player has crafted candles, **Then** the Hive card shows a row for each candle type the player has ever held (Beeswax candles, Repellent candles).
5. **Given** any number of candles crafted, **Then** there is no storage limit on candles.

### User Story 3 - The Hippies trade sage for candles (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player has crafted 5 candles in total (any type, counted for the whole game), **Then** the Hippies panel appears and stays (saved), and the log says they have arrived.
2. **Given** 10 or more beeswax candles, **When** "Trade 10 candles" is pressed, **Then** beeswax candles drop by 10 and sage rises by 1.
3. **Given** 27 beeswax candles, **When** "Trade all" is pressed, **Then** sage rises by 2 and 7 candles are kept. **[DECIDE 3]** Proposal: a "Trade all" button like the bear's Sell All.
4. **Given** fewer than 10 beeswax candles, **Then** both trade buttons are unavailable.
5. **Given** the Hippies, **Then** they never take repellent candles.
6. **Given** the player first gets sage, **Then** a Sage row appears on the Hive card and stays.
7. **[DECIDE 4]** What sage is for in this build. Workbench upgrades cost sage, but no upgrade list exists yet. Proposal: sage is collected in this build and spent once the first upgrades are decided (see Story 6).

### User Story 4 - Wasps come by (Priority: P1)
Wasps are a gentle nuisance during active play only.

**Acceptance Scenarios**:
1. **Given** The Workbench has opened, Beekeeper is on screen, the player is active, No Stress Mode is off and no repellent candle is burning, **When** enough time passes, **Then** a single wasp arrives. **[DECIDE 5]** Proposal: one wasp every 4 to 8 minutes of eligible time (random within that range).
2. **Given** a wasp arrives, **Then** a Wasp panel appears in the right column with a "Throw a shoe" button and a calm countdown, and the log notes the wasp. **[DECIDE 6]** Proposal: the player has 15 seconds to respond (slow, not twitchy).
3. **Given** the countdown runs out with no throw, **Then** the wasp raids: it takes some honey and some bees fly off (nobody is hurt), and the log says what was lost.
4. **Given** any raid, **Then** what it costs is small: never more than about 10 minutes of play to earn back at the player's current rate. **[DECIDE 7]** Proposal (placeholders for the simulator): a raid takes up to 3 minutes' worth of honey production (never more than is stored) and 2% of the bees, rounded down. A hive with no honey loses only bees.
5. **Given** the player switches to another Honeycomb game, minimises the window, or the app is closed, **Then** no wasp arrives and the wasp timer does not run. **[DECIDE 8]** Proposal: "active" means Beekeeper is on screen and the player clicked or pressed a key in Beekeeper in the last 5 minutes.
6. **Given** a wasp is approaching when the player leaves Beekeeper or goes idle, **Then** the wasp leaves without raiding. (Raids only happen while the player can respond.)
7. **Given** the app is closed, **Then** away earnings are never reduced by wasps.

### User Story 5 - Throw a shoe and light a candle (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a wasp is approaching, **When** "Throw a shoe" is pressed, **Then** there is a 60% chance it hits (the wasp is driven off, nothing is lost) and a 40% chance it misses.
2. **Given** a miss, **Then** the wasp raids at once (Story 4, scenario 4), and the log makes it light ("Missed. The wasp helps itself."). One throw per wasp.
3. **Given** the shoe, **Then** it is free and can be thrown at every wasp; the 40% miss chance never changes in this build.
4. **Given** at least one repellent candle, **When** "Light a repellent candle" is pressed, **Then** one candle is used and no wasp arrives while it burns. The Hive card or Wasp panel shows the time left.
5. **Given** a wasp is already approaching, **When** a repellent candle is lit, **Then** that wasp leaves at once without raiding.
6. **Given** a candle is burning, **Then** its time only counts down while wasps could come (Beekeeper on screen, player active, No Stress Mode off), so it is never wasted while the player is away. **[DECIDE 9]** Proposal: one candle burns for 15 minutes of that time.
7. **Given** a candle is burning, **When** another is lit, **Then** the time adds up.
8. **Given** the randomness, **Then** it goes through the injectable random source so tests are deterministic.

### User Story 6 - Workbench upgrades (Priority: P2)
**Acceptance Scenarios**:
1. **Given** The Workbench, **Then** it has an Upgrades area. Each upgrade has a name, what it does, and a cost made of one or more resources (Beebits, wax, sage), and may be locked until another upgrade is bought.
2. **Given** an upgrade the player cannot afford or that is still locked, **Then** it is shown but unavailable; a locked one says which upgrade it needs. Bought upgrades show "✓ Owned".
3. **Given** a purchase, **Then** every resource in its cost is taken at once, or nothing is taken.
4. **[DECIDE 10]** The first upgrades. None are decided yet, and throw upgrades only matter against gangs. Proposal: build the upgrade machinery (mixed costs, locks, saving, tests) with **one to three upgrades from Leah**, or ship this build with candles only and add upgrades in the next spec. Ideas, if wanted: a beeswax-candle mould (2 candles per 10 wax), a better wick (repellent candles burn longer), a sturdier boot (miss chance stays 40%, but a miss costs less).

### User Story 7 - No Stress Mode (Priority: P1)
**Acceptance Scenarios**:
1. **Given** No Stress Mode is on (the existing Options setting), **Then** no wasps arrive and none raid, and the wasp timer does not run.
2. **Given** a wasp is already approaching when No Stress Mode is turned on, **Then** it still plays out (throw or raid); only future wasps are stopped.
3. **Given** No Stress Mode is turned on or off, **Then** nothing is reset, lost or gained: candles, sage, upgrades and burning time stay as they were (a burning candle simply pauses while No Stress Mode is on).
4. **Given** No Stress Mode, **Then** candles can still be crafted and traded, and the Workbench still works.

### User Story 8 - Saving and old saves (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** candles of each type, total candles crafted, sage, Workbench and Hippie reveals, upgrades owned, candle burn time left and the wasp timer are restored. An approaching wasp is not saved (it leaves).
2. **Given** a save from the first build, **When** it is loaded, **Then** it upgrades cleanly: all new amounts start at 0, and The Workbench opens if 2 or more combs are already built.
3. **Given** a save from a newer version, **Then** the existing safe fallback applies.

## Reveal order (adds to the first build's table)
| Trigger | Appears |
|---|---|
| 2nd comb built (or loaded with 2+ combs) | The Workbench; wasps can start coming |
| First candle crafted | that candle's row on the Hive card |
| 5 candles crafted in total | the Hippies panel |
| First sage | Sage row on the Hive card |
| First wasp | Wasp panel (right column); hidden again when no wasp is around and no candle is burning |

## Functional Requirements
- **FR-101**: All rules stay in the view-independent engine with no clock: crafting, trading, upgrades, and the wasp timer advance only through "advance by N seconds of eligible time" calls. The view model decides what counts as eligible time (on screen, active, No Stress Mode off).
- **FR-102**: Every new number (candle costs, Hippie rate, wasp interval, countdown, hit chance, raid size, candle burn time, idle limit, the Workbench's comb requirement, the 5-candle Hippie trigger) lives in `BeekeeperConfig`.
- **FR-103**: All randomness (wasp timing, throw hit/miss) uses the injectable random source.
- **FR-104**: Away time (`AdvanceAway`) never creates wasps, raids, or burns candle time.
- **FR-105**: The save format gets a new version; old saves load with defaults (Story 8). Saving still goes through `AtomicFile`.
- **FR-106**: Every visible string goes through the localization workbook (English and Spanish draft) and the generator. The Help page gets The Workbench, candles, Hippies and wasps.
- **FR-107**: Text stays free of betting or gambling words (FR-009 from the first build). "Chance to miss" is fine in Help; avoid "odds", "bet", "jackpot". Wasps "fly off" or "are driven off"; nothing is killed, and bees "fly off", never die.
- **FR-108**: The Hive card is where all materials are tracked: candle types and sage get rows there (Leah, 2026-11-07).
- **FR-109**: The story log saves event keys plus values, as before, so new lines re-translate on a language change.
- **FR-110**: Layout: The Workbench and the Hippies go in the centre column (the space kept for the Workshop); the Wasp panel goes in the right column (the space kept for wasps).

## Key Entities (additions)
Candles (beeswax count, repellent count, total ever crafted), Sage, Workbench (revealed, upgrades owned), Hippies (revealed, trades), Wasp (approaching or not, countdown; not saved), Wasp timer (eligible seconds until the next wasp), Repellent burn time left.

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Workbench opens | "You clear a space for a workbench." |
| Beeswax candle made | "A beeswax candle. It smells of summer." (first one only) |
| Repellent candle made | "A candle that wasps can't stand." (first one only) |
| Hippies arrive | "A van rolls up. The Hippies love your candles." |
| Candles traded | "The Hippies hand over a bundle of sage." |
| Wasp arrives | "A wasp is buzzing around the hive." |
| Shoe hits | "Thwack! The wasp flies off in a huff." |
| Shoe misses / raid | "Missed. The wasp helps itself to {honey} honey, and {bees} bees fly off." |
| No throw / raid | "The wasp helps itself to {honey} honey, and {bees} bees fly off." |
| Candle lit | "You light a candle. The wasps keep their distance." |
| Candle burns out | "The candle gutters out." |

## Assumptions & notes for review
- The Workbench's opening point (2nd comb) and the Hippies' trigger (5 candles) and rate (1 sage per 10 beeswax candles) are Leah's decisions of 2026-11-07.
- Wasp numbers are placeholders until a simulator run (as was done for the first build with `Beekeeper/tools/simulate_first_hour.py`). The rule "a raid costs at most about 10 minutes of play" is the fixed limit the numbers must respect.
- Bees that fly off in a raid are simply gone; there is no way to win them back in this build.
- A raid can take honey but never wax, candles or sage.

## Decisions needed (from the [DECIDE] marks)
1. Build The Workbench before the Smoker and hive roles? (Proposal: yes.)
2. Repellent candle: 10 wax, available from the start? (Proposal: yes.)
3. Hippies: add a "Trade all" button? (Proposal: yes.)
4. Sage has no use until the first upgrades exist. OK for this build? (Proposal: yes, if Story 6 ships with no upgrades.)
5. Wasp frequency: one every 4 to 8 minutes of active play?
6. Time to respond to a wasp: 15 seconds?
7. Raid size: up to 3 minutes of honey production and 2% of the bees?
8. "Active": Beekeeper on screen and a click or key in the last 5 minutes?
9. Repellent candle: burns for 15 minutes of active play?
10. Upgrades: give the first one to three, or ship candles only and add upgrades next?

## Success Criteria
- **SC-101**: Every acceptance scenario above has an automated engine or view-model test, and Leah has short hand-test steps for the visual parts (with debug-menu shortcuts to reach the 2nd comb and to call a wasp).
- **SC-102**: In a 15-minute play-test after the 2nd comb, the co-designer never loses more than about 10 minutes of progress to wasps and doesn't find them stressful.
- **SC-103**: A first-build save loads into this build with nothing lost.
