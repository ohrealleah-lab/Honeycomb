import Foundation

struct SmartDropTests {
    static func run() {
        testResolveReturnsFullStackWhenValid()
        testResolveTrimsGrabbedEndUntilValid()
        testResolveReturnsNilWhenNoSuffixValid()
        testKlondikeSmartDropTrimsExtraCard()
        testBeecellSmartDropTrimsExtraCard()
        testSpiderSmartDropRequiresSameSuitRun()
    }

    static func testResolveReturnsFullStackWhenValid() {
        let cards = [
            Card(suit: .hearts, rank: 9, faceUp: true),
            Card(suit: .clubs, rank: 8, faceUp: true),
        ]
        let resolved = SmartDrop.resolve(cards: cards, isValidMove: { $0.count == 2 })
        assert(resolved?.count == 2, "A fully valid stack should be returned unmodified")
    }

    static func testResolveTrimsGrabbedEndUntilValid() {
        // [10♠, 9♥, 8♣, 7♦] — only the [9♥, 8♣, 7♦] suffix is "valid" per this stub check.
        let cards = [
            Card(suit: .spades, rank: 10, faceUp: true),
            Card(suit: .hearts, rank: 9, faceUp: true),
            Card(suit: .clubs, rank: 8, faceUp: true),
            Card(suit: .diamonds, rank: 7, faceUp: true),
        ]
        let resolved = SmartDrop.resolve(cards: cards, isValidMove: { $0.first?.rank == 9 })
        assert(resolved?.count == 3, "Should trim the leading 10♠ and return the 3-card suffix")
        assert(resolved?.first?.rank == 9, "Resolved suffix should start at the 9")
    }

    static func testResolveReturnsNilWhenNoSuffixValid() {
        let cards = [
            Card(suit: .spades, rank: 10, faceUp: true),
            Card(suit: .hearts, rank: 9, faceUp: true),
        ]
        let resolved = SmartDrop.resolve(cards: cards, isValidMove: { _ in false })
        assert(resolved == nil, "Should return nil when no suffix, including the single last card, is valid")
    }

    static func testKlondikeSmartDropTrimsExtraCard() {
        let viewModel = GameViewModel()
        let target = Pile(id: "tab_target", type: .tableau, cards: [Card(suit: .clubs, rank: 10, faceUp: true)])

        // A genuine accidental over-grab: [10♠, 9♥, 8♣, 7♦], where 10♠ on 10♣ is illegal
        // but 9♥ on 10♣ is legal.
        let dragged = [
            Card(suit: .spades, rank: 10, faceUp: true),
            Card(suit: .hearts, rank: 9, faceUp: true),
            Card(suit: .clubs, rank: 8, faceUp: true),
            Card(suit: .diamonds, rank: 7, faceUp: true),
        ]

        assert(!viewModel.isValidMove(cards: dragged, to: target), "Whole 4-card stack should not fit on the 10♣")

        let resolved = SmartDrop.resolve(cards: dragged, isValidMove: { viewModel.isValidMove(cards: $0, to: target) })
        assert(resolved?.count == 3, "Smart Drop should peel off the leading 10♠ and move the remaining 3 cards")
        assert(resolved?.first?.rank == 9, "The resolved sub-stack should start at the 9♥")
    }

    static func testBeecellSmartDropTrimsExtraCard() {
        let viewModel = BeecellViewModel()
        let target = Pile(id: "tab_target", type: .tableau, cards: [Card(suit: .clubs, rank: 10, faceUp: true)])

        let dragged = [
            Card(suit: .spades, rank: 10, faceUp: true),
            Card(suit: .hearts, rank: 9, faceUp: true),
            Card(suit: .clubs, rank: 8, faceUp: true),
        ]

        assert(!viewModel.isValidMove(cards: dragged, to: target), "Whole 3-card stack should not fit on the 10♣")

        let resolved = SmartDrop.resolve(cards: dragged, isValidMove: { viewModel.isValidMove(cards: $0, to: target) })
        assert(resolved?.count == 2, "Smart Drop should peel off the leading 10♠ and move the remaining 2 cards")
        assert(resolved?.first?.rank == 9, "The resolved sub-stack should start at the 9♥")
    }

    // Spider's isValidMove only checks the dragged group's first card against the target —
    // it does not verify the group is internally a legal same-suit run. Smart Drop's target
    // closure therefore combines isValidMove with isValidDragSequence, so a mixed-suit group
    // whose *leading* card happens to match the target rank is still correctly rejected
    // rather than wrongly accepted (which plain isValidMove alone would do).
    static func testSpiderSmartDropRequiresSameSuitRun() {
        let viewModel = SpiderViewModel()
        let target = Pile(id: "tab_target", type: .tableau, cards: [Card(suit: .spades, rank: 9, faceUp: true)])

        // 8♣ leads with the correct rank for this target (8 == 9 - 1), but 7♦ beneath it
        // breaks the same-suit run — this pair can never legally move as a group.
        let mixedSuitDrag = [
            Card(suit: .clubs, rank: 8, faceUp: true),
            Card(suit: .diamonds, rank: 7, faceUp: true),
        ]

        assert(viewModel.isValidMove(cards: mixedSuitDrag, to: target),
               "isValidMove alone only checks the leading card's rank, so it would wrongly accept this mixed-suit pair")
        assert(!viewModel.isValidDragSequence(mixedSuitDrag),
               "The pair is not a legal same-suit descending run and should never be draggable as a group")

        func accepts(_ cards: [Card]) -> Bool {
            viewModel.isValidDragSequence(cards) && viewModel.isValidMove(cards: cards, to: target)
        }

        let resolved = SmartDrop.resolve(cards: mixedSuitDrag, isValidMove: accepts)
        assert(resolved == nil, "Smart Drop must not accept any suffix of a mixed-suit run, even when isValidMove alone would")
    }
}
