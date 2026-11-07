# Feature Specification: Beekeeper, stage 4: the Garden, discovering bees, pollen and the wooden hive

**Feature Branch**: `012-beekeeper-garden`
**Created**: 2026-11-07
**Status**: Draft v2, rewritten after Leah's design pivot (2026-11-07): planting a seed is how new kinds of bees are discovered; guards come from a plant, not the Shop; foragers bring back pollen. **Systems first:** numbers and plant names marked *(placeholder)* live in `BeekeeperConfig` and are tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009 (first build), 010 (Workbench, candles, Hippies, wasps, Shop upgrades), 011 (more tools, the Smoker).

**Source**: `Beekeeper/LONG_TERM_DESIGN.md`, stage 3, "Seeds, discovery and bee types". In short: with no bee limit, bees can't be assigned jobs, so **new kinds of bees are discovered by planting seeds**; each kind brings a new resource or a buff; seeds come from the Hippies (no sage plants); bee bread (from pollen) and wax pay for moving to a better hive.

**In this build**: seeds from the Hippies; the Garden card (plant, grow, sprout); two plants and the bees they attract (forager bees, guard bees); pollen; bee bread at The Workbench; the first step of the ladder (skep to wooden hive); the Bees card with bee facts.
**Later**: more seeds and plants (e.g. a poplar for resin foragers and propolis, with the bee-boost candle), the meadow apiary and orchard, the honey house, stronger wasps.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Hippies give a seed (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player's 5th trade with the Hippies, **Then** the Hippies give **a seed** (one, a mystery: it doesn't say what it will grow), and the log says so.
2. **Given** the player's 10th trade with the Hippies *(placeholder)*, **Then** they give a second, different seed. No more seeds come in this build.
3. **Given** a seed, **Then** the Hive card shows "Seeds: 1" (it tracks every material).
4. **Given** sage, **Then** nothing changes: there are no sage plants, sage stays the Hippies' trade.

### User Story 2 - The Garden card: plant, wait, sprout (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the first seed, **Then** a **Garden** card appears (centre column) and stays.
2. **Given** a seed, **Then** the Garden card shows a **Plant seed?** button.
3. **When** it is pressed, **Then** the seed is used and the button is replaced by **"Something is growing!"** No timer is shown: it is a surprise *(placeholder; see To confirm 2)*.
4. **Given** **10 minutes** have passed (Leah) — including time with the app closed, since plants grow while you're away — **Then** the log says **"Your seed has sprouted."** and the Garden card shows the plant, the kind of bee it attracts, and what that bee does.
5. **Given** a seed is already growing, **Then** a second seed waits: one plant grows at a time *(placeholder)*.
6. **Given** the plants of this build, in order *(placeholder names)*:

   | Seed | Grows into | Attracts | Brings |
   |---|---|---|---|
   | 1st (5 trades) | **Wildflowers** | **Forager bees** | pollen |
   | 2nd (10 trades) | **Bramble** | **Guard bees** | raids never cost bees |

### User Story 3 - Forager bees and pollen (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the wildflowers have sprouted, **Then** they attract **1 forager bee a minute** *(placeholder)*, live and while away (up to the 3-day limit). The Hive card shows "Forager bees".
2. **Given** forager bees, **Then** every **10 foragers bring back 1 pollen a minute** *(placeholder)*, live and while away. The Hive card shows "Pollen".
3. **Given** forager bees, **Then** they don't make honey or wax, aren't caught by Catch Bee, aren't part of the 0.1% slice, and never fly off in a raid.

### User Story 4 - Guard bees (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the bramble has sprouted, **Then** it attracts guard bees (**1 a minute** *(placeholder)*). The Hive card shows "Guard bees".
2. **Given** at least one guard bee, **Then** raids never make bees fly off; the wasp can still take honey, and the shoe, a bribe or a candle still save the honey. (Design pivot: guards come from a plant, not the Shop.)
3. **Given** a raid with guards, **Then** the log says so: "The wasp helps itself to 120 honey. The guards keep every bee safe."

### User Story 5 - Bee bread (Priority: P1)
**Acceptance Scenarios**:
1. **Given** pollen, **Then** The Workbench shows a **bee bread** row: **10 pollen + 10 honey** *(placeholder)* make 1 bee bread, instantly. (Real bees make bee bread from pollen and honey to feed their young.)
2. **Given** bee bread, **Then** the Hive card shows "Bee bread".

### User Story 6 - The first hive upgrade: skep to wooden hive (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a new or existing game, **Then** the Hive card's title reads **"A SKEP IN THE GARDEN"** (the hive the player started with).
2. **Given** the player first has bee bread, **Then** the Hive card offers **"Move to a wooden hive"** for **200 wax + 10 bee bread** *(placeholder)*.
3. **Given** the move, **Then** the title becomes **"A WOODEN HIVE IN THE GARDEN"**, the log says so, and every honeybee makes **25% more honey** *(placeholder; see To confirm 3)*.
4. **Given** the wooden hive, **Then** nothing else changes: bees, honey, combs and everything else stay. The next steps (meadow apiary, orchard) come in later builds.

### User Story 7 - The Bees card (Priority: P2)
**Acceptance Scenarios**:
1. **Given** the player has bees, **Then** a **Bees** card (right column, above the story log) lists each kind of bee met so far, with what it does and a bee fact.
2. **Given** a kind not met yet, **Then** it is not listed (discovery stays a surprise).
3. Draft entries (English; Leah to edit):
   - **Honeybees**: make honey, and wax from honey. *Fact: a worker bee makes about a twelfth of a teaspoon of honey in her whole life.*
   - **Forager bees**: bring back pollen. *Fact: in a real hive, foragers are the oldest workers; a bee only starts foraging in the last weeks of her life.*
   - **Guard bees**: keep every bee safe in a raid. *Fact: guards stand at the hive entrance and check the smell of every bee coming in.*

### User Story 8 - Saving (Priority: P1)
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** seeds, the growing seed and its time left, the plants, forager and guard bees, pollen, bee bread and the wooden hive are restored, and a seed that finished growing while away has sprouted.
2. **Given** a save from stages 1 to 3, **Then** it loads with nothing lost. A save with 5 or more Hippie trades gets its first seed on its next trade.

## Reveal order (adds to earlier tables)
| Trigger | Appears |
|---|---|
| 5th Hippie trade | a seed; the Garden card |
| Seed sprouts | the plant on the Garden card; its bees on the Hive card and the Bees card |
| First pollen | bee bread at The Workbench |
| First bee bread | "Move to a wooden hive" on the Hive card |

## Functional Requirements
- **FR-301**: Every number (seed trades, growing time, bees per minute per plant, pollen per forager, bee bread recipe, wooden hive cost and effect) lives in `BeekeeperConfig`.
- **FR-302**: Plants are data (seed order, plant id, which bee, how fast), so later seeds (a poplar for resin foragers) are new entries plus their effect.
- **FR-303**: Growing, attracting and pollen are worked out in one step for any span of time, so live ticks and time away agree. (Forager and guard bees don't make honey, so away honey stays exact.)
- **FR-304**: Guard Bees are no longer a Shop upgrade (removed from the plan for stage 4).
- **FR-305**: Save version 4; older saves load with defaults.
- **FR-306**: New words through the localization workbook (English + Spanish draft) and the generator; Help gets a short Garden paragraph; no betting or gambling words; bees "fly off", never die.
- **FR-307**: Debug menu: "Give a seed", "Finish growing", "+10 pollen", for hand-testing.

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| A seed | "The Hippies press a seed into your hand. They won't say what it is." |
| Planted | "You plant the seed and water it." |
| Sprouted | "Your seed has sprouted." (Leah) then "Wildflowers! Forager bees drift in." / "A bramble! Guard bees settle in its thorns." |
| First pollen | "A forager comes home dusted in pollen." |
| First bee bread | "You pack pollen and honey into bee bread." |
| Wooden hive | "You move the bees into a wooden hive. They seem pleased." |
| Raid with guards | "The wasp helps itself to {honey} honey. The guards keep every bee safe." |

## To confirm (placeholders are in place; building can start without answers)
1. **Plant names and order**: wildflowers (forager bees) from the 1st seed, bramble (guard bees) from the 2nd.
2. **Growing**: a surprise with no timer shown, or a quiet countdown?
3. **The wooden hive**: +25% honey from every honeybee, for 200 wax + 10 bee bread. Or should it give something else (more storage, more bees per click)?

## Success Criteria
- **SC-301**: Every acceptance scenario has an engine or view-model test; Leah has hand-test steps with debug shortcuts.
- **SC-302**: Once a guard bee arrives, no raid ever lowers the bee count.
- **SC-303**: Saves from stages 1 to 3 load with nothing lost.
