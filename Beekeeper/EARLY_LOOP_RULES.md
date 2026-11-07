# Beekeeper: Early Loop Rules (v2, 2026-11-06)

Built from Leah's notes. Where Gemini's files disagree, that's listed at the bottom.
**v2 change:** there is no limit on bees. Combs now store honey. Offline earnings are in (up to 3 days).
Numbers marked as approved were checked with a first-hour simulation (Beekeeper/tools/simulate_first_hour.py).

## What's in the first build
Catch bees, honey, wax, the bear, the shop, combs, saving, offline earnings.
NOT in the first build (planned, see `LONG_TERM_DESIGN.md`): candles, hive roles, the Smoker, tool upgrades, special bees and sites, wasps, hippies, hummingbirds, badgers, seasons, swarming.

## 1. Catching bees
- Button: **Catch Bee**. Each click catches bees according to the tool you have. **There is no limit on how many bees you can have.**
- A popup appears on each click: "+1 Bee" (or "+2 Bees" etc.).
- **Stinging:** with **Bare Hands only**, each click has a **20% chance** of a sting. A sting catches **no bees**, and the popup says so.
  Once you own Padded Gloves (or anything better), stings stop for good.

| Tool | Cost | Bees per click |
|---|---|---|
| Bare Hands | free | 1 (20% sting) |
| Padded Gloves | 15 Beebits | 2 |
| Mesh Net | 75 Beebits | 5 |
| Bee-Safe Vacuum | 250 Beebits | 10 |

Tools must be bought **in order** (Gloves, then Net, then Vacuum). Each replaces the one before.

## 2. Honey
- Every second, each bee makes **0.01 honey**. (100 bees = 1 honey per second.)
- Honey is shown as a whole number (fractions are kept behind the scenes).
- **Honey storage:** honey lives in the combs. You start with room for **200 honey** *(approved for the first build; revisit after play-testing)*. When storage is full, the bees stop making honey (nothing is wasted or sold automatically) and the log says "The combs are full of honey."

## 3. Wax
- Wax drops from **all the honey the bees make**, including honey that doesn't fit because the combs are full (Leah, 2026-11-07). Selling honey never costs you wax progress.
- **50 honey = 1 wax.**
- **Wax-Catcher** (150 Beebits): doubles it, so 2 wax per 50 honey.
- Wax has no storage limit in the first build.

## 4. Combs (more honey storage)
- Each comb adds **+200 honey storage** *(approved for the first build; revisit after play-testing)*.
- First comb costs **50 wax**. Each further comb costs **25% more** than the last (rounded down):
  50, 62, 78, 97, 122, 152, 190...
- The Combs panel appears when you first have 50 wax and stays after that.

## 5. The Bear (selling honey)
- The trade panel appears when you first hold **10 honey**, and stays after that.
- **10 honey = 1 Beebit.**
- **Sell All** turns as much honey as it can into Beebits, in whole bundles of 10. Any left over (under 10) stays with you.
- The bear gets a random name **per game** (Barnaby, Billy, Berenstein, Bruno, Baloo, Buster, Bartholomew), chosen when a new game starts and then kept.
- Each sale counts as a **trade**. Sell All counts as **1 trade**. The counter is kept now; the 100-trade wasp perk comes with wasps later.

## 6. The Shop
- Appears once you've first reached **15 Beebits**, and stays after that.
- Sells: Padded Gloves, Mesh Net, Bee-Safe Vacuum, Wax-Catcher.
- Items you can't afford yet are shown but unavailable. Owned items show as owned.

## 7. Saving and offline earnings
- Progress saves automatically (every few seconds and on quitting) and is restored on launch.
- **Offline earnings:** while the app is closed, the bees keep working for up to **3 days** (72 hours). Anything beyond 3 days is not earned. They earn at the **full 100% rate** (confirmed by Leah; one number in the config).
- Offline honey still obeys honey storage: full combs stop honey being stored, so building combs is how you earn more honey while away. Wax keeps coming while away, even with full combs (up to the 3-day limit).
- When you come back, the log tells you what happened, e.g. "While you were away, the bees made 340 honey."
- A computer sleeping or a frozen window counts as time away under the same rule. A clock set backwards earns nothing.
- A **New Game** option asks "Start over? Your hive will be lost." (only if you have bees) before it does anything. A new game picks a new bear name.

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
