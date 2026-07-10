import Foundation

struct GameViewModelTests {
    static func run() {
        testGameInitialization()
        testDrawCardDrawThree()
        testDrawCardDrawOne()
        testRecycleStock()
        testValidMoveTableauToTableau()
        testHintsAndAutocompleteTriggers()
        testNoMovesPossibleHint()
        testStuckDetectionRecognizesUnblockingMoves()
        testStuckDetectionIgnoresPointlessKingShuffle()
        testUndoAction()
        testZoomAndDefaultZoom()
        testGamesWonCounter()
        testGamesPlayedCounter()
        testFoundationOrder()
        testFoundationSuitRestrictions()
        testResetStatistics()
        testRestartCurrentGame()
        testHighScorePersistence()
        testCardBackThemePersistence()
        testKeyboardNavigation()
    }
    
    static func testGameInitialization() {
        let viewModel = GameViewModel()
        
        assert(viewModel.state.tableau.count == 7, "Tableau count should be 7")
        for i in 0..<7 {
            assert(viewModel.state.tableau[i].cards.count == i + 1, "Tableau \(i) should have \(i+1) cards")
            assert(viewModel.state.tableau[i].cards.last!.faceUp, "Top card of Tableau \(i) should be face-up")
            if i > 0 {
                assert(!viewModel.state.tableau[i].cards.first!.faceUp, "Bottom card of Tableau \(i) should be face-down")
            }
        }
        
        assert(viewModel.state.stock.cards.count == 24, "Stock should have 24 cards")
        assert(viewModel.state.waste.isEmpty, "Waste should be empty")
        assert(viewModel.state.foundations.count == 4, "Foundations count should be 4")
        assert(viewModel.state.foundations.allSatisfy { $0.isEmpty }, "Foundations should be empty")
    }
    
    static func testDrawCardDrawThree() {
        let viewModel = GameViewModel()
        viewModel.state.drawMode = .drawThree
        
        viewModel.drawCard()
        
        assert(viewModel.state.stock.cards.count == 21, "Stock should have 21 cards")
        assert(viewModel.state.waste.cards.count == 3, "Waste should have 3 cards")
        assert(viewModel.state.waste.cards.allSatisfy { $0.faceUp }, "Waste cards should be face-up")
    }
    
    static func testDrawCardDrawOne() {
        let viewModel = GameViewModel()
        viewModel.state.drawMode = .drawOne
        
        viewModel.drawCard()
        
        assert(viewModel.state.stock.cards.count == 23, "Stock should have 23 cards")
        assert(viewModel.state.waste.cards.count == 1, "Waste should have 1 card")
        assert(viewModel.state.waste.topCard!.faceUp, "Waste card should be face-up")
    }
    
    static func testRecycleStock() {
        let viewModel = GameViewModel()
        viewModel.state.drawMode = .drawOne
        
        for _ in 0..<24 {
            viewModel.drawCard()
        }
        
        assert(viewModel.state.stock.cards.count == 0, "Stock should be empty")
        assert(viewModel.state.waste.cards.count == 24, "Waste should have 24 cards")
        
        // Next draw should trigger recycling and immediately draw the first card
        viewModel.drawCard()
        
        assert(viewModel.state.stock.cards.count == 23, "Stock should have 23 cards after recycling & drawing")
        assert(viewModel.state.waste.cards.count == 1, "Waste should have 1 card after recycling & drawing")
    }
    
    static func testValidMoveTableauToTableau() {
        let viewModel = GameViewModel()
        
        let redSeven = Card(suit: .hearts, rank: 7, faceUp: true)
        let blackEight = Card(suit: .spades, rank: 8, faceUp: true)
        let redEight = Card(suit: .diamonds, rank: 8, faceUp: true)
        
        let targetPile = Pile(id: "tab", type: .tableau, cards: [blackEight])
        let invalidTargetPile = Pile(id: "tab2", type: .tableau, cards: [redEight])
        
        assert(viewModel.isValidMove(cards: [redSeven], to: targetPile), "Red 7 on Black 8 should be valid")
        assert(!viewModel.isValidMove(cards: [redSeven], to: invalidTargetPile), "Red 7 on Red 8 should be invalid")
    }
    
    static func testHintsAndAutocompleteTriggers() {
        let viewModel = GameViewModel()
        
        viewModel.findHint()
        assert(viewModel.activeHint != nil, "Hint should be found initially")
        
        viewModel.state.foundations[0].cards = viewModel.state.stock.cards
        viewModel.state.stock.cards.removeAll()
        viewModel.state.waste.cards.removeAll()
        
        for i in 0..<7 {
            for j in 0..<viewModel.state.tableau[i].cards.count {
                viewModel.state.tableau[i].cards[j].faceUp = true
            }
        }
        
        viewModel.checkAutocompleteState()
        assert(viewModel.isAutocompleteAvailable, "Autocomplete should be available")
    }
    
    static func testNoMovesPossibleHint() {
        let viewModel = GameViewModel()
        
        // Empty all piles so no moves are possible
        viewModel.state.stock.cards.removeAll()
        viewModel.state.waste.cards.removeAll()
        for i in 0..<7 {
            viewModel.state.tableau[i].cards.removeAll()
        }
        
        viewModel.findHint()
        assert(viewModel.activeHint != nil, "Hint should be set when blocked")
        assert(viewModel.activeHint?.description == "No such luck, friend! Try a new game!", "Should show stuck friendly message")
    }
    
    static func testStuckDetectionRecognizesUnblockingMoves() {
        let viewModel = GameViewModel()
        // Disable stock recycling (Vegas mode + draw-one caps recycles at 0) so
        // hasValidMoves() must actually reason about tableau moves instead of bailing
        // out early on "the stock can still be redealt".
        viewModel.options.isVegasScoring = true
        viewModel.state.drawMode = .drawOne
        viewModel.state.recyclesCount = 0
        viewModel.state.stock.cards.removeAll()
        viewModel.state.waste.cards.removeAll()

        // The 2 of hearts is already on the foundation, so the 3 of hearts is one move
        // from completing it — but it's sitting under the 2 of spades, and every card
        // involved is already face-up (no hidden card gets "revealed" by moving it).
        viewModel.state.foundations = [
            Pile(id: "foundation_hearts", type: .foundation, cards: [
                Card(suit: .hearts, rank: 1, faceUp: true),
                Card(suit: .hearts, rank: 2, faceUp: true)
            ]),
            Pile(id: "foundation_spades", type: .foundation),
            Pile(id: "foundation_diamonds", type: .foundation),
            Pile(id: "foundation_clubs", type: .foundation)
        ]
        viewModel.state.tableau = [
            Pile(id: "tableau_0", type: .tableau, cards: [
                Card(suit: .hearts, rank: 3, faceUp: true),
                Card(suit: .spades, rank: 2, faceUp: true)
            ]),
            Pile(id: "tableau_1", type: .tableau, cards: [
                Card(suit: .diamonds, rank: 3, faceUp: true)
            ])
        ] + (2..<7).map { Pile(id: "tableau_\($0)", type: .tableau) }

        viewModel.checkStuckState()
        assert(!viewModel.isStuck, "Moving the 2 of spades onto the 3 of diamonds frees the already-face-up 3 of hearts for the foundation — this is a real move and must not be flagged as stuck")

        // Options are persisted to UserDefaults on every assignment — restore the
        // default so later tests that construct a fresh GameViewModel() don't
        // inherit isVegasScoring=true from this test.
        viewModel.options.isVegasScoring = false
    }

    static func testStuckDetectionIgnoresPointlessKingShuffle() {
        let viewModel = GameViewModel()
        viewModel.options.isVegasScoring = true
        viewModel.state.drawMode = .drawOne
        viewModel.state.recyclesCount = 0
        viewModel.state.stock.cards.removeAll()
        viewModel.state.waste.cards.removeAll()
        viewModel.state.foundations = [
            Pile(id: "foundation_hearts", type: .foundation),
            Pile(id: "foundation_spades", type: .foundation),
            Pile(id: "foundation_diamonds", type: .foundation),
            Pile(id: "foundation_clubs", type: .foundation)
        ]

        // A lone King can always hop into an empty column, but doing so here doesn't
        // reveal anything, complete a foundation, or create any new opportunity — it
        // just swaps which column is empty. Every other exposed card is a rank that
        // fits nowhere (foundations are empty and need an Ace; no tableau top is an
        // adjacent rank/opposite color). This board is a genuine dead end.
        viewModel.state.tableau = [
            Pile(id: "tableau_0", type: .tableau, cards: [Card(suit: .clubs, rank: 13, faceUp: true)]),
            Pile(id: "tableau_1", type: .tableau, cards: []),
            Pile(id: "tableau_2", type: .tableau, cards: [Card(suit: .diamonds, rank: 9, faceUp: true)]),
            Pile(id: "tableau_3", type: .tableau, cards: [Card(suit: .clubs, rank: 9, faceUp: true)]),
            Pile(id: "tableau_4", type: .tableau, cards: [Card(suit: .spades, rank: 9, faceUp: true)]),
            Pile(id: "tableau_5", type: .tableau, cards: [Card(suit: .hearts, rank: 9, faceUp: true)]),
            Pile(id: "tableau_6", type: .tableau, cards: [Card(suit: .clubs, rank: 2, faceUp: true)])
        ]

        viewModel.checkStuckState()
        assert(viewModel.isStuck, "The only 'move' available is a lone King hopping between two empty-equivalent columns, which is not real progress — this board must be flagged as stuck")

        viewModel.options.isVegasScoring = false
    }

    static func testUndoAction() {
        let viewModel = GameViewModel()
        viewModel.state.drawMode = .drawOne
        viewModel.startNewGame()
        
        let initialStockCount = viewModel.state.stock.cards.count
        assert(viewModel.state.waste.isEmpty, "Waste should be empty initially")
        assert(!viewModel.canUndo, "Should not be able to undo initially")
        
        // Take an action: Draw card
        viewModel.drawCard()
        assert(viewModel.state.stock.cards.count == initialStockCount - 1, "Stock count should decrease")
        assert(viewModel.state.waste.cards.count == 1, "Waste should have 1 card")
        assert(viewModel.canUndo, "Should be able to undo after an action")
        
        // Undo the action
        viewModel.undoLastAction()
        assert(viewModel.state.stock.cards.count == initialStockCount, "Stock count should be restored")
        assert(viewModel.state.waste.isEmpty, "Waste should be empty again")
        assert(!viewModel.canUndo, "Should not be able to undo after restoring initial state")
    }
    
    static func testZoomAndDefaultZoom() {
        let viewModel = GameViewModel()
        
        // Save current defaults to restore later
        let originalDefault = viewModel.defaultZoomScale
        let originalZoom = viewModel.zoomScale
        
        // 1. Zoom actions
        viewModel.zoomIn()
        assert(viewModel.zoomScale > 1.0 || viewModel.zoomScale == 2.0, "Zoom in should increase scale")
        
        viewModel.zoomOut()
        assert(viewModel.zoomScale == 1.0 || viewModel.zoomScale == originalZoom, "Zoom out should decrease scale")
        
        // 2. Setting default zoom
        viewModel.zoomIn()
        viewModel.zoomIn()
        let newZoom = viewModel.zoomScale
        viewModel.makeCurrentZoomDefault()
        assert(viewModel.defaultZoomScale == newZoom, "Default zoom scale should match new zoom scale")
        
        // 3. Reset zoom
        viewModel.zoomOut()
        assert(viewModel.zoomScale != newZoom, "Zoom should have changed")
        viewModel.resetZoom()
        assert(viewModel.zoomScale == newZoom, "Reset zoom should restore default zoom scale")
        
        // Restore defaults
        viewModel.defaultZoomScale = originalDefault
        UserDefaults.standard.set(Double(originalDefault), forKey: "defaultZoomScale")
        viewModel.zoomScale = originalZoom
        UserDefaults.standard.set(Double(originalZoom), forKey: "zoomScale")
    }
    
    static func testGamesWonCounter() {
        let savedWins = UserDefaults.standard.integer(forKey: "gamesWon")
        UserDefaults.standard.set(0, forKey: "gamesWon")
        
        let viewModel = GameViewModel()
        assert(viewModel.gamesWon == 0, "gamesWon should initialize to 0")
        
        // Simulate winning
        for i in 0..<4 {
            viewModel.state.foundations[i].cards = (1...13).map { Card(suit: Card.Suit.allCases[i], rank: $0, faceUp: true) }
        }
        
        viewModel.checkWinState()
        assert(viewModel.state.hasWon, "Game should be marked as won")
        assert(viewModel.gamesWon == 1, "gamesWon count should be 1")
        
        // Creating a new viewModel should persist this value
        let nextViewModel = GameViewModel()
        assert(nextViewModel.gamesWon == 1, "gamesWon count should persist to next view model launch")
        
        // Clean up
        UserDefaults.standard.set(savedWins, forKey: "gamesWon")
    }
    
    static func testGamesPlayedCounter() {
        let savedPlayed = UserDefaults.standard.integer(forKey: "gamesPlayed")
        UserDefaults.standard.set(0, forKey: "gamesPlayed")
        
        let viewModel = GameViewModel()
        assert(viewModel.gamesPlayed == 1, "gamesPlayed should initialize to 1 on first game start")
        
        viewModel.startNewGame()
        assert(viewModel.gamesPlayed == 2, "gamesPlayed should increment to 2 on startNewGame")
        
        let nextViewModel = GameViewModel()
        assert(nextViewModel.gamesPlayed == 3, "gamesPlayed should load persisted value (2) and increment to 3 on new game start")
        
        UserDefaults.standard.set(savedPlayed, forKey: "gamesPlayed")
    }
    
    static func testFoundationOrder() {
        let viewModel = GameViewModel()
        let expectedOrder: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
        
        assert(viewModel.state.foundations.count == 4, "Should have 4 foundations")
        for i in 0..<4 {
            let foundationId = viewModel.state.foundations[i].id
            let expectedId = "foundation_\(expectedOrder[i].rawValue)"
            assert(foundationId == expectedId, "Foundation \(i) should be \(expectedId), got \(foundationId)")
        }
    }
    
    static func testFoundationSuitRestrictions() {
        let viewModel = GameViewModel()
        
        let spadeAce = Card(suit: .spades, rank: 1, faceUp: true)
        let clubAce = Card(suit: .clubs, rank: 1, faceUp: true)
        
        let spadeFoundation = viewModel.state.foundations[0]
        let clubFoundation = viewModel.state.foundations[1]
        
        assert(viewModel.isValidMove(cards: [spadeAce], to: spadeFoundation), "Spade Ace on Spade Foundation should be valid")
        assert(!viewModel.isValidMove(cards: [clubAce], to: spadeFoundation), "Club Ace on Spade Foundation should be invalid")
        
        assert(viewModel.isValidMove(cards: [clubAce], to: clubFoundation), "Club Ace on Club Foundation should be valid")
        assert(!viewModel.isValidMove(cards: [spadeAce], to: clubFoundation), "Spade Ace on Club Foundation should be invalid")
    }
    
    static func testResetStatistics() {
        let savedWins = UserDefaults.standard.integer(forKey: "gamesWon")
        let savedPlayed = UserDefaults.standard.integer(forKey: "gamesPlayed")
        
        UserDefaults.standard.set(5, forKey: "gamesWon")
        UserDefaults.standard.set(10, forKey: "gamesPlayed")
        
        let viewModel = GameViewModel()
        assert(viewModel.gamesWon == 5, "gamesWon should initialize to 5")
        assert(viewModel.gamesPlayed == 11, "gamesPlayed should initialize to 11 (+1 during setup)")
        
        viewModel.resetStatistics()
        assert(viewModel.gamesWon == 0, "gamesWon should be 0 after reset")
        assert(viewModel.gamesPlayed == 0, "gamesPlayed should be 0 after reset")
        
        let nextViewModel = GameViewModel()
        assert(nextViewModel.gamesWon == 0, "persisted gamesWon should be 0")
        assert(nextViewModel.gamesPlayed == 1, "persisted gamesPlayed should load 0 and increment to 1 on setup init")
        
        // Clean up
        UserDefaults.standard.set(savedWins, forKey: "gamesWon")
        UserDefaults.standard.set(savedPlayed, forKey: "gamesPlayed")
    }
    
    static func testRestartCurrentGame() {
        let viewModel = GameViewModel()
        viewModel.state.drawMode = .drawOne
        viewModel.startNewGame()
        
        let originalState = viewModel.state
        let originalStockCount = viewModel.state.stock.cards.count
        
        // Change game state: Draw card
        viewModel.drawCard()
        assert(viewModel.state.stock.cards.count == originalStockCount - 1, "Stock card should be drawn")
        assert(viewModel.state.movesCount == 1, "Moves count should be 1")
        assert(viewModel.canUndo, "Undo stack should be populated")
        
        // Restart the game
        viewModel.restartCurrentGame()
        assert(viewModel.state == originalState, "Game state should be restored to initial state")
        assert(viewModel.state.movesCount == 0, "Moves count should be reset to 0")
        assert(!viewModel.canUndo, "Undo stack should be cleared on restart")
    }
    
    static func testHighScorePersistence() {
        let savedHighScore = UserDefaults.standard.integer(forKey: "highScore")
        let savedVegasHighScore = UserDefaults.standard.integer(forKey: "highScoreVegas")
        let savedVegasExists = UserDefaults.standard.object(forKey: "highScoreVegas") != nil
        
        UserDefaults.standard.set(100, forKey: "highScore")
        UserDefaults.standard.removeObject(forKey: "highScoreVegas")
        
        let viewModel = GameViewModel()
        assert(viewModel.highScore == 100, "highScore should load 100 from UserDefaults")
        
        // Simulating a move that increases score
        let spadeAce = Card(suit: .spades, rank: 1, faceUp: true)
        viewModel.state.tableau[0].cards = [spadeAce]
        
        // First move Ace to Foundation to get +10 points (score: 10)
        viewModel.doubleClickMoveToFoundation(card: spadeAce, from: viewModel.state.tableau[0])
        assert(viewModel.state.score == 10, "Score should be 10")
        assert(viewModel.highScore == 100, "highScore should remain 100 since score (10) < highScore")
        
        // Set highScore lower (e.g. 5) to test update
        viewModel.highScore = 5
        
        // Move another Ace to Foundation (Clubs Ace)
        let clubAce = Card(suit: .clubs, rank: 1, faceUp: true)
        viewModel.state.tableau[1].cards = [clubAce]
        viewModel.doubleClickMoveToFoundation(card: clubAce, from: viewModel.state.tableau[1])
        
        assert(viewModel.state.score == 20, "Score should be 20")
        assert(viewModel.highScore == 20, "highScore should update to 20 because score (20) > highScore (5)")
        
        // Switch to Vegas mode
        var opts = viewModel.options
        opts.isVegasScoring = true
        viewModel.options = opts
        
        // Default Vegas high score should be -5200 (since no saved vegas score exists yet)
        assert(viewModel.highScore == -5200, "Vegas highScore should default to -5200")
        assert(viewModel.state.score == -5200, "Vegas starting score should be -5200")
        
        // Move club Ace to foundation (in Vegas mode: +500 cents) -> score is now -4700 cents
        viewModel.state.tableau[2].cards = [clubAce]
        viewModel.doubleClickMoveToFoundation(card: clubAce, from: viewModel.state.tableau[2])
        assert(viewModel.state.score == -4700, "Vegas score should be -4700")
        assert(viewModel.highScore == -4700, "Vegas highScore should update to -4700")
        
        // Verify persistence of Vegas score
        let vegasViewModel = GameViewModel()
        assert(vegasViewModel.highScore == -4700, "Vegas highScore should persist")
        
        // Switch back to Standard mode
        var opts2 = vegasViewModel.options
        opts2.isVegasScoring = false
        vegasViewModel.options = opts2
        assert(vegasViewModel.highScore == 20, "Standard highScore should be restored")
        
        // Clean up
        UserDefaults.standard.set(savedHighScore, forKey: "highScore")
        if savedVegasExists {
            UserDefaults.standard.set(savedVegasHighScore, forKey: "highScoreVegas")
        } else {
            UserDefaults.standard.removeObject(forKey: "highScoreVegas")
        }
    }
    
    static func testCardBackThemePersistence() {
        let savedOptions = UserDefaults.standard.data(forKey: "solitaire_options")
        let savedTheme = UserDefaults.standard.string(forKey: "cardBackTheme")
        UserDefaults.standard.removeObject(forKey: "solitaire_options")
        UserDefaults.standard.removeObject(forKey: "cardBackTheme")
        
        let viewModel = GameViewModel()
        assert(viewModel.cardBackTheme == "Moogle", "Default theme should be Moogle")
        
        viewModel.cardBackTheme = "Moogle"
        assert(UserDefaults.standard.string(forKey: "cardBackTheme") == "Moogle", "Theme should be persisted to UserDefaults")
        
        let nextViewModel = GameViewModel()
        assert(nextViewModel.cardBackTheme == "Moogle", "Persisted theme should be loaded on init")
        
        // Clean up
        if let saved = savedOptions {
            UserDefaults.standard.set(saved, forKey: "solitaire_options")
        } else {
            UserDefaults.standard.removeObject(forKey: "solitaire_options")
        }
        if let original = savedTheme {
            UserDefaults.standard.set(original, forKey: "cardBackTheme")
        } else {
            UserDefaults.standard.removeObject(forKey: "cardBackTheme")
        }
    }
    
    static func testKeyboardNavigation() {
        let viewModel = GameViewModel()
        assert(viewModel.activeCursor == nil, "Initial activeCursor should be nil")
        
        viewModel.moveCursorRight()
        assert(viewModel.activeCursor?.pileId == viewModel.state.waste.id, "Right arrow from stock should target waste pile")
        
        viewModel.moveCursorRight()
        assert(viewModel.activeCursor?.pileId == viewModel.state.foundations[0].id, "Right arrow from waste should target first foundation")
        
        viewModel.moveCursorLeft()
        assert(viewModel.activeCursor?.pileId == viewModel.state.waste.id, "Left arrow from first foundation should target waste pile")
        
        viewModel.moveCursorLeft()
        assert(viewModel.activeCursor?.pileId == viewModel.state.stock.id, "Left arrow from waste should target stock pile")
        
        viewModel.moveCursorDown()
        assert(viewModel.activeCursor?.pileId == viewModel.state.tableau[0].id, "Down arrow from stock should target first tableau column")
    }
}
