#!/usr/bin/env python3
"""
One-time seed for tools/Honeycomb_Localization.xlsx — creates the workbook
with the right headers and a first batch of chrome strings (menus, toolbar,
options sheet, alerts) so generate_localization.py has something to run
against. After this runs once, the xlsx is the canonical source of truth —
edit it directly (Excel/Numbers/openpyxl) and re-run generate_localization.py;
never re-run this seed script against a workbook that already has real edits,
since it overwrites the file wholesale.
"""
from pathlib import Path

import openpyxl

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_PATH = REPO_ROOT / "tools" / "Honeycomb_Localization.xlsx"

HEADERS = ["Section", "Key", "Context", "English", "Spanish", "Translate"]

# (Section, Key, Context, English, Spanish, Translate)
ROWS = [
    ("Chrome", "new_game", "File menu / toolbar button", "New Game", "Nueva Partida", True),
    ("Chrome", "restart", "File menu / toolbar button", "Restart", "Reiniciar", True),
    ("Chrome", "undo", "File menu / toolbar button", "Undo", "Deshacer", True),
    ("Chrome", "cancel", "Button, reused across every dialog/sheet", "Cancel", "Cancelar", True),
    ("Chrome", "ok", "Button, reused across every dialog/sheet", "OK", "Aceptar", True),
    ("Chrome", "done", "Button, reused across every dialog/sheet", "Done", "Hecho", True),
    ("Chrome", "hint", "Toolbar button label", "Hint", "Pista", True),
    ("Chrome", "options", "Toolbar button label", "Options", "Opciones", True),
    ("Options", "preferences", "Options sheet title (default)", "Preferences", "Preferencias", True),
    ("Options", "view_stats", "Options sheet button", "View Stats", "Ver Estadísticas", True),
    ("Options", "visual_themes", "Options sheet section header", "Visual Themes", "Temas Visuales", True),
    ("Options", "visual_themes_subtitle", "Options sheet section subtitle", "Felt, card back, face card art, colors", "Fieltro, reverso de carta, arte de figuras, colores", True),
    ("Options", "language", "New Language row label, top of Options", "Language", "Idioma", True),
    ("Options", "language_english", "Language picker option (kept in Latin script for both languages)", "English", "English", False),
    ("Options", "language_spanish", "Language picker option (kept in Spanish for both languages)", "Español", "Español", False),
    ("Alerts", "reset_statistics_title", "Alert title", "Reset Statistics?", "¿Restablecer Estadísticas?", True),
    ("Alerts", "reset_statistics_body", "Alert body", "This will permanently clear all statistics for the current game. This cannot be undone.", "Esto borrará permanentemente todas las estadísticas del juego actual. Esta acción no se puede deshacer.", True),
    ("Alerts", "reset", "Alert button", "Reset", "Restablecer", True),
    ("Toolbar", "score_label", "Status bar label", "SCORE", "PUNTUACIÓN", True),
    ("Toolbar", "moves_label", "Status bar label", "MOVES", "MOVIMIENTOS", True),
    ("Toolbar", "time_label", "Status bar label", "TIME", "TIEMPO", True),
]


def main() -> None:
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Strings"
    ws.append(HEADERS)
    for row in ROWS:
        ws.append(list(row))
    for i, header in enumerate(HEADERS, start=1):
        ws.column_dimensions[chr(64 + i)].width = 28 if header != "English" and header != "Spanish" else 40
    wb.save(OUT_PATH)
    print(f"Wrote {OUT_PATH.relative_to(REPO_ROOT)} ({len(ROWS)} rows)")


if __name__ == "__main__":
    main()
