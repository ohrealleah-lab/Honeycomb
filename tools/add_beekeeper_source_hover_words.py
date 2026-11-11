"""Beekeeper (Bee, 2026-11-11): every stat that grows on its own has a hover listing everything
that feeds it: each source (the wax drip, free bees, combs, the queen, Wanderers, foraging, resin)
and each multiplier that is on (Wax-Catcher, wooden hive, guarding, nursing). Run once from the
repo root, then run generate_localization.py. Safe to re-run."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    # --- sources: a per-second amount
    (B, "beekeeper_source_on_its_own_fmt", "Wax hover: the drip that gathers with no bees; %@ = per second",
     "+%@ / sec on its own", "+%@ / s por su cuenta", True),
    (B, "beekeeper_source_free_bees_fmt", "Wax hover; %@ = per second, %@ = how many free bees",
     "+%@ / sec from %@ free bees", "+%@ / s de %@ abejas libres", True),
    (B, "beekeeper_source_free_bee_one_fmt", "Wax hover with exactly 1 free bee; %@ = per second",
     "+%@ / sec from 1 free bee", "+%@ / s de 1 abeja libre", True),
    (B, "beekeeper_source_combs_fmt", "Honey hover; %@ = per second before boosts, %@ = how many combs",
     "+%@ / sec from %@ combs", "+%@ / s de %@ panales", True),
    (B, "beekeeper_source_comb_one_fmt", "Honey hover with exactly 1 comb; %@ = per second before boosts",
     "+%@ / sec from 1 comb", "+%@ / s de 1 panal", True),
    (B, "beekeeper_source_queen_fmt", "Bees hover; %@ = bees per second the queen raises",
     "+%@ / sec from the queen", "+%@ / s de la reina", True),
    (B, "beekeeper_source_herb_fmt", "Bees hover while an herbal candle's buff brings bees; %@ = per second, %@ = the buff's name",
     "+%@ / sec from %@", "+%@ / s por %@", True),
    (B, "beekeeper_source_foraging_fmt", "Pollen hover; %@ = pollen per second",
     "+%@ / sec from foraging", "+%@ / s de la recolección", True),
    (B, "beekeeper_source_resin_fmt", "Propolis hover; %@ = propolis per second",
     "+%@ / sec from resin", "+%@ / s de la resina", True),

    # --- multipliers that last
    (B, "beekeeper_boost_wax_catcher_fmt", "Wax hover with a Wax-Catcher; %@ = extra wax in percent",
     "+%@% from the Wax-Catcher", "+%@% por el colector de cera", True),
    (B, "beekeeper_boost_wooden_hive_fmt", "Honey hover in the wooden hive; %@ = extra honey in percent",
     "+%@% from the wooden hive", "+%@% por la colmena de madera", True),
    (B, "beekeeper_boost_guarding_fmt", "Honey hover with guarding; %@ = extra honey in percent",
     "+%@% from guarding", "+%@% por la guardia", True),
    (B, "beekeeper_boost_nursing_fmt", "Bees hover with nursing; %@ = how much faster the queen lays, in percent",
     "+%@% from nursing", "+%@% por la crianza", True),
]


def main() -> None:
    wb = openpyxl.load_workbook(PATH)
    ws = wb.worksheets[0]
    rows = {str(r[1].value).strip(): r for r in ws.iter_rows(min_row=2) if r[1].value}
    added = updated = 0
    for sec, key, ctx, en, es, tr in NEW:
        if key in rows:
            r = rows[key]
            r[2].value, r[3].value, r[4].value, r[5].value = ctx, en, es, tr
            updated += 1
        else:
            ws.append([sec, key, ctx, en, es, tr])
            added += 1
    wb.save(PATH)
    print(f"added {added}, updated {updated}")


if __name__ == "__main__":
    main()
