# Feature Specification: SoliBee Complete Suite

**Feature Branch**: `008-solibee-complete`

**Created**: 2026-07-15

**Status**: Current

**Input**: Consolidated from specs 001–007 to reflect the game as it currently exists.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Klondike Solitaire (Priority: P1)

The player can start a game of Klondike Solitaire in either Draw One or Draw Three mode, move cards between Tableau, Foundation, Stock, and Waste piles using standard rules, undo moves, and win when all 52 cards are placed on the four Foundation piles. Two scoring systems are available: Standard (points-based with time penalty and win bonus) and Vegas (currency-based with recycle limits).

**Why this priority**: Klondike is the original and primary game mode of SoliBee.

**Independent Test**: Start a Draw One Standard game, deal from stock, move cards between tableau columns, move a card to a foundation, undo the move, and verify score and state revert correctly.

**Acceptance Scenarios**:

1. **Given** a new Draw One game, **When** the player clicks the stock pile, **Then** one card is drawn to the waste pile.
2. **Given** a new Draw Three game, **When** the player clicks the stock pile, **Then** up to three cards are drawn and only the top waste card is playable.
3. **Given** standard scoring, **When** a card is moved from waste to tableau, **Then** score increases by +5; waste to foundation +10; tableau to foundation +10; flipping a face-down tableau card +5; foundation back to tableau −15.
4. **Given** standard scoring, **When** the game is won, **Then** the time penalty (`−2 × elapsed_seconds / 10`) and time bonus (`700,000 / elapsed_seconds`) are both applied once at game completion.
5. **Given** Vegas scoring, **When** a card is placed on a foundation, **Then** the bankroll increases by $0.50; initial bankroll starts at −$52.00.
6. **Given** Vegas scoring with Draw Three, **When** the stock is recycled more than once, **Then** further recycling is blocked; Draw One Vegas allows zero recycles.
7. **Given** any move, **When** the player presses Cmd+Z, **Then** the move is reversed and the undo penalty (equal to points earned by the undone move) is subtracted from the standard-mode score.
8. **Given** all tableau cards are face-up and stock/waste are empty, **When** the autocomplete condition is met, **Then** an Autocomplete button becomes available and the game plays itself to completion.
9. **Given** an empty waste pile after all stock cards are drawn in standard mode, **When** the player clicks the stock, **Then** the waste cards are recycled back to stock with no score penalty (no recycle limit in standard mode).

---

### User Story 2 - BeeCell (Freecell Solitaire) (Priority: P1)

The player can play Freecell ("BeeCell") in single-deck (52 cards, 4 free cells, 4 foundations, 8 tableau columns) or double-deck (104 cards, 8 free cells, 8 foundations, 10 columns) mode. All cards are dealt face-up. Cards move through free cells as temporary holding spots and build onto foundations in suit order from Ace upward.

**Why this priority**: BeeCell is a co-primary game mode with a fully distinct rule set.

**Independent Test**: Start a single-deck BeeCell game, move a card to a free cell, move a sequence of cards between tableau columns, and verify multi-card sequence movement limits are enforced.

**Acceptance Scenarios**:

1. **Given** a BeeCell game, **When** the player drags a single card to a free cell, **Then** the card occupies that cell and is no longer part of its tableau column.
2. **Given** a BeeCell game with 2 empty free cells and 1 empty tableau column, **When** the player attempts to move a sequence onto an occupied column, **Then** the maximum movable cards is `(1 + 2) × 2^1 = 6`.
3. **Given** a BeeCell game with 2 empty free cells and 1 empty tableau column, **When** the player attempts to move a sequence onto an empty column, **Then** the maximum movable cards is `(1 + 2) × 2^(1−1) = 3`.
4. **Given** all four foundations in a single-deck BeeCell game are complete, **When** the last card is placed, **Then** the victory state triggers and the win animation plays.
5. **Given** double-deck mode is selected, **When** a new game starts, **Then** 104 cards are dealt across 10 tableau columns with 8 free cells and 8 foundations.
6. **Given** Vegas scoring in BeeCell, **When** a new game is started, **Then** the starting score is −$52.00 (single-deck) or −$104.00 (double-deck), with +$0.50 per foundation card.

---

### User Story 3 - Spider Solitaire (Priority: P1)

The player can play Spider Solitaire in 1-suit, 2-suit, or 4-suit difficulty modes. Cards stack in descending order on tableau columns regardless of suit, but only a complete descending same-suit run from King to Ace is swept to a foundation. Deal buttons replenish tableau columns from stock.

**Why this priority**: Spider is a co-primary game mode with its own distinct challenge levels.

**Independent Test**: Start a 1-suit Spider game, stack cards in descending order, complete a King-to-Ace same-suit run, and verify it is automatically swept to the foundation.

**Acceptance Scenarios**:

1. **Given** a Spider game, **When** the player places a card of any suit on a tableau card of the next higher rank, **Then** the move is accepted regardless of suit.
2. **Given** a Spider tableau column containing a complete King-to-Ace same-suit run, **When** the run is completed, **Then** it is automatically swept to a foundation pile.
3. **Given** stock cards remain, **When** the player clicks Deal, **Then** one card is dealt to each non-empty tableau column.
4. **Given** 4-suit mode, **When** a new game starts, **Then** two full decks (104 cards) are distributed across 10 tableau columns.
5. **Given** all 8 foundations are filled (one per complete suit run in 4-suit mode), **When** the last run is swept, **Then** the victory state is triggered.

---

### User Story 4 - Video Poker (Priority: P1)

The player bets 1–5 credits, receives a 5-card hand, selects cards to hold, draws replacements, and is paid according to the active pay table. Three variants are available: Jacks or Better (9/6 full-pay), Deuces Wild, and Bonus Poker. Session credits are tracked but never persisted across sessions.

**Why this priority**: Video Poker is a distinct casino-style game mode with its own complete rule set and pay tables.

**Independent Test**: Start a Jacks or Better game, bet 5 credits, deal a hand, hold specific cards, draw replacements, and verify correct pay table lookup and credit adjustment.

**Acceptance Scenarios**:

1. **Given** a Jacks or Better game with a 5-credit bet, **When** the player draws a Royal Flush, **Then** the payout is 800 credits (the bonus multiplier for 5-credit bet).
2. **Given** a Deuces Wild game, **When** the hand contains one or more 2s, **Then** the 2s act as wilds and the best possible hand rank is awarded.
3. **Given** a Bonus Poker game, **When** the player draws four Aces, **Then** the payout is 80 × bet (the special Aces bonus).
4. **Given** any video poker game, **When** the player clicks a card during the hold phase, **Then** the card toggles between held and non-held states.
5. **Given** credits reach zero, **When** the player tries to deal, **Then** a rebuy prompt appears (unless No Stress Mode is active, in which case credits never change).
6. **Given** Jacks or Better, **When** a pair of Jacks or higher is the best hand, **Then** the payout is 1 × bet; no payout for pairs lower than Jacks.

---

### User Story 5 - Blackjack (Priority: P1)

The player bets credits, receives two cards, and plays against a dealer following standard casino Blackjack rules. Hit, Stand, Double Down, Split, and Insurance actions are available where applicable. The dealer hits soft 16 or below and stands on hard or soft 17+. Session credits are tracked but not persisted.

**Why this priority**: Blackjack is a co-primary card game mode with a complete casino rule set.

**Independent Test**: Start a Blackjack game, bet 10 credits, receive a hand totalling 11, Double Down, receive one more card, and verify the bet doubled and only one additional card was dealt.

**Acceptance Scenarios**:

1. **Given** a Blackjack game, **When** the player is dealt a natural Blackjack (Ace + 10-value card), **Then** the hand is automatically resolved with a 3:1 payout (e.g., bet 10 → win 30) unless the dealer also has Blackjack (push).
2. **Given** a two-card hand totalling 9, 10, or 11, **When** the player chooses Double Down, **Then** the bet doubles and exactly one more card is dealt; no further actions are available on that hand.
3. **Given** a two-card hand of matching rank, **When** the player chooses Split, **Then** the hand splits into two independent hands each receiving an additional card; each hand is then played separately.
4. **Given** the dealer's face-up card is an Ace, **When** Insurance is offered, **Then** the player may wager up to half their current bet on whether the dealer has Blackjack.
5. **Given** the player stands or busts all hands, **When** the dealer turn begins, **Then** the dealer reveals the hole card and draws until reaching 17 or higher before the result is evaluated.
6. **Given** No Stress Mode is active, **When** playing Blackjack, **Then** credit balances are never deducted or increased and the game is purely for entertainment.

---

### User Story 6 - Visual Customization: Card Backs, Face Art & Dark Mode (Priority: P2)

The player can select from built-in card back themes (Vulpera, Moogle, Dingwall), add custom card backs from local image files, and customize face card art (Jack, Queen, King, Ace) per suit slot. A Dark Mode card color palette can be toggled. All selections persist across app restarts and apply to every game mode simultaneously.

**Why this priority**: Visual personalization is a key SoliBee differentiator but does not block gameplay.

**Independent Test**: Open the Themes panel, import a custom card back PNG, adjust its scale and position sliders, save it, and verify it appears correctly during a game and on the next app launch.

**Acceptance Scenarios**:

1. **Given** the Themes panel is open, **When** the player selects Moogle or Dingwall, **Then** all face-down cards across every game mode immediately display the new card back.
2. **Given** the player clicks "Add Custom" for card backs, **When** a PNG or JPG file is selected, **Then** a full-screen editor opens with Scale, Horizontal Position, and Vertical Position sliders that adjust the card back preview in real time.
3. **Given** a custom card back is saved with scale and offset values, **When** cards are rendered face-down in the game, **Then** the image appears with those exact saved offsets and scale factor applied.
4. **Given** the face card art editor is open for a specific suit-slot (e.g., Jack of Spades), **When** the player imports a custom image, **Then** that image replaces the programmatic art for that specific face card combination across all game modes.
5. **Given** Dark Mode cards is toggled on, **When** any card is rendered, **Then** the card background uses a dark (#1E1E1E) color with red suits in #FF4444 and black suits in #C0C0C0.

---

### User Story 7 - Visual Customization: Felt Colors, Backgrounds & Themes (Priority: P2)

The player can choose a table felt color from a preset list (Felt Green, Crimson, Royal Blue, Charcoal, Desert) or a custom color. A custom background image can be imported and positioned independently of the felt color. Multiple customization presets can be saved as named Themes and recalled instantly.

**Why this priority**: Table aesthetics are a major part of the SoliBee identity but don't affect game logic.

**Independent Test**: Add a custom background image, adjust its position, save a Theme combining the background with a felt color and card back, then switch to another Theme and back to verify the preset restores correctly.

**Acceptance Scenarios**:

1. **Given** the player selects Crimson from the felt color list, **When** the board renders, **Then** all game modes display the new felt color immediately.
2. **Given** the player uploads a custom background image (PNG/JPG, ≤ 25 MB), **When** the background editor opens, **Then** scale, horizontal offset, and vertical offset sliders update the preview in real time.
3. **Given** a missing custom background file, **When** the app loads, **Then** the background gracefully falls back to the active felt color without an error or crash.
4. **Given** a custom background is referenced by a saved Theme, **When** the player tries to delete the background, **Then** deletion is blocked with a message naming the referencing Theme.
5. **Given** a named Theme is saved, **When** the player selects that Theme from the list, **Then** the felt color, card back, and background are all restored in a single action.

---

### User Story 8 - Statistics, Scoring & Persistence (Priority: P2)

The application tracks lifetime game statistics separately per game mode and scoring variant (Standard vs. Vegas). Statistics include wins, losses, streaks, and high scores. All game preferences (felt color, card back, draw mode, etc.) are automatically restored on next launch.

**Why this priority**: Persistent stats and preferences are essential for a complete native app experience.

**Independent Test**: Win a Standard Klondike game, note the score and win count, quit the app, relaunch, and verify both are correctly displayed.

**Acceptance Scenarios**:

1. **Given** a Standard Klondike game is won, **When** the statistics panel is opened, **Then** games played, games won, win percentage, current streak, longest streak, and high score are updated.
2. **Given** Standard and Vegas modes each have a high score, **When** the player switches between modes, **Then** the high score display updates to reflect the active scoring mode's record.
3. **Given** the app is relaunched after any game, **When** the launch sequence completes, **Then** the previously selected draw mode, felt color, card back theme, and sound toggle are restored exactly as left.
4. **Given** the options or statistics files in storage are corrupted, **When** the app loads, **Then** it gracefully resets to default values without crashing.
5. **Given** the Statistics panel is open, **When** the player chooses Reset Statistics, **Then** all counters return to zero after a confirmation prompt.

---

### User Story 9 - Sound Effects & Victory Cascade Animation (Priority: P3)

Card shuffle, placement, and victory sound effects play at appropriate moments. Upon winning any game, a full-screen cascade of bouncing cards animates across the window. Both sounds and animations can be independently disabled.

**Why this priority**: Audio and animation are polish that enhances the nostalgic experience but do not affect core gameplay.

**Independent Test**: Win a game, verify the cascade animates with cards bouncing off window edges, then toggle sound off and win another game to verify silence.

**Acceptance Scenarios**:

1. **Given** a new game starts, **When** cards are dealt, **Then** a shuffle sound plays.
2. **Given** a card is placed on a valid target, **When** the move completes, **Then** a snap sound plays (if sound is enabled).
3. **Given** the game is won, **When** the win state is detected, **Then** a victory fanfare plays and a card-bouncing cascade animation fills the window, with each card bouncing off window edges.
4. **Given** a cascading card travels completely off-screen, **When** it exits the viewport, **Then** it is removed from the view hierarchy immediately to prevent resource accumulation.
5. **Given** sound is toggled off in options, **When** any card event or win occurs, **Then** no audio plays until sound is re-enabled.
6. **Given** the player starts a new game while a victory cascade is running, **When** the new game begins, **Then** the cascade stops immediately and all animation resources are released.

---

### User Story 10 - Hint Engine & Keyboard Navigation (Priority: P3)

The player can request a move hint at any time during Klondike or BeeCell games. A set of keyboard shortcuts provides quick access to common actions without using the mouse. The game board supports keyboard cursor navigation for accessible play.

**Why this priority**: Hints and keyboard navigation are quality-of-life features that don't change core rules.

**Independent Test**: Press Cmd+H during a Klondike game and verify a valid move is visually indicated; press Cmd+Z to undo and verify state reverts.

**Acceptance Scenarios**:

1. **Given** a game is in progress, **When** the player presses Cmd+H, **Then** a valid move is highlighted on the board.
2. **Given** a game is in progress, **When** the player presses Cmd+Z, **Then** the last action is undone (subject to undo penalty in Standard mode).
3. **Given** a game is in progress, **When** the player presses Cmd+N, **Then** a new game confirmation dialog appears.
4. **Given** Klondike is active, **When** the player presses Cmd+1 or Cmd+3, **Then** a new game confirmation appears set to Draw One or Draw Three respectively.
5. **Given** No Stress Mode is active, **When** the player plays any game, **Then** the timer does not count, score never changes from time-related adjustments, and credits in Blackjack and Video Poker are unaffected by wins and losses.

---

### User Story 11 - Honeycomb (Triple Triad-Style Card Battle) (Priority: P1)

The player battles an AI opponent on a 3×3 grid using 5-card hands drawn from an 800-card database (4 suits × 200 cards, 1★–5★ rarity). Placing a card next to an opponent's card compares the touching directional stats; the higher value captures (flips) the opponent's card, with chain-reaction combos possible. Up to two optional match rules can modify capture logic, hand visibility, or which card may legally be played each turn. Winners can permanently unlock played cards into a persistent Card Bank and build named decks subject to rarity caps.

**Why this priority**: Honeycomb is a fully independent, complete game mode with its own card economy, AI, and progression system — comparable in scope to the five core card games.

**Independent Test**: Start a match on Medium difficulty with no rules active, place a card adjacent to an opponent's card with a higher facing stat, verify the capture (and any resulting chain flips), fill the board, and verify the winner is declared and the post-game "Take a Card" prompt appears.

**Acceptance Scenarios**:

1. **Given** a card is placed adjacent to an enemy-owned card, **When** the attacking card's facing stat exceeds the defending card's opposite-facing stat, **Then** the defending card flips to the attacker's owner, and any of *its* neighbors that can now be captured are flipped in a chain (combo).
2. **Given** the **Same** rule is active, **When** two or more of a placed card's touching neighbors have an equal facing stat to the attacker (friendly or enemy alike counts toward the trigger), **Then** all matching neighbors are captured.
3. **Given** the **Plus** rule is active, **When** two or more touching neighbor pairs sum to the same value as the attacker's facing stat, **Then** all cards in that matching group are captured.
4. **Given** **Ascension** (or **Descension**) is active, **When** a card of the affected suit is placed or already on the board, **Then** every card of that suit on the board gets `+1` (or `-1`) to all four sides for each card of that suit currently on the board, recalculated before that placement's captures resolve.
5. **Given** **Reverse** is active, **When** an attacking card's facing stat is *lower* than the defending card's, **Then** the attacker captures (capture direction is fully inverted).
6. **Given** **Fallen Ace** is active and the attacker's facing stat is `1` against a defending `10`, **Then** the attacker captures regardless of the normal (or Reverse) comparison.
7. **Given** **All Open** (or **Three Open**) is active, **When** the match starts, **Then** the opponent's entire hand (or 3 random cards from it) is displayed face-up for the whole match, tracked by each card's stable identity so the correct cards stay revealed as the hand shrinks.
8. **Given** **Swap** is active, **When** the match starts, **Then** one random card from each side's hand trades hands before the first turn; the swapped card plays for its new holder, but reverts to its original owner for Card Bank unlock and post-win "steal" eligibility if not recaptured.
9. **Given** **Order** is active, **When** it is a side's turn, **Then** only the next card in that side's original deck order may legally be played. **Given** **Chaos** is active instead, **When** a side's turn begins, **Then** exactly one randomly re-rolled card from that hand is the only legal play, highlighted with a thick border in that side's ownership color; the opponent's mandated card is visible at least 2 seconds before the AI's move executes.
10. **Given** a match ends 5-5, **When** the draw is detected, **Then** a "Sudden Death!" banner displays, the board clears, and a new round starts immediately with each side's end-of-round cards, alternating who goes first, repeating until a side wins outright.
11. **Given** the player wins a match, **When** the post-game prompt appears, **Then** the player may drag any card the opponent played that round onto one of their own 5 active deck slots to swap it in, with a confirmation prompt before the swap completes.
12. **Given** the player attempts to save a deck containing two 5★ cards, **Then** the save is blocked with a validation message; **Given** a deck has one 5★ card and two 4★ cards, **Then** the save is blocked; **Given** a deck has zero 5★ cards and up to two 4★ cards, **Then** the save is allowed.
13. **Given** Ultra Hard difficulty with Reverse active, **When** the opponent's hand is dealt, **Then** all five cards are drawn from the 1★ tier (the tier with the lowest stat-sum band), keeping the match genuinely difficult under the inverted rule instead of handing out high-star cards that are secretly weak.

---

### Edge Cases

- **Corrupted Preferences**: If stored options or statistics are unreadable at launch, the app resets all to defaults (Felt Green, Vulpera card back, Standard scoring) without crashing.
- **Missing Custom Assets**: If a custom card back, face card art image, or background image file is absent from disk at load time, the affected slot falls back to the built-in default gracefully.
- **Victory Cascade Interruption**: If the player starts a new game, switches game modes, or closes the window while the cascade is running, all animation timers and render resources are released immediately.
- **Video Poker / Blackjack Out of Credits**: When session credits reach zero, a rebuy option is presented. If No Stress Mode is active, credits are purely cosmetic and the prompt never appears.
- **Custom Background File Too Large**: Image files over 25 MB are rejected with a user-friendly error at selection time.
- **Custom Background Deletion Conflict**: If a saved Theme references the background being deleted, the deletion is blocked until the referencing Theme is deleted first.
- **Autocomplete Interruption (Klondike/BeeCell)**: If the user triggers Undo during an autocomplete sequence, the autoplay halts and the game returns to the pre-autocomplete snapshot.
- **Window Resize During Autoplay**: If the window is resized while autocomplete is running, card layout and spacing recalculate correctly without disrupting the ongoing animation.
- **Honeycomb Own-Card Same/Plus**: A player's own adjacent cards count toward the Same/Plus capture trigger threshold, not just the opponent's — this is intentional (enables "combo bait" deck archetypes), not a bug.
- **Honeycomb Order/Chaos on an Empty Hand**: If the mandated-card rule (Order or Chaos) is active and a side's hand is empty, no card is treated as legally playable for that side.
- **Honeycomb Corrupted Saved Deck**: If a saved deck slot does not contain exactly 5 valid card IDs, the match falls back to a randomly-generated weak deck rather than failing to start.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Klondike Solitaire
- **FR-001**: The game MUST enforce standard Klondike rules: tableau builds in descending alternating colors; foundations build up in suit from Ace to King.
- **FR-002**: The game MUST support Draw One and Draw Three stock modes with the appropriate waste display for each.
- **FR-003**: Standard mode MUST apply a time penalty of −2 points per 10 elapsed seconds and a win bonus of 700,000 ÷ elapsed seconds, both applied as a single calculation at game completion.
- **FR-004**: Standard mode scoring: Waste→Tableau +5, Waste→Foundation +10, Tableau→Foundation +10, flip face-down card +5, Foundation→Tableau −15.
- **FR-005**: Undo in Standard mode MUST deduct the points earned by the undone move (clamped to zero for moves that already cost points).
- **FR-006**: Vegas mode MUST start at −$52.00 and award +$0.50 per card placed on a foundation.
- **FR-007**: Vegas Draw Three MUST allow at most one stock recycle per game; Vegas Draw One allows zero recycles.
- **FR-008**: Standard mode MUST allow unlimited stock recycles with no scoring penalty.
- **FR-009**: Autocomplete MUST become available when all tableau cards are face-up and stock and waste are both empty.
- **FR-010**: The hint engine MUST suggest a valid move when the player requests one; if no valid move exists, it MUST indicate the game is stuck.

#### BeeCell (Freecell)
- **FR-011**: BeeCell MUST support single-deck (52 cards, 4 free cells, 4 foundations, 8 columns) and double-deck (104 cards, 8 free cells, 8 foundations, 10 columns) modes.
- **FR-012**: Multi-card sequence moves MUST be validated by the formula: max movable = `(1 + emptyFreeCells) × 2^emptyTableauColumns` when moving to an occupied column, or `(1 + emptyFreeCells) × 2^(emptyTableauColumns − 1)` when moving to an empty column.
- **FR-013**: BeeCell Vegas starting score MUST be −$52.00 for single-deck and −$104.00 for double-deck, with +$0.50 per foundation card.

#### Spider Solitaire
- **FR-014**: Spider MUST support 1-suit (easy), 2-suit (medium), and 4-suit (hard) difficulty levels.
- **FR-015**: Any card may be placed on any tableau card of the next higher rank regardless of suit; only complete same-suit King-to-Ace runs are swept to foundations automatically.
- **FR-016**: The Deal action MUST deal one card per non-empty tableau column from the remaining stock.

#### Video Poker
- **FR-017**: Video Poker MUST support three variants: Jacks or Better (9/6 full-pay), Deuces Wild, and Bonus Poker, each with its defined pay table.
- **FR-018**: The player MUST be able to wager 1–5 credits per hand; wagering 5 credits MUST activate the Royal Flush bonus multiplier (800× for Jacks or Better and Bonus Poker).
- **FR-019**: Deuces Wild MUST treat all 2s as wild cards that substitute for any rank and suit when evaluating the best possible hand.
- **FR-020**: Session credits MUST reset to the default starting amount at each app launch and MUST NOT be persisted.
- **FR-021**: A rebuy option MUST be presented when credits reach zero (unless No Stress Mode is active).

#### Blackjack
- **FR-022**: Blackjack MUST implement: Hit, Stand, Double Down (on 2-card 9/10/11 hands only), Split (same-rank 2-card hands), and Insurance (when dealer shows an Ace).
- **FR-023**: A natural Blackjack MUST pay 3:1 (e.g., bet 10 → receive 30 in winnings), offering a more rewarding payout than standard casino rules.
- **FR-024**: The dealer MUST hit on soft 16 or below and stand on hard or soft 17 or above.
- **FR-025**: Session credits MUST reset to the default starting amount at each app launch and MUST NOT be persisted.

#### Shared Visual Systems
- **FR-026**: All game visual elements (card faces, suit symbols, card backs, empty pile indicators, felt texture) MUST be rendered programmatically using vector shapes and gradients — no raster images for gameplay components.
- **FR-027**: Built-in card back themes MUST include Vulpera, Moogle, and Dingwall; all themes MUST be fully programmatic (no external image files required).
- **FR-028**: Custom card backs MUST be importable from local PNG or JPG files, with an editor providing Scale, Horizontal Position, and Vertical Position controls whose preview updates in real time.
- **FR-029**: Custom face card art MUST be importable per suit-slot (Jack, Queen, King, Ace × 4 suits = 16 configurable slots).
- **FR-030**: Built-in felt colors MUST include Felt Green, Crimson, Royal Blue, Charcoal, and Desert; a custom color picker MUST also be available.
- **FR-031**: Custom background images (PNG/JPG, ≤ 25 MB) MUST be importable with an editor providing Scale, Horizontal Position, and Vertical Position controls.
- **FR-032**: Dark Mode card color scheme MUST be togglable (#1E1E1E card background, #FF4444 red suits, #C0C0C0 black suits).
- **FR-033**: Named Themes MUST allow saving and restoring any combination of felt color, card back, and background in a single selection.
- **FR-034**: All visual customization selections MUST apply instantly across all game modes simultaneously and MUST persist across app restarts.

#### Shared Systems
- **FR-035**: Game statistics MUST be tracked separately per game mode and per scoring variant (Standard vs. Vegas), including: games played, games won, win percentage, current streak, longest streak, and high score.
- **FR-036**: All preferences (draw mode, felt color, card back, sound, scoring mode) MUST be restored automatically at app launch.
- **FR-037**: Sound effects (shuffle, card snap, victory fanfare) MUST be packaged locally and played with low latency; all sounds MUST be silenceable via the sound toggle.
- **FR-038**: A card-bouncing victory cascade animation MUST trigger immediately upon game completion; cascade cards MUST bounce off window edges and be removed when they fully exit the viewport.
- **FR-039**: No Stress Mode MUST disable the timer, suppress all score/credit changes from time, and remove credit pressure in Blackjack and Video Poker.
- **FR-040**: The board layout and card sizing MUST scale dynamically and proportionally when the user resizes the macOS window, maintaining crisp vector rendering at all scales.
- **FR-041**: Zoom controls (0.6×–2.0×) MUST allow the player to adjust card display size independently of window size; the zoom level MUST persist.

#### Honeycomb
- **FR-042**: The game MUST be played on a 3×3 grid; placing a card adjacent to an opponent's card MUST compare the attacker's facing stat to the defender's opposite-facing stat, capturing the defender when the attacker's value is higher (or lower, if Reverse is active), including recursive chain-reaction combo captures.
- **FR-043**: Up to two rules MUST be selectable simultaneously from the pool {Ascension, Descension, Same, Plus, Fallen Ace, Reverse, All Open, Three Open, Swap, Order, Chaos}; Ascension/Descension MUST be mutually exclusive, and Order/Chaos MUST be mutually exclusive.
- **FR-044**: If no rules are manually selected, the match MUST default to Roulette mode, randomly selecting 0, 1, or 2 rules from the full pool (respecting the exclusivity pairs) at the start of every match.
- **FR-045**: Same MUST capture all touching neighbors whose facing stat equals the attacker's; Plus MUST capture all touching neighbor groups of 2+ where attacker-plus-neighbor sums match; both MUST only evaluate on the initiating placement, not on cascading combo captures.
- **FR-046**: Fallen Ace MUST let an attacking `1` capture a defending `10` (and, under Reverse, an attacking `10` capture a defending `1`), independent of the standard capture comparison.
- **FR-047**: All Open MUST reveal the opponent's entire hand face-up for the match; Three Open MUST reveal exactly 3 random cards from the opponent's hand, with revealed-card identity tracked by a stable ID so the correct cards stay visible as the hand shrinks.
- **FR-048**: Swap MUST exchange one random card between each side's hand before the first turn; a swapped card MUST play for its new holder but MUST revert to its original owner for Card Bank unlock eligibility and post-win steal eligibility.
- **FR-049**: Order MUST restrict the legal play each turn to the next card in that side's original deck order; Chaos MUST re-roll a single random legal card index for that side the instant its turn begins. The currently-mandated card MUST be highlighted with a thick border in the owning side's highlight color, and the opponent's AI MUST wait at least 2 seconds (with the mandated card visibly highlighted) before executing its move.
- **FR-050**: AI difficulty MUST scale by algorithm: Easy = uniform random move; Medium = greedy (maximizes this move's own capture count, ties broken randomly); Hard = minimax with alpha-beta pruning, 2-ply lookahead; Ultra Hard = minimax with alpha-beta pruning, 4-ply lookahead, both using a positional heuristic (corner cells weighted +3, edge cells +1, center +0).
- **FR-051**: Under normal rules, AI deck composition by difficulty MUST be: Easy = four 1★ + one 2★; Medium = four 2★ + one 3★; Hard = three 3★ + one 4★ + one 5★; Ultra Hard = two 3★ + one 4★ + two 5★, biased within each tier toward the cards best-suited to the active ruleset.
- **FR-052**: Under Reverse, each difficulty MUST use a dedicated Reverse-specific deck composition instead of its normal one, so that a nominally "hard" AI cannot be trivially defeated by exploiting the low-beats-high inversion: Easy borrows Ultra Hard's normal table; Medium borrows Hard's normal table; Hard uses an explicit two 1★ + three 2★ table; Ultra Hard uses five 1★ cards.
- **FR-053**: A drawn (5-5) match MUST trigger Sudden Death: display a "Sudden Death!" banner, clear the board, and immediately start a new round using each side's exact end-of-round cards, alternating the starting player, repeating until a side wins outright.
- **FR-054**: Deck-building MUST enforce: at most one 5★ card per deck; at most one 4★ card if a 5★ card is present in the deck, otherwise at most two 4★ cards; any combination of 1★-3★ cards otherwise. No Stress Mode MUST auto-assign a random deck each match (the player does not choose one), but that deal MUST still respect the same rarity caps — one 5★ + one 4★ + three 3★, the strongest composition the caps allow.
- **FR-055**: A fresh install MUST grant three randomly-selected 1★ cards and two randomly-selected 2★ cards to the Card Bank as starter unlocks.
- **FR-056**: A card MUST be permanently unlocked to the Card Bank only if it was in the player's active deck at the start of the match, was played onto the board during the match, was owned by the player (not merely its original owner, per Swap) at match end, and the player won the match.
- **FR-057**: After a won match, the player MUST be able to drag any card the opponent played that round onto one of their own 5 active deck slots to swap it in, subject to a confirmation prompt; the replaced card MUST return to the Card Bank/Saved Decks.
- **FR-058**: The player profile MUST support 5 named saved-deck slots; once a deck slot is given a name, that name MUST be permanently locked (though the cards within it may still be edited), with names capped at 20 characters.
- **FR-059**: The card database MUST contain 800 cards split evenly across 4 suits (200 each), with per-tier stat ceilings of 7/7/8/9/10 for 1★-5★ (a `10` value MUST be exclusive to 5★ cards) and per-tier total-stat-sum bands of 12-15/16-21/20-25/24-28/25-30.
- **FR-060**: Each suit MUST follow a distinct stat-generation archetype: Spades (pure offensive) concentrate the majority of a card's stat total on one opposite axis (Top/Bottom or Right/Left); Hearts (pure defensive) concentrate it on one adjacent corner pair instead; Diamonds (adaptive/all-rounder) keep all four sides within 1 point of each other; Clubs (tactical/combo bait) force 2-3 sides to share an identical low-to-mid value.
- **FR-061**: Statistics tracked for Honeycomb MUST include: games played/won/lost/tied, current and longest win streak, win percentage, total unique Card Bank unlocks (of 800) with a per-suit breakdown (of 200 each) and per-star-rating breakdown, flawless (10-0) victory count, lifetime cards flipped, and lifetime Same/Plus trigger count.

### Key Entities

- **Card**: rank (1–13), suit (spades/clubs/diamonds/hearts), faceUp state.
- **Pile**: group of cards with a type (Stock, Waste, Foundation, Tableau, FreeCell) and variant-specific placement rules.
- **GameState** (Klondike): stock, waste, foundations, tableau piles, score, moves count, elapsed seconds, draw mode, won state, recycle count.
- **BeecellState**: free cells, foundations, tableau piles, score, timer, free cell count, foundation count.
- **SpiderState**: tableau piles (10), stock batches, foundations, suit count, score, timer.
- **VideoPokerState**: current hand (5 cards), held indices, session credits, current bet, active variant, pay table, phase (deal/holding/result), last hand name, last payout.
- **BlackjackState**: player hand(s), dealer hand, session credits, current bet, active hand index, phase (betting/playing/dealerTurn/result).
- **GameOptions**: felt color, card back theme, dark mode cards, sound enabled, scoring mode, draw mode, no stress mode, custom felt color, custom background selection.
- **GameStatistics**: per-mode records of games played, games won, streaks, high scores.
- **CustomCardBack**: name, file path (relative to App Support), scale, offsetX, offsetY.
- **CustomFaceCardArt**: suit, face rank (J/Q/K/A), file path.
- **CustomBackground**: name, file path (relative to App Support), scale, offsetX, offsetY.
- **SoliBeeTheme**: name, felt color, card back theme identifier, background name (optional).
- **HoneycombCardData**: numeric id, placeholder name, star rating (1-5), 4 directional stats (Top/Right/Bottom/Left), suit (Spade/Heart/Diamond/Club).
- **HoneycombCard**: card data, current owner, original owner (differs from owner only under Swap), temporary Ascension/Descension modifier.
- **HoneycombBoard**: 3×3 array of cells (each optionally holding a card), capture/combo resolution state, per-match Same/Plus trigger flags and count.
- **HoneycombRule**: one of Ascension, Descension, Same, Plus, Fallen Ace, Reverse, All Open, Three Open, Swap, Order, Chaos.
- **HoneycombDeckState**: deck name (lockable once set), 5 card IDs.
- **HoneycombProfileManager**: set of unlocked Card Bank IDs, 5 saved deck slots.
- **HoneycombStats**: games played/won/lost/tied, streaks, flawless victories, lifetime cards flipped, lifetime Same/Plus triggers.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All five game modes enforce their complete rule sets without a single incorrect move acceptance or rejection during a randomized 1,000-hand/game test suite.
- **SC-002**: Card interactions (drag start, drop, double-click) respond in under 30ms from user input to visible state change.
- **SC-003**: The autocomplete solver completes a guaranteed-win Klondike position in under 5 seconds.
- **SC-004**: The hint engine returns a result in under 100ms.
- **SC-005**: Custom card back editor adjustments (scale, offset) refresh the preview in under 16ms (one frame at 60 FPS).
- **SC-006**: Board layout recalculates and re-renders correctly within one frame when the window is resized.
- **SC-007**: App preferences, statistics, and custom asset metadata are restored from storage in under 200ms at launch.
- **SC-008**: The victory cascade animation sustains 60 FPS with up to 52 bouncing cards simultaneously.
- **SC-009**: All automated unit tests pass in under 5 seconds via `make test`.
- **SC-010**: The Video Poker hand evaluator produces correct results for 100% of hands in a randomized 10,000-hand test suite for all three variants.
- **SC-011**: Honeycomb's Ultra Hard AI (4-ply minimax with alpha-beta pruning) selects a move in under 150ms in the worst case.
- **SC-012**: Honeycomb's capture, combo, Same/Plus, and all 11 match rules resolve correctly (matching hand-verified expected outcomes) across a randomized 1,000-match test suite.

---

## Assumptions

- **Target Platform**: macOS 14.0 or later; no iOS, iPadOS, or Windows versions are in scope for this spec (Windows work tracked separately).
- **Input Method**: Trackpad and mouse drag-and-drop; no touch input required.
- **Blackjack Payout**: Natural Blackjack intentionally pays 3:1 (rather than the standard casino 3:2) to provide a more rewarding player experience.
- **Video Poker Triple Play**: Triple Play mode is implemented in code but hidden from the UI pending final polish; it is out of scope for this spec's acceptance criteria.
- **Storage**: Custom assets (card backs, face art, backgrounds) are stored under `~/Library/Application Support/SoliBee/` and referenced by relative path in persisted preferences.
- **Rendering**: All gameplay visual components are programmatically rendered; raster images are only used for imported custom card backs, face art, and backgrounds.
- **Window Sizing**: The app supports any window size from 1024×768 and larger; minimum viable layout is maintained at all sizes.
- **Sound Files**: Shuffle, snap, and victory audio files are bundled locally in the application; no network audio is used.
- **Honeycomb Card Ownership Colors**: Player/opponent card highlight colors are user-configurable (defaulting to blue/red) via the Themes panel's Custom Card Color section, rather than the fixed yellow/black originally documented in the Honeycomb design brief.
- **Honeycomb Card Naming**: Card database entries currently use placeholder names (e.g. "Spade 1"); the card face does not render a name/rank label, showing only the suit icon, star rating, and NESW stats. Final thematic card names/art are out of scope for this spec.
- **Honeycomb Deck Reset**: There is no dedicated "reset active deck to a random 3×1★/2×2★ assortment" action; a corrupted/incomplete saved deck instead falls back to five random 1★ cards (see Edge Cases).
