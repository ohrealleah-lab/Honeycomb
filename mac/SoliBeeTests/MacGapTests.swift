import Foundation

// Gap-filling coverage for pieces the game suites don't reach: the Honeycomb card bank and
// decks (unlocking, favourites, saving a deck, Start Over), the rule and rank text in both
// languages, the poker hand evaluator (every hand, wild deuces, best-of-N), and the update
// checker's version comparison. Pure rules and data only — no screens, no network.
struct MacGapTests {
    static let profileKeys = ["honeycomb_unlocked_cards", "honeycomb_saved_decks", "honeycomb_favorite_cards"]

    static func run() {
        UISound.isHeadlessMode = true
        testPokerHandNamesAndOrdering()
        testEveryFiveCardHand()
        testStraightsIncludingTheWheel()
        testKickersBreakTies()
        testWildDeuces()
        testBestOfSixAndSeven()
        testPreFlopEstimate()
        testVersionComparison()
        testRuleTextInBothLanguages()
        testSuddenDeathAndScoutingPartyWording()
        testDifficultyNamesInBothLanguages()
        testPlayerRankBands()
        withCleanDefaults(["appLanguage"], testStringLookupFallsBackAndFormats)
        testSuitNames()
        testPureStartOverDecks()
        // These two change the shared card bank in memory, so they run last.
        withCleanDefaults([], preserving: profileKeys, testCardBankUnlockFavouritesAndDecks)
        withCleanDefaults([], preserving: profileKeys, testStartOverRebuildsDeckOneFromItsOwnShape)
    }

    // MARK: - Poker hands

    static func c(_ suit: Card.Suit, _ rank: Int) -> Card { CovCards.card(suit, rank) }

    static func testPokerHandNamesAndOrdering() {
        let names = PokerHandRank.allCases.map { $0.displayName }
        expect(Set(names).count == PokerHandRank.allCases.count && names.allSatisfy { !$0.isEmpty }, "Every hand has its own name")
        expect(names.first == "High Card" && names.last == "Royal Flush", "From High Card up to Royal Flush")
        for (a, b) in zip(PokerHandRank.allCases, PokerHandRank.allCases.dropFirst()) {
            expect(a < b && !(b < a), "\(a.displayName) ranks below \(b.displayName)")
        }
        expect(PokerHandResult(rank: .onePair, kickers: [9]) < PokerHandResult(rank: .twoPair, kickers: [3, 2, 4]), "A higher rank always wins")
    }

    static func testEveryFiveCardHand() {
        func rank(_ cards: [Card]) -> PokerHandRank { PokerHandEvaluator.evaluate(cards).rank }
        expect(rank([c(.hearts, 1), c(.hearts, 13), c(.hearts, 12), c(.hearts, 11), c(.hearts, 10)]) == .royalFlush, "A-K-Q-J-10 suited")
        expect(rank([c(.spades, 9), c(.spades, 8), c(.spades, 7), c(.spades, 6), c(.spades, 5)]) == .straightFlush, "Straight flush")
        expect(rank([c(.spades, 9), c(.hearts, 9), c(.clubs, 9), c(.diamonds, 9), c(.spades, 2)]) == .fourOfAKind, "Four of a kind")
        expect(rank([c(.spades, 9), c(.hearts, 9), c(.clubs, 9), c(.diamonds, 4), c(.spades, 4)]) == .fullHouse, "Full house")
        expect(rank([c(.clubs, 2), c(.clubs, 5), c(.clubs, 9), c(.clubs, 11), c(.clubs, 13)]) == .flush, "Flush")
        expect(rank([c(.clubs, 5), c(.hearts, 6), c(.spades, 7), c(.clubs, 8), c(.diamonds, 9)]) == .straight, "Straight")
        expect(rank([c(.spades, 9), c(.hearts, 9), c(.clubs, 9), c(.diamonds, 4), c(.spades, 2)]) == .threeOfAKind, "Three of a kind")
        expect(rank([c(.spades, 9), c(.hearts, 9), c(.clubs, 4), c(.diamonds, 4), c(.spades, 2)]) == .twoPair, "Two pair")
        expect(rank([c(.spades, 9), c(.hearts, 9), c(.clubs, 4), c(.diamonds, 6), c(.spades, 2)]) == .onePair, "One pair")
        expect(rank([c(.spades, 9), c(.hearts, 8), c(.clubs, 4), c(.diamonds, 6), c(.spades, 2)]) == .highCard, "High card")
        expect(rank([c(.spades, 13), c(.hearts, 13), c(.clubs, 13), c(.diamonds, 13), c(.spades, 13)]) == .fourOfAKind, "Five of a kind (only possible with wilds) counts as the top quads")
    }

    static func testStraightsIncludingTheWheel() {
        let wheel = PokerHandEvaluator.evaluate([c(.clubs, 1), c(.hearts, 2), c(.spades, 3), c(.clubs, 4), c(.diamonds, 5)])
        expect(wheel.rank == .straight && wheel.kickers == [5], "A-2-3-4-5 is a straight with the five high")
        let broadway = PokerHandEvaluator.evaluate([c(.clubs, 1), c(.hearts, 13), c(.spades, 12), c(.clubs, 11), c(.diamonds, 10)])
        expect(broadway.rank == .straight && broadway.kickers == [14], "A-K-Q-J-10 offsuit is a straight with the ace high")
        expect(wheel < broadway, "Broadway beats the wheel")
        let wheelFlush = PokerHandEvaluator.evaluate([c(.hearts, 1), c(.hearts, 2), c(.hearts, 3), c(.hearts, 4), c(.hearts, 5)])
        expect(wheelFlush.rank == .straightFlush && wheelFlush.kickers == [5], "A suited wheel is a straight flush, not a royal")
        let notAStraight = PokerHandEvaluator.evaluate([c(.clubs, 13), c(.hearts, 1), c(.spades, 2), c(.clubs, 3), c(.diamonds, 4)])
        expect(notAStraight.rank == .highCard, "K-A-2-3-4 doesn't wrap around")
    }

    static func testKickersBreakTies() {
        let pairNineAce = PokerHandEvaluator.evaluate([c(.spades, 9), c(.hearts, 9), c(.clubs, 1), c(.diamonds, 6), c(.spades, 2)])
        let pairNineKing = PokerHandEvaluator.evaluate([c(.clubs, 9), c(.diamonds, 9), c(.clubs, 13), c(.hearts, 6), c(.hearts, 2)])
        expect(pairNineAce > pairNineKing, "Same pair, better kicker wins")
        let pairTen = PokerHandEvaluator.evaluate([c(.spades, 10), c(.hearts, 10), c(.clubs, 3), c(.diamonds, 4), c(.spades, 6)])
        expect(pairTen > pairNineAce, "A higher pair beats a lower pair with better kickers")
        let twoPairHigh = PokerHandEvaluator.evaluate([c(.spades, 13), c(.hearts, 13), c(.clubs, 3), c(.diamonds, 3), c(.spades, 6)])
        let twoPairLow = PokerHandEvaluator.evaluate([c(.spades, 12), c(.hearts, 12), c(.clubs, 11), c(.diamonds, 11), c(.spades, 6)])
        expect(twoPairHigh > twoPairLow, "Kings and threes beat queens and jacks")
        let flushAce = PokerHandEvaluator.evaluate([c(.clubs, 1), c(.clubs, 5), c(.clubs, 9), c(.clubs, 11), c(.clubs, 3)])
        let flushKing = PokerHandEvaluator.evaluate([c(.hearts, 13), c(.hearts, 5), c(.hearts, 9), c(.hearts, 11), c(.hearts, 3)])
        expect(flushAce > flushKing, "Ace-high flush beats king-high flush")
        expect(flushAce == PokerHandEvaluator.evaluate([c(.spades, 1), c(.spades, 5), c(.spades, 9), c(.spades, 11), c(.spades, 3)]),
               "Identical hands in different suits tie")
    }

    static func testWildDeuces() {
        func rank(_ cards: [Card]) -> PokerHandRank { PokerHandEvaluator.evaluateWithDeuces(cards).rank }
        expect(rank([c(.spades, 9), c(.hearts, 8), c(.clubs, 4), c(.diamonds, 6), c(.spades, 3)]) == .highCard, "No deuces: plain evaluation")
        expect(rank([c(.spades, 2), c(.hearts, 8), c(.clubs, 4), c(.diamonds, 6), c(.spades, 11)]) == .onePair, "One deuce makes a pair")
        expect(rank([c(.spades, 2), c(.hearts, 8), c(.clubs, 8), c(.diamonds, 6), c(.spades, 11)]) == .threeOfAKind, "A deuce on a pair makes trips")
        expect(rank([c(.spades, 2), c(.hearts, 8), c(.clubs, 8), c(.diamonds, 4), c(.spades, 4)]) == .fullHouse, "A deuce on two pair makes a full house")
        expect(rank([c(.hearts, 2), c(.hearts, 8), c(.hearts, 4), c(.hearts, 6), c(.hearts, 11)]) == .flush, "A deuce completes a flush")
        expect(rank([c(.hearts, 2), c(.hearts, 5), c(.hearts, 6), c(.hearts, 7), c(.hearts, 8)]) == .straightFlush, "A deuce completes a straight flush")
        expect(rank([c(.spades, 2), c(.hearts, 5), c(.clubs, 6), c(.diamonds, 7), c(.spades, 8)]) == .straight, "A deuce completes a straight")
        expect(rank([c(.spades, 2), c(.hearts, 2), c(.clubs, 9), c(.diamonds, 4), c(.spades, 6)]) == .threeOfAKind, "Two deuces make trips")
        expect(rank([c(.spades, 2), c(.hearts, 2), c(.clubs, 9), c(.diamonds, 9), c(.spades, 6)]) == .fourOfAKind, "Two deuces on a pair make quads")
        expect(rank([c(.spades, 2), c(.hearts, 2), c(.clubs, 2), c(.diamonds, 9), c(.spades, 6)]) == .fourOfAKind, "Three deuces make quads")
        expect(rank([c(.hearts, 2), c(.hearts, 2), c(.hearts, 2), c(.hearts, 9), c(.hearts, 10)]) == .royalFlush
               || rank([c(.hearts, 2), c(.hearts, 2), c(.hearts, 2), c(.hearts, 9), c(.hearts, 10)]) == .straightFlush,
               "Three deuces with two suited cards reach a straight flush or better")
        expect(rank([c(.spades, 2), c(.hearts, 2), c(.clubs, 2), c(.diamonds, 2), c(.spades, 9)]) == .fourOfAKind, "Four deuces are four of a kind")
        // The best hand is chosen, not the first one found.
        expect(rank([c(.hearts, 2), c(.hearts, 1), c(.hearts, 13), c(.hearts, 12), c(.hearts, 11)]) == .royalFlush, "A deuce for the missing ten gives a royal flush")
    }

    static func testBestOfSixAndSeven() {
        let hole = [c(.spades, 1), c(.spades, 13)]
        let community = [c(.spades, 12), c(.spades, 11), c(.spades, 10), c(.hearts, 2), c(.clubs, 3)]
        expect(PokerHandEvaluator.bestFiveOfSeven(hole: hole, community: community).rank == .royalFlush, "The best five of seven is found")
        expect(PokerHandEvaluator.bestHand(hole: hole, community: community).rank == .royalFlush, "bestHand with seven cards")

        let sixCommunity = [c(.spades, 9), c(.spades, 4), c(.spades, 2), c(.clubs, 3)]
        let six = PokerHandEvaluator.bestHand(hole: hole, community: sixCommunity)
        expect(six.rank == .flush, "Six cards: the best five are the spade flush (got \(six.rank))")
        let sixRoyal = PokerHandEvaluator.bestHand(hole: hole, community: Array(community.prefix(4)))
        expect(sixRoyal.rank == .royalFlush, "Six cards: the royal flush is found among them")
        let five = PokerHandEvaluator.bestHand(hole: [c(.hearts, 9), c(.clubs, 9)], community: [c(.spades, 9), c(.diamonds, 4), c(.spades, 2)])
        expect(five.rank == .threeOfAKind, "Five cards: evaluated directly")
        let extra = PokerHandEvaluator.bestHand(hole: hole, community: community + [c(.diamonds, 7)])
        expect(extra.rank == .royalFlush, "Cards beyond seven are ignored")
    }

    static func testPreFlopEstimate() {
        let pair = PokerHandEvaluator.bestHand(hole: [c(.hearts, 7), c(.clubs, 7)], community: [])
        expect(pair.rank == .onePair && pair.kickers == [7, 7], "A pocket pair is rated as a pair")
        let high = PokerHandEvaluator.bestHand(hole: [c(.hearts, 4), c(.clubs, 12)], community: [])
        expect(high.rank == .highCard && high.kickers == [12, 4], "Two different cards are rated high card, high first")
        let one = PokerHandEvaluator.bestHand(hole: [c(.hearts, 4)], community: [])
        expect(one.rank == .highCard && one.kickers == [4], "A single card is just that card")
        expect(pair > high, "A pocket pair beats two high cards")
    }

    // MARK: - Update checker

    static func testVersionComparison() {
        expect(UpdateChecker.isVersion("1.0.1", newerThan: "1.0.0"), "Patch bump is newer")
        expect(UpdateChecker.isVersion("0.9.10", newerThan: "0.9.6"), "Numbers compare as numbers, not text (10 > 6)")
        expect(UpdateChecker.isVersion("2.0", newerThan: "1.9.9"), "Major bump wins")
        expect(UpdateChecker.isVersion("v1.2.0", newerThan: "1.1.9"), "A leading v is ignored")
        expect(UpdateChecker.isVersion("V1.2.0", newerThan: "1.1.9"), "...whichever case")
        expect(UpdateChecker.isVersion("1.0.1", newerThan: "1.0"), "A missing component counts as 0")
        expect(!UpdateChecker.isVersion("1.0", newerThan: "1.0.0"), "1.0 is the same as 1.0.0")
        expect(!UpdateChecker.isVersion("1.0.0", newerThan: "1.0.0"), "The same version isn't newer")
        expect(!UpdateChecker.isVersion("0.9.5", newerThan: "0.9.6"), "An older one isn't newer")
        expect(!UpdateChecker.isVersion("1.0.0-beta", newerThan: "1.0.1"), "A suffix doesn't make an older number newer")
    }

    // MARK: - Rule and rank text

    static func testRuleTextInBothLanguages() {
        for rule in HoneycombRule.allCases {
            let en = honeycombLocalizedRuleExplanation(rule, language: .english)
            let es = honeycombLocalizedRuleExplanation(rule, language: .spanish)
            expect(!en.isEmpty && !es.isEmpty && !en.hasPrefix("?"), "\(rule) has an explanation in both languages")
            expect(en != es, "\(rule)'s Spanish explanation differs from the English one")
        }
        // With suits active, Pollination / Smoked Out name the suits (English wording).
        let asc = honeycombLocalizedRuleExplanation(.ascension, activeSuits: ["H", "S"], language: .spanish)
        expect(asc.contains("Hearts") && asc.contains("Spades"), "Pollination names its suits when they're known: \(asc)")
        let desc = honeycombLocalizedRuleExplanation(.descension, activeSuits: ["D"], language: .english)
        expect(desc.contains("Diamonds"), "Smoked Out names its suit when it's known: \(desc)")
        expect(honeycombLocalizedRuleExplanation(.ascension, language: .english) != asc, "…and has a generic wording when it isn't")
        for rule in HoneycombRule.allCases {
            expect(!rule.explanation().isEmpty, "\(rule) has a plain explanation")
        }
    }

    // Sudden Death and Scouting Party are worded the same on Mac, Windows and Android: the
    // spreadsheet text the screens show and the built-in fallback agree.
    static func testSuddenDeathAndScoutingPartyWording() {
        let sudden = "If the match ends in a draw, the cards currently owned by each player become their new hand and the match restarts immediately."
        expect(honeycombLocalizedRuleExplanation(.suddenDeath, language: .english) == sudden, "Sudden Death text")
        expect(HoneycombRule.suddenDeath.explanation() == sudden, "Sudden Death fallback text")
        let scouting = "Three randomly selected cards from each player's hand are visible."
        expect(honeycombLocalizedRuleExplanation(.threeOpen, language: .english) == scouting, "Scouting Party text")
        expect(HoneycombRule.threeOpen.explanation() == scouting || HoneycombRule.threeOpen.explanation().contains("each player's hand"),
               "Scouting Party fallback names each player's hand")
    }

    static func testDifficultyNamesInBothLanguages() {
        for d in HoneycombDifficulty.allCases {
            let en = honeycombLocalizedDifficultyName(d, language: .english)
            let es = honeycombLocalizedDifficultyName(d, language: .spanish)
            expect(!en.isEmpty && !es.isEmpty, "\(d) has a name in both languages")
        }
        expect(Set(HoneycombDifficulty.allCases.map { honeycombLocalizedDifficultyName($0, language: .english) }).count == 4, "Four different names")
        expect(honeycombLocalizedDifficultyName(.easy, language: .english) == "Baby Bee", "Easy is Baby Bee")
        expect(honeycombLocalizedDifficultyName(.ultraHard, language: .english) == "Killer Bee", "Ultra Hard is Killer Bee")
    }

    static func testPlayerRankBands() {
        func rank(_ n: Int, of total: Int = 600, _ lang: AppLanguage = .english) -> String {
            honeycombLocalizedPlayerRankName(cardsCollected: n, totalCards: total, language: lang)
        }
        // Each band starts where the table says it does: the name changes exactly at the boundary.
        for boundary in [10, 20, 50, 100, 150, 200, 300, 400, 500] {
            expect(rank(boundary - 1) != rank(boundary), "The rank changes at \(boundary) cards")
        }
        expect(rank(0) == rank(9), "Below 10 cards everyone is just the player")
        expect(rank(20) == rank(49) && rank(50) == rank(99) && rank(100) == rank(149), "A band holds its name until the next boundary")
        expect(rank(500) == rank(599), "500+ is one band…")
        expect(rank(600) != rank(599), "…until you own every card: the completionist title")
        expect(rank(250, of: 250) != rank(249, of: 250), "Owning everything gets the completionist title whatever the collection size")
        expect(rank(700, of: 600) == rank(600), "More than the total is still the completionist")
        expect(rank(5, of: 0) == rank(0), "An empty collection doesn't count as complete")
        let names = Set([0, 10, 20, 50, 100, 150, 200, 300, 400, 500, 600].map { rank($0) })
        expect(names.count == 11, "Eleven different titles from first card to completionist")
        expect(rank(150, .spanish) != rank(150, .english), "The titles are translated")
    }

    static func testStringLookupFallsBackAndFormats() {
        let en = L(.playerLabel, language: .english)
        let es = L(.playerLabel, language: .spanish)
        expect(!en.isEmpty && !es.isEmpty && en != es, "A string differs between the two languages")
        let formatted = L(.freecellStatisticsFmt, language: .english, "1 deck")
        expect(formatted.contains("1 deck") && !formatted.contains("%@"), "Placeholders are filled in: \(formatted)")
        let c = AppCoordinator()
        c.language = .spanish
        expect(c.L(.playerLabel) == es, "The coordinator's lookup follows its language")
        c.language = .english
        expect(c.L(.playerLabel) == en, "...and switches back")
        expect(c.L(.freecellStatisticsFmt, "2 decks").contains("2 decks"), "The coordinator fills placeholders too")
    }

    static func testSuitNames() {
        expect(HoneycombCardData.suitDisplayName("S") == "Spades" && HoneycombCardData.suitDisplayName("H") == "Hearts"
               && HoneycombCardData.suitDisplayName("D") == "Diamonds" && HoneycombCardData.suitDisplayName("C") == "Clubs",
               "Suit codes read as names")
        expect(HoneycombCardData.suitDisplayName("X") == "X", "An unknown code is shown as it is")
    }

    // MARK: - Honeycomb card bank and decks

    static func testPureStartOverDecks() {
        let current = [HoneycombDeckState(name: "Mine", cardIds: [10, 11, 12, 13, 14])] + Array(repeating: HoneycombDeckState(name: "Other", cardIds: [1]), count: 4)
        let starsOf: [Int: Int] = [10: 5, 11: 4, 12: 3, 13: 3, 14: 3]
        var asked: [Int] = []
        let rebuilt = HoneycombProfileManager.computeStartOverDecks(
            currentDecks: current, starLookup: { starsOf[$0] }, randomCard: { stars in asked.append(stars); return 100 + stars })
        expect(rebuilt.count == 5, "Five slots come back")
        expect(rebuilt[0].name == "Default", "Deck 1 is renamed Default")
        expect(asked == [5, 4, 3, 3, 3], "Deck 1 is redrawn with the same shape (5★, 4★, three 3★), got \(asked)")
        expect(rebuilt[0].cardIds == [105, 104, 103, 103, 103], "…using the cards the draw returned")
        expect(rebuilt[1...].allSatisfy { $0.cardIds.isEmpty && $0.name.isEmpty }, "Every other deck is wiped")

        asked = []
        let fresh = HoneycombProfileManager.computeStartOverDecks(
            currentDecks: Array(repeating: HoneycombDeckState(), count: 5), starLookup: { _ in nil }, randomCard: { stars in asked.append(stars); return stars })
        expect(asked == [1, 1, 1, 2, 2], "A never-played Deck 1 starts as three 1★ and two 2★, got \(asked)")
        expect(fresh[0].name == "Default" && fresh[0].cardIds.count == 5, "…named Default")

        let unknown = HoneycombProfileManager.computeStartOverDecks(
            currentDecks: current, starLookup: { _ in nil }, randomCard: { $0 })
        expect(unknown[0].cardIds.isEmpty, "Cards that can't be looked up are skipped, not guessed")
    }

    static func cardId(stars: Int, skipping used: Set<Int> = []) -> Int {
        HoneycombDatabase.shared.allCards.first { $0.stars == stars && !used.contains($0.id) }!.id
    }

    static func testCardBankUnlockFavouritesAndDecks() {
        let bank = HoneycombProfileManager.shared
        let db = HoneycombDatabase.shared
        let target = db.allCards.first { !bank.unlockedCardIds.contains($0.id) }!.id
        bank.unlockCard(id: target)
        expect(bank.unlockedCardIds.contains(target), "A stolen card goes into the bank")
        expect((UserDefaults.standard.array(forKey: "honeycomb_unlocked_cards") as? [Int])?.contains(target) == true, "…and is saved")
        bank.unlockCard(id: target)
        expect(bank.unlockedCardIds.filter { $0 == target }.count == 1, "Unlocking twice keeps one copy")
        expect(!bank.isCardBankFull, "The bank isn't full while cards are missing")

        let fav = db.allCards[0].id
        bank.toggleFavorite(id: fav)
        expect(bank.favoriteCardIds.contains(fav), "A favourite is added")
        expect((UserDefaults.standard.array(forKey: "honeycomb_favorite_cards") as? [Int])?.contains(fav) == true, "…and saved")
        bank.toggleFavorite(id: fav)
        expect(!bank.favoriteCardIds.contains(fav), "Toggling again removes it")

        let ids = [cardId(stars: 5), cardId(stars: 4), cardId(stars: 3), cardId(stars: 3, skipping: [cardId(stars: 3)]), db.allCards.filter { $0.stars == 3 }[2].id]
        bank.saveDeck(index: 2, name: "Strong", cardIds: ids)
        expect(bank.savedDecks[2].name == "Strong" && bank.savedDecks[2].cardIds == ids, "A saved deck keeps its name and cards")
        let data = UserDefaults.standard.data(forKey: "honeycomb_saved_decks")
        let decoded = data.flatMap { try? JSONDecoder().decode([HoneycombDeckState].self, from: $0) }
        expect(decoded?[2].name == "Strong" && decoded?[2].cardIds == ids, "…and is saved to disk")
        let before = bank.savedDecks
        bank.saveDeck(index: -1, name: "Nope", cardIds: [1])
        bank.saveDeck(index: 99, name: "Nope", cardIds: [1])
        expect(bank.savedDecks == before, "A deck slot that doesn't exist is ignored")
    }

    static func testStartOverRebuildsDeckOneFromItsOwnShape() {
        let bank = HoneycombProfileManager.shared
        let db = HoneycombDatabase.shared
        let threes = db.allCards.filter { $0.stars == 3 }
        let old = [cardId(stars: 5), cardId(stars: 4), threes[0].id, threes[1].id, threes[2].id]
        bank.saveDeck(index: 0, name: "My best", cardIds: old)
        bank.saveDeck(index: 1, name: "Second", cardIds: old)
        bank.toggleFavorite(id: db.allCards[0].id)

        bank.startOver()

        expect(bank.savedDecks.count == 5, "Still five slots")
        expect(bank.savedDecks[0].name == "Default", "Deck 1 is Default again")
        let stars = bank.savedDecks[0].cardIds.compactMap { db.card(id: $0)?.stars }.sorted()
        expect(stars == [3, 3, 3, 4, 5], "Deck 1 keeps its shape (5★, 4★, three 3★): \(stars)")
        expect(Set(bank.savedDecks[0].cardIds).count == 5, "…with five different cards")
        expect(bank.savedDecks[1...].allSatisfy { $0.cardIds.isEmpty }, "The other decks are wiped")
        expect(bank.unlockedCardIds == Set(bank.savedDecks[0].cardIds), "The card bank is just Deck 1's cards")
        expect(bank.favoriteCardIds.isEmpty, "Favourites are cleared")
        expect(Set((UserDefaults.standard.array(forKey: "honeycomb_unlocked_cards") as? [Int]) ?? []) == bank.unlockedCardIds, "…and saved that way")
        expect((UserDefaults.standard.array(forKey: "honeycomb_favorite_cards") as? [Int])?.isEmpty == true, "Cleared favourites are saved too")
    }
}
