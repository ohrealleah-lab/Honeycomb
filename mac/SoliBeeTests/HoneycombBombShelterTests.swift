import Foundation

// Regression coverage for the mid-match Bomb Shelter reveal: a fix that staged the
// reveal's flip/banner behind a short delay accidentally only committed the timer's
// countdown to `board` when a reveal *also* happened that turn — so a plain decrement
// (the overwhelmingly common case) was silently discarded every turn, and the timer
// could never actually reach zero outside of the separate end-of-match reveal path.
struct HoneycombBombShelterTests {
    static func run() {
        testTimerDecrementPersistsAndEventuallyReveals()
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
}
