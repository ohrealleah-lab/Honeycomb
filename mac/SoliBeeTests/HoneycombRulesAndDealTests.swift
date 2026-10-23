import Foundation

// Honeycomb rule picking and how a match is dealt: the Rules screen's Auto / Pick / Ban
// logic (HoneycombRuleSelection), and what startNewGame() does with those choices — forced
// Normal Mode, picked rules, the roulette (bans, exclusive pairs, difficulty limits), each
// difficulty's opponent deck, the Ultra Hard Pollination guarantee, the locked difficulty
// and Rematch replaying the same deal.
//
// The roulette and deck rolls are random, so those tests deal many matches and check that a
// rule of the game is NEVER broken (a banned rule never appears, a pair that can't coexist
// never coexists) rather than asserting any one random result.
struct HoneycombRulesAndDealTests {
    static let defaultsKeys = [
        "honeycomb_options", "honeycomb_stats", "honeycomb_unlocked_cards", "honeycomb_saved_decks",
        "honeycomb_favorite_cards", "honeycomb_card_seed", "HoneycombFirstPlayedDate", "HoneycombHasShownOneYearBanner"
    ]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) { withCleanDefaults([], preserving: defaultsKeys, test) }
        testPickingARuleAndTheStateOfEachRow()
        testExclusivePairsSwapInsteadOfStacking()
        testFourRuleCapAndNetZeroSwapAtTheCap()
        testNormalModeAndAutoAndBanInteractions()
        testSillyBeeGuardStopsBanningEverything()
        isolated(testForcedNormalModeDealsNoRules)
        isolated(testPickedRulesAreExactlyTheRulesPlayed)
        isolated(testRouletteNeverBreaksBansOrExclusivesOrDifficultyLimits)
        isolated(testBanningNormalModeAlwaysRollsAtLeastOneRule)
        isolated(testRouletteWithOneRuleLeftOnlyUsesThatRule)
        isolated(testOpponentDeckStarsPerDifficulty)
        isolated(testUltraHardGuaranteesThreePollinationSuitCards)
        isolated(testNoStressMatchDealsTheOverpoweredPlayerDeck)
        isolated(testDifficultyIsLockedForTheMatch)
        isolated(testRematchReplaysTheSameDealAndRules)
    }

    // MARK: - Rule selection (pure)

    typealias Row = HoneycombRuleRowID

    struct Sel {
        var picked: Set<HoneycombRule> = []
        var normal = false
        var banned: Set<String> = []
        func state(_ id: Row) -> HoneycombRuleState {
            HoneycombRuleSelection.state(of: id, selectedRules: picked, forceNormalMode: normal, bannedRules: banned)
        }
        @discardableResult
        mutating func set(_ s: HoneycombRuleState, _ id: Row) -> Bool {
            HoneycombRuleSelection.setState(s, for: id, selectedRules: &picked, forceNormalMode: &normal, bannedRules: &banned)
        }
    }

    static func testPickingARuleAndTheStateOfEachRow() {
        var s = Sel()
        expect(Row.banListOrder.allSatisfy { s.state($0) == .auto }, "Every row starts on Auto")
        expect(Row.banListOrder.count == HoneycombRule.allCases.count + 1 && Row.banListOrder.first == .normalMode,
               "The list is Normal Mode plus every rule")

        s.set(.picked, .rule(.plus))
        expect(s.state(.rule(.plus)) == .picked && s.picked == [.plus], "Picking a rule marks it Picked")
        s.set(.banned, .rule(.same))
        expect(s.state(.rule(.same)) == .banned && s.banned == ["Symmetry"], "Banning stores the rule's name")
        s.set(.picked, .rule(.same))
        expect(s.state(.rule(.same)) == .picked && s.banned.isEmpty, "Picking a banned rule lifts the ban")
        s.set(.banned, .rule(.same))
        expect(s.state(.rule(.same)) == .banned && !s.picked.contains(.same), "Banning a picked rule un-picks it")
        s.set(.auto, .rule(.same))
        expect(s.state(.rule(.same)) == .auto && s.banned.isEmpty, "Auto clears a ban")
        s.set(.auto, .rule(.plus))
        expect(s.picked.isEmpty && s.state(.rule(.plus)) == .auto, "Auto clears a pick")
    }

    static func testExclusivePairsSwapInsteadOfStacking() {
        let pairs: [(HoneycombRule, HoneycombRule)] = [(.ascension, .descension), (.order, .chaos), (.allOpen, .threeOpen)]
        for (a, b) in pairs {
            var s = Sel()
            s.set(.picked, .rule(a))
            s.set(.picked, .rule(b))
            expect(s.picked == [b], "\(a) and \(b) can't both be picked — the second replaces the first")
            s.set(.picked, .rule(a))
            expect(s.picked == [a], "...and back again")
        }
        // Bomb Shelter hides a card, which is pointless when All/Three Open shows every card.
        var s = Sel()
        s.set(.picked, .rule(.bombShelter))
        s.set(.picked, .rule(.allOpen))
        expect(s.picked == [.allOpen], "Picking Clear Skies drops Capped Brood")
        s.set(.picked, .rule(.bombShelter))
        expect(s.picked == [.bombShelter], "Picking Capped Brood drops Clear Skies")
        s.set(.picked, .rule(.threeOpen))
        expect(s.picked == [.threeOpen], "Picking Scouting Party drops Capped Brood")
        s.set(.picked, .rule(.plus))
        expect(s.picked == [.threeOpen, .plus], "Unrelated rules stack")
    }

    static func testFourRuleCapAndNetZeroSwapAtTheCap() {
        var s = Sel()
        for r in [HoneycombRule.plus, .same, .reverse, .fallenAce] { s.set(.picked, .rule(r)) }
        expect(s.picked.count == 4, "Four rules can be picked")
        s.set(.picked, .rule(.swap))
        expect(s.picked.count == 4 && !s.picked.contains(.swap), "A fifth pick is refused")

        s.set(.auto, .rule(.fallenAce))
        s.set(.picked, .rule(.ascension))
        expect(s.picked.count == 4 && s.picked.contains(.ascension), "Back at four with Pollination")
        s.set(.picked, .rule(.descension))
        expect(s.picked.count == 4 && s.picked.contains(.descension) && !s.picked.contains(.ascension),
               "At the cap, swapping to the partner rule still works (net zero, not an addition)")
    }

    static func testNormalModeAndAutoAndBanInteractions() {
        var s = Sel()
        s.set(.picked, .rule(.plus))
        s.set(.picked, .rule(.same))
        s.set(.picked, .normalMode)
        expect(s.normal && s.picked.isEmpty && s.state(.normalMode) == .picked, "Picking Normal Mode clears every picked rule")
        s.set(.picked, .rule(.plus))
        expect(!s.normal && s.picked == [.plus], "Picking a rule leaves Normal Mode")
        s.set(.picked, .normalMode)
        s.set(.banned, .normalMode)
        expect(!s.normal && s.banned == ["Normal Mode"] && s.state(.normalMode) == .banned, "Banning Normal Mode un-forces it")
        s.set(.picked, .normalMode)
        expect(s.normal && s.banned.isEmpty, "Picking Normal Mode lifts its ban")
        s.set(.auto, .normalMode)
        expect(!s.normal && s.state(.normalMode) == .auto, "Auto un-forces Normal Mode")
    }

    static func testSillyBeeGuardStopsBanningEverything() {
        var s = Sel()
        let all = Row.banListOrder
        for id in all.dropLast() { expect(!s.set(.banned, id), "Banning \(id) is allowed while others remain") }
        expect(s.banned.count == all.count - 1, "All but one are banned")
        let last = all.last!
        expect(s.set(.banned, last), "Banning the last remaining one is blocked (the silly-bee warning)")
        expect(s.state(last) == .auto && s.banned.count == all.count - 1, "...and nothing changed")
        expect(!s.set(.banned, all.first!), "Re-banning something already banned isn't blocked")
        s.set(.auto, all.first!)
        expect(!s.set(.banned, last), "After lifting one ban, banning another is fine")
    }

    // MARK: - Dealing a match

    static func vmWith(difficulty: HoneycombDifficulty = .easy,
                       picked: Set<HoneycombRule> = [], normal: Bool = false, banned: Set<String> = []) -> HoneycombViewModel {
        let vm = HoneycombViewModel()
        var o = vm.options
        o.difficulty = difficulty
        o.selectedRules = picked
        o.forceNormalMode = normal
        o.bannedRules = banned
        vm.options = o
        return vm
    }

    /// The five cards the opponent was dealt, wherever they are now (hand, or already
    /// played if the opponent moved first). Swap trades are excluded by the callers.
    static func opponentDeal(_ vm: HoneycombViewModel) -> [HoneycombCardData] {
        let inHand = vm.opponentHand.filter { $0.originalOwner == .opponent }
        let onBoard = vm.board.cells.compactMap { $0.card }.filter { $0.originalOwner == .opponent }
        return (inHand + onBoard).map { $0.data }
    }

    /// How many matches to deal per difficulty. Hard and Ultra Hard run a deep AI search when
    /// the opponent opens (about a second each), so they get far fewer samples than Baby Bee/Honey Bee.
    static func samples(_ difficulty: HoneycombDifficulty, cheap: Int = 60, deep: Int = 8) -> Int {
        (difficulty == .hard || difficulty == .ultraHard) ? deep : cheap
    }

    static func testForcedNormalModeDealsNoRules() {
        for difficulty in HoneycombDifficulty.allCases {
            let vm = vmWith(difficulty: difficulty, picked: [.plus, .same], normal: true)
            for _ in 0..<samples(difficulty, cheap: 15, deep: 3) {
                vm.startNewGame()
                expect(vm.activeRules.isEmpty && vm.ascensionDescensionSuits.isEmpty, "Forced Normal Mode plays with no rules (\(difficulty))")
            }
        }
    }

    static func testPickedRulesAreExactlyTheRulesPlayed() {
        let vm = vmWith(difficulty: .medium, picked: [.plus, .reverse, .order])
        for _ in 0..<10 {
            vm.startNewGame()
            expect(Set(vm.activeRules) == [.plus, .reverse, .order] && vm.activeRules.count == 3, "Exactly the picked rules are played")
            expect(vm.ascensionDescensionSuits.isEmpty, "No Pollination/Smoked Out suit when neither is active")
        }
        let asc = vmWith(picked: [.ascension, .same])
        for _ in 0..<20 {
            asc.startNewGame()
            expect(asc.ascensionDescensionSuits.count == 1 && asc.ascensionDescensionSuits.isSubset(of: ["S", "H", "D", "C"]),
                   "Pollination affects exactly one real suit: \(asc.ascensionDescensionSuits)")
        }
        let desc = vmWith(picked: [.descension])
        desc.startNewGame()
        expect(desc.ascensionDescensionSuits.count == 1, "Smoked Out also gets one suit")
    }

    static func testRouletteNeverBreaksBansOrExclusivesOrDifficultyLimits() {
        let banned: Set<String> = [HoneycombRule.swap.rawValue, HoneycombRule.suddenDeath.rawValue]
        let limits: [HoneycombDifficulty: Int] = [.easy: 2, .medium: 2, .hard: 4, .ultraHard: 4]
        for difficulty in HoneycombDifficulty.allCases {
            let vm = vmWith(difficulty: difficulty, banned: banned)
            var sawRules = false
            for _ in 0..<samples(difficulty, cheap: 80, deep: 10) {
                vm.startNewGame()
                let rules = Set(vm.activeRules)
                expect(rules.count == vm.activeRules.count, "No rule is rolled twice (\(difficulty))")
                expect(rules.isDisjoint(with: [.swap, .suddenDeath]), "Banned rules never appear (\(difficulty)): \(rules)")
                expect(!(rules.contains(.ascension) && rules.contains(.descension)), "Pollination and Smoked Out never together")
                expect(!(rules.contains(.order) && rules.contains(.chaos)), "Hierarchy and Frenzy never together")
                expect(!(rules.contains(.allOpen) && rules.contains(.threeOpen)), "Clear Skies and Scouting Party never together")
                expect(!(rules.contains(.bombShelter) && (rules.contains(.allOpen) || rules.contains(.threeOpen))),
                       "Capped Brood never with an open-hand rule")
                expect(rules.count <= limits[difficulty]!, "\(difficulty) rolls at most \(limits[difficulty]!) rules, got \(rules.count)")
                if difficulty == .easy {
                    expect(rules.isDisjoint(with: [.ascension, .descension, .fallenAce]), "Baby Bee never rolls the brutal rules: \(rules)")
                }
                let hasSuitRule = rules.contains(.ascension) || rules.contains(.descension)
                expect(vm.ascensionDescensionSuits.count == (hasSuitRule ? 1 : 0), "A suit is rolled exactly when Pollination/Smoked Out is")
                if !rules.isEmpty { sawRules = true }
            }
            expect(sawRules, "The roulette does roll rules (\(difficulty))")
        }
    }

    static func testBanningNormalModeAlwaysRollsAtLeastOneRule() {
        for difficulty in HoneycombDifficulty.allCases {
            let vm = vmWith(difficulty: difficulty, banned: ["Normal Mode"])
            for _ in 0..<samples(difficulty, cheap: 80, deep: 10) {
                vm.startNewGame()
                expect(!vm.activeRules.isEmpty, "With Normal Mode banned a match always has a rule (\(difficulty))")
            }
        }
    }

    static func testRouletteWithOneRuleLeftOnlyUsesThatRule() {
        let others = Set(HoneycombRule.allCases.filter { $0 != .plus }.map { $0.rawValue })
        let vm = vmWith(difficulty: .hard, banned: others)
        var sawPlus = false
        for _ in 0..<12 {
            vm.startNewGame()
            expect(Set(vm.activeRules).isSubset(of: [.plus]) && vm.activeRules.count <= 1, "Only Math Bee (or Normal) can roll: \(vm.activeRules)")
            if vm.activeRules == [.plus] { sawPlus = true }
        }
        expect(sawPlus, "Math Bee does come up")
    }

    static func testOpponentDeckStarsPerDifficulty() {
        // Hierarchy has no effect on the deck; Swap and Inversion are avoided/handled below.
        func stars(_ difficulty: HoneycombDifficulty, _ rules: Set<HoneycombRule>) -> [[Int]] {
            let vm = vmWith(difficulty: difficulty, picked: rules)
            return (0..<samples(difficulty, cheap: 25, deep: 4)).map { _ in
                vm.startNewGame()
                let deal = opponentDeal(vm)
                expect(deal.count == 5, "The opponent is dealt five cards (\(difficulty))")
                return deal.map { $0.stars }.sorted()
            }
        }
        expect(stars(.easy, [.order]).allSatisfy { $0 == [1, 1, 1, 2, 2] || $0 == [1, 1, 1, 2, 3] }, "Baby Bee: three 1★, a 2★ and a 2★ or 3★")
        expect(stars(.medium, [.order]).allSatisfy { $0 == [2, 2, 2, 2, 3] || $0 == [2, 2, 2, 2, 4] }, "Honey Bee: four 2★ and a 3★ or 4★")
        expect(stars(.hard, [.order]).allSatisfy { $0 == [3, 3, 3, 4, 5] }, "Hard: three 3★, a 4★ and a 5★")
        expect(stars(.ultraHard, [.order]).allSatisfy { $0 == [3, 3, 4, 5, 5] }, "Ultra Hard: two 3★, a 4★ and two 5★")
        // Under Inversion (low stats win) the strong tiers are the LOW ones.
        expect(stars(.hard, [.reverse]).allSatisfy { $0 == [1, 1, 2, 2, 2] }, "Hard under Inversion: two 1★ and three 2★")
        expect(stars(.ultraHard, [.reverse]).allSatisfy { $0 == [1, 1, 1, 1, 1] }, "Ultra Hard under Inversion: five 1★")
        expect(stars(.easy, [.reverse]).allSatisfy { $0 == [1, 1, 1, 2, 2] || $0 == [1, 1, 1, 2, 3] }, "Baby Bee keeps its own deck under Inversion")
    }

    static func testUltraHardGuaranteesThreePollinationSuitCards() {
        let vm = vmWith(difficulty: .ultraHard, picked: [.ascension])
        for _ in 0..<8 {
            vm.startNewGame()
            let suit = vm.ascensionDescensionSuits
            expect(suit.count == 1, "Pollination has a suit")
            let matching = opponentDeal(vm).filter { suit.contains($0.suit) }.count
            expect(matching >= 3, "Ultra Hard's opponent holds at least 3 cards of the Pollination suit \(suit) (got \(matching))")
        }
    }

    static func testNoStressMatchDealsTheOverpoweredPlayerDeck() {
        let vm = vmWith(picked: [.order])
        vm.sharedOptions.noStressMode = true
        for _ in 0..<10 {
            vm.startNewGame()
            expect(vm.playerStartingDeck.map { $0.data.stars }.sorted() == [3, 3, 3, 4, 5], "No Stress Mode: one 5★, one 4★ and three 3★")
            expect(vm.playerStartingDeck.allSatisfy { $0.owner == .player }, "...all the player's")
        }
        vm.sharedOptions.noStressMode = false
    }

    static func testDifficultyIsLockedForTheMatch() {
        let vm = vmWith(difficulty: .easy, picked: [.order])
        vm.startNewGame()
        expect(vm.matchDifficulty == .easy, "The match is dealt at the picked difficulty")
        var o = vm.options
        o.difficulty = .ultraHard
        vm.options = o
        expect(vm.matchDifficulty == .easy, "Changing the picker mid-match doesn't change the match")
        vm.startNewGame()
        expect(vm.matchDifficulty == .ultraHard, "The next match uses the new difficulty")
    }

    static func testRematchReplaysTheSameDealAndRules() {
        let vm = vmWith(difficulty: .hard, picked: [.plus, .order])
        expect(!vm.canRematch, "Nothing to rematch before a match is dealt")
        vm.startNewGame()
        expect(vm.canRematch, "A dealt match can be rematched")
        let deal = Set(opponentDeal(vm).map { $0.id })
        let rules = Set(vm.activeRules)
        vm.rematch()
        expect(Set(opponentDeal(vm).map { $0.id }) == deal, "Rematch does nothing until the match is finished")
        vm.gameState = .gameOver
        vm.rematch()
        expect(Set(opponentDeal(vm).map { $0.id }) == deal, "Rematch faces the same five opponent cards")
        expect(Set(vm.activeRules) == rules, "...under the same rules")
        expect(vm.matchDifficulty == .hard, "...at the same difficulty")
    }
}
