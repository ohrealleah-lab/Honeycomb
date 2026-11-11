"""Beekeeper (Bee, 2026-11-11): the beeswax candle is gone (the herbal candle replaced it). Its words
stay in the workbook marked unused, and the Workbench Help no longer mentions it. Run once from the
repo root, then run generate_localization.py. Safe to re-run."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

UNUSED = "[unused since 2026-11-11: the beeswax candle was replaced by the herbal candle]"
CUT = [
    "beekeeper_hive_beeswax_candles",
    "beekeeper_beeswax_candle",
    "beekeeper_beeswax_blurb",
    "beekeeper_log_first_beeswax_candle",
    "beekeeper_log_crafted_beeswax_fmt",
]

# key: [(old English, new English), (old Spanish, new Spanish)]
REPLACE = {
    "help_beekeeper_workbench": [
        ("Make a beeswax candle from 10 wax, or, once the bear has given you herbs, an herbal candle (10 wax + 1 herb).",
         "Once the bear has given you herbs, make herbal candles (10 wax + 1 herb)."),
        ("Haz una vela de cera de abeja con 10 de cera o, cuando el oso te haya dado hierbas, una vela de hierbas (10 de cera + 1 hierba).",
         "Cuando el oso te haya dado hierbas, haz velas de hierbas (10 de cera + 1 hierba)."),
    ],
}


def main() -> None:
    wb = openpyxl.load_workbook(PATH)
    ws = wb.worksheets[0]
    rows = {str(r[1].value).strip(): r for r in ws.iter_rows(min_row=2) if r[1].value}
    for key in CUT:
        r = rows[key]
        if not str(r[2].value or "").startswith("[unused"):
            r[2].value = UNUSED + " " + str(r[2].value or "")
    for key, ((en_old, en_new), (es_old, es_new)) in REPLACE.items():
        r = rows[key]
        en, es = str(r[3].value), str(r[4].value)
        if en_old not in en and en_new not in en: raise SystemExit(f"{key}: English text not found")
        if es_old not in es and es_new not in es: raise SystemExit(f"{key}: Spanish text not found")
        r[3].value, r[4].value = en.replace(en_old, en_new), es.replace(es_old, es_new)
    wb.save(PATH)
    print(f"marked {len(CUT)} unused, updated {len(REPLACE)}")


if __name__ == "__main__":
    main()
