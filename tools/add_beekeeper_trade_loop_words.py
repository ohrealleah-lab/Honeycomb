"""Beekeeper stage 10, the core trade loops (spec 019, Bee 2026-11-12): adds and updates the words in
the localization workbook. The bear pays Beebits again (plain and potted honey), the game opens with a
story card and 3 clay jars, honey + a jar makes potted honey, the beeswax candle comes back for the
Hippies, who give clay jars for it, and herbs come only from the bee hotel. The old beeswax candle
rows are used again. Help is not touched. Run once from the repo root, then run
generate_localization.py. Safe to re-run: rows whose key already exists are updated in place."""
import openpyxl
from pathlib import Path

PATH = Path(__file__).resolve().parent / "Honeycomb_Localization.xlsx"

B = "Beekeeper"

# (section, key, context, English, Spanish, translate)
ROWS = [
    # ---- changed: the bear pays Beebits, the Hippies give clay jars
    (B, "beekeeper_sell_hint", "Under the bear's buttons; %@ = honey in one trade (10, or 8 under the agreement), %@ = Beebits",
     "%@ honey = %@ Beebits", "%@ de miel = %@ Beebits", True),
    (B, "beekeeper_sell_hint_one_fmt", "Under the bear's buttons when a trade pays exactly 1 Beebit; %@ = honey in one trade",
     "%@ honey = 1 Beebit", "%@ de miel = 1 Beebit", True),
    (B, "beekeeper_hippies_rate", "Under the Hippies' buttons; %@ = beeswax candles they take for one clay jar",
     "%@ beeswax candles = 1 clay jar", "%@ velas de cera = 1 tarro de barro", True),
    (B, "beekeeper_log_trade_bear_fmt", "Story log; %@ = bear name, %@ = Beebits got, %@ = honey given",
     "%@ pays %@ Beebits for %@ honey.", "%@ te paga %@ Beebits por %@ de miel.", True),
    (B, "beekeeper_log_trade_bear_one_fmt", "Story log, a sale that paid 1 Beebit; %@ = bear name, %@ = honey given",
     "%@ pays 1 Beebit for %@ honey.", "%@ te paga 1 Beebit por %@ de miel.", True),
    (B, "beekeeper_log_trade_hippies_fmt", "Story log; %@ = clay jars got, %@ = beeswax candles given",
     "The Hippies give you %@ clay jars for %@ candles.", "Los hippies te dan %@ tarros de barro por %@ velas.", True),
    (B, "beekeeper_log_trade_hippies_one_fmt", "Story log, one clay jar; %@ = beeswax candles given",
     "The Hippies give you 1 clay jar for %@ candles.", "Los hippies te dan 1 tarro de barro por %@ velas.", True),
    (B, "beekeeper_herb_trades", "Bee Herb buff: more Beebits from the bear",
     "Good Deals", "Buenos tratos", True),
    (B, "beekeeper_log_herb_trades_fmt", "Story log, a herb rolled Good Deals; %@ = extra Beebits from the bear in percent",
     "The smoke smells like a good bargain. The Bear pays %@% more Beebits.",
     "El humo huele a buen trato. El oso paga un %@% más de Beebits.", True),

    # ---- used again: the beeswax candle (it was cut 2026-11-11)
    (B, "beekeeper_hive_beeswax_candles", "Hive card row label (stage 10: back, for the Hippies)",
     "Beeswax candles", "Velas de cera", True),
    (B, "beekeeper_beeswax_candle", "Workbench item name (stage 10: back, for the Hippies)",
     "Beeswax candle", "Vela de cera de abeja", True),
    (B, "beekeeper_beeswax_blurb", "Workbench item description, after its price",
     "The Hippies like these.", "A los hippies les gustan.", True),
    (B, "beekeeper_log_crafted_beeswax_fmt", "Story log, a batch of beeswax candles; %@ = how many",
     "You make %@ beeswax candles.", "Haces %@ velas de cera.", True),

    # ---- new
    (B, "beekeeper_story_opening", "Story card: the opening of a new game (Bee's words)",
     "You have just inherited your grandmother's farmhouse. In the garden, you find a skep and a few clay jars. "
     "It seems a little quiet. What will you do?",
     "Acabas de heredar la granja de tu abuela. En el jardín encuentras una colmena de paja y unos cuantos tarros "
     "de barro. Todo parece un poco tranquilo. ¿Qué vas a hacer?", True),
    (B, "beekeeper_story_look_around", "Story card button on the opening card",
     "Look around", "Echar un vistazo", True),
    (B, "beekeeper_hive_clay_jars", "Hive card row label",
     "Clay jars", "Tarros de barro", True),
    (B, "beekeeper_hive_potted_honey", "Hive card row label",
     "Potted honey", "Miel en tarro", True),
    (B, "beekeeper_pot_honey", "Hive card button: honey + a clay jar make potted honey",
     "Pot honey", "Envasar miel", True),
    (B, "beekeeper_pot_honey_tip_fmt", "Hover on the Pot honey button; %@ = honey one pot takes",
     "%@ honey + 1 clay jar → 1 potted honey. The Bear pays more for it.",
     "%@ de miel + 1 tarro de barro → 1 miel en tarro. El oso paga más por ella.", True),
    (B, "beekeeper_log_honey_potted", "Story log, the first potted honey",
     "You fill your grandmother's first jar with honey.", "Llenas de miel el primer tarro de tu abuela.", True),
    (B, "beekeeper_sell_potted", "The bear's button: sell one potted honey",
     "Sell potted honey", "Vender miel en tarro", True),
    (B, "beekeeper_sell_all_potted", "The bear's button: sell every potted honey",
     "Sell all potted", "Vender todos los tarros", True),
    (B, "beekeeper_potted_rate_fmt", "Under the bear's potted-honey buttons; %@ = Beebits for one potted honey",
     "1 potted honey = %@ Beebits", "1 miel en tarro = %@ Beebits", True),
    (B, "beekeeper_log_potted_sale_fmt", "Story log; %@ = bear name, %@ = Beebits got, %@ = potted honey given",
     "%@ pays %@ Beebits for %@ potted honey.", "%@ te paga %@ Beebits por %@ de miel en tarro.", True),
    (B, "beekeeper_trade_jar_fmt", "The Hippies' button: one trade; %@ = beeswax candles for one clay jar",
     "Trade %@ candles for a clay jar", "Cambiar %@ velas por un tarro de barro", True),
    (B, "beekeeper_clay_jars_tip_fmt", "Hover on the Clay jars row; %@ = jars a new game starts with, %@ = honey one jar pots",
     "%@ were in the garden. The Hippies trade more for beeswax candles. Each one pots %@ honey.",
     "%@ estaban en el jardín. Los hippies te dan más a cambio de velas de cera. Cada uno envasa %@ de miel.", True),
    (B, "beekeeper_herbs_tip", "Hover on the Herbs row",
     "The leafcutter bee brings them from the bee hotel. Used for herbal and herb-propolis candles.",
     "La abeja cortadora de hojas las trae del hotel de abejas. Sirven para las velas de hierbas y las de hierbas y propóleo.", True),
    (B, "beekeeper_beebits_tip", "Hover on the Beebits row, first line (then one line per source)",
     "Only the Bear pays Beebits:", "Solo el oso paga Beebits:", True),
    (B, "beekeeper_beebits_source_plain_fmt", "Beebits hover line; %@ = honey in one trade, %@ = Beebits for it",
     "%@ honey: %@ Beebits", "%@ de miel: %@ Beebits", True),
    (B, "beekeeper_beebits_source_agreement_fmt", "Beebits hover line under the trade agreement; %@ = honey in one trade, %@ = Beebits for it",
     "%@ honey: %@ Beebits (trade agreement)", "%@ de miel: %@ Beebits (acuerdo comercial)", True),
    (B, "beekeeper_beebits_source_potted_fmt", "Beebits hover line; %@ = Beebits for one potted honey",
     "1 potted honey: %@ Beebits", "1 miel en tarro: %@ Beebits", True),
    (B, "beekeeper_herb_trades_tip_fmt", "Hover on a burning Good Deals candle; %@ = extra Beebits in percent",
     "+%@% Beebits from the Bear.", "+%@% de Beebits del oso.", True),
]


def main() -> None:
    wb = openpyxl.load_workbook(PATH)
    ws = wb.worksheets[0]
    rows = {str(r[1].value).strip(): r for r in ws.iter_rows(min_row=2) if r[1].value}
    added = updated = 0
    for sec, key, ctx, en, es, tr in ROWS:
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
