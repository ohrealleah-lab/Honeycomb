import os
import csv
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

base_dir = "/Users/leah/Honeycomb/Beekeeper"
csv_dir = os.path.join(base_dir, "csv")
os.makedirs(csv_dir, exist_ok=True)

sheets_data = {
    "Meta_Loop": [
        ["Stage ID", "Stage Name", "Unlock Condition", "Key Mechanics Introduced", "Primary Bottleneck", "Pacing Goal"],
        ["ST_01_FROLIC", "Frolicking Bees", "Game Start", "Click 'Catch Bee' (+1 bee); Starting hive cap 500; 0.01 honey/sec per bee; Wax drops every 50 honey", "Manual clicks & early stamina", "0 - 3 mins"],
        ["ST_02_BEAR_TRADE", "The Bear Market", "Honey >= 10", "Selling interface appears; Sell 10 Honey for 1 Beebit or Sell All to Bear (Barnaby, Billy, Berenstein); 100 trades = bear ward", "Accumulating 15 Beebits for Shop", "3 - 8 mins"],
        ["ST_03_SHOP_OPEN", "The Beekeeper's Tools", "Beebits >= 15", "Shop appears; Padded Gloves (2 bees), Mesh Net (5 bees), Bee-Safe Vac (10 bees), Wax-Catcher (2x wax)", "Filling 500-bee runway & buying gear", "8 - 18 mins"],
        ["ST_04_COMBS_CRAFT", "Combs & Candlemaking", "Wax >= 10", "Craft Beeswax Candle (10 wax, +20% honey); Craft Comb (50 wax, +500 bee cap, +25% cost/comb); Sell candles to Hippies (25 ₿)", "Wax drop rate & scaling comb cost", "18 - 35 mins"],
        ["ST_05_WASP_CRISIS", "Wasp Incursions", "Honey > 30 (periodic)", "Wasps raid hive; Bribe 10 Honey or LOSE 50% OF BEES; Craft Sage-Propolis Candle (50 wax) to repel", "Honey reserves & candle prep", "30 - 60 mins"],
        ["ST_06_EXPANSION", "Meadow & Honey Factory", "Combs >= 2", "Unlock Meadow and Honey Factory; Clover Bees (extra honey), Bumblebees (extra wax)", "Area unlock costs & logistics", "1 - 2 hours"],
        ["ST_07_QUEEN_COLONY", "The Queen's Dominion", "Full Comb Hive", "Guard Bees & Queen Bee awakening; total colony synergy & multi-hive prestige", "Endgame optimization", "2+ hours"]
    ],
    "Resources": [
        ["Resource ID", "Name", "Category", "Base Cap", "Cap Expanded By", "Source", "Drain / Sinks", "Special Rules"],
        ["RES_BEES", "Bees in Hive", "Population", "500", "Combs (+500 cap per comb)", "Catching in Areas (Hands/Gloves/Net/Vac)", "Wasp raids (50% loss if unbribed)", "Each bee produces 0.01 honey per second (100 bees = 1.0/s)."],
        ["RES_HONEY", "Sweet Honey", "Liquid Gold", "Unlimited", "N/A", "Passive generation from Hive Bees (0.01/s per bee)", "Sold to Bear (10 Honey = 1 Beebit), Wasp bribes (10 honey)", "Every 50 honey produced generates 1 Beeswax flake."],
        ["RES_BEEBITS", "Beebits", "Currency", "Unlimited", "N/A", "Selling honey to Bear, selling candles to Hippies", "Shop tools, upgrades, area passes", "Core progression money."],
        ["RES_WAX", "Beeswax", "Material", "Unlimited", "N/A", "Passive byproduct (1 per 50 honey; 2x with Wax-Catcher)", "Crafting Combs (50 wax +25%/comb), Dipping Candles", "Essential structural and craft material."],
        ["RES_CANDLE_WAX", "Beeswax Candle", "Crafted Item", "Unlimited", "N/A", "Crafted at 10 wax each", "Burned for +20% honey speed (120s) or sold to Hippies (25 ₿)", "High-value trade item."],
        ["RES_CANDLE_REPEL", "Sage-Propolis Candle", "Crafted Item", "Unlimited", "N/A", "Crafted at 50 wax each", "Burned for 100% wasp defense (180s)", "Vital protection against bee annihilation."]
    ],
    "Tools_Gear": [
        ["Tool ID", "Tool Name", "Cost (Beebits)", "Bees Per Grab", "Unlock Condition", "Category", "Description"],
        ["TOOL_BARE_HANDS", "Bare Hands", "0", "1", "Game Start", "Default", "Careful and gentle plucking. 1 bee at a time (20% sting chance)."],
        ["TOOL_PADDED_GLOVES", "Padded Gloves", "15", "2", "Shop Unlock (15 Beebits)", "Gear", "Thick leather lets you safely cup 2 bees at a time. No stings."],
        ["TOOL_MESH_NET", "Mesh Net", "75", "5", "Shop", "Gear", "Light sweeping net. Scoops up 5 bees per click."],
        ["TOOL_BEE_VACUUM", "Bee-Safe Vacuum", "250", "10", "Shop", "Gear", "Gentle pneumatic suction. Sweeps 10 bees into cushioned hopper."],
        ["TOOL_WAX_CATCHER", "Wax-Catcher", "150", "Passive (2x Wax)", "Shop", "Apparatus", "Brass condenser attached to hive combs. Doubles all wax output!"]
    ],
    "Candles_Crafting": [
        ["Candle ID", "Candle Name", "Wax Cost", "Hippie Sell Value", "Burn Duration (s)", "Burn Effect", "Description"],
        ["CANDLE_BEESWAX", "Plain Beeswax Candle", "10 Wax", "25 Beebits", "120s", "+20% Honey generation rate", "Keeps hive calm and speeds up honey production. Hippies pay 25 Beebits each!"],
        ["CANDLE_SAGE_PROPOLIS", "Sage-Propolis Repelling Candle", "50 Wax", "N/A (Essential Defense)", "180s", "100% Wasp Repellent", "Pungent sage & propolis smoke completely wards off wasp attacks while lit."]
    ],
    "Creatures_Market": [
        ["Buyer ID", "Buyer Name / Group", "Trade Goods", "Price / Exchange Rate", "Sell All Behavior", "Special Perk at Milestone"],
        ["BUYER_BEAR", "Bear (Random: Barnaby, Billy, Berenstein, Bruno, Baloo, Buster, Bartholomew)", "Sweet Honey", "10 Honey -> 1 Beebit", "Sells max whole bundles (leaves remainder <10)", "At 100 Trades: Bear guards the meadow, reducing wasp attacks by 50%!"],
        ["BUYER_HIPPIE", "Visiting Hippies", "Beeswax Candles", "1 Candle -> 25 Beebits", "Sell All sells 100% of Plain Beeswax Candles in stock", "Reliable cash injection for expensive tools & tech!"]
    ],
    "Architecture_Combs": [
        ["Comb ID", "Structure Name", "Base Wax Cost", "Cost Growth Rate", "Bee Capacity Added", "Description"],
        ["COMB_EXPANSION", "Hexagonal Brood Comb", "50 Wax", "+25% per comb owned (Cost = 50 * 1.25^N)", "+500 Bees Capacity", "Expand the beehive size by +500 bees per comb built."]
    ],
    "Threats_Wasps": [
        ["Threat ID", "Name", "Trigger", "Bribe Demand", "Candle Counter", "Default Penalty (No Bribe / Unchecked)", "Bear Ally Perk"],
        ["THREAT_WASP_RAID", "Wasp Raid", "Periodic timer", "10 Sweet Honey", "Sage-Propolis Candle (100% repelled)", "50% OF ALL BEES KILLED!", "100 Bear Trades cuts attack frequency in half"]
    ],
    "Areas_Biomes": [
        ["Area ID", "Area Name", "Unlock Cost", "Native Bee Types", "Special Properties"],
        ["AREA_GARDEN", "The Garden", "Free (Start)", "Standard Honeybee", "Peaceful frolicking bees; perfect starting site."],
        ["AREA_MEADOW", "Wildflower Meadow", "100 Beebits", "Clover Bees, Bumblebees", "Clover Bees yield extra honey; Bumblebees generate high wax."],
        ["AREA_FACTORY", "Honey Factory", "500 Beebits", "Industrial Turbo Bees", "Massive honey output, dense swarms, heavy machinery."]
    ],
    "Upgrades_Tech": [
        ["Upgrade ID", "Name", "Cost", "Prerequisite", "Colony Effect", "Description"],
        ["UPG_GUARD_BEES", "Guard Bees", "50 Beebits + 1 Comb", "Shop", "Fights off wasps without bribe", "Tough bees stationed at hive entrance."],
        ["UPG_CLOVER_BEES", "Clover Bee Strain", "80 Beebits", "Meadow Unlocked", "+25% Honey output from all bees", "Sweet wild clover nectar boosts yield."],
        ["UPG_BUMBLEBEES", "Bumblebee Genetics", "120 Beebits", "Meadow Unlocked", "Increases wax drop frequency", "Chonky fuzzy bees produce dense wax flakes."],
        ["UPG_QUEEN_BEE", "Queen Bee Awakening", "1,000 Beebits + 5 Combs", "Late Game", "Boosts all colony stats & automates hatching", "The matriarch unites the entire apiary."]
    ]
}

for f in os.listdir(csv_dir):
    if f.endswith(".csv"):
        os.remove(os.path.join(csv_dir, f))

for name, rows in sheets_data.items():
    csv_path = os.path.join(csv_dir, f"{name}.csv")
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

wb = openpyxl.Workbook()
wb.remove(wb.active)

header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
header_fill = PatternFill(start_color="D97706", end_color="D97706", fill_type="solid")
alt_row_fill = PatternFill(start_color="FFFBEB", end_color="FFFBEB", fill_type="solid")
regular_font = Font(name="Calibri", size=10, color="1F2937")

thin_border = Border(
    left=Side(style='thin', color='E5E7EB'),
    right=Side(style='thin', color='E5E7EB'),
    top=Side(style='thin', color='E5E7EB'),
    bottom=Side(style='thin', color='E5E7EB')
)

for name, rows in sheets_data.items():
    ws = wb.create_sheet(title=name)
    ws.views.sheetView[0].showGridLines = True
    
    for r_idx, row in enumerate(rows, 1):
        for c_idx, val in enumerate(row, 1):
            cell = ws.cell(row=r_idx, column=c_idx, value=val)
            cell.border = thin_border
            if r_idx == 1:
                cell.font = header_font
                cell.fill = header_fill
                cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
                ws.row_dimensions[r_idx].height = 28
            else:
                cell.font = regular_font
                cell.alignment = Alignment(vertical="center")
                ws.row_dimensions[r_idx].height = 20
                if r_idx % 2 == 1:
                    cell.fill = alt_row_fill

    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            val_str = str(cell.value or "")
            if len(val_str) > max_len:
                max_len = len(val_str)
        ws.column_dimensions[col_letter].width = min(max(max_len + 4, 12), 48)
    
    ws.freeze_panes = "A2"

excel_path = os.path.join(base_dir, "Beekeeper_Game_Bible.xlsx")
wb.save(excel_path)
print(f"Updated Excel workbook: {excel_path}")
print(f"Updated {len(sheets_data)} CSV files in {csv_dir}")
