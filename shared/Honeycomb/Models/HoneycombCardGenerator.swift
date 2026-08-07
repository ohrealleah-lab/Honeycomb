import Foundation

// Deterministic, seedable RNG (Swift's `Int.random(in:)` draws from the non-deterministic
// system RNG unless an explicit generator is passed) so the same seed always produces the
// same card pool — HoneycombProfileManager persists `unlockedCardIds` by id, so a player's
// progress would desync from what those ids render as if the pool weren't stable across
// launches for a given seed.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum HoneycombCardGenerator {
    // Suit-agnostic by design: suit no longer implies a stat "play style" (it's purely
    // the label Ascension/Descension keys off), so every suit draws from the same
    // per-tier value range and total-stat budget. The budget window keeps a star
    // rating meaningful — without it, a 5★ card could roll all 1s just because 1 is
    // within its per-edge range.
    //
    // valueWeights/symmetryChance/templateShapes/templateShare all come from analyzing
    // the real FFXIV Triple Triad card set (tools/FFXIV_Triple_Triad_Cards.xlsx) against
    // this generator: the budget bands already matched the real per-star sum ranges
    // exactly, but real cards weren't uniformly random within that budget — they lean on
    // a favored value (7), are more lopsided (variance) than uniform sampling produces,
    // occasionally mirror Top/Bottom and Right/Left, and reuse a handful of "template"
    // stat-shapes across many different cards far more than chance would predict. These
    // four fields close each of those gaps; see conversation/product notes for the
    // real-data breakdown each one is derived from.
    private struct Tier {
        let stars: Int
        let valueRange: ClosedRange<Int>
        let budget: ClosedRange<Int>
        let countPerSuit: Int
        // One weight per value in valueRange (index 0 == valueRange.lowerBound) — not
        // normalized to sum to 100, just relative likelihood, matching the real game's
        // per-star value-frequency distribution.
        let valueWeights: [Double]
        // Probability [0, 1) a freshly-rolled (non-template) card draws only 2 values
        // and mirrors them into Top/Bottom + Right/Left, matching the real game's
        // opposite-side-symmetry rate for this tier.
        let symmetryChance: Double
        // Probability [0, 1) a card in this tier is drawn from templateShapes (a
        // randomly-permuted real template) instead of freshly rolled.
        let templateShare: Double
        // Real FFXIV stat-shapes (sorted, suit/position-agnostic) that recur across many
        // different named cards in that source data — reused here at a modest rate
        // (templateShare) so a few "signature" designs recur across our suits too,
        // without collapsing the whole tier onto a handful of shapes.
        let templateShapes: [[Int]]
    }

    private static let tiers: [Tier] = [
        Tier(stars: 1, valueRange: 1...7, budget: 12...15, countPerSuit: 26,
             valueWeights: [18, 21, 17, 19, 11, 7, 7], symmetryChance: 0.038, templateShare: 0.15,
             templateShapes: [[1, 1, 4, 7], [2, 2, 5, 5], [1, 1, 5, 6], [2, 2, 2, 7], [1, 2, 3, 7],
                               [3, 3, 3, 4], [2, 3, 4, 5], [2, 2, 4, 6], [2, 3, 4, 4], [2, 3, 3, 4]]),
        Tier(stars: 2, valueRange: 1...7, budget: 16...21, countPerSuit: 36,
             valueWeights: [5, 11, 13, 16, 17, 19, 20], symmetryChance: 0.052, templateShare: 0.15,
             templateShapes: [[1, 3, 7, 7], [2, 3, 6, 7], [1, 6, 7, 7], [2, 4, 6, 7], [2, 2, 7, 7],
                               [3, 3, 6, 7], [3, 5, 5, 6], [2, 6, 6, 6], [3, 5, 5, 7], [3, 4, 6, 6]]),
        Tier(stars: 3, valueRange: 1...8, budget: 20...25, countPerSuit: 41,
             valueWeights: [8, 6, 8, 12, 9, 18, 21, 19], symmetryChance: 0.018, templateShare: 0.15,
             templateShapes: [[1, 6, 7, 8], [4, 4, 7, 8], [2, 4, 7, 8], [1, 6, 7, 7], [2, 3, 7, 8],
                               [1, 4, 8, 8], [3, 3, 7, 8], [1, 4, 7, 8], [3, 5, 6, 8], [2, 5, 7, 8]]),
        Tier(stars: 4, valueRange: 1...9, budget: 24...28, countPerSuit: 21,
             valueWeights: [7, 4, 4, 5, 9, 10, 18, 22, 21], symmetryChance: 0.051, templateShare: 0.15,
             templateShapes: [[1, 7, 8, 9], [4, 6, 6, 8], [6, 7, 7, 8], [1, 8, 8, 8], [4, 4, 8, 9],
                               [2, 5, 9, 9], [1, 5, 9, 9], [5, 6, 6, 7], [6, 6, 8, 8], [6, 6, 7, 9]]),
        Tier(stars: 5, valueRange: 1...10, budget: 25...30, countPerSuit: 14,
             valueWeights: [6, 4, 4, 6, 8, 10, 10, 11, 15, 26], symmetryChance: 0.014, templateShare: 0.15,
             templateShapes: [[1, 7, 8, 9], [1, 7, 9, 10], [2, 5, 10, 10], [6, 7, 7, 8], [1, 8, 8, 8],
                               [4, 4, 8, 9], [2, 5, 9, 9], [4, 6, 8, 10], [6, 6, 8, 8], [6, 7, 7, 10]]),
    ]

    private static let suits = ["S", "H", "D", "C"]

    private static func weightedValue(_ tier: Tier, using rng: inout SplitMix64) -> Int {
        let total = tier.valueWeights.reduce(0, +)
        let r = Double.random(in: 0..<total, using: &rng)
        var cumulative = 0.0
        for (i, w) in tier.valueWeights.enumerated() {
            cumulative += w
            if r < cumulative { return tier.valueRange.lowerBound + i }
        }
        return tier.valueRange.upperBound
    }

    public static func generateAllCards(seed: UInt64) -> [HoneycombCardData] {
        var rng = SplitMix64(seed: seed)
        var allCards: [HoneycombCardData] = []
        var nextId = 1

        for suit in suits {
            var seenCombos = Set<[Int]>()
            var suitIndex = 1

            for tier in tiers {
                for _ in 0..<tier.countPerSuit {
                    var stats: [Int]
                    repeat {
                        if !tier.templateShapes.isEmpty, Double.random(in: 0..<1, using: &rng) < tier.templateShare {
                            stats = tier.templateShapes.randomElement(using: &rng)!.shuffled(using: &rng)
                        } else if Double.random(in: 0..<1, using: &rng) < tier.symmetryChance {
                            let a = weightedValue(tier, using: &rng)
                            let b = weightedValue(tier, using: &rng)
                            stats = [a, b, a, b]
                        } else {
                            stats = (0..<4).map { _ in weightedValue(tier, using: &rng) }
                        }
                    } while !(tier.budget.contains(stats.reduce(0, +))) || !seenCombos.insert(stats).inserted

                    allCards.append(HoneycombCardData(
                        id: nextId,
                        name: "\(suitSingular(suit)) \(suitIndex)",
                        stars: tier.stars,
                        stats: stats,
                        suit: suit
                    ))
                    nextId += 1
                    suitIndex += 1
                }
            }
        }

        return allCards
    }

    private static func suitSingular(_ suit: String) -> String {
        switch suit {
        case "S": return "Spade"
        case "H": return "Heart"
        case "D": return "Diamond"
        case "C": return "Club"
        default: return suit
        }
    }
}
