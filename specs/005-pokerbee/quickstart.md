# PokerBee Quickstart & Validation Guide

## Prerequisites

**macOS**: macOS 14.0+, Xcode Command Line Tools with Swift 5.10 (`swift --version`).  
**Windows**: Windows 10/11, Swift for Windows toolchain from swift.org, WinUI 3 SDK.

---

## Build Commands

### macOS
```bash
make build    # swift build -c release + assemble PokerBee.app + codesign
make run      # build + open PokerBee.app
make test     # compile and run PokerBeeTests/
make clean    # remove PokerBee.app and .build/
```

### Windows (PowerShell)
```powershell
swift build -c release
# Binary: .build\release\PokerBee.exe
swift test    # run PokerBeeTests on Windows — validates Core is platform-clean
```

---

## Test Execution

`TestRunner.swift` is the entry point (same pattern as SoliBee — no XCTest). Run individual suites by editing `TestRunner.swift` to call only the desired suite.

```bash
make test
```

Validates:
1. Deck integrity — 52 cards per deck, no duplicates after shuffle.
2. Hand evaluator — all 9 hand ranks correct, tiebreakers resolve deterministically.
3. Texas Hold 'Em state machine — deal, betting rounds, side pots, showdown.
4. Blackjack — soft totals, dealer draw-to-17, split/double payouts.
5. Options round-trip — encode to JSON, decode, verify all defaults survive.

---

## Manual Validation Checklist

### Card Rendering
- [ ] Cards in light mode match SoliBee visually (same fonts, same suit positions, same face card images).
- [ ] Dark mode cards: background #1E1E1E, red suits #FF4444, black suits #C0C0C0, border visible.
- [ ] J/Q/K in dark mode display the dark mode letter images (not vector shapes, not light mode PNGs).
- [ ] Custom card back PNG uploads and appears on all face-down cards immediately.
- [ ] GIF card back animates on the deal pile only.
- [ ] Custom face card art takes priority over default J/Q/K/A images.
- [ ] Felt color changes apply immediately to both game boards.
- [ ] All customization survives app restart.

### Texas Hold 'Em
- [ ] Dealer button rotates each hand.
- [ ] Small and big blinds are posted correctly from the right seats.
- [ ] Fold/Call/Raise buttons are disabled when it is not the player's turn.
- [ ] Raising below the minimum is rejected with no state change.
- [ ] Flop reveals 3 cards, turn 1, river 1 — each followed by a betting round.
- [ ] When all players but one fold, pot is awarded without showdown.
- [ ] Showdown correctly identifies the winning hand; split pot on tie.
- [ ] AI acts within 1.5 seconds per turn.
- [ ] All-in player creates a side pot; ineligible players cannot win it.

### Blackjack
- [ ] Dealer hole card is face-down until dealer's turn.
- [ ] Player Blackjack pays 3:2 (unless dealer also has BJ → push).
- [ ] Hit, Stand, Double Down, Split each produce the correct state.
- [ ] Double Down is available only on totals 9, 10, or 11.
- [ ] Split is available only when both cards share the same rank.
- [ ] Dealer draws until total ≥ 17; does not draw on soft 17.
- [ ] Insurance is offered when dealer up-card is Ace; pays 2:1 if dealer has BJ.
- [ ] Chip balance updates correctly after win, loss, and push.
- [ ] Buy In flow appears when chip balance reaches zero.

### Cross-Platform (Windows)
- [ ] `swift test` passes with zero failures on Windows.
- [ ] `PokerBee.exe` launches and renders cards at the correct dimensions (128×181).
- [ ] Dark mode colors match macOS values exactly.
- [ ] Custom art files are read from `%APPDATA%\PokerBee\` correctly.
- [ ] No `#if os(macOS)` guards exist anywhere in `Sources/PokerBeeCore/`.
