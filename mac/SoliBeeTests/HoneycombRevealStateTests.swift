import Foundation

// Deal-flip reveal state lives in HoneycombViewModel, keyed by card id (not a positional
// array in each platform's view), so it can't fall out of sync with the hands.
struct HoneycombRevealStateTests {
    static func run() {
        let statsKey = "honeycomb_stats"
        let savedStats = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let savedStats { UserDefaults.standard.set(savedStats, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        testSetupIsAlwaysUnrevealed()
        testNewGameSeedsUnrevealedCardsAndBumpsToken()
        testRevealCardOnlyAffectsThatCard()
        testUnknownCardIdsAreRevealedByDefault()
        testQuitMatchClearsRevealStateAndBumpsToken()
        testRematchReseedsWithFreshCards()
    }

    static func testSetupIsAlwaysUnrevealed() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        guard vm.gameState == .setup, !vm.isCardRevealed("any-placeholder-id") else {
            fatalError("❌ HoneycombRevealStateTests: .setup should never report a card as revealed")
        }
    }

    static func testNewGameSeedsUnrevealedCardsAndBumpsToken() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        let tokenBefore = vm.handIdentityToken
        vm.startNewGame()
        guard vm.handIdentityToken > tokenBefore else {
            fatalError("❌ HoneycombRevealStateTests: startNewGame didn't bump handIdentityToken")
        }
        guard vm.playerHand.allSatisfy({ !vm.isCardRevealed($0.id) }) else {
            fatalError("❌ HoneycombRevealStateTests: freshly dealt player cards should start unrevealed")
        }
    }

    static func testRevealCardOnlyAffectsThatCard() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.startNewGame()
        guard let first = vm.playerHand.first, vm.playerHand.count > 1 else {
            fatalError("❌ HoneycombRevealStateTests: expected a dealt player hand")
        }
        vm.revealCard(id: first.id)
        guard vm.isCardRevealed(first.id) else {
            fatalError("❌ HoneycombRevealStateTests: revealCard didn't reveal the card")
        }
        guard vm.playerHand.dropFirst().allSatisfy({ !vm.isCardRevealed($0.id) }) else {
            fatalError("❌ HoneycombRevealStateTests: revealCard leaked to other cards")
        }
    }

    // The crash this replaces indexed a fixed-size-5 array with a hand slot; ids the
    // set has never heard of (Swap arrivals, Sudden Death rebuilds, undo restores)
    // must read as revealed instead of failing.
    static func testUnknownCardIdsAreRevealedByDefault() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.startNewGame()
        guard vm.isCardRevealed("card-that-arrived-after-the-deal") else {
            fatalError("❌ HoneycombRevealStateTests: a card not part of the deal should read as revealed")
        }
    }

    static func testQuitMatchClearsRevealStateAndBumpsToken() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.startNewGame()
        let tokenBefore = vm.handIdentityToken
        vm.quitMatch()
        guard vm.unrevealedCardIds.isEmpty, vm.handIdentityToken > tokenBefore else {
            fatalError("❌ HoneycombRevealStateTests: quitMatch should clear reveal state and bump the token so stale deal flips no-op")
        }
    }

    static func testRematchReseedsWithFreshCards() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.startNewGame()
        vm.playerHand.forEach { vm.revealCard(id: $0.id) }
        vm.gameState = .gameOver
        guard vm.canRematch else { return } // needs a genuinely-new match first; covered by the banner streak tests
        let tokenBefore = vm.handIdentityToken
        vm.rematch()
        guard vm.handIdentityToken > tokenBefore,
              vm.playerHand.allSatisfy({ !vm.isCardRevealed($0.id) }) else {
            fatalError("❌ HoneycombRevealStateTests: rematch should re-deal every card unrevealed")
        }
    }
}
