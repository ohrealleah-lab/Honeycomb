# Feature Specification: Beekeeper, stage 10: the core trade loops

**Feature Branch**: `019-beekeeper-trade`
**Created**: 2026-11-12
**Status**: Specced 2026-11-12, from Bee's decisions in the planning session. **Systems first:** every number marked *(placeholder)* lives in `BeekeeperConfig` and is tuned later.
**Platform**: Windows only (Windows is the reference for Beekeeper).
**Builds on**: specs 009–018. Design: `Beekeeper/LONG_TERM_DESIGN.md`, "Update: The core trade loops" and the build roadmap.

**Why now**: since 2026-11-11 the Bear pays herbs and the Hippies pay every Beebit, so herbs are everywhere and the Bear isn't the honey buyer. In this stage **each trader gets one clear job.** Bee's decisions (2026-11-12):
- **Stage 10 is the trade loops only.** The new buyers (Hummingbirds, Badgers, the road to the orchard) move to stage 10.5.
- **The Bear buys honey for Beebits again**, and he's the only one who pays Beebits. He never stops being the honey buyer, and the trade agreement stays.
- **The game starts with 3 clay jars** and an opening story card.
- **Potted honey:** honey + 1 clay jar makes 1 potted honey, on the Hive card, from the first honey. **Only the Bear buys it**, at a better rate than plain honey.
- **The Hippies trade beeswax candles for clay jars** (Bee: "candles for pots only"). They never pay Beebits. The beeswax candle comes back for them.
- **Herbs come only from the leafcutter bee** (Bee, 2026-11-12: "an interesting boost for later"). The Hippies give none. Herbs are only for the buff candles (herbal and sage-propolis). **They leave the Shop's prices.**
- The 20% seed roll on every Hippie trade stays.

**In this build**: the Bear paying Beebits; potted honey (make it, sell it); clay jars; the opening story card; the beeswax candle; the Hippies' jar trade; herbs only from the leafcutter; herbs out of the Shop; hovers, words, save, debug, tests.
**Not in this build** (later stages): Hummingbirds, Badgers, the orchard (all stage 10.5), named honey, bottles and the honey house, paper labels, Make 10 for potted honey (make buttons are earned), herb kinds, renaming herbs back to sage, new uses for sage (e.g. Smoker fuel), bee hotel upgrades, the swarm. **Do not touch Beekeeper Help** (Bee: it will be very sparse at the end). Don't retune old prices, except taking herbs out of the Shop.

## Conflicts with what is already built
The 11-12 design note describes the trades as if the 11-11 changes hadn't happened. What the code does today, and what changes:

| Today (since 2026-11-11) | Stage 10 |
|---|---|
| The Bear gives **1 herb** for 10 honey (8 under the agreement). | The Bear gives **5 Beebits** for 10 honey (8 under the agreement). Herbs from the Bear are commented out. |
| The Hippies buy **herbal candles** for 10 Beebits each. All Beebits come from them. | The Hippies take **beeswax candles** and give **clay jars**. They pay no Beebits. Herbal candles are only for lighting. |
| The beeswax candle is commented out. | It comes back (wax only), as the Hippies' candle. |
| Sage is gone; herbs replaced it everywhere. | Unchanged. The design note's question "do herbs replace sage?" is already answered: yes. |
| Shop prices ask about 41 herbs (Bigger Combs II 20, More Practice 15, Better Wax-Catcher 5, Stronger Candles 1). | No herbs in the Shop. The old amounts stay in comments. |
| The first herb (from the Bear) opens the herbal candle recipe. | The leafcutter bee's first herbs open it. |

Things to watch:
1. **Beebits come only from the Bear.** Plain honey pays half a Beebit a honey; potted honey pays more. The Shop's Beebit prices were set when the Hippies paid 10 a candle. This stage doesn't retune them; the hand test will show where they feel slow.
2. **Herbs and buff candles move late** (Bee chose this, 2026-11-12). The leafcutter comes only with the bee hotel (100 wood), which needs the carpenter bee, which needs the first willow (in the Hippies' roll from trade 200). Until then: no herbal candles, so no buffs (Quick Fingers, Trades, Busy Bees…), and **Stronger Candles stays out of the Shop** (it needs the herbal recipe). The early game's new thing is potted honey. The mason bee's fallback herbs (when no seed has joined a roll yet) stay as they are; by the hotel they almost never happen.
3. **A Hippie trade is now one jar** (several candles), not one candle. Seeds join the roll at trades 40, 200 and 400, so seeds now arrive a few times slower in candles. The meadow (50 wildflowers, 50 clover) and the willow (so the hotel and its herbs) get further away. Left as is; tune later.
4. **The Smoker, the gloves, "Ouch!" and the seed card** queue behind the opening card, since one card shows at a time. The opening card goes away by itself at the first bee caught, so nothing waits for long.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The opening (Priority: P1)
1. **Given** a new game, **Then** the story area shows the opening card: *"You have just inherited your grandmother's farmhouse. In the garden, you find a skep and a few clay jars. It seems a little quiet. What will you do?"* with one button, **"Look around"** *(draft)*.
2. **Given** a new game, **Then** the hive holds **3 clay jars** *(placeholder)*, and the Hive card shows a Clay jars row.
3. **Given** the opening card, **When** the button is clicked **or the first bee is caught**, **Then** the card is done for good.
4. **Given** an older save, **When** it loads, **Then** it gets the 3 jars once and the opening card counts as done (it never shows).

### User Story 2 - Potting honey (Priority: P1)
1. **Given** the first honey, **Then** the Hive card shows a **"Pot honey"** button (10 honey + 1 jar, *placeholder*). It is disabled while either is short.
2. **When** clicked, **Then** 10 honey and 1 jar are used up and 1 potted honey is added. The jar is gone.
3. **Given** the first potted honey, **Then** a Potted honey row shows on the Hive card (sticky).
4. Potted honey **has no cap** and doesn't count toward the honey cap, so potting frees honey room.
5. There is **one Pot honey button only**: a Make 10 comes later from an upgrade (Bee's rule: make buttons are earned).

### User Story 3 - The Bear (Priority: P1)
1. **Given** the Bear, **When** plain honey is sold, **Then** 10 honey pays **5 Beebits** *(placeholder; the rate before 2026-11-11)*. Under the agreement a bundle is 8 honey for the same 5 Beebits (today's agreement, unchanged).
2. **Given** potted honey, **Then** the Bear's card shows **"Sell potted honey"** (1) and **"Sell all potted"**: each potted honey pays **15 Beebits** *(placeholder; 3× the plain rate for the same 10 honey)*.
3. Each sale click (plain or potted, one or all) **counts as one Bear trade** toward the agreement at 40, as Sell All does today.
4. The agreement's better rate is for plain honey only *(default)*. Potted honey has its own price.
5. The Bear never gives herbs.

### User Story 4 - The beeswax candle (Priority: P1)
1. **Given** the Workbench, **Then** the beeswax candle can be crafted: **2 wax** *(placeholder)*, no herb. It's available from the start of the Workbench, before any herb.
2. The Dipping Rack halves its wax (rounded down, as for every candle), and Candle Molds make 2 per craft, as for every candle.
3. Beeswax candles count toward the **5 candles that bring the Hippies**.
4. A beeswax candle can't be lit. It's for the Hippies.

### User Story 5 - The Hippies (Priority: P1)
1. **Given** the Hippies and enough candles, **Then** their card shows **"Trade 3 candles for a clay jar"** *(placeholder)* and **"Trade all"** (as many jars as the candles allow).
2. **Each jar is one Hippie trade**: the trade count goes up by 1, and the 20% seed roll and the seed join points work per jar, as they did per candle.
3. The Hippies **only take beeswax candles**. Herbal, bee-boost and sage-propolis candles stay on the shelf.
4. The Hippies pay **no Beebits** and give **no herbs**.

### User Story 6 - Herbs (Priority: P1)
1. Herbs come only from **the leafcutter bee** (2 a gift, already built), plus the mason bee's rare fallback. Nothing else gives them.
2. **The first herbs** show the Herbs row and open the herbal candle recipe (with today's log line).
3. Herbs are spent only on **the herbal candle** (1) and **the sage-propolis candle** (1). Shop upgrades ask for **no herbs**; their herb part is commented out with the old amount.
4. The "Trades" buff from a lit herbal candle now gives **+50% Beebits from the Bear** (plain and potted). It doesn't touch the Hippies (half a jar isn't a thing).

### User Story 7 - Hovers (Priority: P1)
1. **Beebits** hover (growth-hover rule): every source. Plain honey (rate, and the agreement), potted honey (rate), and the Trades herb when it burns.
2. **Clay jars** hover: where jars come from (3 at the start, the Hippies' trade) and what they're for.
3. **Herbs** hover: where they come from (the leafcutter bee, from the bee hotel) and what they're for.

## Reveal order (changes)
| Trigger | Appears |
|---|---|
| New game | the opening card; Clay jars row (3) |
| First honey | the Pot honey button |
| First potted honey | Potted honey row; the Bear's potted-honey buttons (once the Bear is here) |
| The Workbench (3 combs) | the beeswax candle's recipe (beside the herbal candle's, which still waits for the first herb) |
| 5 candles crafted (any kind) | the Hippies (unchanged rule; now reachable with beeswax candles) |
| First herbs (the leafcutter bee) | Herbs row; the herbal candle's recipe; then Stronger Candles in the Shop |

## Functional Requirements
- **FR-1001**: Every number lives in `BeekeeperConfig`.
- **FR-1002**: **The Bear pays Beebits.** Bring back `BeebitsPerTrade` (5) and pay `bundles × BeebitsPerTradeNow` (with the Trades herb). Comment out `HerbsPerTrade`, `HerbsPerTradeNow` and the herb lines in `Sell` with a `// Cut (Bee, 2026-11-12): the bear paid herbs` note. The agreement keeps `BetterHoneyPerTrade` (8). The first sale no longer opens the herbal recipe; `BeebitsRevealed` is set as before 11-11.
- **FR-1003**: **Clay jars.** `StartingClayJars` (3). New state: `ClayJars` (decimal) and `StartingJarsGiven` (bool). A new game sets both. On load, a save with `StartingJarsGiven == false` gets the jars, the flag, and the opening card marked done.
- **FR-1004**: **The opening card.** A new `BeekeeperStories.Opening`, first in `Order`, due while not done. `BeginFromStory()` (the button) finishes it. The first bee caught by hand also finishes it, silently. No log line: the card speaks.
- **FR-1005**: **Potted honey.** `PotHoneyHoney` (10). New state: `PottedHoney` (decimal), `PottedHoneyRevealed` (bool, sticky). `CanPotHoney` (honey ≥ 10 and jars ≥ 1); `PotHoney()` takes 10 honey and 1 jar, adds 1, refreshes the storage flag (honey went down) and raises `HoneyPotted`. The button is visible from the first honey (`HoneyRevealed` or the existing equivalent).
- **FR-1006**: **Selling potted honey.** `PottedHoneyBeebits` (15). `SellPotted()` (one) and `SellAllPotted()`; each click is one Bear trade (`State.Trades++`, `OfferAgreementIfDue`). Pays `n × PottedHoneyBeebits × HerbTradeNow`. Raises `PottedSale` (Value: Beebits, Value2: pots). Only while the Bear is here (not chased off by a shoe), the same rule as plain sales.
- **FR-1007**: **The beeswax candle.** `BeeswaxCandleWax` (2), read through `CandleWax()` so the Dipping Rack applies; `CandlesPerCraft` applies. State `BeeswaxCandles` (decimal). `CraftBeeswax(int count = 1)` counts toward `CandlesCrafted` (the Hippies' reveal). Its recipe shows with the Workbench. One Craft button, the same as the herbal candle. Not lightable.
- **FR-1008**: **The Hippies' jar trade.** `CandlesPerJar` (3). `CanTradeCandles` reads beeswax candles ≥ `CandlesPerJar`. `TradeCandles(all)` takes `jars × CandlesPerJar` beeswax candles, adds `jars` clay jars, and for each jar: `HippieTrades++`, `UnlockSeedsIfDue` and the seed roll. Comment out the Beebit payment (`HippieBeebitsPerCandle`, `BeebitsPerCandleNow`) with a `// Cut (Bee, 2026-11-12)` note. Raises `CandlesTraded` (Value: jars, Value2: candles).
- **FR-1009**: **Herbs only from the leafcutter.** Any herb gift (the leafcutter, and the mason's fallback) sets `HerbsRevealed` and, if it's the first herb, opens the herbal recipe (`RepellentUnlocked`, the existing event). Check what the hotel gift does today and add this where it's missing. *(Considered and dropped, Bee, 2026-11-12: an herb every 5th Hippie trade. Not built, so nothing to comment out.)*
- **FR-1010**: **Herbs leave the Shop.** In `Upgrades`, set the herb part to 0 on Bigger Combs II (was 20), Better Wax-Catcher (5), Stronger Candles (1) and More Practice (15), with the old amounts in a comment. Leave the `Herbs` field on `BeekeeperUpgrade` (it may be used again). Shop text with a zero herb part shows no herb line (check it already does).
- **FR-1011**: **Herbal candles** keep their recipe (2 wax + 1 herb) and lighting. The Hippies no longer take them. The view's Hippie section stops offering them.
- **FR-1012**: **The Trades herb** multiplies the Bear's Beebits, plain and potted. Its hover words change to say so.
- **FR-1013**: **Events, not sentences.** New: `HoneyPotted`, `PottedSale`, `BeeswaxCrafted` (only for batches, as `Crafted` is today). Changed meaning: `Sale` (Value is now Beebits), `CandlesTraded` (Value is now jars).
- **FR-1014**: **Save.** New fields load as zero or false, so no version bump: `ClayJars`, `StartingJarsGiven`, `PottedHoney`, `PottedHoneyRevealed`, `BeeswaxCandles`. Older saves keep their herbs, herbal candles and trade counts. Load checks: no negative jars, potted honey or candles.
- **FR-1015**: **Hovers** (User Story 7). Every auto-growing stat's hover lists all its sources.
- **FR-1016**: **Words** through `tools/Honeycomb_Localization.xlsx` (English + Spanish draft) with a small openpyxl script, then `python tools/generate_localization.py`. **No Help changes.**
- **FR-1017**: **Debug menu.** Add **"+10 clay jars"**, **"+10 potted honey"** and **"+30 beeswax candles"**. Keep the existing Hippie, Bear and bee hotel shortcuts working (a hotel gift shortcut is how to get the first herbs).
- **FR-1018**: **Comment out, don't delete.** The Bear's herb pay and the Hippies' Beebit pay are commented out with dated notes. Replaced internals (old event meanings) are changed in place.

## Placeholder numbers (all in `BeekeeperConfig`)
| Setting | Value |
|---|---|
| `StartingClayJars` | 3 |
| `PotHoneyHoney` | 10 honey per potted honey |
| `BeebitsPerTrade` | 5 Beebits per bundle (10 honey; 8 under the agreement) |
| `PottedHoneyBeebits` | 15 Beebits per potted honey |
| `BeeswaxCandleWax` | 2 wax (1 with the Dipping Rack) |
| `CandlesPerJar` | 3 beeswax candles per clay jar |
| Shop herb prices | all 0 (old amounts in comments) |
| Herbs | the leafcutter's 2 a gift, unchanged (`RareBees`) |

**Pacing, roughly:** 10 honey is 5 Beebits plain or 15 potted. A jar costs 3 candles = 6 wax (3 with the rack), so potting is clearly worth it: +10 Beebits for 6 wax. Jars are the limit on how much honey can be potted, and candles are the limit on jars. Herbs start with the bee hotel: a gift every 30 minutes, a leafcutter one time in three, so about 4 herbs every 3 hours (live or away).

## Draft words *(English; Bee to edit, Spanish afterwards)*
| Where | Line |
|---|---|
| Opening card | "You have just inherited your grandmother's farmhouse. In the garden, you find a skep and a few clay jars. It seems a little quiet. What will you do?" (Bee's words) |
| Opening button | "Look around" |
| Hive row | "Clay jars" · "Potted honey" |
| Pot button | "Pot honey" · hover "10 honey + 1 clay jar → 1 potted honey. The Bear pays more for it." |
| Log: first potted honey | "You fill your grandmother's first jar with honey." |
| Bear buttons | "Sell potted honey" · "Sell all potted" |
| Log: potted sale | "{bear} pays {n} Beebits for {pots} potted honey." |
| Log: plain sale | "{bear} pays {n} Beebits for {honey} honey." (as before 11-11) |
| Workbench | "Beeswax candle" · "2 wax. The Hippies like these." |
| Hippie buttons | "Trade 3 candles for a clay jar" · "Trade all" |
| Log: jar trade | "The Hippies give you {n} clay jar(s) for {candles} candles." |
| Hover: clay jars | "3 were in the garden. The Hippies trade more for beeswax candles. Each one pots 10 honey." |
| Hover: herbs | "The leafcutter bee brings them from the bee hotel. Used for herbal and sage-propolis candles." |
| Hover: Trades herb | "+50% Beebits from the Bear." |

## Defaults taken in writing the spec (easy to change)
1. **Herbs keep their name** ("herbs") for now. Whether they go back to being called sage, or sage becomes one herb among others, is open (Bee, 2026-11-12).
2. **Clay jars and "artisan clay pots" are the same thing**, one stock called clay jars. The Hippies' words can say "artisan" if Bee likes.
3. A Hippie trade is **one jar**, not one candle; seeds roll per jar.
4. The opening card **also goes away at the first bee caught**, so it never holds up "Ouch!" or the gloves.
5. Older saves get the 3 jars once and skip the opening card.
6. Potted honey has **no cap** and doesn't count toward the honey cap.
7. The agreement improves **plain honey only**; potted honey has one price.
8. **Each Bear sale click is one trade**, potted or plain, one or all.
9. The Trades herb boosts the **Bear's Beebits** only.
10. The beeswax candle is **2 wax** and the Hippies take only beeswax candles.
11. No Make 10 for potting (make buttons are earned).
12. No Help changes.

## Tests
- New game: 3 jars, the opening card is up; its button finishes it; the first bee caught finishes it too; an older save gets 3 jars once and never sees the card.
- Pot honey: needs 10 honey and a jar; uses both; adds 1; refused when either is short; potted honey isn't capped and frees honey room.
- The Bear: plain sale pays 5 Beebits a bundle (8 honey under the agreement); no herbs; potted sale pays 15 each; Sell all potted sells every pot; each click counts once toward the agreement; refused while the Bear is away.
- The Trades herb: plain and potted Beebits ×1.5.
- Beeswax candle: 2 wax, 1 with the rack; 2 per craft with molds; counts toward the Hippies' 5; can't be lit.
- Hippies: 3 beeswax candles → 1 jar; Trade all makes as many as fit; each jar is one trade; no Beebits and no herbs; herbal candles untouched; the seed roll still runs per trade.
- Herbs: nothing but a hotel gift gives them; the leafcutter's first herbs open the herbal recipe and the Herbs row; Stronger Candles waits for that recipe.
- Shop: no upgrade asks for herbs; upgrades that used to are buyable without them.
- Save: new fields round-trip; negatives are fixed on load.
- Hovers: Beebits lists plain, potted and the Trades herb; herbs names the leafcutter.
- **Older tests:** many tests assume the Bear pays herbs or the Hippies pay Beebits (`BeekeeperStage2Tests`, `Stage3`, `Stage4`, `Stage5`, `Stage7`, `Stage8`, `BeekeeperHerbTests`, `BeekeeperEngineTests`, `BeekeeperLoadFixesTests`, the view-model tests). Update them to the new trades; don't delete what they check.

## Success Criteria
- **SC-1001**: Every acceptance scenario has an engine or view-model test; Bee has hand-test steps with debug shortcuts.
- **SC-1002**: The Bear is the only source of Beebits (plus the 75 a new game starts with).
- **SC-1003**: No Shop upgrade asks for herbs.
- **SC-1004**: A stage 9 save loads without losing anything and gets its 3 jars.

## Hand-test (Bee) — debug build, Banners menu in the toolbar
1. Start a new game: the opening card shows, and the Hive card has 3 clay jars. Click **Look around**: the card goes.
2. Start another new game and catch a bee without clicking the card: it goes by itself.
3. Make 10 honey: **Pot honey** shows. Click it: honey −10, jars 2, potted honey 1.
4. Get the Bear (100 bees caught): sell plain honey (5 Beebits a bundle, no herbs), then **Sell potted honey** (15 Beebits).
5. Hover Beebits: it lists plain honey, potted honey and the agreement.
6. Get to the Workbench (3 combs): craft 5 beeswax candles. The Hippies arrive.
7. **+30 beeswax candles**, then **Trade all**: 10 jars, no Beebits and no herbs. The herbal recipe is still closed.
8. Open the Shop: Bigger Combs II, Better Wax-Catcher and More Practice ask for no herbs; Stronger Candles isn't there yet.
9. Use the bee hotel debug shortcuts until a leafcutter brings herbs: the Herbs row shows, the herbal recipe opens, and Stronger Candles joins the Shop with no herb price.
10. Craft and light an herbal candle until it rolls **Trades**: plain and potted sales pay half again.
11. Close and reopen: jars, potted honey and beeswax candles are the same. Load a save from before this stage: it has 3 extra jars and no opening card.
