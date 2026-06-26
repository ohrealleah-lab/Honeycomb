# Tasks: PokerBee Suite

**Input**: Design documents from `/specs/005-pokerbee/`

**Prerequisites**: spec.md, plan.md, research.md, data-model.md

**Organization**: Tasks grouped by phase. [P] = can run in parallel with other [P] tasks in the same phase.

---

## Phase 1: Repo & Toolchain Setup

- [ ] T001 Install .NET 8 SDK (`dotnet --version` should report 8.x); install Avalonia templates: `dotnet new install Avalonia.Templates`
- [ ] T002 Create solution: `dotnet new sln -n PokerBee`; create three projects:
  - `dotnet new classlib -n PokerBee.Core`
  - `dotnet new avalonia.app -n PokerBee.App`
  - `dotnet new xunit -n PokerBee.Tests`
  - Add all to solution; add project references (App → Core, Tests → Core)
- [ ] T003 [P] Copy image assets from SoliBee into `PokerBee.App/Assets/`: `J.png`, `Q.png`, `K.png`, `red j.png`, `red q.png`, `red k.png`, all six `dark_*.png` files
- [ ] T004 [P] Create Makefile wrapping `dotnet build`, `dotnet test`, `dotnet publish`, `dotnet run`
- [ ] T005 [P] Add `Avalonia.ReactiveUI` NuGet package to `PokerBee.App`; add `ReactiveUI` to `PokerBee.Core`

**Checkpoint**: `dotnet build` succeeds with empty projects on macOS.

---

## Phase 2: Core Models (blocks all game work)

- [ ] T006 Create `Card.cs` — `Suit` enum (Hearts/Diamonds/Spades/Clubs, `IsRed`), `Rank` int 1–13, `FaceUp` bool, `Id` Guid — mirrors SoliBee `Card.swift`
- [ ] T007 [P] Create `Deck.cs` — Fisher-Yates shuffle, `Deal()` pop, `DeckCount` int, cut-card reshuffle for Blackjack
- [ ] T008 [P] Create `GameMode.cs` — `enum GameMode { Holdem, Blackjack }`
- [ ] T009 [P] Create `FeltColorTheme.cs` — `enum FeltColorTheme { FeltGreen, Crimson, RoyalBlue, Charcoal, Desert, Custom }`
- [ ] T010 [P] Create `PokerBeeSharedOptions.cs` — `CardBackTheme`, `FeltColor`, `IsDarkMode`, `IsSoundEnabled`, `CustomFeltColorRevision`; serialize/deserialize via `System.Text.Json` with property defaults
- [ ] T011 [P] Create `FaceCardSlot.cs` and `CustomFaceArt.cs` — mirrors SoliBee `FaceCardSlot.swift`
- [ ] T012 [P] Create `CustomCardBack.cs`
- [ ] T013 Write Core model unit tests — deck integrity (52 unique cards per deck), `Card` equality, `FeltColorTheme` round-trip serialize

**Checkpoint**: T013 all green.

---

## Phase 3: Managers (depends on Phase 2)

- [ ] T014 Create `CustomCardBackManager.cs` — singleton, persists to `%APPDATA%\PokerBee\` / `~/.local/share/PokerBee/`, image cache as non-reactive field (mirrors SoliBee `@ObservationIgnored`)
- [ ] T015 [P] Create `CustomFaceCardArtManager.cs` — same pattern; manages per-slot art files, `IsEnabled` toggle, scale/offset

**Checkpoint**: Managers unit-tested for add/remove/persist round-trip.

---

## Phase 4: Hand Evaluator & Engines (blocks game VMs)

- [ ] T016 Implement `HandEvaluator.cs` — `IEnumerable<Card[]> Combinations(Card[] cards, int r)` generator; per-combination `PokerHandResult Evaluate(Card[] five)` scoring; `Best(Card[] sevenCards)` returns highest result
- [ ] T017 [P] Implement `HoldemAI.cs` — Chen pre-flop score table, pot-odds post-flop ratio, `BluffFrequency` threshold, `DecideAction(HoldemPlayer, HoldemGameState) → HoldemAction`
- [ ] T018 [P] Implement `BlackjackDealer.cs` — `ShouldDraw(BlackjackHand) → bool` (hit ≤ soft 16, stand ≥ hard/soft 17), shoe reshuffle check
- [ ] T019 Write `HandEvaluatorTests.cs` — all 9 hand ranks produced correctly, tiebreaker kicker ordering, 10,000-hand randomized correctness check
- [ ] T020 [P] Write `BlackjackDealerTests.cs` — boundary cases: soft 16 draws, soft 17 stands, hard 17 stands

**Checkpoint**: T019 + T020 all green. Evaluator 100% correct.

---

## Phase 5: Texas Hold 'Em ViewModel (US1)

- [ ] T021 Create `HoldemOptions.cs`, `HoldemStatistics.cs`, `HoldemPlayer.cs`, `SidePot.cs`, `PokerHandResult.cs`
- [ ] T022 Implement `HoldemGameState.cs` — Phase enum, community cards, pot, sidePots, activePlayerIndex, dealerIndex
- [ ] T023 Implement `HoldemViewModel.cs` (ReactiveObject):
  - `StartNewHand()`: rotate dealer, post blinds, shuffle + deal hole cards, set phase to PreFlop
  - `Act(HoldemAction)`: validate legality, update pot + bets, advance turn, detect round-end
  - `DealCommunityCards(Phase)`: flop (3), turn (1), river (1) with burn
  - `Showdown()`: evaluate each player's best hand, award main pot + side pots
  - `TakAITurn()`: call `HoldemAI.DecideAction`, apply with 500–1500ms async delay
  - `Options` setter: save to JSON + raise PropertyChanged for all shared-option properties
- [ ] T024 [P] Write `HoldemViewModelTests.cs` — deal card counts, betting state machine, side-pot math, showdown correctness, AI action legality

**Checkpoint**: T024 all green.

---

## Phase 6: Blackjack ViewModel (US1)

- [ ] T025 Create `BlackjackOptions.cs`, `BlackjackStatistics.cs`, `BlackjackHand.cs`, `BlackjackGameState.cs`
- [ ] T026 Implement `BlackjackViewModel.cs` (ReactiveObject):
  - `PlaceBet(int)` → validates min/max
  - `Deal()` → 4 cards, Blackjack check, Insurance offer if dealer shows Ace
  - `Hit()`, `Stand()`, `DoubleDown()`, `Split()`, `TakeInsurance()`
  - `ResolveDealerTurn()` via `BlackjackDealer.ShouldDraw`
  - `ResolveHand()` → payout calculation, chip balance update
  - `Options` setter: save + PropertyChanged
- [ ] T027 [P] Write `BlackjackViewModelTests.cs` — soft total calculation, all action state transitions, payout ratios, split/double mechanics

**Checkpoint**: T027 all green.

---

## Phase 7: AppCoordinator (depends on Phases 5 + 6)

- [ ] T028 Implement `AppCoordinator.cs`:
  - Holds `HoldemViewModel` and `BlackjackViewModel` simultaneously (never disposed on switch)
  - `GameMode` property setter calls `SyncSharedOptions(from, to)` — copies IsDarkMode, IsSoundEnabled, FeltColor, CardBackTheme, CustomFeltColorRevision
  - Delegates `StartNewGame()`, `CanUndo`, `Undo()` to active VM

**Checkpoint**: Mode switch syncs options (verified via unit test).

---

## Phase 8: Avalonia Card Rendering (US3 prerequisite)

- [ ] T029 Implement `CardView.axaml` + `CardView.axaml.cs`:
  - Outer `Border`: 128×181, CornerRadius=10, Background bound to `IsDarkMode ? #1E1E1E : White`, BorderBrush bound to dark/light outline color
  - `CardFrontView` inner panel: rank + suit text top-left and bottom-right (monospaced, size 17), center suit area
  - `CardCenterSuitView`: Ace (large suit symbol), 2–10 (positioned suit symbols matching SoliBee `positionsFor(rank:)`), J/Q/K (image selected by rank + `IsRed` + `IsDarkMode`)
  - Dark mode colors: Red=#FF4444, Black=#C0C0C0 applied to `Foreground` bindings
  - `CardBackView`: loads card back image via `CustomCardBackManager`
- [ ] T030 [P] Implement `TableView.axaml` — felt background color resolved from `FeltColorTheme` enum, same color table as SoliBee
- [ ] T031 [P] Implement `ChipView.axaml` — chip stack with bet amount label

**Checkpoint**: Cards render correctly in both light and dark mode on macOS. Screenshot matches SoliBee visually.

---

## Phase 9: Options & Customization UI (US3)

- [ ] T032 Implement `OptionsView.axaml` — shared preferences panel with toggles for Dark Mode Cards, Sound Effects, felt color picker, card back selector; follows SoliBee OptionsView layout
- [ ] T033 [P] Implement `CardDeckSelectorView.axaml` — thumbnail grid, import PNG/GIF, delete with confirmation dialog — mirrors SoliBee `CustomCardArtSectionView`
- [ ] T034 [P] Implement `FaceCardArtSectionView.axaml` — 8 slot tiles (blackAce–redKing), import/scale/offset editor, enable/disable toggle — mirrors SoliBee `FaceCardArtSectionView`

**Checkpoint**: All customization persists through app restart.

---

## Phase 10: Texas Hold 'Em Board UI (US1 + US3)

- [ ] T035 Implement `HoldemView.axaml`:
  - Oval table with 2–6 seat positions arranged around perimeter
  - Each seat: `CardView` ×2 (face-down for AI, face-up for player), name label, chip count, dealer button indicator, bet display
  - Community card row: 5 `CardView` placeholders, revealed progressively by phase
  - Action panel (player seat only): Fold / Check / Call / Raise buttons; raise amount slider with min/max enforcement; pot total and current bet display
  - Phase label (Pre-Flop / Flop / Turn / River / Showdown)
  - Hand number and timer display
- [ ] T036 [P] Implement AI turn animation — brief "thinking" indicator (0.5–1.5s delay), then action label appears above AI seat

**Checkpoint**: Full Texas Hold 'Em hand playable macOS end-to-end via `dotnet run`.

---

## Phase 11: Blackjack Board UI (US1 + US3)

- [ ] T037 Implement `BlackjackView.axaml`:
  - Dealer hand area: cards fanned horizontally, hole card face-down until dealer turn
  - Player hand area: cards fanned, total label, bust/blackjack indicator
  - Bet entry control: numeric input with min/max chip enforcement, Place Bet button
  - Action buttons: Hit / Stand / Double Down (grayed if unavailable) / Split (grayed if unavailable) / Insurance (shown only when offered)
  - Chip balance display and hand result flash (Win / Lose / Push / Blackjack)
- [ ] T038 [P] Implement win/lose/push animated overlay and chip-increment counter animation

**Checkpoint**: Full Blackjack hand playable macOS end-to-end.

---

## Phase 12: App Shell & Navigation

- [ ] T039 Implement `AppRouterView.axaml` — game mode switcher (dropdown or tab); switches between `HoldemView` and `BlackjackView`; injects `AppCoordinator` as DataContext
- [ ] T040 [P] Implement `App.axaml.cs` entry point — instantiate `AppCoordinator`, configure dependency injection, set main window
- [ ] T041 [P] Add menu bar: New Hand (Ctrl+N), Restart (Ctrl+R), Undo (Ctrl+Z), Reset Statistics, About PokerBee — mirrors SoliBee menu structure

---

## Phase 13: Statistics & Chip Balance (US4)

- [ ] T042 Implement statistics views for Hold 'Em and Blackjack (hands played, win %, biggest pot, net chips) — follow SoliBee `StatsView` pattern
- [ ] T043 [P] Implement chip balance persistence and Buy In flow (shown when balance = 0)

---

## Phase 14: Polish & Cross-Platform Validation

- [ ] T044 Add sound effects (deal shuffle, card snap, chip clink, bust sound) via Avalonia's `MediaPlayer` or `LibVLCSharp`
- [ ] T045 [P] Implement zoom system — scale factor applied to card dimensions and table layout; persist via options
- [ ] T046 [P] `dotnet publish -r win-x64 --self-contained` from macOS; verify `.exe` runs on Windows with correct card rendering and dark mode colors
- [ ] T047 [P] End-to-end validation using quickstart.md checklist on both platforms
- [ ] T048 [P] Set application version, icon, and copyright in `.csproj` manifest

---

## Dependencies Summary

- Phases 1–2 must complete before Phase 3.
- Phase 4 (Engines) requires Phase 2.
- Phases 5–6 require Phase 4.
- Phase 7 (AppCoordinator) requires Phases 5 and 6.
- Phase 8 (Card UI) can start after Phase 2.
- Phases 9–11 require Phases 7 and 8.
- Phase 12 requires Phases 9–11.
- Phases 13–14 require Phase 12.
