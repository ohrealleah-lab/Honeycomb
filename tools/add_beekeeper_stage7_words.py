"""Beekeeper stage 7 (spec 015): adds the new words to the localization workbook and updates a few
old ones. Run once from the repo root, then run generate_localization.py. Safe to re-run: rows
whose key already exists are updated in place instead of added again."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    # --- the Hive card
    (B, "beekeeper_hive_propolis", "Hive card row label (Garden group)", "Propolis", "Propóleo", True),
    (B, "beekeeper_hive_bee_boost_candles", "Hive card row label (Crafts group)", "Bee-boost candles", "Velas de impulso", True),
    (B, "beekeeper_hive_sage_propolis_candles", "Hive card row label (Crafts group)", "Sage-propolis candles", "Velas de salvia y propóleo", True),
    (B, "beekeeper_specialty_nursing_fmt", "Hive card, Bees group; %@ = extra laying percent (keep the % after it)",
     "Nursing: the queen lays faster, +%@%", "Crianza: la reina pone más rápido, +%@%", True),
    (B, "beekeeper_specialty_resin_fmt", "Hive card, Bees group; %@ = propolis a minute",
     "Resin: %@ propolis a minute", "Resina: %@ de propóleo por minuto", True),
    (B, "beekeeper_bee_boost_burning_fmt", "Hive card, Crafts group; %@ = time left (a phrase like 'about 7 minutes')",
     "Bee-boost: burning, %@ left", "Impulso: encendida, quedan %@", True),
    (B, "beekeeper_sage_propolis_burning_fmt", "Hive card, Crafts group; %@ = time left (a phrase like 'about 3 hours')",
     "Sage-propolis: burning, %@ left", "Salvia y propóleo: encendida, quedan %@", True),
    (B, "beekeeper_propolis_per_sec_fmt", "Hover on Propolis; %@ = propolis gathered per second",
     "+%@ propolis / sec", "+%@ de propóleo / s", True),

    # --- time phrases (rough, for beds and candles)
    (B, "beekeeper_duration_minute", "A rough time: one minute", "about 1 minute", "aproximadamente 1 minuto", True),
    (B, "beekeeper_duration_minutes_fmt", "A rough time; %@ = whole minutes", "about %@ minutes", "aproximadamente %@ minutos", True),
    (B, "beekeeper_duration_hour", "A rough time: one hour", "about 1 hour", "aproximadamente 1 hora", True),
    (B, "beekeeper_duration_hours_fmt", "A rough time; %@ = whole hours", "about %@ hours", "aproximadamente %@ horas", True),

    # --- the Garden card
    (B, "beekeeper_garden_empty_bed", "Garden card: a bed with nothing growing", "An empty bed", "Un bancal vacío", True),
    (B, "beekeeper_garden_bed_growing_fmt", "Garden card; %@ = plant name, %@ = rough time left",
     "%@: growing, %@ left", "%@: creciendo, quedan %@", True),
    (B, "beekeeper_garden_seed_fmt", "Garden card: a seed in hand; %@ = the plant's seed name (lower case)",
     "%@ seed", "Semilla de %@", True),
    (B, "beekeeper_garden_takes_fmt", "Garden card: hover on the Plant button; %@ = rough grow time",
     "Takes %@ to grow.", "Tarda %@ en crecer.", True),


    # --- plants
    (B, "beekeeper_plant_willow", "Garden: a plant", "Willow", "Sauce", True),
    (B, "beekeeper_plant_willow_blurb", "Garden: what the plant's specialty does",
     "The nurse bees fuss over the brood, and the queen lays faster.", "Las nodrizas cuidan de la cría y la reina pone más rápido.", True),
    (B, "beekeeper_plant_poplar", "Garden: a plant", "Poplar", "Álamo", True),
    (B, "beekeeper_plant_poplar_blurb", "Garden: what the plant's specialty does",
     "The bees gather sticky propolis from its buds.", "Las abejas recogen propóleo pegajoso de sus yemas.", True),
    (B, "beekeeper_plant_clover", "Garden: a plant", "Clover", "Trébol", True),
    (B, "beekeeper_plant_clover_blurb", "Garden: what the plant's specialty does",
     "More flowers for the foragers: extra pollen.", "Más flores para las recolectoras: más polen.", True),
    (B, "beekeeper_specialty_nursing", "Garden card: the specialty a plant gives (lower case, after the plant's name)", "nursing", "crianza", True),
    (B, "beekeeper_specialty_resin", "Garden card: the specialty a plant gives (lower case, after the plant's name)", "resin", "resina", True),
    (B, "beekeeper_seed_name_wildflowers", "A seed's plant, lower case, used in 'a ... seed'", "wildflower", "flores silvestres", True),
    (B, "beekeeper_seed_name_bramble", "A seed's plant, lower case, used in 'a ... seed'", "bramble", "zarzamora", True),
    (B, "beekeeper_seed_name_willow", "A seed's plant, lower case, used in 'a ... seed'", "willow", "sauce", True),
    (B, "beekeeper_seed_name_poplar", "A seed's plant, lower case, used in 'a ... seed'", "poplar", "álamo", True),
    (B, "beekeeper_seed_name_clover", "A seed's plant, lower case, used in 'a ... seed'", "clover", "trébol", True),

    # --- prices
    (B, "beekeeper_cost_paper_fmt", "Price part; %@ = amount", "%@ paper", "%@ de papel", True),
    (B, "beekeeper_cost_propolis_fmt", "Price part; %@ = amount", "%@ propolis", "%@ de propóleo", True),

    # --- The Workbench
    (B, "beekeeper_bee_boost_candle", "Workbench: recipe name", "Bee-boost candle", "Vela de impulso", True),
    (B, "beekeeper_bee_boost_blurb_fmt", "Workbench: recipe description; %@ = extra honey percent (keep the % after it), %@ = time",
     "+%@% honey for %@ of play. Burns only while you play.", "+%@% de miel durante %@ de juego. Solo arde mientras juegas.", True),
    (B, "beekeeper_sage_propolis_candle", "Workbench: recipe name", "Sage-propolis candle", "Vela de salvia y propóleo", True),
    (B, "beekeeper_sage_propolis_blurb_fmt", "Workbench: recipe description; %@ = extra honey percent (keep the % after it), %@ = time",
     "+%@% honey for %@. Keeps burning while you're away.", "+%@% de miel durante %@. Sigue ardiendo mientras no estás.", True),
    (B, "beekeeper_light_bee_boost", "Workbench button: light a bee-boost candle", "Light a bee-boost candle", "Encender una vela de impulso", True),
    (B, "beekeeper_light_sage_propolis", "Workbench button: light a sage-propolis candle", "Light a sage-propolis candle", "Encender una vela de salvia y propóleo", True),

    # --- the Shop's new upgrades
    (B, "beekeeper_upgrade_notebook", "Shop upgrade name", "The Beekeeper's Notebook", "El cuaderno del apicultor", True),
    (B, "beekeeper_upgrade_notebook_blurb", "Shop upgrade description", "Notes on what your hive can do", "Notas sobre lo que sabe hacer tu colmena", True),
    (B, "beekeeper_upgrade_third_bed", "Shop upgrade name", "A Third Bed", "Un tercer bancal", True),
    (B, "beekeeper_upgrade_third_bed_blurb", "Shop upgrade description", "Three seeds can grow at once", "Pueden crecer tres semillas a la vez", True),
    (B, "beekeeper_upgrade_propolis_seal", "Shop upgrade name", "The Propolis Seal", "El sello de propóleo", True),
    (B, "beekeeper_upgrade_propolis_seal_blurb", "Shop upgrade description", "The combs hold 25% more honey", "Los panales guardan un 25% más de miel", True),

    # --- the Notebook (the Bees card)
    (B, "beekeeper_notebook_title", "Card title (all caps)", "THE BEEKEEPER'S NOTEBOOK", "EL CUADERNO DEL APICULTOR", True),
    (B, "beekeeper_note_queen", "Notebook note", "The queen: she can lay well over a thousand eggs a day in high summer.",
     "La reina: en pleno verano puede poner bastante más de mil huevos al día.", True),
    (B, "beekeeper_note_foraging", "Notebook note", "Foraging: a forager may visit a few thousand flowers in a day.",
     "Recolección: una recolectora puede visitar unos miles de flores en un día.", True),
    (B, "beekeeper_note_guarding", "Notebook note", "Guarding: guards at the entrance know their hive's smell and turn strangers away.",
     "Guardia: las guardianas de la entrada conocen el olor de su colmena y echan a los extraños.", True),
    (B, "beekeeper_note_nursing", "Notebook note", "Nursing: young bees feed the larvae, checking on each one many times a day.",
     "Crianza: las abejas jóvenes alimentan a las larvas y revisan a cada una muchas veces al día.", True),
    (B, "beekeeper_note_resin", "Notebook note", "Resin: propolis is tree resin mixed with wax; bees use it to seal and clean the hive.",
     "Resina: el propóleo es resina de árbol mezclada con cera; las abejas lo usan para sellar y limpiar la colmena.", True),

    # --- story log
    (B, "beekeeper_log_seed_given_fmt", "Story log; %@ = the plant's seed name (lower case)",
     "The Hippies press a %@ seed into your hand.", "Los hippies te ponen en la mano una semilla de %@.", True),
    (B, "beekeeper_log_wasp_seed_given_fmt", "Story log; %@ = the plant's seed name (lower case)",
     "The wasps leave a %@ seed on the hive roof. 'For the resin. You'll see.'",
     "Las avispas dejan una semilla de %@ en el techo de la colmena. «Para la resina. Ya verás.»", True),
    (B, "beekeeper_log_seed_planted_fmt", "Story log; %@ = the plant's seed name (lower case)",
     "You plant the %@ seed.", "Plantas la semilla de %@.", True),
    (B, "beekeeper_log_plant_willow_nursing", "Story log: the willow sprouts",
     "The willow catkins open. The nurse bees fuss over the brood.", "Se abren los amentos del sauce. Las nodrizas se afanan con la cría.", True),
    (B, "beekeeper_log_plant_poplar_resin", "Story log: the poplar sprouts",
     "The poplar's sticky buds catch the light. The bees start bringing home resin.",
     "Las yemas pegajosas del álamo brillan al sol. Las abejas empiezan a traer resina.", True),
    (B, "beekeeper_log_plant_clover_foraging", "Story log: clover sprouts",
     "Clover carpets the garden. The foragers hardly know where to start.",
     "El trébol alfombra el jardín. Las recolectoras no saben por dónde empezar.", True),
    (B, "beekeeper_log_first_propolis", "Story log: the first propolis",
     "The bees seal a crack with propolis, sticky and sweet-smelling.", "Las abejas sellan una grieta con propóleo, pegajoso y de dulce aroma.", True),
    (B, "beekeeper_log_bee_boost_lit", "Story log", "You light a bee-boost candle. The bees hum a little faster.",
     "Enciendes una vela de impulso. Las abejas zumban un poco más rápido.", True),
    (B, "beekeeper_log_bee_boost_out", "Story log", "The bee-boost candle gutters out.", "La vela de impulso se apaga.", True),
    (B, "beekeeper_log_sage_propolis_lit", "Story log", "You light a sage-propolis candle. It will burn for hours.",
     "Enciendes una vela de salvia y propóleo. Arderá durante horas.", True),
    (B, "beekeeper_log_sage_propolis_out", "Story log", "The sage-propolis candle burns down.", "La vela de salvia y propóleo se consume.", True),
    (B, "beekeeper_log_welcome_back_sage_out", "Story log on reopening the app",
     "The sage-propolis candle burned down while you were away.", "La vela de salvia y propóleo se consumió mientras no estabas.", True),
    (B, "beekeeper_log_welcome_back_propolis_fmt", "Story log on reopening the app; %@ = propolis gathered",
     "The bees gathered %@ propolis.", "Las abejas recogieron %@ de propóleo.", True),
    (B, "beekeeper_log_notebook_bought", "Story log", "You start a beekeeper's notebook.", "Empiezas un cuaderno de apicultor.", True),
    (B, "beekeeper_log_third_bed_bought", "Story log", "You dig a third garden bed.", "Cavas un tercer bancal en el jardín.", True),
    (B, "beekeeper_log_propolis_seal_bought", "Story log", "The bees seal the combs with propolis. They hold more now.",
     "Las abejas sellan los panales con propóleo. Ahora guardan más.", True),
    (B, "beekeeper_log_crafted_bee_boost_fmt", "Story log; %@ = how many", "You make %@ bee-boost candles.", "Haces %@ velas de impulso.", True),
    (B, "beekeeper_log_crafted_sage_propolis_fmt", "Story log; %@ = how many", "You make %@ sage-propolis candles.",
     "Haces %@ velas de salvia y propóleo.", True),
]

# Existing rows to change: key -> (English, Spanish) and/or new context
UPDATE = {
    "beekeeper_garden_plant": ("Plant", "Plantar", "Garden button: plant a seed"),
    "beekeeper_garden_growing": (None, None, "Garden: [unused since stage 7 (spec 015): beds name what grows; kept so it can come back]"),
    "help_beekeeper_garden": (
        "The Hippies and the wasps sometimes give you a seed, and you can see what kind it is. Plant it in a free bed (you have two beds, so two seeds can grow at once; the Shop sells a third) and wait: each plant takes its own time to sprout, even while the app is closed, and gives your hive a specialty.\n\n"
        "Wildflowers and clover give foraging: a steady 3 pollen a minute each. Pollen and honey make bee bread at The Workbench, and bee bread plus wax pays for moving your bees into a wooden hive, where every honeybee makes more honey. A bramble gives guarding: every honeybee makes 25% more honey. The willow (about an hour) gives nursing: the queen lays 50% faster, and eats bee bread faster too. The poplar (about 6 hours, a seed from the wasps once you trade with them) gives resin: the bees gather propolis, which goes into candles and the Propolis Seal. Clover takes about 12 hours.\n\n"
        "Paper from the wasps buys the Beekeeper's Notebook, with a note about each thing your hive can do, and a Third Bed.",
        "Los hippies y las avispas a veces te dan una semilla, y puedes ver de qué es. Plántala en un bancal libre (tienes dos bancales, así que pueden crecer dos semillas a la vez; la tienda vende un tercero) y espera: cada planta tarda su tiempo en brotar, incluso con la aplicación cerrada, y le da a tu colmena una especialidad.\n\n"
        "Las flores silvestres y el trébol dan recolección: 3 de polen por minuto cada una. El polen y la miel hacen pan de abejas en el banco de trabajo, y el pan de abejas junto con cera sirve para mudar a tus abejas a una colmena de madera, donde cada abeja melífera hace más miel. Una zarzamora da guardia: cada abeja melífera hace un 25% más de miel. El sauce (cerca de una hora) da crianza: la reina pone un 50% más rápido y también come más pan de abejas. El álamo (unas 6 horas, una semilla de las avispas cuando comercias con ellas) da resina: las abejas recogen propóleo, que se usa en velas y en el sello de propóleo. El trébol tarda unas 12 horas.\n\n"
        "El papel de las avispas compra el cuaderno del apicultor, con una nota sobre cada cosa que sabe hacer tu colmena, y un tercer bancal.",
        None),
    "help_beekeeper_workbench": (
        "After your 2nd comb, The Workbench opens. Make a beeswax candle from 10 wax. Once you've made 5 candles, the Hippies arrive: they give 1 sage for every 10 beeswax candles. Your first sage unlocks the sage repellent candle (10 wax + 1 sage).\n\n"
        "Wasps start to come by too, but only while you're playing Beekeeper. When one arrives you have a minute to throw a shoe (it misses 4 times in 10), bribe it with a quarter of your honey, or light a repellent candle (no wasps for 15 minutes of play). If the wasp gets through, it helps itself to some honey. Bribe enough wasps and the wasp nest sends an emissary: the raids stop for good, repellent candles are no longer needed, and the wasps trade paper for honey (50 honey a sheet).\n\n"
        "Once the poplar has sprouted, two more candles join The Workbench, made with propolis. The bee-boost candle makes more honey for a while, but only while you play. The sage-propolis candle makes a little more honey for hours and keeps burning while the app is closed.\n\n"
        "Once The Workbench is open, the Beekeeper's Shop also sells upgrades: bigger combs, a better Wax-Catcher, stronger candles, and later a Third Bed, the Notebook and the Propolis Seal. Bought upgrades leave the Shop.",
        "Tras tu 2.º panal se abre el banco de trabajo. Haz una vela de cera de abeja con 10 de cera. Cuando hayas hecho 5 velas llegan los hippies: dan 1 de salvia por cada 10 velas de cera. Tu primera salvia desbloquea la vela repelente de salvia (10 de cera + 1 de salvia).\n\n"
        "También empiezan a venir avispas, pero solo mientras juegas a Beekeeper. Cuando llega una tienes un minuto para lanzarle un zapato (falla 4 de cada 10 veces), sobornarla con una cuarta parte de tu miel o encender una vela repelente (sin avispas durante 15 minutos de juego). Si la avispa lo consigue, se sirve algo de miel. Si sobornas a suficientes avispas, el avispero envía un emisario: los asaltos se acaban para siempre, las velas repelentes ya no hacen falta y las avispas te cambian papel por miel (50 de miel por hoja).\n\n"
        "Cuando el álamo ha brotado, se añaden dos velas más al banco de trabajo, hechas con propóleo. La vela de impulso hace más miel durante un rato, pero solo mientras juegas. La vela de salvia y propóleo hace un poco más de miel durante horas y sigue ardiendo con la aplicación cerrada.\n\n"
        "Con el banco de trabajo abierto, la tienda del apicultor también vende mejoras: panales más grandes, un mejor colector de cera, velas más fuertes y, más adelante, un tercer bancal, el cuaderno y el sello de propóleo. Las mejoras compradas desaparecen de la tienda.",
        None),
}


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
    for key, (en, es, ctx) in UPDATE.items():
        r = rows[key]
        if en is not None: r[3].value = en
        if es is not None: r[4].value = es
        if ctx is not None: r[2].value = ctx
        updated += 1
    wb.save(PATH)
    print(f"added {added}, updated {updated}")


if __name__ == "__main__":
    main()
