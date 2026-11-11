"""Beekeeper herbal candle buff Quick Fingers (Bee, 2026-11-11): adds its words to the localization
workbook. Run once from the repo root, then run generate_localization.py. Safe to re-run: rows whose
key already exists are updated in place."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    (B, "beekeeper_herb_quick_fingers", "Bee Herb buff: Catch Bee and the Smoker are x3 for a short while",
     "Quick Fingers", "Dedos rápidos", True),
    (B, "beekeeper_log_herb_quick_fingers_fmt",
     "Story log, a herb rolled Quick Fingers; %@ = how strong clicks are in percent (300), %@ = seconds it burns",
     "Your fingers feel light and quick. Clicking is %@% as effective for %@ seconds.",
     "Tus dedos se sienten ligeros y rápidos. Hacer clic es un %@% más eficaz durante %@ segundos.", True),
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
