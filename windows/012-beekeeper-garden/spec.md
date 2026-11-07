# Feature Specification: Beekeeper, stage 4: the Garden, seeds, forager bees and guards

**Feature Branch**: `012-beekeeper-garden`
**Created**: 2026-11-07
**Status**: Draft v1. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later. The few open choices are under "To confirm".
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009 (first build), 010 (Workbench, candles, Hippies, wasps, Shop upgrades), 011 (more tools, the Smoker).

**Source**: `Beekeeper/LONG_TERM_DESIGN.md`, stage 3, "Bee types, flowers and guards" (Leah, 2026-11-07). In short: with no bee limit, bees can't be assigned to jobs, so new kinds of bees are **attracted by planting flowers**; the first seeds come from the Hippies; forager bees bring back more seeds; guards are a permanent upgrade that stops raids costing bees; there are no sage flowers, so the Hippies keep their place.

**In this build**: seeds from the Hippies, the Garden card, clover (attracts honeybees), lavender (attracts forager bees), forager bees (bring back seeds), Guard Bees (Shop upgrade).
**Next build, not this one**: the propolis flower and propolis bees, together with the bee-boost candle that uses propolis (so neither arrives with nothing to do). Also later: what else foragers bring back ("and more"), sites, stronger wasps.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Hippies hand out seeds (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player's 5th trade with the Hippies, **Then** from that trade on, every bundle of 10 candles also brings **1 clover seed** *(placeholder)*, and the log says the Hippies have started giving seeds.
2. **Given** the player's 10th trade with the Hippies *(placeholder)*, **Then** from that trade on, every bundle also brings **1 lavender seed**, and the log says so.
3. **Given** seeds, **Then** the Hive card shows a row for each kind of seed the player has had (it tracks every material).
4. **Given** sage, **Then** nothing about it changes: sage still only comes from the Hippies, and there are no sage flowers.

### User Story 2 - The Garden card and planting (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player first gets seeds, **Then** a **Garden** card appears (centre column) and stays.
2. **Given** at least **5 clover seeds** *(placeholder)*, **When** "Plant" is pressed on the clover row, **Then** 5 seeds are used and the clover patches go up by 1. Planting is instant. Fewer seeds: the button is unavailable.
3. **Given** lavender seeds have been seen, **Then** a lavender row appears and works the same way (5 lavender seeds per patch *(placeholder)*).
4. **Given** the Garden card, **Then** each row shows how many patches are planted and what they attract ("12 patches · about 120 bees a minute").
5. **Given** patches, **Then** there is no limit on how many can be planted.

### User Story 3 - Flowers attract bees (Priority: P1)
**Acceptance Scenarios**:
1. **Given** clover patches, **Then** each patch attracts **10 honeybees a minute** *(placeholder)* to the hive. They are ordinary bees: they make honey and wax and count for the Catch Bee slice. (This is the old "nurses" idea: the hive grows without clicking.)
2. **Given** lavender patches, **Then** each patch attracts **1 forager bee a minute** *(placeholder)*.
3. **Given** a fraction of a bee per second, **Then** fractions are kept behind the scenes, as with honey, and whole bees are shown.
4. **Given** the app is closed, **Then** flowers keep attracting bees while away (up to the 3-day limit), like honey. See To confirm 1 for how away honey treats the new bees.

### User Story 4 - Forager bees bring back seeds (Priority: P1)
**Acceptance Scenarios**:
1. **Given** forager bees, **Then** the Hive card shows a "Forager bees" row.
2. **Given** forager bees, **Then** every **10 foragers bring back 1 clover seed a minute** *(placeholder)*, so clover keeps spreading without more trades. See To confirm 2 for which seeds.
3. **Given** forager bees, **Then** they don't make honey or wax and aren't caught by Catch Bee; they are their own kind of bee.
4. **Given** a raid, **Then** forager bees never fly off; only honeybees do (and not at all with Guard Bees).
5. **Given** time away, **Then** foragers keep bringing back seeds (up to the 3-day limit).

### User Story 5 - Guard Bees (Priority: P1)
**Acceptance Scenarios**:
1. **Given** The Workbench has opened (the 2nd comb, when wasps start), **Then** the Beekeeper's Shop offers **Guard Bees** for **300 Beebits + 100 wax** *(placeholder; Leah: yes)*.
2. **Given** Guard Bees are bought, **Then** they are permanent: from then on, a raid never makes bees fly off. The wasp can still take honey; the shoe, a bribe or a candle still save the honey.
3. **Given** Guard Bees and a raid, **Then** the log line says the guards kept the bees safe ("The wasp helps itself to 120 honey. The guards keep every bee safe.").
4. **Given** the Shop rules, **Then** Guard Bees leave the Shop once bought.

### User Story 6 - Saving (Priority: P1)
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** seeds of each kind, patches, forager bees, the Hippie seed unlocks, Guard Bees and the Garden reveal are restored.
2. **Given** a save from stages 1 to 3, **Then** it loads with nothing lost; the new amounts start at zero. A save that already has 5 or more Hippie trades starts getting seeds from its next trade.

## Reveal order (adds to earlier tables)
| Trigger | Appears |
|---|---|
| 2nd comb (The Workbench) | Guard Bees in the Shop |
| 5th Hippie trade | clover seeds; the Garden card with its clover row |
| 10th Hippie trade | lavender seeds; the lavender row |
| First forager bee | "Forager bees" row on the Hive card |

## Functional Requirements
- **FR-301**: Every number (seed unlock trades, seeds per bundle, seeds per patch, bees and foragers per patch per minute, seeds per forager per minute, Guard Bees cost) lives in `BeekeeperConfig`.
- **FR-302**: Flowers and foragers are worked out in one step for any span of time (live ticks and time away use the same maths), as honey already is.
- **FR-303**: Flowers are data (id, seed kind, what they attract and how fast), so the propolis flower later is a new entry plus its effect.
- **FR-304**: Guard Bees reuse the Shop upgrade list (mixed cost, needs The Workbench, hidden once bought).
- **FR-305**: Save version 4; older saves load with defaults.
- **FR-306**: New words through the localization workbook (English + Spanish draft) and the generator; Help gets a short Garden paragraph; no betting or gambling words; bees "fly off", never die.
- **FR-307**: Debug menu: "+10 seeds of each kind", for hand-testing.

## Draft story-log lines *(English; Leah to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| First clover seeds | "The Hippies press a packet of clover seeds into your hand." |
| First lavender seeds | "Tucked in with the sage: a twist of lavender seeds." |
| First clover patch | "You plant a patch of clover. Bees will find it." |
| First lavender patch | "Lavender, row by row. It smells like a nap." |
| First forager bee | "A forager bee heads off over the hedge." |
| Raid with Guard Bees | "The wasp helps itself to {honey} honey. The guards keep every bee safe." |

## To confirm (placeholders are in place; building can start without answers)
1. **Away honey and new bees.** While away, flowers keep attracting bees, but the away honey is worked out with the bees you had when you left; the newly attracted bees start making honey when you come back. (Placeholder. It keeps the away maths simple and exact; the alternative gives a little more honey but needs more complicated maths.)
2. **Which seeds foragers bring back**: clover only (placeholder), or clover and lavender in turn?
3. **Hippie seed timing**: clover from the 5th trade, lavender from the 10th, 1 seed per bundle of each.

## Success Criteria
- **SC-301**: Every acceptance scenario has an engine or view-model test; Leah has hand-test steps with a debug shortcut for seeds.
- **SC-302**: Once Guard Bees are bought, no raid ever lowers the bee count.
- **SC-303**: Saves from stages 1 to 3 load with nothing lost.
