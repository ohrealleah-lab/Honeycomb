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
    
    for row in ROWS:
        ws.append(list(row))
        
    wb.save(OUT_PATH)
    print(f"Appended {len(ROWS)} rows to {OUT_PATH.relative_to(REPO_ROOT)}")

if __name__ == "__main__":
    main()
