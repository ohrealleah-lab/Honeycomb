import Foundation

public struct PokerHandEvaluator {

    public static func evaluate(_ five: [Card]) -> PokerHandResult {
        precondition(five.count == 5, "evaluate requires exactly 5 cards")
        let ranks = five.map { $0.rank }.sorted(by: >)
        let suits = five.map { $0.suit }
        let isFlush = Set(suits).count == 1

        // Normalise ace-low straight (A-2-3-4-5 → ranks [5,4,3,2,1])
        let isStraight: Bool
        let straightHighCard: Int
        if ranks == [14, 5, 4, 3, 2] || ranks == [5, 4, 3, 2, 1] {
            // Wheel
            isStraight = true
            straightHighCard = 5
        } else {
            isStraight = ranks[0] - ranks[4] == 4 && Set(ranks).count == 5
            straightHighCard = ranks[0]
        }

        // Build rank-frequency map
        var freq: [Int: Int] = [:]
        for r in ranks { freq[r, default: 0] += 1 }
        let groups = freq.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key > b.key
        }
        let groupCounts = groups.map { $0.value }

        // Royal / Straight Flush
        if isFlush && isStraight {
            if straightHighCard == 14 || (ranks.contains(1) && ranks.contains(13)) {
                return PokerHandResult(rank: .royalFlush, kickers: [straightHighCard])
            }
            return PokerHandResult(rank: .straightFlush, kickers: [straightHighCard])
        }

        // Four of a Kind
        if groupCounts == [4, 1] {
            let quad = groups[0].key
            let kick = groups[1].key
            return PokerHandResult(rank: .fourOfAKind, kickers: [quad, kick])
        }

        // Full House
        if groupCounts == [3, 2] {
            return PokerHandResult(rank: .fullHouse, kickers: [groups[0].key, groups[1].key])
        }

        // Flush
        if isFlush {
            return PokerHandResult(rank: .flush, kickers: ranks)
        }

        // Straight
        if isStraight {
            return PokerHandResult(rank: .straight, kickers: [straightHighCard])
        }

        // Three of a Kind
        if groupCounts == [3, 1, 1] {
            let trio = groups[0].key
            let kicks = [groups[1].key, groups[2].key].sorted(by: >)
            return PokerHandResult(rank: .threeOfAKind, kickers: [trio] + kicks)
        }

        // Two Pair
        if groupCounts == [2, 2, 1] {
            let high = groups[0].key
            let low  = groups[1].key
            let kick = groups[2].key
            return PokerHandResult(rank: .twoPair, kickers: [high, low, kick])
        }

        // One Pair
        if groupCounts == [2, 1, 1, 1] {
            let pair  = groups[0].key
            let kicks = [groups[1].key, groups[2].key, groups[3].key].sorted(by: >)
            return PokerHandResult(rank: .onePair, kickers: [pair] + kicks)
        }

        // High Card
        return PokerHandResult(rank: .highCard, kickers: ranks)
    }

    // Best 5-of-7: try all C(7,5)=21 combinations
    public static func bestFiveOfSeven(hole: [Card], community: [Card]) -> PokerHandResult {
        let all = hole + community
        precondition(all.count == 7, "bestFiveOfSeven requires exactly 7 cards")
        var best: PokerHandResult? = nil
        for i in 0..<all.count {
            for j in (i+1)..<all.count {
                let five = all.enumerated().filter { $0.offset != i && $0.offset != j }.map { $0.element }
                let result = evaluate(five)
                if best == nil || result > best! { best = result }
            }
        }
        return best!
    }

    // Handles any count: pre-flop estimate (< 5), exact 5-card eval, or best-of-N for 6–7+
    public static func bestHand(hole: [Card], community: [Card]) -> PokerHandResult {
        let all = Array((hole + community).prefix(7))
        if all.count >= 7 {
            return bestFiveOfSeven(hole: Array(hole.prefix(2)), community: Array(community.prefix(5)))
        }
        if all.count == 5 {
            return evaluate(all)
        }
        if all.count == 6 {
            // Best of C(6,5)=6 combos
            var best: PokerHandResult? = nil
            for skip in 0..<all.count {
                let five = all.enumerated().filter { $0.offset != skip }.map { $0.element }
                let result = evaluate(five)
                if best == nil || result > best! { best = result }
            }
            return best!
        }
        // Pre-flop: < 5 cards — estimate strength from hole cards alone
        return estimateHoleStrength(hole: hole)
    }

    // Heuristic strength estimate from 2 hole cards (used pre-flop in Hold'em)
    private static func estimateHoleStrength(hole: [Card]) -> PokerHandResult {
        guard hole.count >= 2 else {
            return PokerHandResult(rank: .highCard, kickers: hole.map { $0.rank }.sorted(by: >))
        }
        let r0 = hole[0].rank, r1 = hole[1].rank
        if r0 == r1 {
            return PokerHandResult(rank: .onePair, kickers: [r0, r1])
        }
        let high = max(r0, r1), low = min(r0, r1)
        return PokerHandResult(rank: .highCard, kickers: [high, low])
    }
}
