"""Beekeeper stage 7.5 (spec 016, combs, bees as currency): adds the new words to the localization
workbook and rewrites the ones that said bees make honey. Run once from the repo root, then run
generate_localization.py. Safe to re-run: rows whose key already exists are updated in place.

Words that stage 7.5 cuts stay in the workbook (Bee's comment-out rule) with an "[unused since
stage 7.5 ...]" context, so they are easy to bring back. Numbers in the Help text are the
BeekeeperConfig placeholders at build time (2026-11-09)."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    # --- the Hive card
    (B, "beekeeper_wax_full", "Hive card, when wax storage is full (stage 7.5)",
     "There's no more room for wax", "No queda sitio para la cera", True),

    # --- prices and walls (a price above a cap)
    (B, "beekeeper_cost_bees_fmt", "Price part; %@ = how many free bees (they move into the comb)",
     "%@ bees", "%@ abejas", True),
    (B, "beekeeper_wall_wax_fmt", "Beside a price whose wax is more than the hive can hold; %@ = the wax cap",
     "Needs more wax storage (holds %@)", "Necesita más espacio para cera (caben %@)", True),
    (B, "beekeeper_wall_honey_fmt", "Beside a price whose honey is more than the hive can hold; %@ = the honey cap",
     "Needs more honey storage (holds %@)", "Necesita más espacio para miel (caben %@)", True),
    (B, "beekeeper_wall_wax_tip", "Hover on a button held back by the wax cap",
     "A Wax Tray, a new comb or a Technology makes more room.",
     "Una bandeja de cera, un panal nuevo o una tecnología dan más espacio.", True),
    (B, "beekeeper_wall_honey_tip", "Hover on a button held back by the honey cap",
     "A Honey Super, a new comb or a Technology makes more room.",
     "Un alza de miel, un panal nuevo o una tecnología dan más espacio.", True),

    # --- capacity upgrades (The Workbench, bought again and again)
    (B, "beekeeper_honey_super", "The Workbench: a capacity upgrade (a real beekeeping word: a box stacked on the hive)",
     "Honey Super", "Alza de miel", True),
    (B, "beekeeper_honey_super_blurb_fmt", "The Workbench; %@ = honey room it adds, %@ = how many owned",
     "+%@ honey room · owned: %@", "+%@ de espacio para miel · tienes: %@", True),
    (B, "beekeeper_wax_tray", "The Workbench: a capacity upgrade", "Wax Tray", "Bandeja de cera", True),
    (B, "beekeeper_wax_tray_blurb_fmt", "The Workbench; %@ = wax room it adds, %@ = how many owned",
     "+%@ wax room · owned: %@", "+%@ de espacio para cera · tienes: %@", True),
    (B, "beekeeper_add", "Button: buy one more capacity upgrade", "Add", "Añadir", True),

    # --- story log
    (B, "beekeeper_log_wax_full", "Story log", "There's no more room for wax.", "No queda sitio para más cera.", True),
    (B, "beekeeper_log_first_wall", "Story log, once: the first price that is more than the hive can hold",
     "This needs more wax than the hive can hold. Time to make room.",
     "Esto necesita más cera de la que cabe en la colmena. Hay que hacer sitio.", True),
    (B, "beekeeper_log_honey_super_bought", "Story log", "You stack a honey super on top. More room for honey.",
     "Colocas un alza de miel encima. Más espacio para la miel.", True),
    (B, "beekeeper_log_wax_tray_bought", "Story log", "You slide in another wax tray.", "Metes otra bandeja de cera.", True),
]

# Existing rows to change: key -> (English, Spanish, context); None keeps what is there.
UNUSED = "[unused since stage 7.5 (spec 016): {}; kept so it can come back]"
UPDATE = {
    "beekeeper_hive_bees": ("Free bees", "Abejas libres",
                            "Hive card row label (Bees group): free bees, the ones not living in a comb"),
    "beekeeper_comb_blurb_fmt": ("+%@ honey a second, room for %@ honey and %@ wax",
                                 "+%@ de miel por segundo, espacio para %@ de miel y %@ de cera",
                                 "Workbench comb row; %@ = honey a second it adds, %@ = honey room, %@ = wax room"),
    "beekeeper_log_combs_available": ("The wax is gathering. Enough of it makes a comb.",
                                      "La cera se va juntando. Con suficiente se hace un panal.", None),
    "beekeeper_log_comb_built_fmt": ("A new comb. %@ bees move in.", "Un panal nuevo. Se mudan %@ abejas.",
                                     "Story log; %@ = bees that moved into the comb"),
    "beekeeper_log_welcome_back_fmt": ("While you were away, the combs filled with %@ honey.",
                                       "Mientras no estabas, los panales se llenaron con %@ de miel.",
                                       "Story log on reopening the app; %@ = honey the combs made while away"),
    "beekeeper_wooden_hive_blurb_fmt": ("The combs make %@% more honey.", "Los panales hacen un %@% más de miel.", None),
    "beekeeper_upgrade_smoker_blurb": ("With calm bees, the combs make double honey",
                                       "Con las abejas tranquilas, los panales hacen el doble de miel", None),
    "beekeeper_upgrade_bigger_combs_1_blurb": ("+%@% honey and wax storage", "+%@% de espacio para miel y cera", None),
    "beekeeper_upgrade_bigger_combs_2_blurb": ("+%@% honey and wax storage", "+%@% de espacio para miel y cera", None),
    "beekeeper_upgrade_propolis_seal_blurb": ("The combs hold %@% more honey and wax",
                                              "Los panales guardan un %@% más de miel y cera", None),
    "beekeeper_agreement_line": ("Trade agreement: a better price for honey.",
                                 "Acuerdo comercial: un mejor precio por la miel.", None),
    "beekeeper_log_trade_agreement_fmt": ("%@ offers a trade agreement: from now on, he pays more for your honey.",
                                          "%@ te ofrece un acuerdo comercial: a partir de ahora, paga más por tu miel.", None),
    "beekeeper_sell_hint": (None, None, "Under the bear's buttons; %@ = honey in one bundle right now (10, or 8 under the trade agreement)"),

    # Cut words stay, marked unused.
    "beekeeper_log_welcome_back_bear_fmt": (None, None, UNUSED.format("the bear no longer sells honey while you are away")),
    "beekeeper_log_welcome_back_bear_one_fmt": (None, None, UNUSED.format("the bear no longer sells honey while you are away")),
    "beekeeper_beebits_per_sec_fmt": (None, None, UNUSED.format("the agreement's rate hover is cut")),
    "beekeeper_log_old_counts_settle": (None, None, UNUSED.format("saves older than version 8 start a new game")),

    # --- Help
    "help_beekeeper_objective": (
        "Catch bees and look after a hive. The combs make honey, and the bees you haven't settled in a comb gather wax. "
        "Bees and wax build new combs, and a friendly bear trades Beebits for your honey. There is no score and no end: "
        "the hive simply grows at its own pace.",
        "Atrapa abejas y cuida de una colmena. Los panales hacen miel, y las abejas que aún no viven en un panal recogen cera. "
        "Con abejas y cera se construyen panales nuevos, y un oso amistoso te da Beebits a cambio de tu miel. No hay puntuación "
        "ni final: la colmena simplemente crece a su ritmo.",
        None),
    "help_beekeeper_how_to_play": (
        "1. Catch Bee: each click catches free bees. With bare hands, a bee sometimes stings you and gets away.\n"
        "2. Honey: you start with one comb. Once you catch your first bee, every comb makes 0.2 honey a second, however many bees there are. When the combs are full, honey simply stops until you make room.\n"
        "3. Wax: a little wax gathers from the start, and every free bee adds a little more. Wax has its own, small store; when it's full, wax stops too.\n"
        "4. The Bear: once you hold 10 honey, a bear comes by. Trade 10 honey for 1 Beebit, or Trade all.\n"
        "5. The Shop: spend Beebits on better tools (each catches more bees, and none of them sting) and on the Wax-Catcher (twice the wax). Tools are bought in order.\n"
        "6. Combs: a new comb costs bees and wax, starting at 20 bees and 10 wax; the bees move in and stop being free bees. Each comb makes more honey and adds room for 300 honey and 2 wax, and each new comb costs a little more.\n"
        "7. Room: when a price needs more wax than the hive can hold, it says so. Honey Supers and Wax Trays at The Workbench, new combs and the storage upgrades in the Shop all make more room.",
        "1. Atrapar abeja: cada clic atrapa abejas libres. A mano limpia, a veces una abeja te pica y se escapa.\n"
        "2. Miel: empiezas con un panal. En cuanto atrapas tu primera abeja, cada panal hace 0,2 de miel por segundo, haya las abejas que haya. Cuando los panales están llenos, la miel simplemente se detiene hasta que hagas sitio.\n"
        "3. Cera: desde el principio se junta un poco de cera, y cada abeja libre añade un poco más. La cera tiene su propio espacio, pequeño; cuando está lleno, la cera también se detiene.\n"
        "4. El oso: cuando tienes 10 de miel, aparece un oso. Cambia 10 de miel por 1 Beebit, o cámbialo todo.\n"
        "5. La tienda: gasta Beebits en mejores herramientas (cada una atrapa más abejas y ninguna pica) y en el colector de cera (el doble de cera). Las herramientas se compran en orden.\n"
        "6. Panales: un panal nuevo cuesta abejas y cera, empezando por 20 abejas y 10 de cera; las abejas se mudan a él y dejan de ser libres. Cada panal hace más miel y añade espacio para 300 de miel y 2 de cera, y cada panal nuevo cuesta un poco más.\n"
        "7. Espacio: cuando un precio necesita más cera de la que cabe en la colmena, lo dice. Las alzas de miel y las bandejas de cera del banco de trabajo, los panales nuevos y las mejoras de espacio de la tienda dan más sitio.",
        None),
    "help_beekeeper_away": (
        "The hive keeps working while you play another game, and even while Honeycomb is closed, for up to 3 days. "
        "When the combs are full, no more honey is stored until you make room, and wax stops at its own store too, so more room means more to come back to. "
        "Nothing is sold while you're away. Your hive is saved automatically. New Game starts a brand-new hive, and asks first once you've caught your first bee.",
        "La colmena sigue trabajando mientras juegas a otro juego, e incluso con Honeycomb cerrado, hasta 3 días. "
        "Cuando los panales están llenos, no se guarda más miel hasta que hagas sitio, y la cera también se detiene al llenarse su espacio, así que más espacio significa más al volver. "
        "No se vende nada mientras no estás. Tu colmena se guarda sola. Nueva Partida empieza una colmena nueva, y antes te pregunta en cuanto hayas atrapado tu primera abeja.",
        None),
    "help_beekeeper_workbench": (
        "At your 3rd comb, The Workbench opens. Make a beeswax candle from 10 wax. Once you've made 5 candles, the Hippies arrive: they give 1 sage for every 10 beeswax candles. Your first sage unlocks the sage repellent candle (10 wax + 1 sage).\n\n"
        "Once the Shop is open, The Workbench also sells Honey Supers (+1,000 honey room) and Wax Trays (+8 wax room) for Beebits. You can buy them again and again; each costs a little more than the last.\n\n"
        "Wasps start to come by too, but only while you're playing Beekeeper. When one arrives you have a minute to throw a shoe (it misses 4 times in 10), bribe it with a quarter of your honey, or light a repellent candle (no wasps for 15 minutes of play). If the wasp gets through, it helps itself to some honey. Bribe enough wasps and the wasp nest sends an emissary: the raids stop for good, repellent candles are no longer needed, and the wasps trade paper for honey (50 honey a sheet).\n\n"
        "Once the poplar has sprouted, two more candles join The Workbench, made with propolis. The bee-boost candle makes the combs make more honey for a while, but only while you play. The sage-propolis candle adds a little more honey for hours and keeps burning while the app is closed.\n\n"
        "Once The Workbench is open, the Beekeeper's Shop also sells upgrades: bigger combs (more room for honey and wax), a better Wax-Catcher, stronger candles, and later a Third Bed, the Notebook and the Propolis Seal (more room for honey and wax). Bought upgrades leave the Shop.",
        "En tu 3.er panal se abre el banco de trabajo. Haz una vela de cera de abeja con 10 de cera. Cuando hayas hecho 5 velas llegan los hippies: dan 1 de salvia por cada 10 velas de cera. Tu primera salvia desbloquea la vela repelente de salvia (10 de cera + 1 de salvia).\n\n"
        "Con la tienda abierta, el banco de trabajo también vende alzas de miel (+1000 de espacio para miel) y bandejas de cera (+8 de espacio para cera) a cambio de Beebits. Puedes comprarlas una y otra vez; cada una cuesta un poco más que la anterior.\n\n"
        "También empiezan a venir avispas, pero solo mientras juegas a Beekeeper. Cuando llega una tienes un minuto para lanzarle un zapato (falla 4 de cada 10 veces), sobornarla con una cuarta parte de tu miel o encender una vela repelente (sin avispas durante 15 minutos de juego). Si la avispa lo consigue, se sirve algo de miel. Si sobornas a suficientes avispas, el avispero envía un emisario: los asaltos se acaban para siempre, las velas repelentes ya no hacen falta y las avispas te cambian papel por miel (50 de miel por hoja).\n\n"
        "Cuando el álamo ha brotado, se añaden dos velas más al banco de trabajo, hechas con propóleo. Con la vela de impulso los panales hacen más miel durante un rato, pero solo mientras juegas. La vela de salvia y propóleo añade un poco más de miel durante horas y sigue ardiendo con la aplicación cerrada.\n\n"
        "Con el banco de trabajo abierto, la tienda del apicultor también vende mejoras: panales más grandes (más espacio para miel y cera), un mejor colector de cera, velas más fuertes y, más adelante, un tercer bancal, el cuaderno y el sello de propóleo (más espacio para miel y cera). Las mejoras compradas desaparecen de la tienda.",
        None),
    "help_beekeeper_garden": (
        "The Hippies and the wasps sometimes give you a seed, and you can see what kind it is. Plant it in a free bed (you have two beds, so two seeds can grow at once; the Shop sells a third) and wait: each plant takes its own time to sprout, even while the app is closed, and gives your hive a specialty.\n\n"
        "Wildflowers and clover give foraging: a steady 3 pollen a minute each. Pollen and honey make bee bread at The Workbench, and bee bread plus wax pays for moving your bees into a wooden hive, where the combs make more honey. A bramble gives guarding: the combs make 25% more honey. The willow (about an hour) gives nursing: the queen lays 50% faster, and eats bee bread faster too. The poplar (about 6 hours, a seed from the wasps once you trade with them) gives resin: the bees gather propolis, which goes into candles and the Propolis Seal. Clover takes about 12 hours.\n\n"
        "Paper from the wasps buys the Beekeeper's Notebook, with a note about each thing your hive can do, and a Third Bed.",
        "Los hippies y las avispas a veces te dan una semilla, y puedes ver de qué es. Plántala en un bancal libre (tienes dos bancales, así que pueden crecer dos semillas a la vez; la tienda vende un tercero) y espera: cada planta tarda su tiempo en brotar, incluso con la aplicación cerrada, y le da a tu colmena una especialidad.\n\n"
        "Las flores silvestres y el trébol dan recolección: 3 de polen por minuto cada una. El polen y la miel hacen pan de abejas en el banco de trabajo, y el pan de abejas junto con cera sirve para mudar a tus abejas a una colmena de madera, donde los panales hacen más miel. Una zarzamora da guardia: los panales hacen un 25% más de miel. El sauce (cerca de una hora) da crianza: la reina pone un 50% más rápido y también come más pan de abejas. El álamo (unas 6 horas, una semilla de las avispas cuando comercias con ellas) da resina: las abejas recogen propóleo, que se usa en velas y en el sello de propóleo. El trébol tarda unas 12 horas.\n\n"
        "El papel de las avispas compra el cuaderno del apicultor, con una nota sobre cada cosa que sabe hacer tu colmena, y un tercer bancal.",
        None),
    "help_beekeeper_smoker": (
        "After the Bee-Safe Vacuum, the Shop sells more tools (Bee Lure, Flower Cart, Hive Whistle) and Practice upgrades that make every click catch more. Every catch also brings in a small slice of your free bees (0.1%), so a big swarm of free bees grows faster (up to 10 times what your tool catches).\n\n"
        "The Smoker, also in the Shop, fills a little with every click. When it's full, press Puff the Smoker: for 2 minutes the bees are calm and the combs make double honey.",
        "Después de la aspiradora segura, la tienda vende más herramientas (señuelo para abejas, carro de flores, silbato de colmena) y mejoras de práctica que hacen que cada clic atrape más. Cada captura también trae una pequeña parte de tus abejas libres (el 0,1%), así que un gran enjambre de abejas libres crece más rápido (hasta 10 veces lo que atrapa tu herramienta).\n\n"
        "El ahumador, también en la tienda, se llena un poco con cada clic. Cuando esté lleno, pulsa Echar humo: durante 2 minutos las abejas están tranquilas y los panales hacen el doble de miel.",
        None),
    "help_beekeeper_queen": (
        "When your bees move into the wooden hive, the queen settles in and starts to lay: she raises 20 new free bees a minute, even while the app is closed. Every 100 bees she raises eat 1 bee bread, so keep the pantry stocked at The Workbench before you leave. When the bee bread runs out she simply rests until there is more; no bees are lost.\n\n"
        "After 25 trades, the bear offers a trade agreement: from then on he pays a better price, 8 honey for 1 Beebit instead of 10. He never takes honey on his own; when the combs are full, honey simply stops.",
        "Cuando tus abejas se mudan a la colmena de madera, la reina se instala y empieza a poner huevos: cría 20 abejas libres nuevas por minuto, incluso con la aplicación cerrada. Cada 100 abejas que cría comen 1 de pan de abejas, así que llena la despensa en el banco de trabajo antes de irte. Cuando se acaba el pan de abejas, simplemente descansa hasta que haya más; no se pierde ninguna abeja.\n\n"
        "Tras 25 tratos, el oso te ofrece un acuerdo comercial: a partir de entonces paga mejor, 8 de miel por 1 Beebit en vez de 10. Nunca se lleva miel por su cuenta; cuando los panales están llenos, la miel simplemente se detiene.",
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
