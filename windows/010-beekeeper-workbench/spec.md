# Feature Specification: Beekeeper, stage 2: The Workbench, candles, Hippies and the first wasps

**Feature Branch**: `010-beekeeper-workbench`
**Created**: 2026-11-07
**Status**: Draft v3 (2026-11-07). All of Leah's questions answered. **This build is about systems, not tuning:** every number marked *(placeholder)* is a first guess to be tuned later, once meadows and the rest are built (Leah, 2026-11-07).
**Platform**: Windows only (Windows is the reference for Beekeeper until Mac exists).
**Builds on**: `windows/009-beekeeper/` (the first build: catch, honey, wax, bear, shop, combs, saving, offline).

**Sources** (Leah's notes win; the archived drafts in `Beekeeper/archive/` are not used):
- `Beekeeper/LONG_TERM_DESIGN.md`, stage 4 (candles, The Workbench, Hippies) and stage 6 (wasps, throw a shoe)
- `Beekeeper/EARLY_LOOP_RULES.md` for the first build's numbers
- Leah's answers of 2026-11-07 (below, marked "Leah")

**Order**: Leah chose to build The Workbench before the Smoker (stage 2) and hive roles (stage 3) of `LONG_TERM_DESIGN.md`. This spec depends on neither, so guards (a hive role) are not a wasp defence yet.

**In this build**: The Workbench (crafting), the beeswax candle, the Hippies, sage, the sage repellent candle (unlocked later in the build), single wasps, throw a shoe, bribing with honey, upgrades sold in the Beekeeper's Shop, No Stress Mode for wasps.
**Not in this build**: wasp gangs, bullies and the horde; throw upgrades; the bee-boost candle; propolis and the bee upgrades that gather it; guards; the bears' 100-trade wasp perk; other buyers (Hummingbirds, Badgers); the Smoker; hive roles.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Workbench opens (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player builds their 2nd comb, **Then** The Workbench card appears and stays for the rest of the game (saved), and the log says so.
2. **Given** an existing save from the first build with 2 or more combs already, **When** it is loaded, **Then** The Workbench is already open.
3. **Given** fewer than 2 combs, **Then** The Workbench is not shown and nothing in it can be used.

### User Story 2 - Craft beeswax candles (Priority: P1)
**Acceptance Scenarios**:
1. **Given** The Workbench and at least 10 wax, **When** "Make a beeswax candle" is pressed, **Then** wax drops by 10 and beeswax candles rise by 1, at once (crafting is instant).
2. **Given** less than 10 wax, **Then** the button is unavailable and pressing it does nothing.
3. **Given** the player has a candle, **Then** the Hive card shows a row for it (the Hive card tracks every material). Candles have no storage limit.
4. **Given** the beeswax candle is the only candle at first (Leah), **Then** the repellent candle is not shown until it unlocks (Story 5).

### User Story 3 - The Hippies trade sage for candles (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player has crafted 5 candles in total (any type, counted for the whole game; in practice beeswax), **Then** the Hippies panel appears and stays (saved), and the log says they have arrived.
2. **Given** 10 or more beeswax candles, **When** "Trade 10 candles" is pressed, **Then** beeswax candles drop by 10 and sage rises by 1.
3. **Given** 27 beeswax candles, **When** "Trade all" is pressed, **Then** sage rises by 2 and 7 candles are kept (Leah: yes to a Trade all button).
4. **Given** fewer than 10 beeswax candles, **Then** both trade buttons are unavailable.
5. **Given** the Hippies, **Then** they only take beeswax candles.
6. **Given** the player first gets sage, **Then** a Sage row appears on the Hive card and stays. Sage is spent on the repellent candle and on upgrades.

### User Story 4 - Wasps come by (Priority: P1)
Wasps are a gentle nuisance during active play only.

**Acceptance Scenarios**:
1. **Given** The Workbench has opened, Beekeeper is on screen, the player is active, No Stress Mode is off and no repellent candle is burning, **Then** a single wasp arrives after a random 4 to 8 minutes of that time (Leah).
2. **Given** a wasp arrives, **Then** a Wasp panel appears in the right column with a "Throw a shoe" button and a countdown of **1 minute** (Leah), and the log notes the wasp.
3. **Given** the minute runs out with no throw or bribe, **Then** the wasp raids: it takes **3 minutes' worth of honey production** (never more than is stored) and **15% of the bees** fly off (Leah), and the log says what was lost. A hive with no honey loses only bees. Leah accepts that a raid can cost a big hive more than 10 minutes of play: later catching upgrades past the Vacuum make bees quick to win back.
4. **Given** "active" (Leah: yes to the proposal), **Then** it means Beekeeper is on screen and the player clicked or pressed a key in Beekeeper in the last 5 minutes. Switching to another game, minimising the window or closing the app stops the wasp timer.
5. **Given** a wasp is approaching when the player leaves Beekeeper or goes idle, **Then** the wasp leaves without raiding.
6. **Given** the app is closed, **Then** away earnings are never reduced by wasps.

### User Story 5 - Throw a shoe, bribe, and later light a repellent candle (Priority: P1)
**Acceptance Scenarios**:
0. **Given** a wasp is approaching, **Then** the player can throw a shoe or bribe it with honey (Leah).
1. **Given** a wasp is approaching, **When** "Throw a shoe" is pressed, **Then** there is a 60% chance it hits (the wasp is driven off, nothing is lost) and a 40% chance it misses.
2. **Given** a miss, **Then** the wasp raids at once (Story 4, scenario 3); one throw per wasp. The shoe is free and the 40% miss chance never changes in this build.
2a. **Given** a wasp is approaching and the player has at least 1 honey, **When** "Bribe with honey" is pressed, **Then** the wasp takes 25% of the stored honey (rounded down, at least 1) and leaves; no bees fly off (Leah). With less than 1 honey the bribe is unavailable. A bribe is chosen instead of throwing, not after a miss.
3. **Given** the player first gets sage, **Then** the sage repellent candle unlocks at The Workbench: 10 wax + 1 sage *(placeholder)*, and the log says so.
4. **Given** at least one repellent candle, **When** "Light a repellent candle" is pressed, **Then** one is used and no wasp arrives while it burns: **15 minutes** (Leah), shown as time left.
5. **Given** a wasp is already approaching, **When** a repellent candle is lit, **Then** that wasp leaves at once without raiding.
6. **Given** a candle is burning, **Then** its time only counts down while wasps could come (Beekeeper on screen, player active, No Stress Mode off), so it is never wasted while the player is away.
7. **Given** a candle is burning, **When** another is lit, **Then** the time adds up.
8. **Given** the randomness (wasp timing, throws), **Then** it goes through the injectable random source so tests are deterministic.

### User Story 6 - Upgrades in the Beekeeper's Shop (Priority: P1)
Leah's first upgrades, sold in the **Beekeeper's Shop** (Leah). Each has a cost made of one or more resources (Beebits, wax, sage) and may be locked behind something else. They appear in the Shop once The Workbench has opened. All costs and amounts are *(placeholder)*.

| Upgrade | What it does | Cost | Needs |
|---|---|---|---|
| **Bigger Combs I** | Honey storage +50% | 300 Beebits + 100 wax | The Workbench |
| **Bigger Combs II** | Honey storage +100% (replaces I) | 800 Beebits + 250 wax + 2 sage | Bigger Combs I |
| **Better Wax-Catcher** | The Wax-Catcher gives 50% more wax | 400 Beebits + 1 sage | the Wax-Catcher |
| **Stronger Candles** | Repellent candles burn 50% longer (22½ minutes) | 200 Beebits + 50 wax + 2 sage | the repellent candle unlocked |

**Acceptance Scenarios**:
1. **Given** an upgrade the player cannot afford, **Then** it is shown but unavailable. **Given** an upgrade that is still locked, **Then** it is not shown yet *(placeholder; see Still open)*. **Given** an upgrade is bought, **Then** it disappears from the Shop (Leah: hide purchased upgrades).
2. **Given** a purchase, **Then** every resource in its cost is taken at once, or nothing is taken.
3. **Given** Bigger Combs I, **Then** all honey storage (the starting 200 and every comb) is 50% bigger: 2 combs give 900 instead of 600. With Bigger Combs II it is 100% bigger (1,200).
4. **Given** the Better Wax-Catcher, **Then** each 50 honey gives 3 wax instead of 2.
5. **Given** Stronger Candles, **Then** a repellent candle lit afterwards burns 22½ minutes instead of 15.
6. **Given** the first build's shop items (tools, Wax-Catcher), **Then** they keep showing "✓ Owned" for now (see Still open).

### User Story 7 - No Stress Mode (Priority: P1)
**Acceptance Scenarios**:
1. **Given** No Stress Mode is on (the existing Options setting), **Then** no wasps arrive and none raid, and the wasp timer does not run.
2. **Given** a wasp is already approaching when No Stress Mode is turned on, **Then** it still plays out (throw or raid); only future wasps are stopped.
3. **Given** No Stress Mode is turned on or off, **Then** nothing is reset, lost or gained (a burning candle simply pauses while No Stress Mode is on).
4. **Given** No Stress Mode, **Then** crafting, trading, upgrades and bribes still work.

### User Story 8 - Saving and old saves (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** candles of each type, total candles crafted, sage, Workbench, Hippie and repellent-candle reveals, upgrades owned, candle burn time left and the wasp timer are restored. An approaching wasp is not saved (it leaves).
2. **Given** a save from the first build, **When** it is loaded, **Then** it upgrades cleanly: all new amounts start at 0, and The Workbench opens if 2 or more combs are already built.
3. **Given** a save from a newer version, **Then** the existing safe fallback applies.

## Reveal order (adds to the first build's table)
| Trigger | Appears |
|---|---|
| 2nd comb built (or loaded with 2+ combs) | The Workbench (beeswax candle); upgrades in the Shop; wasps can start coming |
| First candle crafted | that candle's row on the Hive card |
| 5 candles crafted in total | the Hippies panel |
| First sage | Sage row on the Hive card |
| First sage | the sage repellent candle at The Workbench |
| First wasp | Wasp panel (right column); hidden again when no wasp is around and no candle is burning |

## Functional Requirements
- **FR-101**: All rules stay in the view-independent engine with no clock: crafting, trading, upgrades and the wasp timer advance only through "advance by N seconds of eligible time" calls. The view model decides what counts as eligible time (on screen, active, No Stress Mode off).
- **FR-102**: Every new number (candle costs, Hippie rate, wasp interval, 1-minute countdown, hit chance, raid size, bribe share, burn time, idle limit, the 2-comb Workbench requirement, the 5-candle Hippie trigger, upgrade costs and effects) lives in `BeekeeperConfig`, so tuning later is a one-file change. Upgrades are data (id, costs, effect, what unlocks them), so new ones can be added without new screen code.
- **FR-103**: All randomness uses the injectable random source.
- **FR-104**: Away time (`AdvanceAway`) never creates wasps, raids, or burns candle time.
- **FR-105**: The save format gets a new version; old saves load with defaults (Story 8). Saving still goes through `AtomicFile`.
- **FR-106**: Every visible string goes through the localization workbook (English and Spanish draft) and the generator. The Help page gets The Workbench, candles, Hippies, wasps and the upgrades.
- **FR-107**: No betting or gambling words. Wasps are "driven off"; bees "fly off"; nothing dies.
- **FR-108**: The Hive card tracks every material: each candle type and sage get rows there.
- **FR-109**: The story log saves event keys plus values, as before, so new lines re-translate on a language change.
- **FR-110**: Layout: The Workbench and the Hippies go in the centre column; upgrades are listed in the existing Shop card; the Wasp panel goes in the right column.
- **FR-111**: Honey storage is worked out in one place (`HoneyStorage`), so the comb upgrades also apply to away time and the "45 / 200" display.
- **FR-112**: A debug-build shortcut calls a wasp at once, for hand-testing.

## Key Entities (additions)
Candles (beeswax count, repellent count, total ever crafted), Sage, Workbench (revealed), Upgrades (definitions in config; owned set saved), Hippies (revealed, trades), Repellent candle (unlocked), Wasp (approaching or not, countdown; not saved), Wasp timer (eligible seconds until the next wasp), Repellent burn time left.

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Workbench opens | "You clear a space for a workbench." |
| First beeswax candle | "A beeswax candle. It smells of summer." |
| Hippies arrive | "A van rolls up. The Hippies love your candles." |
| Candles traded | "The Hippies hand over a bundle of sage." |
| Repellent candle unlocked | "Sage and wax. The wasps won't like this." |
| Wasp arrives | "A wasp is buzzing around the hive." |
| Shoe hits | "Thwack! The wasp flies off in a huff." |
| Shoe misses (raid) | "Missed. The wasp helps itself to {honey} honey, and {bees} bees fly off." |
| No throw (raid) | "The wasp helps itself to {honey} honey, and {bees} bees fly off." |
| Bribe | "You set out {honey} honey. The wasp takes it and buzzes off." |
| Candle lit | "You light a candle. The wasps keep their distance." |
| Candle burns out | "The candle gutters out." |
| Upgrade bought | one line per upgrade, written with the Spanish pass |

## Still open (small; placeholders are in place so building can start)
1. **Owned tools and the Wax-Catcher**: should they also disappear from the Shop once bought, like upgrades? (The tool line already says which tool is in use.) Placeholder: they keep showing "✓ Owned".
2. **Locked upgrades**: hidden until unlocked (placeholder), or shown greyed with what they need?

## Success Criteria
- **SC-101**: Every acceptance scenario has an automated engine or view-model test, and Leah has short hand-test steps (with debug shortcuts to reach the 2nd comb and to call a wasp).
- **SC-102**: In a 15-minute play-test after the 2nd comb, the co-designer finds wasps a nuisance, not a worry.
- **SC-103**: A first-build save loads into this build with nothing lost.
