# Feature Specification: Beekeeper, stage 3: bigger catching and the Smoker

**Feature Branch**: `011-beekeeper-catching`
**Created**: 2026-11-07
**Status**: v2 (2026-11-07), Leah's answers folded in. **Systems first:** every number marked *(placeholder)* is a first guess, kept in `BeekeeperConfig` and tuned later (Leah, 2026-11-07).
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: `windows/009-beekeeper/` (first build) and `windows/010-beekeeper-workbench/` (The Workbench, candles, Hippies, upgrades in the Shop, wasps).

**Why now**: a wasp raid takes 15% of the bees (Leah). Today the best tool catches 10 bees a click, so a big hive can't win its bees back. Leah: "There will be upgrades past the vacuum to catch even more and more and more bees! That's what our upgrades are for."

**Source**: `Beekeeper/LONG_TERM_DESIGN.md`, stage 2: "Smoker + tool upgrades: clicking builds a 'calm' meter that boosts the colony for a short time; each tool gets upgrade tiers; a click also catches a small slice of the current colony. Keeps clicking relevant all game."

**In this build**: three tools after the Vacuum; Practice upgrades that multiply every click; each click also catching a slice of the colony; the Smoker with its calm meter.
**Not in this build**: hive roles, sites and special bees, stronger wasps, the bee-boost candle.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tools after the Vacuum (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player owns the Bee-Safe Vacuum, **Then** the Shop offers the next tool. Tools are still bought in order with Beebits, and each replaces the one before:

   | Tool (names: Leah, 2026-11-07; numbers *(placeholder)*) | Cost | Bees per click |
   |---|---|---|
   | Bee Lure | 1,000 Beebits | 25 |
   | Flower Cart | 4,000 Beebits | 60 |
   | Hive Whistle | 15,000 Beebits | 150 |

2. **Given** a new tool is bought, **Then** the tool line updates ("Flower cart · 60 bees") and the log has a line for it.
3. **Given** the Shop, **Then** only the **next** tool to buy is listed; owned tools and the owned Wax-Catcher are hidden like owned upgrades, since the tool line already names the tool in use (Leah). An option to show bought things may come later, so hiding is one switch in the code.
4. **Given** the player owns the Hive Whistle, **Then** no further tool is offered in this build.

### User Story 2 - Practice upgrades (Priority: P1)
Upgrades in the Shop that make every click catch more, whatever the tool.

| Upgrade *(placeholder)* | What it does | Cost | Needs |
|---|---|---|---|
| **Practice** | Bees per click +50% | 600 Beebits + 50 wax | the Vacuum |
| **More Practice** | Bees per click +100% (replaces Practice) | 2,500 Beebits + 200 wax + 3 sage | Practice |

**Acceptance Scenarios**:
1. **Given** the Vacuum (10 bees) and Practice, **When** the player clicks, **Then** 15 bees are caught from the tool (plus the slice, Story 3). With More Practice, 20.
2. **Given** these upgrades, **Then** they follow the Shop rules from stage 2: mixed costs taken all at once or not at all, hidden until unlocked, gone once bought.
3. **Given** the Practice upgrades, **Then** they do not need The Workbench (only what is listed under "Needs").

### User Story 3 - A slice of the colony with every click (Priority: P1)
**Acceptance Scenarios**:
1. **Given** any tool, **When** a click catches bees (not a sting), **Then** it also catches **0.1% of the bees already in the hive** (Leah: "the slice is good"), rounded down. Example: 250,000 bees with the Hive Whistle catch 150 + 250 = 400 bees.
2. **Given** a small hive (under 1,000 bees), **Then** the slice rounds down to 0, so the early game is unchanged.
3. **Given** Practice upgrades, **Then** they multiply only the tool's bees, not the slice. *(placeholder rule)*
4. **Given** a click, **Then** the popup and the tool line show the total ("+400 bees"; "Hive whistle · 400 bees").
5. **Given** a sting (bare hands only), **Then** nothing is caught, slice included.

### User Story 4 - The Smoker (Priority: P1)
Clicking calms the bees; a calm hive works harder for a while.

**Acceptance Scenarios**:
1. **Given** the player owns the Vacuum, **Then** the Shop offers **the Smoker** *(placeholder: 500 Beebits + 50 wax)*. Once bought it leaves the Shop and a Smoker card appears under the tool line.
2. **Given** the Smoker, **When** the player clicks Catch Bee, **Then** the calm meter rises by 1 per click (stings count too), up to **15** (Leah). It never drains on its own (cozy).
3. **Given** a full meter, **When** "Puff the Smoker" is pressed, **Then** the meter empties and the bees are **calm for 2 minutes** (Leah): honey production is **doubled** (Leah) while it lasts. The card shows the time left.
4. **Given** the bees are calm, **Then** clicks still fill the meter for the next puff, but a second puff can't start until the calm ends.
5. **Given** the player presses Puff, **Then** the press is deliberate (no automatic puff; Leah: puffed by hand).
6. **Given** calm time, **Then** it only counts down while the app is open and Beekeeper is running; time away neither uses it up nor doubles away earnings. Switching to another game does not pause it (the hive keeps working there too).
7. **Given** storage is full, **Then** doubled honey still stops at the storage limit; wax follows all honey made, so calm bees also make wax twice as fast.

### User Story 5 - Saving (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** the tool, Practice upgrades, the Smoker, the calm meter and any calm time left are restored.
2. **Given** a save from stage 1 or 2, **Then** it loads with nothing lost; new amounts start at zero.

## Reveal order (adds to earlier tables)
| Trigger | Appears |
|---|---|
| Vacuum owned | the next tool, Practice and the Smoker in the Shop |
| Smoker bought | the Smoker card (left column, under the tool line) |

## Functional Requirements
- **FR-201**: All new numbers (tool costs and bees, slice share, Practice multipliers, Smoker cost, meter size, calm length and boost) live in `BeekeeperConfig`.
- **FR-202**: Bees per click is worked out in one place, so the popup, the tool line and the catch always agree.
- **FR-203**: The Practice upgrades and the Smoker reuse the stage 2 upgrade list (id, mixed cost, what it needs), extended with a "needs a tool level" rule.
- **FR-204**: `Advance` (live play) applies the calm boost and counts calm time down; `AdvanceAway` does neither. The live-vs-away equality test from the first build is kept for hives that are not calm.
- **FR-205**: Save version 3; older versions load with defaults.
- **FR-206**: New words through the localization workbook (English + Spanish draft) and the generator; Help gets a short Smoker paragraph; no betting or gambling words.
- **FR-207**: Debug menu: "Fill the calm meter", for hand-testing.

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Bee Lure bought | "A pot of sweet lure. The bees come to you now." |
| Flower Cart bought | "A cart of flowers. Bees follow it everywhere." |
| Hive Whistle bought | "One soft note, and the bees come home." |
| Smoker bought | "A little smoker. Cool smoke calms the bees." |
| Puff | "You puff the smoker. The hive settles and hums." |
| Calm ends | "The smoke drifts away." |

## How this answers the 15% raids (checked)
With the Hive Whistle (no Practice), 3 clicks a second and the 0.1% slice, winning back a 15% raid takes about (the slice starts from the smaller, raided hive):
- 10,000 bees: 1,500 bees back at about 160 per click, roughly 3 seconds of clicking
- 100,000 bees: 15,000 back at 235 to 250 per click, roughly 20 seconds
- 1,000,000 bees: 150,000 back at 1,000 to 1,150 per click, roughly 50 seconds

So raids stay a nuisance rather than a setback at every size (stage 2 alone: over an hour at 1,000,000 bees). The flip side is that clicking now grows big hives fast; that is a tuning question for later.

## Decided (Leah, 2026-11-07)
1. Owned tools and the Wax-Catcher are hidden in the Shop, like owned upgrades. A "show bought things" option may come later.
2. Tool names: Bee Lure, Flower Cart, Hive Whistle.
3. The slice: 0.1% of the hive per click.
4. The Smoker: 15 clicks to fill, 2 minutes of calm, honey ×2, puffed by hand.

## Success Criteria
- **SC-201**: Every acceptance scenario has an engine or view-model test; Leah has hand-test steps (with debug shortcuts for Beebits and the calm meter).
- **SC-202**: A 15% raid on a 1,000,000-bee hive is won back in under a minute of clicking with the best tool.
- **SC-203**: Stage 1 and 2 saves load with nothing lost.

## Hand-test (Leah) — debug build, Banners menu in the toolbar
1. **Banners → Beekeeper → +100 Beebits** until you can buy the Vacuum (buy Gloves and Net first). The Shop now shows only the next tool (**Bee Lure**), plus **Practice** and **The Smoker**; bought tools and the Wax-Catcher are gone from the list.
2. Buy the Bee Lure, Flower Cart and Hive Whistle in turn (more Beebits). The tool line and the "+N bees" popup grow each time.
3. **+100 bees** a few dozen times (or play a while). Once you have over 1,000 bees, each click catches a little more than the tool alone (the 0.1% slice).
4. Buy **Practice**: the tool's bees go up by half.
5. Buy **The Smoker**. A Smoker card appears under the tool line: "Calm: 0/15". Click Catch Bee 15 times; the bar fills and **Puff the Smoker** lights up.
6. Puff: the card counts down 2:00, the Hive card's honey per second doubles, and the log says so. When it ends, the log says "The smoke drifts away."
7. Close and reopen during a calm: the tool, the Smoker and the time left are still there.
