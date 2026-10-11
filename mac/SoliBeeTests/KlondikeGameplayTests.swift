import Foundation

// Player-visible Klondike behaviour on fixed card layouts: exact point values, undo
// penalty, the timed-win bonus, Vegas buy-ins/winnings, the "no moves left" rules,
// Autocomplete, hints, keyboard play and saved stats/options.
struct KlondikeGameplayTests {
    static let defaultsKeys = [
        "solitaire_options", "solitaire_statistics", "gamesWon", "gamesPlayed", "highScore", "highScoreVegas"
    ]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) { withCleanDefaults(defaultsKeys, test) }
        isolated(testStandardScoringForEveryKindOfMove)
        isolated(testUndoTakesBackThePointsTheMoveEarned)
        isolated(testMoveLegality)
        isolated(testWasteReExposesOlderCardsAfterABatchIsPlayed)
        isolated(testDrawAndRecycleRules)
        isolated(testTimedWinBonusAndNoStressWin)
        isolated(testVegasBuyInWinningsAndLimits)
        isolated(testVegasRestartAndUndoKeepTheBankrollHonest)
        isolated(testVegasHighScoreAndDisplayStrings)
        isolated(testBankrollStartsAtZeroEachLaunch)
        isolated(testTogglingVegasMidGameBreaksStreakButNotGamesPlayed)
        isolated(testEnteringVegasChargesTheBuyInWhetherOrNotYouHadPlayed)
        isolated(testNoMovesLeftRules)
        isolated(testAutocompleteAvailabilityAndRun)
        isolated(testHintTexts)
        isolated(testHintCyclingAndNoRepeatOfLastMove)
        isolated(testKeyboardTopRowAndSelection)
        isolated(testKeyboardAutoMoveAndEmptyColumns)
        isolated(testBannersAndMilestones)
        isolated(testStatsSurviveRelaunchAndLegacyKeysWin)
        isolated(testOptionsPickerChangesRedealAndNoStressToggle)
    }

    // MARK: - Fixtures

    static let foundationSuits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]

    /// Replaces the dealt game with a hand-built board. `found` gives how many cards (A…n)
    /// each foundation already holds.
    static func board(_ vm: GameViewModel, tableau: [[Card]] = [], stock: [Card] = [], waste: [Card] = [],
                      found: [Card.Suit: Int] = [:], draw: GameState.DrawMode = .drawThree) {
        vm.state.drawMode = draw
        vm.state.tableau = (0..<7).map { i in
            Pile(id: "tableau_\(i)", type: .tableau, cards: i < tableau.count ? tableau[i] : [])
        }
        vm.state.foundations = foundationSuits.map { suit in
            Pile(id: "foundation_\(suit.rawValue)", type: .foundation,
                 cards: (found[suit] ?? 0) > 0 ? (1...(found[suit]!)).map { Card(suit: suit, rank: $0, faceUp: true) } : [])
        }
        vm.state.stock = Pile(id: "stock", type: .stock, cards: stock)
        vm.state.waste = Pile(id: "waste", type: .waste, cards: waste)
        vm.state.wasteDisplayCount = waste.isEmpty ? 0 : (draw == .drawOne ? 1 : min(3, waste.count))
        vm.state.score = vm.options.isVegasScoring ? -5200 : 0
        vm.state.movesCount = 0
        vm.state.timerSeconds = 0
        vm.state.isTimerActive = false
        vm.state.hasWon = false
        vm.state.recyclesCount = 0
        vm.isStuck = false
        vm.isStockExhausted = false
        vm.recycleCountAtStuck = nil
        vm.isAutocompleteAvailable = false
        vm.pointPopup = nil
        vm.clearHint()
    }

    /// Three lone kings: nothing in them can move, and they leave empty columns that only a king could use.
    static func kings3() -> [[Card]] {
        [[CovCards.card(.hearts, 13)], [CovCards.card(.diamonds, 13)], [CovCards.card(.clubs, 13)]]
    }

    /// Seven columns where nothing can move (no aces, no alternating-colour neighbours).
    static func deadTableau() -> [[Card]] {
        [[CovCards.card(.spades, 13)], [CovCards.card(.hearts, 13)], [CovCards.card(.diamonds, 13)],
         [CovCards.card(.clubs, 13)], [CovCards.card(.spades, 9)], [CovCards.card(.hearts, 7)],
         [CovCards.card(.spades, 5)]]
    }

    /// 51 cards done except the K♠, which sits alone in column 0.
    static func oneCardFromWinning(_ vm: GameViewModel) {
        board(vm, tableau: [[CovCards.card(.spades, 13)]], found: [.spades: 12, .clubs: 13, .diamonds: 13, .hearts: 13])
    }

    /// A view model that starts from a clean slate: view models load whatever the previous one
    /// saved, which would leak stats (and No Stress Mode) from one scenario into the next.
    static func freshVM() -> GameViewModel {
        for key in defaultsKeys + sharedGameOptionKeys { UserDefaults.standard.removeObject(forKey: key) }
        return GameViewModel()
    }

    static func setVegas(_ vm: GameViewModel, _ on: Bool) {
        var o = vm.options
        o.isVegasScoring = on
        vm.options = o
    }

    static func drain(_ vm: GameViewModel) -> Int {
        var n = 0
        while vm.flashBanner != nil { n += 1; vm.advanceBannerQueue(); if n > 50 { break } }
        return n
    }

    // MARK: - Scoring

    static func testStandardScoringForEveryKindOfMove() {
        let vm = GameViewModel()
        vm.sharedOptions.honeyMode = true

        // Waste → tableau: +5
        let five = CovCards.card(.hearts, 5)
        board(vm, tableau: [[CovCards.card(.spades, 6)]], waste: [five])
        vm.moveCards([five], from: vm.state.waste, to: vm.state.tableau[0])
        expect(vm.state.score == 5, "Waste → tableau scores +5, got \(vm.state.score)")
        expect(vm.pointPopup?.displayText == "+5" && vm.pointPopup?.cardId == five.id && vm.pointPopup?.isPositive == true,
               "...with a +5 popup on the moved card")

        // Waste → foundation: +10
        let ace = CovCards.card(.spades, 1)
        board(vm, waste: [ace])
        vm.moveCards([ace], from: vm.state.waste, to: vm.state.foundations[0])
        expect(vm.state.score == 10 && vm.pointPopup?.displayText == "+10", "Waste → foundation scores +10 (got \(vm.state.score))")

        // Tableau → foundation: +10, and a revealed card adds +5 (the popup shows the move's +10)
        let hidden = CovCards.card(.diamonds, 3, up: false)
        let aceC = CovCards.card(.clubs, 1)
        board(vm, tableau: [[hidden, aceC]])
        vm.moveCards([aceC], from: vm.state.tableau[0], to: vm.state.foundations[1])
        expect(vm.state.score == 15, "Tableau → foundation (+10) revealing a card (+5) = 15, got \(vm.state.score)")
        expect(vm.pointPopup?.displayText == "+10", "The popup shows the foundation move")
        expect(vm.state.tableau[0].cards.last?.faceUp == true, "Uncovered card turns face up")

        // Tableau → tableau that only reveals a card: +5, popup on the revealed card
        let nine = CovCards.card(.clubs, 9, up: false)
        let h5 = CovCards.card(.hearts, 5)
        board(vm, tableau: [[nine, h5], [CovCards.card(.spades, 6)]])
        vm.moveCards([h5], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.state.score == 5 && vm.pointPopup?.displayText == "+5" && vm.pointPopup?.cardId == nine.id,
               "Revealing a card scores +5 with the popup on the revealed card")

        // Tableau → tableau with nothing revealed: 0
        board(vm, tableau: [[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]])
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.state.score == 0 && vm.pointPopup == nil, "A plain tableau shuffle scores nothing")

        // Foundation → tableau: −15
        let two = CovCards.card(.spades, 2)
        board(vm, tableau: [[CovCards.card(.hearts, 3)]], found: [.spades: 1])
        vm.state.foundations[0].cards = [CovCards.card(.spades, 1), two]
        vm.moveCards([two], from: vm.state.foundations[0], to: vm.state.tableau[0])
        expect(vm.state.score == -15 && vm.pointPopup?.displayText == "-15" && vm.pointPopup?.isPositive == false,
               "Foundation → tableau costs 15 (got \(vm.state.score))")

        // Foundation → another (empty) foundation: free, no popup
        board(vm, found: [.spades: 1])
        vm.moveCards([vm.state.foundations[0].cards[0]], from: vm.state.foundations[0], to: vm.state.foundations[1])
        expect(vm.state.score == 0 && vm.state.foundations[1].cards.count == 1, "Shuffling an ace between foundations scores nothing")

        // Honey Mode off: no popups
        let quiet = GameViewModel()
        quiet.sharedOptions.honeyMode = false
        board(quiet, waste: [CovCards.card(.spades, 1)])
        quiet.moveCards([quiet.state.waste.cards[0]], from: quiet.state.waste, to: quiet.state.foundations[0])
        expect(quiet.pointPopup == nil, "No popup with Honey Mode off")
    }

    static func testUndoTakesBackThePointsTheMoveEarned() {
        let vm = GameViewModel()
        let five = CovCards.card(.hearts, 5)
        board(vm, tableau: [[CovCards.card(.spades, 6)]], waste: [five])
        vm.moveCards([five], from: vm.state.waste, to: vm.state.tableau[0])
        expect(vm.state.score == 5, "Move scored")
        vm.undoLastAction()
        expect(vm.state.score == -5, "Undo takes the 5 points back off on top of the revert (got \(vm.state.score))")
        expect(vm.state.waste.cards.map { $0.id } == [five.id] && vm.state.tableau[0].cards.count == 1, "Card back on the waste")
        expect(vm.state.wasteDisplayCount == 1, "Waste fan restored")
        expect(vm.pointPopup == nil && !vm.canUndo, "Popup cleared, nothing left to undo")

        // Undoing a move that COST points never turns into a bonus.
        let two = CovCards.card(.spades, 2)
        board(vm, tableau: [[CovCards.card(.hearts, 3)]], found: [.spades: 1])
        vm.state.foundations[0].cards = [CovCards.card(.spades, 1), two]
        vm.moveCards([two], from: vm.state.foundations[0], to: vm.state.tableau[0])
        expect(vm.state.score == -15, "Foundation retreat costs 15")
        vm.undoLastAction()
        expect(vm.state.score == 0, "Undoing a costly move restores the score, with no extra reward (got \(vm.state.score))")

        // Nothing to undo is harmless.
        vm.undoLastAction()
        expect(vm.state.score == 0, "Empty undo does nothing")
    }

    // MARK: - Rules

    static func testMoveLegality() {
        let vm = GameViewModel()
        board(vm, tableau: [[CovCards.card(.spades, 6)], []], found: [.hearts: 3])
        let t0 = vm.state.tableau[0], empty = vm.state.tableau[1]
        let h5 = CovCards.card(.hearts, 5), c5 = CovCards.card(.clubs, 5)
        expect(vm.isValidMove(cards: [h5], to: t0), "Red 5 on black 6")
        expect(!vm.isValidMove(cards: [c5], to: t0), "Black 5 can't go on black 6")
        expect(!vm.isValidMove(cards: [CovCards.card(.hearts, 4)], to: t0), "Wrong rank")
        expect(vm.isValidMove(cards: [CovCards.card(.hearts, 13)], to: empty), "A king may take an empty column")
        expect(!vm.isValidMove(cards: [CovCards.card(.hearts, 12)], to: empty), "Only kings may take an empty column")
        expect(!vm.isValidMove(cards: [], to: t0), "Empty drag is not a move")

        // Multi-card drags must themselves be alternating-colour runs.
        let run = [CovCards.card(.hearts, 5), CovCards.card(.clubs, 4)]
        expect(vm.isValidMove(cards: run, to: t0), "A valid run moves as one")
        let badRun = [CovCards.card(.hearts, 5), CovCards.card(.diamonds, 4)]
        expect(!vm.isValidMove(cards: badRun, to: t0), "Same-colour neighbours aren't a run")
        let gap = [CovCards.card(.hearts, 5), CovCards.card(.clubs, 3)]
        expect(!vm.isValidMove(cards: gap, to: t0), "Rank gap isn't a run")

        // Foundations: aces start any empty one, then same suit upward, one card at a time.
        let hearts = vm.state.foundations[3], spades = vm.state.foundations[0]
        expect(vm.isValidMove(cards: [CovCards.card(.hearts, 4)], to: hearts), "4♥ continues 3♥")
        expect(!vm.isValidMove(cards: [CovCards.card(.hearts, 5)], to: hearts), "Can't skip a rank")
        expect(!vm.isValidMove(cards: [CovCards.card(.spades, 4)], to: hearts), "Wrong suit")
        expect(vm.isValidMove(cards: [CovCards.card(.diamonds, 1)], to: spades), "Any ace may start an empty foundation")
        expect(!vm.isValidMove(cards: [CovCards.card(.diamonds, 2)], to: spades), "Only an ace starts a foundation")
        expect(!vm.isValidMove(cards: [CovCards.card(.hearts, 4), CovCards.card(.spades, 3)], to: hearts), "Foundations take one card at a time")
        expect(!vm.isValidMove(cards: [h5], to: vm.state.stock) && !vm.isValidMove(cards: [h5], to: vm.state.waste),
               "Can't drop on stock or waste")

        // A refused move changes nothing.
        let before = vm.state
        vm.moveCards([c5], from: vm.state.waste, to: t0)
        expect(vm.state == before, "Illegal moves are ignored")
    }

    static func testWasteReExposesOlderCardsAfterABatchIsPlayed() {
        let vm = GameViewModel()
        let played = CovCards.card(.hearts, 5)
        board(vm, tableau: [[CovCards.card(.spades, 6)]],
              waste: [CovCards.card(.clubs, 9), CovCards.card(.diamonds, 4), CovCards.card(.clubs, 8), played])
        vm.state.wasteDisplayCount = 1   // the last draw only added one card
        vm.moveCards([played], from: vm.state.waste, to: vm.state.tableau[0])
        expect(vm.state.wasteDisplayCount == 3, "Once a batch is used up the three cards beneath fan out again (got \(vm.state.wasteDisplayCount))")

        let one = GameViewModel()
        board(one, tableau: [[CovCards.card(.spades, 6)]], waste: [CovCards.card(.clubs, 9), played], draw: .drawOne)
        one.moveCards([played], from: one.state.waste, to: one.state.tableau[0])
        expect(one.state.wasteDisplayCount == 1, "Draw One shows just the next card")
    }

    static func testDrawAndRecycleRules() {
        let vm = GameViewModel()
        let stock = (1...7).map { CovCards.card(.clubs, $0, up: false) }
        board(vm, tableau: deadTableau(), stock: stock, draw: .drawThree)
        vm.drawCard()
        expect(vm.state.stock.cards.count == 4 && vm.state.waste.cards.count == 3 && vm.state.wasteDisplayCount == 3, "Draw Three takes three")
        expect(vm.state.waste.cards.map { $0.rank } == [7, 6, 5], "Cards are drawn from the end of the stock, 7 then 6 then 5 (top = 5)")
        expect(vm.state.movesCount == 1 && vm.hasDrawnFromStockThisGame, "A draw is a move")
        vm.drawCard()
        vm.drawCard()   // 1 card left: draws just that one
        expect(vm.state.stock.isEmpty && vm.state.waste.cards.count == 7 && vm.state.wasteDisplayCount == 1, "The last draw takes what's left")

        // Drawing from an empty stock recycles (it does not also draw).
        vm.drawCard()
        expect(vm.state.stock.cards.count == 7 && vm.state.waste.isEmpty && vm.state.recyclesCount == 1, "Recycle turns the waste back over")
        expect(vm.state.stock.cards.allSatisfy { !$0.faceUp }, "...face down")
        expect(vm.state.stock.cards.map { $0.rank } == [1, 2, 3, 4, 5, 6, 7],
               "...in the original order so the same cards come out again")
        vm.undoLastAction()
        expect(vm.state.stock.isEmpty && vm.state.waste.cards.count == 7 && vm.state.recyclesCount == 0, "Undo puts the recycle back")

        // Nothing to recycle: no-ops.
        let empty = GameViewModel()
        board(empty, tableau: deadTableau())
        empty.drawCard(); empty.recycleStock()
        expect(empty.state.movesCount == 0 && !empty.canUndo, "Drawing with an empty stock and waste does nothing")
        expect(!empty.canRecycleStock, "No waste, nothing to recycle")

        // Draw One draws one.
        let d1 = GameViewModel()
        board(d1, tableau: deadTableau(), stock: stock, draw: .drawOne)
        d1.drawCard()
        expect(d1.state.waste.cards.count == 1 && d1.state.stock.cards.count == 6, "Draw One takes one")

        // Standard play allows unlimited recycles; Vegas is limited by draw mode.
        expect(d1.maxRecycles == nil, "Standard play has no recycle limit")
        let v = GameViewModel()
        setVegas(v, true)
        expect(v.maxRecycles == 2, "Vegas Draw Three allows two recycles")
        var o3 = v.options; o3.drawMode = .drawOne; v.options = o3
        expect(v.maxRecycles == 0, "Vegas Draw One allows none")
        board(v, tableau: deadTableau(), waste: [CovCards.card(.clubs, 2)], draw: .drawOne)
        expect(!v.canRecycleStock, "Vegas Draw One can't recycle even with a waste pile")
        v.recycleStock()
        expect(v.state.waste.cards.count == 1 && v.state.recyclesCount == 0, "...and recycleStock refuses")
        v.drawCard()
        expect(v.state.waste.cards.count == 1 && v.state.movesCount == 0, "...and neither does drawing with an empty stock")
        var o1 = v.options; o1.drawMode = .drawThree; v.options = o1
        board(v, tableau: deadTableau(), waste: [CovCards.card(.clubs, 2)], draw: .drawThree)
        v.state.recyclesCount = 1
        expect(v.canRecycleStock, "Vegas Draw Three allows the second recycle")
        v.state.recyclesCount = 2
        expect(!v.canRecycleStock, "...but not a third")
    }

    // MARK: - Winning

    static func testTimedWinBonusAndNoStressWin() {
        // 100 s: −2 per 10 s, then +700,000 ÷ 100.
        var vm = freshVM()
        oneCardFromWinning(vm)
        vm.state.score = 500
        vm.state.timerSeconds = 100
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && !vm.state.isTimerActive, "Last card wins and stops the clock")
        expect(vm.state.score == 510 - 20 + 7000, "Timed bonus: 510 − 20 + 7000 = 7490, got \(vm.state.score)")
        expect(vm.highScore == 7490 && vm.statistics.gamesWon == 1, "High score and win recorded")
        expect(vm.statistics.shortestWinTime == 100 && vm.statistics.totalWinningTime == 100, "Time recorded")
        expect(!vm.canUndo, "No undo after a win")
        vm.undoLastAction()
        expect(vm.state.hasWon, "Undo can't reopen a won game")
        expect(GameViewModel().highScore == 7490, "High score survives a relaunch")

        // Very fast win: no 30 s minimum — 7 s still earns 700,000 ÷ 7.
        vm = freshVM()
        oneCardFromWinning(vm)
        vm.state.score = 500
        vm.state.timerSeconds = 7
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.score == 510 + 100000, "A 7 second win earns 700000/7 with no time penalty, got \(vm.state.score)")

        // The time penalty never takes the score below zero.
        vm = freshVM()
        oneCardFromWinning(vm)
        vm.state.score = 0
        vm.state.timerSeconds = 1_000_000
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.score == 0 + 0, "Penalty floors at zero before the bonus (700000/1000000 = 0), got \(vm.state.score)")

        // No Stress Mode: win counts, no time, no bonus.
        vm = freshVM()
        vm.sharedOptions.noStressMode = true
        oneCardFromWinning(vm)
        vm.state.score = 500
        vm.state.timerSeconds = 100
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && vm.state.score == 510, "No Stress win: no time bonus (got \(vm.state.score))")
        expect(vm.statistics.gamesWon == 1 && vm.statistics.winningGamesCount == 0 && vm.statistics.shortestWinTime == 0,
               "...and no time recorded")

        // Turning No Stress on partway taints the time too.
        vm = freshVM()
        board(vm, tableau: [[CovCards.card(.spades, 12)], [CovCards.card(.spades, 13)]], found: [.spades: 11, .clubs: 13, .diamonds: 13, .hearts: 13])
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.isTimerActive, "Clock started with the first move")
        vm.state.timerSeconds = 50
        vm.sharedOptions.noStressMode = true
        vm.reactToNoStressModeChange()
        expect(!vm.state.isTimerActive && vm.state.timerSeconds == 0, "No Stress on: clock stops and zeroes")
        vm.sharedOptions.noStressMode = false
        vm.reactToNoStressModeChange()
        expect(vm.state.isTimerActive, "No Stress off: clock restarts")
        vm.state.timerSeconds = 3
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.foundations[0])
        expect(vm.state.hasWon && vm.statistics.winningGamesCount == 0, "A part-untimed game records no best time")
        expect(vm.state.score == 20, "...and earns no time bonus (2 moves × 10), got \(vm.state.score)")

        // Not started yet → no clock.
        let fresh = freshVM()
        fresh.sharedOptions.noStressMode = true
        fresh.reactToNoStressModeChange()
        fresh.sharedOptions.noStressMode = false
        fresh.reactToNoStressModeChange()
        expect(!fresh.state.isTimerActive, "No clock before the first move")
    }

    // MARK: - Vegas

    static func testVegasBuyInWinningsAndLimits() {
        let vm = GameViewModel()
        setVegas(vm, true)
        expect(vm.state.score == -5200 && vm.vegasBankroll == -5200, "Entering Vegas buys in: score and bankroll −$52")
        expect(vm.statistics.gamesPlayed == 1, "Switching scoring mode isn't a new game played")

        // Each foundation card pays $5; taking one back costs $5; tableau moves are free.
        let ace = CovCards.card(.spades, 1), two = CovCards.card(.spades, 2)
        board(vm, tableau: [[CovCards.card(.hearts, 3)]], waste: [ace])
        vm.moveCards([ace], from: vm.state.waste, to: vm.state.foundations[0])
        expect(vm.state.score == -4700 && vm.vegasBankroll == -4700, "A foundation card pays $5")
        expect(vm.pointPopup?.displayText == "+$5", "...with a +$5 popup, got \(String(describing: vm.pointPopup?.displayText))")
        vm.state.foundations[0].cards.append(two)
        vm.moveCards([two], from: vm.state.foundations[0], to: vm.state.tableau[0])
        expect(vm.state.score == -5200 && vm.vegasBankroll == -5200, "Taking it back costs $5")
        expect(vm.pointPopup?.displayText == "-$5", "...with a -$5 popup")

        // Waste→tableau and reveals earn nothing in Vegas.
        let h5 = CovCards.card(.hearts, 5)
        board(vm, tableau: [[CovCards.card(.clubs, 9, up: false), CovCards.card(.spades, 6)]], waste: [h5])
        vm.moveCards([h5], from: vm.state.waste, to: vm.state.tableau[0])
        expect(vm.state.score == -5200, "No points for waste→tableau in Vegas")

        // Moving an ace between foundations can't farm money.
        board(vm, found: [.spades: 1])
        let before = vm.vegasBankroll
        vm.moveCards([vm.state.foundations[0].cards[0]], from: vm.state.foundations[0], to: vm.state.foundations[1])
        expect(vm.vegasBankroll == before, "Foundation → foundation pays nothing")

        // A new game charges another buy-in; Vegas has no time bonus on a win.
        let bankroll = vm.vegasBankroll
        vm.startNewGame()
        expect(vm.vegasBankroll == bankroll - 5200 && vm.state.score == -5200, "Each new game costs another $52")

        oneCardFromWinning(vm)
        vm.state.timerSeconds = 100
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && vm.state.score == -5200 + 500, "Vegas win has no time bonus (got \(vm.state.score))")
    }

    static func testVegasRestartAndUndoKeepTheBankrollHonest() {
        let vm = GameViewModel()
        setVegas(vm, true)
        let ace = CovCards.card(.spades, 1)
        board(vm, tableau: [[ace]])
        vm.moveCards([ace], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.vegasBankroll == -4700, "Earned $5")
        vm.undoLastAction()
        expect(vm.state.score == -5200 && vm.vegasBankroll == -5200, "Undo gives the $5 back, no penalty in Vegas")

        // Restarting an unwon game rolls back in-game gains and doesn't re-charge.
        board(vm, tableau: [[CovCards.card(.spades, 1)]])
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        vm.restartCurrentGame()
        expect(vm.vegasBankroll == -5200, "Restart of an unwon Vegas game: gains rolled back, buy-in stays paid (got \(vm.vegasBankroll))")
        expect(vm.state.score == -5200 && vm.statistics.gamesPlayed == 1, "...and not counted as another game")

        // Restarting a WON game charges a fresh buy-in and keeps the winnings.
        oneCardFromWinning(vm)
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.state.hasWon && vm.vegasBankroll == -4700, "Won: +$5")
        vm.restartCurrentGame()
        expect(vm.vegasBankroll == -4700 - 5200, "Restarting a won Vegas game: fresh buy-in on top of the winnings (got \(vm.vegasBankroll))")
        expect(vm.statistics.gamesPlayed == 2 && !vm.state.hasWon, "...and it counts as a new game played")
    }

    static func testVegasHighScoreAndDisplayStrings() {
        let vm = GameViewModel()
        vm.highScore = 40
        expect(vm.highScoreString == "40" && vm.scoreString == "0", "Standard scores are plain numbers")
        setVegas(vm, true)
        expect(vm.highScore == -5200, "Vegas starts with its own best score of −$52")
        expect(vm.scoreString.contains("$") && vm.scoreString.contains("52"), "Vegas score is money: \(vm.scoreString)")
        expect(vm.highScoreString.contains("$") && vm.vegasBankrollString.contains("52"), "Vegas high score and bankroll are money")
        vm.resetVegasBankroll()
        expect(vm.vegasBankroll == 0 && vm.vegasBankrollString.contains("0"), "Bankroll can be reset to $0")
        oneCardFromWinning(vm)
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.foundations[0])
        expect(vm.highScore == -4700, "Vegas best score updates on a win")
        setVegas(vm, false)
        expect(vm.highScore == 40, "Standard best score is kept separately (got \(vm.highScore))")
        expect(UserDefaults.standard.integer(forKey: "highScoreVegas") == -4700, "Vegas best is saved under its own key")

        vm.resetStatistics()
        expect(vm.highScore == 0 && UserDefaults.standard.object(forKey: "highScoreVegas") == nil,
               "Reset Stats clears both scoring modes' best scores")
    }

    static func testBankrollStartsAtZeroEachLaunch() {
        let vm = GameViewModel()
        setVegas(vm, true)
        vm.startNewGame(); vm.startNewGame()
        expect(vm.vegasBankroll == -15600, "Three buy-ins in one session")
        let relaunched = GameViewModel()
        expect(relaunched.options.isVegasScoring, "Vegas mode itself is remembered")
        expect(relaunched.vegasBankroll == -5200, "...but the bankroll starts from $0 each launch (only the first deal's buy-in), got \(relaunched.vegasBankroll)")
    }

    static func testTogglingVegasMidGameBreaksStreakButNotGamesPlayed() {
        let vm = GameViewModel()
        var s = vm.statistics; s.currentStreak = 3; s.longestStreak = 3; vm.statistics = s
        board(vm, tableau: [[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]])
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        let played = vm.gamesPlayed
        setVegas(vm, true)
        expect(vm.statistics.currentStreak == 0 && vm.statistics.longestStreak == 3, "Abandoning a played game by switching scoring breaks the streak")
        expect(vm.gamesPlayed == played, "...without counting a new game played")
    }

    // Regression: switching Vegas on AFTER playing a standard game used to skip the $52 buy-in
    // (score showed −$52.00 but the bankroll stayed at $0.00), while doing it on an untouched
    // game charged it correctly.
    static func testEnteringVegasChargesTheBuyInWhetherOrNotYouHadPlayed() {
        let untouched = freshVM()
        setVegas(untouched, true)
        expect(untouched.state.score == -5200 && untouched.vegasBankroll == -5200, "Untouched game: Vegas charges the buy-in")

        let played = freshVM()
        board(played, tableau: [[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]])
        played.moveCards([played.state.tableau[0].cards[0]], from: played.state.tableau[0], to: played.state.tableau[1])
        expect(played.state.movesCount == 1, "A move was made in standard play")
        setVegas(played, true)
        expect(played.state.score == -5200, "Score shows the buy-in")
        expect(played.vegasBankroll == -5200, "...and the bankroll is charged it too, even after playing (got \(played.vegasBankroll))")

        // The bankroll then tracks the score as usual, and leaving Vegas zeroes it.
        let ace = CovCards.card(.spades, 1)
        board(played, tableau: [[ace]])
        played.moveCards([ace], from: played.state.tableau[0], to: played.state.foundations[0])
        expect(played.vegasBankroll == -4700, "A foundation card pays $5 on top of the buy-in")
        setVegas(played, false)
        expect(played.vegasBankroll == 0, "Leaving Vegas clears the bankroll")
    }

    // MARK: - No moves left

    static func testNoMovesLeftRules() {
        // Nothing playable and nothing left to draw or recycle → stuck at once.
        var vm = GameViewModel()
        board(vm, tableau: deadTableau())
        vm.checkStuckState()
        expect(vm.isStockExhausted && vm.isStuck, "No moves and no stock/waste: stuck immediately")

        // Any legal move means not stuck.
        board(vm, tableau: [[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]] + Array(deadTableau().dropFirst(2)))
        vm.checkStuckState()
        expect(!vm.isStuck, "A legal progressive move: not stuck")

        // A playable card still in the stock: not stuck.
        board(vm, tableau: deadTableau(), stock: [CovCards.card(.spades, 1, up: false)])
        vm.checkStuckState()
        expect(!vm.isStuck, "An ace waiting in the stock is a move")

        // Dead stock, standard play: only flagged after the player recycles past the first detection.
        vm = GameViewModel()
        board(vm, tableau: deadTableau(), stock: [CovCards.card(.hearts, 2, up: false)])
        vm.checkStuckState()
        expect(!vm.isStuck && vm.recycleCountAtStuck == 0, "First detection remembers where we were but doesn't flag")
        vm.drawCard()
        expect(!vm.isStuck, "Not stuck on the first pass through the stock")
        vm.drawCard()   // recycles
        expect(vm.state.recyclesCount == 1, "Recycled once")
        vm.drawCard()   // draws the 2♥ again
        expect(vm.isStuck, "Stuck once the stock has been recycled past the first detection")

        // Vegas: never stuck while another pass is allowed; stuck once passes run out.
        vm = GameViewModel()
        setVegas(vm, true)
        board(vm, tableau: deadTableau(), stock: [CovCards.card(.hearts, 2, up: false)])
        vm.checkStuckState()
        expect(!vm.isStuck, "Vegas with cards left to deal: not stuck")
        board(vm, tableau: deadTableau(), waste: [CovCards.card(.hearts, 2)])
        vm.checkStuckState()
        expect(!vm.isStuck, "Vegas with a pass remaining: never stuck")
        vm.state.recyclesCount = 2
        vm.checkStuckState()
        expect(vm.isStockExhausted && vm.isStuck, "Vegas with no passes left: stuck")

        // A won game is never stuck.
        board(vm, tableau: deadTableau())
        vm.state.hasWon = true
        vm.checkStuckState()
        expect(!vm.isStuck && !vm.isStockExhausted, "Won games are not stuck")
    }

    // MARK: - Autocomplete

    static func testAutocompleteAvailabilityAndRun() {
        let vm = GameViewModel()
        oneCardFromWinning(vm)
        vm.checkAutocompleteState()
        expect(vm.isAutocompleteAvailable, "Everything face up, stock/waste empty: Autocomplete offered")
        vm.checkStuckState()
        expect(!vm.isStuck, "An Autocomplete-able game isn't stuck")

        // A face-down card, cards still in the stock, or cards in the waste → not offered.
        board(vm, tableau: [[CovCards.card(.spades, 13, up: false)]], found: [.spades: 12, .clubs: 13, .diamonds: 13, .hearts: 13])
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Face-down card → not offered")
        board(vm, tableau: [[CovCards.card(.spades, 12)]], stock: [CovCards.card(.spades, 13, up: false)],
              found: [.spades: 11, .clubs: 13, .diamonds: 13, .hearts: 13])
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Cards in the stock → not offered")
        board(vm, tableau: [[CovCards.card(.spades, 12)]], waste: [CovCards.card(.spades, 13)],
              found: [.spades: 11, .clubs: 13, .diamonds: 13, .hearts: 13])
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Cards in the waste → not offered")
        vm.runAutocomplete()
        expect(!vm.isAutoplayRunning, "Autocomplete does nothing when it isn't offered")

        // Two kings to go: both are played automatically and the game is won.
        board(vm, tableau: [[CovCards.card(.spades, 13)], [CovCards.card(.clubs, 13)]],
              found: [.spades: 12, .clubs: 12, .diamonds: 13, .hearts: 13])
        vm.checkAutocompleteState()
        vm.runAutocomplete()
        expect(vm.isAutoplayRunning, "Autocomplete starts")
        pumpRunLoop(timeout: 3) { vm.state.hasWon && !vm.isAutoplayRunning }
        expect(vm.state.hasWon && !vm.isAutoplayRunning, "Autocomplete plays the game out and stops")
        expect(vm.state.score == 20 && vm.statistics.gamesWon == 1, "Two foundation moves scored, win recorded (score \(vm.state.score))")
    }

    // MARK: - Hints

    static func hintFor(_ vm: GameViewModel) -> GameViewModel.HintMove? {
        vm.clearHint()
        _ = vm.findHint()
        return vm.activeHint
    }

    /// Hint text without its "[1/2] " cycling prefix. (A playable waste card also gets a second,
    /// lower-ranked "Recycle" suggestion, so hints on such boards are numbered.)
    static func unnumbered(_ hint: GameViewModel.HintMove?) -> String {
        guard var t = hint?.description else { return "nil" }
        if t.hasPrefix("["), let r = t.range(of: "] ") { t = String(t[r.upperBound...]) }
        return t
    }

    static func testHintTexts() {
        let vm = GameViewModel()

        board(vm, tableau: kings3(), waste: [CovCards.card(.spades, 2)], found: [.spades: 1])
        var h = hintFor(vm)
        expect(unnumbered(h) == "Move 2♠ from Waste to Foundation." && h?.sourcePileId == "waste" && h?.targetPileId == "foundation_spades",
               "Waste→foundation hint: \(h?.description ?? "nil")")

        board(vm, tableau: [[CovCards.card(.spades, 2)]] + kings3(), found: [.spades: 1])
        h = hintFor(vm)
        expect(h?.description == "Move 2♠ to Foundation." && h?.targetPileId == "foundation_spades", "Tableau→foundation hint: \(h?.description ?? "nil")")

        board(vm, tableau: [[CovCards.card(.spades, 6)]] + kings3(), waste: [CovCards.card(.hearts, 5)])
        h = hintFor(vm)
        expect(unnumbered(h) == "Move 5♥ from Waste to Tableau." && h?.targetPileId == "tableau_0", "Waste→tableau hint: \(h?.description ?? "nil")")

        board(vm, tableau: [[CovCards.card(.clubs, 9, up: false), CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]] + kings3())
        h = hintFor(vm)
        expect(h?.description == "Move 5♥ — Reveal 1 face-down card." && h?.sourcePileId == "tableau_0" && h?.targetPileId == "tableau_1",
               "Reveal hint: \(h?.description ?? "nil")")

        // Playable card hiding in the stock → "Draw from Stock".
        board(vm, tableau: kings3(), stock: [CovCards.card(.spades, 1, up: false)])
        h = hintFor(vm)
        expect(h?.description == "Draw from Stock pile." && h?.sourcePileId == "stock", "Draw hint: \(h?.description ?? "nil")")

        // Playable card buried in the waste → "Recycle".
        board(vm, tableau: kings3(), waste: [CovCards.card(.spades, 1), CovCards.card(.clubs, 9)], draw: .drawOne)
        h = hintFor(vm)
        expect(h?.description == "Recycle Waste pile to Stock." && h?.sourcePileId == "waste" && h?.targetPileId == "stock", "Recycle hint: \(h?.description ?? "nil")")

        // Foundation moves past the twos rank as "safe" only once the other-colour foundations have caught up;
        // either way the move is offered.
        board(vm, tableau: [[CovCards.card(.spades, 3)]] + kings3(), found: [.spades: 2, .hearts: 2, .diamonds: 2])
        h = hintFor(vm)
        expect(unnumbered(h) == "Move 3♠ to Foundation.", "Safe foundation hint: \(h?.description ?? "nil")")
        board(vm, tableau: [[CovCards.card(.spades, 3)]] + kings3(), found: [.spades: 2])
        h = hintFor(vm)
        expect(unnumbered(h) == "Move 3♠ to Foundation.", "Not-yet-safe foundation hint is still offered: \(h?.description ?? "nil")")

        // Nothing at all (the stock card can never be played).
        board(vm, tableau: kings3(), stock: [CovCards.card(.hearts, 2, up: false)])
        vm.clearHint()
        expect(!vm.findHint(), "findHint reports failure when no hint exists")
        expect(vm.activeHint?.description == "No such luck, friend! Try a new game!", "No-moves message: \(vm.activeHint?.description ?? "nil")")
        vm.clearHint()
        expect(vm.activeHint == nil, "clearHint removes it")
    }

    static func testHintCyclingAndNoRepeatOfLastMove() {
        let vm = GameViewModel()
        // 5♥ can go on either black six → two hints.
        board(vm, tableau: [[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)], [CovCards.card(.clubs, 6)]] + kings3())
        expect(vm.findHint(), "Hint found")
        let first = vm.activeHint!.description
        expect(first.hasPrefix("[1/2] "), "Cycling hints are numbered: \(first)")
        _ = vm.findHint()
        expect(vm.activeHint!.description.hasPrefix("[2/2] ") && vm.activeHint!.description != first, "Next hint")
        _ = vm.findHint()
        expect(vm.activeHint!.description.hasPrefix("[1/2] "), "...and wraps")
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.activeHint == nil, "A move clears the hint")

        // Stock/waste operations clear hints too.
        board(vm, tableau: kings3(), stock: [CovCards.card(.spades, 1, up: false), CovCards.card(.hearts, 2, up: false)])
        _ = vm.findHint()
        expect(vm.activeHint != nil, "Hint showing")
        vm.drawCard()
        expect(vm.activeHint == nil, "Drawing clears the hint")
        board(vm, tableau: kings3(), waste: [CovCards.card(.clubs, 2)])
        _ = vm.findHint()
        expect(vm.activeHint != nil, "Hint showing")
        vm.recycleStock()
        expect(vm.activeHint == nil, "Recycling clears the hint")
        board(vm, tableau: kings3(), waste: [CovCards.card(.clubs, 2)])
        _ = vm.findHint()
        vm.startNewGame()
        expect(vm.activeHint == nil, "A new game clears the hint")
    }

    // MARK: - Keyboard

    static func testKeyboardTopRowAndSelection() {
        let vm = GameViewModel()
        board(vm, tableau: [[CovCards.card(.spades, 6)], [CovCards.card(.hearts, 3)]] + Array(deadTableau().dropFirst(2)),
              stock: [CovCards.card(.diamonds, 9, up: false)], waste: [CovCards.card(.hearts, 5)])
        vm.state.foundations[0].cards = [CovCards.card(.spades, 1), CovCards.card(.spades, 2)]

        vm.moveCursorLeft()
        expect(vm.activeCursor?.pileId == "foundation_hearts", "Left from the stock wraps to the last foundation")
        vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "stock", "...and right wraps back to the stock")
        vm.moveCursorRight(); vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "foundation_spades", "The blank slot between waste and foundations is skipped going right")
        vm.moveCursorLeft()
        expect(vm.activeCursor?.pileId == "waste", "...and going left")

        // Select the waste's 5♥ and drop it on column 0's 6♠.
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "waste", "Space picks up the waste card")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil, "Space again puts it down")
        vm.performSpaceAction()
        vm.moveCursorDown()
        expect(vm.activeCursor?.pileId == "tableau_0", "Down goes to the first column")
        vm.performSpaceAction()
        expect(vm.state.tableau[0].cards.map { $0.rank } == [6, 5] && vm.state.score == 5, "Space drops it: waste → tableau")
        expect(vm.selectedCardsSource == nil, "Selection cleared")

        // Up from a tableau column returns to the matching top-row slot.
        vm.moveCursorRight(); vm.moveCursorRight(); vm.moveCursorRight()   // column 3
        vm.moveCursorRight()                                                 // column 4
        vm.moveCursorUp()
        expect(vm.activeCursor?.pileId == "foundation_clubs", "Up from column 4 lands on the second foundation")
        vm.moveCursorDown()
        expect(vm.activeCursor?.pileId == "tableau_4", "Down comes back to column 4")
        vm.moveCursorLeft(); vm.moveCursorLeft(); vm.moveCursorLeft(); vm.moveCursorLeft()
        vm.moveCursorLeft()
        expect(vm.activeCursor?.pileId == "tableau_6", "Left from the first column wraps to the last")
        vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "tableau_0", "Right from the last column wraps to the first")

        // Walk up/down inside a column of face-up cards.
        vm.moveCursorUp()
        expect(vm.activeCursor?.cardIndex == 0 || vm.activeCursor?.pileId == "stock", "Up inside column 0 or out to the stock")
        vm.moveCursorDown()
        vm.moveCursorDown()
        expect(vm.activeCursor?.cardIndex == 1, "Down walks to the column's top card")

        // Pick a card up off a foundation and put it on a tableau column.
        vm.clearKeyboardCursor()
        vm.state.tableau[1].cards = [CovCards.card(.hearts, 3)]
        vm.moveCursorRight(); vm.moveCursorRight()   // first foundation
        expect(vm.activeCursor?.pileId == "foundation_spades", "On the spades foundation")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "foundation_spades" && vm.selectedCardsIndex == 1, "Foundation top card picked up")
        vm.moveCursorDown(); vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "tableau_1", "Moved to column 1")
        vm.performSpaceAction()
        expect(vm.state.tableau[1].cards.map { $0.rank } == [3, 2] && vm.state.foundations[0].cards.count == 1, "2♠ moves from the foundation onto the red 3")
        expect(vm.state.score == 5 - 15, "...and costs 15")

        // Space on the stock draws; Space on an empty stock recycles.
        vm.clearKeyboardCursor()
        vm.enableKeyboardCursorIfNeeded()
        vm.performSpaceAction()
        expect(vm.state.stock.isEmpty && vm.state.waste.cards.last?.rank == 9, "Space on the stock draws")
        vm.performSpaceAction()
        expect(vm.state.stock.cards.count >= 1 && vm.state.recyclesCount == 1, "Space on an empty stock recycles the waste")
        vm.enableKeyboardCursorIfNeeded()
    }

    static func testKeyboardAutoMoveAndEmptyColumns() {
        let vm = GameViewModel()
        board(vm, tableau: [[CovCards.card(.diamonds, 7, up: false), CovCards.card(.spades, 1)], []],
              waste: [CovCards.card(.clubs, 1)])
        // Auto-move from a tableau column
        vm.moveCursorDown()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_0", cardIndex: 1), "Cursor on column 0's top card")
        vm.autoMoveFocusedCardToFoundations()
        expect(vm.state.foundations.contains { $0.cards.contains { $0.suit == .spades && $0.rank == 1 } }, "A♠ jumps to a foundation")
        expect(vm.state.tableau[0].cards.last?.faceUp == true && vm.state.score == 15, "...revealing the card beneath (+10 +5)")
        // Auto-move from the waste
        vm.clearKeyboardCursor()
        vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "waste", "Cursor on the waste")
        vm.autoMoveFocusedCardToFoundations()
        expect(vm.state.waste.isEmpty && vm.state.score == 25, "A♣ from the waste goes up too")
        // Nothing to auto-move from a foundation / stock
        vm.moveCursorRight()
        let score = vm.state.score
        vm.autoMoveFocusedCardToFoundations()
        expect(vm.state.score == score, "Auto-move from a foundation does nothing")

        // The next Autocomplete move: waste first, then the columns, otherwise none.
        board(vm, tableau: kings3(), waste: [CovCards.card(.spades, 1)])
        let fromWaste = vm.findNextFoundationMove()
        expect(fromWaste?.card.rank == 1 && fromWaste?.source.id == "waste", "Autocomplete takes the waste card first")
        board(vm, tableau: [[CovCards.card(.clubs, 1)]] + kings3())
        expect(vm.findNextFoundationMove()?.source.id == "tableau_0", "...then a column's top card")
        board(vm, tableau: kings3())
        expect(vm.findNextFoundationMove() == nil, "...and nothing when nothing can go up")

        // Pick up a run from a column with Space and drop it on another column.
        board(vm, tableau: [[CovCards.card(.clubs, 9, up: false), CovCards.card(.diamonds, 7), CovCards.card(.spades, 6)], [CovCards.card(.clubs, 8)]])
        vm.clearKeyboardCursor()
        vm.moveCursorDown()
        vm.moveCursorUp()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_0", cardIndex: 1), "Cursor walks up onto the 7♦")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "tableau_0" && vm.selectedCardsIndex == 1, "Space picks up the 7♦ and everything on it")
        vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.state.tableau[1].cards.map { $0.rank } == [8, 7, 6] && vm.state.tableau[0].cards.count == 1 && vm.state.tableau[0].cards[0].faceUp,
               "The run lands on the 8♣ and the 9♣ underneath flips")
        // A selection whose pile has vanished is dropped safely.
        vm.selectedCardsSource = "tableau_gone"
        vm.selectedCardsIndex = 0
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil && vm.selectedCardsIndex == nil, "A stale selection is cleared")

        // Cursor over an empty column has no card; Space there does nothing.
        board(vm, tableau: [[CovCards.card(.diamonds, 7)], []])
        vm.clearKeyboardCursor()
        vm.moveCursorDown()
        vm.moveCursorRight()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_1", cardIndex: nil), "Empty column: cursor without a card")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil, "Nothing to pick up from an empty column")
        vm.moveCursorUp()
        expect(vm.activeCursor?.pileId == "waste", "Up from column 1 lands on the waste")
        // Selecting something and then dropping on a pile that isn't there clears it safely.
        vm.clearKeyboardCursor()
        expect(vm.activeCursor == nil && vm.selectedCardsIndex == nil, "Cursor cleared")
    }

    // MARK: - Banners & stats

    static func testBannersAndMilestones() {
        let vm = GameViewModel()
        expect(drain(vm) == 1, "The very first game shows the welcome banner once")
        vm.checkLoadingBanner()
        _ = drain(vm)
        vm.checkLoadingBanner()
        expect(drain(vm) == 0, "The loading banner fires once per session")

        vm.gamesWon = 9
        vm.recordWin(timeInSeconds: 30)
        expect(vm.flashBanner != nil, "10th win shows the milestone banner")
        let t = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t + 1, "A banner that was never shown is re-announced when the board returns")
        expect(drain(vm) == 1, "One banner")
        vm.recordWin(timeInSeconds: 30)
        expect(drain(vm) == 0, "11th win: no repeat")
        let t2 = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t2, "Nothing to replay")
        vm.scheduleIdleActionCheck()
        vm.cancelIdleActionCheck()

        // Stats numbers
        vm.recordWin(timeInSeconds: 0)
        expect(vm.statistics.gamesWon == 12 && vm.statistics.currentStreak == 3, "Wins and streak accumulate")
        expect(vm.statistics.winningGamesCount == 2 && vm.statistics.shortestWinTime == 30 && vm.statistics.averageWinningTime == 30,
               "Only timed wins feed the time stats: \(vm.statistics)")
        expect(vm.statistics.winPercentage > 0 && GameStatistics().winPercentage == 0 && GameStatistics().averageWinningTime == 0,
               "Win percentage/average are safe when empty")
    }

    static func testStatsSurviveRelaunchAndLegacyKeysWin() {
        UserDefaults.standard.set(7, forKey: "gamesWon")
        UserDefaults.standard.set(12, forKey: "gamesPlayed")
        let vm = GameViewModel()
        expect(vm.gamesWon == 7 && vm.gamesPlayed == 13, "Old-style saved counts are picked up (13 = 12 + this launch's deal)")
        vm.gamesWon = 8
        expect(UserDefaults.standard.integer(forKey: "gamesWon") == 8, "Setting a count also writes the key older versions read")
        vm.recordWin(timeInSeconds: 45)
        let relaunched = GameViewModel()
        expect(relaunched.statistics.shortestWinTime == 45 && relaunched.statistics.longestStreak == 1 && relaunched.gamesWon == 9,
               "Win time, streak and count survive a relaunch")
        // An unreadable saved blob falls back to fresh stats rather than crashing.
        UserDefaults.standard.set(Data("garbage".utf8), forKey: "solitaire_statistics")
        UserDefaults.standard.set(Data("garbage".utf8), forKey: "solitaire_options")
        let recovered = GameViewModel()
        expect(recovered.options == GameOptions() && recovered.statistics.longestStreak == 0, "Corrupt saves fall back to defaults")
    }

    static func testOptionsPickerChangesRedealAndNoStressToggle() {
        let vm = GameViewModel()
        let ids = vm.state.stock.cards.map { $0.id }
        var o = vm.options
        o.drawMode = .drawOne
        vm.options = o
        expect(vm.state.drawMode == .drawOne, "Changing Draw mode in options applies to the board")
        expect(vm.state.stock.cards.map { $0.id } != ids, "...by dealing a new game")
        expect(GameViewModel().options.drawMode == .drawOne && GameViewModel().state.drawMode == .drawOne, "...and is remembered")
        // Idempotent when the board already matches.
        let again = vm.state.stock.cards.map { $0.id }
        vm.options = vm.options
        expect(vm.state.stock.cards.map { $0.id } == again, "Re-saving identical options doesn't re-deal")

        // The status-bar toggle persists too.
        var hidden = vm.options; hidden.isStatusBarVisible = false; vm.options = hidden
        expect(GameViewModel().options.isStatusBarVisible == false, "Status bar visibility is remembered")
    }
}
