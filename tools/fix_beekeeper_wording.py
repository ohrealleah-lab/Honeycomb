"""Beekeeper wording fixes: Spanish time lines that don't depend on singular or plural ("quedan"
disagreed with "aproximadamente 1 hora"), and singular forms for the pantry hover and two
welcome-back lines. Run once from the repo root, then run generate_localization.py. Safe to
re-run: existing keys are updated in place."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"
B = "Beekeeper"

UPDATE = {  # key: Spanish
    "beekeeper_garden_bed_growing_fmt": "%@: creciendo, tiempo restante: %@",
    "beekeeper_bee_boost_burning_fmt": "Impulso: encendida, tiempo restante: %@",
    "beekeeper_sage_propolis_burning_fmt": "Salvia y propóleo: encendida, tiempo restante: %@",
}

NEW = [
    (B, "beekeeper_pantry_minute", "Hover on Bee bread, second line; a minute or less",
     "The pantry lasts about 1 minute.", "La despensa dura aproximadamente 1 minuto.", True),
    (B, "beekeeper_log_welcome_back_queen_one", "Story log on reopening the app; exactly 1 bee raised",
     "The queen raised 1 bee.", "La reina crió 1 abeja.", True),
    (B, "beekeeper_log_welcome_back_bear_one_fmt", "Story log on reopening the app; %@ = bear name; exactly 1 Beebit",
     "%@ came by and left 1 Beebit for the extra honey.", "%@ pasó y dejó 1 Beebit por la miel que sobraba.", True),
]

wb = openpyxl.load_workbook(PATH)
ws = wb.worksheets[0]
rows = {str(r[1].value).strip(): r for r in ws.iter_rows(min_row=2) if r[1].value}
for key, es in UPDATE.items():
    rows[key][4].value = es
for sec, key, ctx, en, es, tr in NEW:
    if key in rows:
        r = rows[key]
        r[2].value, r[3].value, r[4].value, r[5].value = ctx, en, es, tr
    else:
        ws.append([sec, key, ctx, en, es, tr])
wb.save(PATH)
print("done")
