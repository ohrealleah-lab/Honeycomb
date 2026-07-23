STEP: 4
Created At: 2026-07-22T11:42:17-04:00
Completed At: 2026-07-22T11:42:17-04:00
File Path: `file:///Users/leah/.claude/plans/as-you-know-we-mutable-owl.md`
Total Lines: 548
Total Bytes: 59640
Showing lines 1 to 548
Content truncated: showing bytes 0-46080 of 59640. To see more, call this tool again with the same line range and ContentOffset=46080.
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
1: # Honeycomb: macOS → Windows Port Spec (for Gemini)
2: 
3: ## Context
4: 
5: Honeycomb is a Triple-Triad-style card battle game that now exists, complete and shipped, on the macOS app (`/Users/leah/Honeycomb/mac/src/Honeycomb/`). The mono-repo houses two independently-built codebases for the same product — Swift/SwiftUI on mac, C#/Avalonia on Windows — because the two platforms require genuinely different toolchains, not because the code is meant to diverge. Every other game in the suite (Klondike, Spider, Beecell/Freecell, Blackjack, Video Poker) has already been verified to behave identically on both platforms. Honeycomb is the one game that exists on only one side, and it's time to close that gap.
6: 
7: This document is the literal spec Gemini will code from. Gemini is capable but needs everything spelled out explicitly — exact algorithms, exact numbers, exact file paths to imitate, and exact points where "look at how Blackjack does it" is the instruction. Nothing in here should require Gemini to infer intent from vibes. Where the mac source is the source of truth, this doc quotes or transcribes it directly rather than paraphrasing loosely.
8: 
9: **Goal: 100% behavioral parity.** Every rule, every capture edge case, every AI heuristic, every deck-validation rule, every persisted stat, every card position on screen — all of it should work the same way a mac player already knows it to work. The two known non-deterministic spots in the mac implementation (see "Accepted non-determinism" below) don't need bit-for-bit run-to-run matching, but everything else does.
10: 
11: ---
12: 
13: ## Reference materials (read these first, in this order)
14: 
15: **Mac source of truth** — `/Users/leah/Honeycomb/mac/src/Honeycomb/`:
16: - `Models/HoneycombCardGenerator.swift`, `HoneycombDatabase.swift`, `HoneycombCard.swift`, `HoneycombTypes.swift` — card DB
17: - `Models/HoneycombBoard.swift` — board + capture rules
18: - `Models/HoneycombAI.swift` — AI opponent
19: - `Models/HoneycombDeck.swift` — collection/deck persistence (`HoneycombProfileManager`)
20: - `Models/HoneycombStats.swift` — stats
21: - `ViewModels/HoneycombViewModel.swift` — match orchestration (the biggest file, ~1300 lines)
22: - `Views/HoneycombView.swift`, `HoneycombCardView.swift`, `HoneycombDecksView.swift`, `HoneycombStatsView.swift` — UI
23: - `/Users/leah/Honeycomb/mac/src/Views/HelpGuideView.swift` lines 215–272 (`HoneycombHelpView`) — help text, quoted in full below
24: - `/Users/leah/Honeycomb/mac/SoliBeeTests/HoneycombCardGeneratorTests.swift` — existing mac test coverage to mirror
25: 
26: **Windows conventions to imitate** — `/Users/leah/Honeycomb/windows/`:
27: - `src/SoliBee.Core/ViewModels/BlackjackViewModel.cs` + `Models/BlackjackState.cs`/`BlackjackOptions.cs`/`BlackjackStatistics.cs` — **this is the template**. Honeycomb is architecturally the same shape as Blackjack (a self-contained mini-game with its own board/state, not a solitaire tableau), and Blackjack already establishes every pattern this port needs: MVVM shape, self-contained JSON persistence, no Undo/Hint (Honeycomb needs both — see Phase 5).
28: - `src/SoliBee.Desktop/Views/BlackjackView.axaml` + `.axaml.cs` — board layout structure, imperative `Refresh(vm)`-on-`PropertyChanged` pattern, felt-color handling.
29: - `src/SoliBee.Desktop/Views/SpiderViewModel.cs` — reference for the Undo-stack pattern (Honeycomb needs this, Blackjack doesn't have it).
30: - `src/SoliBee.Desktop/App.axaml` — shared style classes.
31: - `src/SoliBee.Desktop/Views/HelpWindow.axaml` + `.axaml.cs` — help-content anchor/section pattern.
32: - `src/SoliBee.Desktop/Views/MainWindow.axaml` + `.axaml.cs` — game-switching wiring.
33: - `src/SoliBee.Core/ViewModels/AppCoordinator.cs` — cross-game orchestration.
34: - `tests/SoliBee.Tests/ViewModels/BlackjackViewModelTests.cs` — test-writing conventions.
35: 
36: ---
37: 
38: ## Architecture decisions (already made — don't relitigate these)
39: 
40: 1. **Where code lives**: all game logic (card DB, board, rules, AI, persistence, stats) goes in `SoliBee.Core/Models/` and `SoliBee.Core/ViewModels/`, exactly mirroring the mac file split. Only rendering goes in `SoliBee.Desktop/Views/`.
41: 2. **Persistence**: follow Blackjack's self-contained pattern exactly, **not** the shared `SettingsService`/`GameOptions` system (that system is for cross-game visual/window settings only). Honeycomb gets its own JSON files under `%LocalAppData%\SoliBee\`, one per concept, mirroring the mac UserDefaults keys 1:1 so behavior is trivially cross-checkable against mac:
42:    - `honeycomb_seed.json` — the card-generation seed (a `ulong`, matches mac's `honeycomb_card_seed`)
43:    - `honeycomb_unlocked_cards.json` — `List<int>` of unlocked card ids (mac: `honeycomb_unlocked_cards`)
44:    - `honeycomb_saved_decks.json` — the 5 `HoneycombDeckState` slots (mac: `honeycomb_saved_decks`)
45:    - `honeycomb_favorite_cards.json` — `List<int>` (mac: `honeycomb_favorite_cards`)
46:    - `honeycomb_stats.json` — `HoneycombStatistics` (mac: `honeycomb_stats`)
47:    - `honeycomb_options.json` — match options: difficulty, selected rules, active deck index, force-normal-mode, sound/point-highlight/hint-visibility toggles, window width/height/maximized (mac: `honeycomb_options`, i.e. `HoneycombViewModel.Options`)
48: 
49:    Use the exact `Directory.CreateDirectory` + `File.WriteAllText`/`File.ReadAllText` + try/catch-swallow pattern from `BlackjackViewModel.cs` (`SaveOptions`/`LoadOptions`/`SaveStatistics`/`LoadStatistics`). Still pull the *shared* cross-cutting settings (felt color, sound-enabled, no-stress-mode, card back theme) from `SettingsService.LoadOptions()` at construction time and mirror them onto Honeycomb's own options object, the same way `BlackjackViewModel`'s constructor does — and add `HoneycombWidth`/`HoneycombHeight`/`HoneycombMaximized` properties to the shared `GameOptions.cs` (alongside the existing `BlackjackWidth` etc.) plus matching `GetValue`/`SetValue` lines in `SettingsService.cs`'s `LoadOptions()`/`SaveOptions()`, so window-size restore works the same way it does for every other game.
50: 3. **Class/file naming**: mirror mac 1:1 so the two codebases stay easy to diff conceptually:
51:    - `HoneycombCardGenerator.cs`, `HoneycombDatabase.cs`, `HoneycombCard.cs` (`HoneycombCardData` + the modifier-wrapping `HoneycombCard` instance type), `HoneycombTypes.cs` (enums) → `SoliBee.Core/Models/`
52:    - `HoneycombBoard.cs` → `SoliBee.Core/Models/`
53:    - `HoneycombAI.cs` → `SoliBee.Core/Models/` (matches mac's placement — it's algorithmic, not a ViewModel, even though it's AI logic)
54:    - `HoneycombDeck.cs` (`HoneycombProfileManager` class + `HoneycombDeckState` struct/record) → `SoliBee.Core/Models/`
55:    - `HoneycombStats.cs` (`HoneycombStatistics`) → `SoliBee.Core/Models/`
56:    - `HoneycombViewModel.cs` (+ nested `Options` class) → `SoliBee.Core/ViewModels/`
57:    - `HoneycombView.axaml`/`.axaml.cs` (main board+hands screen), `HoneycombCardView.axaml`/`.axaml.cs` (card visual) → `SoliBee.Desktop/Views/`
58:    - `HoneycombDecksWindow.axaml`/`.axaml.cs` (deck builder + card bank) → `SoliBee.Desktop/Views/`, built as its own `Window` shown via `.Show(owner)`, the same way `ThemeEditorWindow`/`CardBackEditorWindow` are separate windows rather than crammed into `MainWindow`'s overlay system — this screen is complex enough (filter bar, deck slots, card grid, deck builder sheet) to deserve its own window.
59:    - `HoneycombStatsWindow.axaml`/`.axaml.cs` → `SoliBee.Desktop/Views/`, same "own Window" treatment, mirroring mac's fixed 440×560 stats sheet.
60:    - `HoneycombDatabase` is a singleton, exactly like mac (`HoneycombDatabase.Shared`, static instance) — it must survive the whole app session (card pool + seed), not be recreated on game-switch, matching mac's `HoneycombDatabase.shared`.
61: 4. **Test project layout**: `tests/SoliBee.Tests/Core/HoneycombCardGeneratorTests.cs`, `HoneycombBoardTests.cs`, `HoneycombAITests.cs`, and `tests/SoliBee.Tests/ViewModels/HoneycombViewModelTests.cs` — follow `BlackjackViewModelTests.cs`'s conventions exactly: construct the real class directly (no mocking), hand-set fields to engineer a scenario, assert on results; group tests with `// ── Section Name ──` banner comments; use reflection to reach private fields/methods where the design deliberately snapshots something (Honeycomb's AI/board don't currently need this, but if you add a similar frozen-snapshot field, follow the `SetHandFreePlay`-style reflection helper pattern from `BlackjackViewModelTests.cs`).
62: 
63: ## Accepted non-determinism (do not "fix" these — mac itself doesn't guarantee them either)
64: 
65: 1. **Starter deck card order**: mac's first-run starter deck reads `Array(unlockedCardIds)` from a `Set<Int>` — unordered. On Windows, populate the initial 5-card starter deck (3× 1★ + 2× 2★, drawn via the same `RandomCards` calls) in whatever order they're drawn in; don't sort or otherwise try to impose a "canonical" order. Just be internally consistent (same code path every time), not bit-matching mac.
66: 2. **Hard/Ultra-Hard AI tie-breaking**: when multiple moves score equally in minimax, mac picks randomly among the tied "most aggressive" (highest immediate-capture) candidates. Port this as a genuine random pick among ties too (`Random.Shared.Next` or equivalent) — don't pin it to "always pick the first candidate" or similar, since that would make the AI more predictable than the mac version and is a real behavior change, not just an implementation detail.
67: 
68: ---
69: 
70: ## Phase 1 — Card Database & RNG
71: 
72: **Build:** `HoneycombCardGenerator.cs`, `HoneycombDatabase.cs`, `HoneycombCard.cs`, `HoneycombTypes.cs`.
73: 
74: ### SplitMix64 — must be bit-exact
75: 
76: Mac's generator uses a custom seedable RNG so the same seed always produces the same card pool (`HoneycombCardGenerator.swift:8-18`):
77: 
78: ```swift
79: struct SplitMix64: RandomNumberGenerator {
80:     private var state: UInt64
81:     init(seed: UInt64) { self.state = seed }
82:     mutating func next() -> UInt64 {
83:         state = state &+ 0x9E3779B97F4A7C15
84:         var z = state
85:         z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
86:         z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
87:         return z ^ (z >> 31)
88:     }
89: }
90: ```
91: 
92: Port to C# `unchecked` arithmetic on `ulong` (C#'s `+`/`*` throw on overflow in checked contexts by default in some project configs — force `unchecked` explicitly to get the same wraparound Swift's `&+`/`&*` give you):
93: 
94: ```csharp
95: public struct SplitMix64
96: {
97:     private ulong _state;
98:     public SplitMix64(ulong seed) { _state = seed; }
99:     public ulong Next()
100:     {
101:         unchecked
102:         {
103:             _state += 0x9E3779B97F4A7C15UL;
104:             ulong z = _state;
105:             z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
106:             z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
107:             return z ^ (z >> 31);
108:         }
109:     }
110: }
111: ```
112: 
113: **Verify this in isolation first**, before touching the card generator at all. `SplitMix64(seed: 1).Next()` called 8 times in a row must produce exactly:
114: ```
115: 10451216379200822465
116: 13757245211066428519
117: 17911839290282890590
118: 8196980753821780235
119: 8195237237126968761
120: 14072917602864530048
121: 16184226688143867045
122: 9648886400068060533
123: ```
124: And `SplitMix64(seed: 42)`, 8 calls:
125: ```
126: 13679457532755275413
127: 2949826092126892291
128: 5139283748462763858
129: 6349198060258255764
130: 701532786141963250
131: 16015981125662989062
132: 4028864712777624925
133: 14769051326987775908
134: ```
135: (These were extracted by actually running the real mac Swift code, not derived by hand — they're ground truth.) Write this as the very first test in `HoneycombCardGeneratorTests.cs` and don't proceed to anything else until it passes.
136: 
137: Swift's `Int.random(in: range, using: &rng)` needs a matching C# helper that draws from `SplitMix64.Next()` — implement uniform-in-range sampling (standard rejection-based modulo-bias-free technique, e.g. `next % rangeSize` is NOT good enough if you want bit-parity with Swift's actual algorithm; Swift's implementation for a `ClosedRange<Int>` draws a full-width random value and reduces it via Lemire's method internally). **You do not need to reproduce Swift's internal `Int.random(in:using:)` algorithm exactly** — the card-generation test vectors below (Phase 1 acceptance) are the actual bar, and they were generated using Swift's real `Int.random(in:using:)`. If your C# uniform-int-in-range implementation doesn't produce the same sequence of stat draws as Swift's does from the same raw `SplitMix64` stream, the generated-card test vectors will fail even though the raw RNG vectors above pass — that's expected and means you need to specifically reverse-engineer Swift's `Int.random(in:using:)` reduction algorithm (it's Lemire's nearly-divisionless unbiased range reduction over the raw 64-bit stream) rather than substitute your own. Standard reference: for range size `n`, compute a random full-width value, do a 128-bit-widening multiply by `n`, and take the high 64 bits as the result, with a rejection loop only in the rare case the low bits fall below a modulo threshold. If C#'s `Math.BigMul(ulong, ulong, out ulong)` (available in .NET) is used for the widening multiply, this should reproduce Swift's stdlib behavior.
138: 
139: ### Tier table (`HoneycombCardGenerator.swift:33-39`)
140: 
141: | Stars | Stat value range | Budget (sum of 4 stats) | Count per suit |
142: |---|---|---|---|
143: | 1 | 1–7 | 12–15 | 26 |
144: | 2 | 1–7 | 16–21 | 36 |
145: | 3 | 1–8 | 20–25 | 41 |
146: | 4 | 1–9 | 24–28 | 21 |
147: | 5 | 1–10 | 25–30 | 14 |
148: 
149: Total per suit = 138. Total cards = 552.
150: 
151: ### Generation algorithm (`HoneycombCardGenerator.swift:43-73`)
152: 
153: - Suits in fixed order `["S", "H", "D", "C"]`.
154: - **One** `SplitMix64` instance, seeded once, consumed sequentially across the entire generation — suit is the outer loop, tier is the middle loop, count-per-suit is the inner loop. Order matters for determinism.
155: - Per suit, a `HashSet<int[]>`-equivalent (C# needs a value-comparing set — use a `HashSet<string>` keyed by e.g. `string.Join(",", stats)`, or a `HashSet<(int,int,int,int)>` tuple) prevents duplicate exact 4-stat combos *within that suit only* — cross-suit duplicates are fine.
156: - Per card: repeatedly draw 4 stats, each uniform-random in `tier.ValueRange`, until the sum falls in `tier.Budget` AND the exact 4-tuple hasn't been used yet in this suit (rejection sampling — a `do { ... } while (...)` loop).
157: - Card IDs assigned sequentially starting at 1, incrementing across the entire generation — id 1 is Spade 1★ #1, and ids run through all 5 tiers of Spades (1–138), then all 5 tiers of Hearts (139–276), then Diamonds (277–414), then Clubs (415–552).
158: - Naming: `"{SuitSingular} {suitIndex}"` where `suitIndex` restarts at 1 per suit and increments across all 5 tiers within that suit (not per-tier) — "Spade 1".."Spade 138", "Heart 1".."Heart 138", etc. `S→Spade, H→Heart, D→Diamond, C→Club`.
159: - `stats` array index meaning: **[0: Top, 1: Right, 2: Bottom, 3: Left]**.
160: 
161: ### Acceptance test vectors (bit-exact, extracted from the real mac generator)
162: 
163: `GenerateAllCards(seed: 1)` — total count 552; these specific (index, id, name, stars, stats, suit) tuples:
164: 
165: ```
166: idx 0:   id=1   name="Spade 1"    stars=1 stats=[4,4,4,2]   suit=S
167: idx 1:   id=2   name="Spade 2"    stars=1 stats=[3,1,4,5]   suit=S
168: idx 2:   id=3   name="Spade 3"    stars=1 stats=[3,4,2,4]   suit=S
169: idx 25:  id=26  name="Spade 26"   stars=1 stats=[2,5,4,2]   suit=S
170: idx 26:  id=27  name="Spade 27"   stars=2 stats=[3,4,4,6]   suit=S   (first tier-2 card — tier boundary check)
171: idx 61:  id=62  name="Spade 62"   stars=2 stats=[2,7,1,7]   suit=S
172: idx 62:  id=63  name="Spade 63"   stars=3 stats=[6,6,5,3]   suit=S   (first tier-3 card)
173: idx 102: id=103 name="Spade 103"  stars=3 stats=[3,8,5,5]   suit=S
174: idx 103: id=104 name="Spade 104"  stars=4 stats=[6,7,7,5]   suit=S   (first tier-4 card)
175: idx 123: id=124 name="Spade 124"  stars=4 stats=[7,7,3,7]   suit=S
176: idx 124: id=125 name="Spade 125"  stars=5 stats=[7,7,9,6]   suit=S   (first tier-5 card)
177: idx 137: id=138 name="Spade 138"  stars=5 stats=[10,4,8,8]  suit=S   (last Spade card)
178: idx 138: id=139 name="Heart 1"    stars=1 stats=[2,5,3,5]   suit=H   (first Heart card — suit boundary check)
179: idx 139: id=140 name="Heart 2"    stars=1 stats=[2,6,3,4]   suit=H
180: idx 275: id=276 name="Heart 138"  stars=5 stats=[5,10,10,5] suit=H   (last Heart card)
181: idx 413: id=414 name="Diamond 138" stars=5 stats=[10,6,2,10] suit=D  (last Diamond card)
182: idx 551: id=552 name="Club 138"   stars=5 stats=[10,7,2,6]  suit=C   (last card overall)
183: ```
184: 
185: `GenerateAllCards(seed: 42)` — total count 552; these tuples:
186: 
187: ```
188: idx 0:   id=1   name="Spade 1"    stars=1 stats=[6,2,2,3]  suit=S
189: idx 1:   id=2   name="Spade 2"    stars=1 stats=[3,5,2,4]  suit=S
190: idx 137: id=138 name="Spade 138"  stars=5 stats=[9,7,8,3]  suit=S
191: idx 138: id=139 name="Heart 1"    stars=1 stats=[2,2,2,7]  suit=H
192: idx 551: id=552 name="Club 138"   stars=5 stats=[6,2,8,9]  suit=C
193: ```
194: 
195: These two seeds, exercising tier boundaries, suit boundaries, and the very first/last cards, are enough to catch essentially any off-by-one in loop ordering, id assignment, or the rejection-sampling condition. **All of these must match exactly.** Also port the existing mac structural tests as-is (they check general invariants, not exact values) from `HoneycombCardGeneratorTests.swift:13-63`: total=552, each suit has exactly 138 cards, each suit's per-tier counts match the table above, every card's stat sum is within its tier's budget, no in-suit duplicate 4-stat combos, and different seeds produce different pools.
196: 
197: ### `HoneycombDatabase` (`HoneycombDatabase.swift`)
198: 
199: - Singleton (`HoneycombDatabase.Shared`), lazily constructed.
200: - On construction: load a persisted seed from `honeycomb_seed.json` if present, else generate a random `ulong` and persist it. Generate `AllCards` from that seed.
201: - `Card(int id)` — linear lookup (`AllCards.First(c => c.Id == id)`), returns nullable.
202: - `RandomCards(int stars, int count)` — filter to the star tier, then pick `count` cards **with replacement** (duplicates allowed) uniformly at random.
203: - `Reseed()` — generate a fresh random seed, persist it, regenerate `AllCards`. Used by Start Over.
204: - `RulesAwareCards(int stars, int count, bool preferLowStats)` (`HoneycombDatabase.swift:60-106`) — used for AI hand composition:
205:   1. `SpecializationScore(stats) = sum(stats) + variance(stats)` where `variance = mean((stat - mean)^2)` over the 4 stats.
206:   2. Sort the tier pool by this score: ascending if `preferLowStats`, descending otherwise.
207:   3. `candidateCount = max(count, ceil(sortedPool.Count * 0.4))` — top 40% of the sorted pool (or at least `count`) is the candidate window.
208:   4. Greedy weighted pick, `count` iterations: track `edgeCounts[4]` (how many already-picked cards have each of the 4 stat-indices as their dominant/max value). Weight each remaining candidate `1.0 / (edgeCounts[DominantEdge(card)] + 1)`, do a weighted-random draw (cumulative-sum technique), remove the pick from the candidate pool, bump that edge's count. This biases the AI's hand toward covering different dominant stats rather than stacking similar specialists.
209:   5. If candidates run out before `count` is reached, fall back to a uniform-random pick from `sorted` (top `candidateCount`).
210:   6. `DominantEdge(card)` = index of the max stat value — on ties, use Swift's `max(by:)` semantics, which returns the **first** element achieving the max when comparing left-to-right with `<` (i.e., iterate stats 0→3, track the running max index, only replace it on strictly-greater, never on tie) — this is a real behavioral detail, don't use `IndexOf(Max())`-style code that might pick the last tied index instead.
211: 
212: ### `HoneycombCard` (instance wrapper, `HoneycombCard.swift:45-50`)
213: 
214: ```csharp
215: public int Stat(int index)
216: {
217:     int val = Data.Stats[index] + Modifier;
218:     return Math.Min(10, Math.Max(1, val));
219: }
220: ```
221: `Modifier` is the live Ascension/Descension battle-time bonus (see Phase 2); `Data.Stats` (base values) are never mutated. **UI always displays the unclamped base `Data.Stats[i]`**, not `Stat(i)` — the modifier shows as a separate `+N`/`-N` badge. Only combat math (captures, AI heuristics) uses the clamped `Stat(i)`.
222: 
223: ---
224: 
225: ## Phase 2 — Board & Capture Rules Engine
226: 
227: **Build:** `HoneycombBoard.cs`, rule enum in `HoneycombTypes.cs`.
228: 
229: ### The 11 rules (`HoneycombBoard.swift:3-15`)
230: 
231: ```csharp
232: public enum HoneycombRule
233: {
234:     Ascension, Descension, Same, Plus, FallenAce, Reverse, AllOpen, ThreeOpen, Swap, Order, Chaos
235: }
236: ```
237: There is no "Elemental" rule and no "Sudden Death" rule entry — Sudden Death is an automatic tie-break game state, not a selectable rule (see Phase 5).
238: 
239: ### Board state
240: 9-cell array (row-major, `index = row*3 + col`), each cell either empty or holding a placed card + owner. Also track: `SessionSamePlusTriggers`, `SessionFallenAceCaptures` (running match counters), transient per-placement flags `LastSameTriggered`, `LastPlusTriggered`, `LastFallenAceTriggered`, `LastComboFlipCount` (reset to false/0 at the start of every `PlaceCard`), and `AscensionDescensionSuits` (the 2 suits Ascension/Descension affect this match, rolled once in the ViewModel's `SetupRules`).
241: 
242: ### Neighbor/direction indices (`HoneycombBoard.swift:153-176`)
243: 
244: For a card at index `idx`: Top neighbor = `idx-3` (compare attacker's stat[0] vs neighbor's stat[2]); Right = `idx+1` (attacker stat[1] vs neighbor stat[3]); Bottom = `idx+3` (attacker stat[2] vs neighbor stat[0]); Left = `idx-1` (attacker stat[3] vs neighbor stat[1]). Out-of-bounds/edge-of-board neighbors don't exist — skip them (don't wrap rows/columns).
245: 
246: ### `PlaceCard(card, index, rules)` (`HoneycombBoard.swift:69-85`)
247: 
248: 1. Guard: index valid and cell empty — return empty flip-list otherwise (no-op).
249: 2. Place the card; reset the 4 per-placement trigger flags.
250: 3. `UpdateModifiers(rules)` — recompute Ascension/Descension modifier for **every occupied cell on the board**, including the one just placed, before resolving any captures.
251: 4. `ResolveCaptures(index, rules, isCombo: false)` — returns the list of flipped cell indices.
252: 
253: ### Ascension/Descension modifier (`HoneycombBoard.swift:87-107`)
254: 
255: For each occupied cell: `Modifier = 0` by default. If that card's suit is in `AscensionDescensionSuits`: under Ascension, `Modifier = SuitCount(suit)` (count of cards of that suit currently anywhere on the board); under Descension, `Modifier = -SuitCount(suit)`. Cards of unaffected suits always have `Modifier = 0`. **Recomputed from scratch every placement** — not cumulative/additive across turns.
256: 
257: `AscensionDescensionSuits` is rolled once per match, in the ViewModel: 2 suits chosen randomly without replacement from `{S,H,D,C}`, only when Ascension or Descension is an active rule; otherwise empty. It does **not** get re-rolled if the match goes to Sudden Death.
258: 
259: ### Capture comparison — `CanCapture(attackerStat, targetStat, rules)` (`HoneycombBoard.swift:109-140` region)
260: 
261: Check Fallen Ace exceptions **first** (only if the Fallen Ace rule is active):
262: - Fallen-Ace win: (not-Reverse AND attackerStat==1 AND targetStat==10) → true. (Reverse AND attackerStat==10 AND targetStat==1) → true.
263: - Fallen-Ace **blocked** loss (the mirror pairing is explicitly *disallowed* from winning via the normal higher/lower comparison, even though it normally would): (not-Reverse AND attackerStat==10 AND targetStat==1) → **false**, overriding what would otherwise be a normal win. (Reverse AND attackerStat==1 AND targetStat==10) → **false**.
264: 
265: This is a subtle, easy-to-get-wrong detail: **don't just add "1 beats 10"** — you must also explicitly suppress the "10 beats 1" case that the plain comparison would otherwise allow, or Fallen Ace effectively does nothing on the mirror direction.
266: 
267: Otherwise (no Fallen Ace exception applies): if Reverse is active, capture succeeds when `attackerStat < targetStat`; else succeeds when `attackerStat > targetStat`. Ties never capture, under either direction.
268: 
269: ### Same / Plus (`HoneycombBoard.swift:109-264` region — only evaluated on the initial placement, never during a combo chain)
270: 
271: 1. For each of the (up to 4) real neighbors of the placed card, compute the attacker's facing stat and the neighbor's opposite facing stat (using `Stat(i)`, the modifier-adjusted, clamped value — captures always use the live battle stat, not the base display stat).
272: 2. **Same**: a neighbor index qualifies if its facing stat exactly equals the attacker's matching facing stat.
273: 3. **Plus**: bucket neighbors by `sum = attackerStat + neighborStat` — group neighbor indices by that sum value.
274: 4. **Same fires** only if 2 or more neighbors qualify simultaneously. **Plus fires** independently, per sum-bucket, wherever a bucket has 2+ members.
275: 5. Union all matched indices from both triggers into one trigger set. `LastSameTriggered`/`LastPlusTriggered` are only set `true` if at least one matched neighbor is actually **enemy-owned** (i.e., will genuinely flip) — if every matched neighbor already belongs to the attacker, nothing visibly happens and it doesn't count toward `SessionSamePlusTriggers`.
276: 6. Every triggered index belonging to someone other than the attacker gets flipped **immediately** (owner reassigned) — this happens **regardless of what the normal higher/lower stat comparison would have said**. That's the entire point of Same/Plus: they bypass the ordinary capture check on the strength of the match alone. Add each flipped index to the combo queue for chain resolution.
277: 7. `SessionSamePlusTriggers` increments by exactly 1 (not by the number of cards flipped) if either Same or Plus flipped anything at all this placement.
278: 
279: ### Normal captures
280: 
281: For each real neighbor that's enemy-owned and wasn't already flipped by Same/Plus: apply `CanCapture`. On success: if it won specifically via the Fallen Ace exception, set `LastFallenAceTriggered = true`. Increment `SessionFallenAceCaptures` whenever the raw stat matchup is *exactly* `attackerStat==1 && targetStat==10` — this is a pure statistic tracked independently of which rule actually enabled the win (i.e., it also increments if Fallen Ace isn't even active but this exact matchup happens to occur and win via Reverse or a coincidental tie-break — track it purely off the numbers, not off "did Fallen Ace cause this"). Flip owner, add to the flip list. If this capture happened during a combo chain (`isCombo == true`), also push it onto the combo queue and increment `LastComboFlipCount`.
282: 
283: ### Combo chain
284: 
285: After direct captures resolve for the current cell, for every index queued during this resolution, recursively call `ResolveCaptures(index, rules, isCombo: true)`. **Same/Plus are skipped entirely on combo iterations** — only normal higher/lower (and Fallen Ace) captures cascade. Recurse until no cell produces any further captures. `LastComboFlipCount` counts only chain-reaction flips, not the initial placement's own direct captures — matches real Triple Triad "Combo" semantics.
286: 
287: ---
288: 
289: ## Phase 3 — AI Opponent
290: 
291: **Build:** `HoneycombAI.cs`.
292: 
293: ### Difficulty → algorithm
294: 
295: | Difficulty | Algorithm |
296: |---|---|
297: | Easy | Pure uniform-random legal (hand-index, cell-index) pair |
298: | Medium | 1-ply greedy — maximize this move's own immediate capture count; ties broken randomly |
299: | Hard | Minimax w/ alpha-beta, 2-ply lookahead, Fallen-Ace weighting **off** |
300: | Ultra Hard | Minimax w/ alpha-beta, 6-ply lookahead, Fallen-Ace weighting **on** |
301: 
302: **Hint** (any difficulty below Ultra Hard) always runs at Ultra Hard's exact settings (6-ply, Fallen-Ace weighting on), computed by mirroring board ownership (swap player/opponent tags so the same "maximize for the searching side" code finds the human's best move) and swapping which hand counts as "opponent's" for the search. Hint only ever considers opponent cards the player has actually been shown (via All Open/Three Open reveal) — never a still-hidden card.
303: 
304: ### Minimax (`HoneycombAI.swift:123-283` region)
305: 
306: - Alpha-beta pruning. Alternates maximizing (AI's simulated turn) / minimizing (player's simulated turn) per ply.
307: - Leaf/terminal conditions, checked in this order:
308:   1. Board full → return `(opponentScore - playerScore) * 1000`. The `1000` multiplier ensures any genuinely-decided line always outranks a heuristic-only leaf score.
309:   2. It's the player's simulated ply AND some player cards are still unrevealed to the AI → treat as a leaf immediately, score via the heuristic (don't "cheat" by continuing to search a hand the AI doesn't actually know).
310:   3. `depth == 0`, or no empty cells remain, or the acting side's deck is empty → heuristic leaf.
311: - **Move ordering** (pruning optimization only, doesn't change the chosen move): pre-simulate every (hand, cell) pair for the side to move, sort candidates descending by immediate capture count before recursing.
312: - **Top-level tie-break**: among moves tied for the best score, first filter to only those with the highest immediate capture count ("most aggressive"), then pick uniformly at random among what's left. (This is the accepted non-determinism — see top of doc.)
313: 
314: ### Heuristic — `PositionalEvaluation` (`HoneycombAI.swift:334-350`)
315: 
316: For each occupied cell: base score 10. For each of the 4 directions where the neighboring cell exists **and is currently empty** (occupied neighbors contribute nothing further — "that fight already happened"): add `ExposureValue(stat, reverse, fallenAce)`. The cell's signed contribution to the total: `+cardScore` if opponent(AI)-owned, `-cardScore` if player-owned. Plus `ComboPotential(board, rules)` added once, globally, not per-cell.
317: 
318: ```
319: ExposureValue(stat, reverse, fallenAce):
320:     effectiveStrength = reverse ? (11 - stat) : stat
321:     value = effectiveStrength - 5
322:     fallenAceVulnerableStat = reverse ? 1 : 10
323:     if fallenAce && stat == fallenAceVulnerableStat:
324:         value -= 3
325:     return value
326: ```
327: (Centers around 0 — a mid-strength stat is roughly neutral. The Fallen-Ace `-3` penalty only applies when Fallen-Ace weighting is enabled, i.e. Ultra Hard's own moves and the Hint search — Hard difficulty never applies it.)
328: 
329: `ComboPotential(board, rules)` (`HoneycombAI.swift:375-409`) — zero unless Same or Plus is active. For every **empty** cell: gather `(owner, facingStat)` for each occupied neighbor, where facing stat = that neighbor's stat pointing *toward* the empty cell (i.e. index `(direction + 2) % 4` from the neighbor's own stat array). Per owner side with 2+ facing stats gathered: `sameMatches` = count of pairs with exactly equal facing stat (only counted if Same is active); `plusMatches` = count of *all* pairs regardless of value (only counted if Plus is active — treated as an always-live threat, since almost any two stats can be completed by some attacker). `weight = 6*sameMatches + 3*plusMatches`, added positively if it threatens the player's cards (AI could exploit it), negated if it threatens the AI's own cards.
330: 
331: ### Difficulty → deck composition (`HoneycombViewModel.swift:535-590`)
332: 
333: Normal (non-Reverse) hand composition — `(stars, count)` pairs, concatenated:
334: - Easy: (1★,4), (2★,1)
335: - Medium: (2★,4), (3★,1)
336: - Hard: (3★,3), (4★,1), (5★,1)
337: - Ultra Hard: (3★,2), (4★,1), (5★,2)
338: 
339: Reverse hand composition (used instead when Reverse is the active rule — deliberately weighted toward *low* stats since Reverse makes low values strong):
340: - Easy: (3★,3), (4★,1), (5★,1)  ← reuses Hard's *normal* table
341: - Medium: (2★,4), (3★,1)  ← reuses its own normal table
342: - Hard: (1★,2), (2★,3)
343: - Ultra Hard: (1★,5) — all five cards 1★, the lowest possible tier
344: 
345: For each `(stars, count)` pair, call `HoneycombDatabase.Shared.RulesAwareCards(stars, count, preferLowStats: reverseActive)` and concatenate the results into the opponent's hand.
346: 
347: ---
348: 
349: ## Phase 4 — Deck/Collection System
350: 
351: **Build:** `HoneycombDeck.cs` (`HoneycombProfileManager` + `HoneycombDeckState`).
352: 
353: ### `HoneycombProfileManager` — persisted state
354: - `UnlockedCardIds` (set of ids) — `honeycomb_unlocked_cards.json`
355: - `SavedDecks` — exactly 5 `HoneycombDeckState { string Name; List<int> CardIds; }` slots — `honeycomb_saved_decks.json`
356: - `FavoriteCardIds` (set of ids) — `honeycomb_favorite_cards.json`
357: 
358: ### First-run initialization (`HoneycombDeck.swift:25-57`)
359: - No unlocked-cards file yet → starter unlock = 3 random 1★ cards + 2 random 2★ cards (`RandomCards`).
360: - No saved-decks file yet → 5 empty slots created; if exactly 5 starter ids exist, slot 0 is named `"Default"` and populated with those 5 ids (see "Accepted non-determinism" above re: draw order).
361: 
362: ### Deck validation (`HoneycombDecksView.swift:357-380`, mirrored in `HoneycombViewModel.swift:1165-1179` for the steal flow) — apply this exact rule set anywhere a 5-card deck is being saved or a steal/swap is being validated:
363: 
364: ```
365: fiveStars = count of 5★ cards in the proposed 5-card deck
366: fourStars = count of 4★ cards
367: 
368: if fiveStars > 1:
369:     reject — "A deck can never contain more than one 5★ card."
370: else if fiveStars == 1 && fourStars > 1:
371:     reject — "If you have a 5★ card, you can only have one 4★ card."
372: else if fiveStars == 0 && fourStars > 2:
373:     reject — "A deck can never contain more than two 4★ cards."
374: else if deckNameLength > 20:
375:     reject — "Deck name cannot exceed 20 characters."
376: else:
377:     valid
378: ```
379: Deck Builder additionally requires exactly 5 cards and a non-empty name before Save is enabled.
380: 
381: ### Start Over (already implemented on both platforms as of the most recent mac/windows change — this section documents the *current* correct behavior, already shipped, just needs the exact same logic in Honeycomb's own persistence)
382: 
383: - Wipe all 5 slots empty; rename slot 0 to `"Default"`.
384: - Read slot 0's *previous* card ids, map each to its star tier. If slot 0 was empty, fall back to the default starter composition `[1,1,1,2,2]` (three 1★, two 2★).
385: - For each star value in that composition, draw one **freshly random** card of that tier (`RandomCards(stars, 1)`) — so a deck that was e.g. one-5★/one-4★/three-3★ regenerates that same *composition* with brand-new specific cards, not the literal same card ids.
386: - Reset `UnlockedCardIds` to exactly the new slot-0 ids; clear `FavoriteCardIds` entirely.
387: - Caller also calls `HoneycombDatabase.Shared.Reseed()` (fresh seed → all-new card stats across the whole 552-card pool) and resets the active-deck-index option to 0.
388: 
389: ### Card capture → unlock ("Take a Card" / steal), `HoneycombViewModel.swift:1183-1257`
390: - Reachable only once per match, post-win (`HasStolenThisMatch` flag, reset at match start).
391: - Eligibility: the board card's original owner (before any Swap) was the opponent, its current owner is the player (i.e. genuinely captured this match, not merely swapped-and-abandoned), and its id isn't already in `UnlockedCardIds`.
392: - The hypothetical resulting deck (swap one of the player's 5 active-deck cards for the incoming card) must pass the exact same rarity-cap validation as the Deck Builder — reject with an alert if it fails, otherwise proceed.
393: - Two-step confirm flow: staging a pending swap (shows a confirmation prompt) → confirming actually applies it (`UnlockCard`, increment stolen-count stat, set `HasStolenThisMatch = true`, mutate the in-session active hand — **not yet written to the saved deck slot**).
394: - A separate explicit "Save to slot N" action is what actually persists the in-session hand override into a chosen saved-deck slot (keeps that slot's existing name, replaces its cards). No-op if No Stress Mode is on.
395: 
396: ### Favorites
397: Simple toggle, persisted immediately on every change. Only togglable from the Card Bank browse grid, not from inside the Deck Builder's card-picker (avoids an ambiguous tap meaning in that context).
398: 
399: ### No Stress Mode deck
400: Bypasses saved decks entirely — every match deals a fresh random deck of exactly one 5★ + one 4★ + three 3★ (via `RandomCards` per tier), the strongest composition that still respects the rarity caps.
401: 
402: ---
403: 
404: ## Phase 5 — Match ViewModel (orchestration)
405: 
406: **Build:** `HoneycombViewModel.cs`, following `BlackjackViewModel.cs`'s exact structural pattern: `[ObservableProperty]` top-level `State`/`Options`/`Stats` fields, computed properties as plain `=>` expressions, a `NotifyStateChanged()`-style helper that fires `OnPropertyChanged` for every dependent computed property after mutating actions.
407: 
408: ### Rule selection / "roulette" (`HoneycombViewModel.swift:442-487`)
409: - Force-Normal toggle on → zero active rules, no roulette.
410: - Else, if the player's manually-selected rule set is empty → **roulette**: pick a random count in `0..2` rules from all 11 (Reverse *is* included in the roulette pool, unlike the manual picker), enforcing 3 exclusivity pairs — Ascension↔Descension, Order↔Chaos, AllOpen↔ThreeOpen — by removing the paired rule from the pool once its counterpart is picked. **On Easy difficulty, additionally exclude Ascension, Descension, and Fallen Ace from the roulette pool entirely** (too punishing for a new player).
411: - Else → use the manual selection directly (max 2, enforced live in the Options UI).
412: - **Reverse is never manually selectable** — filter it out of whatever rule-picker UI you build; it's roulette-only, since it's "too easily exploited to pick on purpose" (per the actual mac help text). If you ever decode an old options file with Reverse manually selected, strip it.
413: 
414: ### Turn order (`HoneycombViewModel.swift:350-391`)
415: - Normal coin toss, but with "bad luck protection": track a running streak of consecutive matches with the same starter; once that streak hits 3, force the 4th match to start with the other side. This streak persists across matches within the app session (not reset per-match, not persisted across app restarts).
416: - After a side's turn "starts," the AI's actual move is delayed 2.5 seconds before landing (purely a UX pace beat — skip this delay entirely in any headless/test code path).
417: 
418: ### Win condition (`HoneycombViewModel.swift:1068-1104`)
419: When the board fills: `playerScore = cardsOnBoardOwnedByPlayer + cardsStillInPlayerHand` (every card the player owns anywhere counts), same for opponent. Higher score wins outright. Equal scores → Sudden Death.
420: 
421: ### Sudden Death (`HoneycombViewModel.swift:1106-1146`)
422: Not a rule — an automatic tie-break. Collect every card each side currently owns (board + hand), reset every card's `Modifier` to 0 (a leftover Ascension/Descension bonus doesn't carry into the fresh board), build a brand-new empty board, reuse the **same** `AscensionDescensionSuits` rolled for the original match (don't re-roll), flip who starts, continue play under the same active rules. Track a `SuddenDeathCount` stat, incremented here directly (not through the normal end-of-match stats recording).
423: 
424: ### Other rule mechanics
425: - **All Open / Three Open** (mutually exclusive): reveal both hands to both sides symmetrically — not just opponent-to-player. All Open reveals every card id in the deck up front. Three Open reveals a random 3-of-5 per hand, and that specific revealed-card identity stays tracked as cards are played (not "3 random cards at any given moment").
426: - **Swap** (`HoneycombViewModel.swift:659-675`): before the match begins, one uniformly-random card index from each hand trades hands (owner reassigned; `OriginalOwner` preserved for later steal-eligibility/unlock purposes). Identity-preserving — the same card object moves, so a UI animation can track it. Stage this as a short multi-beat animation if your UI supports it (mac does: highlight the two real pre-swap cards + a "Swap!" banner, then the actual swap, then clear the highlight — timing isn't load-bearing, just don't do it instantly with zero feedback).
427: - **Order**: the player's legal hand index each turn is always index 0 (falls out naturally as earlier cards are removed and the rest shift up — no special logic needed beyond "restrict legal plays to index 0").
428: - **Chaos**: the legal hand index is randomly re-rolled the instant that side's turn begins (not fixed at match start) — re-roll on every turn transition for the side under Chaos. Order and Chaos are mutually exclusive.
429: 
430: ### Undo (`HoneycombViewModel.swift:937-997`) — Honeycomb needs this, Blackjack doesn't have it; **follow `SpiderViewModel.cs`'s undo-stack pattern instead** (a `Stack<HoneycombSnapshot>`, pushed before every player placement, popped in `Undo()`).
431: 
432: Snapshot must capture: board state, player hand, opponent hand, the open/revealed-card-id sets for both sides, whose turn it is, the running captured-cards-this-match counter, and the Chaos mandated-index for both sides if Chaos is active. `CanUndo` requires: undo stack non-empty AND match is actively playing AND it's currently the player's turn AND no placement-animation is mid-flight. Undo only ever rewinds to the start of the player's own turn — never into the middle of an AI turn.
433: 
434: ### Hint — surface `HoneycombAI`'s Hint search (Phase 3) as a `FindHint()`-style method mirroring `SpiderViewModel.FindHint()`'s shape: run the search, store the resulting suggested (hand-index, cell-index) as an active-hint value the View highlights for ~2 seconds, gated by an options toggle to hide the Hint button entirely if the player wants it off.
435: 
436: ### Stats recording (`HoneycombStats.swift`)
437: 
438: Fields (all ints, default 0): `GamesPlayed, MatchesWon, MatchesLost, MatchesDrawn, CardsCaptured, CurrentWinStreak, LongestWinStreak, FlawlessVictories, SamePlusTriggers, UltraHardWins, TimesStartedOver, EasyWins, MediumWins, HardWins, CardsStolen, FallenAces, SuddenDeathCount`.
439: 
440: `RecordGame(won, drawn, captures, sessionCombos, flawless, difficulty, fallenAceCaptures)` logic:
441: - Always: `GamesPlayed++`, `CardsCaptured += captures`, `SamePlusTriggers += sessionCombos`, `FallenAces += fallenAceCaptures`.
442: - Drawn: `MatchesDrawn++`, `CurrentWinStreak = 0`.
443: - Won: `MatchesWon++`, `CurrentWinStreak++` (bump `LongestWinStreak` if exceeded), `FlawlessVictories++` if the opponent's score was exactly 0, plus the matching per-difficulty win counter (`EasyWins`/`MediumWins`/`HardWins`/`UltraHardWins`).
444: - Lost: `MatchesLost++`, `CurrentWinStreak = 0`.
445: 
446: `SuddenDeathCount` is incremented directly inside the Sudden Death trigger, not through `RecordGame`.
447: 
448: ---
449: 
450: ## Phase 6 — Main Game View (board + hands)
451: 
452: **Build:** `HoneycombView.axaml`/`.axaml.cs`, `HoneycombCardView.axaml`/`.axaml.cs`.
453: 
454: **Reuse from the existing codebase — do not reinvent:**
455: - Overall imperative rendering pattern: subscribe to `vm.PropertyChanged` in the View's `Loaded` handler, do one full `Refresh(vm)` re-render pass on every notification — copy this shape from `BlackjackView.axaml.cs`.
456: - Felt background/vignette: **don't paint your own felt** — the window level already handles this (`MainWindow.ApplyFeltColor`); `BlackjackView` only computes the hex color for reference, it doesn't paint anything itself. Do the same.
457: - Button styling: reuse `Button.light-primary`/`light-secondary`/`banner-action`/`banner-close` from `App.axaml` wherever they fit (Start Match/Quit Match/Options/rematch prompts, etc.) rather than defining new colors. Only truly Honeycomb-specific one-off button colors (if any) should be defined locally in `HoneycombView.axaml`'s own `<UserControl.Styles>`, the same way Blackjack keeps its yellow Buy-In / purple Split buttons local instead of app-wide.
458: - Suit + star glyphs: **use Unicode text glyphs, not an icon package.** The existing `CardView.axaml` already renders suits via `TextBlock FontFamily="Segoe UI Symbol,Apple Symbols,sans-serif"` with `♠ ♥ ♦ ♣` characters — do the same for Honeycomb's suit icon and use `★`/`☆` for the star rating and favorite-heart toggle (`♥`/`♡`), all as plain `TextBlock` glyphs. No `PathIcon`, no Material icon package — none exists in this project yet and introducing one is out of scope.
459: - `HoneycombCardView` is a **from-scratch control** — mac's card format (4 edge-numbers, star rating, suit glyph) has nothing in common with the existing `CardView`'s standard playing-card rank/pip layout, so don't try to extend/reuse `CardView.axaml.cs`. Do follow its *structural* conventions: a fixed-size root `Grid`, a `CardBack` `Border` toggled via `IsVisible` for face-down state, a static brush/bitmap cache instead of per-render allocation (mirroring the `_brush*` static pool pattern CLAUDE.md calls out), and `Viewbox`-wrapping if cards need to render at different sizes in different contexts (hand vs. board vs. deck-builder thumbnail).
460: 
461: **Layout to replicate** (`HoneycombView.swift:248-364` region, `HoneycombCardView.swift` full file):
462: - Window/panel layout: player hand column — spacer — board+rules-banner column — spacer — opponent hand column, left to right.
463: - Hand layout: 2-2-1 pyramid (2 cards top row, 2 middle row, 1 bottom-centered), not a straight row or grid.
464: - Board: 3×3 grid of cells, empty cells rendered as a plain rounded rectangle placeholder.
465: - Rules banner sits directly above the board. **Bottom-align it within its reserved height** so a second active-rule line grows the banner *upward* into empty space rather than pushing the board down — this exact bug was already found and fixed on mac (see `HoneycombView.swift`'s `rulesBanner`, `.frame(height:alignment:.bottom)`); replicate that fix from day one rather than shipping the bug and fixing it later. Shows "Rules:" header plus one line per active rule (or "Normal"/"Roulette" before a match starts); Ascension/Descension lines append the 2 affected suit names.
466: - Card visual: suit glyph centered (large), 4 edge-position stat numbers (Top/Right/Bottom/Left), star rating displayed over/near the suit glyph (layout varies slightly by star count and suit in mac — 1-3 stars single row, 4 stars 2×2, 5 stars 3-over-2 or 2-over-3 depending on suit; feel free to simplify to a single consistent 5-star layout on Windows if an exact suit-dependent asymmetry isn't worth the complexity — this is the one place where 100% pixel parity isn't required, just "clearly shows N stars"). Displays `"A"` for a stat value of 10, otherwise the digit
The above content was truncated because individual lines are very long. Only a portion of the content is shown.

========================================
STEP: 8
Created At: 2026-07-22T11:42:23-04:00
Completed At: 2026-07-22T11:42:23-04:00
File Path: `file:///Users/leah/.claude/plans/as-you-know-we-mutable-owl.md`
Total Lines: 548
Total Bytes: 59640
Showing lines 1 to 548
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
1: . Numbers/suit glyph render black for player-owned, red for opponent-owned — **this overrides the card's natural suit color** (an opponent-owned heart card still renders in red, not its natural red — same color either way here, but a player-owned spade renders black same as natural; the point is ownership color always wins over suit color, they just happen to coincide for red suits under mac's black/red scheme). Modifier badge (`+N`/`-N`) in a corner when Ascension/Descension is boosting/penalizing that card. A brief highlight/flash on the specific winning stat(s) just before a capture visually resolves (gate this behind the point-highlights options toggle). A 180°-flip animation when a card's owner changes (color-swap should happen at the animation's midpoint, when the card is edge-on/invisible, so the flip never visibly shows the "wrong" color mid-flip).
2: - Toolbar: Start Match/Quit Match, Options, Manage Decks (pre/post-match) vs Hint/Undo (mid-match), score display once a match is live.
3: - Post-game overlay: win/lose result with New Game / Rematch / Steal Card actions.
4: - Wiring into `MainWindow`/`AppCoordinator` (see Phase 9) needs a new toolbar-chrome category — Honeycomb isn't a solitaire game but (unlike Blackjack/VideoPoker) it *does* need Hint and Undo, so the existing `isCardGame` boolean gate in `MainWindow.ApplyGameSwitch` can't just be reused as-is; add a category that shows Hint/Undo for solitaire games *and* Honeycomb, while still hiding solitaire-only chrome (Restart, stat panel) that doesn't apply to Honeycomb.
5: 
6: ---
7: 
8: ## Phase 7 — Deck Builder / Card Bank Window
9: 
10: **Build:** `HoneycombDecksWindow.axaml`/`.axaml.cs`.
11: 
12: Replicate `HoneycombDecksView.swift`'s structure: left panel = the 5 saved-deck rows (name or "Empty Slot N", "(Active)" tag, Set Active / Create-Edit button, small card-preview row) plus a "Start Over" panel with a destructive confirmation prompt; right panel = the full Card Bank grid with a filter bar (star-tier filter, suit filter, Favorites-only toggle, Clear-filters button) and a favorite-heart toggle overlay per card. The Deck Builder itself opens as a sub-view/dialog: deck-name text field (max 20 chars, editable even after saving — matches the "allow editing deck names once saved" fix already shipped on mac and windows for the saved-decks list itself, so don't reintroduce a name-lock here either), a 5-slot "your deck" row (tap to remove), the Card Bank grid below it (tap to add; already-in-deck cards shown dimmed), live validation error text (rules in Phase 4), Save disabled until valid + full + named.
13: 
14: ---
15: 
16: ## Phase 8 — Stats Window
17: 
18: **Build:** `HoneycombStatsWindow.axaml`/`.axaml.cs`.
19: 
20: Replicate `HoneycombStatsView.swift`'s grouped stat rows: Games Played/Won/Lost/Drawn/Sudden Deaths/Win Rate; streak + flawless-victory + per-difficulty win counts; captures/Fallen-Aces/combos/steals/start-overs; total card-bank unlock progress plus per-suit and per-star unlock breakdowns (computed live from `HoneycombDatabase.AllCards` vs `UnlockedCardIds`, not persisted). Win rate = `MatchesWon / (GamesPlayed - MatchesDrawn) * 100`. Include a destructive, confirmed "Reset Stats" action and a Close button.
21: 
22: ---
23: 
24: ## Phase 9 — Wiring & Help Text
25: 
26: ### Wiring into the app shell
27: 
28: - `AppCoordinator.cs`: add `[ObservableProperty] private HoneycombViewModel _honeycombViewModel;`, a `SwitchToHoneycomb()` method mirroring `SwitchToBlackjack()`, and a new arm in every `switch (ActiveViewModel)` block (`CanUndo`, `Undo()`, `ResetStatistics`, `ApplyTheme`, `TriggerWinAnimation`) — Honeycomb needs real arms in `CanUndo`/`Undo()` (unlike Blackjack/VideoPoker's `false`/no-op fallthrough), since it has real Undo support.
29: - `MainWindow.axaml`: add a `ComboBoxItem Tag="Honeycomb"` to the game-selection combo box.
30: - `MainWindow.axaml.cs`: add a `tag == "Honeycomb"` branch to `ApplyGameSwitch` instantiating `new HoneycombView { DataContext = _coordinator.HoneycombViewModel }`; add `Honeycomb` to `GameModeToIndex`/its reverse mapping; add window-size-restore entries (the `RestoreWindowSizeForGame` switch and the persisted-size property additions to `GameOptions.cs`/`SettingsService.cs`, per the Architecture Decisions section above); extend the `isCardGame`-style toolbar-chrome gate as described in Phase 6.
31: 
32: ### Help window content
33: 
34: Add a `HoneycombAnchor` section to `HelpWindow.axaml` (index entry + `GoTo_Honeycomb` handler in the code-behind, following the exact anchor/index/content-block pattern every other game's help section already uses — see `BlackjackAnchor`/`GoTo_Blackjack` as the template). Use this content, adapted only for Windows' click-based interaction (mac describes drag-or-tap-then-tap; Windows should describe whatever your actual input model ends up being — click-to-select-then-click-to-place is the natural equivalent) — this is mac's actual shipped help copy, quoted in full so there's no ambiguity about what each rule should say:
35: 
36: > **Objective** — Battle an AI opponent on a 3×3 grid. Place your 5 cards one at a time; when a placement's facing stat beats an adjacent enemy card's opposite facing stat, you capture it. Whoever controls more of the 9 cells once the board fills wins the match.
37: >
38: > **How to Play** — [adapt for Windows input model; mac: "Drag a card from your hand onto any empty board cell, or tap a hand card to select it and then tap an empty cell."] You and the dealer alternate turns until the board is full.
39: >
40: > **Capturing & Combos** — Each card shows 4 stats — Top, Right, Bottom, Left. Placing a card next to an enemy card compares your facing stat to their opposite facing stat; the higher value flips the loser to your side (10 is shown as "A"). A card captured this way can immediately capture its own neighbors in a chain reaction, called a Combo.
41: >
42: > **Match Rules Overview** — Up to 2 rules can be active per match, chosen in Options before you Start Match. Ascension and Descension can't both be picked (they're opposites), and neither can Order and Chaos. Leave rule selection empty (and Normal Mode off) and Roulette randomly rolls 0–2 rules for you every match instead — Roulette is also the only way Reverse can appear, since it's too easily exploited to pick on purpose.
43: >
44: > **Ascension / Descension** — At the start of the match, 2 of the 4 suits are randomly chosen to be affected. Under Ascension, every card of an affected suit gains +1 to all four of its stats for each card of that suit currently on the board — recalculated before every placement's captures resolve, so the bonus grows as more of that suit hits the table. Descension is the same idea in reverse: −1 per card of that suit on the board. A card of an unaffected suit plays completely normally.
45: >
46: > **Same** — If 2 or more of a placed card's touching neighbors have a facing stat exactly equal to the attacker's matching facing stat, every one of those matching neighbors is captured at once — not just the strongest one. Your own adjacent cards count toward the trigger too, not only the dealer's, so a placement boxed in by 2 of your own matching cards can still fire Same (this is intentional, not a bug).
47: >
48: > **Plus** — If 2 or more touching neighbor pairs each sum (attacker's facing stat + that neighbor's facing stat) to the same total as each other, every card in that matching group is captured — even if the shared sum isn't the attacker's own stat. Like Same, your own adjacent cards count toward the trigger.
49: >
50: > **Fallen Ace** — A card showing a 1 that attacks a card showing a 10 ("A") always captures it, overriding the normal higher-beats-lower comparison — a 1 is the one value that can topple an Ace. Under Reverse, this flips too: an attacking 10 always captures a defending 1.
51: >
52: > **Reverse** — Capture direction is fully inverted: the attacker wins when its facing stat is lower than the defender's, not higher. Reverse only ever appears via Roulette, never by manual selection — the AI's own deck (and, under Fallen Ace, its capture math) is specially adjusted per difficulty so a nominally "easy" opponent doesn't become trivial under the inversion.
53: >
54: > **All Open / Three Open** — All Open reveals the dealer's entire hand face-up for the whole match; Three Open reveals exactly 3 random cards from it, staying revealed by that specific card's identity as the hand shrinks. Either way the reveal is symmetric — the dealer's AI gets the same look at your hand it's giving you, so nobody's playing with hidden information the other side lacks.
55: >
56: > **Swap** — Before the first turn, one random card from your hand trades places with one random card from the dealer's hand. The swapped card plays for whoever now holds it, but for Card Bank unlock and post-win steal eligibility it still belongs to its original owner if you don't recapture it during the match.
57: >
58: > **Order / Chaos** — Order restricts your legal play each turn to strictly the next card in your original deck order — no choosing. Chaos instead re-rolls one random legal card the instant a side's turn begins, highlighted with a thick yellow border; you'll see the dealer's mandated card highlighted at least 2 seconds before its AI actually plays it.
59: >
60: > **Sudden Death** — A 5-5 tie sends the match into Sudden Death: the board clears and immediately replays with each side's exact end-of-round cards, alternating who starts, until someone wins outright.
61: >
62: > **Difficulty** — Easy plays randomly. Medium greedily maximizes its own captures each turn. Hard and Ultra Hard search several moves ahead using a full positional evaluation, with Ultra Hard also fielding the strongest overall deck.
63: >
64: > **Hint** — On any difficulty below Ultra Hard, the Hint button suggests the strongest card-and-cell placement — found with the same search Ultra Hard's own AI uses — highlighting it for 2 seconds. It only ever considers dealer cards you've actually been shown, never one still hidden from you.
65: >
66: > **Card Bank & Decks** — Winning a card isn't automatic — after a win, you may [drag/click, per your input model] one card the dealer played that round onto one of your 5 active deck slots, permanently unlocking it into your Card Bank. This steal is capped at one per match; Rematch (or start a new match) to steal again. Build named decks from Manage Decks, subject to rarity caps: at most one 5★ card, and at most one 4★ if a 5★ is already in the deck (otherwise up to two 4★).
67: >
68: > **No Stress Mode** — Deals a fixed, strong deck every match (one 5★, one 4★, three 3★) instead of your chosen active deck, and hides Steal Card — a relaxed way to play without managing a collection. This is a shared setting — enabling it here also enables it across the other games.
69: 
70: ---
71: 
72: ## Verification / acceptance criteria
73: 
74: Run in order — each phase's tests must pass before starting the next phase's implementation:
75: 
76: 1. **Phase 1**: `dotnet test --filter "FullyQualifiedName~HoneycombCardGeneratorTests"` — raw `SplitMix64` vectors, both seed-1 and seed-42 full generated-card vectors, plus the ported structural tests (counts/budgets/no-duplicates), all green.
77: 2. **Phase 2**: `HoneycombBoardTests.cs` — hand-construct board states exercising: a plain higher-beats-lower capture, a Reverse capture, Same firing across 2+ neighbors (including the "boxed in by your own matching cards" case), Plus firing on a shared sum, a combo chain flipping a second card, Fallen Ace's win case AND its blocked-mirror case (both directions, under both Reverse states), Ascension modifier scaling as suit count grows, Descension going negative, edge/corner cells correctly having fewer neighbors.
78: 3. **Phase 3**: `HoneycombAITests.cs` — Easy AI never crashes and always plays a legal move over many random trials; Medium AI always picks an available immediate-capture move when one exists; Hard/Ultra-Hard AI picks a move at least as good (by the heuristic) as a hand-picked "obviously bad" alternative in a constructed scenario; `RulesAwareCards` under `preferLowStats=true` returns lower-average-total cards than `preferLowStats=false` for the same tier.
79: 4. **Phase 4**: deck-validation rule tests (each rejection message, each boundary — exactly one 5★ allowed, exactly two 4★ when no 5★, etc.), Start Over composition test (mirroring the existing mac/windows `computeStartOverDecks`-style pure-function test — given a previous deck's star composition, assert the redrawn deck matches that composition with different specific card ids).
80: 5. **Phase 5**: `HoneycombViewModelTests.cs` — full match flow smoke test (place all 5 player + 5 opponent cards, verify board fills, winner determined correctly by score); Sudden Death triggers correctly on a tied board and preserves `AscensionDescensionSuits`; Undo restores the exact pre-placement state; stats recording increments the right counters for a won/lost/drawn/flawless match.
81: 6. **Phase 6–8 (UI)**: manual verification — run the Windows app, switch to Honeycomb from the game selector, play a full match against each difficulty at least once, confirm the rules banner grows upward (not downward) with 2 active rules, confirm Undo/Hint work mid-match, open Manage Decks and build/save/edit a deck, open Stats and confirm numbers update after a match, open Help and confirm the Honeycomb section renders and its TOC link jumps to it.
82: 7. **Full regression**: `dotnet build` (0 errors) and `dotnet test` (full suite, not just Honeycomb's new tests — confirm nothing else broke) before considering the port done.
83: 
The above content shows the entire, complete file contents of the requested file.

========================================
STEP: 141
Created At: 2026-07-22T12:10:17-04:00
Completed At: 2026-07-22T12:10:17-04:00
File Path: `file:///Users/leah/.claude/plans/as-you-know-we-mutable-owl.md`
Total Lines: 83
Total Bytes: 12357
Showing lines 1 to 83
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
1: # Real installers + auto-update for both platforms (Velopack + fallback)
2: 
3: ## Context
4: 
5: Right now, "installing" Honeycomb means: download a zip, unzip it somewhere, run the exe/app directly from that folder. There's no install location, no Start Menu/Applications entry, no uninstaller, and — despite the in-app "Check for Updates" button already existing on both platforms — no actual update mechanism. That button just opens the GitHub release page in a browser; the user still has to manually download and re-unzip every time.
6: 
7: This plan closes that gap: real installers that put the app somewhere permanent, and an update mechanism that can replace the app in place without the user doing anything manual. You've decided to **start unsigned** (no Apple Developer Program enrollment, no Windows signing cert yet) and revisit code signing later if/when this reaches a wider audience than friends and family — that's the right call for where this is right now, and nothing here locks you out of adding signing on top later.
8: 
9: **Two separate tracks**, because the platforms genuinely need different tools:
10: 
11: - **Windows** → **Velopack**. This is a clean, natural fit — the app is already .NET, Velopack is a .NET library + CLI, and it works fine on unsigned builds (users just see a one-time SmartScreen "unknown publisher" click-through instead of a completely silent install).
12: - **Mac** → **needs a verification spike before committing to Velopack.** Velopack does advertise macOS support, but its client integration is built for .NET apps — this app is native Swift/SwiftUI, not .NET. I don't have solid enough information to promise Velopack has a real, maintained Swift-native client today. Rather than build the whole mac plan on an assumption I can't verify, **the first concrete step on mac is a short spike to confirm one way or the other**, with **Sparkle** (the standard, mature, Swift-native mac auto-update framework — this is what most non-App-Store Mac apps actually use, including big-name ones) already chosen as the fallback if Velopack's Swift story doesn't hold up. This isn't hedging for its own sake — it means the mac track can't stall on a dependency that might not actually fit.
13: 
14: A third piece, underneath both tracks: **neither platform's CI actually publishes a real GitHub Release today.** Windows' workflow builds and uploads a 30-day *workflow artifact*, not a release asset — the current 0.9.6 release with real download assets was put together by hand. Mac has no CI at all. Any update mechanism needs a reliable, automated release feed to check against, so fixing this is part of the work, not optional polish.
15: 
16: ---
17: 
18: ## What stays the same
19: 
20: - **User data is completely install-location-independent already** — confirmed on both platforms. Windows: everything lives in `%LocalAppData%\SoliBee\` (`SettingsService.cs`, and each game's own JSON like `BlackjackViewModel.cs`'s `DataDir`). Mac: `~/Library/Application Support/SoliBee/` via `FileManager.urls(for: .applicationSupportDirectory, ...)`, plus `UserDefaults`. An installer/updater on either platform will never touch, need to migrate, or risk this data.
21: - **The existing "Check for Updates" UI shell is good and should be kept** — the About window buttons, the "Don't Ask Again" persisted-disable flag with the auto-reset-on-newer-install logic, the 30-day background cadence. What changes underneath it is the *mechanism*: instead of "compare version, then open a browser link," it becomes "compare version, then hand off to the platform's real updater to download and apply it." `UpdateCheckService.cs` (windows) and `UpdateChecker.swift` (mac) are the files that change; `AboutWindow`/`AboutHoneycombView` and the automatic-prompt windows stay structurally the same, just with their "View Release" action replaced by "Install & Restart."
22: 
23: ---
24: 
25: ## Track A: Windows — Velopack
26: 
27: ### 1. Fix the release pipeline first
28: `build-sign-windows.yml` currently zips the publish output and uploads it as a workflow artifact — it never creates a GitHub Release. Replace the zip/upload-artifact steps with:
29: - `dotnet tool install -g vpk` (or a pinned version) as a workflow step.
30: - `vpk pack -u Honeycomb -v <version-from-csproj> -p <publish-dir> -e Honeycomb.exe -i src/SoliBee.Desktop/Assets/AppIcon.ico` — this replaces the manual `Compress-Archive` step. It produces a `releases/` folder containing `Honeycomb-Setup.exe` (the installer), a full `.nupkg`, a delta `.nupkg` (automatically, once there's a previous version to diff against — Velopack handles this itself, nothing you need to build), and a `RELEASES` manifest file.
31: - Add an actual release-publish step (`softprops/action-gh-release` or `gh release create`/`gh release upload`) that creates/updates the GitHub Release for the pushed tag and uploads everything in `releases/`. This is the step that's missing entirely today.
32: - Leave the existing conditional signing steps in place, gated on the same `CERT_PFX_BASE64` secret check — they're already correctly "off by default," so unsigned builds just flow straight through. When you do decide to sign later, `vpk pack` also accepts a `--signParams` flag to sign as part of packaging, so almost no workflow restructuring will be needed then.
33: 
34: ### 2. Wire `VelopackApp` into app startup
35: Add the `Velopack` NuGet package to `SoliBee.Desktop.csproj`. At the very top of `Program.cs`'s `Main`, before anything else runs (this matters — Velopack needs to intercept certain first-run/install-time invocations before the normal app UI starts):
36: ```csharp
37: VelopackApp.Build().Run();
38: ```
39: This single line handles Velopack's internal install/update/uninstall hook events; you don't need to write handlers for them yourself unless you want custom behavior (e.g. a custom "just installed, show a welcome screen" moment — not required for parity with what exists today).
40: 
41: ### 3. Replace the update-check mechanism
42: In `UpdateCheckService.cs`, replace `FetchLatestReleaseAsync`'s GitHub-API-based version check with Velopack's own `UpdateManager`:
43: ```csharp
44: var mgr = new UpdateManager(new GithubSource("https://github.com/ohrealleah-lab/Honeycomb", null, false));
45: var newVersion = await mgr.CheckForUpdatesAsync();
46: if (newVersion != null) {
47:     await mgr.DownloadUpdatesAsync(newVersion);
48:     mgr.ApplyUpdatesAndRestart(newVersion);
49: }
50: ```
51: Velopack's `GithubSource` reads directly from your GitHub Releases (using the `RELEASES` manifest from step 1), so it needs no separate hosting. Keep the existing `UpdateCheckOutcome` record shape (`LatestVersion`, `IsNewer`) so `AboutWindow`/`UpdateAvailableWindow`'s UI code barely changes — just swap what happens when the user clicks the action button: instead of `Process.Start(...)` opening a browser, call `DownloadUpdatesAsync` + `ApplyUpdatesAndRestart`. Keep the 30-day cadence and disabled-flag logic in `GameOptions`/`SettingsService` exactly as-is; that layer doesn't care what the underlying check mechanism is.
52: - Also worth a quick check before relying on version strings for comparison: confirm `dotnet publish` isn't appending a `+<git-hash>` suffix to `AssemblyInformationalVersion` (no SourceLink package is referenced in the csproj today, so this is likely already clean, but verify the actual published exe's version string once before wiring Velopack's semver-based comparison against it).
53: 
54: ### 4. First-run experience
55: Velopack's installer (`Honeycomb-Setup.exe`) installs per-user (no admin rights required, unlike a traditional MSI) into `%LocalAppData%\Honeycomb`, creates a Start Menu shortcut, and registers an uninstaller in "Apps & Features." Unsigned, the user will see one SmartScreen "Windows protected your PC" screen on first run of the installer — "More info" → "Run anyway" clears it; this does **not** re-appear on every subsequent auto-update the way it does on first install, since Velopack's update-apply step isn't launching a fresh unrecognized executable through the same Explorer/download path SmartScreen inspects.
56: 
57: ---
58: 
59: ## Track B: Mac — spike first, Sparkle as the fallback
60: 
61: ### 1. Spike: does Velopack have a real Swift-usable client?
62: Before writing any mac-specific plan in detail, spend a short, bounded research pass confirming whether Velopack ships anything a Swift/SwiftUI app (not a .NET/MAUI app) can actually call — a proper Swift package, a C-ABI dynamic library with a usable header, anything maintained and documented. If yes, Track B becomes "mirror Track A's shape using whatever that binding looks like." If no (or it's clearly experimental/unmaintained), proceed straight to Sparkle below — don't burn more time trying to force a .NET-shaped tool onto a Swift app.
63: 
64: ### 2. Sparkle (the expected outcome)
65: Sparkle is the de facto standard for auto-updating non-App-Store Mac apps — mature, Swift-friendly (it's Objective-C/Swift native, added via Swift Package Manager), and built around exactly this problem.
66: - Add Sparkle via SPM to `Package.swift`.
67: - Sparkle needs an **appcast** — an XML feed listing available versions, their download URLs, and release notes — hosted somewhere it can fetch from (a file in the GitHub repo served via raw.githubusercontent.com, or attached as a release asset, are both common zero-infrastructure options).
68: - Sparkle can update **unsigned** apps, but with a real caveat worth being upfront about: without notarization, Gatekeeper's quarantine flag re-triggers on each newly-downloaded update the same way it does on first launch — so "seamless silent update" isn't fully achievable pre-signing on mac the way it is on Windows. The realistic unsigned-mac experience is: Sparkle downloads and stages the new version automatically, but the user still needs to click through one "are you sure you want to open this" the first time they launch the updated app. That's a meaningfully better experience than "manually redownload a zip," even if it's not the fully invisible update signing would eventually buy you.
69: - CI: since mac has zero automation today, this means standing up a new GitHub Actions workflow (mac has none — Windows' `build-sign-windows.yml` is the template to mirror the *shape* of: tag-triggered, `make build`, package, publish a real release) that runs `make build`, zips/DMGs the resulting `Honeycomb.app`, updates the appcast XML with the new version entry, and publishes both to a GitHub Release.
70: - Update `UpdateChecker.swift`: same idea as the Windows change — keep the existing options/disabled-flag/cadence logic, but replace the custom GitHub-API polling + browser-hand-off with Sparkle's own `SPUStandardUpdaterController`, which handles the check-download-verify-relaunch cycle itself.
71: 
72: ### 3. Packaging format
73: A DMG (disk image) is the conventional mac distribution format and pairs cleanly with Sparkle — `create-dmg` (a small, widely-used open-source CLI tool) is the standard way to build one without hand-rolling AppleScript/`hdiutil` invocations. This replaces "download a zip, unzip somewhere" with "download a DMG, drag Honeycomb.app into Applications" — the standard mac install ritual users already know.
74: 
75: ---
76: 
77: ## Verification
78: 
79: - **Windows**: after wiring Velopack, do one real end-to-end pass — publish a lower version locally (e.g. bump to a throwaway `0.9.5-test`), install it via the generated `Setup.exe`, then publish and release a `0.9.6-test` and confirm the in-app "Check for Updates" button actually downloads and applies it, relaunching into the new version. Confirm the app still launches clean from a completely fresh machine/VM with no prior install (tests the SmartScreen click-through path).
80: - **Mac**: same idea — install an old version via DMG, ship a newer one through the new CI pipeline, confirm Sparkle detects and applies it. Confirm a completely fresh (never-run-before) copy still opens via the expected right-click-Open-once flow, and doesn't silently fail due to the missing signature.
81: - **Both**: confirm existing user data (saved decks, stats, custom themes) survives an update untouched — install v1, generate some real user data by playing a game and customizing a theme, update to v2, confirm none of it was reset or lost.
82: - **Regression**: existing `dotnet test` (windows) / `make test` (mac) suites should still pass unmodified — this work doesn't touch game logic, only build/packaging/update plumbing.
83: 
The above content shows the entire, complete file contents of the requested file.

========================================
STEP: 180
Created At: 2026-07-22T12:18:58-04:00
Completed At: 2026-07-22T12:18:58-04:00
File Path: `file:///Users/leah/Honeycomb/windows/full_spec.md`
Total Lines: 93
Total Bytes: 14422
Showing lines 1 to 93
The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
1: Created At: 2026-07-22T11:42:23-04:00
2: Completed At: 2026-07-22T11:42:23-04:00
3: File Path: `file:///Users/leah/.claude/plans/as-you-know-we-mutable-owl.md`
4: Total Lines: 548
5: Total Bytes: 59640
6: Showing lines 1 to 548
7: The following code has been modified to include a line number before every line, in the format: <line_number>: <original_line>. Please note that any changes targeting the original code should remove the line number, colon, and leading space.
8: 1: . Numbers/suit glyph render black for player-owned, red for opponent-owned — **this overrides the card's natural suit color** (an opponent-owned heart card still renders in red, not its natural red — same color either way here, but a player-owned spade renders black same as natural; the point is ownership color always wins over suit color, they just happen to coincide for red suits under mac's black/red scheme). Modifier badge (`+N`/`-N`) in a corner when Ascension/Descension is boosting/penalizing that card. A brief highlight/flash on the specific winning stat(s) just before a capture visually resolves (gate this behind the point-highlights options toggle). A 180°-flip animation when a card's owner changes (color-swap should happen at the animation's midpoint, when the card is edge-on/invisible, so the flip never visibly shows the "wrong" color mid-flip).
9: 2: - Toolbar: Start Match/Quit Match, Options, Manage Decks (pre/post-match) vs Hint/Undo (mid-match), score display once a match is live.
10: 3: - Post-game overlay: win/lose result with New Game / Rematch / Steal Card actions.
11: 4: - Wiring into `MainWindow`/`AppCoordinator` (see Phase 9) needs a new toolbar-chrome category — Honeycomb isn't a solitaire game but (unlike Blackjack/VideoPoker) it *does* need Hint and Undo, so the existing `isCardGame` boolean gate in `MainWindow.ApplyGameSwitch` can't just be reused as-is; add a category that shows Hint/Undo for solitaire games *and* Honeycomb, while still hiding solitaire-only chrome (Restart, stat panel) that doesn't apply to Honeycomb.
12: 5: 
13: 6: ---
14: 7: 
15: 8: ## Phase 7 — Deck Builder / Card Bank Window
16: 9: 
17: 10: **Build:** `HoneycombDecksWindow.axaml`/`.axaml.cs`.
18: 11: 
19: 12: Replicate `HoneycombDecksView.swift`'s structure: left panel = the 5 saved-deck rows (name or "Empty Slot N", "(Active)" tag, Set Active / Create-Edit button, small card-preview row) plus a "Start Over" panel with a destructive confirmation prompt; right panel = the full Card Bank grid with a filter bar (star-tier filter, suit filter, Favorites-only toggle, Clear-filters button) and a favorite-heart toggle overlay per card. The Deck Builder itself opens as a sub-view/dialog: deck-name text field (max 20 chars, editable even after saving — matches the "allow editing deck names once saved" fix already shipped on mac and windows for the saved-decks list itself, so don't reintroduce a name-lock here either), a 5-slot "your deck" row (tap to remove), the Card Bank grid below it (tap to add; already-in-deck cards shown dimmed), live validation error text (rules in Phase 4), Save disabled until valid + full + named.
20: 13: 
21: 14: ---
22: 15: 
23: 16: ## Phase 8 — Stats Window
24: 17: 
25: 18: **Build:** `HoneycombStatsWindow.axaml`/`.axaml.cs`.
26: 19: 
27: 20: Replicate `HoneycombStatsView.swift`'s grouped stat rows: Games Played/Won/Lost/Drawn/Sudden Deaths/Win Rate; streak + flawless-victory + per-difficulty win counts; captures/Fallen-Aces/combos/steals/start-overs; total card-bank unlock progress plus per-suit and per-star unlock breakdowns (computed live from `HoneycombDatabase.AllCards` vs `UnlockedCardIds`, not persisted). Win rate = `MatchesWon / (GamesPlayed - MatchesDrawn) * 100`. Include a destructive, confirmed "Reset Stats" action and a Close button.
28: 21: 
29: 22: ---
30: 23: 
31: 24: ## Phase 9 — Wiring & Help Text
32: 25: 
33: 26: ### Wiring into the app shell
34: 27: 
35: 28: - `AppCoordinator.cs`: add `[ObservableProperty] private HoneycombViewModel _honeycombViewModel;`, a `SwitchToHoneycomb()` method mirroring `SwitchToBlackjack()`, and a new arm in every `switch (ActiveViewModel)` block (`CanUndo`, `Undo()`, `ResetStatistics`, `ApplyTheme`, `TriggerWinAnimation`) — Honeycomb needs real arms in `CanUndo`/`Undo()` (unlike Blackjack/VideoPoker's `false`/no-op fallthrough), since it has real Undo support.
36: 29: - `MainWindow.axaml`: add a `ComboBoxItem Tag="Honeycomb"` to the game-selection combo box.
37: 30: - `MainWindow.axaml.cs`: add a `tag == "Honeycomb"` branch to `ApplyGameSwitch` instantiating `new HoneycombView { DataContext = _coordinator.HoneycombViewModel }`; add `Honeycomb` to `GameModeToIndex`/its reverse mapping; add window-size-restore entries (the `RestoreWindowSizeForGame` switch and the persisted-size property additions to `GameOptions.cs`/`SettingsService.cs`, per the Architecture Decisions section above); extend the `isCardGame`-style toolbar-chrome gate as described in Phase 6.
38: 31: 
39: 32: ### Help window content
40: 33: 
41: 34: Add a `HoneycombAnchor` section to `HelpWindow.axaml` (index entry + `GoTo_Honeycomb` handler in the code-behind, following the exact anchor/index/content-block pattern every other game's help section already uses — see `BlackjackAnchor`/`GoTo_Blackjack` as the template). Use this content, adapted only for Windows' click-based interaction (mac describes drag-or-tap-then-tap; Windows should describe whatever your actual input model ends up being — click-to-select-then-click-to-place is the natural equivalent) — this is mac's actual shipped help copy, quoted in full so there's no ambiguity about what each rule should say:
42: 35: 
43: 36: > **Objective** — Battle an AI opponent on a 3×3 grid. Place your 5 cards one at a time; when a placement's facing stat beats an adjacent enemy card's opposite facing stat, you capture it. Whoever controls more of the 9 cells once the board fills wins the match.
44: 37: >
45: 38: > **How to Play** — [adapt for Windows input model; mac: "Drag a card from your hand onto any empty board cell, or tap a hand card to select it and then tap an empty cell."] You and the dealer alternate turns until the board is full.
46: 39: >
47: 40: > **Capturing & Combos** — Each card shows 4 stats — Top, Right, Bottom, Left. Placing a card next to an enemy card compares your facing stat to their opposite facing stat; the higher value flips the loser to your side (10 is shown as "A"). A card captured this way can immediately capture its own neighbors in a chain reaction, called a Combo.
48: 41: >
49: 42: > **Match Rules Overview** — Up to 2 rules can be active per match, chosen in Options before you Start Match. Ascension and Descension can't both be picked (they're opposites), and neither can Order and Chaos. Leave rule selection empty (and Normal Mode off) and Roulette randomly rolls 0–2 rules for you every match instead — Roulette is also the only way Reverse can appear, since it's too easily exploited to pick on purpose.
50: 43: >
51: 44: > **Ascension / Descension** — At the start of the match, 2 of the 4 suits are randomly chosen to be affected. Under Ascension, every card of an affected suit gains +1 to all four of its stats for each card of that suit currently on the board — recalculated before every placement's captures resolve, so the bonus grows as more of that suit hits the table. Descension is the same idea in reverse: −1 per card of that suit on the board. A card of an unaffected suit plays completely normally.
52: 45: >
53: 46: > **Same** — If 2 or more of a placed card's touching neighbors have a facing stat exactly equal to the attacker's matching facing stat, every one of those matching neighbors is captured at once — not just the strongest one. Your own adjacent cards count toward the trigger too, not only the dealer's, so a placement boxed in by 2 of your own matching cards can still fire Same (this is intentional, not a bug).
54: 47: >
55: 48: > **Plus** — If 2 or more touching neighbor pairs each sum (attacker's facing stat + that neighbor's facing stat) to the same total as each other, every card in that matching group is captured — even if the shared sum isn't the attacker's own stat. Like Same, your own adjacent cards count toward the trigger.
56: 49: >
57: 50: > **Fallen Ace** — A card showing a 1 that attacks a card showing a 10 ("A") always captures it, overriding the normal higher-beats-lower comparison — a 1 is the one value that can topple an Ace. Under Reverse, this flips too: an attacking 10 always captures a defending 1.
58: 51: >
59: 52: > **Reverse** — Capture direction is fully inverted: the attacker wins when its facing stat is lower than the defender's, not higher. Reverse only ever appears via Roulette, never by manual selection — the AI's own deck (and, under Fallen Ace, its capture math) is specially adjusted per difficulty so a nominally "easy" opponent doesn't become trivial under the inversion.
60: 53: >
61: 54: > **All Open / Three Open** — All Open reveals the dealer's entire hand face-up for the whole match; Three Open reveals exactly 3 random cards from it, staying revealed by that specific card's identity as the hand shrinks. Either way the reveal is symmetric — the dealer's AI gets the same look at your hand it's giving you, so nobody's playing with hidden information the other side lacks.
62: 55: >
63: 56: > **Swap** — Before the first turn, one random card from your hand trades places with one random card from the dealer's hand. The swapped card plays for whoever now holds it, but for Card Bank unlock and post-win steal eligibility it still belongs to its original owner if you don't recapture it during the match.
64: 57: >
65: 58: > **Order / Chaos** — Order restricts your legal play each turn to strictly the next card in your original deck order — no choosing. Chaos instead re-rolls one random legal card the instant a side's turn begins, highlighted with a thick yellow border; you'll see the dealer's mandated card highlighted at least 2 seconds before its AI actually plays it.
66: 59: >
67: 60: > **Sudden Death** — A 5-5 tie sends the match into Sudden Death: the board clears and immediately replays with each side's exact end-of-round cards, alternating who starts, until someone wins outright.
68: 61: >
69: 62: > **Difficulty** — Easy plays randomly. Medium greedily maximizes its own captures each turn. Hard and Ultra Hard search several moves ahead using a full positional evaluation, with Ultra Hard also fielding the strongest overall deck.
70: 63: >
71: 64: > **Hint** — On any difficulty below Ultra Hard, the Hint button suggests the strongest card-and-cell placement — found with the same search Ultra Hard's own AI uses — highlighting it for 2 seconds. It only ever considers dealer cards you've actually been shown, never one still hidden from you.
72: 65: >
73: 66: > **Card Bank & Decks** — Winning a card isn't automatic — after a win, you may [drag/click, per your input model] one card the dealer played that round onto one of your 5 active deck slots, permanently unlocking it into your Card Bank. This steal is capped at one per match; Rematch (or start a new match) to steal again. Build named decks from Manage Decks, subject to rarity caps: at most one 5★ card, and at most one 4★ if a 5★ is already in the deck (otherwise up to two 4★).
74: 67: >
75: 68: > **No Stress Mode** — Deals a fixed, strong deck every match (one 5★, one 4★, three 3★) instead of your chosen active deck, and hides Steal Card — a relaxed way to play without managing a collection. This is a shared setting — enabling it here also enables it across the other games.
76: 69: 
77: 70: ---
78: 71: 
79: 72: ## Verification / acceptance criteria
80: 73: 
81: 74: Run in order — each phase's tests must pass before starting the next phase's implementation:
82: 75: 
83: 76: 1. **Phase 1**: `dotnet test --filter "FullyQualifiedName~HoneycombCardGeneratorTests"` — raw `SplitMix64` vectors, both seed-1 and seed-42 full generated-card vectors, plus the ported structural tests (counts/budgets/no-duplicates), all green.
84: 77: 2. **Phase 2**: `HoneycombBoardTests.cs` — hand-construct board states exercising: a plain higher-beats-lower capture, a Reverse capture, Same firing across 2+ neighbors (including the "boxed in by your own matching cards" case), Plus firing on a shared sum, a combo chain flipping a second card, Fallen Ace's win case AND its blocked-mirror case (both directions, under both Reverse states), Ascension modifier scaling as suit count grows, Descension going negative, edge/corner cells correctly having fewer neighbors.
85: 78: 3. **Phase 3**: `HoneycombAITests.cs` — Easy AI never crashes and always plays a legal move over many random trials; Medium AI always picks an available immediate-capture move when one exists; Hard/Ultra-Hard AI picks a move at least as good (by the heuristic) as a hand-picked "obviously bad" alternative in a constructed scenario; `RulesAwareCards` under `preferLowStats=true` returns lower-average-total cards than `preferLowStats=false` for the same tier.
86: 79: 4. **Phase 4**: deck-validation rule tests (each rejection message, each boundary — exactly one 5★ allowed, exactly two 4★ when no 5★, etc.), Start Over composition test (mirroring the existing mac/windows `computeStartOverDecks`-style pure-function test — given a previous deck's star composition, assert the redrawn deck matches that composition with different specific card ids).
87: 80: 5. **Phase 5**: `HoneycombViewModelTests.cs` — full match flow smoke test (place all 5 player + 5 opponent cards, verify board fills, winner determined correctly by score); Sudden Death triggers correctly on a tied board and preserves `AscensionDescensionSuits`; Undo restores the exact pre-placement state; stats recording increments the right counters for a won/lost/drawn/flawless match.
88: 81: 6. **Phase 6–8 (UI)**: manual verification — run the Windows app, switch to Honeycomb from the game selector, play a full match against each difficulty at least once, confirm the rules banner grows upward (not downward) with 2 active rules, confirm Undo/Hint work mid-match, open Manage Decks and build/save/edit a deck, open Stats and confirm numbers update after a match, open Help and confirm the Honeycomb section renders and its TOC link jumps to it.
89: 82: 7. **Full regression**: `dotnet build` (0 errors) and `dotnet test` (full suite, not just Honeycomb's new tests — confirm nothing else broke) before considering the port done.
90: 83: 
91: The above content shows the entire, complete file contents of the requested file.
92: 
93: 
The above content shows the entire, complete file contents of the requested file.

========================================
