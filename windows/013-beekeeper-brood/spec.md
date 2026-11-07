# Feature Specification: Beekeeper, stage 5: the queen, the brood and the trade agreement

**Feature Branch**: `013-beekeeper-brood`
**Created**: 2026-11-07
**Status**: BUILT (2026-11-07, commit `d690603`). Was: Draft v1 (2026-11-07), from Leah's decisions in the planning session. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009 (first build), 010 (Workbench, candles, wasps), 011 (tools, slice, Smoker), 012 (Garden, foragers, pollen, bee bread, wooden hive).

**Why now**: today the honeybees only grow by clicking, so time away fills the combs in minutes and then makes nothing but wax. A game meant to last weeks needs time away to matter. Leah's answers (2026-11-07):
- **Passive growth comes from bee bread:** bee bread feeds the queen, and the queen raises new bees.
- **The slice gets a cap** so clicking can't outgrow everything else.
- **The bear's trade agreement** at 100 bear trades: honey that doesn't fit is bought automatically at 50% of the normal rate.

**In this build**: the queen and the brood (live and away), the pantry (bee bread as the brood's food), the slice cap, the trade agreement, a fuller "welcome back" message.
**Not in this build**: nurse bees and more seeds (stage 6, with the poplar); the propolis entrance, the emissary and turning No Stress Mode off for Beekeeper (stage 6); the meadow apiary and the honey house (stage 7); seasons (much later).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The queen starts laying (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player moves to the wooden hive (or loads a save that already has it), **Then** the log says **"The queen settles into the wooden hive and starts to lay."** and the Hive card shows a **Queen** row. (The skep has no room for brood: this also keeps the queen from eating the 10 bee bread the wooden hive costs.)
2. **Given** the queen and at least some bee bread, **Then** she raises **20 honeybees a minute** *(placeholder)* in the wooden hive, live and while away (up to the 3-day limit).
3. **Given** the brood, **Then** every **100 bees raised eat 1 bee bread** *(placeholder)*, so the wooden hive uses 0.2 bee bread a minute.
4. **Given** bees raised by the queen, **Then** they are ordinary honeybees: they make honey and wax, count toward the slice, and can fly off in a raid (unless there are guards).
5. **Given** the hive ladder, **Then** the laying rate belongs to the hive (`QueenBeesPerMinute` per hive step in config), so the meadow apiary and later steps can raise it without new rules.

### User Story 2 - The pantry runs out, gently (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the bee bread runs out, **Then** the queen stops laying. Nothing is lost and no bees fly off. The Queen row reads **"resting (no bee bread)"** and, in live play, the log says once: **"The pantry is empty. The queen rests."**
2. **Given** the queen is resting, **When** bee bread is made, **Then** she starts again at once and the Queen row reads **"laying"**.
3. **Given** a stretch of time (live or away) in which the bee bread runs out partway, **Then** the bees, honey and wax are worked out exactly: growth for the part with bee bread, flat for the rest. Never a negative amount of bee bread.
4. **Given** bee bread is crafted at The Workbench, **Then** batches (x10, x100) work as today. This is how the player stocks the pantry before leaving.

### User Story 3 - Hover shows the rates (Priority: P1)
The standard for any resource that changes on its own.
1. **Given** the queen is laying, **When** the player hovers the **Honeybees** row, **Then** it shows bees per second from the queen (e.g. "+0.33 bees/s").
2. **Given** the queen is laying, **When** the player hovers the **Bee bread** row, **Then** it shows bee bread used per second (e.g. "−0.0033 bee bread/s") and, if it helps, how long the pantry lasts ("about 8 hours").
3. **Given** the queen is resting, **Then** both read zero.

### User Story 4 - The slice cap (Priority: P1)
1. **Given** any tool, **When** a click catches bees, **Then** the slice (0.1% of the hive) is **never more than 10 × the bees the tool catches** *(placeholder)*, after Practice. Example: Hive Whistle with More Practice catches 300, so the slice stops at 3,000 bees per click, reached at 3,000,000 bees.
2. **Given** a hive below the cap, **Then** nothing changes (250,000 bees with the Whistle still catch 150 + 250).
3. **Given** the cap, **Then** the popup and the tool line show the capped total, worked out in the one place that does bees per click (FR-202).

### User Story 5 - The bear's trade agreement (Priority: P1)
1. **Given** the player's **100th trade with the bear** (Sell All counts as 1, as today), **Then** the log says **"{bear} offers a trade agreement: when your combs are full, he'll take the extra honey at half price."** It costs nothing.
2. **Given** the trade agreement and full combs, **Then** honey that doesn't fit is sold to the bear automatically at **50% of the normal rate** (Leah): **20 honey = 1 Beebit**, live and while away. Fractions are kept behind the scenes, like honey.
3. **Given** the trade agreement, **Then** selling by hand stays at the full rate (10 honey = 1 Beebit), so selling yourself is still the better deal. Automatic sales don't count as trades.
4. **Given** the trade agreement, **Then** wax still follows all the honey made, as today.
5. **Given** a save already past 100 bear trades, **Then** the agreement starts on load, with its log line.
6. **Given** the Smoker's calm (double honey) with full combs, **Then** the extra honey goes to the bear too.
7. **Given** the Trading card, **Then** it shows a small line under the bear: **"Trade agreement: extra honey at half price."** Hover shows Beebits per second from it while the combs are full.

### User Story 6 - Welcome back (Priority: P1)
1. **Given** time away, **Then** the welcome-back line says what happened, one line per thing that happened *(drafts)*:
   - "While you were away, the bees made {honey} honey."
   - "The queen raised {bees} bees." (only if she laid)
   - "{bear} came by and left {beebits} Beebits for the extra honey." (only with the agreement and overflow)
   - "The pantry ran empty while you were gone." (only if it did)

### User Story 7 - Saving (Priority: P1)
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** the queen's state, the trade agreement, and any fractional Beebits from it are restored; time away is credited as above.
2. **Given** a save from stages 1 to 4, **Then** it loads with nothing lost. A save with the wooden hive gets the queen; a save with 100 or more bear trades gets the agreement.

## Reveal order (adds to earlier tables)
| Trigger | Appears |
|---|---|
| Wooden hive (or loaded with it) | the Queen row on the Hive card; laying starts if there is bee bread |
| 100th bear trade (or loaded past it) | the trade agreement line on the Trading card |

## Functional Requirements
- **FR-401**: Every number (laying rate per hive step, bee bread per 100 bees, slice cap multiple, agreement rate, agreement trade count) lives in `BeekeeperConfig`.
- **FR-402**: **The colony now grows during a stretch of time.** Bees grow in a straight line while there is bee bread, so honey made over a stretch is the area under that line (the same kind of formula as pollen in stage 4). `Produce` must use it; the stretch is split at the moment the pantry runs out. The Smoker's calm part and the normal part of `Advance` must both see the growing hive.
- **FR-403**: **Live and away must agree.** Many 1-second `Advance` calls and one `AdvanceAway` over the same time (no calm, no wasps) give the same bees, honey, wax, bee bread and Beebits, to within rounding. Extend the existing equality test to a laying queen, one whose pantry runs out partway, and full combs with the agreement.
- **FR-404**: Overflow honey (made but not stored) is the only honey the agreement buys. It is worked out in the same place as storage (`HoneyStorage`).
- **FR-405**: The slice cap is applied inside the one bees-per-click calculation.
- **FR-406**: Save version 5; older saves load with defaults; add sanity checks for the new amounts (no negative bee bread or fractional Beebits).
- **FR-407**: New words through the localization workbook (English + Spanish draft) and the generator; Help gets a short paragraph on the queen, the pantry and the trade agreement; no betting or gambling words; bees "fly off", never die.
- **FR-408**: Debug menu: **"+10 bee bread"**, **"Bear trades to 99"** (one more sale brings the agreement), **"Spend 8 hours away"** (calls `AdvanceAway`, so the welcome-back lines can be seen without waiting), **"Bees ×10"** (to reach the slice cap quickly). The existing "Skip 10 minutes" stays live-play time.

## Key Entities (additions)
Queen (laying or resting; follows from wooden hive + bee bread, so it may not need its own saved field), Trade agreement (unlocked, saved), Agreement Beebits progress (fraction kept), Pantry-empty announced (so the log line shows once per emptying).

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| Queen starts | "The queen settles into the wooden hive and starts to lay." |
| Pantry empty (live) | "The pantry is empty. The queen rests." |
| Laying again | "Fresh bee bread. The queen gets back to work." |
| Trade agreement | "{bear} offers a trade agreement: when your combs are full, he'll take the extra honey at half price." |
| Welcome back | see User Story 6 |

## Decided (Leah, 2026-11-07)
1. Passive growth comes from bee bread feeding the queen, who raises new bees.
2. The slice gets a cap (placeholder: 10 × the tool's bees).
3. The trade agreement comes free at 100 bear trades, buying extra honey at 50% of the normal rate, automatically.
4. `decimal` is big enough for the bee count (about 7.9 × 10²⁸; 11,111,111,111,111 bees fit easily).

## Still open (placeholders in place; none blocks building)
1. The laying rate (20 bees a minute) and bee bread use (1 per 100 bees): tune once Leah has played a night away.
2. The long-term doc's old idea "bears reduce raids after 100 trades" is replaced by the trade agreement at 100 trades. Placeholder: dropped (the emissary ends raids in stage 6).

## Success Criteria
- **SC-401**: Every acceptance scenario has an engine or view-model test; Leah has hand-test steps with debug shortcuts.
- **SC-402**: After a night away with a stocked pantry, the colony is visibly bigger and the welcome-back message says why.
- **SC-403**: Live and away give the same result for a laying queen, including a pantry that runs out partway.
- **SC-404**: Saves from stages 1 to 4 load with nothing lost.

## Hand-test (Leah) — debug build, Banners menu in the toolbar
1. Load a game that has the wooden hive (or reach it with "+10 pollen", bee bread at The Workbench, and the move). The log says the queen starts to lay and the Hive card has a **Queen** row.
2. With no bee bread, the Queen row says **resting**. Use **+10 bee bread**: it says **laying**. Hover **Honeybees**: about +0.33 bees/s. Hover **Bee bread**: about −0.0033/s.
3. Watch the bee count tick up on its own for a minute (no clicking).
4. **Skip 10 minutes** twice: 2 bee bread are gone and about 400 bees are added. Skip three more times (10 bee bread last 50 minutes): the log says the pantry is empty, and the bees stop growing.
5. Make bee bread at The Workbench (x10): the queen starts again.
6. **Bear trades to 99**, then sell once: the bear offers the trade agreement and the Trading card shows its line.
7. Fill the combs (stop selling), then **Spend 8 hours away**: the welcome-back lines say what the bees made, how many bees the queen raised, and what the bear left. Beebits went up without selling.
8. With the Hive Whistle, use **Bees ×10** until you have several million bees: the "+N bees" popup stops growing past 10 × the tool's bees.
9. Close and reopen: the queen, the pantry and the agreement are still there.
