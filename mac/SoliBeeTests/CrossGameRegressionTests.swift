import Foundation

// Regression coverage replaying the exact sequence from a real bug report: win some
// Klondike games, play several Honeycomb matches with Bomb Shelter active (some ending
// in a steal, some not), then switch to Beecell and confirm ordinary alternating-color
// tableau stacking still works. The original report turned out to trace to a game-
// switch/settings bug (see AppCoordinatorTests.testSoundAndNoStressModeAreAppWide), not
// Beecell's move validation itself — this test exists so any future regression in
// *either* area gets caught by actually driving the cross-game sequence, not just by
// reasoning about the code in isolation.
struct CrossGameRegressionTests {
    static func run() {
        testKlondikeWinsThenHoneycombBombShelterThenBeecellStacking()
    }

    static func testKlondikeWinsThenHoneycombBombShelterThenBeecellStacking() {
        UISound.isHeadlessMode = true

        // This test exercises Honeycomb's real steal flow, which writes into the actual
        // persisted card-bank profile (HoneycombProfileManager) — save/restore the
        // UserDefaults key around the test so it doesn't leave stray unlocked cards
        // behind for a real user's save data or a later test run.
        let unlockedKey = "honeycomb_unlocked_cards"
        let savedUnlocked = UserDefaults.standard.array(forKey: unlockedKey)
        defer {
            if let savedUnlocked {
                UserDefaults.standard.set(savedUnlocked, forKey: unlockedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: unlockedKey)
            }
        }

        // Also restore whichever gameMode was persisted before this test ran — this test
        // deliberately switches through several games, and AppCoordinator persists
        // gameMode on every switch, so leaving it on Beecell would affect any later test
        // (or real app launch) that reads "selectedGameMode" fresh.
        let savedGameMode = UserDefaults.standard.object(forKey: "selectedGameMode")
        defer {
            if let savedGameMode { UserDefaults.standard.set(savedGameMode, forKey: "selectedGameMode") }
            else { UserDefaults.standard.removeObject(forKey: "selectedGameMode") }
        }

        let coordinator = AppCoordinator()

        // --- 1. Win a couple of Klondike games ---
        coordinator.gameMode = .klondike
        let kv = coordinator.klondikeViewModel
        kv.startNewGame()
        for _ in 0..<2 {
            forceKlondikeWin(kv)
            kv.startNewGame()
        }

        // --- 2. Honeycomb: play several Bomb Shelter matches, including one that ends
        // in a steal and one that doesn't ---
        coordinator.gameMode = .honeycomb
        let hc = coordinator.honeycombViewModel
        let savedHoneycombOptions = hc.options
        defer { hc.options = savedHoneycombOptions }

        hc.options.forceNormalMode = false
        hc.options.selectedRules = [.bombShelter]

        // First match: play a real Bomb Shelter match to completion (exercises the
        // actual placement/reveal/banner machinery), regardless of outcome — this is
        // the "several games of Honeycomb" part of the original report.
        hc.startNewGame()
        playHoneycombMatchToCompletion(hc)
        guard hc.gameState == .gameOver else {
            fatalError("❌ CrossGameRegressionTests: first Honeycomb match never reached gameOver")
        }

        // Second: force a winning, stealable board directly rather than hoping a naive
        // "always play hand[0] onto the first empty cell" auto-play happens to end in a
        // win with a stealable card — that combination is too rare to rely on within a
        // reasonable retry budget. This still exercises the real requestSteal/
        // confirmPendingSteal API surface and its effect on hasStolenThisMatch/the real
        // persisted card-bank profile, which is what this test cares about.
        hc.startNewGame()
        forceHoneycombWinWithStealableCard(hc)
        guard hc.hasStealableCard else {
            fatalError("❌ CrossGameRegressionTests: forced win board wasn't actually stealable")
        }
        guard let idx = hc.board.cells.firstIndex(where: { cell in
            guard let c = cell.card else { return false }
            return c.originalOwner == .opponent && c.owner == .player
        }) else {
            fatalError("❌ CrossGameRegressionTests: couldn't find the forced stealable cell")
        }
        hc.requestSteal(boardIndex: idx)
        hc.confirmPendingSteal()
        guard hc.hasStolenThisMatch else {
            fatalError("❌ CrossGameRegressionTests: steal didn't register (hasStolenThisMatch still false)")
        }

        // Third: one more real full match, deliberately not stealing even if eligible.
        hc.startNewGame()
        playHoneycombMatchToCompletion(hc)
        guard hc.gameState == .gameOver else {
            fatalError("❌ CrossGameRegressionTests: third Honeycomb match never reached gameOver")
        }

        // --- 3. Switch to Beecell (FreeCell) and confirm ordinary alternating-color
        // stacking still works, in both directions, exactly as reported ---
        coordinator.gameMode = .beecell
        let bc = coordinator.beecellViewModel
        guard bc.state.tableau.count >= 4 else {
            fatalError("❌ CrossGameRegressionTests: expected at least 4 Beecell tableau columns")
        }

        let blackEight = Card(suit: .spades, rank: 8, faceUp: true)
        let redSeven = Card(suit: .hearts, rank: 7, faceUp: true)
        bc.state.tableau[0].cards = [blackEight]
        bc.state.tableau[1].cards = [redSeven]
        guard bc.isValidMove(cards: [redSeven], to: bc.state.tableau[0]) else {
            fatalError("❌ CrossGameRegressionTests: REGRESSION — red 7 onto black 8 rejected after Klondike wins + Honeycomb Bomb Shelter/steal + game switch")
        }
        bc.moveCards([redSeven], from: bc.state.tableau[1], to: bc.state.tableau[0])
        guard bc.state.tableau[0].cards.map(\.rank) == [8, 7] else {
            fatalError("❌ CrossGameRegressionTests: red-on-black move didn't actually apply")
        }

        let blackSix = Card(suit: .clubs, rank: 6, faceUp: true)
        let redSevenAgain = Card(suit: .diamonds, rank: 7, faceUp: true)
        bc.state.tableau[2].cards = [blackSix]
        bc.state.tableau[3].cards = [redSevenAgain]
        guard bc.isValidMove(cards: [blackSix], to: bc.state.tableau[3]) else {
            fatalError("❌ CrossGameRegressionTests: REGRESSION — black 6 onto red 7 rejected after Klondike wins + Honeycomb Bomb Shelter/steal + game switch")
        }
        bc.moveCards([blackSix], from: bc.state.tableau[2], to: bc.state.tableau[3])
        guard bc.state.tableau[3].cards.map(\.rank) == [7, 6] else {
            fatalError("❌ CrossGameRegressionTests: black-on-red move didn't actually apply")
        }
    }

    private static func forceKlondikeWin(_ vm: GameViewModel) {
        let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
        vm.state.foundations = suits.map { suit in
            Pile(id: "foundation_\(suit.rawValue)", type: .foundation, cards: (1...13).map { Card(suit: suit, rank: $0, faceUp: true) })
        }
        vm.state.hasWon = true
    }

    // Directly builds a full, won board with one stealable (originally-opponent,
    // currently player-owned) card, and clears both hands — bypasses actually playing
    // the match out, since we only need this specific shape to exercise the steal API,
    // not to test how a win gets reached (that's what the real-play matches above do).
    private static func forceHoneycombWinWithStealableCard(_ hc: HoneycombViewModel) {
        var board = HoneycombBoard()
        let playerCardData = HoneycombCardData(id: 9001, name: "Forced Player Card", stars: 3, stats: [5, 5, 5, 5], suit: "S")
        let stolenCardData = HoneycombCardData(id: 9002, name: "Forced Stealable Card", stars: 3, stats: [5, 5, 5, 5], suit: "H")

        board.cells[0].card = HoneycombCard(data: stolenCardData, owner: .player, originalOwner: .opponent)
        for i in 1..<9 {
            board.cells[i].card = HoneycombCard(data: playerCardData, owner: .player, originalOwner: .player)
        }

        hc.board = board
        hc.playerHand = []
        hc.opponentHand = []
        hc.matchResult = "You Win!"
        hc.gameState = .gameOver
    }

    private static func playHoneycombMatchToCompletion(_ hc: HoneycombViewModel) {
        var guardCount = 0
        while (hc.gameState == .playing || hc.gameState == .suddenDeath) && guardCount < 20 {
            guardCount += 1
            guard hc.isPlayerTurn, !hc.playerHand.isEmpty,
                  let boardIdx = hc.board.cells.firstIndex(where: { $0.card == nil }) else { break }
            let handIdx = hc.mandatedPlayerHandIndex ?? 0
            _ = hc.playerPlayCard(handIndex: min(handIdx, hc.playerHand.count - 1), boardIndex: boardIdx)

            // Bomb Shelter's end-of-match reveal (revealBombSheltersAndSettle) always
            // uses real DispatchQueue.main.asyncAfter delays, even in headless mode —
            // this bare test-runner process never otherwise spins a run loop, so those
            // callbacks would sit queued forever. Pump the run loop briefly to give them
            // a chance to fire instead of looping forever waiting for a gameState change
            // that can't happen without it.
            if hc.board.isFull && hc.gameState != .gameOver {
                RunLoop.main.run(until: Date().addingTimeInterval(3.5))
            }
        }
    }
}
