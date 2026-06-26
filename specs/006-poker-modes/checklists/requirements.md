# Requirements Checklist: Pokerbee & Tejas Hold'em

## Functional Requirements

- [ ] FR-001: GameMode enum has `.pokerbee = "Pokerbee"` and `.tejas = "Tejas Hold\'em"` cases
- [ ] FR-002: Pokerbee implements 5-Card Draw — two betting rounds + discard/draw phase
- [ ] FR-003: Tejas implements Texas Hold 'Em — four streets (preFlop/flop/turn/river)
- [ ] FR-004: Both modes support 1–5 AI opponents (configurable via seatCount option)
- [ ] FR-005: Pokerbee "No Bid" toggle skips all betting rounds; chips not involved
- [ ] FR-006: Chip balance is session-scoped (initialized from startingChips, resets on launch, never persisted)
- [ ] FR-007: Rebuy restores starting balance and increments statistics.rebuyCount
- [ ] FR-008: Both modes update handsPlayed, handsWon, biggestPotWon, netSessionChips statistics
- [ ] FR-009: AI difficulty (Easy/Medium/Hard) configurable per mode; controls bluff rate and fold threshold
- [ ] FR-010: Ante configurable in Pokerbee; smallBlind + bigBlind configurable in Tejas
- [ ] FR-011: Starting chip amount configurable in both options screens (default 1000)
- [ ] FR-012: Options screens: poker fields at top, then shared toggle block, then felt, then art — matching BeecellOptionsView order and style
- [ ] FR-013: hideHintButton hides the Hint button in both poker modes
- [ ] FR-014: Tejas supports side pots for all-in players
- [ ] FR-015: AppCoordinator holds all 5 ViewModels simultaneously; syncSharedOptions covers all 5 modes
- [ ] FR-016: All new Options structs use decodeIfPresent ?? default in init(from:)
- [ ] FR-017: options.didSet posts feltColorDidChange, cardBackThemeDidChange, darkModeDidChange notifications

## Non-Functional Requirements

- [ ] Hand evaluator correct across 10,000-hand randomized test
- [ ] AI acts within 1.5 seconds per turn
- [ ] make build succeeds with all 5 modes
- [ ] All visual options sync correctly on every mode switch across all 5 modes
- [ ] Pokerbee-specific and Tejas-specific options survive app restart; session chips do not
