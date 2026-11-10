#!/usr/bin/env python3
"""Beekeeper economy simulation. Not shipped; used to tune placeholder numbers.

Default: the combs economy (stage 7.5, spec windows/016-beekeeper-combs), four weeks for a fast
clicker, a steady player and an idle player. It reports the first hours, the walls (which price,
which cap, when a player meets it), fast against idle, whether growth levels off around week 3,
and every price set for the old economy that needs a new look.

--old: the original first-hour run (task T006), where every bee made honey. Kept for comparing.
  Plays the early loop second by second for a simple, steady player:
  - clicks Catch Bee `cps` times a second (bare hands sting 20% of the time)
  - sells all honey to the bear every `sell_every` seconds
  - buys Gloves, Net, Vacuum, Wax-Catcher in that order as soon as affordable
  - builds a comb as soon as wax allows

Run:  python simulate_first_hour.py                 (the combs economy)
      python simulate_first_hour.py --set WaxTrayCapacity=20 --set StartingWaxCap=30
      python simulate_first_hour.py --old           (the old economy)
      python simulate_first_hour.py --old --storage 1000 --comb-storage 1000
"""
import argparse

TOOLS = [("Gloves", 15, 2), ("Net", 75, 5), ("Vacuum", 250, 10)]
WAX_CATCHER_COST = 150


def simulate(cps, storage0, comb_storage, sell_every, honey_per_bee, minutes,
             tool_cost_scale=1.0):
    bees = 0.0
    honey = 0.0
    wax = 0
    wax_progress = 0.0   # honey stored since last wax
    beebits = 0
    combs = 0
    tool = -1            # -1 = bare hands
    catcher = False
    storage = storage0
    ms = {}              # milestone name -> second
    full_seconds = 0
    wasted = 0.0
    shop_open = False
    last_clicks_frac = 0.0

    def mark(name, t):
        if name not in ms:
            ms[name] = t

    for t in range(1, minutes * 60 + 1):
        # clicking
        last_clicks_frac += cps
        clicks = int(last_clicks_frac)
        last_clicks_frac -= clicks
        per_click = 1 if tool < 0 else TOOLS[tool][2]
        eff = 0.8 if tool < 0 else 1.0          # 20% stings with bare hands
        gained = clicks * per_click * eff
        if gained > 0:
            mark("first bee", t)
        bees += gained

        # honey into storage
        made = bees * honey_per_bee
        room = storage - honey
        stored = min(made, max(room, 0))
        wasted += made - stored
        if room <= 0:
            full_seconds += 1
            mark("storage first full", t)
        honey += stored
        wax_progress += stored
        while wax_progress >= 50:
            wax_progress -= 50
            wax += 2 if catcher else 1
            mark("first wax", t)

        if honey >= 10:
            mark("bear arrives (10 honey)", t)

        # selling
        if t % sell_every == 0 and honey >= 10:
            bundles = int(honey // 10)
            honey -= bundles * 10
            beebits += bundles
            mark("first sale", t)

        if beebits >= 15 and not shop_open:
            shop_open = True
            mark("shop opens (15 Beebits)", t)

        # buying (in order)
        if tool + 1 < len(TOOLS):
            name, cost, _ = TOOLS[tool + 1]
            cost = int(cost * tool_cost_scale)
            if shop_open and beebits >= cost:
                beebits -= cost
                tool += 1
                mark(name, t)
        if not catcher and shop_open and beebits >= WAX_CATCHER_COST and tool >= 2:
            beebits -= WAX_CATCHER_COST
            catcher = True
            mark("Wax-Catcher", t)

        # combs
        cost = int(50 * 1.25 ** combs)
        if wax >= 50:
            mark("50 wax (combs appear)", t)
        if wax >= cost:
            wax -= cost
            combs += 1
            storage += comb_storage
            mark(f"comb {combs}", t)

    return ms, dict(bees=bees, honey=honey, wax=wax, beebits=beebits, combs=combs,
                    storage=storage, full_seconds=full_seconds, wasted=wasted,
                    seconds=minutes * 60)


def fmt(sec):
    return "never" if sec is None else f"{sec // 60}m{sec % 60:02d}s"


def old_report(a):
    speeds = [0.5, 1, 3, 5]
    names = ["first bee", "bear arrives (10 honey)", "first sale", "shop opens (15 Beebits)",
             "Gloves", "Net", "Vacuum", "Wax-Catcher", "first wax", "50 wax (combs appear)",
             "comb 1", "comb 2", "comb 3", "comb 5", "storage first full"]
    results = {s: simulate(s, a.storage, a.comb_storage, a.sell_every, a.honey_per_bee,
                           a.minutes, a.tool_cost_scale) for s in speeds}

    print(f"storage {a.storage:g} (+{a.comb_storage:g}/comb) · sells every {a.sell_every}s · "
          f"{a.honey_per_bee:g} honey/bee/s · tool prices x{a.tool_cost_scale:g} · {a.minutes} min\n")
    print(f"{'milestone':28}" + "".join(f"{str(s)+' click/s':>14}" for s in speeds))
    for n in names:
        print(f"{n:28}" + "".join(f"{fmt(results[s][0].get(n)):>14}" for s in speeds))
    print()
    print(f"{'at the end':28}" + "".join(f"{str(s)+' click/s':>14}" for s in speeds))
    for key in ["bees", "combs", "storage", "beebits", "wax"]:
        print(f"{key:28}" + "".join(f"{results[s][1][key]:>14,.0f}" for s in speeds))
    print(f"{'% of time storage full':28}" + "".join(
        f"{100*results[s][1]['full_seconds']/results[s][1]['seconds']:>13.0f}%" for s in speeds))
    print(f"{'honey wasted (full)':28}" + "".join(f"{results[s][1]['wasted']:>14,.0f}" for s in speeds))


# =====================================================================================
# The combs economy. The names in CFG are the names the numbers get in BeekeeperConfig.
# Everything below CFG is the current config, copied. Bees and wax buy combs; combs make
# honey at a flat rate; free bees make wax; both caps stop production. No auto-sale and no
# honey-to-wax. A wall is a visible wax price above the wax cap.
# Left out on purpose: the bee-boost and sage-propolis candles (small boosts, honey only).
# =====================================================================================
CFG = dict(
    # production
    HoneyPerCombPerSecond=0.2,
    WaxBasePerSecond=0.005,
    WaxPerFreeBeePerSecond=0.0001,
    # caps
    StartingHoneyCap=200, HoneyCapPerComb=300,
    StartingWaxCap=20, WaxCapPerComb=2,
    # comb prices (n = combs bought so far; the starter comb does not count)
    CombBaseBeeCost=20, CombBeeCostGrowth=1.4,
    CombBaseWaxCost=10, CombCostGrowth=1.25,
    # capacity upgrades: repeatable, flat, Beebits only, so a wall can always be paid past
    HoneySuperCapacity=1000, HoneySuperBaseCost=75, HoneySuperCostGrowth=1.5,
    WaxTrayCapacity=8, WaxTrayBaseCost=100, WaxTrayCostGrowth=1.6,
    # the bear
    HoneyPerBeebit=10, BetterHoneyPerBeebit=8, AgreementTrades=25,
    # reveals and the Workbench
    CombsRevealWax=5, WorkbenchCombs=3,
)

# Prices set for the old economy, unchanged in stage 7.5. Id -> Beebits, wax, sage, paper, propolis.
TOOLS_ALL = [("gloves", 15, 2), ("net", 75, 5), ("vacuum", 250, 10),
             ("lure", 1000, 25), ("cart", 4000, 60), ("whistle", 15000, 150)]
UPGRADES = {
    "bigger_combs_1": (300, 100, 0, 0, 0), "bigger_combs_2": (800, 250, 2, 0, 0),
    "better_wax_catcher": (400, 0, 1, 0, 0), "stronger_candles": (200, 50, 2, 0, 0),
    "practice": (600, 50, 0, 0, 0), "more_practice": (2500, 200, 3, 0, 0), "smoker": (500, 50, 0, 0, 0),
    "notebook": (100, 0, 0, 20, 0), "third_bed": (1500, 200, 0, 10, 0), "propolis_seal": (1000, 150, 0, 0, 30),
}
# Seed: trade count, grow seconds, who gives it.
PLANTS = {"wildflowers": (5, 600, "h"), "bramble": (10, 600, "h"), "willow": (20, 3600, "h"),
          "poplar": (10, 21600, "w"), "clover": (35, 43200, "h")}
OTHER_WAX = {"beeswax candle": 10, "repellent candle": 10, "bee-boost candle": 20,
             "sage-propolis candle": 20}
WOODEN_HIVE_WAX = 200
DAY = 86400


class Hive:
    """One game of the combs economy, following the rules in spec 016."""

    def __init__(s, c):
        s.c = c
        s.t = 0
        s.free = 0.0
        s.honey = 0.0
        s.wax = 0.0
        s.bits = 0.0
        s.combs = 1                  # the starter comb counts as a comb
        s.first_bee = False          # sticky: free bees can go back to zero
        s.tool = 0
        s.catcher = False
        s.ups = set()
        s.supers = 0
        s.trays = 0
        s.trades = 0
        s.candles = 0
        s.crafted = 0
        s.sage = 0
        s.h_trades = 0
        s.w_trades = 0
        s.bribes = 0
        s.paper = 0
        s.emissary = False
        s.next_wasp = 360
        s.seeds = []
        s.given = set()
        s.beds = []
        s.plants = []
        s.pollen = 0.0
        s.bread = 0.0
        s.bread_seen = False
        s.propolis = 0.0
        s.wooden = False
        s.combs_seen = False
        s.bear = False
        s.shop = False
        s.calm_on = False
        s.seen = {}
        s.bought = {}
        s.ms = {}
        s.walls = {}
        s.last_cap = "start"
        s.full_h = 0
        s.full_w = 0
        s.total = 0
        s.earned = 0.0

    # ---- derived numbers
    def bench(s):
        return s.combs >= s.c["WorkbenchCombs"]

    def tech(s):
        """The Technologies, one-time % boosts on both caps."""
        m = 2.0 if "bigger_combs_2" in s.ups else 1.5 if "bigger_combs_1" in s.ups else 1.0
        return m * (1.25 if "propolis_seal" in s.ups else 1.0)

    def honey_cap(s):
        c = s.c
        return (c["StartingHoneyCap"] + (s.combs - 1) * c["HoneyCapPerComb"]
                + s.supers * c["HoneySuperCapacity"]) * s.tech()

    def wax_cap(s):
        c = s.c
        return (c["StartingWaxCap"] + (s.combs - 1) * c["WaxCapPerComb"]
                + s.trays * c["WaxTrayCapacity"]) * s.tech()

    def honey_rate(s, live=False):
        if not s.first_bee:
            return 0.0
        mult = (1.25 if s.wooden else 1.0) * (1.25 if "bramble" in s.plants else 1.0)
        return s.combs * s.c["HoneyPerCombPerSecond"] * mult * (2.0 if live and s.calm_on else 1.0)

    def wax_mult(s):
        return 1.0 if not s.catcher else 3.0 if "better_wax_catcher" in s.ups else 2.0

    def wax_rate(s, bees=None):
        bees = s.free if bees is None else bees
        return (s.c["WaxBasePerSecond"] + bees * s.c["WaxPerFreeBeePerSecond"]) * s.wax_mult()

    def queen(s):
        if not s.wooden or s.bread <= 0:
            return 0.0
        return 20.0 * (1.5 if "willow" in s.plants else 1.0)

    def comb_price(s):
        c = s.c
        b = float(c["CombBaseBeeCost"])
        w = float(c["CombBaseWaxCost"])
        for _ in range(s.combs - 1):
            b *= c["CombBeeCostGrowth"]
            w *= c["CombCostGrowth"]
        return int(b), int(w)

    @staticmethod
    def repeat_price(base, growth, n):
        v = float(base)
        for _ in range(n):
            v *= growth
        return int(v)

    def super_price(s):
        return s.repeat_price(s.c["HoneySuperBaseCost"], s.c["HoneySuperCostGrowth"], s.supers)

    def tray_price(s):
        return s.repeat_price(s.c["WaxTrayBaseCost"], s.c["WaxTrayCostGrowth"], s.trays)

    def rate(s):
        better = s.trades >= s.c["AgreementTrades"]
        return s.c["BetterHoneyPerBeebit"] if better else s.c["HoneyPerBeebit"]

    def click_bees(s):
        base = 1 if s.tool == 0 else TOOLS_ALL[s.tool - 1][2]
        m = 2.0 if "more_practice" in s.ups else 1.5 if "practice" in s.ups else 1.0
        return int(base * m)

    def unlocked(s, u):
        vacuum = s.tool >= 3
        paper = s.emissary and s.w_trades > 0
        return {"bigger_combs_1": s.bench(), "bigger_combs_2": "bigger_combs_1" in s.ups,
                "better_wax_catcher": s.bench() and s.catcher,
                "stronger_candles": s.h_trades > 0 and not s.emissary,
                "practice": vacuum, "more_practice": "practice" in s.ups, "smoker": vacuum,
                "notebook": paper, "third_bed": paper and bool(s.given),
                "propolis_seal": s.propolis >= 1}[u]

    def mark(s, k):
        if k not in s.ms:
            s.ms[k] = s.t

    # ---- time passing: exact amounts for the stretch, as the engine does it
    def advance(s, dt, live):
        s.total += dt
        rate = s.honey_rate(live)
        room = max(0.0, s.honey_cap() - s.honey)
        if room <= 0 and rate > 0:
            s.full_h += dt
        s.honey += min(rate * dt, room)

        laying = s.queen()
        raised = 0.0
        if laying > 0:
            raised = min(laying * dt / 60.0, s.bread * 100.0)
            s.bread = max(0.0, s.bread - raised / 100.0)
        average_bees = s.free + raised / 2.0    # the queen's triangle, now under the wax line
        s.free += raised
        wax_room = max(0.0, s.wax_cap() - s.wax)
        if wax_room <= 0:
            s.full_w += dt
        s.wax += min(s.wax_rate(average_bees) * dt, wax_room)
        if s.wax >= s.c["CombsRevealWax"]:
            s.combs_seen = True

        pollen_plants = ("wildflowers" in s.plants) + ("clover" in s.plants)
        s.pollen += 3 * pollen_plants * dt / 60.0
        if "poplar" in s.plants:
            s.propolis += dt / 60.0
        for bed in list(s.beds):
            bed[1] -= dt
            if bed[1] <= 0:
                s.beds.remove(bed)
                s.plants.append(bed[0])
                s.mark("sprout " + bed[0])
        s.t += dt

    def click(s, clicks):
        if clicks <= 0:
            return
        success = 0.8 if s.tool == 0 else 1.0
        tool_bees = s.click_bees()
        slice_bees = min(int(s.free * 0.001), tool_bees * 10)   # free bees only
        s.free += clicks * success * (tool_bees + slice_bees)
        s.first_bee = True
        s.mark("first bee")

    def give_seeds(s):
        for plant, (n, _, giver) in PLANTS.items():
            if plant not in s.given and (s.h_trades if giver == "h" else s.w_trades) >= n:
                s.given.add(plant)
                s.seeds.append(plant)
                s.mark("seed " + plant)

    # ---- the walls: every visible price, and which are above the wax cap
    def visible(s):
        out = {}
        if s.combs_seen:
            out["comb #%d" % (s.combs + 1)] = s.comb_price()[1]
        if s.bench() and not s.wooden and s.bread_seen:
            out["wooden hive"] = WOODEN_HIVE_WAX
        if s.shop and s.tool < len(TOOLS_ALL):
            out[TOOLS_ALL[s.tool][0]] = 0
        if s.shop and not s.catcher:
            out["wax_catcher"] = 0
        for u, p in UPGRADES.items():
            if u not in s.ups and s.unlocked(u):
                out[u] = p[1]
        return out

    def track_walls(s):
        cap = s.wax_cap()
        for name, wax in s.visible().items():
            if name not in s.seen:
                s.seen[name] = s.t
            if wax > cap and name not in s.walls:
                s.walls[name] = dict(price=wax, cap=cap, opened=s.t, closed=None, by=None)
        for w in s.walls.values():
            if w["closed"] is None and cap >= w["price"]:
                w["closed"] = s.t
                w["by"] = s.last_cap

    # ---- a simple greedy player
    def act(s, live):
        c = s.c
        s.track_walls()
        if s.honey >= 10:
            s.bear = True
        pantry_goal = 150 if s.wooden else 12
        while s.pollen >= 10 and s.honey >= 10 and s.bread < pantry_goal:
            s.pollen -= 10
            s.honey -= 10
            s.bread += 1
            s.bread_seen = True
        if s.emissary and s.w_trades < 35 and s.honey >= 50:
            s.honey -= 50
            s.paper += 1
            s.w_trades += 1
            s.give_seeds()
        for plant in list(s.seeds):
            if len(s.beds) < (3 if "third_bed" in s.ups else 2):
                s.seeds.remove(plant)
                s.beds.append([plant, PLANTS[plant][1]])
        half_full = s.honey >= 0.5 * s.honey_cap()
        if s.bear and s.honey >= s.rate() and (half_full or s.t % 120 == 0):
            bundles = s.honey // s.rate()
            s.honey -= bundles * s.rate()
            s.bits += bundles
            s.earned += bundles
            s.trades += 1
            if s.trades == c["AgreementTrades"]:
                s.mark("better selling rate")
        if s.bits >= 15:
            s.shop = True

        bought = True
        while bought:
            bought = False
            bees, wax = s.comb_price()
            if s.combs_seen and s.free >= bees and s.wax >= wax:
                s.free -= bees
                s.wax -= wax
                s.combs += 1
                s.last_cap = "comb"
                bought = True
                s.mark("comb %d" % s.combs)
                if s.combs == c["WorkbenchCombs"]:
                    s.mark("workbench and first wasp")
            if not s.wooden and s.bread_seen and s.wax >= WOODEN_HIVE_WAX and s.bread >= 10 and s.bench():
                s.wax -= WOODEN_HIVE_WAX
                s.bread -= 10
                s.wooden = True
                s.bought["wooden hive"] = s.t
                s.mark("wooden hive and queen")
                bought = True
            if not s.shop:
                continue
            options = []
            if s.tool < len(TOOLS_ALL):
                options.append((TOOLS_ALL[s.tool][1], "tool"))
            if not s.catcher:
                options.append((150, "catcher"))
            if s.combs_seen:
                options.append((s.tray_price(), "tray"))
                options.append((s.super_price(), "super"))
            for u, p in UPGRADES.items():
                if (u not in s.ups and s.unlocked(u) and s.wax >= p[1] and s.sage >= p[2]
                        and s.paper >= p[3] and s.propolis >= p[4]):
                    options.append((p[0], u))
            if options:
                price, what = min(options, key=lambda x: x[0])
                if s.bits >= price:
                    s.bits -= price
                    bought = True
                    if what == "tool":
                        s.tool += 1
                        s.mark(TOOLS_ALL[s.tool - 1][0])
                        s.bought[TOOLS_ALL[s.tool - 1][0]] = s.t
                    elif what == "catcher":
                        s.catcher = True
                        s.mark("wax-catcher")
                        s.bought["wax_catcher"] = s.t
                    elif what == "tray":
                        s.trays += 1
                        s.last_cap = "Wax Tray %d" % s.trays
                    elif what == "super":
                        s.supers += 1
                    else:
                        p = UPGRADES[what]
                        s.wax -= p[1]
                        s.sage -= p[2]
                        s.paper -= p[3]
                        s.propolis -= p[4]
                        s.ups.add(what)
                        s.bought[what] = s.t
                        s.mark(what)
                        if what in ("bigger_combs_1", "bigger_combs_2", "propolis_seal"):
                            s.last_cap = what

        # Wax left over goes to candles, keeping what the next buy that fits needs.
        goals = [s.comb_price()[1]] if s.combs_seen else []
        if s.bread_seen and not s.wooden:
            goals.append(WOODEN_HIVE_WAX)
        goals += [p[1] for u, p in UPGRADES.items() if u not in s.ups and s.unlocked(u) and p[1] > 0]
        cap = s.wax_cap()
        fits = [g for g in goals if g <= cap]
        keep = min(fits) if fits else 0
        full = s.wax >= cap - 0.01
        while s.bench() and (s.wax >= keep + 10 or (full and s.wax >= 10)):
            s.wax -= 10
            s.candles += 1
            s.crafted += 1
            full = False
        if s.crafted >= 5 and s.candles >= 10:
            s.candles -= 10
            s.sage += 1
            s.h_trades += 1
            s.give_seeds()

        # Wasps come in live play once the Workbench is open; the player bribes until the emissary.
        if live and s.bench() and not s.emissary:
            s.next_wasp -= 1
            if s.next_wasp <= 0 and s.honey >= 1:
                s.honey -= max(1, int(s.honey * 0.25))
                s.bribes += 1
                s.next_wasp = 360
                if s.bribes >= 5:
                    s.emissary = True
                    s.mark("emissary")


class Player:
    def __init__(p, name, cps, first_day_minutes, sessions, minutes):
        p.name = name
        p.cps = cps
        p.first = first_day_minutes
        p.sessions = sessions
        p.minutes = minutes


PLAYERS = [Player("fast clicker", 6.0, 180, 2, 45),
           Player("steady player", 2.0, 60, 2, 20),
           Player("idle player", 0.2, 10, 2, 5)]
CHECK_DAYS = [1, 2, 3, 5, 7, 10, 14, 17, 21, 24, 28]


def play(player, cfg, days):
    h = Hive(cfg)
    snaps = {}
    carry = 0.0
    for d in range(days):
        plan = [player.first] if d == 0 else [player.minutes] * player.sessions
        gap = (DAY - sum(plan) * 60) // len(plan)
        for minutes in plan:
            for _ in range(minutes * 60):
                carry += player.cps
                clicks = int(carry)
                carry -= clicks
                h.calm_on = "smoker" in h.ups and clicks > 0   # a clicker keeps the bees calm
                h.click(clicks)
                h.advance(1, True)
                h.act(True)
            h.calm_on = False
            left = gap
            while left > 0:
                step = min(60, left)
                h.advance(step, False)
                left -= step
                h.track_walls()
        left = (d + 1) * DAY - h.t
        while left > 0:
            step = min(60, left)
            h.advance(step, False)
            left -= step
        snaps[d + 1] = dict(combs=h.combs, honey_rate=h.honey_rate(), free=h.free, wax_cap=h.wax_cap(),
                            honey_cap=h.honey_cap(), earned=h.earned, wax_rate=h.wax_rate(),
                            honey_fill=h.honey_cap() / max(h.honey_rate(), 1e-9),
                            wax_fill=h.wax_cap() / max(h.wax_rate(), 1e-9))
    return h, snaps


def when(sec):
    if sec is None:
        return "-"
    d = int(sec // DAY)
    h = int(sec % DAY // 3600)
    m = int(sec % 3600 // 60)
    return f"{d}d{h:02d}h" if d else f"{h}h{m:02d}m"


def report(cfg, days):
    runs = [(p, *play(p, cfg, days)) for p in PLAYERS]
    print("THE COMBS ECONOMY (spec 016). Placeholders, named as they are in BeekeeperConfig:")
    for k, v in cfg.items():
        print(f"  {k} = {v}")
    print("Players (clicks a second; minutes on day 1; then sessions x minutes a day):")
    for p in PLAYERS:
        print(f"  {p.name}: {p.cps}/s; {p.first} min; {p.sessions} x {p.minutes} min")

    print("\n--- 1. Milestones")
    names = ["first bee", "comb 2", "gloves", "comb 3", "workbench and first wasp", "net", "wax-catcher",
             "better selling rate", "vacuum", "emissary", "seed wildflowers", "smoker", "bigger_combs_1",
             "wooden hive and queen", "seed bramble", "seed willow", "sprout poplar", "bigger_combs_2",
             "propolis_seal", "seed clover", "lure", "cart", "whistle"]
    print(f"{'milestone':28}" + "".join(f"{p.name:>16}" for p, _, _ in runs))
    for n in names:
        print(f"{n:28}" + "".join(f"{when(h.ms.get(n)):>16}" for _, h, _ in runs))

    print("\n--- 2. The walls: a visible wax price above the wax cap. For each player: when it was met,")
    print("    the cap then, how long until it fit, and what made it fit. Comb #8 is the 8th comb, counting the starter.")
    keys = []
    for _, h, _ in runs:
        keys += [k for k in h.walls if k not in keys]
    keys.sort(key=lambda k: min(h.walls[k]["opened"] for _, h, _ in runs if k in h.walls))
    print(f"{'price':20}{'wax':>7}" + "".join(f"{p.name:>42}" for p, _, _ in runs))
    for k in keys:
        first = next(h.walls[k] for _, h, _ in runs if k in h.walls)
        row = f"{k:20}{first['price']:>7,}"
        for _, h, _ in runs:
            w = h.walls.get(k)
            if not w:
                row += f"{'no wall' if k in h.seen else 'not reached':>42}"
                continue
            wait = "still open" if w["closed"] is None else when(w["closed"] - w["opened"])
            row += f"{when(w['opened']) + ', cap ' + format(w['cap'], ',.0f') + ', ' + wait + ', ' + str(w['by'] or '-'):>42}"
        print(row)

    print("\n--- 3. Fast clicker against idle player")
    print(f"{'day':>4}" + "".join(f"{p.name + ' combs':>21}{'honey/s':>9}{'wax cap':>9}" for p, _, _ in runs))
    for d in CHECK_DAYS:
        if d <= days:
            print(f"{d:>4}" + "".join(f"{s[d]['combs']:>21}{s[d]['honey_rate']:>9.1f}{s[d]['wax_cap']:>9,.0f}"
                                      for _, _, s in runs))
    for label, f in (("free bees at the end", lambda h: f"{h.free:,.0f}"),
                     ("% of time wax full", lambda h: f"{100 * h.full_w / h.total:.0f}%"),
                     ("% of time honey full", lambda h: f"{100 * h.full_h / h.total:.0f}%")):
        print(f"{label:24}" + "".join(f"{p.name + ': ' + f(h):>30}" for p, h, _ in runs))
    print("  Time away that still pays: how long empty caps take to fill (honey / wax) at the end of a day")
    for d in (1, 7, 21):
        if d <= days:
            print(f"    day {d:<3}" + "".join(f"{p.name + ': ' + when(s[d]['honey_fill']) + ' / ' + when(s[d]['wax_fill']):>36}" for p, _, s in runs))
    fast, idle = runs[0][2], runs[2][2]
    for d in (1, 7, 21):
        if d <= days:
            print(f"  day {d}: the fast clicker has {fast[d]['combs'] / idle[d]['combs']:.1f}x the idle player's combs "
                  f"and has earned {fast[d]['earned'] / max(1, idle[d]['earned']):.1f}x the Beebits.")

    if days >= 28:
        print("\n--- 4. Does growth level off around week 3? (honey a second, without calm)")
        for p, h, s in runs:
            a, b, c, d = s[7], s[14], s[21], s[28]
            growth = lambda x, y: 100 * (y["honey_rate"] / max(x["honey_rate"], 1e-9) - 1)
            earned = lambda x, y: y["earned"] - x["earned"]
            print(f"  {p.name:14} honey: week 2 +{growth(a, b):.0f}%, week 3 +{growth(b, c):.0f}%, week 4 +{growth(c, d):.0f}%"
                  f"  | combs d7 {a['combs']}, d14 {b['combs']}, d21 {c['combs']}, d28 {d['combs']}"
                  f"  | Beebits earned wk2 {earned(a, b):,.0f}, wk3 {earned(b, c):,.0f}, wk4 {earned(c, d):,.0f}")
            print(f"  {'':14} -> {'levelled off' if growth(c, d) <= 10 else 'still growing'} after week 3 (10% or less in week 4 counts as levelled off)")

    print(f"\n--- 5. Prices set for the old economy, unchanged here (first seen -> bought, in {days} days)")
    print(f"{'price':22}{'Beebits':>9}{'wax':>6}" + "".join(f"{p.name:>21}" for p, _, _ in runs) + "   needs a new look because")
    rows = [(t[0], t[1], 0) for t in TOOLS_ALL] + [("wax_catcher", 150, 0)]
    rows += [(u, p[0], p[1]) for u, p in UPGRADES.items()] + [("wooden hive", 0, WOODEN_HIVE_WAX)]
    for name, bits, wax in rows:
        row = f"{name:22}{bits:>9,}{wax:>6}"
        reasons = []
        never = 0
        slow = 0
        for p, h, _ in runs:
            seen, got = h.seen.get(name), h.bought.get(name)
            if got is None:
                never += 1
                row += f"{(when(seen) if seen is not None else 'unseen') + ' -> never':>21}"
            else:
                if seen is not None and got - seen > 3 * DAY:
                    slow += 1
                row += f"{when(seen if seen is not None else got) + ' -> ' + when(got):>21}"
        walls = [h.walls[name] for _, h, _ in runs if name in h.walls]
        if walls:
            reasons.append(f"WALL: {wax} wax is above the wax cap when seen ({min(w['cap'] for w in walls):,.0f} to {max(w['cap'] for w in walls):,.0f})")
        if never:
            reasons.append(f"never bought by {never} of 3")
        if slow:
            reasons.append(f"over 3 days' wait for {slow} of 3")
        if not reasons:
            reasons.append("fits; priced for the old income, so check against the new")
        print(row + "   " + "; ".join(reasons))
    print("  Small wax prices that always fit but use up a small cap: " + ", ".join(f"{k} {v}" for k, v in OTHER_WAX.items()))
    print("  Honey prices: bee bread 10 honey and paper 50 honey fit the honey cap; the x100 paper batch (5,000 honey) needs a far bigger one.")

    print("\n--- 6. Where each player is stuck at the end (to-dos for later stages)")
    for p, h, _ in runs:
        bees, wax = h.comb_price()
        print(f"  {p.name}: {h.combs} combs; next comb {bees:,} bees + {wax:,} wax; wax cap {h.wax_cap():,.0f}; "
              f"next Wax Tray {h.tray_price():,} Beebits (level {h.trays}); Beebits in hand {h.bits:,.0f}; tools {h.tool}/{len(TOOLS_ALL)}; "
              f"not bought: {sorted(set(UPGRADES) - h.ups)}; open walls: {[k for k, w in h.walls.items() if w['closed'] is None]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", action="store_true", help="the old first-hour run, where every bee made honey")
    ap.add_argument("--set", action="append", default=[], metavar="NAME=VALUE", help="change one number in CFG")
    ap.add_argument("--days", type=int, default=28)
    ap.add_argument("--storage", type=float, default=200)
    ap.add_argument("--comb-storage", type=float, default=200)
    ap.add_argument("--sell-every", type=int, default=10)
    ap.add_argument("--honey-per-bee", type=float, default=0.01)
    ap.add_argument("--minutes", type=int, default=60)
    ap.add_argument("--tool-cost-scale", type=float, default=1.0)
    a = ap.parse_args()

    if a.old:
        old_report(a)
        return
    cfg = dict(CFG)
    for item in a.set:
        name, value = item.split("=", 1)
        if name not in cfg:
            ap.error(f"{name} is not one of the numbers in CFG")
        cfg[name] = float(value)
    report(cfg, a.days)


if __name__ == "__main__":
    main()
