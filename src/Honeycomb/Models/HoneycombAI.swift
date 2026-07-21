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
            return minimaxMove(board: board, opponentDeck: opponentDeck, playerDeck: playerDeck, eligibleHands: eligibleHands, empties: empties, rules: rules, lookaheadPlies: 2)
        case .ultraHard:
            return minimaxMove(board: board, opponentDeck: opponentDeck, playerDeck: playerDeck, eligibleHands: eligibleHands, empties: empties, rules: rules, lookaheadPlies: 6)
        }
    }

    static func emptyBoardIndices(board: HoneycombBoard) -> [Int] {
        board.cells.enumerated().filter { $0.element.card == nil }.map { $0.offset }
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
    static func minimaxMove(board: HoneycombBoard, opponentDeck: [HoneycombCardData], playerDeck: [HoneycombCardData], eligibleHands: [Int], empties: [Int], rules: [HoneycombRule], lookaheadPlies: Int) -> (handIndex: Int, boardIndex: Int)? {
        guard !empties.isEmpty, !eligibleHands.isEmpty else { return nil }

        var bestScore = Int.min
        var bestMoves: [(handIndex: Int, boardIndex: Int, immediateCaptures: Int)] = []
        var alpha = Int.min

        // Order/Chaos only constrain the *actual* move being chosen right now — the
        // lookahead below still searches the opponent's/player's full hands for
        // hypothetical future turns, since under Chaos that turn's mandated card isn't
        // even decided yet (re-rolled fresh each turn), and modeling Order's exact
        // future constraint multiple plies out isn't worth the complexity it'd add.
        for h in eligibleHands {
            let cardData = opponentDeck[h]
            for b in empties {
                var simBoard = board
                let card = HoneycombCard(data: cardData, owner: .opponent)
                let immediateCaptures = simBoard.placeCard(card, at: b, rules: rules).count

                var remainingOpponentDeck = opponentDeck
                remainingOpponentDeck.remove(at: h)

                let score = minimaxScore(
                    board: simBoard,
                    opponentDeck: remainingOpponentDeck,
                    playerDeck: playerDeck,
                    maximizingOpponent: false,
                    depth: lookaheadPlies - 1,
                    alpha: alpha,
                    beta: Int.max,
                    rules: rules
                )

                if score > bestScore {
                    bestScore = score
                    bestMoves = [(h, b, immediateCaptures)]
                    alpha = max(alpha, bestScore)
                } else if score == bestScore {
                    bestMoves.append((h, b, immediateCaptures))
                }
            }
        }
        let maxCaptures = bestMoves.map(\.immediateCaptures).max() ?? 0
        let mostAggressive = bestMoves.filter { $0.immediateCaptures == maxCaptures }
        return mostAggressive.randomElement().map { ($0.handIndex, $0.boardIndex) }
    }

    // Alpha-beta minimax over simulated placements. `maximizingOpponent` alternates each
    // ply: true when it's the AI's simulated turn (maximize the positional heuristic in
    // its favor), false when it's the player's simulated turn (minimize it, i.e. assume
    // the player plays their best response). Bottoms out at `depth == 0`, an empty
    // board, or either side running out of cards to place, at which point the current
    // board is scored directly by `positionalEvaluation`.
    static func minimaxScore(
        board: HoneycombBoard,
        opponentDeck: [HoneycombCardData],
        playerDeck: [HoneycombCardData],
        maximizingOpponent: Bool,
        depth: Int,
        alpha: Int,
        beta: Int,
        rules: [HoneycombRule]
    ) -> Int {
        let empties = board.cells.enumerated().filter { $0.element.card == nil }.map { $0.offset }
        let activeDeck = maximizingOpponent ? opponentDeck : playerDeck
        guard depth > 0, !empties.isEmpty, !activeDeck.isEmpty else {
            return positionalEvaluation(board: board)
        }

        var alpha = alpha
        var beta = beta

        if maximizingOpponent {
            var best = Int.min
            outer: for h in 0..<activeDeck.count {
                let cardData = activeDeck[h]
                for b in empties {
                    var simBoard = board
                    _ = simBoard.placeCard(HoneycombCard(data: cardData, owner: .opponent), at: b, rules: rules)
                    var remaining = opponentDeck
                    remaining.remove(at: h)
                    let score = minimaxScore(board: simBoard, opponentDeck: remaining, playerDeck: playerDeck,
                                              maximizingOpponent: false, depth: depth - 1, alpha: alpha, beta: beta, rules: rules)
                    best = max(best, score)
                    alpha = max(alpha, best)
                    if beta <= alpha { break outer }
                }
            }
            return best
        } else {
            var best = Int.max
            outer: for h in 0..<activeDeck.count {
                let cardData = activeDeck[h]
                for b in empties {
                    var simBoard = board
                    _ = simBoard.placeCard(HoneycombCard(data: cardData, owner: .player), at: b, rules: rules)
                    var remaining = playerDeck
                    remaining.remove(at: h)
                    let score = minimaxScore(board: simBoard, opponentDeck: opponentDeck, playerDeck: remaining,
                                              maximizingOpponent: true, depth: depth - 1, alpha: alpha, beta: beta, rules: rules)
                    best = min(best, score)
                    beta = min(beta, best)
                    if beta <= alpha { break outer }
                }
            }
            return best
        }
    }

    // Positional heuristic (Hard/Ultra Hard's "positional evaluation"): each occupied
    // cell is worth 10 points plus a safety bonus based on how exposed it is — corners
    // (0, 2, 6, 8) only ever have 2 neighbors and are hardest to recapture, edges
    // (1, 3, 5, 7) have 3, and the center (4) has all 4 and is the most vulnerable.
    // Positive from the AI's (opponent's) perspective.
    static func positionalWeight(_ index: Int) -> Int {
        switch index {
        case 0, 2, 6, 8: return 3
        case 1, 3, 5, 7: return 1
        default: return 0
        }
    }

    static func positionalEvaluation(board: HoneycombBoard) -> Int {
        var score = 0
        for (idx, cell) in board.cells.enumerated() {
            guard let card = cell.card else { continue }
            let weight = 10 + positionalWeight(idx)
            score += card.owner == .opponent ? weight : -weight
        }
        return score
    }
}
