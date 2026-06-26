# Tasks: Pokerbee & Tejas Hold'em

**Input**: Design documents from `/specs/006-poker-modes/`

**Prerequisites**: spec.md, plan.md, research.md, data-model.md

**[P]** = can run in parallel with other [P] tasks in the same phase.

---

## Phase 1: Shared Engine (blocks all game work)

- [ ] T001 Add `case pokerbee = "Pokerbee"` and `case tejas = "Tejas Hold\'em"` to `GameMode` enum in `src/Models/GameMode.swift`
- [ ] T002 [P] Create `src/Models/PokerHandRank.swift` — `PokerHandRank` enum (Int raw value, Comparable), `PokerHandResult` struct (rank + kickers, Comparable via rank then lexicographic kickers)
- [ ] T003 [P] Create `src/Models/PokerHandEvaluator.swift`:
  - `evaluate(_ five: [Card]) -> PokerHandResult` — classify exactly 5 cards
  - `bestFiveOfSeven(hole: [Card], community: [Card]) -> PokerHandResult` — try all C(7,5)=21 subsets, return max
- [ ] T004 [P] Create `src/Models/PokerAI.swift`:
  - `AIDifficulty` enum (`easy`, `medium`, `hard`) with `Codable`
  - `decideAction(hand:communityCards:pot:callAmount:difficulty:) -> PokerAction`
  - `decideDiscards(hand:difficulty:) -> [Int]`
  - Bluff rates: easy 3%, medium 8%, hard 18%
- [ ] T005 [P] Create `src/Models/SidePot.swift` — `SidePot` struct (amount, eligiblePlayerIDs: Set\<UUID\>)
- [ ] T006 Write hand evaluator unit tests in `SoliBeeTests/PokerHandEvaluatorTests.swift`:
  - One test per hand rank (highCard through royalFlush)
  - Tiebreaker ordering (two pairs with different kickers)
  - 10,000-hand randomized test: deal 5 random cards, evaluate, assert no crash and rank is a valid `PokerHandRank`

**Checkpoint**: T006 all green. Evaluator correct rate 100%.

---

## Phase 2: Pokerbee Models & ViewModel

- [ ] T007 Create `src/Pokerbee/Models/PokerbeeOptions.swift` — all fields with `decodeIfPresent ?? default` in `init(from:)`, `CodingKeys` for every property; saved to `"pokerbee_options"` UserDefaults key
- [ ] T008 [P] Create `src/Pokerbee/Models/PokerbeeState.swift` — `PokerbeePlayer`, `PokerbeeGameState`, `Phase` enum
- [ ] T009 [P] Create `src/Pokerbee/Models/PokerbeeStatistics.swift` — `PokerStatistics` struct, saved to `"pokerbee_statistics"`
- [ ] T010 Create `src/Pokerbee/ViewModels/PokerbeeViewModel.swift` (`@Observable`):
  - `var options: PokerbeeOptions { didSet { saveOptions(); broadcast() } }` — posts feltColorDidChange, cardBackThemeDidChange, darkModeDidChange following BeecellViewModel pattern
  - `var state: PokerbeeGameState`
  - `var statistics: PokerbeeStatistics`
  - `var sessionChips: Int` — initialized from `options.startingChips` in `init()`, never persisted
  - `startNewHand()` — shuffle, deal 5 per player, collect antes (skip if noBidMode)
  - `act(_ action: PokerAction)` — validate legality, update pot/bets, advance turn
  - `submitDiscards(_ indices: [Int])` — replace selected cards from remaining deck
  - `aiTurn()` — call `PokerAI.decideAction` or `decideDiscards` depending on phase; apply with brief async delay
  - `showdown()` — evaluate all hands, award pot, update statistics
  - `rebuy()` — add `options.startingChips` to `sessionChips`, increment `statistics.rebuyCount`
- [ ] T011 [P] Write `SoliBeeTests/PokerbeeViewModelTests.swift`:
  - Deal produces correct card count per player
  - Ante deducted correctly from all players
  - Fold removes player from active set
  - noBidMode skips betting phases
  - Discard + draw produces hand of exactly 5 cards
  - Showdown awards pot to correct winner

**Checkpoint**: T011 all green.

---

## Phase 3: Tejas Hold'em Models & ViewModel

- [ ] T012 Create `src/Tejas/Models/TejasOptions.swift` — same pattern as PokerbeeOptions; saved to `"tejas_options"`
- [ ] T013 [P] Create `src/Tejas/Models/TejasState.swift` — `TejasPlayer`, `TejasGameState`, `Phase` enum, side pot construction logic
- [ ] T014 [P] Create `src/Tejas/Models/TejasStatistics.swift` — saved to `"tejas_statistics"`
- [ ] T015 Create `src/Tejas/ViewModels/TejasViewModel.swift` (`@Observable`):
  - `var options: TejasOptions { didSet { saveOptions(); broadcast() } }` — identical notification pattern
  - `var state: TejasGameState`
  - `var statistics: TejasStatistics`
  - `var sessionChips: Int`
  - `startNewHand()` — rotate dealer, post blinds, deal 2 hole cards per player
  - `act(_ action: PokerAction)` — validate legality (check only when no bet, raise min = lastRaise × 2), update pot, handle all-in → side pot creation, advance turn, detect round-end
  - `dealCommunityCards(for phase: TejasGameState.Phase)` — flop (burn+3), turn (burn+1), river (burn+1)
  - `aiTurn()` — call `PokerAI.decideAction` with community cards context; apply with async delay
  - `showdown()` — `bestFiveOfSeven` for each player, award main pot + side pots
  - `rebuy()`
- [ ] T016 [P] Write `SoliBeeTests/TejasViewModelTests.swift`:
  - Blind posting and dealer rotation
  - Pre-flop betting state machine
  - Flop/turn/river card counts
  - All-in side pot construction
  - Showdown winner evaluation
  - AI action legality

**Checkpoint**: T016 all green.

---

## Phase 4: AppCoordinator Extension

- [ ] T017 Add `public let pokerbeeViewModel = PokerbeeViewModel()` and `public let tejasViewModel = TejasViewModel()` to `AppCoordinator`
- [ ] T018 Extend `syncSharedOptions(from:to:)` to handle all 5 `GameMode` cases — read shared fields from outgoing VM, write to all four other VMs
- [ ] T019 Extend `startNewGame()`, `restartCurrentGame()`, `undoLastAction()`, `canUndo`, `zoomIn()`, `zoomOut()`, `resetZoom()`, `makeCurrentZoomDefault()`, `resetStatistics()` with `.pokerbee` and `.tejas` cases
- [ ] T020 Extend `triggerWinAnimation()` with `.pokerbee` and `.tejas` cases (no-op or chip-win animation)

**Checkpoint**: App compiles. Switching to `.pokerbee` or `.tejas` in the game picker does not crash.

---

## Phase 5: Pokerbee UI

- [ ] T021 Create `src/Pokerbee/Views/PokerbeeView.swift`:
  - Felt background (same `feltBackground` helper as BeecellView)
  - Player seat row across the top: each AI seat shows face-down cards, chip count, name, current bet indicator
  - Human hand area: 5 `CardView`s, tap-to-select-discard highlight (selected cards lift slightly), "Draw" button (disabled until at least 0 cards selected)
  - Pot display and phase label in center
  - Action buttons panel: Fold / Check / Call / Raise (hidden when not the player's turn); Raise includes a chip-amount stepper
  - "No Bid" mode hides all betting UI; shows only "Ready" button to advance through phases
  - Status bar: session chips, current bet, hand number, timer (if isTimed)
  - Inline `PokerbeeOptionsView` sheet triggered by gear/preferences button

- [ ] T022 Create `PokerbeeOptionsView` inside `PokerbeeView.swift`:
  - **Top section (poker-specific)**:
    - `Picker("Players:", selection: $seatCount)` — segmented, tags 2–6
    - `Picker("AI Difficulty:", selection: $aiDifficulty)` — segmented: Easy / Medium / Hard
    - `Stepper("Starting Chips: \(startingChips)", value: $startingChips, in: 100...10000, step: 100)`
    - `Stepper("Ante: \(ante)", value: $ante, in: 0...500, step: 5)`
    - `Toggle("No Bid Mode", isOn: $noBidMode)` with `.monospaced` font
    - `Divider()`
  - **Shared toggle block** (identical order and labels to BeecellOptionsView):
    - Timed Game, Sound Effects, Hide Hint button, Hide Stats button, Dark Mode Cards
    - `Divider()`
  - **Felt color** (identical to BeecellOptionsView)
  - **Custom card art** (`CustomArtPanelView`)
  - OK button builds `updatedOpts` from all @State vars and assigns to `viewModel.options`

- [ ] T023 [P] Create `src/Pokerbee/Views/PokerbeeViews.swift` — reusable sub-views:
  - `PokerSeatView(player:)` — seat card display + chip count + bet badge
  - `PokerActionPanel(onFold:onCheck:onCall:onRaise:)` — action buttons
  - `PokerChipDisplay(amount:)` — formatted chip count label

**Checkpoint**: Pokerbee hand playable end-to-end on macOS via `make run`.

---

## Phase 6: Tejas Hold'em UI

- [ ] T024 Create `src/Tejas/Views/TejasView.swift`:
  - Oval felt table with player seats arranged around the perimeter (2–6 positions); dealer button badge on dealer seat
  - Community card row in center: 5 `CardView` placeholders, revealed progressively by phase (flop shows 3, turn adds 1, river adds 1)
  - Human seat at bottom: 2 hole cards face-up, chip count, current bet display
  - AI seats: 2 hole cards face-down (revealed at showdown), chip count, current bet, fold indicator
  - Action buttons (human turn only): Fold / Check / Call / Raise with raise slider (min/max enforced); all-in button
  - Pot total, side pot breakdown (shown when side pots > 0), phase label, blind display
  - Status bar: session chips, hand number, timer
  - Inline `TejasOptionsView` sheet

- [ ] T025 Create `TejasOptionsView` inside `TejasView.swift`:
  - **Top section (poker-specific)**:
    - `Picker("Players:", selection: $seatCount)` — segmented 2–6
    - `Picker("AI Difficulty:", selection: $aiDifficulty)` — Easy / Medium / Hard
    - `Stepper("Starting Chips: \(startingChips)", value: $startingChips, in: 100...10000, step: 100)`
    - `Stepper("Small Blind: \(smallBlind)", value: $smallBlind, in: 5...1000, step: 5)`
    - `Stepper("Big Blind: \(bigBlind)", value: $bigBlind, in: 10...2000, step: 10)`
    - `Divider()`
  - **Shared toggle block** (identical to Beecell / Pokerbee)
  - **Felt color** (identical)
  - **Custom card art** (`CustomArtPanelView`)

- [ ] T026 [P] Create `src/Tejas/Views/TejasViews.swift` — reusable sub-views:
  - `TejasPlayerSeat(player:isActive:showCards:)` — seat tile with cards, chips, dealer button, fold indicator
  - `TejasActionPanel(...)` — Fold/Check/Call/Raise/All-in with raise stepper
  - `CommunityCardRow(cards:phase:)` — 5 slots, revealed by phase

**Checkpoint**: Full Tejas Hold'em hand playable end-to-end via `make run`.

---

## Phase 7: AppRouterView & Navigation

- [ ] T027 Update `AppRouterView` to route `.pokerbee` → `PokerbeeView` and `.tejas` → `TejasView`; add `.id(GameMode.pokerbee.rawValue)` and `.id(GameMode.tejas.rawValue)` modifiers
- [ ] T028 [P] Update the game mode picker in the main UI to show all 5 modes
- [ ] T029 [P] Update menu bar commands: ensure New Game, Restart, Undo route correctly for all 5 modes via `AppCoordinator`

**Checkpoint**: All 5 modes accessible and switchable. `make build` succeeds.

---

## Phase 8: Statistics & Polish

- [ ] T030 Implement statistics views for Pokerbee and Tejas — hands played, win %, biggest pot, net session chips, rebuy count; follow SoliBee `StatsView` pattern
- [ ] T031 [P] Add sound effects for deal (reuse shuffle.aiff), chip win (snap.aiff), and bust/lose events
- [ ] T032 [P] Window minimum size review — Tejas Hold'em table may need a wider minimum width than existing modes; enforce via `contentMinSize` in `TejasView`
- [ ] T033 [P] End-to-end validation per quickstart.md checklist; `make build` final

---

## Dependencies

- Phase 1 must complete before Phases 2, 3, 4.
- Phases 2 and 3 can run in parallel after Phase 1.
- Phase 4 requires Phases 2 and 3.
- Phases 5 and 6 can run in parallel after Phase 4.
- Phase 7 requires Phases 5 and 6.
- Phase 8 requires Phase 7.
