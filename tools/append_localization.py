import openpyxl
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_PATH = REPO_ROOT / "tools" / "Honeycomb_Localization.xlsx"

ROWS = [
    ("TouchViewsIOS", "touch_layout_coming_soon", "Placeholder/fallback text", "Touch layout coming soon", "Diseño táctil próximamente", True),
    ("TouchViewsIOS", "touch_blackjack_title", "Title-case game label", "Blackjack", "Blackjack", False),
    ("TouchViewsIOS", "touch_blackjack_banner", "All-caps banner/header label", "BLACKJACK", "BLACKJACK", False),
    ("TouchViewsIOS", "touch_spider_banner", "All-caps banner/header label", "SPIDER", "SPIDER", False),
    ("TouchViewsIOS", "touch_klondike_banner", "All-caps banner/header label", "KLONDIKE", "KLONDIKE", False),
    ("TouchViewsIOS", "touch_beecell_banner", "All-caps banner/header label", "BEECELL", "BEECELL", False),
    ("Chrome", "debug_banners_menu", "Mac-only dev menu title", "Banners", "Anuncios", True)
]

def main() -> None:
    wb = openpyxl.load_workbook(OUT_PATH)
    ws = wb.active
    
    existing_keys = set()
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row and len(row) > 1 and row[1]:
            existing_keys.add(str(row[1]).strip())
    
    added_count = 0
    for row in ROWS:
        key = row[1]
        if key in existing_keys:
            print(f"Warning: Skipping duplicate key '{key}'")
            continue
        ws.append(list(row))
        added_count += 1
        
    wb.save(OUT_PATH)
    print(f"Appended {added_count} rows to {OUT_PATH.relative_to(REPO_ROOT)}")

if __name__ == "__main__":
    main()
