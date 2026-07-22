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
    private struct Tier {
        let stars: Int
        let valueRange: ClosedRange<Int>
        let budget: ClosedRange<Int>
        let countPerSuit: Int
    }

    private static let tiers: [Tier] = [
        Tier(stars: 1, valueRange: 1...7, budget: 12...15, countPerSuit: 26),
        Tier(stars: 2, valueRange: 1...7, budget: 16...21, countPerSuit: 36),
        Tier(stars: 3, valueRange: 1...8, budget: 20...25, countPerSuit: 41),
        Tier(stars: 4, valueRange: 1...9, budget: 24...28, countPerSuit: 21),
        Tier(stars: 5, valueRange: 1...10, budget: 25...30, countPerSuit: 14),
    ]

    private static let suits = ["S", "H", "D", "C"]

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
                        stats = (0..<4).map { _ in Int.random(in: tier.valueRange, using: &rng) }
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
