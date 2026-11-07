# 🐝 Beekeeper — UI Specification (Honeycomb Card Suite)

> **Desktop First** (Avalonia on Windows, SwiftUI on macOS/iOS, Compose on Android).  
> Designed to live as the **7th game entry** in the Honeycomb Card Suite app!

---

## 1 · Integration in Honeycomb
* **GameSelectionBox:** 7th entry: `"Beekeeper"`.
* **Toolbar Buttons:** `New Game` and `Options` only (hides Restart, Hint, Undo).
* **StatsBarPanel Pattern:** Order is strictly:
  $$\text{BEES} \quad\cdot\quad \text{HONEY} \quad\cdot\quad \text{WAX} \quad\cdot\quad \text{BEEBITS}$$
  * Label `14 Bold` at 60% opacity over Value `20 Bold`, spacing `25`.
  * Bees shows `"12 / 20"` (with `" / 20"` at 14 Bold 60%).
  * Tabular figures prevent jiggling.
  * Stats appear sequentially as they are revealed in the game.
* **Persistent Hive Execution:** The hive continues running in the background when the player switches to Solitaire or Triple Triad in Honeycomb. Only quitting the app pauses production.
* **Theme Support:** Inherits the theme felt color (Default green, Honey amber, Sunset, Moogle, Forest, Ocean Sky).

---

## 2 · 3-Column Layout (`340px, *, 260px`)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ [Beekeeper ▾] [New Game] [Options]                 BEES: 12/500  HONEY: 45  BEEBITS: 8  │
├─────────────────────────┬───────────────────────────────┬──────────────────────────────┤
│ LEFT COLUMN (340px)     │ CENTRE COLUMN (Fluid, min 360)│ RIGHT COLUMN (260px)         │
│                         │                               │                              │
│ ┌─────────────────────┐ │ ┌───────────────────────────┐ │ ┌──────────────────────────┐ │
│ │ Pixel Art Frame     │ │ │ THE BEAR                  │ │ │ THE GARDEN (Log)         │ │
│ │ (170×102 at 2×)     │ │ │ Barnaby · Trades: 23      │ │ │                          │ │
│ └─────────────────────┘ │ │ [Sell 10] [Sell All]      │ │ │ 100% "Hive is full."     │ │
│ ┌─────────────────────┐ │ └───────────────────────────┘ │ │  80% "Padded gloves on." │ │
│ │ Catch Bee Button    │ │ ┌───────────────────────────┐ │ │  62% "Shop opens."       │ │
│ └─────────────────────┘ │ │ THE BEEKEEPER'S SHOP      │ │ │  46% "Wax drops."        │ │
│ "Bare hands · 1 bee"    │ │ • Gloves  [✓ Owned]       │ │ │  32% "Barnaby counts."   │ │
│                         │ │ • Net     [75 Beebits]    │ │ └──────────────────────────┘ │
│ ┌─────────────────────┐ │ │ • Vac     [250 Beebits]   │ │                              │
│ │ THE HIVE            │ │ │ • Catcher [150 Beebits]   │ │                              │
│ │ 2.0 honey / sec     │ │ └───────────────────────────┘ │                              │
│ │ Next wax: 17/50     │ │ ┌───────────────────────────┐ │                              │
│ │ [██████░░░░░░░░░]   │ │ │ COMBS · 2 built           │ │                              │
│ └─────────────────────┘ │ │ Room for 120 bees         │ │                              │
│                         │ └───────────────────────────┘ │                              │
└─────────────────────────┴───────────────────────────────┴──────────────────────────────┘
```

---

## 3 · Color Tokens & Typography
* **Accent:** Theme highlight (`#FFD300` Honey, `#FFD700` Default).
* **Glass:** `#8C0C0803` (`rgba(12, 8, 3, 0.55)`), border `rgba(255, 255, 255, 0.10)`. Radius `12px`.
* **Catch Bee:** 64px tall, radius 14px, accent fill, on-accent text `#2B1D05`.
* **Sting Popup:** Soft coral `#FFA38F`, accompanied by a $\pm 3\text{px}$ button nudge.
* **Fonts:**
  * `Newsreader` (or Georgia): Headings, story chronicle, popups, bear names.
  * `Segoe UI`: Buttons, numbers, tabular data, labels.

---

## 4 · Sticky Reveal Progression
| Trigger | What Appears |
|---|---|
| **New Game** | Art frame, Catch Bee, Tool line, Chronicle Log. Stat: `BEES` |
| **First bee caught** | The Hive Card. Stat: `HONEY` |
| **Holding 10 honey** | The Bear Panel (*Barnaby, Billy, Berenstein*) |
| **First sale** | Stat: `BEEBITS` |
| **First wax drop** | Stat: `WAX` |
| **Reached 15 Beebits** | The Beekeeper's Tool Shop |
| **Reached 50 wax** | Combs Construction Panel & Chandler's Workshop |
