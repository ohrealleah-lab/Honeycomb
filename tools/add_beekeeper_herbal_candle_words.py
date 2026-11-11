"""Beekeeper herbal candles (Bee, 2026-11-11): herbs replace sage, the bear trades herbs for honey,
the sage repellent candle becomes the herbal candle (lit for a random buff, sold to the Hippies for
Beebits), and the sage-propolis candle becomes the herb-propolis candle. Run once from the repo
root, then run generate_localization.py. Safe to re-run.

Words that this cuts stay in the workbook (Bee's comment-out rule) with an "[unused since ...]"
context, so they are easy to bring back. Numbers in the Help text are the BeekeeperConfig
placeholders at build time (2026-11-11)."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
NEW = [
    (B, "beekeeper_cost_herb_one", "Price part when it is exactly 1 herb",
     "1 herb", "1 hierba", True),
]

UNUSED = "[unused since 2026-11-11 (herbal candles): {}; kept so it can come back]"
CUT = {
    "beekeeper_bee_herbs": "the Shop's Bee Herbs row",
    "beekeeper_bee_herbs_blurb_fmt": "the Shop's Bee Herbs row",
    "beekeeper_light_bee_herb": "lighting a Bee Herb",
}

# key: (English, Spanish, context) - None leaves that cell as it is
UPDATE = {
    # --- trades
    "beekeeper_sell_hint": ("%@ honey = %@ herbs", "%@ de miel = %@ hierbas",
                            "Under the bear's buttons; %@ = honey in one trade (10, or 8 under the agreement), %@ = herbs"),
    "beekeeper_hippies_rate": ("1 herbal candle = %@ Beebits", "1 vela de hierbas = %@ Beebits",
                               "Under the Hippies' buttons; %@ = Beebits they pay for one herbal candle"),
    "beekeeper_log_trade_bear_fmt": ("You trade %@ %@ honey for %@ herbs.", "Le cambias a %@ %@ de miel por %@ hierbas.",
                                     "Story log; %@ = bear name, %@ = honey given, %@ = herbs got"),
    "beekeeper_log_trade_bear_one_fmt": ("You trade %@ %@ honey for 1 herb.", "Le cambias a %@ %@ de miel por 1 hierba.",
                                         "Story log; %@ = bear name, %@ = honey given"),
    "beekeeper_log_trade_hippies_fmt": ("You sell the Hippies %@ herbal candles for %@ Beebits.",
                                        "Les vendes a los hippies %@ velas de hierbas por %@ Beebits.",
                                        "Story log; %@ = herbal candles given, %@ = Beebits got"),
    "beekeeper_log_candles_traded_fmt": ("The Hippies hand over %@ Beebits.", "Los hippies te dan %@ Beebits.", None),
    "beekeeper_log_repellent_unlocked": ("Herbs and wax. That could make a nice candle.",
                                         "Hierbas y cera. Con eso se podría hacer una buena vela.",
                                         "Story log, the first herb from the bear opens the herbal candle"),
    "beekeeper_hive_sage": ("Herbs", "Hierbas", "Hive card row label: herbs (from the bear)"),
    "beekeeper_cost_sage_fmt": ("%@ herbs", "%@ hierbas", "Price part; %@ = how many herbs (more than 1)"),

    # --- the herbal candle (was the sage repellent candle)
    "beekeeper_repellent_candle": ("Herbal candle", "Vela de hierbas", "The Workbench: 10 wax + 1 herb"),
    "beekeeper_repellent_blurb_fmt": ("Light it and see how the bees feel. Burns %@ of play.",
                                      "Enciéndela y mira cómo se sienten las abejas. Arde %@ de juego.",
                                      "The Workbench, after the herbal candle's price; %@ = how long it burns"),
    "beekeeper_hive_repellent_candles": ("Herbal candles", "Velas de hierbas", None),
    "beekeeper_log_crafted_repellent_fmt": ("You make %@ herbal candles.", "Haces %@ velas de hierbas.", None),
    "beekeeper_upgrade_stronger_candles_blurb": ("Herbal candles burn %@% longer",
                                                 "Las velas de hierbas duran un %@% más", None),
    "beekeeper_log_herb_dud": ("The candle sputters and fizzles. The bees don't seem to notice.",
                               "La vela chisporrotea y se apaga. Las abejas ni se enteran.", None),
    "beekeeper_log_herb_out": ("The herbal candle burns down.", "La vela de hierbas se consume.", None),

    # --- the herb-propolis candle (was sage-propolis)
    "beekeeper_hive_sage_propolis_candles": ("Herb-propolis candles", "Velas de hierbas y propóleo", None),
    "beekeeper_sage_propolis_burning_fmt": ("Herb-propolis: burning, %@ left",
                                            "Hierbas y propóleo: encendida, tiempo restante: %@", None),
    "beekeeper_sage_propolis_candle": ("Herb-propolis candle", "Vela de hierbas y propóleo", None),
    "beekeeper_light_sage_propolis": ("Light a herb-propolis candle", "Encender una vela de hierbas y propóleo", None),
    "beekeeper_log_sage_propolis_lit": ("You light a herb-propolis candle. It will burn for hours.",
                                        "Enciendes una vela de hierbas y propóleo. Arderá durante horas.", None),
    "beekeeper_log_sage_propolis_out": ("The herb-propolis candle burns down.",
                                        "La vela de hierbas y propóleo se consume.", None),
    "beekeeper_log_welcome_back_sage_out": ("The herb-propolis candle burned down while you were away.",
                                            "La vela de hierbas y propóleo se consumió mientras no estabas.", None),
    "beekeeper_log_crafted_sage_propolis_fmt": ("You make %@ herb-propolis candles.",
                                                "Haces %@ velas de hierbas y propóleo.", None),

    # --- Help
    "help_beekeeper_objective": (
        "Catch bees and look after a hive. The combs make honey, and the bees you haven't settled in a comb gather wax. Bees and wax build new combs, a friendly bear trades herbs for your honey, and the Hippies buy your herbal candles. There is no score and no end: the hive simply grows at its own pace.",
        "Atrapa abejas y cuida de una colmena. Los panales hacen miel, y las abejas que aún no viven en un panal recogen cera. Con abejas y cera se construyen panales nuevos, un oso amistoso te da hierbas a cambio de tu miel y los hippies te compran las velas de hierbas. No hay puntuación ni final: la colmena simplemente crece a su ritmo.",
        None),
    "help_beekeeper_how_to_play": (
        "1. Catch Bee: each click catches free bees. With bare hands, a bee sometimes stings you and gets away.\n"
        "2. Honey: you start with one comb. Once you catch your first bee, every comb makes 0.2 honey a second, however many bees there are. When the combs are full, honey simply stops until you make room.\n"
        "3. Wax: a little wax gathers from the start, and every free bee adds a little more. Wax has its own, small store; when it's full, wax stops too.\n"
        "4. The Bear: once you hold 10 honey, a bear comes by. Trade 10 honey for 1 herb, or Trade all.\n"
        "5. The Shop: opens with your first Beebits (the Hippies pay them for herbal candles). Spend Beebits on better tools (each catches more bees, and none of them sting) and on the Wax-Catcher (twice the wax). Tools are bought in order.\n"
        "6. Combs: a new comb costs bees and wax, starting at 20 bees and 10 wax; the bees move in and stop being free bees. Each comb makes more honey and adds room for 300 honey and 2 wax, and each new comb costs a little more.\n"
        "7. Room: when a price needs more wax than the hive can hold, it says so. Honey Supers and Wax Trays at The Workbench, new combs and the storage upgrades in the Shop all make more room.",
        "1. Atrapar abeja: cada clic atrapa abejas libres. A mano limpia, a veces una abeja te pica y se escapa.\n"
        "2. Miel: empiezas con un panal. En cuanto atrapas tu primera abeja, cada panal hace 0,2 de miel por segundo, haya las abejas que haya. Cuando los panales están llenos, la miel simplemente se detiene hasta que hagas sitio.\n"
        "3. Cera: desde el principio se junta un poco de cera, y cada abeja libre añade un poco más. La cera tiene su propio espacio, pequeño; cuando está lleno, la cera también se detiene.\n"
        "4. El oso: cuando tienes 10 de miel, aparece un oso. Cambia 10 de miel por 1 hierba, o cámbialo todo.\n"
        "5. La tienda: abre con tus primeros Beebits (te los pagan los hippies por las velas de hierbas). Gasta Beebits en mejores herramientas (cada una atrapa más abejas y ninguna pica) y en el colector de cera (el doble de cera). Las herramientas se compran en orden.\n"
        "6. Panales: un panal nuevo cuesta abejas y cera, empezando por 20 abejas y 10 de cera; las abejas se mudan a él y dejan de ser libres. Cada panal hace más miel y añade espacio para 300 de miel y 2 de cera, y cada panal nuevo cuesta un poco más.\n"
        "7. Espacio: cuando un precio necesita más cera de la que cabe en la colmena, lo dice. Las alzas de miel y las bandejas de cera del banco de trabajo, los panales nuevos y las mejoras de espacio de la tienda dan más sitio.",
        None),
    "help_beekeeper_workbench": (
        "At your 3rd comb, The Workbench opens. Make a beeswax candle from 10 wax, or, once the bear has given you herbs, an herbal candle (10 wax + 1 herb). Once you've made 5 candles, the Hippies arrive: they buy herbal candles, 10 Beebits each.\n\n"
        "Light an herbal candle and see how the bees feel: each one brings one surprise for 5 minutes of play. The bees might make more honey or more wax, traders might give 50% more, stray bees might wander in, or each puff of the Smoker might last 30 seconds. Now and then a candle just fizzles. One burns at a time.\n\n"
        "Once the Shop is open, The Workbench also sells Honey Supers (+1,000 honey room) and Wax Trays (+10 wax room) for Beebits. You can buy them again and again; each costs a little more than the last.\n\n"
        "Wasps start to come by too, but only while you're playing Beekeeper. When one arrives you have a minute to throw a shoe (it misses 4 times in 10) or bribe it with a quarter of your honey. If the wasp gets through, it helps itself to some honey. Bribe enough wasps and the wasp nest sends an emissary: the raids stop for good, and the wasps trade paper for honey (50 honey a sheet).\n\n"
        "Once the poplar has sprouted, two more candles join The Workbench, made with propolis. The bee-boost candle makes the combs make more honey for a while, but only while you play. The herb-propolis candle adds a little more honey for hours and keeps burning while the app is closed.\n\n"
        "Once The Workbench is open, the Beekeeper's Shop also sells upgrades: bigger combs (more room for honey and wax), a better Wax-Catcher, stronger candles (herbal candles burn longer), and later the Notebook and the Propolis Seal (more room for honey and wax). Bought upgrades leave the Shop.",
        "En tu 3.er panal se abre el banco de trabajo. Haz una vela de cera de abeja con 10 de cera o, cuando el oso te haya dado hierbas, una vela de hierbas (10 de cera + 1 hierba). Cuando hayas hecho 5 velas llegan los hippies: compran velas de hierbas a 10 Beebits cada una.\n\n"
        "Enciende una vela de hierbas y mira cómo se sienten las abejas: cada una trae una sorpresa durante 5 minutos de juego. Puede que las abejas hagan más miel o más cera, que los comerciantes den un 50% más, que lleguen abejas sueltas o que cada bocanada del ahumador dure 30 segundos. De vez en cuando una vela simplemente se apaga. Arde una cada vez.\n\n"
        "Con la tienda abierta, el banco de trabajo también vende alzas de miel (+1000 de espacio para miel) y bandejas de cera (+10 de espacio para cera) a cambio de Beebits. Puedes comprarlas una y otra vez; cada una cuesta un poco más que la anterior.\n\n"
        "También empiezan a venir avispas, pero solo mientras juegas a Beekeeper. Cuando llega una tienes un minuto para lanzarle un zapato (falla 4 de cada 10 veces) o sobornarla con una cuarta parte de tu miel. Si la avispa lo consigue, se sirve algo de miel. Si sobornas a suficientes avispas, el avispero envía un emisario: los asaltos se acaban para siempre y las avispas te cambian papel por miel (50 de miel por hoja).\n\n"
        "Cuando el álamo ha brotado, se añaden dos velas más al banco de trabajo, hechas con propóleo. Con la vela de impulso los panales hacen más miel durante un rato, pero solo mientras juegas. La vela de hierbas y propóleo añade un poco más de miel durante horas y sigue ardiendo con la aplicación cerrada.\n\n"
        "Con el banco de trabajo abierto, la tienda del apicultor también vende mejoras: panales más grandes (más espacio para miel y cera), un mejor colector de cera, velas más fuertes (las velas de hierbas duran más) y, más adelante, el cuaderno y el sello de propóleo (más espacio para miel y cera). Las mejoras compradas desaparecen de la tienda.",
        None),
    "help_beekeeper_queen": (
        "When your bees move into the wooden hive, the queen settles in and starts to lay: she raises 20 new free bees a minute, even while the app is closed. Every 100 bees she raises eat 1 bee bread, so keep the pantry stocked at The Workbench before you leave. When the bee bread runs out she simply rests until there is more; no bees are lost.\n\n"
        "After 40 trades, the bear offers a trade agreement: from then on he pays a better price, 8 honey for 1 herb instead of 10. He never takes honey on his own; when the combs are full, honey simply stops.",
        "Cuando tus abejas se mudan a la colmena de madera, la reina se instala y empieza a poner huevos: cría 20 abejas libres nuevas por minuto, incluso con la aplicación cerrada. Cada 100 abejas que cría comen 1 de pan de abejas, así que llena la despensa en el banco de trabajo antes de irte. Cuando se acaba el pan de abejas, simplemente descansa hasta que haya más; no se pierde ninguna abeja.\n\n"
        "Tras 40 tratos, el oso te ofrece un acuerdo comercial: a partir de entonces paga mejor, 8 de miel por 1 hierba en vez de 10. Nunca se lleva miel por su cuenta; cuando los panales están llenos, la miel simplemente se detiene.",
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
    for key, why in CUT.items():
        r = rows[key]
        if not str(r[2].value or "").startswith("[unused"):
            r[2].value = UNUSED.format(why) + " " + str(r[2].value or "")
        updated += 1
    wb.save(PATH)
    print(f"added {added}, updated {updated}")


if __name__ == "__main__":
    main()
