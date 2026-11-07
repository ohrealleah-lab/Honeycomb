# Feature Specification: Beekeeper (7th Honeycomb game)

**Feature Branch**: `009-beekeeper`
**Created**: 2026-11-06
**Status**: Draft v3 (v2 = analyzed; v3 = no bee limit, combs store honey, offline earnings up to 3 days)
**Platform order**: Windows first (Avalonia/.NET), because the co-designer tests on Windows only. Mac, iOS and Android follow; Windows is the reference for Beekeeper until Mac exists.

**Deliberate exceptions to Honeycomb's product rules** (Leah's decisions, to be written into `mac/CLAUDE.md` and `windows/CLAUDE.md` by task T053):
1. Beekeeper saves a game in progress on desktop. The rule "only Android saves a game in progress" covers the card games only.
2. Windows, not Mac, is the reference for Beekeeper's rules until a Mac version exists.
3. Beekeeper earns while the app is closed (up to 3 days). The card games have nothing like this.

**Sources** (all in `/Users/leah/Honeycomb/Beekeeper/`):
- `EARLY_LOOP_RULES.md` (v2): approved rules; the numbers there are final (storage 200 and +200 per comb approved by Leah on 2026-11-06 after the first-hour simulation; revisit after play-testing)
- `LONG_TERM_DESIGN.md`: where the game is going (not built now)
- `UI_SPEC.md` and `mockup_*.html`: approved layout, tokens, reveal order (needs a small refresh for v3, see T055)
- `README.md`, `csv/`, `Beekeeper_Game_Bible.xlsx`: Gemini's drafts. Leah's notes win where they disagree.

**Out of scope for this build**: candles, Chandler's Workshop, hive roles, the Smoker, tool upgrades, special bees and sites, hippies, hummingbirds, badgers, wasps, seasons, swarming. Leave layout room for them; build none of them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catch bees and make honey (Priority: P1)
A new player sees a quiet screen with a pixel-art frame, a Catch Bee button, a tool line and a story log. Clicking catches bees (there is no limit); the hive then makes honey and wax on its own.

**Independent Test**: start a new game, click Catch Bee repeatedly, watch bees, honey and wax appear in the order the reveal table gives.

**Acceptance Scenarios**:
1. **Given** a new game, **When** it opens, **Then** only the art frame, Catch Bee, the tool line ("Bare hands · 1 bee"), the story log and the BEES stat are visible.
2. **Given** Bare Hands, **When** the player clicks Catch Bee, **Then** there is a 20% chance of a sting (no bee, coral "stung" popup, ±3px button nudge) and otherwise a "+1 Bee" popup.
3. **Given** the player owns Padded Gloves or better, **When** they click, **Then** a sting never happens.
4. **Given** the hive has 12 bees and room in storage, **When** a second passes, **Then** honey rises by 12 × 0.01 = 0.12 (fractions kept, whole number shown).
5. **Given** any number of bees (for example 1,000,000), **When** the player clicks, **Then** the bees are added; there is no cap and no "hive is full".
6. **Given** honey storage is full, **When** time passes, **Then** no honey or wax is produced, and the log says "The combs are full of honey." once (not every second).
7. **Given** honey produced and stored: every 50 honey gives 1 wax (2 with the Wax-Catcher). Selling honey does not change wax progress.
8. **Given** 41 honey stored and 200 storage, with 100 bees, **When** 1 second passes, **Then** honey is 42; with 199.5 honey stored, **Then** honey becomes 200 (not 200.5) and the extra is lost.

### User Story 2 - Sell honey to the bear (Priority: P1)
At 10 honey a bear arrives with a random name and buys honey for Beebits.

**Acceptance Scenarios**:
1. **Given** the player first holds 10 honey, **Then** the Bear panel appears and stays for the rest of the game.
2. **Given** 10+ honey, **When** Sell 10 is pressed, **Then** honey drops by 10, Beebits rise by 1, trades rise by 1.
3. **Given** 47 honey, **When** Sell All is pressed, **Then** the player gets 4 Beebits, keeps 7 honey, and trades rise by 1.
4. **Given** under 10 honey, **Then** both sell buttons are unavailable.
5. **Given** a new game, **Then** the bear gets one of 7 names (Barnaby, Billy, Berenstein, Bruno, Baloo, Buster, Bartholomew), kept for the whole game and saved.

### User Story 3 - Buy better tools (Priority: P1)
When the player first reaches 15 Beebits the Beekeeper's Shop appears.

**Acceptance Scenarios**:
1. **Given** the player first reaches 15 Beebits, **Then** the shop appears and stays.
2. **Given** the shop, **Then** tools must be bought in order: Padded Gloves (15 ₿, 2 bees), Mesh Net (75 ₿, 5 bees), Bee-Safe Vacuum (250 ₿, 10 bees). Each replaces the one before and the tool line updates.
3. **Given** the Wax-Catcher (150 ₿), **When** bought, **Then** wax output doubles. It is independent of the tool order.
4. **Given** an item the player cannot afford, **Then** it is shown but unavailable; owned items show "✓ Owned".
5. **Given** the player has 80 Beebits and no Gloves, **Then** the Net and Vacuum are shown but unavailable (tools are bought in order), and pressing an unavailable item does nothing.

### User Story 4 - Build combs (Priority: P1)
**Acceptance Scenarios**:
1. **Given** the player first reaches 50 wax, **Then** the Combs panel appears and stays.
2. **Given** enough wax, **When** a comb is built, **Then** honey storage rises by 200 and the wax is spent. **Given** too little wax, **Then** the Build button is unavailable and pressing it does nothing.
3. **Given** N combs built, **Then** the next costs floor(50 × 1.25^N): 50, 62, 78, 97, 122, 152, 190…

### User Story 5 - Come back to the hive (Priority: P2)
**Acceptance Scenarios**:
1. **Given** a game in progress, **When** the app is closed and reopened, **Then** bees, honey (with fractions), wax progress, Beebits, tool, Wax-Catcher, combs, trades, bear name, revealed panels and the log are restored.
2. **Given** the app was closed for 2 hours with 100 bees and room in storage, **When** reopened, **Then** honey rose by 100 × 0.01 × 7,200 = 7,200 (up to storage) and wax by the matching amount, and the log says how much honey the bees made.
3. **Given** the app was closed for 10 days, **Then** only 3 days (259,200 seconds) of production is credited.
4. **Given** the saved time is in the future (clock set backwards), **Then** nothing is credited and nothing breaks.
5. **Given** storage fills 1 hour into an away period, **Then** production stops there; the rest of the time earns nothing.
6. **Given** the computer sleeps for 30 minutes with the app open, **Then** that gap is credited under the same rule as being closed.
7. **Given** the player switches to another Honeycomb game, **Then** the hive keeps running in the background.
8. **Given** a hive with at least one bee, **When** New Game is pressed, **Then** it first asks "Start over? Your hive and everything in it will be lost." (Leah kept this wording on 2026-11-07; the button may later be hidden or moved for Beekeeper); on confirm everything resets and a new bear name is chosen. **Given** a brand-new hive with no bees, **Then** New Game starts over without asking.
9. **Given** the player changes language in Options, **Then** every story-log line, including old ones, shows in the new language (the log is saved as event keys plus values, not as finished sentences).

### User Story 6 - Fits inside Honeycomb (Priority: P2)
**Acceptance Scenarios**:
1. **Given** the game picker, **Then** "Beekeeper" is the 7th entry; the toolbar shows only New Game and Options (no Restart, Hint, Undo).
2. **Given** any theme, **Then** Beekeeper uses its felt colour and accent.
3. **Given** the stats bar, **Then** order is BEES · HONEY · WAX · BEEBITS, tabular figures, bees shown as a plain number ("12"), honey shown with its storage ("45 / 200"), each stat appearing when revealed. Large numbers are shortened (1.2K, 3.4M) and follow the chosen language's number style.
4. **Given** Beekeeper is on screen, **Then** the Statistics and Reset Statistics menu entries are unavailable, and Undo, Hint and Restart are off.

## Reveal order *(from UI_SPEC §4)*
| Trigger | Appears |
|---|---|
| New game | Art frame, Catch Bee, tool line, story log, BEES |
| First bee caught | Hive card, HONEY |
| Holding 10 honey | Bear panel |
| First sale | BEEBITS |
| First wax drop | WAX |
| Reached 15 Beebits | Shop |
| Reached 50 wax | Combs panel (the Workshop is NOT shown in this build) |

"Sticky" means once revealed, it stays revealed (and is saved).

## Functional Requirements
- **FR-001**: Game logic lives in a view-independent engine (core library), unit-testable without UI. The engine has no clock. It offers "advance by N seconds" and, for long gaps, a fast route that does the same maths in one step (no loop over 259,200 seconds).
- **FR-002**: All tuning numbers (honey per bee 0.01, 50 honey per wax, 20% sting, tool costs and bees, 1.25 comb growth, 10 honey per Beebit, starting storage 200 and comb storage +200, offline cap 3 days, offline rate 100%) live in one config place, not scattered.
- **FR-003**: Randomness (sting, bear name) goes through an injectable random source so tests are deterministic.
- **FR-004**: Saving uses the app's atomic file writer into the Honeycomb data folder; autosave every few seconds and on quit; the save stores the time it was written. A corrupt save falls back to a new game.
- **FR-005**: The Beekeeper view model stays alive while the player uses other games.
- **FR-006**: Every visible string goes through the localization spreadsheet (English and Spanish) and the generator script. Layout must tolerate longer Spanish.
- **FR-007**: The story log shows the newest line first at full opacity, older lines fading; it is saved as event keys plus values (so a language change re-translates it) and capped at the last 50 lines.
- **FR-008**: Layout follows `UI_SPEC.md` (3 columns 340 / fluid / 260; tokens, fonts, Catch Bee 64px), with the v3 text changes (no bee capacity; honey storage instead). A 170×102 art frame slot is reserved.
- **FR-009**: Text must stay free of betting or gambling wording on every platform (trading honey for Beebits is fine; no "bet", "jackpot", "payout").
- **FR-010**: Leave layout room, but build no UI, for the Workshop, hive roles, Smoker, reputations, wasp panel and sites.
- **FR-011**: Big numbers use one shared formatter (short suffixes, language-aware) everywhere they are shown.
- **FR-012**: Time away is measured from the saved time. Real gaps over 2 seconds while the app is open are treated as time away. Negative gaps are ignored; gaps over 3 days are cut to 3 days.
- **FR-013**: Honey, wax and bees are stored in a number type that stays exact for 0.01 steps and can hold very large values (planned: `decimal`; revisit if the later game outgrows it).

## Key Entities
Colony (bees, combs, honey storage), Resources (honey with fraction, wax, wax progress, Beebits), Tool (owned level), Wax-Catcher (owned), Bear (name, trades), Reveal flags, Story log (list of event keys + values), Save file (with saved-at time).

## Draft story-log lines *(English; Leah and co-designer to edit, Spanish afterwards)*
| Event | Line |
|---|---|
| New game | "The garden hums. Your bees are frolicking." |
| First bee | "You cup a bee in your hands. It tickles." |
| Sting | "Ouch! A sting. No bee this time." |
| Storage full | "The combs are full of honey." |
| Bear arrives | "A bear wanders over. He says his name is {name}." |
| Each sale | "{name} counts it out." |
| First wax | "Wax drops, pale as moonlight." |
| Shop opens | "The Beekeeper's shop opens." |
| Padded Gloves | "Padded gloves on. Much braver." |
| Mesh Net | "A mesh net. Sweeping, not chasing." |
| Bee-Safe Vacuum | "The vacuum hums. The bees seem to like it." |
| Wax-Catcher | "The brass catcher gleams. Wax comes twice as fast." |
| Combs available | "There is wax enough for a new comb." |
| Comb built | "A new comb. Room for {n} more honey." |
| Welcome back (earned) | "While you were away, the bees made {n} honey." |
| Welcome back (nothing) | "The bees are glad you're back." |

## Assumptions & notes for review
- Starting honey storage 200 and +200 per comb were **approved by Leah on 2026-11-06** after the first-hour simulation (`Beekeeper/tools/simulate_first_hour.py`). They are first-build numbers: revisit after play-testing with the co-designer. Beebits lose their purpose after about 10 minutes in this build; that is expected until the Smoker, tool upgrades and roles arrive.
- Offline rate is 100% (confirmed by Leah, 2026-11-06).
- One Sell All = one trade. Bear names: all 7.
- Windows is the reference for Beekeeper rules until a Mac version exists; golden test vectors can be generated from the Windows engine later for the other platforms.
- Duplicated numbers: the config file is the single truth in code; `EARLY_LOOP_RULES.md` is the single truth on paper. Other documents (UI_SPEC, README, CSVs, workbook) must be brought in line (T055), not copied from.
- Help window gets a short "How to play Beekeeper" page. No Beekeeper-specific options and no sound in this build.

## Success Criteria
- **SC-001**: A player clicking about 3 times a second reaches the Bear in under 1 minute and the Shop in under 5 minutes (rough hand-check; exact pacing comes from the T006 simulation and play-testing).
- **SC-002**: Every acceptance scenario above has an automated engine test, and Leah has simple hand-test steps for the visual parts.
- **SC-003**: Close and reopen restores the game exactly, and a 2-hour absence credits exactly what scenario 5.2 says.
