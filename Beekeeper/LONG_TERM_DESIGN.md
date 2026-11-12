# Beekeeper: Long-Term Design (planned, NOT in the first build)

Written 2026-11-06 from Leah's decisions. Inspired by idle games like Kittens Game, but not a copy: the hooks below come from real beekeeping.

## The shape of the game
- **Length:** 1.5 to 4 weeks. Growth should level off around week 3, which is where the first swarm (reset) happens.
- **Tone:** cozy. Wasps steal honey; some bees flee during a raid (nobody is killed). Later pests may steal other resources.
- **Offline:** the combs and the bees work while the app is closed, up to 3 days. The honey and wax caps limit it (both caps from stage 7.5).
- **No bee limit.** Big, growing swarms are the fun. The limits are on honey storage, wax storage (from stage 7.5) and prices.

## The core loop (what each part is for)
| Part | Job in the loop |
|---|---|
| **Clicking: Catch Bee** | Brings in bees, forever. Gets stronger with tools, tool upgrades, a slice of the free bees per click (from stage 7.5; before, of the whole colony), and the Smoker. |
| **Bee types and flowers** | Replaces "hive roles" (Leah, 2026-11-07): with no bee limit, bees can't be assigned one by one, so roles come from kinds of bees, attracted by planting flowers. |
| **Combs** | **Changed in stage 7.5:** combs make the honey and raise both caps. They cost bees and wax; the wax price grows 25% each. *(Replaced: honey storage only, paid in wax only, and every bee making honey.)* |
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
   - **Changed (Leah, 2026-11-10): one starting bed, and seed trades spread from 5 to 100.** The Hippies give wildflowers at 5, bramble at 30, willow at 60 and clover at 100 (placeholders); the wasps still give the poplar at 10. Each plant's seed is given once, to move the game forward. Extra beds leave the Shop and become a technology bought after a swarm (stage 11, not built). Saves that already own the Third Bed keep it.
   - **The Garden card** appears with the first seed: a "Plant seed?" button, which then reads "Something is growing!". About 10 minutes later the log says "Your seed has sprouted." and the Garden shows the plant and the kind of bee it attracts.
   - **Forager bees** (from a plant) bring back **pollen**. Pollen becomes **bee bread**, used with wax for hive upgrades.
   - **Guard bees are attracted by a plant, not bought** (design pivot): once you have them, raids never make bees fly off. The wasp can still take honey.
   - **Propolis**: real hives have no separate propolis bee; a few older foragers collect tree resin ("resin foragers"). Later, a tree (e.g. a poplar) could attract resin foragers for propolis and the bee-boost candle.
   - **Changed (Leah, 2026-11-07): plants give the hive a specialty, not a count of bees.** Counts of forager and guard bees are meaningless and go. Wildflowers give **foraging** (pollen at a steady rate); bramble gives **guarding**, which is now "the hive feels safe": a production boost (raids are out as guarding's job). Later, several plants at once give several specialties. To be built in stage 6.
   - **A Bees card** explains what each kind of bee does, with bee facts. Cut after stage 4 play-testing, but **it can come back later** (Leah): its words and code are in the stage 4 commit `f196a8a`, before they were removed. Next time, comment things out rather than deleting them.
   - **Where the bees live (the ladder)**: **one hive only, by different names** (Leah, 2026-11-07). The one hive moves: a skep in the garden, then a wooden hive in the garden, then a hive in the meadow, then in the orchard, and on. Never a count of hives. Hive upgrades cost wax and bee bread. The honey house may come later as an upgrade that automates something.
   - *(Replaced from the meadow onward, Bee, 2026-11-09: the player **buys** a meadow and a honey house instead of the hive moving. The skep, the wooden hive and the queen stay. See build stage 8.)*
   - Open: what each later seed grows and attracts, what each step of the ladder gives, and what the honey house automates.
4. **Candles, made at the Workbench:** Leah's notes (2026-11-07):
   - **The Workbench is for crafting** (candles). It replaces the earlier "Chandler's Workshop" idea.
   - **Upgrades ("Technology") are sold in the Beekeeper's Shop** (Leah, 2026-11-07), not at The Workbench. They are bought (not researched), usually with a mix of resources: Beebits, wax, sage. Some are locked until something else is bought. **Bought upgrades disappear from the Shop.** First upgrades: Bigger Combs I/II (+50% / +100% honey storage; both caps from stage 7.5), Better Wax-Catcher (+50%), Stronger Candles (repellent burns longer). The shoe-throw upgrades (stage 6) will be sold there too.
   - **When:** the Workbench opens at 3 combs, counting the starter comb (the same point as the old "after the 2nd comb"; stage 7.5), together with the first wasp (see stage 6), so candles arrive with wasps rather than before them.
   - **Candles are crafted from wax, instantly** (no crafting time): the first candles cost **10 wax** each (costs of later types to be set later). Later candles also cost **sage** or **propolis**. For now, sage comes only from the Hippies; propolis is gathered by the bees once they get the right upgrades.
   - **At least two types at first:** the **beeswax candle** (the first candle the player can craft, and the one the Hippies buy), and a **wasp-repellent candle** that keeps wasps away (duration to decide).
   - **Later, a bee-boost candle** that makes the bees more effective (the old idea was +20% honey for a time).
   - **The Hippies arrive after the player has crafted 5 candles** of any type. The beeswax candle is the first one available, so in practice 5 beeswax candles bring them. They buy beeswax candles and **pay 1 sage per 10 candles** (they are one of the stage 7 buyers).
5. **Sites** *(replaced from the meadow onward, Bee, 2026-11-09: they are bought, see build stage 8)*: the garden, the meadow apiary, the orchard and on (see the ladder in stage 3). The "Honey Factory" becomes the honey house, an automation upgrade. Kinds of bees come from plants (stage 3), not from catching.
6. **Wasps (cozy):** raids steal honey and make some bees flee; bribe, guards or candles stop them. (The old "bears reduce raids after 100 trades" is replaced by the bear's trade agreement, a better selling rate at 25 trades from stage 7.5; see the build roadmap.) Leah's notes (2026-11-07):
   - **Changed (Leah, 2026-11-07, planning session): No Stress Mode will not be used in Beekeeper.** Wasps are required for play because the emissary needs them. Wasps still come only during active play. To be built in stage 6 together with the emissary, so wasps never lose their off switch before they have an ending. *The rule below is what is built today:*
   - **No Stress Mode turns wasps off completely.** No wasps appear and none raid. It can be turned on or off at any time without affecting game progress (nothing is reset, lost or gained by switching). A raid already under way when it is turned on still plays out; only future raids are stopped.
   - **Active play only.** Wasps never raid while the app is closed or idle, so away earnings are safe.
   - **Changed (Leah, 2026-11-07, planning session): raids take only honey**, never bees, from stage 6 on.
   - *(Replaced)* **Raid size** (placeholders, Leah 2026-11-07): a raid takes 3 minutes' worth of honey and 15% of the bees. This replaces the earlier "at most about 10 minutes of play" rule: catching upgrades past the Vacuum will make bees quick to win back.
   - **Bribe with honey:** instead of throwing, pay 25% of your stored honey; the wasp leaves and no bees fly off.
   - **Dropped (Leah, 2026-11-07, planning session): the growing threat and the shoe-throw upgrades.** The emissary ends raids after 5 bribes, so they would never matter. Kept below for the record.
   - *(Dropped)* **The threat grows.** Wasps first appear after the 2nd comb: one wasp, then more wasps, then wasp gangs (5 wasps), then wasp bullies (tougher, could have names and return), and at high levels a wasp horde.
   - **Throw a shoe.** The first, free defence: drives off one wasp, with a 40% chance to miss. A miss costs honey and makes some bees flee. Against a gang it takes out just one wasp and the rest still raid (the joke: "One down. The other four look annoyed.").
   - *(Dropped)* **The throw is upgraded through Technology** (not tied to the horde). The miss chance always stays 40%; some upgrades raise how many wasps one hit takes out. Upgrade names come later. Guards and candles stay the reliable late-game answer.
   - **The Workbench** (stage 4) opens at 3 combs, counting the starter comb (stage 7.5; before, after the 2nd comb), together with the first wasp. Upgrades ("Technology") are bought in the Beekeeper's Shop.
   - **Changed (Leah, 2026-11-07, planning session): the emissary comes after 5 bribes**, counted in total (not in a row). Wasps steal honey until the player has bribed them 5 times; a bribe is a low cost. The 5th bribe unlocks the wasps' reputation and the paper trade (paper will be used for things). This replaces the "3 failed raids" idea below; no guard upgrade or propolis entrance is needed. To be built in stage 6.
   - *(Replaced)* **Long-term idea: the wasps become trade partners** (Leah, 2026-11-07). After a future guard bee upgrade fends wasps off, a wasp nest that fails to raid **3 times** sends an **emissary**. From then on **raids stop entirely**, and the wasps become a buyer on the Trading card who **sells paper** (what paper is for comes later, for example new crafts). Not in the stage 4 build.
7. **Reputations:** Bears, Hippies, Hummingbirds, Badgers, each with their own wants.
8. **Seasons, as a bloom calendar:** instead of four generic seasons, different flowers bloom in turn (crocus, clover, linden, goldenrod), each rewarding different roles and honey, ending in a winter cluster. Chosen to feel like beekeeping, not like Kittens.
   - **Plan to try (Leah, 2026-11-07: "we'll try your recs"):** **one bloom per real day**, counting time away; crocus, clover, linden, goldenrod, then a short, gentle winter (half a day). A "year" is about 4½ days, so a 3-week run sees each bloom 4 or 5 times. The reason to come back tomorrow is "the linden is in bloom". Each bloom favours one specialty and gives its own named honey; winter slows honey a little, nothing is lost and no bee flies off. (Replaces the "maybe every 15 minutes" idea.)
   - **Settled for build stage 9 (Bee, 2026-11-11):** days in game time from the first plant; each bloom doubles its specialty; **named honey is dropped for now.** See "Update: The bloom calendar".
9. **Swarming:** the reset with a bonus, and the long-term goal. **A swarm is a full wipe** (Leah, 2026-11-07): starting over means starting over. What the player keeps is **production bonuses**. So nothing built before needs to plan what carries over.
10. **Other platforms:** Mac, iOS, Android once Windows is playable. Mobile text must stay free of betting words.

## Build roadmap (planning session, 2026-11-07)
Built so far (build stages 1–8; 6 to 8 are in the table below): catching and tools, honey, wax, combs, the bear, the Shop; The Workbench, candles, Hippies, sage, single wasps; the Smoker, the slice; the Garden, foragers, guards, pollen, bee bread, the wooden hive; the queen and the pantry, the slice cap, the trade agreement (its auto-sale is cut in stage 7.5). Before stage 5, by rough arithmetic, the game held about 3–5 hours of active play, nearly all on day 1. The aim: **week 1** colony and garden, **week 2** meadow and automation, **week 3** seasons and growth levelling off, then the swarm. **Pacing rule: long-term progress is gated by real time (the queen, plant growth, seasons), not clicks.** Rapid clicking always pays (Leah); the slice cap only stops it snowballing.

| Build stage | Theme | New systems |
|---|---|---|
| **5. The queen and the brood** (spec: `windows/013-beekeeper-brood/`) — **BUILT** (`d690603`) | The colony grows itself | Bee bread feeds the queen, who raises honeybees, live and away; the pantry; the slice cap; the bear's trade agreement at 100 trades; a fuller welcome-back message. |
| **6. Specialties and the wasp emissary** (spec: `windows/014-beekeeper-specialties/`) — **BUILT** (`2d63047`) | Plants give the hive a job; the wasps' story ends | Specialties replace the forager and guard counts (foraging: steady pollen; guarding: "the hive feels safe", +honey). The Hive card in groups (bees, the hive, garden, crafts, trade goods). Raids take only honey. The emissary after 5 bribes in total: raids stop, the wasps trade paper for honey, repellent candles retire. No Stress Mode stops applying to Beekeeper. Old saves: counts turn into specialties. |
| **7. More seeds, the poplar and propolis** (spec: `windows/015-beekeeper-seeds/`) — **BUILT** (`8d36f82`) | Discovery keeps going | Named seeds; two garden beds (a third from the Shop); each plant its own grow time. The willow (1 h, nursing: the queen lays faster), the poplar (6 h, resin: propolis; its seed from the wasps), clover (12 h, more foraging). The bee-boost candle (live-only) and the sage-propolis candle (burns while away). Paper buys the Beekeeper's Notebook (the Bees card returns) and is part of new Shop prices; the Propolis Seal (+storage). |
| **7.5. Combs, bees as currency** (spec: `windows/016-beekeeper-combs/`) — **BUILT** (2026-11-09) | Bees pay for combs; combs make the honey | One starter comb. Each comb makes honey at a flat rate; wax comes from a tiny drip plus free bees. A comb costs bees and wax, and the bees move in. Honey and wax each have a cap, and the wax cap is small on purpose, so prices above it are walls. Repeatable capacity upgrades; Technologies boost both caps. The bear's trade agreement becomes a better selling rate at 25 trades (auto-sale commented out). Save version 8; older saves start a new game. |
| **8. Seeds, wood and the meadow** (spec: `windows/017-beekeeper-meadow/`) — **BUILT** (`1aafa93`) *(reworked, Bee, 2026-11-09; seeds and the meadow's price reworked 2026-11-11, see "Update: Seeds, plants and the meadow"; the honey house moves to a later stage)* | Bigger places you buy | **First:** random Hippie seeds (20% a trade, paced by progress), instant growth, many of each plant with a tiny bonus each, the carpenter bee and wood, and the Bees tab with bee facts. **The meadow** is bought with 50 wildflowers and 50 clover *(was: for tons of bees)*, instead of the hive moving there. It works like **one giant comb**: the bees paid move in, there is still no bee limit, and it makes honey and raises both caps on a much larger scale. It takes bees out of the free count, so they stop making wax. **The honey house** is bought and holds tons of honey. **Later upgrades, priced with paper, automate selling, but it makes bottles of honey and the bottles are what gets sold** (not the auto-sale that stage 7.5 cuts; jar labels were already planned as a use of paper). The wooden hive and the queen stay. Meadow plants. Batch comb building. |
| **9. The bloom calendar** (spec: `windows/018-beekeeper-blooms/`) — **BUILT** (2026-11-11) | A reason to come back tomorrow | One bloom per game-time day (live plus away), from the first plant: crocus, clover, linden, goldenrod, a half-day winter. Each bloom makes one specialty work twice as hard; winter slows honey a little. *(Named honey dropped for now, Bee, 2026-11-11.)* |
| **10. The core trade loops** (spec: `windows/019-beekeeper-trade/`) — **BUILT** (2026-11-12) | Each trader has one job | The Bear buys honey for Beebits again, the only Beebit source. The game starts with 3 clay jars and an opening story card. Honey + a jar makes potted honey (Hive card), which only the Bear buys, at a better rate. The beeswax candle returns; the Hippies trade beeswax candles for clay jars. Herbs come only from the leafcutter bee and leave the Shop. See "Update: The core trade loops". |
| **10.5. New buyers** *(was stage 10, moved by Bee, 2026-11-12)* | Relationships | Hummingbirds and Badgers, each wanting a craft (named honey was dropped from stage 9; it may come back here) and giving something unique; slow standing orders; the road to the orchard (whether the orchard is bought like the meadow is still open). |
| **11. The swarm** | The reset | A full wipe that keeps production bonuses. Specced once stages 6–10 show where growth levels off. |

Gaps these stages answer: time away barely grew anything (5, built); content ran out after the wooden hive (6–10); resources with no sink, such as pollen and bee bread after the wooden hive (5), meaningless bee counts (6), Beebits after the Whistle and sage (7–8); the slice compounding without limit (5); storage that can't keep up with production (7.5, capacity upgrades; 8); walls with nothing past them (7.5 lists them; 8); no long timers (7, 9); no automation (8); a crowded Hive card (6).

## Decisions made
- **Passive growth comes from bee bread** (Leah, 2026-11-07): bee bread feeds the queen, who raises new bees. The queen starts in the wooden hive (the skep has no room for brood).
- **The slice gets a cap** (Leah, 2026-11-07): placeholder, never more than 10 × the tool's bees per click.
- *(Replaced in stage 7.5, Bee, 2026-11-09: a better selling rate at 25 trades, and the auto-sale is commented out.)* **The bear's trade agreement** (Leah, 2026-11-07): free at 100 bear trades; honey that doesn't fit in the combs is sold automatically at 50% of the normal rate, live and away. Selling by hand stays at the full rate.
- **No Stress Mode will not be used in Beekeeper** (Leah, 2026-11-07): wasps are required for the emissary. Built in stage 6.
- **The emissary comes after 5 bribes, in total** (Leah, 2026-11-07): it unlocks the wasps' reputation and the paper trade. Replaces "3 failed raids".
- **Specialties, not counts** (Leah, 2026-11-07): a plant gives the hive a specialty; no counts of forager or guard bees. Guarding becomes "the hive feels safe", a production boost. Later, several plants give several specialties.
- *(Replaced from the meadow onward, Bee, 2026-11-09: the meadow and the honey house are bought.)* **One hive, by different names** (Leah, 2026-11-07): the ladder moves and renames the one hive; never a count of hives.
- **A swarm is a full wipe with production bonuses** (Leah, 2026-11-07).
- **Seasons: try one bloom per real day** (Leah, 2026-11-07), counting time away, with a half-day winter.
- **The bloom calendar** (Bee, 2026-11-11): days count in game time from the first plant; crocus favours nursing, clover foraging, linden guarding, goldenrod resin, each at twice the strength; named honey is dropped for now.
- **Rapid clicking always pays** (Leah, 2026-11-07); the slice cap stays, so clicking can't snowball.
- **Raids take only honey** (Leah, 2026-11-07): never bees, from stage 6 on.
- **Repellent candles retire after the emissary** (Leah, 2026-11-07): hidden, with their stock kept in the save.
- **The wasps trade paper for honey** (Leah, 2026-11-07): placeholder 50 honey a paper.
- **The growing wasp threat is dropped** (Leah, 2026-11-07): gangs, bullies, the horde and the shoe-throw upgrades.
- **Two garden beds, a third from the Shop** (Leah, 2026-11-07, stage 7 planning): beds are for growing; sprouted plants move into the garden.
- **Stage 7 seeds** (Leah, 2026-11-07): the willow (nursing), the poplar (resin, propolis), clover (more foraging), growing 1 h, 6 h and overnight.
- **The wasps give the poplar seed** (Leah, 2026-11-07): the first thing their reputation gives beyond paper. The Hippies give the willow and clover seeds.
- **Paper's first uses** (Leah, 2026-11-07): the Beekeeper's Notebook (brings back the Bees card as notes on the specialties) and a share of new Shop prices.
- **The bee-boost candle is live-only; the sage-propolis candle burns while away** (Leah, 2026-11-07): the sage-propolis candle is no longer a wasp repellent (the wasps are gone after the emissary); it is a smaller, slow honey boost that rewards time away.
- **Propolis** (Leah, 2026-11-07): gathered by the resin specialty; used in the two candles and the Propolis Seal upgrade (more honey storage; both caps from stage 7.5).
- **Comment out, don't delete** (Leah, 2026-11-07): cut features (like the Bees card) should be easy to bring back.
- **Live-only boosts are intended** (Leah, 2026-11-07): the Smoker's calm and later boost candles reward live play; "same live and away" applies to growth, not to boosts.
- **`decimal` is big enough** (2026-11-07): about 7.9 × 10²⁸, far more than a database BIGINT; with the slice cap the bee count can't run away.
- **Make buttons are earned** (Bee, 2026-11-11): a new batch button (Make 10, later Make 100) comes from an upgrade, not from the start. Bigger batches come once storage allows them. This is the pattern for adding make buttons from now on; the batch buttons already built (herbal candles, bee bread, the wasps' trade) stay as they are.
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
3. ~~Specialties: the seeds after the bramble~~ Settled for stage 7 (willow, poplar, clover). Open: the size of every specialty's strength.
4. ~~Whether nurses are the only passive bee growth~~ Settled: the queen, fed by bee bread; a nursing specialty (stage 7) makes her lay faster.
5. Which production bonuses the swarm gives (it is a full wipe otherwise).
6. ~~Sage-propolis candle duration~~ Settled as a slow boost that burns while away (placeholder 4 h, capped at 24 h). Open: its on-screen name.
7. ~~The number type~~ Settled: `decimal` is big enough.
8. Mobile layout of the 3-column screen.
9. ~~Wasps: horde size, throw upgrades~~ Dropped: the emissary ends raids. Open: the bribe cost (placeholder 25%).
10. Upgrades: the full list, each upgrade's cost, and which upgrades unlock which (work in progress; the first build of them uses placeholders).
11. Candles: settled for stage 7 (bee-boost: wax + propolis; sage-propolis: wax + sage + propolis; propolis comes from the poplar's resin specialty). Open: their prices and boosts.
12. Wasp emissary: settled that it comes after 5 bribes in total. Settled: the wasps trade paper for honey (placeholder 50 honey each). Settled (stage 7): paper buys the Notebook and is part of new Shop prices; the wasps give the poplar seed. Open: labels for jarred honey (stage 8) and anything more their reputation gives.
13. The meadow (stage 8): ~~its price~~ settled, 50 wildflowers and 50 clover (Bee, 2026-11-11); how much honey and room it gives; whether it also speeds up the queen (the old stage 8 raised laying); whether there can be more than one.
14. The honey house (stage 8): its price; how bottling works; whether bee bread and candles can still be automated (the old plan; Bee named only selling).
15. Stage 7.5's prices: which old Beebit and wax prices change. The list is in `windows/016-beekeeper-combs/spec.md`, "Prices to look at again".
16. Seeds and plants (stage 8, Bee, 2026-11-11): ~~when each seed joins the roll, the poplar, garden beds, each plant's tiny bonus~~ settled as placeholders (see "Update: Seeds, plants and the meadow", item 8). ~~How a specialty works with many copies~~ Settled: the first plant gives the specialty, each one after it only the tiny bonus.
17. The carpenter bee and wood (stage 8): ~~which plant summons it~~ settled, the first willow; how fast it collects wood, and the building upgrades wood pays for. Wood is for further expansions, not paper (Bee, 2026-11-11). Open: which expansions, smaller ones first, and whether the honey house is built with wood later on.

18. The bloom calendar (stage 9): the favour strength (placeholder ×2), winter's slowdown (placeholder ×0.75 honey), whether named honey comes back with stage 10.5's buyers, and whether crocus, linden and goldenrod become plants you can grow.
19. The trade loops (stage 10): potted honey's price, candles per jar, the herb rate, and whether the Shop's Beebit prices need retuning now that only the Bear pays Beebits.

## Update: Combs, bees as currency (planned for build stage 7.5, 2026-11-09)
Bee's design notes (earlier sections call Bee "Leah"). **Built (2026-11-09, `windows/016-beekeeper-combs/`): the game follows these rules now.**

*Replaces:* every bee making 0.01 honey a second; wax following honey with no cap; the bear's auto-sale at 100 trades; combs being storage-only and paid in wax only; starting with zero combs; the Workbench and the first wasp opening at 2 combs; Wax-Catchers working per 50 honey.

1. **Bees are caught by clicking** and are the currency for combs. The queen stays; her bees arrive as free bees.
2. **Bees don't make honey.** Honey comes from combs. Wax = a tiny base drip + free bees × a rate; it is not multiplied by combs.
3. **You start with one comb.** It counts as a comb, so the Workbench threshold moves to 3 and opens at the same point as before. The starter comb makes no honey until the first bee is caught. The wax drip runs from the start.
4. **Each comb makes honey at a flat rate.** It doesn't matter how many bees live in it, so there is no per-comb bee tracking. "How many bees fit in a comb" is the comb's bee price, not a separate number.
5. **A new comb costs bees and wax.** The bees move into the comb and **leave the free-bee count**. The catch slice reads free bees only.
6. **Honey and wax each have a cap.** At the cap, production stops; nothing is wasted or auto-sold. New combs raise both caps, each adding only a little wax room.
7. **The wax cap is small, on purpose.** It is what stops a fast clicker from running away: the rising comb price outruns it.
8. **Getting stuck is intended.** When a price rises above a cap, that wall shows where an upgrade, Technology or larger purchase belongs. There is no rule that caps must stay above prices.
9. **Wax also crafts candles.**
10. **Capacity upgrades** are repeatable flat increases to the caps.
11. **Technologies** are the one-time % boosts (the existing Bigger Combs and Propolis Seal), now on both caps.
12. Honey still goes to the bear for Beebits, which buy tools. **The trade agreement's auto-sale is commented out.** In its place, the bear gives a better selling rate, at 25 trades instead of 100.
13. Calm, candles, the wooden hive and guarding boost comb honey only. Wax-Catchers multiply the wax rate.
14. Old saves don't matter: save version 8, and any older save just starts a new game.

*Answered by the stage 7.5 placeholders (all in `BeekeeperConfig`, listed in the spec):* the cost of the first new comb and how it grows, the honey rate per comb, and the caps.

### Long-term direction (recorded, not built in stage 7.5)
Bee, 2026-11-09. Instead of the hive moving to the meadow, the player eventually **buys a meadow** to store bees: it holds tons of bees and costs tons of bees. The same idea applies to the **honey house**. This replaces the "one hive, by different names" ladder from the meadow onward. The wooden hive and the queen stay.
- **Confirmed: the meadow works like one giant comb.** The bees paid move in, there is still no bee limit, and it makes honey and raises both caps like a comb, on a much larger scale.
- **Confirmed: the honey house holds tons of honey, and later upgrades, priced with paper, automate selling, but it makes bottles of honey to sell.**
- Details are in build stage 8 and "Still open".
- *(Partly replaced, Bee, 2026-11-11: the meadow is bought with plants, not bees; see the next section.)*

## Update: Seeds, plants and the meadow (Bee, 2026-11-11)
Bee's design notes for stage 8. **Built (`1aafa93`).** Every number below is a placeholder.

*Replaces:* the Hippies giving each seed once, on a set trade (5, 40, 200, 400); one plant of each kind; grow times (10 min to 12 h); the "growth formula" idea for instant sprouting; buying the meadow with bees.

1. **The Hippies give seeds at random.** Each Hippie trade has a **20% chance** to give a seed. When the roll misses, the trade works as it does today. Every Hippie seed comes through this roll, the willow and clover included.
2. **Seeds are paced by progress.** Each seed type joins the roll at its own point in the game, so new seeds keep arriving over time (the points are in item 8).
3. **Plants grow as soon as they're planted.** No waiting after planting (Bee: the wait "introduces weird complexity"). The grow times are commented out, and the instant-sprout formula is no longer needed. Pacing comes from how often seeds drop.
4. **You can have many of each plant.** **The first plant of a kind gives its specialty** (at today's strength); **each one after it adds only a tiny production bonus** to something else, such as wax, honey or paper (Bee, 2026-11-11). Copies never stack the specialty, so 50 brambles don't multiply honey 50 times.
5. **The meadow is bought with plants:** **50 wildflowers and 50 clover** (Bee, 2026-11-11: small flowering plants only, so not the bramble, the willow or the poplar). Owning the meadow upgrades the hive. It still works like one giant comb (see "Long-term direction").
6. **The carpenter bee** is summoned once **the first willow** has been planted (Bee, 2026-11-11). It collects **wood**, and wood pays for **further expansions** (building upgrades). *(Wood into paper was tried and scrapped, Bee, 2026-11-11: paper stays the wasps' trade.)* Which expansions come first is still being talked through; the honey house feels too big to be the first. Wood uses so far (Bee, 2026-11-11):
   - **Wooden frames** (liked): a one-time upgrade that cuts **the wax cost of new combs** in half (combs only, not candles; Bee, 2026-11-11). Later stages add other kinds of frames that cut it further.
   - **The bee hotel** (liked): brings **rare bees** who now and then bring back **rare resources**. Later upgrades make them bring them more often. Its bees go in the Bees tab. *(Open: which bees, which resources.)*
   - **Wooden candle molds** (yes, Bee, 2026-11-11): a one-time upgrade; each candle craft makes 2 candles (placeholder).
   - **The dipping rack** (yes, Bee, 2026-11-11): a one-time upgrade; every candle costs **half the wax**. *(Changed the same day: it was going to add a Make 10 button.)*
   - **Honey supers** (yes, Bee, 2026-11-11): repeatable wooden boxes stacked on the hive, each raising the honey cap. "Super" is the real beekeeping name. Stage 7.5 already built the Honey Super, bought with Beebits; **from stage 8 it costs wood, not Beebits** (Bee, 2026-11-11). The Wax Tray stays on Beebits.
7. **The Bees tab** lists every summoned bee, what it does in the game, and a short real fact about that bee. The fact is picked from a list of bee facts to be added later.
8. **Placeholders** (accepted by Bee, 2026-11-11):
   - Each seed joins the Hippie roll at today's trade points: wildflowers from the first trade, bramble from trade 40, the willow from 200, clover from 400. A successful roll gives any unlocked seed with an equal chance.
   - The poplar stays the wasps' gift: from their 20th trade, each wasp trade also has a 20% chance to give one.
   - Garden beds and the Third Bed upgrade are commented out, since nothing waits in a bed anymore.
   - Each extra plant adds +1%: wildflowers and bramble to honey, clover to wax, the willow to wood, the poplar to propolis.
   - The carpenter bee collects 1 wood a minute.

## Update: The bloom calendar (Bee, 2026-11-11)
Bee's decisions for build stage 9. **Built 2026-11-11** (spec: `windows/018-beekeeper-blooms/`). Every number below is a placeholder.

*Replaces:* blooms that each give a named honey; "one bloom per real day" meaning calendar days.

1. **Game-time days.** A day is 24 hours of live play plus time away (within the 3-day cap), counted from when the calendar starts. Crocus, clover, linden and goldenrod last 24 hours each, then a 12-hour winter, then crocus again. One "year" is 4½ days.
2. **The calendar starts with the first plant.** Nothing about blooms shows before it.
3. **Each bloom favours one specialty, from real beekeeping**, and it works **twice as hard**: crocus, nursing (spring brood); clover, foraging; linden, guarding (the big summer honey flow); goldenrod, resin (autumn propolis). A multiplier's bonus part doubles (+25% → +50%); a rate doubles (6 pollen → 12). Plant bonuses don't double. A bloom without its plant does nothing.
4. **Winter** makes honey ×0.75. Nothing else slows, nothing is lost and no bee leaves.
5. **Named honey is dropped for now.** Stage 10's buyers need another want, or it comes back with them.

## Update: The core trade loops (Bee, 2026-11-12)
Bee's design notes from a thinking session. **Built in stage 10 (2026-11-12, `windows/019-beekeeper-trade/`).** Every number below is a placeholder.

*Replaces (as built on 2026-11-11):* the Bear paying 1 herb a trade; the Hippies buying herbal candles for Beebits; herbs in Shop prices. Herbs are now an occasional gift, used only for buff candles. *(Sage was already gone: herbs replaced it on 2026-11-11.)*

1. **The Bear is the constant early trade: honey for Beebits.** It never stops being the honey buyer. The 25-trade agreement stays.
2. **The game starts with clay jars.** The opening story card: "You have just inherited your grandmother's farmhouse. In the garden, you find a skep and a few clay jars. It seems a little quiet. What will you do?" The skep is already the starting hive; the new part is **3 clay jars** in hand from the start.
3. **Potted honey:** honey + 1 clay jar crafts 1 potted honey. The jar is used up.
4. **Potted honey sells only to the Bear**, at a higher Beebit rate than plain honey. No other buyer takes it. The Bear's card shows the potted-honey sale once the first potted honey is crafted. *(Dropped the same day: a Bear story card asking for potted honey, which blocked a trade; it isn't needed when the game starts with jars.)*
5. **The Hippies:** they buy beeswax candles and sell **artisan clay pots**, the way to get more jars after the starting ones.
6. *(Dropped, Bee, 2026-11-12: herbs only come from the leafcutter bee; see 7.)* **Herbs every 5th Hippie trade:** each 5th trade also gives one herb, used to craft herb candles (buffs). The 20% seed roll on every Hippie trade stays as it is.
7. **Settled in stage 10 planning (Bee, 2026-11-12):**
   - **Stage 10 is the trade loops only.** The new buyers move to stage 10.5.
   - **Candles for pots only:** the Hippies take beeswax candles and give clay jars; they never pay Beebits. **The Bear is the only Beebit source** (plus the 75 a new game starts with). The beeswax candle comes back for them; herbal candles are only for lighting.
   - **Herbs leave the Shop's prices.** They're for buff candles.
   - **Herbs come only from the leafcutter bee** (Bee: "an interesting boost for later"). *(Dropped the same day: an herb every 5th Hippie trade.)* So herbal candles and their buffs, and Stronger Candles, arrive with the bee hotel.
   - **Potting happens on the Hive card**, from the first honey.
8. **Placeholders** (in the stage 10 spec): 10 honey + 1 jar per potted honey; plain honey 5 Beebits per 10 (8 honey under the agreement); potted honey 15 Beebits; the beeswax candle 2 wax; 3 candles per jar; the leafcutter's 2 herbs a gift (unchanged).
9. **Later (Bee, 2026-11-12, not in stage 10): sage as Smoker fuel.** Some real beekeepers burn dried herbs like sage in their smokers. Sage could become fuel that makes the Smoker's boost stronger or last longer, a use for sage beyond the candles. More sage could come from bee hotel upgrades.
10. **Still open:**
   - Whether "herbs" go back to being called sage on screen, or sage becomes one herb among others.
   - Whether the Hippies' jars are the only way to get more jars.
