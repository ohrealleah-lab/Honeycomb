import Foundation

struct BeecellTests {
    static func run() {
        testBeecellAutocompleteNotAvailableAtStart()
        testBeecellAutocompleteAvailableWhenWinnable()
        testBeecellAutocompleteNotAvailableWhenBlocked()
        testBeecellAutocompleteNotAvailableWhenUnsafe()
    }
    
    static func testBeecellAutocompleteNotAvailableAtStart() {
        let viewModel = BeecellViewModel()
        // Freshly started game should not have autocomplete available
        assert(!viewModel.isAutocompleteAvailable, "Autocomplete should not be available at the start of a game")
    }
    
    static func testBeecellAutocompleteAvailableWhenWinnable() {
        let viewModel = BeecellViewModel()
        
        // 4 empty free cells
        let freeCells = [
            Pile(id: "free_0", type: .freeCell),
            Pile(id: "free_1", type: .freeCell),
            Pile(id: "free_2", type: .freeCell),
            Pile(id: "free_3", type: .freeCell)
        ]
        
        // Put Ace through Queen of all 4 suits on foundations.
        var foundations: [Pile] = []
        let suits: [Card.Suit] = [.hearts, .diamonds, .spades, .clubs]
        for (idx, suit) in suits.enumerated() {
            var cards: [Card] = []
            for rank in 1...12 {
                cards.append(Card(suit: suit, rank: rank, faceUp: true))
            }
            foundations.append(Pile(id: "fnd_\(idx)", type: .foundation, cards: cards))
        }
        
        // The remaining 4 Kings are in the tableau columns
        var tableau: [Pile] = []
        for i in 0..<8 {
            var cards: [Card] = []
            if i < 4 {
                let suit = suits[i]
                cards.append(Card(suit: suit, rank: 13, faceUp: true))
            }
            tableau.append(Pile(id: "tab_\(i)", type: .tableau, cards: cards))
        }
        
        viewModel.state = BeecellState(
            freeCells: freeCells,
            foundations: foundations,
            tableau: tableau,
            score: 0,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            hasWon: false
        )
        
        viewModel.checkAutocompleteState()
        assert(viewModel.isAutocompleteAvailable, "Autocomplete should be available when all remaining cards (the four Kings) can move to foundations")
    }
    
    static func testBeecellAutocompleteNotAvailableWhenBlocked() {
        let viewModel = BeecellViewModel()
        
        let freeCells = [
            Pile(id: "free_0", type: .freeCell),
            Pile(id: "free_1", type: .freeCell),
            Pile(id: "free_2", type: .freeCell),
            Pile(id: "free_3", type: .freeCell)
        ]
        
        // Foundations have Ace to Jack of all suits.
        var foundations: [Pile] = []
        let suits: [Card.Suit] = [.hearts, .diamonds, .spades, .clubs]
        for (idx, suit) in suits.enumerated() {
            var cards: [Card] = []
            for rank in 1...11 { // Ace to Jack
                cards.append(Card(suit: suit, rank: rank, faceUp: true))
            }
            foundations.append(Pile(id: "fnd_\(idx)", type: .foundation, cards: cards))
        }
        
        // Column 0: Queen of Hearts, then King of Hearts on top of it.
        var tableau: [Pile] = []
        let qHearts = Card(suit: .hearts, rank: 12, faceUp: true)
        let kHearts = Card(suit: .hearts, rank: 13, faceUp: true)
        tableau.append(Pile(id: "tab_0", type: .tableau, cards: [qHearts, kHearts]))
        
        // Put other Queens and Kings in other columns separately (not blocked)
        for i in 1..<4 {
            let suit = suits[i]
            let q = Card(suit: suit, rank: 12, faceUp: true)
            let k = Card(suit: suit, rank: 13, faceUp: true)
            tableau.append(Pile(id: "tab_\(i * 2 - 1)", type: .tableau, cards: [q]))
            tableau.append(Pile(id: "tab_\(i * 2)", type: .tableau, cards: [k]))
        }
        while tableau.count < 8 {
            tableau.append(Pile(id: "tab_\(tableau.count)", type: .tableau, cards: []))
        }
        
        viewModel.state = BeecellState(
            freeCells: freeCells,
            foundations: foundations,
            tableau: tableau,
            score: 0,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            hasWon: false
        )
        
        viewModel.checkAutocompleteState()
        assert(!viewModel.isAutocompleteAvailable, "Autocomplete should not be available when the Queen of Hearts is blocked by the King of Hearts")
    }
    
    static func testBeecellAutocompleteNotAvailableWhenUnsafe() {
        let viewModel = BeecellViewModel()
        
        let freeCells = [
            Pile(id: "free_0", type: .freeCell),
            Pile(id: "free_1", type: .freeCell),
            Pile(id: "free_2", type: .freeCell),
            Pile(id: "free_3", type: .freeCell)
        ]
        
        // Foundations:
        // Diamonds: Ace to 4 (Fnd index 1)
        // Spades: Ace to 6 (Fnd index 2)
        // Hearts: Ace to 3 (Fnd index 0)
        // Clubs: Ace to 4 (Fnd index 3)
        var foundations: [Pile] = []
        
        var hCards: [Card] = []
        for r in 1...3 { hCards.append(Card(suit: .hearts, rank: r, faceUp: true)) }
        foundations.append(Pile(id: "fnd_0", type: .foundation, cards: hCards))
        
        var dCards: [Card] = []
        for r in 1...4 { dCards.append(Card(suit: .diamonds, rank: r, faceUp: true)) }
        foundations.append(Pile(id: "fnd_1", type: .foundation, cards: dCards))
        
        var sCards: [Card] = []
        for r in 1...6 { sCards.append(Card(suit: .spades, rank: r, faceUp: true)) }
        foundations.append(Pile(id: "fnd_2", type: .foundation, cards: sCards))
        
        var cCards: [Card] = []
        for r in 1...4 { cCards.append(Card(suit: .clubs, rank: r, faceUp: true)) }
        foundations.append(Pile(id: "fnd_3", type: .foundation, cards: cCards))
        
        var tableau: [Pile] = []
        // Col 0: 4 of Hearts, 5 of Diamonds
        tableau.append(Pile(id: "tab_0", type: .tableau, cards: [
            Card(suit: .hearts, rank: 4, faceUp: true),
            Card(suit: .diamonds, rank: 5, faceUp: true)
        ]))
        
        // Col 1: 7 of Spades (under), 6 of Diamonds (top)
        tableau.append(Pile(id: "tab_1", type: .tableau, cards: [
            Card(suit: .spades, rank: 7, faceUp: true),
            Card(suit: .diamonds, rank: 6, faceUp: true)
        ]))
        
        // Col 2: 7 of Diamonds (top)
        tableau.append(Pile(id: "tab_2", type: .tableau, cards: [
            Card(suit: .diamonds, rank: 7, faceUp: true)
        ]))
        
        while tableau.count < 8 {
            tableau.append(Pile(id: "tab_\(tableau.count)", type: .tableau, cards: []))
        }
        
        tableau[3].cards = [Card(suit: .clubs, rank: 8, faceUp: true)]
        tableau[4].cards = [Card(suit: .clubs, rank: 9, faceUp: true)]
        
        viewModel.state = BeecellState(
            freeCells: freeCells,
            foundations: foundations,
            tableau: tableau,
            score: 0,
            movesCount: 0,
            timerSeconds: 0,
            isTimerActive: false,
            hasWon: false
        )
        
        viewModel.checkAutocompleteState()
        assert(!viewModel.isAutocompleteAvailable, "Autocomplete should not trigger when resolving the board requires unsafe moves (e.g. 7 of Diamonds when Clubs is at 4)")
    }
}
