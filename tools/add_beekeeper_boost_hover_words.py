"""Beekeeper (Bee, 2026-11-11): the Hive card's honey and wax hovers list the boosts that are on
right now (the Smoker, an herbal candle's buff, the bee-boost and herb-propolis candles), and the
bear's rate line says "1 herb" rather than "1 herbs". Run once
from the repo root, then run generate_localization.py. Safe to re-run."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    (B, "beekeeper_boost_smoker_fmt", "Honey hover while the Smoker is on; %@ = extra honey in percent",
     "+%@% from the Smoker", "+%@% por el ahumador", True),
    (B, "beekeeper_boost_herb_fmt", "Honey or wax hover while an herbal candle's buff burns; %@ = percent, %@ = the buff's name",
     "+%@% from %@", "+%@% por %@", True),
    (B, "beekeeper_boost_bee_boost_fmt", "Honey hover while a bee-boost candle burns; %@ = extra honey in percent",
     "+%@% from the bee-boost candle", "+%@% por la vela de impulso", True),
    (B, "beekeeper_boost_herb_propolis_fmt", "Honey hover while a herb-propolis candle burns; %@ = extra honey in percent",
     "+%@% from the herb-propolis candle", "+%@% por la vela de hierbas y propóleo", True),
    (B, "beekeeper_sell_hint_one_fmt", "Under the bear's buttons when a trade gives exactly 1 herb; %@ = honey in one trade",
     "%@ honey = 1 herb", "%@ de miel = 1 hierba", True),
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
