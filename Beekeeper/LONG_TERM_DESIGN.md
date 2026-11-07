# Beekeeper: Long-Term Design (planned, NOT in the first build)

Written 2026-11-06 from Leah's decisions. Inspired by idle games like Kittens Game, but not a copy: the hooks below come from real beekeeping.

## The shape of the game
- **Length:** 1.5 to 4 weeks. Growth should level off around week 3, which is where the first swarm (reset) happens.
- **Tone:** cozy. Wasps steal honey; some bees flee during a raid (nobody is killed). Later pests may steal other resources.
- **Offline:** the bees work while the app is closed, up to 3 days. Honey storage limits it.
- **No bee limit.** Big, growing swarms are the fun. The limits are on honey storage and on prices.

## The core loop (what each part is for)
| Part | Job in the loop |
|---|---|
| **Clicking: Catch Bee** | Brings in bees, forever. Gets stronger with tools, tool upgrades, a slice of the current colony per click, and the Smoker. |
| **Bee types and flowers** | Replaces "hive roles" (Leah, 2026-11-07): with no bee limit, bees can't be assigned one by one, so roles come from kinds of bees, attracted by planting flowers. |
| **Combs** | Honey storage (and later room for role cells). Cost grows 25% each. |
| **Bear and other buyers** | Turn goods into Beebits. Reputations are relationships: each buyer wants and gives something different. |
| **Tools and upgrades** | Spend Beebits to make clicking and the colony stronger. |
| **Swarm (reset)** | The hive splits: the queen leaves with half the bees, you start a new hive with a lasting bonus. |

## Planned stages
1. **First build (now):** catch, honey, wax, bear, shop, combs, saving, offline.
2. **Smoker + tool upgrades:** clicking builds a "calm" meter that boosts the colony for a short time; each tool gets upgrade tiers; a click also catches a small slice of the current colony. Keeps clicking relevant all game.
3. **Seeds, discovery and bee types** (replaces "hive roles"; Leah's notes and design pivot, 2026-11-07):
   - **No assigning bees.** Kittens Game can assign individual kittens because it has a small population; Beekeeper has no bee limit, so roles come from **kinds of bees**, each counted on the Hive card.
   - **Planting a seed is how new kinds of bees are discovered.** Each new kind unlocks a new resource or gives a buff.
   - **Seeds come from the Hippies**: after 5 trades they give a seed; different seeds come after further trades. No sage plants: sage stays the Hippies' trade.
   - **The Garden card** appears with the first seed: a "Plant seed?" button, which then reads "Something is growing!". About 10 minutes later the log says "Your seed has sprouted." and the Garden shows the plant and the kind of bee it attracts.
   - **Forager bees** (from a plant) bring back **pollen**. Pollen becomes **bee bread**, used with wax for hive upgrades.
   - **Guard bees are attracted by a plant, not bought** (design pivot): once you have them, raids never make bees fly off. The wasp can still take honey.
   - **Propolis**: real hives have no separate propolis bee; a few older foragers collect tree resin ("resin foragers"). Later, a tree (e.g. a poplar) could attract resin foragers for propolis and the bee-boost candle.
   - **Changed (Leah, 2026-11-07): plants give the hive a specialty, not a count of bees.** Counts of forager and guard bees are meaningless and go. Wildflowers give **foraging** (pollen at a steady rate); bramble gives **guarding**, which is now "the hive feels safe": a production boost (raids are out as guarding's job). Later, several plants at once give several specialties. To be built in stage 6.
   - **A Bees card** explains what each kind of bee does, with bee facts. Cut after stage 4 play-testing, but **it can come back later** (Leah): its words and code are in the stage 4 commit `f196a8a`, before they were removed. Next time, comment things out rather than deleting them.
   - **Where the bees live (the ladder)**: **one hive only, by different names** (Leah, 2026-11-07). The one hive moves: a skep in the garden, then a wooden hive in the garden, then a hive in the meadow, then in the orchard, and on. Never a count of hives. Hive upgrades cost wax and bee bread. The honey house may come later as an upgrade that automates something.
   - Open: what each later seed grows and attracts, what each step of the ladder gives, and what the honey house automates.
4. **Candles, made at the Workbench:** Leah's notes (2026-11-07):
   - **The Workbench is for crafting** (candles). It replaces the earlier "Chandler's Workshop" idea.
   - **Upgrades ("Technology") are sold in the Beekeeper's Shop** (Leah, 2026-11-07), not at The Workbench. They are bought (not researched), usually with a mix of resources: Beebits, wax, sage. Some are locked until something else is bought. **Bought upgrades disappear from the Shop.** First upgrades: Bigger Combs I/II (+50% / +100% honey storage), Better Wax-Catcher (+50%), Stronger Candles (repellent burns longer). The shoe-throw upgrades (stage 6) will be sold there too.
   - **When:** the Workbench opens after the 2nd comb, together with the first wasp (see stage 6), so candles arrive with wasps rather than before them.
   - **Candles are crafted from wax, instantly** (no crafting time): the first candles cost **10 wax** each (costs of later types to be set later). Later candles also cost **sage** or **propolis**. For now, sage comes only from the Hippies; propolis is gathered by the bees once they get the right upgrades.
   - **At least two types at first:** the **beeswax candle** (the first candle the player can craft, and the one the Hippies buy), and a **wasp-repellent candle** that keeps wasps away (duration to decide).
   - **Later, a bee-boost candle** that makes the bees more effective (the old idea was +20% honey for a time).
   - **The Hippies arrive after the player has crafted 5 candles** of any type. The beeswax candle is the first one available, so in practice 5 beeswax candles bring them. They buy beeswax candles and **pay 1 sage per 10 candles** (they are one of the stage 7 buyers).
5. **Sites**: the garden, the meadow apiary, the orchard and on (see the ladder in stage 3). The "Honey Factory" becomes the honey house, an automation upgrade. Kinds of bees come from plants (stage 3), not from catching.
6. **Wasps (cozy):** raids steal honey and make some bees flee; bribe, guards or candles stop them. (The old "bears reduce raids after 100 trades" is replaced by the bear's trade agreement at 100 trades; see the build roadmap.) Leah's notes (2026-11-07):
   - **Changed (Leah, 2026-11-07, planning session): No Stress Mode will not be used in Beekeeper.** Wasps are required for play because the emissary needs them. Wasps still come only during active play. To be built in stage 6 together with the emissary, so wasps never lose their off switch before they have an ending. *The rule below is what is built today:*
   - **No Stress Mode turns wasps off completely.** No wasps appear and none raid. It can be turned on or off at any time without affecting game progress (nothing is reset, lost or gained by switching). A raid already under way when it is turned on still plays out; only future raids are stopped.
   - **Active play only.** Wasps never raid while the app is closed or idle, so away earnings are safe.
   - **Raid size** (placeholders, Leah 2026-11-07): a raid takes 3 minutes' worth of honey and 15% of the bees. This replaces the earlier "at most about 10 minutes of play" rule: catching upgrades past the Vacuum will make bees quick to win back.
   - **Bribe with honey:** instead of throwing, pay 25% of your stored honey; the wasp leaves and no bees fly off.
   - **The threat grows.** Wasps first appear after the 2nd comb: one wasp, then more wasps, then wasp gangs (5 wasps), then wasp bullies (tougher, could have names and return), and at high levels a wasp horde.
   - **Throw a shoe.** The first, free defence: drives off one wasp, with a 40% chance to miss. A miss costs honey and makes some bees flee. Against a gang it takes out just one wasp and the rest still raid (the joke: "One down. The other four look annoyed.").
   - **The throw is upgraded through Technology** (not tied to the horde). The miss chance always stays 40%; some upgrades raise how many wasps one hit takes out. Upgrade names come later. Guards and candles stay the reliable late-game answer.
   - **The Workbench** (stage 4) opens after the 2nd comb, together with the first wasp. Upgrades ("Technology") are bought in the Beekeeper's Shop.
   - **Changed (Leah, 2026-11-07, planning session): the emissary comes after 5 bribes**, counted in total (not in a row). Wasps steal honey until the player has bribed them 5 times; a bribe is a low cost. The 5th bribe unlocks the wasps' reputation and the paper trade (paper will be used for things). This replaces the "3 failed raids" idea below; no guard upgrade or propolis entrance is needed. To be built in stage 6.
   - *(Replaced)* **Long-term idea: the wasps become trade partners** (Leah, 2026-11-07). After a future guard bee upgrade fends wasps off, a wasp nest that fails to raid **3 times** sends an **emissary**. From then on **raids stop entirely**, and the wasps become a buyer on the Trading card who **sells paper** (what paper is for comes later, for example new crafts). Not in the stage 4 build.
7. **Reputations:** Bears, Hippies, Hummingbirds, Badgers, each with their own wants.
8. **Seasons, as a bloom calendar:** instead of four generic seasons, different flowers bloom in turn (crocus, clover, linden, goldenrod), each rewarding different roles and honey, ending in a winter cluster. Chosen to feel like beekeeping, not like Kittens.
   - **Plan to try (Leah, 2026-11-07: "we'll try your recs"):** **one bloom per real day**, counting time away; crocus, clover, linden, goldenrod, then a short, gentle winter (half a day). A "year" is about 4½ days, so a 3-week run sees each bloom 4 or 5 times. The reason to come back tomorrow is "the linden is in bloom". Each bloom favours one specialty and gives its own named honey; winter slows honey a little, nothing is lost and no bee flies off. (Replaces the "maybe every 15 minutes" idea.)
9. **Swarming:** the reset with a bonus, and the long-term goal. **A swarm is a full wipe** (Leah, 2026-11-07): starting over means starting over. What the player keeps is **production bonuses**. So nothing built before needs to plan what carries over.
10. **Other platforms:** Mac, iOS, Android once Windows is playable. Mobile text must stay free of betting words.

## Build roadmap (planning session, 2026-11-07)
Built so far (build stages 1–5): catching and tools, honey, wax, combs, the bear, the Shop; The Workbench, candles, Hippies, sage, single wasps; the Smoker, the slice; the Garden, foragers, guards, pollen, bee bread, the wooden hive; the queen and the pantry, the slice cap, the trade agreement. Before stage 5, by rough arithmetic, the game held about 3–5 hours of active play, nearly all on day 1. The aim: **week 1** colony and garden, **week 2** meadow and automation, **week 3** seasons and growth levelling off, then the swarm. **Pacing rule: long-term progress is gated by real time (the queen, plant growth, seasons), not clicks.** Rapid clicking always pays (Leah); the slice cap only stops it snowballing.

| Build stage | Theme | New systems |
|---|---|---|
| **5. The queen and the brood** (spec: `windows/013-beekeeper-brood/`) — **BUILT** (`d690603`) | The colony grows itself | Bee bread feeds the queen, who raises honeybees, live and away; the pantry; the slice cap; the bear's trade agreement at 100 trades; a fuller welcome-back message. |
| **6. Specialties and the wasp emissary** | Plants give the hive a job; the wasps' story ends | Specialties replace the forager and guard counts (foraging: steady pollen; guarding: "the hive feels safe", a production boost). The Hive card grouped (bees, garden, crafts). The emissary after 5 bribes in total; the wasps' reputation and the paper trade. No Stress Mode stops applying to Beekeeper. Old saves: counts turn into specialties. |
| **7. More seeds, the poplar and propolis** | Discovery keeps going | More seeds (each grows longer: 10 min, 1 h, 6 h, overnight); several plants at once, several specialties; a nursing specialty (the queen lays faster); the poplar and the resin specialty; propolis; the bee-boost and sage-propolis candles; first uses for paper. Maybe the Bees card returns (from `f196a8a`). |
| **8. The meadow and the honey house** | The hive moves; automation | The one hive moves to the meadow (the next name on the ladder; higher laying and storage). Meadow plants. The honey house automates one job per upgrade (sell, bee bread, candles). Paper becomes labels for jarred honey. Batch comb building. |
| **9. The bloom calendar** | A reason to come back tomorrow | One bloom per real day, counting time away: crocus, clover, linden, goldenrod, a half-day winter. Each bloom favours a specialty and gives a named honey. |
| **10. New buyers** | Relationships | Hummingbirds and Badgers, each wanting a named honey or a craft and giving something unique; slow standing orders; the road to the orchard. |
| **11. The swarm** | The reset | A full wipe that keeps production bonuses. Specced once stages 6–10 show where growth levels off. |

Gaps these stages answer: time away barely grew anything (5, built); content ran out after the wooden hive (6–10); resources with no sink, such as pollen and bee bread after the wooden hive (5), meaningless bee counts (6), Beebits after the Whistle and sage (7–8); the slice compounding without limit (5); storage that can't keep up with production (5, the trade agreement; 8); no long timers (7, 9); no automation (8); a crowded Hive card (6).

## Decisions made
- **Passive growth comes from bee bread** (Leah, 2026-11-07): bee bread feeds the queen, who raises new bees. The queen starts in the wooden hive (the skep has no room for brood).
- **The slice gets a cap** (Leah, 2026-11-07): placeholder, never more than 10 × the tool's bees per click.
- **The bear's trade agreement** (Leah, 2026-11-07): free at 100 bear trades; honey that doesn't fit in the combs is sold automatically at 50% of the normal rate, live and away. Selling by hand stays at the full rate.
- **No Stress Mode will not be used in Beekeeper** (Leah, 2026-11-07): wasps are required for the emissary. Built in stage 6.
- **The emissary comes after 5 bribes, in total** (Leah, 2026-11-07): it unlocks the wasps' reputation and the paper trade. Replaces "3 failed raids".
- **Specialties, not counts** (Leah, 2026-11-07): a plant gives the hive a specialty; no counts of forager or guard bees. Guarding becomes "the hive feels safe", a production boost. Later, several plants give several specialties.
- **One hive, by different names** (Leah, 2026-11-07): the ladder moves and renames the one hive; never a count of hives.
- **A swarm is a full wipe with production bonuses** (Leah, 2026-11-07).
- **Seasons: try one bloom per real day** (Leah, 2026-11-07), counting time away, with a half-day winter.
- **Rapid clicking always pays** (Leah, 2026-11-07); the slice cap stays, so clicking can't snowball.
- **Comment out, don't delete** (Leah, 2026-11-07): cut features (like the Bees card) should be easy to bring back.
- **Live-only boosts are intended** (Leah, 2026-11-07): the Smoker's calm and later boost candles reward live play; "same live and away" applies to growth, not to boosts.
- **`decimal` is big enough** (2026-11-07): about 7.9 × 10²⁸, far more than a database BIGINT; with the slice cap the bee count can't run away.
- **Build the systems first, tune later** (Leah, 2026-11-07): each stage adds its systems with placeholder numbers kept in the config; fine tuning comes once meadows and the rest are built.
- Clicking stays "catch bees" (the game's premise) and stays relevant through scaling, the Smoker and special bees.
- Hive roles become bee types attracted by flowers; guards are a permanent upgrade (Leah, 2026-11-07). *(Now specialties; see above.)*
- Swarming is the reset.
- Seasons: yes, later, in a form that is not a copy of Kittens.
- Wasps steal honey and make bees flee; they only raid during active play. A raid takes 3 minutes of honey and 15% of the bees (placeholders); a bribe costs 25% of the honey and no bees.
- Offline earnings up to 3 days.

## Still open
1. Offline rate is 100% (confirmed). Open: whether the 3-day cap grows with upgrades.
2. The slice is 0.1% per click, capped (stage 5). Open: the cap's size (placeholder 10 × the tool's bees).
3. Specialties: the seeds after the bramble and which plant gives which specialty (stage 7: nursing, resin); how big the guarding boost is.
4. ~~Whether nurses are the only passive bee growth~~ Settled: the queen, fed by bee bread; a nursing specialty (stage 7) makes her lay faster.
5. Which production bonuses the swarm gives (it is a full wipe otherwise).
6. Sage-propolis candle duration.
7. ~~The number type~~ Settled: `decimal` is big enough.
8. Mobile layout of the 3-column screen.
9. Wasps: horde size and when it starts, how much a miss or raid costs (needs the simulator), and the throw upgrades' names and wasps-per-hit numbers.
10. Upgrades: the full list, each upgrade's cost, and which upgrades unlock which (work in progress; the first build of them uses placeholders).
11. Candles: the cost of later candle types; which later candles need sage or propolis; which bee upgrades gather propolis.
12. Wasp emissary: settled that it comes after 5 bribes in total. Open: what paper costs and what it is used for, what the wasps want in trade, and what their reputation gives beyond paper.
