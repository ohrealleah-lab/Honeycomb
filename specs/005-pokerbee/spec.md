# Feature Specification: PokerBee Suite

**Feature Branch**: `005-pokerbee`

**Created**: 2026-06-24

**Status**: Draft

## Overview

PokerBee is a native card game suite containing **Texas Hold 'Em** (multiplayer / vs. AI) and **Blackjack** (vs. dealer). It is a sibling project to SoliBee, sharing the same card rendering engine, visual customization system (custom card backs, custom face card art, custom felt), and aesthetic identity. The architecture separates game logic into a cross-platform Swift Package (`PokerBeeCore`) that compiles on both macOS and Windows, with platform-native UI shells on top.

---

## User Scenarios & Testing *(mandatory)*

---

### User Story 1 — Texas Hold 'Em: Deal, Bet, and Showdown (Priority: P1)

The player sits at a table with up to 5 AI opponents and plays a complete hand of Texas Hold 'Em through all four betting rounds (pre-flop, flop, turn, river) to showdown or fold-out.

**Why this priority**: Core MVP. Without deal/bet/showdown the game cannot be played.

**Independent Test**: Start a game, play through all four rounds manually, reach showdown, verify correct winner evaluation.

**Acceptance Scenarios**:

1. **Given** a new hand begins, **When** cards are dealt, **Then** each player receives exactly 2 hole cards face-down, and the dealer button, small blind, and big blind positions rotate correctly.
2. **Given** it is the player's turn to act, **When** the player chooses Fold / Call / Raise, **Then** the pot is updated, the next player to act is determined, and illegal actions (raise below minimum) are rejected.
3. **Given** the pre-flop round ends, **When** the flop is dealt, **Then** exactly 3 community cards are revealed face-up and a new betting round begins from the player left of the dealer.
4. **Given** all players except one have folded, **When** the last remaining player wins uncontested, **Then** the pot is awarded immediately without revealing hole cards.
5. **Given** two or more players reach showdown, **When** hands are compared, **Then** the correct 5-card best hand from any combination of 2 hole cards + 5 community cards is selected, and the highest hand wins (with correct split-pot resolution for ties).
6. **Given** an AI player's turn, **When** the AI decides its action, **Then** it acts within the legal action set and does so within 1.5 seconds.

---

### User Story 2 — Blackjack: Deal, Hit, Stand, Bust (Priority: P1)

The player plays a hand of standard casino-style Blackjack against a dealer, with options to Hit, Stand, Double Down, and Split pairs.

**Why this priority**: Core MVP for Blackjack. Without deal and basic actions the game cannot be played.

**Independent Test**: Deal a hand, hit to 21 and to bust, stand, verify dealer draws to 17+, verify win/loss/push payouts.

**Acceptance Scenarios**:

1. **Given** a new hand begins, **When** cards are dealt, **Then** the player and dealer each receive 2 cards; the dealer's second card is face-down (hole card).
2. **Given** the player's hand totals 21 with the initial 2 cards, **When** the hand is evaluated, **Then** a Blackjack is declared and the player is paid 3:2 unless the dealer also has Blackjack (push).
3. **Given** the player chooses Hit, **When** the new card pushes the hand total over 21 (with no ace to convert), **Then** the player busts and loses the bet immediately.
4. **Given** the player stands, **When** it is the dealer's turn, **Then** the dealer reveals the hole card and draws until the hand total is 17 or more (soft 17 stands).
5. **Given** the player's initial two cards have the same rank, **When** the player chooses Split, **Then** two separate hands are created, each receives one additional card, and the player acts on each hand independently.
6. **Given** the player chooses Double Down (hand total 9, 10, or 11), **When** the action is confirmed, **Then** the bet is doubled and exactly one more card is dealt; no further actions are available on that hand.

---

### User Story 3 — Shared Visual Customization (Priority: P2)

The player can customize card backs, face card art (J/Q/K/A per suit), felt color, and dark mode cards — identical to the SoliBee customization system.

**Why this priority**: Defines the visual identity that sets PokerBee apart from generic card games.

**Independent Test**: Load custom card back PNG/GIF, upload face card art for each slot, change felt color, toggle dark mode; verify all changes persist after app restart.

**Acceptance Scenarios**:

1. **Given** the player opens Preferences, **When** they upload a PNG or GIF as a card back, **Then** the new back renders on all face-down cards immediately, with GIF animation limited to the stock/deal pile.
2. **Given** custom face card art is uploaded for a slot (e.g. Red Queen), **When** that card is rendered face-up, **Then** the custom art takes priority over the default letter image.
3. **Given** the player selects a felt color or custom color, **When** confirmed, **Then** all game boards update immediately via the existing notification system.
4. **Given** the player enables Dark Mode Cards, **When** a face-up card is rendered, **Then** the card background is #1E1E1E, red suits are #FF4444, black suits are #C0C0C0, and J/Q/K render the dark-mode letter images.
5. **Given** any customization is saved, **When** the application is relaunched, **Then** all settings are restored exactly.

---

### User Story 4 — Statistics, Chips, and Session History (Priority: P2)

The player accumulates chips across hands, can view session statistics, and has a persistent chip balance.

**Why this priority**: Without stakes and chip tracking, neither game has meaningful progression.

**Acceptance Scenarios**:

1. **Given** the player wins a Blackjack hand, **When** the hand resolves, **Then** chips are added at the correct payout ratio (1:1 standard, 3:2 Blackjack) and the chip display updates.
2. **Given** the player loses all chips, **When** this state is detected, **Then** a "Buy In" option is offered to restore the starting balance.
3. **Given** the player opens Statistics, **When** the view is displayed, **Then** hands played, hands won, win percentage, biggest pot won, and net chip change are shown per game mode.
4. **Given** chip balance and statistics, **When** the player quits and relaunches, **Then** balance and statistics are fully restored from UserDefaults.

---

## Requirements

### Functional Requirements

- **FR-001**: Support Texas Hold 'Em with 2–6 seats (1 human + up to 5 AI).
- **FR-002**: Support Blackjack with 1 human player vs. a dealer, with 1–8 configurable decks.
- **FR-003**: AI opponents in Texas Hold 'Em MUST use a rule-based strategy engine (fold/call/raise based on hand strength and pot odds); bluffing at configurable frequency.
- **FR-004**: Dealer in Blackjack MUST follow standard casino rules: hit on soft 16 or less, stand on hard or soft 17+.
- **FR-005**: The card rendering engine MUST be byte-for-byte identical to SoliBee's `CardView`, `CardFrontView`, `CardCenterSuitView`, and `FaceCardImageView` on macOS, and a faithful port on Windows.
- **FR-006**: Custom card back, custom face card art, and felt color customization MUST use the same data structures and file storage paths as SoliBee (`~/Library/Application Support/PokerBee/` on macOS, `%APPDATA%\PokerBee\` on Windows).
- **FR-007**: Dark mode cards MUST use the same color values: bg #1E1E1E, red #FF4444, black #C0C0C0, border `Color(red:0.3,green:0.3,blue:0.3)`.
- **FR-008**: All shared options (dark mode, felt color, card back, sound) MUST sync across game modes when switching, using the same `syncSharedOptions` pattern as SoliBee's `AppCoordinator`.
- **FR-009**: Options structs MUST use `decodeIfPresent ?? default` in all Codable inits so new fields survive old saves without migration.
- **FR-010**: Sound effects MUST play on deal, chip win, card hit, and bust events.
- **FR-011**: The game MUST display a live chip balance, current bet, pot total, and timer (elapsed per hand) in the status bar.
- **FR-012**: The player MUST be able to resize the game window and the card layout scales proportionally (same zoom system as SoliBee).
- **FR-013**: Texas Hold 'Em MUST support side pots when one or more players are all-in.
- **FR-014**: Blackjack MUST support Insurance when the dealer's up-card is an Ace.

### Key Entities

- **Card**: rank 1–13, suit (hearts/diamonds/spades/clubs), faceUp Bool — identical to SoliBee `Card`.
- **Deck**: ordered collection of Cards with shuffle; multi-deck support for Blackjack.
- **PokerHand**: 5-card evaluated hand with rank (Royal Flush → High Card) and tiebreaker kicker values.
- **Player**: name, chipBalance, holeCards, currentBet, isFolded, isAllIn, isDealer, isAI.
- **PokerGameState**: community cards, pot, sidePots, currentPhase, activePlayerIndex, dealerIndex.
- **BlackjackHand**: cards array, computed total (with ace flexibility), isBust, isBlackjack, isSplit.
- **BlackjackGameState**: playerHands (array for splits), dealerHand, currentBet, phase.
- **GameOptions** (shared): feltColor, cardBackTheme, isDarkMode, isSoundEnabled, isDarkMode, customFeltColorRevision — mirrors SoliBee pattern.

---

## Success Criteria

- **SC-001**: Texas Hold 'Em hand evaluator correctly ranks all hand categories with zero errors across a 10,000-hand randomized test suite.
- **SC-002**: Blackjack dealer behavior conforms to casino rules in 100% of automated deal simulations.
- **SC-003**: Card rendering is pixel-identical on macOS between SoliBee and PokerBee for the same card and options combination.
- **SC-004**: All customization settings survive app restart with 100% fidelity.
- **SC-005**: AI action decision time is under 1.5 seconds per turn at all table sizes.
- **SC-006**: The Windows build compiles and runs with no platform-specific code in `PokerBeeCore`.

## Assumptions

- macOS target: 14.0+ (same as SoliBee).
- Windows target: Windows 11 / Windows 10 (build 19041+), Swift 5.10 for Windows via swift.org toolchain.
- The card rendering system is extracted from SoliBee into a shared Swift module; no visual regression from the extraction.
- No real-money gambling mechanics; chip values are fictional.
- No networked multiplayer in v1; AI opponents only.
