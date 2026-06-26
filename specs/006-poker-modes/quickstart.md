# Quickstart & Validation Guide: Pokerbee & Tejas Hold'em

## Build & Run

```bash
make build   # swift build -c release + bundle + codesign
make run     # build + open SoliBee.app
make test    # compile and run all tests including new poker suites
make clean   # remove SoliBee.app and .build/
```

No new dependencies. All new source files under `src/Pokerbee/` and `src/Tejas/` are picked up automatically by SPM.

---

## Test Execution

Edit `SoliBeeTests/TestRunner.swift` to include `PokerHandEvaluatorTests`, `PokerbeeViewModelTests`, and `TejasViewModelTests`. Run with `make test`.

Key suites:
1. **PokerHandEvaluatorTests** — all 9 hand ranks, tiebreaker kicker ordering, 10,000-hand randomized correctness.
2. **PokerbeeViewModelTests** — deal card counts, ante deduction, discard/draw, noBidMode phase skipping, showdown winner.
3. **TejasViewModelTests** — blind posting, dealer rotation, pre-flop through river state machine, side pot construction, showdown.

---

## Manual Validation Checklist

### Game Mode Switching
- [ ] All 5 modes appear in the game mode selector.
- [ ] Switching from Pokerbee to Klondike carries over isDarkMode, isSoundEnabled, hideHintButton, hideStatsButton, feltColor, cardBackTheme.
- [ ] Switching back to Pokerbee restores its game-specific options (seatCount, ante, etc.) unchanged.

### Pokerbee — 5-Card Draw
- [ ] New hand deals exactly 5 cards to each seat.
- [ ] Antes are deducted from all players and added to the pot.
- [ ] Human can select 0–5 cards to discard; "Draw" replaces exactly those cards.
- [ ] AI discard behavior differs visibly by difficulty (Easy discards more liberally, Hard keeps draws).
- [ ] Fold removes a player from the hand; pot is awarded if only 1 remains.
- [ ] Showdown reveals all hands and awards pot to the correct winner.
- [ ] In No Bid Mode: no ante prompt, no Fold/Call/Raise buttons appear; hand goes directly deal → draw → showdown.
- [ ] Session chips decrement on loss, increment on win; reaching zero shows "Rebuy" button.
- [ ] "Rebuy" restores starting chip amount and increments rebuy count in statistics.
- [ ] Preferences opens options sheet; all poker-specific fields appear above the first Divider.
- [ ] Changing AI Difficulty in options takes effect on the next hand.

### Tejas Hold'em
- [ ] Dealer button rotates each hand; small blind and big blind are posted from the correct seats.
- [ ] Pre-flop deals exactly 2 hole cards per player.
- [ ] Check is only available when no bet is to call; Raise minimum is enforced.
- [ ] Flop reveals exactly 3 community cards; Turn and River each reveal 1.
- [ ] A new betting round begins after each community card reveal.
- [ ] All-in creates a side pot visible in the UI; the all-in player cannot win chips they aren't eligible for.
- [ ] Showdown correctly evaluates best 5-of-7 for each player and awards the pot.
- [ ] AI acts within 1.5 seconds per turn.
- [ ] Preferences shows seatCount, AI Difficulty, Starting Chips, Small Blind, Big Blind at the top.

### Shared Visual Options (both modes)
- [ ] Dark Mode Cards renders correctly: bg #1E1E1E, red suits #FF4444, black suits #C0C0C0.
- [ ] J/Q/K in dark mode use the dark mode letter images, not the light-mode PNGs.
- [ ] Custom card back appears on all face-down cards (AI hole cards, deck).
- [ ] Custom face card art takes priority over default J/Q/K images.
- [ ] Felt color changes apply immediately on OK.
- [ ] All options survive app restart (poker-specific options only; session chips reset).
