import Foundation

// Player-visible Beecell (FreeCell) behaviour on fixed layouts: the supermove limit, what
// each pile accepts, exact scoring, winning in 1 and 2 decks, "stuck", Autocomplete, hints,
// double-click and keyboard play, and per-deck-count stats.
struct BeecellGameplayTests {
    static let defaultsKeys = ["beecell_options", "beecell_statistics"]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) { withCleanDefaults(defaultsKeys, test) }
        isolated(testDealLayoutAndPerDeckCountStats)
        isolated(testSupermoveLimitAndPileRules)
        isolated(testScoringAndUndo)
        isolated(testWinInOneAndTwoDecks)
        isolated(testStreakAndRestartRules)
        isolated(testStuckDetection)
        isolated(testAutocompleteRunsAndSafetyRule)
        isolated(testHintTextsAndCycling)
        isolated(testDoubleClickPreferences)
        isolated(testKeyboardPlay)
        isolated(testBannersMilestonesAndStats)
        isolated(testNoStressAndTimer)
    }

    // MARK: - Fixtures

    /// Replaces the dealt game with a hand-built board sized for the current deck count.
    static func board(_ vm: BeecellViewModel, tableau: [[Card]] = [], cells: [Card] = [], found: [[Card]] = []) {
        let two = vm.options.deckCount == 2
        let columns = two ? 10 : 8, cellCount = two ? 8 : 4, foundCount = two ? 8 : 4
        vm.state.tableau = (0..<columns).map { Pile(id: "tableau_\($0)", type: .tableau, cards: $0 < tableau.count ? tableau[$0] : []) }
        vm.state.freeCells = (0..<cellCount).map { Pile(id: "freecell_\($0)", type: .freeCell, cards: $0 < cells.count ? [cells[$0]] : []) }
        vm.state.foundations = (0..<foundCount).map { Pile(id: "foundation_\($0)", type: .foundation, cards: $0 < found.count ? found[$0] : []) }
        vm.state.score = 0
        vm.state.movesCount = 0
        vm.state.timerSeconds = 0
        vm.state.isTimerActive = false
        vm.state.hasWon = false
        vm.isStuck = false
        vm.isAutocompleteAvailable = false
        vm.pointPopup = nil
        vm.clearHint()
    }

    /// Single cards that can't take or give anything to each other (kings and nines): keeps
    /// every column occupied without creating extra legal moves among themselves.
    static func fillers(_ count: Int) -> [[Card]] {
        let pool = [CovCards.card(.diamonds, 13), CovCards.card(.hearts, 13), CovCards.card(.clubs, 13), CovCards.card(.spades, 13),
                    CovCards.card(.diamonds, 9), CovCards.card(.hearts, 9), CovCards.card(.clubs, 9), CovCards.card(.spades, 9)]
        return (0..<count).map { [pool[$0 % pool.count]] }
    }

    /// Up to four lone kings — columns that can never move anywhere. Remaining columns stay empty.
    static func kings(_ count: Int) -> [[Card]] { Array(fillers(4).prefix(count)) }

    static func setDecks(_ vm: BeecellViewModel, _ decks: Int) {
        var o = vm.options
        o.deckCount = decks
        vm.options = o
    }

    static func mode(_ vm: BeecellViewModel, _ key: String) -> ModeStats {
        vm.statistics.statsByMode[key] ?? ModeStats()
    }

    static func drain(_ vm: BeecellViewModel) -> Int {
        var n = 0
        while vm.flashBanner != nil { n += 1; vm.advanceBannerQueue(); if n > 50 { break } }
        return n
    }

    /// 8 columns where nothing can move and all 4 cells are full — a genuinely stuck game.
    static func stuckBoard(_ vm: BeecellViewModel, withFoundation: Bool = false) {
        board(vm,
              tableau: [[CovCards.card(.spades, 13)], [CovCards.card(.hearts, 13)], [CovCards.card(.diamonds, 13)],
                        [CovCards.card(.clubs, 13)], [CovCards.card(.hearts, 5)], [CovCards.card(.clubs, 9)],
                        [CovCards.card(.spades, 9)], [CovCards.card(.diamonds, 9)]],
              cells: [CovCards.card(.spades, 7), CovCards.card(.hearts, 7), CovCards.card(.diamonds, 7), CovCards.card(.clubs, 7)],
              found: withFoundation ? [CovCards.ascending(.spades, through: 4)] : [])
    }

    // MARK: - Deal & modes

    static func testDealLayoutAndPerDeckCountStats() {
        let vm = BeecellViewModel()
        expect(vm.state.tableau.count == 8 && vm.state.freeCells.count == 4 && vm.state.foundations.count == 4, "1 deck: 8 columns, 4 cells, 4 foundations")
        expect(vm.state.tableau.map { $0.cards.count } == [7, 7, 7, 7, 6, 6, 6, 6], "52 cards dealt round-robin: 7,7,7,7,6,6,6,6")
        expect(vm.state.tableau.flatMap { $0.cards }.allSatisfy { $0.faceUp }, "Every card is face up")
        expect(Set(vm.state.tableau.flatMap { $0.cards }.map { $0.id }).count == 52, "52 distinct cards")
        expect(vm.currentModeKey == "1deck" && mode(vm, "1deck").gamesPlayed == 1, "First deal counted in the 1-deck mode")

        setDecks(vm, 2)
        expect(vm.state.tableau.count == 10 && vm.state.freeCells.count == 8 && vm.state.foundations.count == 8, "2 decks: 10 columns, 8 cells, 8 foundations")
        expect(vm.state.tableau.reduce(0) { $0 + $1.cards.count } == 104, "104 cards")
        expect(vm.currentModeKey == "2deck" && mode(vm, "2deck").gamesPlayed == 1 && mode(vm, "1deck").gamesPlayed == 1,
               "Each deck count keeps its own games-played")
        expect(BeecellViewModel().options.deckCount == 2, "Deck count is remembered across relaunch")

        // Scores and win counts are per mode.
        vm.recordWin(timeInSeconds: 90)
        expect(mode(vm, "2deck").gamesWon == 1 && mode(vm, "1deck").gamesWon == 0, "A 2-deck win only counts in the 2-deck mode")
        vm.highScore = 123
        expect(vm.highScoreString == "123" && vm.currentModeStats.highScore == 123, "High score is stored per mode")
        setDecks(vm, 1)
        expect(vm.highScore == 0, "The 1-deck high score is separate")
        vm.recordWin(timeInSeconds: 10)
        vm.resetStatistics()
        expect(mode(vm, "1deck") == ModeStats() && mode(vm, "2deck").gamesWon == 1, "Reset Stats clears just the current mode")
        expect(ModeStats().winPercentage == 0 && ModeStats().averageWinningTime == 0, "Empty stats are safe")
    }

    // MARK: - Rules

    static func testSupermoveLimitAndPileRules() {
        let vm = BeecellViewModel()
        let run5 = [CovCards.card(.spades, 9), CovCards.card(.hearts, 8), CovCards.card(.clubs, 7), CovCards.card(.diamonds, 6), CovCards.card(.spades, 5)]
        let run6 = [CovCards.card(.clubs, 9), CovCards.card(.diamonds, 8), CovCards.card(.spades, 7), CovCards.card(.hearts, 6),
                    CovCards.card(.clubs, 5), CovCards.card(.diamonds, 4)]
        board(vm, tableau: [[CovCards.card(.clubs, 13)] + run5, [CovCards.card(.hearts, 10)], run6] + fillers(5))

        expect(vm.emptyFreeCellsCount == 4 && vm.emptyTableauColumnsCount == 0, "4 empty cells, no empty columns")
        expect(vm.maxMoveLimit(toEmptyTableau: false) == 5, "(cells+1) × 2^columns = 5")
        expect(vm.maxMoveLimit(toEmptyTableau: true) == 5, "An empty target doesn't count as spare space")
        let t1 = vm.state.tableau[1]
        expect(vm.isValidMove(cards: run5, to: t1), "Five cards fit within the limit of five")
        expect(!vm.isValidMove(cards: run6, to: t1), "Six cards exceed the limit")
        vm.moveCards(run6, from: vm.state.tableau[2], to: t1)
        expect(vm.state.tableau[2].cards.count == 6 && vm.state.movesCount == 0, "An over-limit move is refused")

        // Filling cells shrinks the limit.
        board(vm, tableau: [[CovCards.card(.clubs, 13)] + run5, [CovCards.card(.hearts, 10)]] + fillers(6),
              cells: [CovCards.card(.spades, 2)])
        expect(vm.maxMoveLimit(toEmptyTableau: false) == 4, "3 free cells → limit 4")
        expect(!vm.isValidMove(cards: run5, to: vm.state.tableau[1]), "Five cards no longer fit")
        expect(vm.isValidMove(cards: Array(run5.suffix(4)), to: vm.state.tableau[1]) == false, "Four cards 8,7,6,5 don't fit on a 10 (wrong rank)")

        // An empty column doubles the limit for other columns but not for itself.
        board(vm, tableau: [[CovCards.card(.clubs, 13)] + run6, [CovCards.card(.hearts, 10)]] + fillers(5))
        expect(vm.emptyTableauColumnsCount == 1 && vm.maxMoveLimit(toEmptyTableau: false) == 10 && vm.maxMoveLimit(toEmptyTableau: true) == 5,
               "One empty column: limit 10 elsewhere, 5 into the empty column itself")
        expect(vm.isValidMove(cards: run6, to: vm.state.tableau[1]), "Six cards fit onto the 10 now")
        expect(!vm.isValidMove(cards: run6, to: vm.state.tableau[7]), "...but not into the empty column (limit 5)")
        expect(vm.isValidMove(cards: Array(run6.suffix(1)), to: vm.state.tableau[7]), "Any single card may start an empty column")
        vm.moveCards(run6, from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.state.tableau[1].cards.count == 7 && vm.state.movesCount == 1, "A legal supermove goes through as one move")

        // Pile rules.
        board(vm, tableau: [[CovCards.card(.spades, 6)]] + fillers(7), cells: [CovCards.card(.hearts, 2)],
              found: [CovCards.ascending(.hearts, through: 3)])
        let h5 = CovCards.card(.hearts, 5), c5 = CovCards.card(.clubs, 5), d4 = CovCards.card(.diamonds, 4)
        expect(vm.isValidMove(cards: [h5], to: vm.state.tableau[0]), "Red 5 on black 6")
        expect(!vm.isValidMove(cards: [c5], to: vm.state.tableau[0]), "Same colour refused")
        expect(!vm.isValidMove(cards: [d4], to: vm.state.tableau[0]), "Wrong rank refused")
        expect(!vm.isValidMove(cards: [h5, CovCards.card(.hearts, 4)], to: vm.state.tableau[0]), "Non-alternating pair refused")
        expect(!vm.isValidMove(cards: [], to: vm.state.tableau[0]), "Nothing to move")
        expect(!vm.isValidMove(cards: [h5], to: vm.state.freeCells[0]), "An occupied free cell is refused")
        expect(vm.isValidMove(cards: [h5], to: vm.state.freeCells[1]), "A vacant free cell takes one card")
        expect(!vm.isValidMove(cards: [CovCards.card(.spades, 6), h5], to: vm.state.freeCells[1]), "...but only one")
        expect(vm.isValidMove(cards: [CovCards.card(.hearts, 4)], to: vm.state.foundations[0]), "4♥ continues the hearts foundation")
        expect(!vm.isValidMove(cards: [CovCards.card(.hearts, 5)], to: vm.state.foundations[0]), "Can't skip a rank")
        expect(!vm.isValidMove(cards: [CovCards.card(.spades, 4)], to: vm.state.foundations[0]), "Wrong suit")
        expect(vm.isValidMove(cards: [CovCards.card(.spades, 1)], to: vm.state.foundations[1]), "An ace starts an empty foundation")
        expect(!vm.isValidMove(cards: [CovCards.card(.spades, 2)], to: vm.state.foundations[1]), "...only an ace")
        expect(!vm.isValidMove(cards: [h5], to: Pile(id: "stock", type: .stock)), "Stock/waste piles accept nothing")
        expect(vm.isValidDragSequence([CovCards.card(.spades, 6), CovCards.card(.hearts, 5)]) && !vm.isValidDragSequence([]), "Drag sequence check")
    }

    // MARK: - Scoring

    static func testScoringAndUndo() {
        let vm = BeecellViewModel()
        vm.sharedOptions.honeyMode = true

        let ace = CovCards.card(.spades, 1)
        board(vm, tableau: [[ace]] + fillers(7))
        vm.moveCards([ace], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.score == 10 && vm.pointPopup?.displayText == "+10" && vm.pointPopup?.cardId == ace.id,
               "Tableau → foundation scores +10 with a +10 popup")
        vm.undoLastAction()
        expect(vm.state.score == 0 && vm.pointPopup == nil, "Undo restores the score exactly (no extra penalty) and clears the popup")

        let aceC = CovCards.card(.clubs, 1)
        board(vm, tableau: fillers(8), cells: [aceC])
        vm.moveCards([aceC], from: vm.state.freeCells[0], to: vm.state.foundations[0])
        expect(vm.state.score == 10 && vm.state.freeCells[0].isEmpty, "Free cell → foundation scores +10")

        // Leaving a foundation costs 15 (never below zero) whether it lands on the tableau or in a cell.
        let two = CovCards.card(.spades, 2)
        board(vm, tableau: [[CovCards.card(.hearts, 3)]] + fillers(7), found: [[CovCards.card(.spades, 1), two]])
        vm.state.score = 20
        vm.moveCards([two], from: vm.state.foundations[0], to: vm.state.tableau[0])
        expect(vm.state.score == 5 && vm.pointPopup?.displayText == "-15" && vm.pointPopup?.isPositive == false,
               "Foundation → tableau costs 15 (got \(vm.state.score))")
        board(vm, tableau: fillers(8), found: [[CovCards.card(.spades, 1), two]])
        vm.state.score = 5
        vm.moveCards([two], from: vm.state.foundations[0], to: vm.state.freeCells[0])
        expect(vm.state.score == 0, "Foundation → free cell costs 15 too, but never goes below 0 (got \(vm.state.score))")

        // Shuffling an ace between foundations, or tableau → cell, is free.
        board(vm, tableau: fillers(8), found: [[CovCards.card(.spades, 1)]])
        vm.moveCards([CovCards.card(.spades, 1)], from: vm.state.foundations[0], to: vm.state.foundations[1])
        expect(vm.state.score == 0, "Foundation → foundation is free")
        let k = CovCards.card(.hearts, 5)
        board(vm, tableau: [[k]] + fillers(7))
        vm.pointPopup = nil
        vm.moveCards([k], from: vm.state.tableau[0], to: vm.state.freeCells[0])
        expect(vm.state.score == 0 && vm.pointPopup == nil, "Tableau → free cell is free, no popup")

        // No popups with Honey Mode off.
        let quiet = BeecellViewModel()
        quiet.sharedOptions.honeyMode = false
        board(quiet, tableau: [[CovCards.card(.spades, 1)]] + fillers(7))
        quiet.moveCards([quiet.state.tableau[0].cards[0]], from: quiet.state.tableau[0], to: quiet.state.foundations[0])
        expect(quiet.pointPopup == nil && quiet.state.score == 10, "Honey Mode off: points but no popup")

        // Undo with no history; undo keeps the clock running.
        let fresh = BeecellViewModel()
        fresh.undoLastAction()
        expect(!fresh.canUndo, "Nothing to undo")
        board(fresh, tableau: [[CovCards.card(.spades, 1)]] + fillers(7))
        fresh.moveCards([fresh.state.tableau[0].cards[0]], from: fresh.state.tableau[0], to: fresh.state.foundations[0])
        fresh.state.timerSeconds = 33
        expect(fresh.canUndo, "A move can be undone")
        fresh.undoLastAction()
        expect(fresh.state.timerSeconds == 33 && fresh.state.movesCount == 0, "The clock keeps running through undo")
    }

    // MARK: - Winning

    static func testWinInOneAndTwoDecks() {
        let vm = BeecellViewModel()
        board(vm, tableau: [[CovCards.card(.spades, 13)]],
              found: [CovCards.ascending(.spades, through: 12), CovCards.ascending(.clubs, through: 13),
                      CovCards.ascending(.diamonds, through: 13), CovCards.ascending(.hearts, through: 13)])
        vm.state.timerSeconds = 60
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && !vm.state.isTimerActive, "All 52 on the foundations wins and stops the clock")
        let s = mode(vm, "1deck")
        expect(s.gamesWon == 1 && s.currentStreak == 1 && s.shortestWinTime == 60 && s.totalWinningTime == 60 && s.highScore == 10,
               "Win, streak, time and score recorded: \(s)")
        expect(!vm.canUndo, "No undo after winning")
        vm.undoLastAction()
        expect(vm.state.hasWon, "Undo can't reopen a won game")

        // Two decks need all 104.
        setDecks(vm, 2)
        let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts, .spades, .clubs, .diamonds, .hearts]
        board(vm, tableau: [[CovCards.card(.spades, 13)]],
              found: suits.enumerated().map { CovCards.ascending($0.element, through: $0.offset == 0 ? 12 : 13) })
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && mode(vm, "2deck").gamesWon == 1 && mode(vm, "1deck").gamesWon == 1, "2-deck win counts only in the 2-deck mode")
        // 103 of 104 is not a win.
        let almost = BeecellViewModel()
        setDecks(almost, 2)
        board(almost, tableau: [[CovCards.card(.spades, 13)], [CovCards.card(.hearts, 13)]],
              found: suits.enumerated().map { CovCards.ascending($0.element, through: $0.offset < 2 ? 12 : 13) })
        almost.moveCards([almost.state.tableau[0].cards[0]], from: almost.state.tableau[0], to: almost.state.foundations[0])
        expect(!almost.state.hasWon, "One card short isn't a win")
    }

    static func testStreakAndRestartRules() {
        func primed(_ streak: Int) -> BeecellViewModel {
            let vm = BeecellViewModel()
            var s = vm.statistics
            s.statsByMode["1deck"] = ModeStats(gamesPlayed: 5, currentStreak: streak, longestStreak: streak)
            vm.statistics = s
            return vm
        }
        func oneMove(_ vm: BeecellViewModel) {
            board(vm, tableau: [[CovCards.card(.spades, 1)]] + fillers(7))
            vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        }
        let untouched = primed(3); untouched.startNewGame()
        expect(mode(untouched, "1deck").currentStreak == 3, "New game before moving keeps the streak")

        let played = primed(3); oneMove(played); played.startNewGame()
        expect(mode(played, "1deck").currentStreak == 0 && mode(played, "1deck").longestStreak == 3, "Abandoning a played game breaks the streak")

        let undone = primed(3); oneMove(undone); undone.undoLastAction(); undone.startNewGame()
        expect(mode(undone, "1deck").currentStreak == 0, "Undo to the start can't dodge the streak break")

        let restarted = primed(3); oneMove(restarted); restarted.restartCurrentGame(); restarted.startNewGame()
        expect(mode(restarted, "1deck").currentStreak == 0, "Restart can't dodge it either")

        // Restart: unwon = same deal, not another game played; won = new game played.
        let vm = BeecellViewModel()
        let deal = vm.state.tableau.map { $0.cards.map { $0.id } }
        let played0 = mode(vm, "1deck").gamesPlayed
        vm.moveCards([vm.state.tableau[0].cards.last!], from: vm.state.tableau[0], to: vm.state.freeCells[0])
        vm.restartCurrentGame()
        expect(vm.state.tableau.map { $0.cards.map { $0.id } } == deal && vm.state.movesCount == 0 && !vm.canUndo, "Restart replays the same deal")
        expect(mode(vm, "1deck").gamesPlayed == played0, "Restarting an unwon game isn't another game")
        board(vm, tableau: [[CovCards.card(.spades, 13)]],
              found: [CovCards.ascending(.spades, through: 12), CovCards.ascending(.clubs, through: 13),
                      CovCards.ascending(.diamonds, through: 13), CovCards.ascending(.hearts, through: 13)])
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon, "Won")
        vm.restartCurrentGame()
        expect(!vm.state.hasWon && mode(vm, "1deck").gamesPlayed == played0 + 1, "Restarting a won game counts as a new game played")
        vm.restartCurrentGame()
        expect(mode(vm, "1deck").gamesPlayed == played0 + 1, "...once")
    }

    // MARK: - Stuck

    static func testStuckDetection() {
        let vm = BeecellViewModel()
        stuckBoard(vm)
        vm.checkStuckState()
        expect(vm.isStuck, "Full cells and no legal move: stuck")

        stuckBoard(vm, withFoundation: true)
        vm.checkStuckState()
        expect(vm.isStuck, "Pulling a card back off a foundation doesn't count as a way out")

        // One open free cell is always a way forward.
        board(vm, tableau: vm.state.tableau.map { $0.cards }, cells: [CovCards.card(.spades, 7), CovCards.card(.hearts, 7), CovCards.card(.diamonds, 7)])
        vm.checkStuckState()
        expect(!vm.isStuck, "An open free cell means not stuck")

        // A real legal move.
        stuckBoard(vm)
        vm.state.tableau[5].cards = [CovCards.card(.clubs, 6)]   // 5♥ can now go on it
        vm.checkStuckState()
        expect(!vm.isStuck, "A legal tableau move means not stuck")

        // A card in a full set of cells can still go to an empty column.
        board(vm, tableau: [[CovCards.card(.spades, 13)]],
              cells: [CovCards.card(.spades, 7), CovCards.card(.hearts, 7), CovCards.card(.diamonds, 7), CovCards.card(.clubs, 7)])
        vm.checkStuckState()
        expect(!vm.isStuck, "A cell card can still go to an empty column")

        // Playing into a dead end sets the flag.
        stuckBoard(vm)
        vm.state.freeCells[3].cards = []
        vm.state.tableau[0].cards = [CovCards.card(.spades, 13), CovCards.card(.clubs, 3)]
        vm.moveCards([vm.state.tableau[0].cards[1]], from: vm.state.tableau[0], to: vm.state.freeCells[3])
        expect(vm.isStuck, "Filling the last cell with nothing left to do raises the stuck flag")
        vm.undoLastAction()
        expect(!vm.isStuck, "Undo clears it")

        stuckBoard(vm)
        vm.state.hasWon = true
        vm.checkStuckState()
        expect(!vm.isStuck, "Won games are never stuck")
    }

    // MARK: - Autocomplete

    static func testAutocompleteRunsAndSafetyRule() {
        let vm = BeecellViewModel()
        let nearlyDone = [CovCards.ascending(.spades, through: 11), CovCards.ascending(.clubs, through: 13),
                          CovCards.ascending(.diamonds, through: 13), CovCards.ascending(.hearts, through: 13)]
        board(vm, tableau: [[CovCards.card(.spades, 13), CovCards.card(.spades, 12)]], found: nearlyDone)
        vm.checkAutocompleteState()
        expect(vm.isAutocompleteAvailable, "Q♠ then K♠ can go straight up: Autocomplete offered")
        vm.checkStuckState()
        expect(!vm.isStuck, "Not stuck while Autocomplete is possible")
        vm.runAutocomplete()
        expect(vm.isAutoplayRunning, "Autocomplete running")
        pumpRunLoop(timeout: 3) { vm.state.hasWon && !vm.isAutoplayRunning }
        expect(vm.state.hasWon && !vm.isAutoplayRunning, "Autocomplete plays the game out and stops")
        expect(vm.state.score == 20 && mode(vm, "1deck").gamesWon == 1, "Two foundation moves scored (\(vm.state.score)), win recorded")

        // A needed card buried → not offered.
        board(vm, tableau: [[CovCards.card(.spades, 12), CovCards.card(.spades, 13)]], found: nearlyDone)
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Q♠ is under the K♠: not offered")
        vm.runAutocomplete()
        expect(!vm.isAutoplayRunning, "runAutocomplete does nothing when not offered")

        // Playable but not "safe": the opposite-colour foundations are too far behind.
        board(vm, tableau: [[CovCards.card(.spades, 12)]], found: [CovCards.ascending(.spades, through: 11)])
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "A queen isn't auto-played while hearts/diamonds are far behind")

        // Cards in free cells get played too — and are played first.
        board(vm, tableau: [[CovCards.card(.spades, 13)]], cells: [CovCards.card(.spades, 12)], found: nearlyDone)
        vm.checkAutocompleteState()
        vm.runAutocomplete()
        expect(vm.state.freeCells[0].isEmpty, "The free-cell Q♠ is the first card Autocomplete plays")
        pumpRunLoop(timeout: 3) { vm.state.hasWon && !vm.isAutoplayRunning }
        expect(vm.state.hasWon, "...and it finishes the game")

        // Availability with only a free-cell card to play:
        board(vm, tableau: [], cells: [CovCards.card(.spades, 12)], found: nearlyDone)
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "...but the K♠ is missing from this board, so it can't finish")
        board(vm, tableau: [[CovCards.card(.spades, 13)]], cells: [CovCards.card(.spades, 12)], found: nearlyDone)
        vm.checkAutocompleteState()
        expect(vm.isAutocompleteAvailable, "Free-cell cards are included")
    }

    // MARK: - Hints

    /// Every hint Hint would cycle through for the current board (descriptions without the "[i/n]" prefix).
    static func allHints(_ vm: BeecellViewModel) -> [String] {
        vm.clearHint()
        guard vm.findHint(), let first = vm.activeHint else { return [] }
        var total = 1
        if first.description.hasPrefix("["), let slash = first.description.firstIndex(of: "/"),
           let close = first.description.firstIndex(of: "]") {
            total = Int(first.description[first.description.index(after: slash)..<close]) ?? 1
        }
        var out = [stripped(first.description)]
        for _ in 1..<max(total, 1) {
            _ = vm.findHint()
            out.append(stripped(vm.activeHint?.description))
        }
        return out
    }

    static func stripped(_ text: String?) -> String {
        guard var t = text else { return "nil" }
        if t.hasPrefix("["), let r = t.range(of: "] ") { t = String(t[r.upperBound...]) }
        return t
    }

    static func testHintTextsAndCycling() {
        let vm = BeecellViewModel()

        board(vm, tableau: [[CovCards.card(.spades, 2)]] + kings(3), found: [[CovCards.card(.spades, 1)]])
        var hints = allHints(vm)
        expect(hints.contains("Move 2♠ to Foundation."), "Tableau→foundation hint offered: \(hints)")
        expect(vm.activeHint != nil, "A hint is showing")

        board(vm, tableau: kings(4), cells: [CovCards.card(.spades, 2)], found: [[CovCards.card(.spades, 1)]])
        hints = allHints(vm)
        expect(hints.contains("Move 2♠ from Free Cell to Foundation."), "Cell→foundation hint offered: \(hints)")

        board(vm, tableau: [[CovCards.card(.spades, 6)]] + kings(3), cells: [CovCards.card(.hearts, 5)])
        hints = allHints(vm)
        expect(hints.contains("Move 5♥ from Free Cell to Tableau."), "Cell→tableau hint offered: \(hints)")

        board(vm, tableau: [[CovCards.card(.clubs, 9), CovCards.card(.hearts, 8)], [CovCards.card(.diamonds, 10)]] + kings(2))
        hints = allHints(vm)
        expect(hints.contains("Move 9♣ sequence to Tableau."), "Sequence hint offered: \(hints)")
        expect(hints.count >= 2, "Several hints to cycle through: \(hints)")
        // Cycling: numbered, wraps, and a move clears it.
        vm.clearHint()
        _ = vm.findHint()
        expect(vm.activeHint!.description.hasPrefix("[1/"), "First hint is numbered 1: \(vm.activeHint!.description)")
        _ = vm.findHint()
        expect(vm.activeHint!.description.hasPrefix("[2/"), "Second hint is numbered 2")
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.freeCells[0])
        expect(vm.activeHint == nil, "A move clears the hint")

        // Only dead columns and an open cell: the last-resort hints park a king.
        board(vm, tableau: kings(4))
        hints = allHints(vm)
        expect(hints.count == 4 && hints.allSatisfy { $0.hasSuffix("to Free Cell to clear space.") }, "Park-a-card hints only: \(hints)")

        // A foundation move past the twos is offered whether or not the other colours have caught up.
        board(vm, tableau: [[CovCards.card(.spades, 3)]] + kings(3),
              found: [CovCards.ascending(.spades, through: 2), CovCards.ascending(.hearts, through: 2), CovCards.ascending(.diamonds, through: 2)])
        expect(allHints(vm).contains("Move 3♠ to Foundation."), "Safe foundation hint")
        board(vm, tableau: [[CovCards.card(.spades, 3)]] + kings(3), found: [CovCards.ascending(.spades, through: 2)])
        expect(allHints(vm).contains("Move 3♠ to Foundation."), "Foundation hint when the other colours are behind")

        // No hint on a stuck board.
        stuckBoard(vm)
        vm.clearHint()
        expect(!vm.findHint(), "findHint fails on a dead board")
        expect(vm.activeHint?.description == "No moves available. Try restarting or starting a new game.", "Message: \(vm.activeHint?.description ?? "nil")")
        vm.startNewGame()
        expect(vm.activeHint == nil, "A new game clears the hint")
    }

    // MARK: - Double-click

    static func testDoubleClickPreferences() {
        let vm = BeecellViewModel()
        // Foundation first
        let ace = CovCards.card(.spades, 1)
        board(vm, tableau: [[ace], [CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]] + fillers(5))
        vm.doubleClickMove(card: ace, from: vm.state.tableau[0])
        expect(vm.state.foundations.contains { $0.cards.first?.id == ace.id }, "Double-click sends an ace to a foundation")

        // Then an empty free cell, even if the tableau would also take it.
        let five = vm.state.tableau[1].cards[0]
        vm.doubleClickMove(card: five, from: vm.state.tableau[1])
        expect(vm.state.freeCells[0].cards.first?.id == five.id, "...otherwise to the first empty free cell")

        // With every cell full it goes to the tableau.
        board(vm, tableau: [[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]] + fillers(6),
              cells: [CovCards.card(.spades, 2), CovCards.card(.hearts, 2), CovCards.card(.clubs, 2), CovCards.card(.diamonds, 2)])
        vm.doubleClickMove(card: vm.state.tableau[0].cards[0], from: vm.state.tableau[0])
        expect(vm.state.tableau[1].cards.count == 2 && vm.state.tableau[0].isEmpty, "...or, with no free cell, onto a legal column")

        // Only the top card responds.
        board(vm, tableau: [[CovCards.card(.spades, 1), CovCards.card(.hearts, 5)]] + fillers(7))
        vm.doubleClickMove(card: vm.state.tableau[0].cards[0], from: vm.state.tableau[0])
        expect(vm.state.movesCount == 0, "Double-clicking a buried card does nothing")
    }

    // MARK: - Keyboard

    static func testKeyboardPlay() {
        let vm = BeecellViewModel()
        let run = [CovCards.card(.hearts, 8), CovCards.card(.clubs, 7), CovCards.card(.diamonds, 6)]
        board(vm, tableau: [[CovCards.card(.spades, 9)], run] + fillers(6), cells: [CovCards.card(.clubs, 1)])
        vm.state.foundations[1].cards = []

        vm.moveCursorDown()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_0"), "Down from the top row lands on the first column")
        vm.moveCursorDown()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_0"), "Down again does nothing")
        vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "tableau_1", "Space selects the column")
        vm.moveCursorLeft()
        vm.performSpaceAction()
        expect(vm.state.tableau[0].cards.map { $0.rank } == [9, 8, 7, 6] && vm.state.tableau[1].isEmpty,
               "Space on a legal target moves the whole run 8♥ 7♣ 6♦ (supermove) onto the 9♠")
        expect(vm.selectedCardsSource == nil, "Selection cleared")

        // Top row: cells then foundations, wrapping.
        vm.moveCursorUp()
        expect(vm.activeCursor?.pileId == "freecell_0", "Up returns to the top row")
        vm.moveCursorRight(); vm.moveCursorRight(); vm.moveCursorRight(); vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "foundation_0", "Four rights from the first cell reach the first foundation")
        for _ in 0..<5 { vm.moveCursorLeft() }
        expect(vm.activeCursor?.pileId == "foundation_3", "Left wraps from the first cell to the last foundation")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil, "Space on an empty pile picks nothing up")
        vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "freecell_0", "Right wraps back to the first cell")

        // Pick up the ace from a cell and put it on a foundation.
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "freecell_0", "Cell card picked up")
        vm.moveCursorRight(); vm.moveCursorRight(); vm.moveCursorRight(); vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.state.foundations[0].cards.first?.rank == 1 && vm.state.score == 10, "A♣ goes to the foundation (+10)")

        // Space on the same pile twice cancels; an illegal drop clears the selection quietly.
        vm.moveCursorDown()
        vm.performSpaceAction()
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil, "Space twice on one pile cancels")
        vm.performSpaceAction()
        vm.moveCursorRight()
        vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil && vm.state.tableau[0].cards.count == 4, "An illegal drop does nothing and clears the selection")

        // Auto-move to a free cell and to a foundation.
        vm.clearKeyboardCursor()
        vm.moveCursorDown()
        vm.autoMoveFocusedCardToFreeCell()
        expect(vm.state.freeCells[0].cards.first?.rank == 6 && vm.state.tableau[0].cards.count == 3, "Auto-move parks the focused card in a free cell")
        board(vm, tableau: [[CovCards.card(.spades, 5), CovCards.card(.hearts, 1)]] + fillers(7), cells: [CovCards.card(.clubs, 1)])
        vm.clearKeyboardCursor()
        vm.moveCursorDown()
        vm.autoMoveFocusedCardToFoundations()
        expect(vm.state.foundations.contains { $0.cards.first?.suit == .hearts } && vm.state.score == 10, "Auto-move sends an ace to a foundation")
        vm.clearKeyboardCursor()
        vm.enableKeyboardCursorIfNeeded()
        vm.autoMoveFocusedCardToFoundations()
        expect(vm.state.foundations.contains { $0.cards.first?.suit == .clubs }, "...from a free cell too")
        vm.autoMoveFocusedCardToFreeCell()
        expect(vm.state.movesCount == 2, "Nothing to park from a free cell cursor")
    }

    // MARK: - Banners & stats

    static func testBannersMilestonesAndStats() {
        let vm = BeecellViewModel()
        expect(drain(vm) == 1, "First game ever shows the welcome banner")
        vm.checkLoadingBanner(); _ = drain(vm)
        vm.checkLoadingBanner()
        expect(drain(vm) == 0, "Loading banner fires once")
        var s = vm.statistics
        s.statsByMode["1deck"] = ModeStats(gamesPlayed: 6, gamesWon: 6)
        s.statsByMode["2deck"] = ModeStats(gamesPlayed: 3, gamesWon: 3)
        vm.statistics = s
        vm.recordWin(timeInSeconds: 20)
        expect(vm.flashBanner != nil, "10th win across both deck counts shows a milestone banner")
        let t = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t + 1, "Banner replayed when the board returns")
        expect(drain(vm) == 1, "One banner")
        vm.recordWin(timeInSeconds: 20)
        expect(drain(vm) == 0, "No repeat at 11")
        vm.replayCurrentBanner()
        vm.scheduleIdleActionCheck(); vm.cancelIdleActionCheck()
        let m = mode(vm, "1deck")
        expect(m.gamesWon == 8 && m.winningGamesCount == 2 && m.shortestWinTime == 20, "Stats add up: \(m)")
        // Saved stats survive a relaunch.
        expect(mode(BeecellViewModel(), "1deck").gamesWon == 8, "Wins survive a relaunch")
    }

    static func testNoStressAndTimer() {
        let vm = BeecellViewModel()
        board(vm, tableau: [[CovCards.card(.spades, 13)], [CovCards.card(.hearts, 5)]] + fillers(6),
              found: [CovCards.ascending(.spades, through: 12), CovCards.ascending(.clubs, through: 13),
                      CovCards.ascending(.diamonds, through: 13), CovCards.ascending(.hearts, through: 13)])
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.freeCells[0])
        expect(vm.state.isTimerActive, "First move starts the clock")
        vm.state.timerSeconds = 40
        vm.sharedOptions.noStressMode = true
        vm.reactToNoStressModeChange()
        expect(!vm.state.isTimerActive && vm.state.timerSeconds == 0, "No Stress on: clock stops and zeroes")
        vm.sharedOptions.noStressMode = false
        vm.reactToNoStressModeChange()
        expect(vm.state.isTimerActive, "No Stress off: clock restarts")
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && mode(vm, "1deck").winningGamesCount == 0, "A part-untimed win records no time")

        let quiet = BeecellViewModel()
        quiet.sharedOptions.noStressMode = true
        board(quiet, tableau: [[CovCards.card(.spades, 1)]] + fillers(7))
        quiet.moveCards([quiet.state.tableau[0].cards[0]], from: quiet.state.tableau[0], to: quiet.state.foundations[0])
        expect(!quiet.state.isTimerActive, "No clock in No Stress Mode")
        let fresh = BeecellViewModel()
        fresh.sharedOptions.noStressMode = true; fresh.reactToNoStressModeChange()
        fresh.sharedOptions.noStressMode = false; fresh.reactToNoStressModeChange()
        expect(!fresh.state.isTimerActive, "No clock before the first move")
    }
}
