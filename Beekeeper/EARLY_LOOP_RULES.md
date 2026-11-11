# Beekeeper: Early Loop Rules (v2, 2026-11-06)

Built from Leah's notes. Where Gemini's files disagree, that's listed at the bottom.
**v2 change:** there is no limit on bees. Combs now store honey. Offline earnings are in (up to 3 days).
Numbers marked as approved were checked with a first-hour simulation (Beekeeper/tools/simulate_first_hour.py).

**v3 change (Bee, 2026-11-09; stage 7.5, spec `windows/016-beekeeper-combs/`, built 2026-11-09):** combs make the honey, bees and wax buy combs, and honey and wax each have a cap. **The game follows the rules marked "From stage 7.5"; the ones marked "Replaced" are kept for the record (their code is commented out).** All new numbers are placeholders in `BeekeeperConfig`.

## What's in the first build
Catch bees, honey, wax, the bear, the shop, combs, saving, offline earnings.
NOT in the first build (planned, see `LONG_TERM_DESIGN.md`): candles, hive roles, the Smoker, tool upgrades, special bees and sites, wasps, hippies, hummingbirds, badgers, seasons, swarming.

## 1. Catching bees
- Button: **Catch Bee**. Each click catches bees according to the tool you have. **There is no limit on how many bees you can have.**
- **From stage 7.5:** the bees you hold are **free bees**. Bees spent on a comb move in and leave that count, and the catch slice reads free bees only.
- A popup appears on each click: "+1 Bee" (or "+2 Bees" etc.).
- **Stinging:** with **Bare Hands only**, and only after the first **10 bees caught by hand** (never before). The first sting at 10 is certain and brings the "Ouch!" story card; after that each click has a **20% chance** of a sting. A sting catches **no bees**, and the popup says so. The Catch Bee button then turns red and is disabled for **1 second**.
  Once you have the Padded Gloves (found, not bought: see Story cards), stings stop for good.

| Tool | Cost | Bees per click |
|---|---|---|
| Bare Hands | free | 1 (20% sting) |
| Padded Gloves | found (story card) | 2 |
| Mesh Net | 75 Beebits | 5 |
| Bee-Safe Vacuum | 250 Beebits | 10 |

The gloves are found, never bought. After that, tools are bought **in order** (Net, then Vacuum, then the stage 3 tools). Each replaces the one before. **Without the gloves the Shop lists no catching tools** (Practice and More Practice need the Vacuum, so they wait too).

### Story cards
Small story moments appear in the **story area** at the top of the left column (where the bee art is; the bee art shows when there is no story). Visitors (Bear, Hippies) show there too. Story cards are **one at a time, in a fixed order**; each has its own buttons.
0. **Ouch!**, after the first sting (at 10 bees caught by hand). OK to dismiss; said once.
1. **Gloves**, due once **30 bees** have been caught by hand (all time). "You find a pair of gloves on the ground. Put them on?" **Yes**: gloves on (2 bees a click, no more stings). **No**: the card goes away and comes back after **2 minutes of play** (not while away). The **5th No** puts it away for good ("You're one tough cookie. Bare hands it is.") and sets a saved flag for a future hard-mode achievement.
2. **Smoker**, due when the hive holds **250 bees** (once shown, it stays until answered). "An old smoker lies in the grass…" **Repair?** is free and the Smoker works at once. It is no longer sold in the Shop.

A save that already has the gloves or the Smoker never sees that card. To add a moment: an id in `BeekeeperStories`, its "due" rule and answers in `BeekeeperEngine`, and one case in `BeekeeperView.UpdateStory`.

## 2. Honey
- **From stage 7.5:** every second, each comb makes **0.2 honey** *(placeholder)*, however many bees live in it. You start with one comb, and it makes no honey until the first bee is caught. Calm, candles, the wooden hive and guarding boost this honey.
- *(Replaced by stage 7.5)* Every second, each bee makes **0.01 honey**. (100 bees = 1 honey per second.)
- Honey is shown as a whole number (fractions are kept behind the scenes).
- **Honey storage:** honey lives in the combs. You start with room for **200 honey** *(first build's number; a placeholder from stage 7.5, where it includes the starter comb)*. When storage is full, the honey stops (nothing is wasted or sold automatically) and the log says "The combs are full of honey."

## 3. Wax
- **From stage 7.5:** wax per second = (**0.005** + free bees × **0.0001**) × the Wax-Catcher *(placeholders)*. It runs from the start of the game and is not multiplied by combs. Calm and the honey boosts do not touch it.
- **From stage 7.5: wax has a small cap**, starting at **20** *(placeholder)*. At the cap, wax stops. The cap is small on purpose: it stops a fast clicker from running away, and a price above it is a wall that shows where an upgrade belongs.
- **From stage 7.5:** the **Wax-Catcher** (150 Beebits) doubles the wax rate, and the Better Wax-Catcher makes it three times.
- *(Replaced by stage 7.5)* Wax drops from **all the honey the bees make**, including honey that doesn't fit because the combs are full (Leah, 2026-11-07). Selling honey never costs you wax progress.
- *(Replaced by stage 7.5)* **50 honey = 1 wax.**
- *(Replaced by stage 7.5)* **Wax-Catcher** (150 Beebits): doubles it, so 2 wax per 50 honey.
- *(Replaced by stage 7.5)* Wax has no storage limit in the first build.

## 4. Combs (honey, and room for honey and wax)
**From stage 7.5** *(all numbers placeholders)*:
- You start with **one comb**. Each comb you buy adds **0.2 honey a second**, **+300 honey room** and **+2 wax room**.
- A comb costs **bees and wax**, starting at **250 bees and 5 wax** (Bee, 2026-11-11: wax was 10). The bee price grows 40% each, the wax price **25%** each (rounded down). The starter comb doesn't count towards the price: wax 5, 6, 7, 9, 12, 15, 19...
- The bees you pay move in and stop being free bees. How many bees fit in a comb is simply its bee price.
- The Combs panel appears when you first have **5 wax** and stays after that.
- **Capacity upgrades** can be bought again and again, for Beebits: **Honey Super** (+1,000 honey room) and **Wax Tray** (+8 wax room).
- **Technologies** (Bigger Combs and the Propolis Seal) are one-time % boosts on **both** caps.
- **A price above a cap is a wall, and walls are intended.** The screen says it needs more storage. There is no rule that caps must stay above prices.

*(Replaced by stage 7.5)*
- Each comb adds **+200 honey storage** *(approved for the first build; revisit after play-testing)*.
- First comb costs **50 wax**. Each further comb costs **25% more** than the last (rounded down):
  50, 62, 78, 97, 122, 152, 190...
- The Combs panel appears when you first have 50 wax and stays after that.

## 5. The Bear (selling honey)
- The bear (and so the trade panel) appears once you have caught **100 bees by hand** (100 successful clicks), and stays after that. (Before 2026-11-11: at 10 honey.)
- **10 honey = 1 Beebit.**
- **Sell All** turns as much honey as it can into Beebits, in whole bundles of 10. Any left over (under 10) stays with you.
- The bear gets a random name **per game** (Barnaby, Billy, Berenstein, Bruno, Baloo, Buster, Bartholomew), chosen when a new game starts and then kept.
- Each sale counts as a **trade**. Sell All counts as **1 trade**. The counter is kept now; the 100-trade wasp perk comes with wasps later.
- **From stage 7.5:** at **25 trades**, the bear's trade agreement gives a better rate: **8 honey = 1 Beebit** *(placeholder)*. Selling stays in whole bundles at the rate of the moment. There is no auto-sale: when the combs are full, honey simply stops.

## 6. The Shop
- A new game **starts with 75 Beebits and the Shop open** (Bee, 2026-11-11): enough for one Wax-Catcher (75) right away, a free choice. (Otherwise it appears once you've reached 10 Beebits.)
- Sells: Mesh Net, Bee-Safe Vacuum (once you have the gloves), Wax-Catcher (75 Beebits). Stage 7.5 leaves these prices alone for now; the ones to look at again are listed in `windows/016-beekeeper-combs/spec.md`.
- Items you can't afford yet are shown but unavailable. Owned items show as owned.

## 7. Saving and offline earnings
- Progress saves automatically (every few seconds and on quitting) and is restored on launch.
- **Offline earnings:** while the app is closed, the bees (from stage 7.5, the combs and the free bees) keep working for up to **3 days** (72 hours). Anything beyond 3 days is not earned. They earn at the **full 100% rate** (confirmed by Leah; one number in the config).
- Offline honey still obeys honey storage: full combs stop honey being stored, so building combs is how you earn more honey while away. Wax keeps coming while away, even with full combs (up to the 3-day limit). *(Replaced by stage 7.5: wax stops at the wax cap, while away as well.)*
- When you come back, the log tells you what happened, e.g. "While you were away, the bees made 340 honey."
- A computer sleeping or a frozen window counts as time away under the same rule. A clock set backwards earns nothing.
- A **New Game** option asks "Start over? Your hive will be lost." (only if you have bees; from stage 7.5, once the first bee has been caught, since a hive can have zero free bees) before it does anything. A new game picks a new bear name.

## 8. Text and look
- Plain text style (like *A Dark Room*): atmospheric lines, no card imagery. A frame slot is reserved for your pixel art later.
- All words go through the English and Spanish translation spreadsheet.
- Big numbers are shortened (1.2K, 3.4M) and follow the language's number style.

## Where Gemini's files disagree with your notes (your notes win)
1. Gemini has **no sting** mechanic. Added from your notes.
2. Gemini's README and CSVs still show a bee limit (older numbers 20 / 500). The limit is gone.
3. Gemini's CSV lists 5 bear names, its README lists 7. Using 7.
4. Gemini treats the Bear and Hippies as plain buyers. Your notes have four reputations. Not in the first build.
5. Gemini's wasps kill 50% of bees. Your decision: **wasps steal honey** (cozy). Not in the first build.
6. Gemini's Sage-Propolis candle lasts 180s; your notes say "X amount of time" (later).

## Achievements to build later (Bee, 2026-11-11)
There is no Beekeeper achievements system yet. The numbers are already saved, so one can read them later:
- **100 successful clicks**: `BeekeeperState.BeesCaught >= 100` (bees caught by hand, stings don't count). The same moment the bear arrives.
- **Tough cookie (hard mode)**: `BeekeeperState.GlovesRefusedForGood`, set on the 5th No to the gloves.
