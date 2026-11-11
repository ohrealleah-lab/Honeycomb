"""Beekeeper Bee Herbs (Bee, 2026-11-10): adds the herb words to the localization workbook.
Run once from the repo root, then run generate_localization.py. Safe to re-run: rows whose key
already exists are updated in place."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    # --- the Shop row
    (B, "beekeeper_bee_herbs", "Shop: Bee Herbs, bought again and again; lighting one rolls one buff",
     "Bee Herbs", "Hierbas para abejas", True),
    (B, "beekeeper_bee_herbs_blurb_fmt", "Shop, under Bee Herbs; %@ = how many you have, %@ = how long one burns (\"5 minutes\")",
     "You have %@ · Light one and see how the bees feel. Burns %@ of play.",
     "Tienes %@ · Enciende una y mira cómo se sienten las abejas. Arde %@ de juego.", True),
    (B, "beekeeper_light_bee_herb", "Shop button: light one Bee Herb",
     "Light a herb", "Encender una hierba", True),
    (B, "beekeeper_herb_burning_fmt", "Shop, under Bee Herbs while one burns; %@ = the buff's name, %@ = time left",
     "%@: burning, %@ left", "%@: encendida, tiempo restante: %@", True),

    # --- the buffs' names
    (B, "beekeeper_herb_busy_bees", "Bee Herb buff: more honey", "Busy Bees", "Abejas atareadas", True),
    (B, "beekeeper_herb_wax", "Bee Herb buff: more wax", "Wax Makers", "Cereras", True),
    (B, "beekeeper_herb_trades", "Bee Herb buff: more from trades", "Good Deals", "Buenos tratos", True),
    (B, "beekeeper_herb_wanderers", "Bee Herb buff: stray bees fly in", "Wanderers", "Errantes", True),
    (B, "beekeeper_herb_lingering_smoke", "Bee Herb buff: Smoker clicks last longer",
     "Lingering Smoke", "Humo persistente", True),

    # --- the story log
    (B, "beekeeper_log_herb_busy_bees_fmt", "Story log, a herb rolled Busy Bees; %@ = extra honey in percent",
     "Something is in the air, the bees are happy. Increased honey production (+%@%).",
     "Algo flota en el aire, las abejas están felices. Más producción de miel (+%@%).", True),
    (B, "beekeeper_log_herb_wax_fmt", "Story log, a herb rolled Wax Makers; %@ = extra wax in percent",
     "A warm, sweet smoke drifts over the combs. The bees make more wax (+%@%).",
     "Un humo cálido y dulce pasa sobre los panales. Las abejas hacen más cera (+%@%).", True),
    (B, "beekeeper_log_herb_trades_fmt", "Story log, a herb rolled Good Deals; %@ = extra from trades in percent",
     "The smoke smells like a good bargain. Traders give %@% more.",
     "El humo huele a buen trato. Los comerciantes dan un %@% más.", True),
    (B, "beekeeper_log_herb_wanderers", "Story log, a herb rolled Wanderers",
     "The scent drifts far. Stray bees come to see what's going on.",
     "El aroma llega lejos. Abejas sueltas vienen a ver qué pasa.", True),
    (B, "beekeeper_log_herb_lingering_smoke_fmt", "Story log, a herb rolled Lingering Smoke; %@ = seconds a Smoker click lasts",
     "The smoke hangs low and lazy. Each puff of the Smoker lasts %@ seconds.",
     "El humo se queda bajo y perezoso. Cada bocanada del ahumador dura %@ segundos.", True),
    (B, "beekeeper_log_herb_dud", "Story log, a herb rolled nothing (rare)",
     "The herbs smolder and fizzle. The bees don't seem to notice.",
     "Las hierbas humean y se apagan. Las abejas ni se enteran.", True),
    (B, "beekeeper_log_herb_out", "Story log, a lit herb has burned out",
     "The herbs burn down to ash.", "Las hierbas se consumen hasta la ceniza.", True),
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
