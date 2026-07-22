import Foundation

struct HoneycombCardGeneratorTests {
    static func run() {
        testTotalsAndTierCounts()
        testNoInSuitDuplicates()
        testStatRangesAndBudgets()
        testDeterminism()
        testProfileStartOver()
        testDatabaseSmokeTest()
    }

    static func testTotalsAndTierCounts() {
        let cards = HoneycombCardGenerator.generateAllCards(seed: 1)
        assert(cards.count == 552, "Total card pool must be 552")

        let suits = ["S", "H", "D", "C"]
        let expectedTierCounts: [Int: Int] = [1: 26, 2: 36, 3: 41, 4: 21, 5: 14]

        for suit in suits {
            let suitCards = cards.filter { $0.suit == suit }
            assert(suitCards.count == 138, "\(suit) must have exactly 138 cards")

            for (stars, expected) in expectedTierCounts {
                let count = suitCards.filter { $0.stars == stars }.count
                assert(count == expected, "\(suit) \(stars)★ must have \(expected) cards, got \(count)")
            }
        }
    }

    static func testNoInSuitDuplicates() {
        let cards = HoneycombCardGenerator.generateAllCards(seed: 42)
        for suit in ["S", "H", "D", "C"] {
            let suitCards = cards.filter { $0.suit == suit }
            let uniqueCombos = Set(suitCards.map { $0.stats })
            assert(uniqueCombos.count == suitCards.count, "\(suit) must have zero duplicate N/E/S/W combos")
        }
    }

    static func testStatRangesAndBudgets() {
        let cards = HoneycombCardGenerator.generateAllCards(seed: 7)
        let valueRanges: [Int: ClosedRange<Int>] = [1: 1...7, 2: 1...7, 3: 1...8, 4: 1...9, 5: 1...10]
        let budgets: [Int: ClosedRange<Int>] = [1: 12...15, 2: 16...21, 3: 20...25, 4: 24...28, 5: 25...30]

        for card in cards {
            guard let valueRange = valueRanges[card.stars], let budget = budgets[card.stars] else {
                assertionFailure("Unexpected star tier \(card.stars)")
                continue
            }
            for stat in card.stats {
                assert(valueRange.contains(stat), "Card \(card.id) stat \(stat) out of range for \(card.stars)★")
            }
            let total = card.stats.reduce(0, +)
            assert(budget.contains(total), "Card \(card.id) total \(total) out of budget for \(card.stars)★")
        }
    }

    static func testDeterminism() {
        let a = HoneycombCardGenerator.generateAllCards(seed: 123)
        let b = HoneycombCardGenerator.generateAllCards(seed: 123)
        assert(a == b, "Same seed must produce identical card pools")

        let c = HoneycombCardGenerator.generateAllCards(seed: 456)
        assert(a != c, "Different seeds must produce different card pools")
    }

    static func testProfileStartOver() {
        // Exercises the pure core of Start Over directly, rather than the shared
        // singleton (which persists to real UserDefaults) — see HoneycombDeck.swift.
        let currentDecks = [
            HoneycombDeckState(name: "Keep Me", cardIds: [1, 2, 3, 4, 5]),
            HoneycombDeckState(name: "Slot Two", cardIds: [6, 7, 8, 9, 10]),
        ] + Array(repeating: HoneycombDeckState(), count: 3)

        // Mirrors "a 5, 4, three 3s": ids 1-3 are 3-star, id 4 is 4-star, id 5 is 5-star.
        let stars: [Int: Int] = [1: 3, 2: 3, 3: 3, 4: 4, 5: 5]
        var drawnComposition: [Int] = []
        let result = HoneycombProfileManager.computeStartOverDecks(
            currentDecks: currentDecks,
            starLookup: { stars[$0] },
            randomCard: { starTier in
                drawnComposition.append(starTier)
                return starTier * 1000 // fake new id, distinguishable from the old ones
            }
        )

        assert(drawnComposition == [3, 3, 3, 4, 5], "Deck 1 must be redrawn matching its previous star composition")
        assert(result[0].cardIds == [3000, 3000, 3000, 4000, 5000], "Deck 1 must get freshly drawn cards, not the old ids")
        assert(result[0].name == "Default", "Deck 1 must be renamed \"Default\" by Start Over")
        for index in 1..<5 {
            assert(result[index].cardIds.isEmpty, "Deck \(index + 1) must be cleared by Start Over")
        }

        // Edge case: Deck 1 was never filled — the default starter composition
        // (three 1-star, two 2-star) must be drawn instead.
        let emptyDecks = Array(repeating: HoneycombDeckState(), count: 5)
        var starterComposition: [Int] = []
        let resultWithStarters = HoneycombProfileManager.computeStartOverDecks(
            currentDecks: emptyDecks,
            starLookup: { _ in
                assertionFailure("Star lookup should not be called when Deck 1 was never filled")
                return nil
            },
            randomCard: { starTier in
                starterComposition.append(starTier)
                return starTier * 1000
            }
        )
        assert(starterComposition == [1, 1, 1, 2, 2], "Empty Deck 1 must draw the default starter composition")
        assert(resultWithStarters[0].cardIds == [1000, 1000, 1000, 2000, 2000], "Empty Deck 1 must be filled with freshly drawn starter-tier cards")
    }

    static func testDatabaseSmokeTest() {
        let fives = HoneycombDatabase.shared.randomCards(stars: 3, count: 5)
        assert(fives.count == 5, "randomCards must still return the requested count")
        assert(fives.allSatisfy { $0.stars == 3 }, "randomCards must only return cards from the requested tier")
    }
}
