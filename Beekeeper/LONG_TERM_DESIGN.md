# Beekeeper: Long-Term Design (planned, NOT in the first build)

Written 2026-11-06 from Leah's decisions. Inspired by idle games like Kittens Game, but not a copy: the hooks below come from real beekeeping.

## The shape of the game
- **Length:** 1.5 to 4 weeks. Growth should level off around week 3, which is where the first swarm (reset) happens.
- **Tone:** cozy. Wasps steal honey, not bees. Later pests may steal other resources.
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
4. **Candles and the Chandler's Workshop:** plain beeswax candle (+20% honey for a time), sage-propolis candle (wasp repellent, duration to decide), candles sold to Hippies.
5. **Sites and special bees:** Garden, Meadow, Honey Factory. Special bees can only be caught by clicking, and which kind depends on the site.
6. **Wasps (cozy):** raids steal honey; bribe, guards or candles stop them; bears reduce raids after 100 trades.
7. **Reputations:** Bears, Hippies, Hummingbirds, Badgers, each with their own wants.
8. **Seasons, as a bloom calendar:** instead of four generic seasons, different flowers bloom in turn (crocus, clover, linden, goldenrod), each rewarding different roles and honey, ending in a winter cluster. Chosen to feel like beekeeping, not like Kittens.
9. **Swarming:** the reset with a bonus, and the long-term goal.
10. **Other platforms:** Mac, iOS, Android once Windows is playable. Mobile text must stay free of betting words.

## Decisions made
- Clicking stays "catch bees" (the game's premise) and stays relevant through scaling, the Smoker and special bees.
- Hive roles are important, not decoration.
- Swarming is the reset.
- Seasons: yes, later, in a form that is not a copy of Kittens.
- Wasps steal honey.
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
