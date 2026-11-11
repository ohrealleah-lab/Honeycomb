# Feature Specification: Beekeeper, stage 9: the bloom calendar

**Feature Branch**: `018-beekeeper-blooms`
**Created**: 2026-11-11
**Status**: Specced 2026-11-11; **built** 2026-11-11. From Bee's decisions in the planning session. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009–017 and the commits after 017 (herbal candle prices, seeds that plant themselves, the Smoker at +150%). Design: `Beekeeper/LONG_TERM_DESIGN.md`, "Update: The bloom calendar", stage 8 of "Planned stages" and "Decisions made".

**Why now**: nothing in the game changes from one day to the next, so there is no reason to come back tomorrow, and nothing is gated by real time past the queen. In this stage **a different flower blooms each day, and each bloom makes one specialty work twice as hard.** Bee's decisions (2026-11-11):
- **One bloom per day, in game time.** A day is 24 hours of live play plus time away, counted from when the calendar starts. The order is **crocus, clover, linden, goldenrod**, then a **half-day winter**, then crocus again. One "year" is 4½ days.
- **The calendar starts with the first plant.** It does not run before the garden has something growing.
- **Each bloom favours one specialty, from real beekeeping**, and that specialty **works twice as hard** *(placeholder)* while it blooms:
  | Bloom | Favours | Why (real beekeeping) |
  |---|---|---|
  | Crocus | **Nursing**: the queen lays faster | Early spring pollen sets off the spring brood. |
  | Clover | **Foraging**: pollen | Clover is a steady pollen and nectar source all summer. |
  | Linden | **Guarding**: the hive feels safe, +honey | The linden flow is the big summer honey flow. |
  | Goldenrod | **Resin**: propolis | Bees gather the most propolis in autumn, to seal the hive for winter. |
- **Winter** slows the combs' honey a little. Nothing is lost, and no bee leaves.
- **Named honey is dropped for now** (Bee, 2026-11-11). The blooms give no crocus or linden honey. Stage 10's buyers were going to want named honey, so stage 10 needs another want (see "To-dos for later stages").

**In this build**: the calendar and its clock; the four blooms and winter; doubling the favoured specialty; winter's honey slowdown; the Garden card's bloom line and hover; story-log lines and the welcome-back line; specialty and honey hovers that name the bloom; save; debug; tests.
**Not in this build** (later stages): named honey, bloom facts, new buyers, the honey house, bottles, paper labels, better frames, bee hotel upgrades, new meadow plants, batch comb building, the swarm. **Do not touch Beekeeper Help** (Bee: it will be very sparse at the end). This stage does not retune old prices.

## Conflicts with what is already built
None found. Two things to watch:
1. **Clover is both a plant and a bloom.** They don't clash: the clover bloom favours foraging, which the clover plant (and the wildflowers) give anyway. Words must say "the clover is in bloom", not anything that sounds like a new plant or a seed.
2. **A bloom without its plant does nothing** *(default)*. Crocus does nothing until a willow is planted, and goldenrod does nothing until a poplar is planted. The bloom line still shows, and the hover says what it would favour.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The calendar starts (Priority: P1)
1. **Given** no plant yet, **Then** there is no calendar, no bloom line and no bloom effect.
2. **Given** the first plant (planted by hand, by a seed that plants itself, or by a debug shortcut), **Then** the calendar starts on **day 1, crocus**, with a log line.
3. **Given** a save that already has plants but no calendar, **When** it loads, **Then** the calendar starts on crocus at that moment.

### User Story 2 - One bloom a day (Priority: P1)
1. **Given** the calendar, **Then** the blooms follow in order: **crocus 24 h, clover 24 h, linden 24 h, goldenrod 24 h, winter 12 h** *(placeholders)*, then crocus again, for ever.
2. **Given** a change of bloom during live play, **Then** the story log says so at that moment ("The linden is in bloom.").
3. **Given** time away, **Then** the clock counts it exactly as live time, up to the 3-day cap on time away. Time past the cap doesn't move the calendar, as it doesn't make honey.

### User Story 3 - The favoured specialty works twice as hard (Priority: P1)
Strength is doubled as follows *(`BloomFavourMultiplier` = 2, placeholder)*. A multiplier doubles **its bonus part**; a rate doubles **itself**:

| Bloom | Specialty | Normal | In bloom |
|---|---|---|---|
| Crocus | Nursing | the queen lays ×1.5 | ×2 (1 + 2 × 0.5) |
| Clover | Foraging | 6 pollen a minute (wildflowers + clover) | 12 a minute |
| Linden | Guarding | +25% honey | +50% honey |
| Goldenrod | Resin | 1 propolis a minute | 2 a minute (before the poplars' bonus) |

1. **Given** a bloom and its specialty, **Then** the specialty reads as in the table. Plant bonuses (+1% per extra plant) don't double: only the specialty does.
2. **Given** a bloom without its specialty, **Then** nothing changes.
3. **Given** a hover on the favoured resource (honey for linden, pollen for clover, propolis for goldenrod, the queen's laying for crocus), **Then** it names the bloom as a source ("Linden in bloom: guarding ×2"), as every growth hover does.

### User Story 4 - Winter (Priority: P1)
1. **Given** winter, **Then** the combs' and the meadow's honey is **×0.75** *(placeholder)*. Wax, pollen, propolis, wood, the queen and the bee hotel are unchanged.
2. **Given** winter, **Then** no specialty is favoured, and nothing is lost: stored honey, bees and plants stay.
3. **Given** a hover on honey in winter, **Then** it lists "Winter: ×0.75".

### User Story 5 - Seeing the bloom (Priority: P1)
1. **Given** the calendar, **Then** the Garden card shows one line: **"In bloom: linden · 9 h left"** (winter: **"Winter · 5 h left"**). Hours round up; under an hour shows minutes.
2. **Given** a hover on that line, **Then** it says what the bloom favours, whether the hive has that specialty yet, and what blooms next. Draft words are below.

### User Story 6 - Time away (Priority: P1)
1. **Given** any stretch, **Then** many 1-second `Advance` calls equal one `AdvanceAway`, now including bloom changes: honey, pollen, propolis and new bees all come out the same.
2. **Given** time away that crossed one or more bloom changes, **Then** the welcome-back message gets one line naming them in order and the bloom now ("While you were away, the clover and the linden bloomed. Now the goldenrod is out."). There is no separate log line for each change while away.

## Reveal order (additions)
| Trigger | Appears |
|---|---|
| First plant | the calendar (crocus); the Garden card's bloom line; a log line |
| Each change of bloom | a log line (live) or the welcome-back line (away) |

## Functional Requirements
- **FR-901**: Every number lives in `BeekeeperConfig`.
- **FR-902**: **The blooms.** A config list `Blooms` of `BeekeeperBloom(string Id, decimal Seconds, string? Favours)`: crocus (86,400, nursing), clover (86,400, foraging), linden (86,400, guarding), goldenrod (86,400, resin), winter (43,200, none). Ids in a `BeekeeperBlooms` static class like `BeekeeperPlants`. `BloomFavourMultiplier` (2) and `WinterHoneyMultiplier` (0.75).
- **FR-903**: **The clock.** `State.CalendarStarted` (bool) and `State.BloomIndex` (int) and `State.BloomSecondsLeft` (decimal). `StartCalendar()` sets crocus with its full length; it is called from every path that adds the first plant and on load (User Story 1.3). The engine exposes `CurrentBloom` (null before the calendar) and `BloomSecondsLeft`.
- **FR-904**: **Splitting `Work`.** In `Work`'s loop, a running calendar adds `State.BloomSecondsLeft` to the `Math.Min` that picks the step, beside the sage-propolis candle and the bee hotel. At the end of the piece, when it reaches 0, the bloom moves to the next one (wrapping), its seconds reset, and a `BloomChanged` event carries the new bloom's id. The produce step in each piece reads the bloom of that piece, so live and away agree exactly.
- **FR-905**: **Favoured specialties.** One helper, `BloomFavour(string specialty)`: `BloomFavourMultiplier` when the current bloom favours that specialty, else 1. `NursingMultiplier` and `GuardingMultiplier` become 1 + (product − 1) × favour; `ForagingPollenPerMinute` and `ResinPropolisPerMinute` are multiplied by it. Plant bonuses stay outside it.
- **FR-906**: **Winter.** `HiveMultiplier` (or `HoneyPerSecond`, whichever keeps the meadow included) gains a `WinterMultiplier` factor: `WinterHoneyMultiplier` in winter, else 1.
- **FR-907**: **Events, not sentences.** New events: `CalendarStarted`, `BloomChanged` (Text = bloom id). The view model turns live `BloomChanged` events into log lines, and gathers away ones into the one welcome-back line, as it does for other away events.
- **FR-908**: **The Garden card.** The view model exposes `BloomLine` and `BloomHover` (empty before the calendar). They refresh on the tick, like other timers on screen.
- **FR-909**: **Hovers.** The honey, pollen and propolis hovers, and the queen's laying hover, add a bloom line when the bloom changes their number, and the honey hover adds the winter line (growth-hover rule: every source and multiplier).
- **FR-910**: **Save.** New fields load as false or zero, so no version bump: `CalendarStarted`, `BloomIndex`, `BloomSecondsLeft`. Sanity checks on load: the index wraps into range, and the seconds are clamped to (0, that bloom's length]; a running calendar with 0 seconds gets the full length.
- **FR-911**: **Words** through `tools/Honeycomb_Localization.xlsx` (English + Spanish draft) with a small openpyxl script, then `python tools/generate_localization.py`. **No Help changes.**
- **FR-912**: **Debug menu.** Add **"Next bloom now"** (moves to the next bloom without producing anything, with the usual log line) and **"Start the calendar"** (for a save with no plant). The existing time-away shortcuts show the welcome-back line.
- **FR-913**: **Comment out, don't delete.** Nothing is cut in this stage. If the named-honey idea leaves anything behind in comments or config, mark it `// Later (named honey, dropped from stage 9)`.

## Placeholder numbers (all in `BeekeeperConfig`)
| Setting | Value |
|---|---|
| Bloom lengths | crocus, clover, linden, goldenrod 86,400 s (24 h) each; winter 43,200 s (12 h) |
| `BloomFavourMultiplier` | 2 (a multiplier's bonus part doubles; a rate doubles) |
| `WinterHoneyMultiplier` | 0.75 |

**Pacing, roughly:** a 3-week run sees each bloom 4 or 5 times. A player with all four specialties gets one strong day for each, and the linden day is the honey day.

## Draft words *(English; Bee to edit, Spanish afterwards)*
| Where | Line |
|---|---|
| Log: calendar starts | "The crocuses are in bloom. A new flower will bloom each day." |
| Log: crocus (again) | "Spring again: the crocuses are in bloom." |
| Log: clover | "The clover is in bloom." |
| Log: linden | "The linden is in bloom." |
| Log: goldenrod | "The goldenrod is in bloom." |
| Log: winter | "Winter. The bees cluster together to keep warm." |
| Welcome back | "While you were away, the {list} bloomed. Now the {bloom} is out." / "…Now it's winter." |
| Garden line | "In bloom: {bloom} · {time} left" / "Winter · {time} left" |
| Hover: crocus | "Crocus: the queen lays twice as fast as nursing alone would make her." / without nursing: "Crocus favours nursing. A willow would help." |
| Hover: clover | "Clover: foraging brings in twice the pollen." / "Clover favours foraging. Wildflowers or clover would help." |
| Hover: linden | "Linden: the hive feels twice as safe (+50% honey)." / "Linden favours guarding. A bramble would help." |
| Hover: goldenrod | "Goldenrod: the bees gather twice the propolis." / "Goldenrod favours resin. A poplar would help." |
| Hover: winter | "Winter: honey comes 25% slower. Nothing is lost." |
| Hover: last line | "Next: {bloom}." |

## To-dos for later stages
1. **Named honey** (dropped from stage 9, Bee). Stage 10's Hummingbirds and Badgers were going to want it; they need another want, or named honey comes back with them.
2. **Bloom facts**: a short real fact per bloom in its hover, like the Bees tab's facts.
3. **A plant for every bloom?** Crocus, linden and goldenrod are not plants you can grow. They could become seeds later.

## Tests
- No calendar before the first plant; the first plant starts it on crocus; every path that plants (by hand, self-planting seed, debug) starts it; an older save with plants starts it on load.
- The order and lengths: 24 h steps through crocus, clover, linden, goldenrod; winter is 12 h; then crocus again.
- Each favour: nursing ×1.5 → ×2 in crocus; pollen 6 → 12 in clover; guarding 1.25 → 1.5 in linden; resin 1 → 2 in goldenrod; plant bonuses don't double; no effect without the specialty.
- Winter: honey ×0.75 (combs and meadow); wax, pollen, propolis, wood and laying unchanged.
- `Work` splits at a bloom change: a stretch across linden → goldenrod gives exactly the honey of each part.
- Live and away agree across several bloom changes (honey, pollen, propolis, bees raised).
- Away: the 3-day cap also caps the calendar; the welcome-back line lists the blooms in order.
- Save: the fields round-trip; a bad index or seconds value is fixed on load.
- Hovers: honey shows the linden line in linden and the winter line in winter; pollen shows the clover line in clover.

## Decided (Bee, 2026-11-11)
Game-time days; the calendar starts with the first plant; the real-life matches (crocus nursing, clover foraging, linden guarding, goldenrod resin) at twice the strength; named honey dropped for now.

## Defaults taken in writing the spec (easy to change)
1. Winter is ×0.75 honey, and only honey.
2. A bloom without its plant does nothing (the line still shows).
3. "Twice as hard" doubles a multiplier's bonus part (+25% → +50%), not the whole multiplier.
4. Plant bonuses don't double in a bloom.
5. The Garden card holds the bloom line; no new card.
6. Away bloom changes are one welcome-back line, not one log line each.
7. Debug: "Next bloom now" and "Start the calendar".
8. No Help changes.

## Success Criteria
- **SC-901**: Every acceptance scenario has an engine or view-model test; Bee has hand-test steps with debug shortcuts.
- **SC-902**: Live and away agree across bloom changes.
- **SC-903**: Before the first plant, nothing on screen mentions blooms.
- **SC-904**: A stage 8 save loads without losing anything; one with plants starts on crocus.

## Hand-test (Bee) — debug build, Banners menu in the toolbar
1. Start a new game and get to the Garden. Before planting: no bloom line.
2. Plant the first seed: the log says the crocuses are in bloom, and the Garden card shows "In bloom: crocus · 24 h left".
3. Hover the bloom line: it says what crocus favours, whether the hive has it, and that clover is next.
4. **+10 of every seed**, plant one of each. Note pollen a minute (6) and the honey hover's guarding line (+25%).
5. **Next bloom now** (clover): pollen is 12 a minute, and the pollen hover names the clover.
6. **Next bloom now** (linden): the honey hover says guarding +50% and names the linden.
7. **Next bloom now** (goldenrod): propolis a minute doubles.
8. **Next bloom now** (winter): honey a second drops by a quarter, and the honey hover lists winter. **Next bloom now** again: "Spring again".
9. Spend 3 days away: the welcome-back message names the blooms that passed and the one out now.
10. Close and reopen: the bloom and its time left are the same.
