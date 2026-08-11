import Foundation

// Direct unit coverage for HoneycombBoard.resolveCaptures — the capture rule engine
// (Same, Plus, Fallen Ace, Reverse, combo cascades) that every other Honeycomb test
// in this suite only exercises incidentally through full-game simulation. These tests
// build a HoneycombBoard directly and call placeCard()/revealFaceDownCard() with
// specific board shapes, asserting exactly which cells flip and which trigger flags
// fire — the kind of "place card X at Y, expect indices [a,b] to flip" assertion the
// rest of the suite never makes.
struct HoneycombCaptureRulesTests {
    static func run() {
        testBasicCaptureFlipsWeakerEnemyNeighbor()
        testCaptureRequiresEnemyOwnership()
        testSameRuleFlipsAllMatchingEnemyNeighborsAndSetsFlag()
        testSameRuleDoesNotTriggerFlagWhenAllMatchesAreOwnCards()
        testSameRuleFlipsEnemyWhenMixedWithOwnCard()
        testPlusRuleFlipsMatchingSumNeighbors()
        testSameAndPlusRequireAtLeastTwoMatches()
        testComboCascadeCountsChainCaptures()
        testFallenAceCapturesTenWithOne()
        testFallenAceBlocksNormalTenBeatsOneWin()
        testReverseRuleInvertsCaptures()
        testFaceDownNeighborIsIgnoredForCaptureAndSamePlus()
        testPlaceCardOnOccupiedCellIsNoOp()
        testPlaceCardOutOfBoundsIsNoOp()
    }

    // MARK: - Helpers

    // Board indices:
    //   0 1 2
    //   3 4 5
    //   6 7 8
    // stats are [top, right, bottom, left].
    private static func mkCard(_ id: Int, owner: CardOwner, stats: [Int], suit: String = "S") -> HoneycombCard {
        HoneycombCard(data: HoneycombCardData(id: id, name: "C\(id)", stars: 3, stats: stats, suit: suit), owner: owner)
    }

    // MARK: - Baseline capture (no special rules)

    static func testBasicCaptureFlipsWeakerEnemyNeighbor() {
        var board = HoneycombBoard()
        // Top neighbor: attacker's top(9) beats neighbor's bottom(3) -> captured.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 3, 1])
        // Right neighbor: attacker's right(3) loses to neighbor's left(9) -> not captured.
        board.cells[5].card = mkCard(5, owner: .opponent, stats: [1, 1, 1, 9])
        let attacker = mkCard(100, owner: .player, stats: [9, 3, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [])

        guard flips == [1] else {
            fatalError("❌ HoneycombCaptureRulesTests: expected only index 1 to flip on a basic capture (got \(flips))")
        }
        guard board.cells[5].card?.owner == .opponent else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — a neighbor with a stronger facing stat got captured anyway")
        }
    }

    static func testCaptureRequiresEnemyOwnership() {
        var board = HoneycombBoard()
        // Same shape as the basic-capture test (attacker's top beats neighbor's bottom),
        // but the neighbor is owned by the SAME side as the attacker — must never flip.
        board.cells[1].card = mkCard(1, owner: .player, stats: [1, 1, 3, 1])
        let attacker = mkCard(100, owner: .player, stats: [9, 1, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [])

        guard flips.isEmpty else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — placing next to your own weaker card captured it (flips: \(flips))")
        }
    }

    // MARK: - Same rule

    static func testSameRuleFlipsAllMatchingEnemyNeighborsAndSetsFlag() {
        var board = HoneycombBoard()
        // Top neighbor's bottom(5) matches attacker's top(5); right neighbor's left(5)
        // matches attacker's right(5) — 2 matches, both enemy-owned, Same should flip both.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 5, 1])
        board.cells[5].card = mkCard(5, owner: .opponent, stats: [1, 1, 1, 5])
        let attacker = mkCard(100, owner: .player, stats: [5, 5, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.same])

        guard Set(flips) == [1, 5] else {
            fatalError("❌ HoneycombCaptureRulesTests: Same rule didn't flip both matching enemy neighbors (got \(flips))")
        }
        guard board.lastSameTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: lastSameTriggered was false after a real Same capture")
        }
        guard board.sessionSamePlusTriggers == 1 else {
            fatalError("❌ HoneycombCaptureRulesTests: sessionSamePlusTriggers didn't increment for a real Same capture (got \(board.sessionSamePlusTriggers))")
        }
    }

    static func testSameRuleDoesNotTriggerFlagWhenAllMatchesAreOwnCards() {
        var board = HoneycombBoard()
        // Both matching neighbors already belong to the attacker's own side — nothing
        // should flip (there's no enemy to capture), and the trigger flag/session count
        // must NOT fire since nothing actually happened.
        board.cells[1].card = mkCard(1, owner: .player, stats: [1, 1, 5, 1])
        board.cells[5].card = mkCard(5, owner: .player, stats: [1, 1, 1, 5])
        let attacker = mkCard(100, owner: .player, stats: [5, 5, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.same])

        guard flips.isEmpty else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — Same rule flipped cards that already belonged to the attacker (flips: \(flips))")
        }
        guard !board.lastSameTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — lastSameTriggered fired even though every matched neighbor was already the attacker's own")
        }
        guard board.sessionSamePlusTriggers == 0 else {
            fatalError("❌ HoneycombCaptureRulesTests: sessionSamePlusTriggers incremented for a no-op Same match (got \(board.sessionSamePlusTriggers))")
        }
    }

    static func testSameRuleFlipsEnemyWhenMixedWithOwnCard() {
        var board = HoneycombBoard()
        // One matching neighbor is the attacker's own, the other is an enemy — still 2
        // total matches, so Same fires; only the enemy-owned one should actually flip.
        board.cells[1].card = mkCard(1, owner: .player, stats: [1, 1, 5, 1])
        board.cells[5].card = mkCard(5, owner: .opponent, stats: [1, 1, 1, 5])
        let attacker = mkCard(100, owner: .player, stats: [5, 5, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.same])

        guard flips == [5] else {
            fatalError("❌ HoneycombCaptureRulesTests: mixed own/enemy Same match should flip only the enemy card (got \(flips))")
        }
        guard board.lastSameTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: lastSameTriggered was false even though an enemy card was actually captured via Same")
        }
    }

    // MARK: - Plus rule

    static func testPlusRuleFlipsMatchingSumNeighbors() {
        var board = HoneycombBoard()
        // attacker.top(6) + neighbor.bottom(2) == 8; attacker.right(4) + neighbor.left(4) == 8.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 2, 1])
        board.cells[5].card = mkCard(5, owner: .opponent, stats: [1, 1, 1, 4])
        let attacker = mkCard(100, owner: .player, stats: [6, 4, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.plus])

        guard Set(flips) == [1, 5] else {
            fatalError("❌ HoneycombCaptureRulesTests: Plus rule didn't flip both matching-sum enemy neighbors (got \(flips))")
        }
        guard board.lastPlusTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: lastPlusTriggered was false after a real Plus capture")
        }
    }

    static func testSameAndPlusRequireAtLeastTwoMatches() {
        var board = HoneycombBoard()
        // Only one neighbor placed, with a stat exactly equal to the attacker's (a Same
        // match) but a single match never triggers Same/Plus, and equal stats don't win
        // a normal capture either (attacker needs to be strictly greater) — nothing
        // should flip.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 5, 1])
        let attacker = mkCard(100, owner: .player, stats: [5, 1, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.same, .plus])

        guard flips.isEmpty else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — a single Same/Plus match flipped a card without a 2nd match (flips: \(flips))")
        }
        guard !board.lastSameTriggered, !board.lastPlusTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: Same/Plus trigger flags fired with only a single match")
        }
    }

    // MARK: - Combo cascade

    static func testComboCascadeCountsChainCaptures() {
        var board = HoneycombBoard()
        // Same triggers on the top and left neighbors (indices 1 and 3). The top
        // neighbor (index 1), once flipped to the attacker's side, then captures ITS
        // own right neighbor (index 2) via a normal (non-Same) capture — a genuine
        // combo chain reaction, not a top-level Same/Plus event.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 9, 5, 1]) // right=9 attacks index 2 next
        board.cells[3].card = mkCard(3, owner: .opponent, stats: [1, 5, 1, 1])
        board.cells[2].card = mkCard(2, owner: .opponent, stats: [1, 1, 1, 1]) // left=1, loses to index 1's right=9
        let attacker = mkCard(100, owner: .player, stats: [5, 1, 1, 5])

        let flips = board.placeCard(attacker, at: 4, rules: [.same])

        guard Set(flips) == [1, 2, 3] else {
            fatalError("❌ HoneycombCaptureRulesTests: combo cascade didn't flip the expected [1, 2, 3] (got \(flips))")
        }
        guard board.lastComboFlipCount == 1 else {
            fatalError("❌ HoneycombCaptureRulesTests: lastComboFlipCount should count exactly the 1 chain-reaction capture (index 2), got \(board.lastComboFlipCount)")
        }
        guard board.sessionSamePlusTriggers == 1 else {
            fatalError("❌ HoneycombCaptureRulesTests: sessionSamePlusTriggers should count the single top-level Same event, not each combo flip (got \(board.sessionSamePlusTriggers))")
        }
    }

    // MARK: - Fallen Ace

    static func testFallenAceCapturesTenWithOne() {
        var board = HoneycombBoard()
        // Neighbor's bottom stat is 10 ("A"); attacker's top is 1. A plain comparison
        // would lose (1 < 10), but Fallen Ace's exception always lets a 1 topple a 10.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 10, 1])
        let attacker = mkCard(100, owner: .player, stats: [1, 1, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.fallenAce])

        guard flips == [1] else {
            fatalError("❌ HoneycombCaptureRulesTests: Fallen Ace didn't let a 1 capture a 10 (flips: \(flips))")
        }
        guard board.lastFallenAceTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: lastFallenAceTriggered was false after a real Fallen Ace capture")
        }
        guard board.sessionFallenAceCaptures == 1 else {
            fatalError("❌ HoneycombCaptureRulesTests: sessionFallenAceCaptures didn't increment (got \(board.sessionFallenAceCaptures))")
        }
    }

    static func testFallenAceBlocksNormalTenBeatsOneWin() {
        var board = HoneycombBoard()
        // The mirror case: attacker is a 10 attacking a 1. Fallen Ace makes this matchup
        // strictly one-directional (1 always beats 10) — the normal "10 > 1" win must be
        // blocked outright, not just skip the Fallen Ace bonus.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 1, 1])
        let attacker = mkCard(100, owner: .player, stats: [10, 1, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.fallenAce])

        guard flips.isEmpty else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — Fallen Ace didn't block a 10 from capturing a 1 (flips: \(flips))")
        }
        guard !board.lastFallenAceTriggered else {
            fatalError("❌ HoneycombCaptureRulesTests: lastFallenAceTriggered fired on a blocked (non-)capture")
        }
    }

    // MARK: - Reverse

    static func testReverseRuleInvertsCaptures() {
        var board = HoneycombBoard()
        // Under Reverse, LOWER beats higher — attacker's top(2) should now beat the
        // neighbor's bottom(8), the opposite of the normal-rules outcome.
        board.cells[1].card = mkCard(1, owner: .opponent, stats: [1, 1, 8, 1])
        let attacker = mkCard(100, owner: .player, stats: [2, 1, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.reverse])

        guard flips == [1] else {
            fatalError("❌ HoneycombCaptureRulesTests: Reverse rule didn't let a lower stat capture a higher one (flips: \(flips))")
        }
    }

    // MARK: - Face-down neighbors

    static func testFaceDownNeighborIsIgnoredForCaptureAndSamePlus() {
        var board = HoneycombBoard()
        // A face-down (Bomb Shelter) neighbor must be invisible to both normal captures
        // and Same/Plus matching — even though its stats would otherwise lose/match.
        var hidden = mkCard(1, owner: .opponent, stats: [1, 1, 1, 1])
        hidden.isFaceDown = true
        board.cells[1].card = hidden
        let attacker = mkCard(100, owner: .player, stats: [9, 1, 1, 1])

        let flips = board.placeCard(attacker, at: 4, rules: [.same, .plus])

        guard flips.isEmpty else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — a face-down neighbor was captured/considered (flips: \(flips))")
        }
        guard board.cells[1].card?.isFaceDown == true else {
            fatalError("❌ HoneycombCaptureRulesTests: face-down neighbor's state was mutated by capture resolution")
        }
    }

    // MARK: - Bounds / occupancy guards

    static func testPlaceCardOnOccupiedCellIsNoOp() {
        var board = HoneycombBoard()
        board.cells[4].card = mkCard(1, owner: .opponent, stats: [1, 1, 1, 1])
        let attacker = mkCard(100, owner: .player, stats: [9, 9, 9, 9])

        let flips = board.placeCard(attacker, at: 4, rules: [])

        guard flips.isEmpty, board.cells[4].card?.data.id == 1 else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — placeCard overwrote an already-occupied cell")
        }
    }

    static func testPlaceCardOutOfBoundsIsNoOp() {
        var board = HoneycombBoard()
        let attacker = mkCard(100, owner: .player, stats: [9, 9, 9, 9])

        let flips = board.placeCard(attacker, at: 9, rules: [])

        guard flips.isEmpty else {
            fatalError("❌ HoneycombCaptureRulesTests: REGRESSION — placeCard didn't no-op for an out-of-bounds index")
        }
    }
}
