"""Beekeeper story cards (Bee, 2026-11-11): gloves found, Smoker repaired. Adds/updates the words in the
localization workbook. Run once from the repo root, then run generate_localization.py. Safe to re-run."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"
B = "Beekeeper"

HOW_TO = {
 "en_old1": "1. Catch Bee: each click catches free bees. With bare hands, a bee sometimes stings you and gets away.",
 "en_new1": "1. Catch Bee: each click catches free bees. With bare hands, a bee sometimes stings you and gets away. Catch enough and you may find a pair of gloves.",
 "en_old5": "Spend Beebits on better tools (each catches more bees, and none of them sting) and on the Wax-Catcher (twice the wax). Tools are bought in order.",
 "en_new5": "Spend Beebits on better tools (each catches more bees, and none of them sting) and on the Wax-Catcher (twice the wax). Tools are bought in order, once you have the gloves.",
 "es_old1": "1. Atrapar abeja: cada clic atrapa abejas libres. A mano limpia, a veces una abeja te pica y se escapa.",
 "es_new1": "1. Atrapar abeja: cada clic atrapa abejas libres. A mano limpia, a veces una abeja te pica y se escapa. Si atrapas suficientes, puede que encuentres unos guantes.",
 "es_old5": "Las herramientas se compran en orden.",
 "es_new5": "Las herramientas se compran en orden, cuando ya tengas los guantes.",
}

NEW = [
    (B, "beekeeper_story_ouch", "Story card: the first sting (after 10 bees caught by hand)",
     "Ouch! A bee stung you.", "¡Ay! Una abeja te picó.", True),
    (B, "beekeeper_story_gloves", "Story card: the gloves are found (after 100 bees caught by hand)",
     "You find a pair of gloves on the ground. Put them on?",
     "Encuentras un par de guantes en el suelo. ¿Te los pones?", True),
    (B, "beekeeper_story_no", "Story card button: leave the gloves (No)", "No", "No", False),
    (B, "beekeeper_log_gloves_gone", "Story log, the 5th No to the gloves: bare hands for good",
     "You're one tough cookie. Bare hands it is.",
     "Eres de piel dura. Seguirás con las manos desnudas.", True),
    (B, "beekeeper_story_smoker", "Story card: the old Smoker is found (at 250 bees in the hive)",
     "An old smoker lies in the grass, dented and clogged with soot.",
     "Un viejo ahumador yace en la hierba, abollado y lleno de hollín.", True),
    (B, "beekeeper_story_repair", "Story card button: repair the Smoker (free)", "Repair?", "¿Reparar?", True),
    (B, "beekeeper_log_smoker_repaired", "Story log, the Smoker is repaired",
     "Good as new. Each puff calms the hive.",
     "Como nuevo. Cada bocanada calma la colmena.", True),
]
UPDATE = {
    "beekeeper_log_gloves": ("Story log, the gloves go on",
        "Protective gloves. You can now catch two bees at a time.",
        "Guantes protectores. Ahora puedes atrapar dos abejas a la vez."),
    "help_beekeeper_smoker": None,
}

def main():
    wb = openpyxl.load_workbook(PATH)
    ws = wb.worksheets[0]
    rows = {str(r[1].value).strip(): r for r in ws.iter_rows(min_row=2) if r[1].value}
    for key, (ctx, en, es) in [(k, v) for k, v in UPDATE.items() if v]:
        r = rows[key]; r[2].value, r[3].value, r[4].value = ctx, en, es
    # Smoker help: found, not bought.
    r = rows["help_beekeeper_smoker"]
    r[3].value = r[3].value.replace("After the Bee-Safe Vacuum, the Shop sells more tools", "After the Bee-Safe Vacuum, the Shop sells more tools") \
        .replace("The Smoker, also in the Shop, adds", "The Smoker, an old one you find in the grass and repair for free, adds")
    r[4].value = r[4].value.replace("El ahumador, también en la tienda, añade", "El ahumador, uno viejo que encuentras en la hierba y reparas gratis, añade")
    r = rows["help_beekeeper_how_to_play"]
    r[3].value = r[3].value.replace("starting at 250 bees and 10 wax", "starting at 250 bees and 5 wax")
    r[4].value = r[4].value.replace("empezando por 250 abejas y 10 de cera", "empezando por 250 abejas y 5 de cera")
    r[3].value = r[3].value.replace(HOW_TO["en_old1"], HOW_TO["en_new1"]).replace(HOW_TO["en_old5"], HOW_TO["en_new5"])
    r[4].value = r[4].value.replace(HOW_TO["es_old1"], HOW_TO["es_new1"]).replace(HOW_TO["es_old5"], HOW_TO["es_new5"])
    added = 0
    for sec, key, ctx, en, es, tr in NEW:
        if key in rows:
            r = rows[key]; r[2].value, r[3].value, r[4].value, r[5].value = ctx, en, es, tr
        else:
            ws.append([sec, key, ctx, en, es, tr]); added += 1
    wb.save(PATH)
    print("added", added)

if __name__ == "__main__":
    main()
