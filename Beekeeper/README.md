# 🐝 Beekeeper — Master Game Design Bible & Systems Architecture

> **Title:** *Beekeeper*  
> **Aesthetic Philosophy:** **Pure Text-Based Incremental** (in the tradition of *A Dark Room*, *Kittens Game*, and *Universal Paperclips*). Zero visual bloat or physics clutter—relying on atmospheric narrative text, clean typography, quiet reveal pacing, and dedicated frame slots reserved for custom pixel art illustrations.

---

## 🕹️ Interactive Web Prototype (Text-Based)

Open the browser client at:  
👉 **[`/Users/leah/Honeycomb/Beekeeper/index.html`](file:///Users/leah/Honeycomb/Beekeeper/index.html)**

---

## 📜 Core Game Rules & Mechanics

### 1. Active Harvesting
* Click `[ Catch Bee ]`: Adds **+1 bee** to the hive.
* Catch amount scales with equipped tools:
  * **Bare Hands:** +1 bee per click
  * **Padded Gloves (15 Beebits):** +2 bees per click
  * **Mesh Net (75 Beebits):** +5 bees per click
  * **Bee-Safe Vacuum (250 Beebits):** +10 bees per click

### 2. Passive Production & Wax Drops
* **Honey Flow:** Each bee in the hive passively generates **0.01 Honey per second** (100 bees = 1.0/s; 500 bees = 5.0/s).
* **Wax Excretion:** Wax drops slowly: **every 50 honey produced creates 1 Beeswax**.
* **Wax-Catcher (150 Beebits):** Doubles wax output (creates 2 wax per 50 honey).

### 3. Hive Architecture & Comb Scaling
* Hive starts with a capacity of **500 bees**.
* **Building a Comb:** Costs **50 Beeswax** initially.
  * Each comb increases the size of the beehive by **+500 bees**.
  * **Cost Scaling:** Increases by **+25% per comb built**:  
    $$\text{Cost} = \lfloor 50 \times 1.25^N \rfloor$$

### 4. Commerce & Trading Post (Appears at 10 Honey)
* **The Bear:** A bear with a unique name (*Barnaby, Billy, Berenstein, Bruno, Baloo, Buster, Bartholomew*) appears at **10 Honey**.
  * **10 Honey $\rightarrow$ 1 Beebit.**
  * `[ Sell All Honey ]`: Converts the maximum whole number of 10-honey bundles into Beebits (remainder stays in reservoir).
  * **100 Trades Perk:** At 100 trades, the bear becomes your meadow protector, **reducing wasp raid frequency by 50%**.
* **Visiting Hippies:** Buy Plain Beeswax Candles for **25 Beebits each**.
  * `[ Sell All Candles ]`: Sells all crafted beeswax candles for an instant cash injection.

### 5. Chandler's Workshop & Candles
* **Plain Beeswax Candle (10 Wax):** Burns for 120s, keeping the hive calm and increasing honey generation speed by **+20%**. Can also be sold to hippies for 25 Beebits.
* **Sage-Propolis Candle (50 Wax):** Burns for 180s. **100% Wasp Repellent** (wasps are immediately warded off by the fragrant smoke).

### 6. Wasp Incursions (High-Stakes Threat)
* Wasps periodically threaten the hive.
* **The Ultimatum:** Bribe with **10 Honey** within 15 seconds.
* **The Penalty:** If no bribe occurs, **50% of all bees are killed!**
* **The Counter:** If a Sage-Propolis Candle is burning, the wasp is automatically repelled without demanding honey or harming bees.

### 7. Site Expansion & Late Game
* **Sites:** Expand from **The Garden** $\rightarrow$ **Wildflower Meadow** (100 ₿) $\rightarrow$ **Honey Factory** (500 ₿).
* **Future Upgrades:** Guard Bees (defend without bribes), Bumblebees (heavy wax generators), Clover Bees (extra honey), and Queen Bee awakening.

---

## 📁 Repository Structure

```
/Users/leah/Honeycomb/Beekeeper/
├── index.html                  # 🕹️ Pure text-based playable client
├── README.md                   # Master Design Bible
├── Beekeeper_Game_Bible.xlsx   # Styled 9-tab Excel workbook
├── build_sheets.py             # Automated sheet & CSV compiler
└── csv/                        # 9 Synchronized data tables:
    ├── Meta_Loop.csv
    ├── Resources.csv
    ├── Tools_Gear.csv
    ├── Candles_Crafting.csv
    ├── Creatures_Market.csv
    ├── Architecture_Combs.csv
    ├── Threats_Wasps.csv
    ├── Areas_Biomes.csv
    └── Upgrades_Tech.csv
```
