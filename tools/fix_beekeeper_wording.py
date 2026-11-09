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
    # Spanish wording that read badly (review finding 12)
    "beekeeper_log_comb_built_fmt": "Un panal nuevo. Ahora caben %@ más de miel.",
    "beekeeper_group_crafts": "Velas",
    "beekeeper_queen_laying": "poniendo huevos",
    "beekeeper_honey_per_sec_fmt": "%@ de miel / s",
    "beekeeper_wax_per_sec_fmt": "%@ de cera / s",
    # Review finding 16: numbers come from the config, so the words take a %@
    "beekeeper_sell_hint": "%@ de miel = 1 Beebit",
    "beekeeper_hippies_rate": "%@ velas de cera = 1 de salvia",
    "beekeeper_upgrade_bigger_combs_1_blurb": "+%@% de espacio para miel",
    "beekeeper_upgrade_bigger_combs_2_blurb": "+%@% de espacio para miel",
    "beekeeper_upgrade_better_wax_catcher_blurb": "El colector da un %@% más de cera",
    "beekeeper_upgrade_stronger_candles_blurb": "Las velas repelentes duran un %@% más",
    "beekeeper_upgrade_practice_blurb": "+%@% de abejas por clic",
    "beekeeper_upgrade_more_practice_blurb": "+%@% de abejas por clic",
    "beekeeper_upgrade_propolis_seal_blurb": "Los panales guardan un %@% más de miel",
}

UPDATE_EN = {  # key: English
    "beekeeper_sell_hint": "%@ honey = 1 Beebit",
    "beekeeper_hippies_rate": "%@ beeswax candles = 1 sage",
    "beekeeper_upgrade_bigger_combs_1_blurb": "+%@% honey storage",
    "beekeeper_upgrade_bigger_combs_2_blurb": "+%@% honey storage",
    "beekeeper_upgrade_better_wax_catcher_blurb": "%@% more wax from the catcher",
    "beekeeper_upgrade_stronger_candles_blurb": "Repellent candles burn %@% longer",
    "beekeeper_upgrade_practice_blurb": "+%@% bees per click",
    "beekeeper_upgrade_more_practice_blurb": "+%@% bees per click",
    "beekeeper_upgrade_propolis_seal_blurb": "The combs hold %@% more honey",
}

REPLACE_IN = {  # key: (old, new) inside the Spanish text
    "help_beekeeper_queen": ("Tras 100 intercambios", "Tras 100 tratos"),
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
for key, en in UPDATE_EN.items():
    rows[key][3].value = en
for key, (old, new) in REPLACE_IN.items():
    assert old in rows[key][4].value or new in rows[key][4].value
    rows[key][4].value = rows[key][4].value.replace(old, new)
for sec, key, ctx, en, es, tr in NEW:
    if key in rows:
        r = rows[key]
        r[2].value, r[3].value, r[4].value, r[5].value = ctx, en, es, tr
    else:
        ws.append([sec, key, ctx, en, es, tr])
wb.save(PATH)
print("done")
