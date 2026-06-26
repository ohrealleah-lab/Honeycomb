# Feature Specification: Pokerbee & Tejas Hold'em Game Modes

**Feature Branch**: `006-poker-modes`

**Created**: 2026-06-24

**Status**: Draft

## Overview

Add two new game modes to the existing SoliBee suite:

- **Pokerbee** — 5-Card Draw poker, 1 human vs. 1–5 AI opponents, play-money chips that reset on app launch.
- **Tejas Hold'em** — Texas Hold 'Em, 1 human vs. 1–5 AI opponents, same chip system.

Both modes are added as new `GameMode` cases (`.pokerbee`, `.tejas`) and follow the exact same three-layer pattern as Klondike, Beecell, and Spider: Options struct → ViewModel → View. Options screens mimic `BeecellOptionsView` in layout, with poker-specific pickers at the top in place of the deck-count picker.

---

## User Scenarios & Testing

---

### User Story 1 — Pokerbee: 5-Card Draw Hand (Priority: P1)

The player and AI opponents are each dealt 5 cards. A betting round follows. Each player discards and redraws. A second betting round concludes with a showdown (or fold-out).

**Why this priority**: Core MVP. No other Pokerbee work is possible without a functional hand.

**Acceptance Scenarios**:

1. **Given** a new hand begins, **When** cards are dealt, **Then** each active player (human + all AI) receives exactly 5 face-down cards and the human's hand is shown face-up.
2. **Given** "No Bid" mode is OFF, **When** the pre-draw betting round begins, **Then** the player sees Call / Raise / Fold actions and the current bet is tracked in the pot.
3. **Given** "No Bid" mode is ON, **When** a hand is dealt, **Then** there are no betting rounds; players proceed directly to the discard phase and then straight to showdown.
4. **Given** the draw phase, **When** the player selects cards to discard (0–5), **Then** exactly that many new cards are dealt from the remaining deck to replace them.
5. **Given** all players have drawn, **When** a second betting round completes (or is skipped in No Bid mode), **Then** all remaining players reveal their hands and the best 5-card poker hand wins the pot (or claims a point in No Bid mode).
6. **Given** all opponents fold, **When** the last remaining player wins uncontested, **Then** the pot is awarded immediately without a showdown.
7. **Given** the session chip balance reaches zero, **When** this state is detected, **Then** a "Rebuy" button appears offering to restore the starting chip balance for the remainder of the session.

---

### User Story 2 — Tejas Hold'em: Full Hand (Priority: P1)

The player plays a complete Texas Hold 'Em hand through all four betting rounds (pre-flop, flop, turn, river) to showdown or fold-out.

**Why this priority**: Core MVP for Tejas Hold'em.

**Acceptance Scenarios**:

1. **Given** a new hand begins, **When** cards are dealt, **Then** each player receives exactly 2 face-down hole cards; the dealer button, small blind, and big blind rotate correctly each hand.
2. **Given** the pre-flop betting round, **When** the player acts, **Then** Fold / Check / Call / Raise are available (Check only when no bet to call); an illegal raise below the minimum is rejected.
3. **Given** pre-flop ends, **When** the flop is dealt, **Then** exactly 3 community cards appear face-up and a new betting round begins left of the dealer.
4. **Given** the turn and river, **When** each is dealt, **Then** exactly 1 community card is added per street and a betting round follows each.
5. **Given** two or more players reach showdown, **When** hands are compared, **Then** the best 5-card hand from any combination of 2 hole cards + 5 community cards is selected; ties split the pot.
6. **Given** one player is all-in, **When** other players continue betting, **Then** a side pot is created; the all-in player is only eligible for the main pot.
7. **Given** an AI player's turn, **When** the AI decides, **Then** it acts within the legal action set within 1.5 seconds.

---

### User Story 3 — Shared Visual Customization (Priority: P2)

Both new modes participate in the existing shared options system: dark mode cards, felt color, card back theme, sound effects, and hide-stats/hide-hints toggles persist and sync across all five game modes when switching.

**Acceptance Scenarios**:

1. **Given** the player enables Dark Mode Cards in Pokerbee, **When** they switch to Klondike, **Then** Klondike's cards are also in dark mode.
2. **Given** a custom card back is set in Tejas Hold'em options, **When** face-down cards are rendered at the table, **Then** the custom back appears on all AI hole cards and the deck.
3. **Given** any shared option changes, **When** the player switches game modes, **Then** `syncSharedOptions` propagates the change to all five ViewModels.

---

### User Story 4 — AI Opponents (Priority: P2)

AI players act autonomously on their turns using a configurable difficulty engine.

**Acceptance Scenarios**:

1. **Given** Easy difficulty, **When** an AI acts, **Then** it folds weak hands, calls medium hands, and raises strong hands with minimal bluffing (≤5% bluff rate).
2. **Given** Hard difficulty, **When** an AI acts, **Then** bluff rate is higher (≤20%), and the AI uses pot-odds reasoning to call or fold marginal hands.
3. **Given** an AI's turn in Pokerbee draw phase, **When** the AI discards, **Then** it keeps the highest-value partial hand (pair, flush draw, straight draw) and draws the remainder.

---

## Requirements

### Functional Requirements

- **FR-001**: Add `case pokerbee = "Pokerbee"` and `case tejas = "Tejas Hold\'em"` to `GameMode` enum in `src/Models/GameMode.swift`.
- **FR-002**: Pokerbee implements 5-Card Draw with two betting rounds (pre-draw, post-draw) and a discard/draw phase. Standard poker hand rankings apply.
- **FR-003**: Tejas Hold'em implements Texas Hold 'Em with four betting rounds (pre-flop, flop, turn, river), community cards, and best-5-of-7 hand evaluation.
- **FR-004**: Both modes support 1–5 AI opponents (configurable in options); seat count includes the human player (e.g. "3 players" = human + 2 AI).
- **FR-005**: "No Bid" toggle in Pokerbee options skips all betting rounds; hands are dealt, drawn, and evaluated for a single point per win — no chips involved.
- **FR-006**: Chip balance is session-scoped: initialized from `startingChips` on app launch, never persisted to UserDefaults, reset on next launch. Displayed in the status bar alongside pot and current bet.
- **FR-007**: When chips reach zero, a "Rebuy" action restores the session starting balance. Rebuys are tracked in statistics but do not affect win/loss counts.
- **FR-008**: Both modes contribute to shared statistics: hands played, hands won, biggest pot won, net chip change for the session.
- **FR-009**: AI difficulty (Easy / Medium / Hard) is configurable per game mode in options and controls bluff frequency and pot-odds threshold.
- **FR-010**: Blind / ante amounts are configurable in Tejas options (small blind, big blind) and Pokerbee options (ante). Defaults: small blind 10, big blind 20, ante 10.
- **FR-011**: Starting chip amount is configurable in each game's options (default 1000).
- **FR-012**: Both options screens follow `BeecellOptionsView` structure exactly: poker-specific pickers and fields at the top (above the first Divider), then Timed Game / Sound Effects / Hide Hint / Hide Stats / Dark Mode Cards toggles, then felt color, then custom card art.
- **FR-013**: The `hideHintButton` option hides the Hint button in both poker modes (hints suggest the statistically best action for the current hand).
- **FR-014**: Tejas Hold'em supports side pots when a player goes all-in.
- **FR-015**: `AppCoordinator` must hold `pokerbeeViewModel` and `tejasViewModel` alive simultaneously alongside the three existing ViewModels. `syncSharedOptions` must include all five modes.
- **FR-016**: All new Options structs use `decodeIfPresent ?? default` in `init(from:)` for every field.
- **FR-017**: `options.didSet` in each new ViewModel saves options and posts `feltColorDidChange`, `cardBackThemeDidChange`, `darkModeDidChange` notifications following the existing pattern.

### Key Entities

- **PokerCard** — reuses existing `Card` (rank 1–13, suit, faceUp). No changes to Card.swift.
- **PokerHand** — array of 5 Cards; evaluated rank (Royal Flush → High Card) + kicker array for tiebreaking.
- **PokerHandRank** — `enum` with cases `highCard` through `royalFlush` (9 cases), `Int` raw value for comparison.
- **PokerPlayer** — name, chipBalance, hand ([Card]), currentBet, isFolded, isAllIn, isAI, aiDifficulty.
- **PokerbeeGameState** — players, deck, pot, phase (dealing/preDraw betting/draw/postDraw betting/showdown), activePlayerIndex, dealerIndex.
- **TejasGameState** — players, deck, communityCards ([Card] 0–5), pot, sidePots ([SidePot]), phase (preFlop/flop/turn/river/showdown/handOver), activePlayerIndex, dealerIndex, minimumBet.
- **SidePot** — amount, eligiblePlayerIDs (Set\<UUID\>).
- **PokerbeeOptions** — seatCount, startingChips, ante, aiDifficulty, noBidMode, isTimed, isSoundEnabled, hideHintButton, hideStatsButton, isDarkMode, feltColor, cardBackTheme, customFeltColorRevision.
- **TejasOptions** — seatCount, startingChips, smallBlind, bigBlind, aiDifficulty, isTimed, isSoundEnabled, hideHintButton, hideStatsButton, isDarkMode, feltColor, cardBackTheme, customFeltColorRevision.

---

## Success Criteria

- **SC-001**: The hand evaluator correctly ranks all hand categories with zero errors across a 10,000-hand randomized test suite (shared by Pokerbee and Tejas).
- **SC-002**: No Bid mode in Pokerbee completes a full hand (deal → draw → showdown → award) with no chip state touched.
- **SC-003**: All five game modes sync shared visual options correctly on every mode switch.
- **SC-004**: AI acts within 1.5 seconds per turn at all table sizes.
- **SC-005**: `make build` succeeds with all five game modes; the app launches to the game selector and all modes are selectable.

## Assumptions

- The existing `CardView` and card rendering system requires no changes for poker use.
- Window minimum size may need adjustment for the Tejas Hold'em table layout (more horizontal space needed for community cards + seats).
- No network multiplayer in v1; AI opponents only.
- No real-money or gambling mechanics; chips are fictional session-only values.
- Both new ViewModels follow the `@Observable` macro pattern, identical to `BeecellViewModel`.
