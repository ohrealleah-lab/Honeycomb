# Feature Specification: Beekeeper, stage 2: The Workbench, candles, Hippies and the first wasps

**Feature Branch**: `010-beekeeper-workbench`
**Created**: 2026-11-07
**Status**: Draft v2. Leah answered the first ten questions on 2026-11-07; what is still open is marked **[OPEN n]** and collected at the end.
**Platform**: Windows only (Windows is the reference for Beekeeper until Mac exists).
**Builds on**: `windows/009-beekeeper/` (the first build: catch, honey, wax, bear, shop, combs, saving, offline).

**Sources** (Leah's notes win; the archived drafts in `Beekeeper/archive/` are not used):
- `Beekeeper/LONG_TERM_DESIGN.md`, stage 4 (candles, The Workbench, Hippies) and stage 6 (wasps, throw a shoe)
- `Beekeeper/EARLY_LOOP_RULES.md` for the first build's numbers
- Leah's answers of 2026-11-07 (below, marked "Leah")

**Order**: Leah chose to build The Workbench before the Smoker (stage 2) and hive roles (stage 3) of `LONG_TERM_DESIGN.md`. This spec depends on neither, so guards (a hive role) are not a wasp defence yet.

**In this build**: The Workbench (crafting), the beeswax candle, the Hippies, sage, the sage repellent candle (unlocked later in the build), single wasps, throw a shoe, three upgrades, No Stress Mode for wasps.
**Not in this build**: wasp gangs, bullies and the horde; throw upgrades; the bee-boost candle; propolis and the bee upgrades that gather it; bribes; guards; the bears' 100-trade wasp perk; other buyers (Hummingbirds, Badgers); the Smoker; hive roles.

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
3. **Given** the minute runs out with no throw, **Then** the wasp raids: it takes **3 minutes' worth of honey production** (never more than is stored) and **15% of the bees** fly off (Leah), and the log says what was lost. A hive with no honey loses only bees. See **[OPEN 1]**.
4. **Given** "active" (Leah: yes to the proposal), **Then** it means Beekeeper is on screen and the player clicked or pressed a key in Beekeeper in the last 5 minutes. Switching to another game, minimising the window or closing the app stops the wasp timer.
5. **Given** a wasp is approaching when the player leaves Beekeeper or goes idle, **Then** the wasp leaves without raiding.
6. **Given** the app is closed, **Then** away earnings are never reduced by wasps.

### User Story 5 - Throw a shoe, and later light a repellent candle (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a wasp is approaching, **When** "Throw a shoe" is pressed, **Then** there is a 60% chance it hits (the wasp is driven off, nothing is lost) and a 40% chance it misses.
2. **Given** a miss, **Then** the wasp raids at once (Story 4, scenario 3); one throw per wasp. The shoe is free and the 40% miss chance never changes in this build.
3. **Given** the repellent candle is unlocked, **When** the player has 10 wax and 1 sage, **Then** "Make a sage repellent candle" crafts one. See **[OPEN 2]** for when it unlocks and what it costs.
4. **Given** at least one repellent candle, **When** "Light a repellent candle" is pressed, **Then** one is used and no wasp arrives while it burns: **15 minutes** (Leah), shown as time left.
5. **Given** a wasp is already approaching, **When** a repellent candle is lit, **Then** that wasp leaves at once without raiding.
6. **Given** a candle is burning, **Then** its time only counts down while wasps could come (Beekeeper on screen, player active, No Stress Mode off), so it is never wasted while the player is away.
7. **Given** a candle is burning, **When** another is lit, **Then** the time adds up.
8. **Given** the randomness (wasp timing, throws), **Then** it goes through the injectable random source so tests are deterministic.

### User Story 6 - Upgrades (Priority: P1)
Leah's first three upgrades. Each has a cost made of one or more resources (Beebits, wax, sage) and may be locked behind another upgrade. Where they are sold is **[OPEN 3]**.

| Upgrade | What it does | Needs |
|---|---|---|
| **Stronger Candles** | Repellent candles burn longer | the repellent candle unlocked |
| **Bigger Combs I** | Honey storage +50% | The Workbench |
| **Bigger Combs II** | Honey storage +100% (replaces I) | Bigger Combs I |
| **Better Wax-Catcher** | The Wax-Catcher is 50% more effective | the Wax-Catcher |

**Acceptance Scenarios**:
1. **Given** an upgrade the player cannot afford or that is still locked, **Then** it is shown but unavailable; a locked one says what it needs. Bought upgrades show "✓ Owned".
2. **Given** a purchase, **Then** every resource in its cost is taken at once, or nothing is taken.
3. **Given** Bigger Combs I, **Then** all honey storage (the starting 200 and every comb) is 50% bigger: 2 combs give 900 instead of 600. With Bigger Combs II it is 100% bigger (1,200).
4. **Given** the Better Wax-Catcher, **Then** each 50 honey gives 3 wax instead of 2.
5. **Given** Stronger Candles, **Then** a repellent candle burns longer (amount in **[OPEN 4]**).
6. Costs and amounts are in **[OPEN 4]**.

### User Story 7 - No Stress Mode (Priority: P1)
**Acceptance Scenarios**:
1. **Given** No Stress Mode is on (the existing Options setting), **Then** no wasps arrive and none raid, and the wasp timer does not run.
2. **Given** a wasp is already approaching when No Stress Mode is turned on, **Then** it still plays out (throw or raid); only future wasps are stopped.
3. **Given** No Stress Mode is turned on or off, **Then** nothing is reset, lost or gained (a burning candle simply pauses while No Stress Mode is on).
4. **Given** No Stress Mode, **Then** crafting, trading and upgrades still work.

### User Story 8 - Saving and old saves (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** candles of each type, total candles crafted, sage, Workbench, Hippie and repellent-candle reveals, upgrades owned, candle burn time left and the wasp timer are restored. An approaching wasp is not saved (it leaves).
2. **Given** a save from the first build, **When** it is loaded, **Then** it upgrades cleanly: all new amounts start at 0, and The Workbench opens if 2 or more combs are already built.
3. **Given** a save from a newer version, **Then** the existing safe fallback applies.

## Reveal order (adds to the first build's table)
| Trigger | Appears |
|---|---|
| 2nd comb built (or loaded with 2+ combs) | The Workbench (beeswax candle, upgrades); wasps can start coming |
| First candle crafted | that candle's row on the Hive card |
| 5 candles crafted in total | the Hippies panel |
| First sage | Sage row on the Hive card |
| See [OPEN 2] | the sage repellent candle |
| First wasp | Wasp panel (right column); hidden again when no wasp is around and no candle is burning |

## Functional Requirements
- **FR-101**: All rules stay in the view-independent engine with no clock: crafting, trading, upgrades and the wasp timer advance only through "advance by N seconds of eligible time" calls. The view model decides what counts as eligible time (on screen, active, No Stress Mode off).
- **FR-102**: Every new number (candle costs, Hippie rate, wasp interval, 1-minute countdown, hit chance, raid size, burn time, idle limit, the 2-comb Workbench requirement, the 5-candle Hippie trigger, upgrade costs and effects) lives in `BeekeeperConfig`.
- **FR-103**: All randomness uses the injectable random source.
- **FR-104**: Away time (`AdvanceAway`) never creates wasps, raids, or burns candle time.
- **FR-105**: The save format gets a new version; old saves load with defaults (Story 8). Saving still goes through `AtomicFile`.
- **FR-106**: Every visible string goes through the localization workbook (English and Spanish draft) and the generator. The Help page gets The Workbench, candles, Hippies, wasps and the upgrades.
- **FR-107**: No betting or gambling words. Wasps are "driven off"; bees "fly off"; nothing dies.
- **FR-108**: The Hive card tracks every material: each candle type and sage get rows there.
- **FR-109**: The story log saves event keys plus values, as before, so new lines re-translate on a language change.
- **FR-110**: Layout: The Workbench and the Hippies go in the centre column; the Wasp panel goes in the right column.
- **FR-111**: Honey storage is worked out in one place (`HoneyStorage`), so the comb upgrades also apply to away time and the "45 / 200" display.
- **FR-112**: A debug-build shortcut calls a wasp at once, for hand-testing.

## Key Entities (additions)
Candles (beeswax count, repellent count, total ever crafted), Sage, Workbench (revealed), Upgrades (owned set), Hippies (revealed, trades), Repellent candle (unlocked), Wasp (approaching or not, countdown; not saved), Wasp timer (eligible seconds until the next wasp), Repellent burn time left.

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
| Candle lit | "You light a candle. The wasps keep their distance." |
| Candle burns out | "The candle gutters out." |
| Upgrade bought | one line per upgrade, written with the Spanish pass |

## Still open
1. **Raid size vs the "about 10 minutes" rule.** Leah chose 15% of the bees per raid. Wasps come about 10 times an hour of active play and 40% of throws miss, so about 4 raids an hour: a player who always throws loses roughly half their bees each hour (0.85⁴ ≈ 0.52) before catching more. Winning back 15% takes about 1 minute of clicking at 10,000 bees, about 8 minutes at 100,000 and over an hour at 1,000,000 (Vacuum, 3 clicks a second). So above roughly 100,000 bees one raid breaks the rule in `LONG_TERM_DESIGN.md` that a raid never costs more than about 10 minutes of play. Options: keep 15% and drop or change that rule; a smaller share (for example 2 to 5%); or 15% capped at about 10 minutes' worth of catching. Leah to decide.
2. **The sage repellent candle.** Leah: it comes after the beeswax candle. Proposal: it unlocks when the player first gets sage (so the first wasps meet only the shoe), and costs 10 wax + 1 sage.
3. **Where upgrades are sold**: The Workbench (as decided earlier: crafting = technology) or the Beekeeper's Shop (Leah's question, 2026-11-07).
4. **Upgrade costs and amounts**: what each upgrade costs (Beebits, wax, sage), and how much longer Stronger Candles makes a candle burn (proposal: +50%, so 22½ minutes).

## Success Criteria
- **SC-101**: Every acceptance scenario has an automated engine or view-model test, and Leah has short hand-test steps (with debug shortcuts to reach the 2nd comb and to call a wasp).
- **SC-102**: In a 15-minute play-test after the 2nd comb, the co-designer finds wasps a nuisance, not a worry.
- **SC-103**: A first-build save loads into this build with nothing lost.
