import Foundation

public enum AIDifficulty: String, Codable, CaseIterable, Equatable {
    case easy
    case medium
    case hard

    public var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }
}

public enum PokerAction: Equatable {
    case fold
    case check
    case call
    case raise(Int)
    case discard([Int])   // indices into hand array to replace
}

public struct PokerAI {

    // MARK: - Betting action decision

    public static func decideAction(
        hand: [Card],
        communityCards: [Card],
        pot: Int,
        callAmount: Int,
        difficulty: AIDifficulty
    ) -> PokerAction {
        let result: PokerHandResult
        if hand.count == 5 && communityCards.isEmpty {
            // 5-Card Draw: evaluate full hand directly
            result = PokerHandEvaluator.evaluate(hand)
        } else {
            // Hold'em: variable community count (0=pre-flop, 3=flop, 4=turn, 5=river)
            result = PokerHandEvaluator.bestHand(hole: Array(hand.prefix(2)), community: communityCards)
        }

        let handStrength = result.rank.rawValue  // 0–9
        let bluffRoll    = Double.random(in: 0..<1)
        let bluffRate    = bluffRate(for: difficulty)
        let isBluffing   = bluffRoll < bluffRate

        switch difficulty {
        case .easy:
            // Fold anything below one pair unless bluffing
            if handStrength < PokerHandRank.onePair.rawValue && !isBluffing {
                return callAmount > 0 ? .fold : .check
            }
            if callAmount == 0 { return .check }
            return .call

        case .medium:
            // Pot odds check: call if hand strength justifies it
            let potOdds = pot > 0 ? Double(callAmount) / Double(pot + callAmount) : 0
            let threshold = 0.35 - Double(handStrength) * 0.03
            if handStrength < PokerHandRank.onePair.rawValue && !isBluffing && potOdds > threshold {
                return callAmount > 0 ? .fold : .check
            }
            if handStrength >= PokerHandRank.twoPair.rawValue && !isBluffing {
                let raiseAmt = max(callAmount * 2, pot / 2)
                return .raise(raiseAmt)
            }
            if callAmount == 0 { return .check }
            return .call

        case .hard:
            // Full pot-odds + draw estimation heuristic
            let equity = estimatedEquity(handStrength: handStrength, community: communityCards)
            let potOdds = pot > 0 ? Double(callAmount) / Double(pot + callAmount) : 0
            if !isBluffing && equity < potOdds {
                return callAmount > 0 ? .fold : .check
            }
            if equity > 0.65 || isBluffing {
                let raiseAmt = max(callAmount * 2, pot / 3)
                return .raise(raiseAmt)
            }
            if callAmount == 0 { return .check }
            return .call
        }
    }

    // MARK: - Discard decision (5-Card Draw only)

    public static func decideDiscards(hand: [Card], difficulty: AIDifficulty) -> [Int] {
        precondition(hand.count == 5)

        var freq: [Int: [Int]] = [:]  // rank → indices
        for (i, card) in hand.enumerated() {
            freq[card.rank, default: []].append(i)
        }

        // Find best group to keep
        let sorted = freq.values.sorted { $0.count > $1.count || ($0.count == $1.count && $0[0] > $1[0]) }
        let keepGroup = sorted.first ?? []
        let keepSet   = Set(keepGroup)

        // Check flush draw
        var suitBuckets: [Card.Suit: [Int]] = [:]
        for (i, card) in hand.enumerated() {
            suitBuckets[card.suit, default: []].append(i)
        }
        let bestFlushDraw = suitBuckets.values.max(by: { $0.count < $1.count }) ?? []

        // Check straight draw
        let ranks = hand.map { $0.rank }.sorted()
        let uniqueRanks = Array(Set(ranks).sorted())
        var longestRun = 1, curRun = 1
        var bestRunEnd = uniqueRanks.first ?? 0
        for i in 1..<uniqueRanks.count {
            if uniqueRanks[i] == uniqueRanks[i-1] + 1 {
                curRun += 1
                if curRun > longestRun {
                    longestRun = curRun
                    bestRunEnd = uniqueRanks[i]
                }
            } else {
                curRun = 1
            }
        }

        // Decide what to keep based on difficulty
        let keepIndices: Set<Int>
        switch difficulty {
        case .easy:
            // Keep pairs+, discard everything else freely
            keepIndices = keepSet
        case .medium:
            // Prefer flush draw (4+) or straight draw (4+) over single high cards
            if bestFlushDraw.count >= 4 && bestFlushDraw.count > keepGroup.count {
                keepIndices = Set(bestFlushDraw)
            } else if longestRun >= 4 {
                let runRanks = Set((bestRunEnd - longestRun + 1)...bestRunEnd)
                keepIndices = Set(hand.enumerated().filter { runRanks.contains($0.element.rank) }.map { $0.offset })
            } else {
                keepIndices = keepSet
            }
        case .hard:
            // Flush draw > straight draw > pair group
            if bestFlushDraw.count >= 4 {
                keepIndices = Set(bestFlushDraw)
            } else if longestRun >= 4 {
                let runRanks = Set((bestRunEnd - longestRun + 1)...bestRunEnd)
                keepIndices = Set(hand.enumerated().filter { runRanks.contains($0.element.rank) }.map { $0.offset })
            } else {
                keepIndices = keepSet
            }
        }

        return (0..<5).filter { !keepIndices.contains($0) }
    }

    // MARK: - Helpers

    private static func bluffRate(for difficulty: AIDifficulty) -> Double {
        switch difficulty {
        case .easy:   return 0.03
        case .medium: return 0.08
        case .hard:   return 0.18
        }
    }

    private static func estimatedEquity(handStrength: Int, community: [Card]) -> Double {
        let base = Double(handStrength) / 9.0
        // Slightly discount if still on early streets (more cards to come = more variance)
        let streetFactor = community.isEmpty ? 0.8 : (community.count < 4 ? 0.9 : 1.0)
        return min(1.0, base * streetFactor + 0.05)
    }
}
