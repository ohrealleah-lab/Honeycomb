import Foundation

// Honeycomb play on hand-built boards (headless play is synchronous, so these are exact):
// taking a card from the opponent, Steal Protection across a rematch chain, the Hint button,
// what happens on a tied board with and without Sudden Death, which plays are refused, and
// Start Over. The card bank is a shared in-memory object, so cards taken here are real cards
// from the collection and the saved lists are put back afterwards.
struct HoneycombPlayTests {
    static let defaultsKeys = [
        "honeycomb_options", "honeycomb_stats", "honeycomb_unlocked_cards", "honeycomb_saved_decks",
        "honeycomb_favorite_cards", "honeycomb_card_seed", "HoneycombFirstPlayedDate", "HoneycombHasShownOneYearBanner"
    ]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) { withCleanDefaults([], preserving: defaultsKeys, test) }
        isolated(testStealEligibilityAndTheStealFlow)
        isolated(testStealRefusals)
        isolated(testOpponentCardsRemaining)
        isolated(testStealProtectionAcrossARematchChain)
        isolated(testHintPointsAtALegalMove)
        isolated(testHintUnderOrderAndWhenUnavailable)
        isolated(testATieWithoutSuddenDeathIsADraw)
        isolated(testATieWithSuddenDeathPlaysOvertime)
        isolated(testRefusedPlays)
        isolated(testRestartDealsAFreshMatch)
    }

    /// Runs after the other suites: Start Over rerolls the whole card collection in memory.
    static func runStartOver() {
        UISound.isHeadlessMode = true
        withCleanDefaults([], preserving: defaultsKeys, testStartOverRebuildsTheProfile)
    }

    // MARK: - Fixtures

    static var nextId = 920_000

    static func card(owner: CardOwner, originalOwner: CardOwner? = nil, stats: [Int] = [10, 10, 10, 10]) -> HoneycombCard {
        nextId += 1
        let data = HoneycombCardData(id: nextId, name: "T\(nextId)", stars: 3, stats: stats, suit: "S")
        return HoneycombCard(data: data, owner: owner, originalOwner: originalOwner)
    }

    /// A real card from the collection that the player doesn't own yet.
    static func unownedRealCard(owner: CardOwner, originalOwner: CardOwner) -> HoneycombCard {
        let bank = HoneycombProfileManager.shared
        let data = HoneycombDatabase.shared.allCards.first { !bank.unlockedCardIds.contains($0.id) }!
        return HoneycombCard(data: data, owner: owner, originalOwner: originalOwner)
    }

    static func playingVM() -> HoneycombViewModel {
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = []
        vm.board = HoneycombBoard()
        vm.playerHand = []
        vm.opponentHand = []
        return vm
    }

    /// 8 unbeatable cards for the player plus one weak card to play last: an exact 9–0 win.
    static func forceWin(_ vm: HoneycombViewModel, playerOwned: [HoneycombCard]? = nil) {
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = []
        var board = HoneycombBoard()
        let fortress = playerOwned ?? (0..<8).map { _ in card(owner: .player) }
        for (i, c) in fortress.enumerated() { board.cells[i].card = c }
        vm.board = board
        vm.playerHand = [card(owner: .player, stats: [1, 1, 1, 1])]
        vm.opponentHand = []
        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)
    }

    // MARK: - Taking a card

    static func testStealEligibilityAndTheStealFlow() {
        let bank = HoneycombProfileManager.shared
        let vm = playingVM()
        let captured = unownedRealCard(owner: .player, originalOwner: .opponent)
        let own = card(owner: .player)
        let held = card(owner: .opponent)
        vm.board.cells[0].card = captured
        vm.board.cells[1].card = own
        vm.board.cells[2].card = held

        expect(vm.isStealEligible(captured), "A card the opponent played and you captured is takeable")
        expect(!vm.isStealEligible(own), "Your own card isn't")
        expect(!vm.isStealEligible(held), "A card the opponent still holds isn't")
        expect(vm.hasStealableCard, "The board has something to take")

        vm.requestSteal(boardIndex: 0)
        expect(vm.pendingSteal == HoneycombViewModel.PendingSteal(boardIndex: 0, cardName: captured.data.name), "Asking stages the steal with the card's name")
        vm.cancelPendingSteal()
        expect(vm.pendingSteal == nil && !bank.unlockedCardIds.contains(captured.data.id), "Cancelling takes nothing")

        let before = vm.stats.cardsStolen
        vm.requestSteal(boardIndex: 0)
        vm.confirmPendingSteal()
        expect(vm.pendingSteal == nil, "Confirming clears the request")
        expect(bank.unlockedCardIds.contains(captured.data.id), "The card goes into your collection")
        expect(vm.stats.cardsStolen == before + 1 && vm.hasStolenThisMatch, "It's counted, and that's your one steal this match")
        expect((UserDefaults.standard.array(forKey: "honeycomb_unlocked_cards") as? [Int])?.contains(captured.data.id) == true, "…and saved")
        expect(!vm.isStealEligible(captured), "Once you own it, it can't be taken again")
        expect(!vm.hasStealableCard, "…so nothing is left to take")

        let second = unownedRealCard(owner: .player, originalOwner: .opponent)
        vm.board.cells[3].card = second
        vm.requestSteal(boardIndex: 3)
        expect(vm.pendingSteal == nil, "One steal per match")

        // takeCard asks and confirms in one go.
        let fresh = playingVM()
        let target = unownedRealCard(owner: .player, originalOwner: .opponent)
        fresh.board.cells[4].card = target
        fresh.takeCard(boardIndex: 4)
        expect(bank.unlockedCardIds.contains(target.data.id) && fresh.hasStolenThisMatch, "takeCard takes it straight away")
    }

    static func testStealRefusals() {
        let bank = HoneycombProfileManager.shared
        let vm = playingVM()
        let own = card(owner: .player)
        let held = card(owner: .opponent)
        vm.board.cells[0].card = own
        vm.board.cells[1].card = held
        vm.requestSteal(boardIndex: 0)
        expect(vm.pendingSteal == nil, "Your own card can't be taken")
        vm.requestSteal(boardIndex: 1)
        expect(vm.pendingSteal == nil, "A card you didn't capture can't be taken")
        vm.requestSteal(boardIndex: 5)
        expect(vm.pendingSteal == nil, "An empty cell can't be taken")
        vm.confirmPendingSteal()
        expect(!vm.hasStolenThisMatch, "Confirming with nothing staged does nothing")

        // No Stress Mode has no stealing at all.
        withCleanDefaults([], preserving: []) {
            let quiet = HoneycombViewModel()
            quiet.sharedOptions.noStressMode = true
            quiet.startNewGame()
            let target = unownedRealCard(owner: .player, originalOwner: .opponent)
            quiet.board = HoneycombBoard()
            quiet.board.cells[0].card = target
            quiet.requestSteal(boardIndex: 0)
            quiet.takeCard(boardIndex: 0)
            expect(quiet.pendingSteal == nil && !bank.unlockedCardIds.contains(target.data.id), "No Stress Mode: nothing can be taken")
        }
    }

    static func testOpponentCardsRemaining() {
        let bank = HoneycombProfileManager.shared
        let vm = HoneycombViewModel()
        expect(vm.opponentCardsRemainingCount == 0 && !vm.hasObtainedAllOpponentCards, "Before a match there's no opponent to count")
        vm.startNewGame()
        // The opponent's five cards, wherever they are now (in hand, or already played).
        let dealt = (vm.opponentHand + vm.board.cells.compactMap { $0.card }.filter { $0.originalOwner == .opponent }).map { $0.data.id }
        expect(Set(dealt).count == 5, "The opponent was dealt five different cards")
        let missing = dealt.filter { !bank.unlockedCardIds.contains($0) }.count
        expect(vm.opponentCardsRemainingCount == missing, "The count is how many of those you don't own yet (\(missing))")
        expect(vm.hasObtainedAllOpponentCards == (missing == 0), "…and 'obtained all' matches")
        for id in dealt { bank.unlockCard(id: id) }
        expect(vm.opponentCardsRemainingCount == 0 && vm.hasObtainedAllOpponentCards, "Owning all five means none remain")
    }

    static func testStealProtectionAcrossARematchChain() {
        let vm = HoneycombViewModel()
        vm.startNewGame()
        expect(!vm.stealProtectionActive, "A new opponent starts without protection")

        // Wins where nothing is takeable (every card on the board is yours): the first win is
        // the original match, so only rematch wins count.
        forceWin(vm)
        expect(vm.matchOutcome == .win && vm.canRematch, "A forced 9–0 win")
        vm.rematch()
        forceWin(vm)
        expect(!vm.stealProtectionActive, "One rematch win with nothing to take isn't enough")
        vm.rematch()
        forceWin(vm)
        expect(vm.stealProtectionActive, "Two in a row switch Steal Protection on")
        let unowned = unownedRealCard(owner: .opponent, originalOwner: .opponent)
        expect(vm.isStealEligible(unowned), "…and then any card you don't own can be taken, even one you didn't capture")
        vm.rematch()
        forceWin(vm)
        expect(vm.stealProtectionActive, "It stays on for the rest of the chain")
        vm.startNewGame()
        expect(!vm.stealProtectionActive, "A genuinely new opponent turns it off")

        // A rematch win that DID have something to take starts the count again.
        let chain = HoneycombViewModel()
        chain.startNewGame()
        forceWin(chain)
        chain.rematch()
        forceWin(chain)                                   // count 1
        chain.rematch()
        var withSteal = (0..<7).map { _ in card(owner: .player) }
        withSteal.append(unownedRealCard(owner: .player, originalOwner: .opponent))
        forceWin(chain, playerOwned: withSteal)           // something to take: count back to 0
        chain.rematch()
        forceWin(chain)                                   // count 1 again
        expect(!chain.stealProtectionActive, "A win with something to take resets the count")
        chain.rematch()
        forceWin(chain)                                   // count 2
        expect(chain.stealProtectionActive, "…and it takes two more to switch protection on")
    }

    // MARK: - Hints

    static func testHintPointsAtALegalMove() {
        let vm = playingVM()
        for i in 0..<9 where i != 4 { vm.board.cells[i].card = card(owner: i % 2 == 0 ? .player : .opponent, stats: [5, 5, 5, 5]) }
        vm.playerHand = [card(owner: .player, stats: [6, 6, 6, 6])]
        expect(vm.hasHintsAvailable, "A hint is available with a card and an empty cell")
        vm.findHint()
        expect(vm.activeHint == HoneycombViewModel.HintMove(handIndex: 0, boardIndex: 4), "It points at the only move there is")
        vm.clearHint()
        expect(vm.activeHint == nil, "Clearing removes it")
        vm.findHint()
        expect(vm.activeHint != nil, "Asking again shows it again")
        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 4)
        expect(vm.activeHint == nil, "Playing a card clears the hint")

        let open = playingVM()
        open.board.cells[0].card = card(owner: .opponent, stats: [3, 3, 3, 3])
        open.playerHand = [card(owner: .player, stats: [9, 1, 9, 1]), card(owner: .player, stats: [2, 2, 2, 2]), card(owner: .player, stats: [8, 8, 8, 8])]
        open.opponentHand = [card(owner: .opponent, stats: [5, 5, 5, 5]), card(owner: .opponent, stats: [4, 4, 4, 4])]
        open.findHint()
        if let hint = open.activeHint {
            expect((0..<3).contains(hint.handIndex) && open.board.cells[hint.boardIndex].card == nil, "A hint is a real card and an empty cell")
        } else { expect(false, "A hint is given on an open board") }
    }

    static func testHintUnderOrderAndWhenUnavailable() {
        let ordered = playingVM()
        ordered.activeRules = [.order]
        for i in 0..<9 where i != 7 { ordered.board.cells[i].card = card(owner: i % 2 == 0 ? .player : .opponent, stats: [5, 5, 5, 5]) }
        ordered.playerHand = [card(owner: .player, stats: [2, 2, 2, 2]), card(owner: .player, stats: [9, 9, 9, 9])]
        ordered.findHint()
        expect(ordered.activeHint?.handIndex == 0, "Under Hierarchy the hint is always the first card")

        let notYourTurn = playingVM()
        notYourTurn.playerHand = [card(owner: .player)]
        notYourTurn.isPlayerTurn = false
        expect(!notYourTurn.hasHintsAvailable, "No hint on the opponent's turn")
        notYourTurn.findHint()
        expect(notYourTurn.activeHint == nil, "…and asking shows nothing")

        let noCards = playingVM()
        expect(!noCards.hasHintsAvailable, "No hint with no cards in hand")

        let full = playingVM()
        for i in 0..<9 { full.board.cells[i].card = card(owner: .player) }
        full.playerHand = [card(owner: .player)]
        expect(!full.hasHintsAvailable, "No hint on a full board")

        let over = playingVM()
        over.playerHand = [card(owner: .player)]
        over.gameState = .gameOver
        expect(!over.hasHintsAvailable, "No hint once the match is over")
    }

    // MARK: - Ties

    /// Board filled to 4 each by unbeatable cards, then each side has one weak card left:
    /// the last card makes it 5–5.
    static func tiedBoardMatch(rules: [HoneycombRule]) -> HoneycombViewModel {
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = rules
        var board = HoneycombBoard()
        for i in 0..<4 { board.cells[i].card = card(owner: .player) }
        for i in 4..<8 { board.cells[i].card = card(owner: .opponent) }
        vm.board = board
        vm.playerHand = [card(owner: .player, stats: [1, 1, 1, 1])]
        vm.opponentHand = [card(owner: .opponent, stats: [1, 1, 1, 1])]
        vm.stats = HoneycombStats()
        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)
        return vm
    }

    static func testATieWithoutSuddenDeathIsADraw() {
        let vm = tiedBoardMatch(rules: [])
        expect(vm.matchOutcome == .tie && vm.gameState == .gameOver, "A tie is a final result when Sudden Death isn't on")
        expect(vm.stats.matchesDrawn == 1 && vm.stats.gamesPlayed == 1 && vm.stats.matchesWon == 0 && vm.stats.matchesLost == 0, "It's recorded as a draw")
        expect(vm.stats.currentWinStreak == 0, "A draw doesn't build a win streak")
        expect(vm.showPostGamePrompt, "The result is shown")
    }

    static func testATieWithSuddenDeathPlaysOvertime() {
        let vm = tiedBoardMatch(rules: [.suddenDeath])
        expect(vm.matchOutcome == .suddenDeathPending && vm.gameState == .suddenDeath, "A tie with Swarm to the Death goes to overtime")
        expect(vm.stats.gamesPlayed == 0 && vm.stats.matchesDrawn == 0, "Nothing is recorded yet — overtime decides it")
        pumpRunLoop(timeout: 4) { vm.gameState == .playing }
        expect(vm.gameState == .playing, "After a pause the tie-break starts")
        expect(vm.stats.suddenDeathCount == 1, "The overtime is counted")
        // Overtime starts on the opponent's turn (it alternates), so its opening card is already down.
        let onBoard = vm.board.cells.compactMap { $0.card }
        expect(onBoard.count <= 1, "On a fresh board — at most the opponent's opening card is down (\(onBoard.count))")
        expect(vm.playerHand.count + vm.opponentHand.count + onBoard.count == 10, "All ten cards are back in play (\(vm.playerHand.count) + \(vm.opponentHand.count) + \(onBoard.count))")
        expect(vm.playerHand.count == 5 && vm.opponentHand.count + onBoard.count == 5, "Five each")
        expect(vm.playerHand.allSatisfy { $0.owner == .player } && vm.opponentHand.allSatisfy { $0.owner == .opponent }, "Each hand holds only its own side's cards")
        expect(vm.playerHand.allSatisfy { $0.modifier == 0 && !$0.isFaceDown }, "Cards come back face up with no leftover boosts")
    }

    // MARK: - Refused plays

    static func testRefusedPlays() {
        let vm = playingVM()
        vm.playerHand = [card(owner: .player), card(owner: .player)]
        vm.board.cells[3].card = card(owner: .opponent)

        expect(!vm.playerPlayCard(handIndex: 0, boardIndex: 3), "A cell that's taken is refused")
        expect(!vm.playerPlayCard(handIndex: 5, boardIndex: 0) && !vm.playerPlayCard(handIndex: -1, boardIndex: 0), "A card that isn't in your hand is refused")
        vm.isPlayerTurn = false
        expect(!vm.playerPlayCard(handIndex: 0, boardIndex: 0), "Not your turn")
        vm.isPlayerTurn = true
        vm.gameState = .gameOver
        expect(!vm.playerPlayCard(handIndex: 0, boardIndex: 0), "The match is over")
        vm.gameState = .setup
        expect(!vm.playerPlayCard(handIndex: 0, boardIndex: 0), "No match started")
        expect(vm.playerHand.count == 2, "Refused plays use no cards")

        vm.gameState = .playing
        vm.activeRules = [.order]
        expect(vm.mandatedPlayerHandIndex == 0, "Hierarchy mandates the first card")
        expect(!vm.playerPlayCard(handIndex: 1, boardIndex: 0), "Playing the second card under Hierarchy is refused")
        expect(vm.playerPlayCard(handIndex: 0, boardIndex: 0), "Playing the first card is allowed")
    }

    static func testRestartDealsAFreshMatch() {
        let vm = HoneycombViewModel()
        vm.stats = HoneycombStats()
        vm.gameState = .gameOver
        vm.restartCurrentGame()
        expect(vm.gameState == .playing, "Restart deals a new match")
        let playerCards = vm.playerHand.count + vm.board.cells.compactMap { $0.card }.filter { $0.originalOwner == .player }.count
        expect(playerCards == 5, "…with five cards for you")
        vm.quitMatch()
        expect(vm.gameState == .setup && vm.board.cells.allSatisfy { $0.card == nil }, "Quitting clears the board and goes back to setup")
    }

    // MARK: - Start Over

    static func testStartOverRebuildsTheProfile() {
        let vm = HoneycombViewModel()
        vm.stats = HoneycombStats()
        var o = vm.options
        o.activeDeckIndex = 3
        vm.options = o
        let before = vm.stats.timesStartedOver
        vm.startOver()
        expect(vm.options.activeDeckIndex == 0, "Deck 1 becomes the active deck")
        expect(vm.stats.timesStartedOver == before + 1, "Starting over is counted")
        expect(HoneycombProfileManager.shared.savedDecks[0].name == "Default", "Deck 1 is renamed Default")
        expect(HoneycombProfileManager.shared.savedDecks[1...].allSatisfy { $0.cardIds.isEmpty }, "Every other deck is wiped")
        expect(HoneycombProfileManager.shared.unlockedCardIds == Set(HoneycombProfileManager.shared.savedDecks[0].cardIds), "The collection is just Deck 1's cards")
        let saved = UserDefaults.standard.data(forKey: "honeycomb_stats").flatMap { try? JSONDecoder().decode(HoneycombStats.self, from: $0) }
        expect(saved?.timesStartedOver == before + 1, "…and it's saved")
    }
}
