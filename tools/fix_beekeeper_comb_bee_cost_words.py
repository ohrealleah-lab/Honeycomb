"""Beekeeper (Bee, 2026-11-11): the first comb costs 250 bees (was 20); the Help text says so.
Run once from the repo root, then run generate_localization.py. Safe to re-run."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

# key: [(old English, new English), (old Spanish, new Spanish)]
REPLACE = {
    "help_beekeeper_how_to_play": [
        ("starting at 20 bees and 10 wax", "starting at 250 bees and 10 wax"),
        ("empezando por 20 abejas y 10 de cera", "empezando por 250 abejas y 10 de cera"),
    ],
}


def main() -> None:
    wb = openpyxl.load_workbook(PATH)
    ws = wb.worksheets[0]
    rows = {str(r[1].value).strip(): r for r in ws.iter_rows(min_row=2) if r[1].value}
    for key, ((en_old, en_new), (es_old, es_new)) in REPLACE.items():
        r = rows[key]
        en, es = str(r[3].value), str(r[4].value)
        if en_old not in en and en_new not in en: raise SystemExit(f"{key}: English text not found")
        if es_old not in es and es_new not in es: raise SystemExit(f"{key}: Spanish text not found")
        r[3].value, r[4].value = en.replace(en_old, en_new), es.replace(es_old, es_new)
    wb.save(PATH)
    print("updated", len(REPLACE))


if __name__ == "__main__":
    main()
