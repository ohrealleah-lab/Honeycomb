"""Beekeeper stage 9, the bloom calendar (spec 018, Bee 2026-11-11): adds its words to the
localization workbook. Run once from the repo root, then run generate_localization.py. Safe to
re-run: rows whose key already exists are updated in place. English is Bee's draft; Spanish is a draft."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    # Bloom names, lower case (the Garden line, "Next: …"); the hovers capitalise the first letter.
    (B, "beekeeper_bloom_crocus", "Bloom calendar: a flower's name, lower case", "crocus", "azafrán", True),
    (B, "beekeeper_bloom_clover", "Bloom calendar: a flower's name, lower case (the clover in bloom, not a seed)", "clover", "trébol", True),
    (B, "beekeeper_bloom_linden", "Bloom calendar: a flower's name, lower case", "linden", "tilo", True),
    (B, "beekeeper_bloom_goldenrod", "Bloom calendar: a flower's name, lower case", "goldenrod", "vara de oro", True),
    (B, "beekeeper_bloom_winter", "Bloom calendar: the half-day winter, lower case", "winter", "invierno", True),
    # With the article, for the welcome-back list ("the clover and the linden").
    (B, "beekeeper_bloom_the_crocus", "Welcome-back list item: a bloom with its article", "the crocus", "el azafrán", True),
    (B, "beekeeper_bloom_the_clover", "Welcome-back list item: a bloom with its article", "the clover", "el trébol", True),
    (B, "beekeeper_bloom_the_linden", "Welcome-back list item: a bloom with its article", "the linden", "el tilo", True),
    (B, "beekeeper_bloom_the_goldenrod", "Welcome-back list item: a bloom with its article", "the goldenrod", "la vara de oro", True),
    (B, "beekeeper_bloom_the_winter", "Welcome-back list item: winter with its article", "winter", "el invierno", True),

    # The Garden card's line.
    (B, "beekeeper_bloom_line_fmt", "Garden card; %@ = the bloom (lower case), %@ = time left (\"9 h\", \"40 min\")",
     "In bloom: %@ · %@ left", "En flor: %@ · quedan %@", True),
    (B, "beekeeper_bloom_winter_line_fmt", "Garden card in winter; %@ = time left (\"5 h\")",
     "Winter · %@ left", "Invierno · quedan %@", True),

    # The Garden line's hover: what the bloom favours, with or without that specialty, then what's next.
    (B, "beekeeper_bloom_tip_crocus", "Garden bloom hover, crocus, the hive has nursing (a willow)",
     "Crocus: the queen lays twice as fast as nursing alone would make her.",
     "Azafrán: la reina pone el doble de rápido de lo que la haría poner la crianza sola.", True),
    (B, "beekeeper_bloom_tip_crocus_none", "Garden bloom hover, crocus, no nursing yet",
     "Crocus favours nursing. A willow would help.", "El azafrán favorece la crianza. Un sauce ayudaría.", True),
    (B, "beekeeper_bloom_tip_clover", "Garden bloom hover, clover, the hive has foraging",
     "Clover: foraging brings in twice the pollen.", "Trébol: el forrajeo trae el doble de polen.", True),
    (B, "beekeeper_bloom_tip_clover_none", "Garden bloom hover, clover, no foraging yet",
     "Clover favours foraging. Wildflowers or clover would help.",
     "El trébol favorece el forrajeo. Unas flores silvestres o trébol ayudarían.", True),
    (B, "beekeeper_bloom_tip_linden_fmt", "Garden bloom hover, linden, the hive has guarding; %@ = guarding's extra honey now, in percent (50)",
     "Linden: the hive feels twice as safe (+%@% honey).", "Tilo: la colmena se siente el doble de segura (+%@% de miel).", True),
    (B, "beekeeper_bloom_tip_linden_none", "Garden bloom hover, linden, no guarding yet",
     "Linden favours guarding. A bramble would help.", "El tilo favorece la guardia. Una zarza ayudaría.", True),
    (B, "beekeeper_bloom_tip_goldenrod", "Garden bloom hover, goldenrod, the hive has resin",
     "Goldenrod: the bees gather twice the propolis.", "Vara de oro: las abejas recogen el doble de propóleo.", True),
    (B, "beekeeper_bloom_tip_goldenrod_none", "Garden bloom hover, goldenrod, no resin yet",
     "Goldenrod favours resin. A poplar would help.", "La vara de oro favorece la resina. Un álamo ayudaría.", True),
    (B, "beekeeper_bloom_tip_winter_fmt", "Garden bloom hover, winter; %@ = how much slower honey comes, in percent (25)",
     "Winter: honey comes %@% slower. Nothing is lost.", "Invierno: la miel llega un %@% más despacio. No se pierde nada.", True),
    (B, "beekeeper_bloom_tip_next_fmt", "Garden bloom hover, last line; %@ = the next bloom (lower case)",
     "Next: %@.", "Después: %@.", True),

    # Growth hovers (honey, pollen, propolis, the queen's laying).
    (B, "beekeeper_boost_bloom_fmt", "Growth hover; %@ = the bloom (capitalised), %@ = the specialty it favours, %@ = how much harder (2)",
     "%@ in bloom: %@ ×%@", "%@ en flor: %@ ×%@", True),
    (B, "beekeeper_boost_winter_fmt", "Honey hover in winter; %@ = the honey factor (0.75)",
     "Winter: ×%@", "Invierno: ×%@", True),

    # Story log, live.
    (B, "beekeeper_log_calendar_started", "Story log: the first plant starts the bloom calendar",
     "The crocuses are in bloom. A new flower will bloom each day.",
     "Los azafranes están en flor. Cada día florecerá una flor nueva.", True),
    (B, "beekeeper_log_bloom_crocus", "Story log: crocus again, after winter",
     "Spring again: the crocuses are in bloom.", "Otra vez primavera: los azafranes están en flor.", True),
    (B, "beekeeper_log_bloom_clover", "Story log: the clover bloom (not a seed or a new plant)",
     "The clover is in bloom.", "El trébol está en flor.", True),
    (B, "beekeeper_log_bloom_linden", "Story log", "The linden is in bloom.", "El tilo está en flor.", True),
    (B, "beekeeper_log_bloom_goldenrod", "Story log", "The goldenrod is in bloom.", "La vara de oro está en flor.", True),
    (B, "beekeeper_log_bloom_winter", "Story log: winter begins",
     "Winter. The bees cluster together to keep warm.", "Invierno. Las abejas se apiñan para darse calor.", True),

    # Story log on reopening the app: one line for every bloom change while away.
    (B, "beekeeper_log_welcome_back_bloom_one_fmt", "Story log on reopening the app, one bloom came out; %@ = the bloom with its article",
     "While you were away, %@ came into bloom.", "Mientras no estabas, floreció %@.", True),
    (B, "beekeeper_log_welcome_back_winter_one", "Story log on reopening the app, winter came",
     "While you were away, winter came.", "Mientras no estabas, llegó el invierno.", True),
    (B, "beekeeper_log_welcome_back_blooms_fmt", "Story log on reopening the app; %@ = the blooms that came and went, %@ = the bloom out now (with articles)",
     "While you were away, %@ bloomed. Now %@ is out.", "Mientras no estabas, florecieron %@. Ahora está en flor %@.", True),
    (B, "beekeeper_log_welcome_back_blooms_winter_fmt", "Story log on reopening the app, and it is winter now; %@ = the blooms that came and went",
     "While you were away, %@ bloomed. Now it's winter.", "Mientras no estabas, florecieron %@. Ahora es invierno.", True),
    (B, "beekeeper_log_welcome_back_seasons_fmt", "Story log on reopening the app, a winter among the blooms; %@ = what came and went, %@ = the bloom out now (with articles)",
     "While you were away, %@ came and went. Now %@ is out.", "Mientras no estabas, pasaron %@. Ahora está en flor %@.", True),
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
