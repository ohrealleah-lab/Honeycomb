# Requirements Checklist: PokerBee Suite

## Functional Requirements

- [ ] FR-001: Texas Hold 'Em supports 2–6 seats (1 human + up to 5 AI)
- [ ] FR-002: Blackjack supports 1 human vs. dealer, 1–8 configurable decks
- [ ] FR-003: AI opponents use rule-based strategy (Chen formula + pot odds) with configurable bluff frequency
- [ ] FR-004: Blackjack dealer hits soft 16 or less, stands on hard or soft 17+
- [ ] FR-005: Card rendering engine matches SoliBee's CardView visually on macOS
- [ ] FR-006: Custom art stored in `~/Library/Application Support/PokerBee/` (macOS) / `%APPDATA%\PokerBee\` (Windows)
- [ ] FR-007: Dark mode colors — bg #1E1E1E, red #FF4444, black #C0C0C0, border (0.3, 0.3, 0.3)
- [ ] FR-008: Shared options sync across game modes via syncSharedOptions
- [ ] FR-009: All Options structs use decodeIfPresent ?? default in Codable init
- [ ] FR-010: Sound effects on deal, chip win, hit, and bust
- [ ] FR-011: Status bar shows chip balance, current bet, pot total, hand timer
- [ ] FR-012: Window resize scales card layout proportionally (zoom system)
- [ ] FR-013: Texas Hold 'Em supports side pots for all-in players
- [ ] FR-014: Blackjack supports Insurance when dealer shows Ace

## Non-Functional Requirements

- [ ] Hand evaluator 100% correct over 10,000-hand randomized test
- [ ] AI decision time ≤ 1.5 seconds
- [ ] No platform-specific code in PokerBeeCore (verified by `swift test` on Windows)
- [ ] All settings survive app restart with 100% fidelity
- [ ] Card rendering pixel-matches SoliBee on macOS for same card + options
