import Foundation

// Everything here is `static` and takes its board/hand/rules state as plain value-type
// parameters (no reference to a ViewModel) so it's safe to run on a background queue —
// HoneycombViewModel.aiPlayTurn() snapshots the current state and dispatches
// HoneycombAI.computeMove(...) off the main thread for Hard/Ultra Hard's minimax search.
enum HoneycombAI {
    static func computeMove(
        difficulty: HoneycombDifficulty,
        board: HoneycombBoard,
        opponentDeck: [HoneycombCardData],
        playerDeck: [HoneycombCardData],
        unknownPlayerCardCount: Int = 0,
        eligibleHands: [Int],
        empties: [Int],
        rules: [HoneycombRule]
    ) -> (handIndex: Int, boardIndex: Int)? {
        switch difficulty {
        case .easy:
            return randomMove(eligibleHands: eligibleHands, empties: empties)
        case .medium:
            return greedyMove(board: board, opponentDeck: opponentDeck, eligibleHands: eligibleHands, empties: empties, rules: rules)
        case .hard:
            return minimaxMove(board: board, opponentDeck: opponentDeck, playerDeck: playerDeck, unknownPlayerCardCount: unknownPlayerCardCount, eligibleHands: eligibleHands, empties: empties, rules: rules, lookaheadPlies: 2, weighFallenAce: false)
        case .ultraHard:
            return minimaxMove(board: board, opponentDeck: opponentDeck, playerDeck: playerDeck, unknownPlayerCardCount: unknownPlayerCardCount, eligibleHands: eligibleHands, empties: empties, rules: rules, lookaheadPlies: 6, weighFallenAce: true)
        }
    }

    static func emptyBoardIndices(board: HoneycombBoard) -> [Int] {
        board.cells.enumerated().filter { $0.element.card == nil }.map { $0.offset }
    }

    // Mirrors a board's cell ownership tags (.player <-> .opponent). minimaxMove/
    // minimaxScore/positionalEvaluation are all written from a fixed "opponent
    // maximizes, player minimizes" perspective (see positionalEvaluation's
    // `card.owner == .opponent ? cardScore : -cardScore`), since that's the only
    // perspective the real AI opponent ever needs. Mirroring the board's owners before
    // handing it to computeHint below reuses that exact same machinery unmodified to
    // find the human PLAYER's best move instead: after mirroring, the player's own
    // cards read as .opponent (the maximizing side) and the real opponent's cards read
    // as .player (the minimizing side), so the search now optimizes for the player.
    // originalOwner is left untouched — nothing in the search reads it.
    private static func mirroredOwnership(_ board: HoneycombBoard) -> HoneycombBoard {
        var mirrored = board
        for i in mirrored.cells.indices {
            guard var card = mirrored.cells[i].card else { continue }
            card.owner = card.owner == .player ? .opponent : .player
            mirrored.cells[i].card = card
        }
        return mirrored
    }

    // Hint system: always searches at Ultra Hard's caliber (deepest lookahead, Fallen
    // Ace weighed) regardless of the match's own difficulty, since a hint is meant to
    // be the mathematically best move, not merely as good as whatever difficulty was
    // picked. `unknownOpponentCardCount` mirrors aiPlayTurn's own fairness guard for
    // the AI (unknownPlayerCardCount): only opponent cards actually revealed to the
    // player (openOpponentCardIds) may be passed in `opponentDeck`, so the hint can't
    // use information the player hasn't actually been shown.
    static func computeHint(
        board: HoneycombBoard,
        playerDeck: [HoneycombCardData],
        opponentDeck: [HoneycombCardData],
        unknownOpponentCardCount: Int,
        eligibleHands: [Int],
        empties: [Int],
        rules: [HoneycombRule]
    ) -> (handIndex: Int, boardIndex: Int)? {
        minimaxMove(
            board: mirroredOwnership(board),
            opponentDeck: playerDeck,
            playerDeck: opponentDeck,
            unknownPlayerCardCount: unknownOpponentCardCount,
            eligibleHands: eligibleHands,
            empties: empties,
            rules: rules,
            lookaheadPlies: 6,
            weighFallenAce: true
        )
    }

    // Easy: naive random play — no evaluation at all, matches spec's "Naive random play."
    // Still respects Order/Chaos: if either is active there's only one legal card, so
    // "random" only has the empty board cells left to pick from.
    static func randomMove(eligibleHands: [Int], empties: [Int]) -> (handIndex: Int, boardIndex: Int)? {
        guard !empties.isEmpty, !eligibleHands.isEmpty else { return nil }
        return (eligibleHands.randomElement()!, empties.randomElement()!)
    }

    // Medium: greedy 1-step lookahead — maximize this move's own capture count only,
    // no consideration of what the player might do in response. Ties are broken
    // randomly among equally-good moves (previously always kept the first-found move,
    // making the AI deterministically predictable/exploitable in tied situations).
    static func greedyMove(board: HoneycombBoard, opponentDeck: [HoneycombCardData], eligibleHands: [Int], empties: [Int], rules: [HoneycombRule]) -> (handIndex: Int, boardIndex: Int)? {
        guard !empties.isEmpty, !eligibleHands.isEmpty else { return nil }

        var bestScore = -1
        var bestMoves: [(handIndex: Int, boardIndex: Int)] = []
        for h in eligibleHands {
            let cardData = opponentDeck[h]
            for b in empties {
                var simBoard = board
                let score = simBoard.placeCard(HoneycombCard(data: cardData, owner: .opponent), at: b, rules: rules).count
                if score > bestScore {
                    bestScore = score
                    bestMoves = [(h, b)]
                } else if score == bestScore {
                    bestMoves.append((h, b))
                }
            }
        }
        return bestMoves.randomElement()
    }

    // Hard/Ultra Hard: minimax with alpha-beta pruning, looking `lookaheadPlies` moves
    // ahead (Hard: 2 — this move + the player's best reply. Ultra Hard: 6 — three full
    // exchanges), scored by a positional heuristic rather than just this move's own
    // capture count. Ties at the top-level minimax score are broken by preferring the
    // move that captures the most cards *immediately* (more aggressive — previously
    // random, which could pick a totally passive placement over an equally-scored one
    // that actually flips cards this turn) — genuine remaining ties are broken randomly.
    static func minimaxMove(board: HoneycombBoard, opponentDeck: [HoneycombCardData], playerDeck: [HoneycombCardData], unknownPlayerCardCount: Int = 0, eligibleHands: [Int], empties: [Int], rules: [HoneycombRule], lookaheadPlies: Int, weighFallenAce: Bool) -> (handIndex: Int, boardIndex: Int)? {
        guard !empties.isEmpty, !eligibleHands.isEmpty else { return nil }

        var bestScore = Int.min
        var bestMoves: [(handIndex: Int, boardIndex: Int, immediateCaptures: Int)] = []
        var alpha = Int.min

        // Order/Chaos only constrain the *actual* move being chosen right now — the
        // lookahead below still searches the opponent's/player's full hands for
        // hypothetical future turns, since under Chaos that turn's mandated card isn't
        // even decided yet (re-rolled fresh each turn), and modeling Order's exact
        // future constraint multiple plies out isn't worth the complexity it'd add.
        //
        // Candidates are pre-sorted by immediate capture count (orderedCandidates) so
        // the strongest-looking moves are explored first — this doesn't change which
        // move is ultimately chosen (every eligible move is still evaluated), it just
        // lets `alpha` tighten sooner, giving the recursive minimaxScore calls beneath
        // later candidates more pruning to work with.
        let candidates = orderedCandidates(deck: opponentDeck, handIndices: eligibleHands, empties: empties, board: board, owner: .opponent, rules: rules)
        for candidate in candidates {
            var remainingOpponentDeck = opponentDeck
            remainingOpponentDeck.remove(at: candidate.h)

            let score = minimaxScore(
                board: candidate.board,
                opponentDeck: remainingOpponentDeck,
                playerDeck: playerDeck,
                unknownPlayerCardCount: unknownPlayerCardCount,
                maximizingOpponent: false,
                depth: lookaheadPlies - 1,
                alpha: alpha,
                beta: Int.max,
                rules: rules,
                weighFallenAce: weighFallenAce
            )

            if score > bestScore {
                bestScore = score
                bestMoves = [(candidate.h, candidate.b, candidate.captures)]
                alpha = max(alpha, bestScore)
            } else if score == bestScore {
                bestMoves.append((candidate.h, candidate.b, candidate.captures))
            }
        }
        let maxCaptures = bestMoves.map(\.immediateCaptures).max() ?? 0
        let mostAggressive = bestMoves.filter { $0.immediateCaptures == maxCaptures }
        return mostAggressive.randomElement().map { ($0.handIndex, $0.boardIndex) }
    }

    // Pre-simulates every (hand-index, board-index) candidate for `owner` and sorts by
    // immediate capture count, descending — a cheap move-ordering proxy (each placement
    // is one real `board.placeCard` call, O(4) neighbor checks, not another recursive
    // search) that lets alpha-beta cutoffs in minimaxScore/minimaxMove fire earlier
    // without changing the final minimax value, only the cost of finding it. Returns
    // the resulting board alongside each candidate so callers don't need to redo the
    // same `placeCard` simulation a second time.
    static func orderedCandidates(
        deck: [HoneycombCardData], handIndices: [Int], empties: [Int], board: HoneycombBoard, owner: CardOwner, rules: [HoneycombRule]
    ) -> [(h: Int, b: Int, captures: Int, board: HoneycombBoard)] {
        var candidates: [(h: Int, b: Int, captures: Int, board: HoneycombBoard)] = []
        candidates.reserveCapacity(handIndices.count * empties.count)
        for h in handIndices {
            let cardData = deck[h]
            for b in empties {
                var simBoard = board
                let captures = simBoard.placeCard(HoneycombCard(data: cardData, owner: owner), at: b, rules: rules).count
                candidates.append((h, b, captures, simBoard))
            }
        }
        return candidates.sorted { $0.captures > $1.captures }
    }

    // Alpha-beta minimax over simulated placements. `maximizingOpponent` alternates each
    // ply: true when it's the AI's simulated turn (maximize the positional heuristic in
    // its favor), false when it's the player's simulated turn (minimize it, i.e. assume
    // the player plays their best response). Bottoms out at `depth == 0`, an empty
    // board, or either side running out of cards to place, at which point the current
    // board is scored directly by `positionalEvaluation`.
    // Dominates any possible `positionalEvaluation` score (whose per-cell range is
    // roughly ±15, so ±135 across a full 9-cell board) without approaching
    // Int.max/Int.min, which participate directly in alpha/beta comparisons and would
    // risk overflow/trapping if any future change did arithmetic on them (e.g. scaling
    // by margin). A genuinely won/lost board must always outrank a merely
    // heuristically-favorable one.
    private static let terminalScoreUnit = 1000

    static func minimaxScore(
        board: HoneycombBoard,
        opponentDeck: [HoneycombCardData],
        playerDeck: [HoneycombCardData],
        unknownPlayerCardCount: Int = 0,
        maximizingOpponent: Bool,
        depth: Int,
        alpha: Int,
        beta: Int,
        rules: [HoneycombRule],
        weighFallenAce: Bool
    ) -> Int {
        // The match is genuinely decided — score by final ownership margin rather than
        // the heuristic, so a won line always outranks a line that merely "looks good"
        // mid-game. Checked ahead of the depth/hand-exhaustion guard below since a full
        // board can be reached exactly as depth hits 0 or a deck empties.
        if board.isFull {
            let margin = board.opponentScore - board.playerScore
            return margin * Self.terminalScoreUnit
        }

        let empties = board.cells.enumerated().filter { $0.element.card == nil }.map { $0.offset }
        let activeDeck = maximizingOpponent ? opponentDeck : playerDeck

        // The AI doesn't get to see the player's whole hand unless it's actually been
        // revealed (All Open/Three Open now apply symmetrically — see
        // HoneycombViewModel.aiPlayTurn). If cards remain that we have no data for, we
        // can't fabricate a concrete placement for them, so rather than continuing to
        // search the player's ply as if their whole hand were the (incomplete) known
        // `playerDeck`, this ply is treated as a leaf and scored by the heuristic —
        // reduced lookahead in exchange for not "cheating."
        if !maximizingOpponent && unknownPlayerCardCount > 0 {
            return positionalEvaluation(board: board, rules: rules, weighFallenAce: weighFallenAce)
        }

        guard depth > 0, !empties.isEmpty, !activeDeck.isEmpty else {
            return positionalEvaluation(board: board, rules: rules, weighFallenAce: weighFallenAce)
        }

        var alpha = alpha
        var beta = beta

        // Candidates are pre-sorted by immediate capture count (orderedCandidates) so
        // alpha-beta cutoffs below fire earlier — this changes search cost, not the
        // minimax value returned, since every candidate is still fully evaluated unless
        // a cutoff genuinely applies.
        let owner: CardOwner = maximizingOpponent ? .opponent : .player
        let candidates = orderedCandidates(deck: activeDeck, handIndices: Array(0..<activeDeck.count), empties: empties, board: board, owner: owner, rules: rules)

        if maximizingOpponent {
            var best = Int.min
            outer: for candidate in candidates {
                var remaining = opponentDeck
                remaining.remove(at: candidate.h)
                let score = minimaxScore(board: candidate.board, opponentDeck: remaining, playerDeck: playerDeck, unknownPlayerCardCount: unknownPlayerCardCount,
                                          maximizingOpponent: false, depth: depth - 1, alpha: alpha, beta: beta, rules: rules, weighFallenAce: weighFallenAce)
                best = max(best, score)
                alpha = max(alpha, best)
                if beta <= alpha { break outer }
            }
            return best
        } else {
            var best = Int.max
            outer: for candidate in candidates {
                var remaining = playerDeck
                remaining.remove(at: candidate.h)
                let score = minimaxScore(board: candidate.board, opponentDeck: opponentDeck, playerDeck: remaining, unknownPlayerCardCount: unknownPlayerCardCount,
                                          maximizingOpponent: true, depth: depth - 1, alpha: alpha, beta: beta, rules: rules, weighFallenAce: weighFallenAce)
                best = min(best, score)
                beta = min(beta, best)
                if beta <= alpha { break outer }
            }
            return best
        }
    }

    // Maps a board index + direction (0=Top, 1=Right, 2=Bottom, 3=Left) to the
    // neighboring index, or nil if that direction runs off the board — same neighbor
    // geometry HoneycombBoard.resolveCaptures uses to find capture targets.
    static func neighborIndex(from index: Int, direction: Int) -> Int? {
        let row = index / 3
        let col = index % 3
        switch direction {
        case 0: return row > 0 ? index - 3 : nil
        case 1: return col < 2 ? index + 1 : nil
        case 2: return row < 2 ? index + 3 : nil
        case 3: return col > 0 ? index - 1 : nil
        default: return nil
        }
    }

    // How safe a single exposed stat is, centered on 0 (a mid-value ~5/6 stat is
    // roughly neutral; low is negative/risky, high is positive/safe) — under Reverse
    // capture direction flips (low beats high, per HoneycombBoard's own `canCapture`),
    // so a high stat becomes the liability instead of a low one. When Fallen Ace is
    // active *and* being weighed (Ultra Hard only — see positionalEvaluation), the
    // stat that would otherwise look safest (10 normally, or 1 under Reverse) is
    // docked a flat penalty: it's still exploitable by the one specific attacking
    // value Fallen Ace lets topple it (an Ace, or a 10 under Reverse), so it's not the
    // clean, unbeatable value the base formula assumes. The penalty is smaller than
    // the max possible safety bonus (5) since only that one specific attacking value
    // threatens it, not any higher/lower stat the way the base exposure risk works.
    static func exposureValue(stat: Int, reverse: Bool, fallenAce: Bool) -> Int {
        let effectiveStrength = reverse ? (11 - stat) : stat
        var value = effectiveStrength - 5
        let fallenAceVulnerableStat = reverse ? 1 : 10
        if fallenAce && stat == fallenAceVulnerableStat {
            value -= 3
        }
        return value
    }

    // Positional heuristic (Hard/Ultra Hard's "positional evaluation"): each occupied
    // cell is worth a flat ownership value, adjusted by how *actually* exposed it is —
    // not just whether it sits in a corner, but the real stat (Ascension/Descension
    // modifier included, via `card.stat(at:)`, which already folds the modifier in)
    // it presents toward every currently-empty neighboring cell, since that's the only
    // direction a future card could attack from. A corner is only safe if what it's
    // showing into the board is genuinely strong; a `1` facing an empty center square
    // is a liability wherever it sits. Occupied neighbors contribute no further risk —
    // that fight already happened. Positive from the AI's (opponent's) perspective.
    //
    // `weighFallenAce` is only true for Ultra Hard (see computeMove) — Hard's shallower
    // 2-ply search is meant to stay a notch simpler/more exploitable than Ultra Hard's,
    // so this specific extra layer of caution is reserved for the top difficulty.
    static func positionalEvaluation(board: HoneycombBoard, rules: [HoneycombRule], weighFallenAce: Bool) -> Int {
        let reverse = rules.contains(.reverse)
        let fallenAce = weighFallenAce && rules.contains(.fallenAce)
        var score = 0
        for (idx, cell) in board.cells.enumerated() {
            guard let card = cell.card else { continue }
            var cardScore = 10
            for direction in 0..<4 {
                guard let neighbor = neighborIndex(from: idx, direction: direction),
                      board.cells[neighbor].card == nil else { continue }
                cardScore += exposureValue(stat: card.stat(at: direction), reverse: reverse, fallenAce: fallenAce)
            }
            score += card.owner == .opponent ? cardScore : -cardScore
        }
        score += comboPotential(board: board, rules: rules)
        return score
    }

    // Estimates Same/Plus chain-capture *potential* sitting on the board right now:
    // for every empty cell, look at its occupied neighbors. If 2+ of them are owned by
    // the same side, that empty cell is a launch point for a future combo against them
    // — a much bigger swing than generic per-cell exposure captures on its own.
    //
    // Same requires the two facing stats to already be equal, so it's checked exactly.
    // Plus is NOT "the two stats sum to 10" — HoneycombBoard.resolveCaptures triggers
    // it whenever two neighbors' (attacker-stat + facing-stat) sums match each other,
    // and the attacker's stat facing each neighbor comes from a *different* side of the
    // same card (Top/Right/Bottom/Left can be anything 1-10 independently). So for any
    // two facing stats E1/E2, some attacker stats s1/s2 in 1...10 with s1+E1 == s2+E2
    // almost always exist (s2 = s1 + (E1-E2), and |E1-E2| can be at most 9, i.e. always
    // fits within 1...10 for some s1) — in practice any 2+ same-owner neighbors around
    // an empty cell are a live Plus threat, not just ones that happen to sum to 10.
    // Weighted lower than Same (which is a confirmed match, not just "some card could
    // do this") since Plus additionally needs the AI/player to actually be holding a
    // card with the right two stats on the right two sides.
    //
    // Deliberately coarse otherwise: doesn't check whether the AI/player's actual
    // remaining hand contains a fitting card at all (that would mean threading hand
    // contents into positionalEvaluation), consistent with exposureValue's own
    // coarseness (raw stat exposure, no hand awareness either). Zero-cost when neither
    // rule is active, matching the existing weighFallenAce/fallenAce gating pattern.
    static func comboPotential(board: HoneycombBoard, rules: [HoneycombRule]) -> Int {
        guard rules.contains(.same) || rules.contains(.plus) else { return 0 }
        var score = 0
        let empties = board.cells.enumerated().filter { $0.element.card == nil }.map { $0.offset }
        for emptyIdx in empties {
            var facingStats: [(owner: CardOwner, stat: Int)] = []
            for direction in 0..<4 {
                guard let neighbor = neighborIndex(from: emptyIdx, direction: direction),
                      let card = board.cells[neighbor].card else { continue }
                let towardEmptyDirection = (direction + 2) % 4
                facingStats.append((card.owner, card.stat(at: towardEmptyDirection)))
            }
            for owner: CardOwner in [.player, .opponent] {
                let theirs = facingStats.filter { $0.owner == owner }.map(\.stat)
                guard theirs.count >= 2 else { continue }
                var sameMatches = 0
                var plusMatches = 0
                for i in 0..<theirs.count {
                    for j in (i + 1)..<theirs.count {
                        if rules.contains(.same) && theirs[i] == theirs[j] { sameMatches += 1 }
                        if rules.contains(.plus) { plusMatches += 1 }
                    }
                }
                guard sameMatches > 0 || plusMatches > 0 else { continue }
                // Positive when it's the PLAYER's cards exposed to a future combo (the
                // AI could exploit this), negative when it's the AI's own cards exposed
                // the same way. Weights are smaller than a real capture (~10-15 in
                // cardScore terms) since this is only potential — tunable after
                // playtesting.
                let weight = 6 * sameMatches + 3 * plusMatches
                score += owner == .player ? weight : -weight
            }
        }
        return score
    }
}
