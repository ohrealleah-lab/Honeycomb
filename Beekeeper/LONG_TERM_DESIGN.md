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
| **Hive roles** | The main choice system: split bees between foragers (honey), builders (wax and combs), guards (wasps) and nurses (hatch bees without clicking). |
| **Combs** | Honey storage (and later room for role cells). Cost grows 25% each. |
| **Bear and other buyers** | Turn goods into Beebits. Reputations are relationships: each buyer wants and gives something different. |
| **Tools and upgrades** | Spend Beebits to make clicking and the colony stronger. |
| **Swarm (reset)** | The hive splits: the queen leaves with half the bees, you start a new hive with a lasting bonus. |

## Planned stages
1. **First build (now):** catch, honey, wax, bear, shop, combs, saving, offline.
2. **Smoker + tool upgrades:** clicking builds a "calm" meter that boosts the colony for a short time; each tool gets upgrade tiers; a click also catches a small slice of the current colony. Keeps clicking relevant all game.
3. **Hive roles:** introduced after the first comb. Includes nurses (passive bee growth). Guard Bees, Bumblebees (wax) and Clover Bees (honey) become role or strain choices.
4. **Candles, in a Crafting / Technology section:** candles are crafted from wax, and there are different types (at least two at first). Leah's notes (2026-11-07):
   - **Hippie candle:** made to sell to the Hippies.
   - **Wasp-repellent candle:** keeps wasps away (the sage-propolis candle; duration to decide).
   - **Later, a bee-boost candle:** makes the bees more effective (the old idea was +20% honey for a time).
   - This replaces the earlier "Chandler's Workshop" idea of a separate panel; see open question 11.
5. **Sites and special bees:** Garden, Meadow, Honey Factory. Special bees can only be caught by clicking, and which kind depends on the site.
6. **Wasps (cozy):** raids steal honey and make some bees flee; bribe, guards or candles stop them; bears reduce raids after 100 trades. Leah's notes (2026-11-07):
   - **No Stress Mode turns wasps off completely.** No wasps appear and none raid. It can be turned on or off at any time without affecting game progress (nothing is reset, lost or gained by switching). A raid already under way when it is turned on still plays out; only future raids are stopped.
   - **Active play only.** Wasps never raid while the app is closed or idle, so away earnings are safe.
   - **Gentle penalty.** A raid (or a missed throw) never costs more than about 10 minutes of play to earn back, at the player's current rate. This scales with the hive.
   - **The threat grows.** Wasps first appear after the 2nd comb: one wasp, then more wasps, then wasp gangs (5 wasps), then wasp bullies (tougher, could have names and return), and at high levels a wasp horde.
   - **Throw a shoe.** The first, free defence: drives off one wasp, with a 40% chance to miss. A miss costs honey and makes some bees flee. Against a gang it takes out just one wasp and the rest still raid (the joke: "One down. The other four look annoyed.").
   - **The throw is upgraded through Technology** (not tied to the horde). The miss chance always stays 40%; some upgrades raise how many wasps one hit takes out. Upgrade names come later. Guards and candles stay the reliable late-game answer.
   - **Technology (placeholder).** Upgrades are bought or researched there. It opens after the 2nd comb, together with the first wasp; its exact unlock and contents are to be decided.
7. **Reputations:** Bears, Hippies, Hummingbirds, Badgers, each with their own wants.
8. **Seasons, as a bloom calendar:** instead of four generic seasons, different flowers bloom in turn (crocus, clover, linden, goldenrod), each rewarding different roles and honey, ending in a winter cluster. Chosen to feel like beekeeping, not like Kittens.
9. **Swarming:** the reset with a bonus, and the long-term goal.
10. **Other platforms:** Mac, iOS, Android once Windows is playable. Mobile text must stay free of betting words.

## Decisions made
- Clicking stays "catch bees" (the game's premise) and stays relevant through scaling, the Smoker and special bees.
- Hive roles are important, not decoration.
- Swarming is the reset.
- Seasons: yes, later, in a form that is not a copy of Kittens.
- Wasps steal honey and make bees flee; they only raid during active play, and a raid costs at most about 10 minutes of play.
- Offline earnings up to 3 days.

## Still open
1. Offline rate is 100% (confirmed). Open: whether the 3-day cap grows with upgrades.
2. How much of a click is the "slice of the colony" (needs the simulator).
3. Exact roles list and how many roles at start.
4. Whether nurses are the only passive bee growth, or flowers also attract bees.
5. What the swarm bonus is.
6. Sage-propolis candle duration.
7. The number type for the very late game (planned `decimal`; may need a larger type).
8. Mobile layout of the 3-column screen.
9. Wasps: horde size and when it starts, how much a miss or raid costs (needs the simulator), and the throw upgrades' names and wasps-per-hit numbers.
10. Technology: bought or researched, what it contains besides throw upgrades, and whether it really opens right at the 2nd comb.
11. Candles: is crafting one section together with Technology, or a tab inside it? How much wax each candle costs, whether crafting takes time, and whether anything besides wax is needed (sage, propolis).
12. Candles: the stage order. The repellent candle needs wasps (stage 6) and the Hippie candle needs Hippies (stage 7), but candles are stage 4. Do candles move later, or do Hippies arrive with them?
