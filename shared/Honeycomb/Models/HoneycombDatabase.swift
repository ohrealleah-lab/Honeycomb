import Foundation

public class HoneycombDatabase {
    public static let shared = HoneycombDatabase()
    public private(set) var allCards: [HoneycombCardData] = []

    private static let seedKey = "honeycomb_card_seed"

    private init() {
        allCards = HoneycombCardGenerator.generateAllCards(seed: HoneycombDatabase.loadOrCreateSeed())
    }

    private static func loadOrCreateSeed() -> UInt64 {
        if let stored = UserDefaults.standard.string(forKey: seedKey), let seed = UInt64(stored) {
            return seed
        }
        let seed = UInt64.random(in: UInt64.min...UInt64.max)
        UserDefaults.standard.set(String(seed), forKey: seedKey)
        return seed
    }

    // Regenerates the entire card pool under a fresh random seed — used by "Start Over"
    // so a maxed-out card bank can be played again with a different set of cards. Every
    // existing card id now maps to different stats, which is the point: HoneycombProfileManager
    // resets `unlockedCardIds`/`savedDecks` to just Deck 1's ids in the same operation, so
    // those surviving ids simply render as new cards after this call.
    public func reseed() {
        let newSeed = UInt64.random(in: UInt64.min...UInt64.max)
        UserDefaults.standard.set(String(newSeed), forKey: HoneycombDatabase.seedKey)
        allCards = HoneycombCardGenerator.generateAllCards(seed: newSeed)
    }

    public func card(id: Int) -> HoneycombCardData? {
        return allCards.first { $0.id == id }
    }
    
    public func randomCards(stars: Int, count: Int) -> [HoneycombCardData] {
        let pool = allCards.filter { $0.stars == stars }
        guard !pool.isEmpty else { return [] }
        var result: [HoneycombCardData] = []
        for _ in 0..<count {
            result.append(pool.randomElement()!)
        }
        return result
    }

    // Same star-tier pool as randomCards, but biased toward whichever cards are
    // actually strong under the match's current rules — under Reverse (where low
    // values capture high ones), a uniformly random pick within a tier could hand the
    // AI cards with a high total stat budget that are a *liability* rather than a
    // strength, letting a player farm high-star/high-value cards off a supposedly
    // "hard" opponent by simply enabling Reverse. Ranks by total stat *plus* how
    // unevenly it's spread across edges (variance), so a specialized card like
    // [8,8,1,1] outranks a flat card like [5,4,5,4] with the same total — the flat
    // one is weak on every edge and gets captured easily, the specialized one
    // dominates the two edges it's strong on. Every card in the tier stays eligible
    // (weighted, not hard-cutoff) so no card is permanently unreachable — a strict
    // top-slice cutoff here previously meant the bottom ~60% of every tier could
    // never appear as an opponent card regardless of how much the player owned —
    // but well-suited cards are still far more likely to be drawn, and picks favor
    // covering different dominant edges across the hand so the AI doesn't end up
    // with several cards all strong on the same side.
    public func rulesAwareCards(stars: Int, count: Int, preferLowStats: Bool) -> [HoneycombCardData] {
        let pool = allCards.filter { $0.stars == stars }
        guard !pool.isEmpty else { return [] }

        func specializationScore(_ stats: [Int]) -> Double {
            let total = Double(stats.reduce(0, +))
            let mean = total / Double(stats.count)
            let variance = stats.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(stats.count)
            return total + variance
        }

        let scored = pool.map { ($0, specializationScore($0.stats)) }
        let minScore = scored.map(\.1).min() ?? 0
        let maxScore = scored.map(\.1).max() ?? 0
        let scoreRange = max(maxScore - minScore, 0.0001)

        // Normalized 0...1 "how well-suited under current rules", then a floor so
        // even the least-suited card keeps a real (if small) chance of being drawn.
        func suitabilityWeight(_ score: Double) -> Double {
            let normalized = (score - minScore) / scoreRange
            let favored = preferLowStats ? (1 - normalized) : normalized
            return 0.2 + favored
        }

        var remaining = scored

        // Greedily pick, weighting toward candidates whose dominant edge is least
        // represented among cards already picked, so the resulting hand covers
        // different sides of the board instead of stacking similar specialists.
        var edgeCounts = [Int](repeating: 0, count: 4)
        func dominantEdge(_ card: HoneycombCardData) -> Int {
            card.stats.indices.max { card.stats[$0] < card.stats[$1] } ?? 0
        }

        var result: [HoneycombCardData] = []
        for _ in 0..<count {
            guard !remaining.isEmpty else {
                result.append(pool.randomElement()!)
                continue
            }
            let weights = remaining.map { suitabilityWeight($0.1) / Double(edgeCounts[dominantEdge($0.0)] + 1) }
            let totalWeight = weights.reduce(0, +)
            var r = Double.random(in: 0..<totalWeight)
            var chosenIndex = remaining.count - 1
            for (i, weight) in weights.enumerated() {
                if r < weight { chosenIndex = i; break }
                r -= weight
            }
            let chosen = remaining.remove(at: chosenIndex).0
            edgeCounts[dominantEdge(chosen)] += 1
            result.append(chosen)
        }
        return result
    }
}
