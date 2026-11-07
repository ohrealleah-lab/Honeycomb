#!/usr/bin/env python3
"""Beekeeper first-hour simulation (task T006). Not shipped; used to tune placeholder numbers.

Plays the early loop second by second for a simple, steady player:
  - clicks Catch Bee `cps` times a second (bare hands sting 20% of the time)
  - sells all honey to the bear every `sell_every` seconds
  - buys Gloves, Net, Vacuum, Wax-Catcher in that order as soon as affordable
  - builds a comb as soon as wax allows

Run:  python3 simulate_first_hour.py            (default numbers)
      python3 simulate_first_hour.py --storage 1000 --comb-storage 1000
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--storage", type=float, default=200)
    ap.add_argument("--comb-storage", type=float, default=200)
    ap.add_argument("--sell-every", type=int, default=10)
    ap.add_argument("--honey-per-bee", type=float, default=0.01)
    ap.add_argument("--minutes", type=int, default=60)
    ap.add_argument("--tool-cost-scale", type=float, default=1.0)
    a = ap.parse_args()

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


if __name__ == "__main__":
    main()
