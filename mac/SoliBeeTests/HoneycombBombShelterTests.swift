import Foundation

// Regression coverage for the mid-match Bomb Shelter reveal: a fix that staged the
// reveal's flip/banner behind a short delay accidentally only committed the timer's
// countdown to `board` when a reveal *also* happened that turn — so a plain decrement
// (the overwhelmingly common case) was silently discarded every turn, and the timer
// could never actually reach zero outside of the separate end-of-match reveal path.
struct HoneycombBombShelterTests {
    static func run() {
        testTimerDecrementPersistsAndEventuallyReveals()
        testSuddenDeathRevealsEveryHiddenCardEvenWithNectarExchange()
    }

    static func testTimerDecrementPersistsAndEventuallyReveals() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.activeRules = [.bombShelter]
        vm.gameState = .playing
        vm.isPlayerTurn = true

        func mkCard(_ id: Int, owner: CardOwner, _ stats: [Int]) -> HoneycombCard {
            HoneycombCard(data: HoneycombCardData(id: id, name: "C\(id)", stars: 3, stats: stats, suit: "S"), owner: owner)
        }
        vm.playerHand = (1...5).map { mkCard($0, owner: .player, [1, 1, 1, 1]) }
        vm.opponentHand = (11...15).map { mkCard($0, owner: .opponent, [1, 1, 1, 1]) }

        // Player's first play (5 cards in hand) is treated as the Bomb Shelter
        // placement — goes face-down with a 3-turn countdown.
        vm.playerPlayCard(handIndex: 0, boardIndex: 0)
        guard let placed = vm.board.cells[0].card, placed.isFaceDown, placed.bombShelterTurnsRemaining != nil else {
            fatalError("❌ HoneycombBombShelterTests: Bomb Shelter placement didn't go face-down with a timer")
        }

        // In headless mode, playerPlayCard synchronously triggers the AI's own reply
        // turn too, so one call already advances the timer twice (the player's own
        // placement excludes itself from the tick; the AI's placement doesn't exclude
        // cell 0). The card must still be face-down with *some* remaining count > 0 —
        // the exact number only matters as "did this persist across turns instead of
        // staying frozen at its initial value," which the loop below checks directly.
        var previousRemaining = placed.bombShelterTurnsRemaining!
        var revealed = false
        for round in 1...4 {
            guard let boardIdx = vm.board.cells.firstIndex(where: { $0.card == nil }), !vm.playerHand.isEmpty else { break }
            vm.playerPlayCard(handIndex: 0, boardIndex: boardIdx)
            guard let card = vm.board.cells[0].card else {
                fatalError("❌ HoneycombBombShelterTests: Bomb Shelter card disappeared from the board")
            }
            if !card.isFaceDown {
                revealed = true
                break
            }
            guard let remaining = card.bombShelterTurnsRemaining, remaining < previousRemaining else {
                fatalError("❌ HoneycombBombShelterTests: REGRESSION — timer didn't decrement on round \(round) (stuck at \(previousRemaining)), so it can never reach zero mid-match")
            }
            previousRemaining = remaining
        }

        guard revealed else {
            fatalError("❌ HoneycombBombShelterTests: REGRESSION — Bomb Shelter card never revealed mid-match after its timer should have expired")
        }
    }

    // Capped Brood + Sudden Death (+ Nectar Exchange): the end-of-board reveal used to
    // sort hidden cards by originalOwner, so a hidden Nectar Exchange card (owned by
    // the player, originally the opponent's) collided with the opponent's own hidden
    // card — one of the two never turned over and re-entered the Sudden Death hand
    // still face-down. Every card that was visible must still be visible afterwards.
    static func testSuddenDeathRevealsEveryHiddenCardEvenWithNectarExchange() {
        UISound.isHeadlessMode = true
        let statsKey = "honeycomb_stats"
        let saved = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        let vm = HoneycombViewModel()
        vm.activeRules = [.bombShelter, .suddenDeath, .swap, .allOpen]
        vm.gameState = .playing
        vm.isPlayerTurn = true

        // Equal stats everywhere, so nothing captures and the round ends 5-5.
        func mkCard(_ id: Int, owner: CardOwner, originalOwner: CardOwner? = nil, faceDown: Bool = false) -> HoneycombCard {
            var c = HoneycombCard(data: HoneycombCardData(id: id, name: "C\(id)", stars: 3, stats: [5, 5, 5, 5], suit: "S"), owner: owner, originalOwner: originalOwner ?? owner)
            if faceDown { c.isFaceDown = true; c.bombShelterTurnsRemaining = 3 }
            return c
        }
        var board = HoneycombBoard()
        board.cells[0].card = mkCard(0, owner: .player, originalOwner: .opponent, faceDown: true) // swapped card, hidden
        for i in 1..<4 { board.cells[i].card = mkCard(i, owner: .player) }
        board.cells[4].card = mkCard(4, owner: .opponent, faceDown: true)
        for i in 5..<8 { board.cells[i].card = mkCard(i, owner: .opponent) }
        vm.board = board
        vm.playerHand = [mkCard(100, owner: .player)]
        vm.opponentHand = [mkCard(200, owner: .opponent)]
        vm.openPlayerCardIds = Set(vm.playerHand.map { $0.id })
        vm.openOpponentCardIds = Set(vm.opponentHand.map { $0.id })

        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)

        // End-of-board reveal (~3s of staged flips) + the 2.5s Sudden Death lead-in.
        let deadline = Date().addingTimeInterval(10)
        while vm.handIdentityToken == 0 || vm.playerHand.count < 5, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        guard vm.gameState == .playing, vm.playerHand.count == 5, vm.opponentHand.count == 5 else {
            fatalError("❌ HoneycombBombShelterTests: forced 5-5 Capped Brood board didn't reach Sudden Death (state=\(vm.gameState), hands=\(vm.playerHand.count)/\(vm.opponentHand.count))")
        }
        let stillHidden = (vm.playerHand + vm.opponentHand).filter { $0.isFaceDown }.map { $0.data.id }
        guard stillHidden.isEmpty else {
            fatalError("❌ HoneycombBombShelterTests: REGRESSION — card(s) \(stillHidden) went back into a Sudden Death hand still face-down")
        }
        let notOpen = vm.opponentHand.filter { !vm.isOpponentCardVisible(cardId: $0.id) }.map { $0.data.id }
            + vm.playerHand.filter { !vm.isPlayerCardVisibleToOpponent(cardId: $0.id) }.map { $0.data.id }
        guard notOpen.isEmpty, (vm.playerHand + vm.opponentHand).allSatisfy({ vm.isCardRevealed($0.id) }) else {
            fatalError("❌ HoneycombBombShelterTests: REGRESSION — previously visible card(s) \(notOpen) are hidden after Sudden Death")
        }
    }
}
