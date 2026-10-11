import Foundation

// Player-visible Spider behaviour on fixed card layouts: the deal, stock dealing, the move
// rule, completed runs, winning, stats/streaks, undo, stuck detection, Autocomplete, hints,
// double-click and keyboard play. Every board is hand-built (no random deals) except where
// a test only needs "a freshly dealt game".
struct SpiderGameplayTests {
    static func run() {
        UISound.isHeadlessMode = true
        // Each test starts from a fresh install (no saved Spider options/stats) so stats
        // assertions cannot be polluted by an earlier test in this suite.
        let keys = ["spider_options", "spider_statistics"]
        func isolated(_ test: () -> Void) { withCleanDefaults(keys, test) }
        isolated(testDealLayoutForEachSuitCount)
        isolated(testStockDealRules)
        isolated(testDealingTheLastRowCanLeaveTheBoardStuck)
        isolated(testMoveRulesAndUndo)
        isolated(testMovedCardsFlipTheNextCardAndEmptyColumnsAcceptAnything)
        isolated(testCompletedRunGoesToFoundationAndScoresPoints)
        isolated(testMixedSuitRunIsNotRemoved)
        isolated(testWinRecordsStatsAndLocksUndo)
        isolated(testWinInNoStressModeRecordsNoTimeAndKeepsHigherHighScore)
        isolated(testTogglingNoStressMidGameTaintsTheTime)
        isolated(testStatsAccumulateAndStayPerSuitMode)
        isolated(testStreakRulesForNewGameUndoRestart)
        isolated(testRestartRules)
        isolated(testWinMilestoneBannerFiresOnlyOnTheTenthWin)
        isolated(testFirstLaunchAndLoadingBanners)
        isolated(testUndoBehaviour)
        isolated(testStuckDetection)
        isolated(testAutocompleteOfferedOnlyWhenItFinishesTheGame)
        isolated(testAutocompleteRunsToAWin)
        isolated(testUndoDuringAutocompleteReversesItInOneStep)
        isolated(testHintSuggestsRevealingMove)
        isolated(testHintSuggestsEmptyColumnMoves)
        isolated(testHintPrefersSameSuitAndCycles)
        isolated(testHintFallbacksAndStockHints)
        isolated(testHintDoesNotSuggestUndoingTheLastMove)
        isolated(testHintClearsWhenTheBoardChanges)
        isolated(testDoubleClickPicksTheBestTarget)
        isolated(testKeyboardNavigationAndSelection)
        isolated(testPointPopups)
    }

    // MARK: - Fixtures

    /// Replaces the dealt game with a hand-built board. `cols` fills columns 0… in order
    /// (remaining columns empty); `doneRuns` pre-fills that many foundations with a full
    /// spade K→A run.
    static func board(_ vm: SpiderViewModel, _ cols: [[Card]], stock: [Card] = [], doneRuns: Int = 0) {
        vm.state.tableau = (0..<10).map { i in
            Pile(id: "tableau_\(i)", type: .tableau, cards: i < cols.count ? cols[i] : [])
        }
        vm.state.stock = Pile(id: "stock", type: .stock, cards: stock)
        vm.state.foundations = (0..<8).map { i in
            Pile(id: "foundation_\(i)", type: .foundation,
                 cards: i < doneRuns ? CovCards.run(.spades, from: 13, through: 1) : [])
        }
        vm.state.score = 500
        vm.state.movesCount = 0
        vm.state.timerSeconds = 0
        vm.state.isTimerActive = false
        vm.state.hasWon = false
        vm.isStuck = false
        vm.isAutocompleteAvailable = false
    }

    /// A kings-only filler column so a layout has no empty column and nothing can move onto it.
    static func king() -> [Card] { [CovCards.card(.diamonds, 13)] }

    /// Columns 0… from `cols`, padded with filler king columns up to 10 columns.
    static func padded(_ cols: [[Card]]) -> [[Card]] {
        cols + (cols.count..<10).map { _ in king() }
    }

    /// The last row of a win: seven finished foundations, K→2 spades in column 0, the ace in column 1.
    static func oneMoveFromWinning(_ vm: SpiderViewModel) {
        board(vm, [CovCards.run(.spades, from: 13, through: 2), [CovCards.card(.spades, 1)]], doneRuns: 7)
    }

    static func tableauIds(_ vm: SpiderViewModel) -> [[UUID]] {
        vm.state.tableau.map { $0.cards.map { $0.id } }
    }

    static func drainBanners(_ vm: SpiderViewModel) -> Int {
        var n = 0
        while vm.flashBanner != nil { n += 1; vm.advanceBannerQueue(); if n > 50 { break } }
        return n
    }

    static func modeStats(_ vm: SpiderViewModel, _ suits: Int = 1) -> SpiderModeStats {
        vm.statistics.statsBySuits[suits] ?? SpiderModeStats()
    }

    // MARK: - Deal

    static func testDealLayoutForEachSuitCount() {
        let vm = SpiderViewModel()
        for suits in [1, 2, 4] {
            var opts = vm.options
            opts.suitCount = suits
            vm.options = opts

            expect(vm.state.tableau.count == 10, "Spider (\(suits) suit) must deal 10 columns")
            for (i, pile) in vm.state.tableau.enumerated() {
                let want = i < 4 ? 6 : 5
                expect(pile.cards.count == want, "Column \(i) should be dealt \(want) cards, got \(pile.cards.count)")
                expect(pile.cards.last?.faceUp == true, "Column \(i)'s top card must be face up")
                expect(pile.cards.dropLast().allSatisfy { !$0.faceUp }, "Column \(i)'s other cards must be face down")
            }
            expect(vm.state.stock.cards.count == 50 && vm.state.stock.cards.allSatisfy { !$0.faceUp },
                   "Stock must hold 50 face-down cards")
            expect(vm.state.foundations.count == 8 && vm.state.foundations.allSatisfy { $0.isEmpty },
                   "Eight empty foundations at the start")
            expect(vm.state.score == 500 && vm.state.movesCount == 0 && !vm.state.hasWon, "Fresh game: 500 points, no moves")

            let all = vm.state.tableau.flatMap { $0.cards } + vm.state.stock.cards
            expect(all.count == 104 && Set(all.map { $0.id }).count == 104, "104 distinct cards")
            expect(Set(all.map { $0.suit }).count == suits, "\(suits)-suit game must use exactly \(suits) suit(s)")
            var counts: [String: Int] = [:]
            for c in all { counts["\(c.suit.rawValue)\(c.rank)", default: 0] += 1 }
            expect(counts.values.allSatisfy { $0 == 8 / suits }, "Each (suit, rank) must appear \(8 / suits) times in a \(suits)-suit game")
        }
        // The two suit-count switches each dealt a game in the NEW mode.
        expect(modeStats(vm, 2).gamesPlayed == 1 && modeStats(vm, 4).gamesPlayed == 1,
               "Switching suit count deals (and counts) a new game in the new mode")
        // Saved options survive a relaunch.
        expect(SpiderViewModel().options.suitCount == 4, "Chosen suit count must persist across relaunch")
    }

    // MARK: - Stock

    static func testStockDealRules() {
        let vm = SpiderViewModel()
        let stock = (0..<20).map { CovCards.card(.hearts, 1 + $0 % 13, up: false) }
        board(vm, (0..<10).map { _ in king() }, stock: stock)
        let willGoToColumn0 = vm.state.stock.cards.last!

        vm.drawFromStock()
        expect(vm.state.stock.cards.count == 10, "A stock deal uses 10 cards")
        expect(vm.state.tableau.allSatisfy { $0.cards.count == 2 && $0.cards.last!.faceUp }, "Each column gets one face-up card")
        expect(vm.state.tableau[0].cards.last!.id == willGoToColumn0.id, "The top of the stock goes to the first column")
        expect(vm.state.score == 499 && vm.state.movesCount == 1, "A stock deal costs 1 point and counts as a move")
        expect(vm.canUndo, "A stock deal can be undone")

        vm.undoLastAction()
        expect(vm.state.stock.cards.count == 20 && vm.state.tableau.allSatisfy { $0.cards.count == 1 },
               "Undo puts the dealt row back on the stock")
        expect(vm.state.score == 500 && vm.state.movesCount == 0, "Undo restores score and moves")

        // Rule: no dealing while any column is empty.
        let blocked = SpiderViewModel()
        board(blocked, (0..<10).map { $0 == 3 ? [] : king() }, stock: stock)
        blocked.drawFromStock()
        expect(blocked.state.stock.cards.count == 20 && blocked.state.movesCount == 0 && !blocked.canUndo,
               "Dealing is refused while a column is empty")

        // An empty stock does nothing.
        let drained = SpiderViewModel()
        board(drained, (0..<10).map { _ in king() }, stock: [])
        drained.drawFromStock()
        expect(drained.state.movesCount == 0 && drained.state.score == 500, "Dealing from an empty stock does nothing")

        // The score never goes below zero.
        let broke = SpiderViewModel()
        board(broke, (0..<10).map { _ in king() }, stock: stock)
        broke.state.score = 0
        broke.drawFromStock()
        expect(broke.state.score == 0, "Score never goes negative")
    }

    static func testDealingTheLastRowCanLeaveTheBoardStuck() {
        let vm = SpiderViewModel()
        // Every column is a lone king and the last row is ten more kings: nothing can move
        // afterwards, the stock is empty and there is no empty column to use.
        board(vm, (0..<10).map { _ in king() },
              stock: (0..<10).map { _ in CovCards.card(.spades, 13, up: false) })
        vm.drawFromStock()
        expect(vm.state.stock.isEmpty, "Last row dealt")
        expect(vm.isStuck, "No legal move left after the final deal → stuck")
        expect(!vm.isAutocompleteAvailable, "Autocomplete can't finish a stuck board")
    }

    // MARK: - Moves

    static func testMoveRulesAndUndo() {
        let vm = SpiderViewModel()
        let five = CovCards.card(.hearts, 5)
        let nine = CovCards.card(.clubs, 9, up: false)
        let six = CovCards.card(.spades, 6)
        board(vm, padded([[nine, five], [six], []]))
        let before = tableauIds(vm)

        // Any suit may go on a card exactly one rank higher.
        vm.moveCards([five], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.state.tableau[1].cards.map { $0.id } == [six.id, five.id], "5♥ lands on 6♠ (suit doesn't matter)")
        expect(vm.state.tableau[0].cards.count == 1 && vm.state.tableau[0].cards[0].faceUp, "The card left behind is turned face up")
        expect(vm.state.score == 499 && vm.state.movesCount == 1, "A move costs 1 point")

        // The wrong rank is refused: nothing changes, nothing to undo for it.
        let snapshot = tableauIds(vm)
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(tableauIds(vm) == snapshot && vm.state.movesCount == 1, "9♣ can't go onto 5♥")

        // Only tableau columns are legal targets.
        expect(!vm.isValidMove(cards: [five], to: vm.state.foundations[0]), "Can't drop on a foundation")
        expect(!vm.isValidMove(cards: [five], to: vm.state.stock), "Can't drop on the stock")
        expect(!vm.isValidMove(cards: [], to: vm.state.tableau[1]), "Nothing to move is not a move")

        vm.undoLastAction()
        expect(tableauIds(vm) == before, "Undo restores the exact layout")
        expect(!vm.state.tableau[0].cards[0].faceUp, "...including the card that had been flipped face down again")
        expect(vm.state.score == 500 && vm.state.movesCount == 0 && !vm.canUndo, "Undo restores score/moves; nothing left to undo")
    }

    static func testMovedCardsFlipTheNextCardAndEmptyColumnsAcceptAnything() {
        let vm = SpiderViewModel()
        // Drag validity
        let s6 = CovCards.card(.spades, 6), s5 = CovCards.card(.spades, 5), h4 = CovCards.card(.hearts, 4)
        expect(vm.isValidDragSequence([s6, s5]), "Same-suit descending run can be dragged")
        expect(!vm.isValidDragSequence([s6, h4]), "Mixed suits can't be dragged together")
        expect(!vm.isValidDragSequence([s5, s6]), "Ascending cards can't be dragged together")
        expect(!vm.isValidDragSequence([]), "An empty drag is invalid")
        expect(!vm.isValidDragSequence([CovCards.card(.spades, 6, up: false)]), "A face-down card can't be dragged")
        expect(!vm.isValidDragSequence([s6, CovCards.card(.spades, 5, up: false)]), "A run containing a face-down card can't be dragged")

        // A whole run moves into an empty column, and the card it uncovers turns face up.
        board(vm, padded([[CovCards.card(.clubs, 9, up: false), s6, s5], [], []]))
        vm.moveCards([s6, s5], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.state.tableau[1].cards.map { $0.id } == [s6.id, s5.id], "A two-card run moves to an empty column")
        expect(vm.state.tableau[0].cards.count == 1 && vm.state.tableau[0].cards[0].faceUp, "Uncovered card flips")
        // Any single card — even a king-less odd one — may take an empty column.
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[2])
        expect(vm.state.tableau[2].cards.count == 1 && vm.state.tableau[0].isEmpty, "Any card may go to an empty column")
    }

    // MARK: - Completed runs

    static func testCompletedRunGoesToFoundationAndScoresPoints() {
        let vm = SpiderViewModel()
        let hidden = CovCards.card(.hearts, 2, up: false)
        let ace = CovCards.card(.spades, 1)
        board(vm, padded([[hidden] + CovCards.run(.spades, from: 13, through: 2), [ace]]))

        vm.moveCards([ace], from: vm.state.tableau[1], to: vm.state.tableau[0])

        expect(vm.state.foundations[0].cards.count == 13, "The finished K→A run moves to a foundation")
        expect(vm.state.foundations[0].cards.first?.rank == 13 && vm.state.foundations[0].cards.last?.rank == 1, "Run is stored K…A")
        expect(vm.state.tableau[0].cards.map { $0.id } == [hidden.id] && vm.state.tableau[0].cards[0].faceUp,
               "The card under the run is revealed")
        expect(vm.state.score == 500 - 1 + 100, "A move costs 1, a finished run earns 100 (got \(vm.state.score))")
        expect(!vm.state.hasWon, "One run is not a win")

        vm.undoLastAction()
        expect(vm.state.foundations.allSatisfy { $0.isEmpty }, "Undo takes the run back off the foundation")
        expect(vm.state.tableau[0].cards.count == 13 && vm.state.tableau[1].cards.count == 1 && vm.state.score == 500, "...and restores the columns and the score")
    }

    static func testMixedSuitRunIsNotRemoved() {
        let vm = SpiderViewModel()
        let ace = CovCards.card(.hearts, 1)
        board(vm, padded([CovCards.run(.spades, from: 13, through: 2), [ace]]))
        vm.moveCards([ace], from: vm.state.tableau[1], to: vm.state.tableau[0])
        expect(vm.state.tableau[0].cards.count == 13, "A K→A pile of mixed suits stays on the board")
        expect(vm.state.foundations.allSatisfy { $0.isEmpty } && vm.state.score == 499, "No foundation, no bonus")
    }

    // MARK: - Winning & stats

    static func testWinRecordsStatsAndLocksUndo() {
        let vm = SpiderViewModel()
        oneMoveFromWinning(vm)
        vm.state.timerSeconds = 100
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.tableau[0])

        expect(vm.state.hasWon, "The eighth finished run wins the game")
        expect(!vm.state.isTimerActive, "The clock stops on a win")
        expect(vm.state.foundations.reduce(0) { $0 + $1.cards.count } == 104, "All 104 cards on the foundations")
        let s = modeStats(vm)
        expect(s.gamesWon == 1 && s.currentStreak == 1 && s.longestStreak == 1, "Win counted with a 1-win streak")
        expect(s.totalWinningTime == 100 && s.winningGamesCount == 1 && s.shortestWinTime == 100 && s.averageWinningTime == 100,
               "Win time recorded (got \(s))")
        expect(vm.highScore == 599, "High score becomes the winning score 599, got \(vm.highScore)")
        expect(vm.highScoreString == "599" && vm.scoreString == "599", "Score strings")
        expect(!vm.canUndo, "Undo is locked once the game is won")
        vm.undoLastAction()
        expect(vm.state.hasWon, "Undo does nothing after a win")

        // Stats were saved: a relaunch sees the win.
        let relaunched = SpiderViewModel()
        expect(modeStats(relaunched).gamesWon == 1 && modeStats(relaunched).shortestWinTime == 100, "Win survives a relaunch")
        expect(relaunched.gamesWon == 1 && relaunched.highScore == 599 && relaunched.shortestWinTime == 100, "Accessors read the saved mode stats")
        expect(relaunched.averageWinningTime == 100, "Average win time survives relaunch")
    }

    static func testWinInNoStressModeRecordsNoTimeAndKeepsHigherHighScore() {
        let vm = SpiderViewModel()
        vm.sharedOptions.noStressMode = true
        vm.highScore = 700
        oneMoveFromWinning(vm)
        vm.state.timerSeconds = 100
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.tableau[0])
        let s = modeStats(vm)
        expect(vm.state.hasWon && s.gamesWon == 1, "A No Stress win still counts as a win")
        expect(s.winningGamesCount == 0 && s.totalWinningTime == 0 && s.shortestWinTime == 0,
               "...but records no time (got \(s))")
        expect(vm.highScore == 700, "A lower score doesn't replace the high score")
        expect(!vm.state.isTimerActive, "No clock runs in No Stress Mode")
    }

    static func testTogglingNoStressMidGameTaintsTheTime() {
        let vm = SpiderViewModel()
        board(vm, padded([CovCards.run(.spades, from: 13, through: 3), [CovCards.card(.spades, 2)], [CovCards.card(.spades, 1)]]),
              doneRuns: 7)
        // vm has no coordinator here, so the toggle's reaction is invoked by hand.
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.tableau[0])
        expect(vm.state.isTimerActive, "The first move starts the clock")
        vm.state.timerSeconds = 42

        vm.sharedOptions.noStressMode = true
        vm.reactToNoStressModeChange()
        expect(!vm.state.isTimerActive && vm.state.timerSeconds == 0, "Turning No Stress on mid-game stops and zeroes the clock")

        vm.sharedOptions.noStressMode = false
        vm.reactToNoStressModeChange()
        expect(vm.state.isTimerActive, "Turning it off again restarts the clock")

        vm.moveCards([vm.state.tableau[2].cards[0]], from: vm.state.tableau[2], to: vm.state.tableau[0])
        expect(vm.state.hasWon, "Game won")
        expect(modeStats(vm).gamesWon == 1 && modeStats(vm).winningGamesCount == 0 && modeStats(vm).shortestWinTime == 0,
               "A game that was part untimed records no best time")

        // Toggling on a game that hasn't started leaves the clock alone.
        let fresh = SpiderViewModel()
        fresh.sharedOptions.noStressMode = true
        fresh.reactToNoStressModeChange()
        fresh.sharedOptions.noStressMode = false
        fresh.reactToNoStressModeChange()
        expect(!fresh.state.isTimerActive, "No clock before the first move")
    }

    static func testStatsAccumulateAndStayPerSuitMode() {
        let vm = SpiderViewModel()
        vm.recordWin(timeInSeconds: 120)
        vm.recordWin(timeInSeconds: 90)
        vm.recordWin(timeInSeconds: 0)
        let s = modeStats(vm)
        expect(s.gamesWon == 3 && s.currentStreak == 3 && s.longestStreak == 3, "Three wins, streak 3")
        expect(s.winningGamesCount == 2 && s.totalWinningTime == 210 && s.shortestWinTime == 90 && s.averageWinningTime == 105,
               "Only timed wins count towards time stats (got \(s))")
        expect(vm.shortestWinTime == 90 && vm.averageWinningTime == 105 && vm.gamesWon == 3, "View-model accessors agree")

        // A different suit count keeps its own stats.
        var o = vm.options; o.suitCount = 2; vm.options = o
        expect(vm.gamesWon == 0 && modeStats(vm, 1).gamesWon == 3, "2-suit stats are separate from 1-suit stats")
        vm.recordWin(timeInSeconds: 60)
        expect(vm.gamesWon == 1 && modeStats(vm, 1).gamesWon == 3, "A 2-suit win doesn't touch 1-suit stats")
        expect(vm.currentModeStats.winPercentage == 100.0 * 1.0 / Double(max(1, vm.gamesPlayed)), "Win percentage = won / played")

        vm.resetStatistics()
        expect(modeStats(vm, 2) == SpiderModeStats(), "Reset clears the current mode")
        expect(modeStats(vm, 1).gamesWon == 3, "...and only the current mode")
        expect(SpiderModeStats().winPercentage == 0 && SpiderModeStats().averageWinningTime == 0, "Empty stats have no division by zero")

        // Setters used by the stats screen write through to the right mode.
        vm.gamesPlayed = 7; vm.gamesWon = 2; vm.highScore = 650
        expect(modeStats(vm, 2).gamesPlayed == 7 && modeStats(vm, 2).gamesWon == 2 && modeStats(vm, 2).highScore == 650,
               "Setters write the current mode's stats")
    }

    static func testStreakRulesForNewGameUndoRestart() {
        func primed(streak: Int) -> SpiderViewModel {
            let vm = SpiderViewModel()
            var s = vm.statistics
            s.statsBySuits[1] = SpiderModeStats(currentStreak: streak, longestStreak: streak)
            vm.statistics = s
            return vm
        }
        func playOneMove(_ vm: SpiderViewModel) {
            board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]))
            vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        }

        let untouched = primed(streak: 4)
        untouched.startNewGame()
        expect(modeStats(untouched).currentStreak == 4, "Dealing a new game before moving doesn't break the streak")

        let played = primed(streak: 4)
        playOneMove(played)
        played.startNewGame()
        expect(modeStats(played).currentStreak == 0 && modeStats(played).longestStreak == 4,
               "Abandoning a played game breaks the current streak but keeps the best")

        let undone = primed(streak: 4)
        playOneMove(undone)
        undone.undoLastAction()
        undone.startNewGame()
        expect(modeStats(undone).currentStreak == 0, "Undo-to-start can't dodge the streak break")

        let restarted = primed(streak: 4)
        playOneMove(restarted)
        restarted.restartCurrentGame()
        restarted.startNewGame()
        expect(modeStats(restarted).currentStreak == 0, "Restart can't dodge the streak break")

        let won = primed(streak: 0)
        oneMoveFromWinning(won)
        won.moveCards([won.state.tableau[1].cards[0]], from: won.state.tableau[1], to: won.state.tableau[0])
        won.startNewGame()
        expect(modeStats(won).currentStreak == 1, "Starting a new game after a win keeps the streak")
        expect(modeStats(won).gamesPlayed == 1, "The new game counts as one more game played")
    }

    static func testRestartRules() {
        let vm = SpiderViewModel()
        let initialTableau = tableauIds(vm)
        let initialStock = vm.state.stock.cards.map { $0.id }
        let generation = vm.gameGeneration
        let played = vm.gamesPlayed

        vm.drawFromStock()
        expect(vm.state.stock.cards.count == 40, "Dealt a row")
        vm.restartCurrentGame()
        expect(tableauIds(vm) == initialTableau && vm.state.stock.cards.map { $0.id } == initialStock, "Restart replays the same deal")
        expect(vm.state.score == 500 && vm.state.movesCount == 0 && !vm.canUndo, "Restart resets score, moves and undo")
        expect(vm.gamesPlayed == played, "Restarting an unwon game doesn't count another game")
        expect(vm.gameGeneration == generation + 1, "Restart bumps the deal generation so the view re-fits")

        // Restarting a WON game counts as a new game played.
        oneMoveFromWinning(vm)
        vm.moveCards([vm.state.tableau[1].cards[0]], from: vm.state.tableau[1], to: vm.state.tableau[0])
        expect(vm.state.hasWon, "Won")
        let playedAtWin = vm.gamesPlayed
        vm.restartCurrentGame()
        expect(!vm.state.hasWon && vm.gamesPlayed == playedAtWin + 1, "Restarting a won game counts as a new game played")
        expect(modeStats(vm).currentStreak == 1, "...and doesn't break the win streak")
    }

    // MARK: - Banners

    static func testWinMilestoneBannerFiresOnlyOnTheTenthWin() {
        let vm = SpiderViewModel()
        _ = drainBanners(vm)
        var s = vm.statistics
        s.statsBySuits[1] = SpiderModeStats(gamesPlayed: 6, gamesWon: 6)
        s.statsBySuits[2] = SpiderModeStats(gamesPlayed: 3, gamesWon: 3)
        vm.statistics = s

        vm.recordWin(timeInSeconds: 50)   // 10th win across both modes
        expect(vm.flashBanner != nil, "The 10th win (across all suit modes) shows a milestone banner")
        let shown = drainBanners(vm)
        expect(shown == 1, "Exactly one banner for the 10th win, got \(shown)")

        vm.recordWin(timeInSeconds: 50)   // 11th
        expect(drainBanners(vm) == 0, "The 11th win doesn't repeat the milestone")

        // With two banners waiting, dismissing the first brings up the second.
        var more = vm.statistics
        more.statsBySuits[1] = SpiderModeStats(gamesPlayed: 20, gamesWon: 99)
        vm.statistics = more
        vm.recordWin(timeInSeconds: 5)   // 100th win
        vm.checkLoadingBanner()
        let waiting = vm.flashBanner != nil
        let triggerBefore = vm.flashBannerTrigger
        vm.advanceBannerQueue()
        if vm.flashBanner != nil { expect(vm.flashBannerTrigger == triggerBefore + 1, "The next waiting banner is announced") }
        expect(waiting, "The 100th win queued a milestone")
        _ = drainBanners(vm)

        vm.advanceBannerQueue()  // empty queue: must be harmless
        expect(vm.flashBanner == nil, "Empty queue stays empty")
    }

    static func testFirstLaunchAndLoadingBanners() {
        // Fresh install (no spider stats): dealing the very first game shows the welcome banner.
        let vm = SpiderViewModel()
        let welcome = drainBanners(vm)
        expect(welcome == 1, "First-ever game shows exactly one welcome banner, got \(welcome)")

        vm.checkLoadingBanner()
        let loading = drainBanners(vm)
        vm.checkLoadingBanner()
        expect(drainBanners(vm) == 0, "The loading banner fires at most once per session (first time \(loading))")

        // A banner that was never shown (the player was on another game) is re-announced.
        vm.recordWin(timeInSeconds: 10)
        var s = vm.statistics
        s.statsBySuits[1] = SpiderModeStats(gamesPlayed: 9, gamesWon: 9)
        vm.statistics = s
        vm.recordWin(timeInSeconds: 10)
        expect(vm.flashBanner != nil, "Milestone banner queued")
        let t = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t + 1, "Returning to the game re-announces the waiting banner")
        _ = drainBanners(vm)
        let t2 = vm.flashBannerTrigger
        vm.replayCurrentBanner()
        expect(vm.flashBannerTrigger == t2, "Nothing to re-announce with an empty queue")

        // Idle nudge plumbing is safe to call (timers are disabled in headless mode).
        vm.scheduleIdleActionCheck()
        vm.cancelIdleActionCheck()
    }

    // MARK: - Undo

    static func testUndoBehaviour() {
        let vm = SpiderViewModel()
        vm.undoLastAction()
        expect(vm.state.movesCount == 0 && !vm.canUndo, "Undo with nothing to undo is harmless")

        let stock = (0..<10).map { _ in CovCards.card(.hearts, 3, up: false) }
        board(vm, padded([[CovCards.card(.clubs, 9), CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]), stock: stock)
        let start = tableauIds(vm)
        vm.moveCards([vm.state.tableau[0].cards[1]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        vm.drawFromStock()
        vm.state.timerSeconds = 30
        expect(vm.state.movesCount == 2 && vm.canUndo, "Two moves made")

        vm.findHint()
        vm.undoLastAction()
        expect(vm.activeHint == nil, "Undo clears a showing hint")
        expect(vm.state.timerSeconds == 30, "The clock keeps running forward through an undo")
        expect(vm.state.stock.cards.count == 10 && vm.state.movesCount == 1, "Undo reverses only the stock deal")
        vm.undoLastAction()
        expect(tableauIds(vm) == start && vm.state.movesCount == 0, "Second undo reverses the card move")
        expect(!vm.canUndo, "Undo history is exhausted")

        // The history is bounded (100 steps) rather than growing forever. Shuttle the 5♥
        // between two sixes 110 times (a one-card stock keeps Autocomplete from simulating).
        let shuttle = SpiderViewModel()
        board(shuttle, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)], [CovCards.card(.diamonds, 6)]]),
              stock: [CovCards.card(.hearts, 2, up: false)])
        var at = 0
        for i in 0..<110 {
            let dst = i % 2 == 0 ? 1 : 2
            let card = shuttle.state.tableau[at].cards.last!
            shuttle.moveCards([card], from: shuttle.state.tableau[at], to: shuttle.state.tableau[dst])
            at = dst
        }
        var undos = 0
        while shuttle.canUndo && undos < 500 { shuttle.undoLastAction(); undos += 1 }
        expect(undos == 100, "Undo remembers the last 100 moves, got \(undos)")
    }

    // MARK: - Stuck

    static func testStuckDetection() {
        let vm = SpiderViewModel()
        board(vm, (0..<10).map { _ in king() })
        vm.checkStuckState()
        expect(vm.isStuck, "Ten lone kings, no stock, no empty column: stuck")

        board(vm, (0..<10).map { _ in king() }, stock: [CovCards.card(.spades, 2, up: false)])
        vm.checkStuckState()
        expect(!vm.isStuck, "A dealable stock means not stuck")

        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]))
        vm.checkStuckState()
        expect(!vm.isStuck, "A legal move means not stuck")

        board(vm, (0..<10).map { _ in king() })
        vm.state.hasWon = true
        vm.checkStuckState()
        expect(!vm.isStuck, "A won game is never stuck")

        // After the player's own move leaves nothing, the flag is raised by the move itself.
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]))
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.isStuck == false, "Empty column 0 can still take cards, so not stuck")
        vm.undoLastAction()
        expect(!vm.isStuck, "Undo clears the stuck flag")
    }

    // MARK: - Autocomplete

    static func testAutocompleteOfferedOnlyWhenItFinishesTheGame() {
        let vm = SpiderViewModel()

        // Cards still in the stock → never offered.
        board(vm, [CovCards.run(.spades, from: 13, through: 2), [CovCards.card(.spades, 1)]],
              stock: [CovCards.card(.hearts, 1, up: false)], doneRuns: 7)
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Not offered while the stock still has cards")

        // Stock empty and the rest can be sorted out → offered.
        oneMoveFromWinning(vm)
        vm.checkAutocompleteState()
        expect(vm.isAutocompleteAvailable, "Offered when simulating it finishes the game")
        vm.checkStuckState()
        expect(!vm.isStuck, "An Autocomplete-able board is never reported as stuck")

        // Stock empty but it can't be finished → not offered.
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 13)]]))
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Not offered when the game can't be finished")

        // Pressing Autocomplete when it isn't offered does nothing.
        vm.runAutocomplete()
        expect(!vm.isAutoplayRunning && vm.state.movesCount == 0, "runAutocomplete is a no-op when unavailable")

        // All foundations already full → nothing to offer.
        board(vm, [], doneRuns: 8)
        vm.checkAutocompleteState()
        expect(!vm.isAutocompleteAvailable, "Nothing to autocomplete on a finished board")
    }

    static func testAutocompleteRunsToAWin() {
        let vm = SpiderViewModel()
        // 2♠ must hop onto the 3♠, then the A♠ onto the 2♠ to finish the eighth run.
        board(vm, [CovCards.run(.spades, from: 13, through: 3), [CovCards.card(.spades, 2)], [CovCards.card(.spades, 1)]],
              doneRuns: 7)
        vm.checkAutocompleteState()
        expect(vm.isAutocompleteAvailable, "Two-step finish is offered")
        vm.runAutocomplete()
        expect(vm.isAutoplayRunning, "Autocomplete is running")
        pumpRunLoop(timeout: 3) { vm.state.hasWon && !vm.isAutoplayRunning }
        expect(vm.state.hasWon, "Autocomplete played the game out to a win")
        expect(!vm.isAutoplayRunning, "Autocomplete stops when the game is won")
        expect(modeStats(vm).gamesWon == 1, "The win was recorded")
        expect(vm.state.score == 500 - 2 + 100, "Two autoplayed moves cost 2 points and the run earns 100 (got \(vm.state.score))")
    }

    static func testUndoDuringAutocompleteReversesItInOneStep() {
        let vm = SpiderViewModel()
        board(vm, [CovCards.run(.spades, from: 13, through: 3), [CovCards.card(.spades, 2)], [CovCards.card(.spades, 1)]],
              doneRuns: 7)
        let start = tableauIds(vm)
        vm.checkAutocompleteState()
        vm.runAutocomplete()
        expect(vm.state.tableau[0].cards.count == 12, "First autoplay move happens immediately")
        vm.undoLastAction()
        expect(!vm.isAutoplayRunning, "Undo stops Autocomplete")
        expect(tableauIds(vm) == start && vm.state.score == 500, "Undo puts the board back before Autocomplete began")
        // The pending animation step must not carry on after the undo.
        pumpRunLoop(timeout: 0.4) { false }
        expect(tableauIds(vm) == start, "Autocomplete doesn't resume after an undo")
    }

    // MARK: - Hints

    static func testHintSuggestsRevealingMove() {
        let vm = SpiderViewModel()
        board(vm, padded([[CovCards.card(.clubs, 9, up: false), CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]))
        expect(vm.activeHint == nil && !vm.activeHintIsFillEmptyColumns, "No hint showing at the start")
        expect(vm.findHint(), "A move exists, so Hint finds one")
        guard let hint = vm.activeHint else { fatalError("❌ Hint produced no activeHint") }
        expect(hint.sourcePileId == "tableau_0" && hint.targetPileId == "tableau_1", "Hint says move 5♥ from column 0 to column 1")
        expect(hint.card.rank == 5 && hint.card.suit == .hearts, "Hint points at the 5♥")
        expect(hint.description.contains("5♥") && hint.description.contains("6♠") && hint.description.contains("Reveal"),
               "Hint text names the cards and the reveal: \(hint.description)")
        vm.clearHint()
        expect(vm.activeHint == nil, "clearHint removes the hint")
    }

    static func testHintSuggestsEmptyColumnMoves() {
        let vm = SpiderViewModel()
        // A face-down card is waiting under the 5♥: parking it on the empty column reveals it.
        board(vm, [[CovCards.card(.clubs, 9, up: false), CovCards.card(.hearts, 5)], []] + (2..<10).map { _ in king() })
        expect(vm.findHint(), "Hint found")
        expect(vm.activeHint?.description == "Move 5♥ to empty column — Reveal 1 face-down card." && vm.activeHint?.targetPileId == "tableau_1",
               "Reveal-by-parking hint: \(vm.activeHint?.description ?? "nil")")
        vm.clearHint()
        // Nothing to reveal, but breaking up a mixed-suit stack onto the empty column is still offered.
        board(vm, [[CovCards.card(.clubs, 9), CovCards.card(.hearts, 5)], []] + (2..<10).map { _ in king() })
        expect(vm.findHint(), "Hint found")
        expect(vm.activeHint?.description == "Move 5♥ sequence to empty column.", "Park hint: \(vm.activeHint?.description ?? "nil")")
        vm.clearHint()
    }

    static func testHintPrefersSameSuitAndCycles() {
        let vm = SpiderViewModel()
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)], [CovCards.card(.hearts, 6)]]))
        expect(vm.findHint(), "Hint found")
        let first = vm.activeHint!
        expect(first.targetPileId == "tableau_2", "Same-suit placement (5♥ on 6♥) is suggested first")
        expect(first.description.hasPrefix("[1/2] "), "Hint is numbered 1 of 2: \(first.description)")
        expect(first.description.contains("Move 5♥ onto 6♥"), "Same-suit wording: \(first.description)")

        expect(vm.findHint(), "Asking again cycles to the next hint")
        let second = vm.activeHint!
        expect(second.description.hasPrefix("[2/2] ") && second.targetPileId == "tableau_1", "Second hint: 5♥ on 6♠ (\(second.description))")
        expect(vm.findHint(), "Cycle continues")
        expect(vm.activeHint!.description.hasPrefix("[1/2] "), "...and wraps around")
        vm.clearHint()
    }

    static func testHintFallbacksAndStockHints() {
        let vm = SpiderViewModel()

        board(vm, (0..<10).map { _ in king() })
        expect(!vm.findHint(), "With no moves at all Hint reports failure")
        expect(vm.activeHint?.description.contains("No moves available") == true, "...with a 'no moves' message")
        expect(vm.activeHint?.sourcePileId == "" && vm.activeHint?.targetPileId == "", "...pointing at no pile")
        vm.clearHint()

        board(vm, (0..<10).map { _ in king() }, stock: [CovCards.card(.hearts, 2, up: false)])
        expect(vm.findHint(), "With only a deal left Hint suggests it")
        expect(vm.activeHint?.sourcePileId == "stock" && vm.activeHint?.description.contains("Deal") == true, "Hint says to deal from the stock")
        expect(!vm.activeHintIsFillEmptyColumns, "...which is not the fill-columns blocker")
        vm.clearHint()

        // An empty column blocks dealing → the hint is the "fill every empty column" message.
        board(vm, [[]] + (1..<10).map { _ in king() }, stock: [CovCards.card(.hearts, 2, up: false)])
        expect(vm.findHint(), "Hint found")
        expect(vm.activeHintIsFillEmptyColumns, "Hint reports that every empty column must be filled before dealing")
        expect(vm.activeHint?.description.contains("Fill all empty columns") == true, "...with the fill-columns text")
        vm.clearHint()
    }

    static func testHintDoesNotSuggestUndoingTheLastMove() {
        let vm = SpiderViewModel()
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)], [CovCards.card(.diamonds, 7)], [CovCards.card(.clubs, 6)]]))
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        var seen: [Spider_Hint] = []
        for _ in 0..<6 {
            _ = vm.findHint()
            if let h = vm.activeHint { seen.append(Spider_Hint(source: h.sourcePileId, target: h.targetPileId)) }
        }
        expect(!seen.isEmpty, "There are other moves to suggest")
        expect(!seen.contains(where: { $0.source == "tableau_1" && $0.target == "tableau_0" }),
               "Hint never suggests simply moving the card straight back")
        vm.clearHint()
    }

    struct Spider_Hint { let source: String; let target: String }

    static func testHintClearsWhenTheBoardChanges() {
        let vm = SpiderViewModel()
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]), stock: [CovCards.card(.hearts, 2, up: false)])
        _ = vm.findHint()
        expect(vm.activeHint != nil, "Hint showing")
        vm.moveCards([vm.state.tableau[0].cards[0]], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.activeHint == nil, "A move clears the hint")

        let vm2 = SpiderViewModel()
        board(vm2, (0..<10).map { _ in king() }, stock: (0..<10).map { _ in CovCards.card(.hearts, 2, up: false) })
        _ = vm2.findHint()
        vm2.drawFromStock()
        expect(vm2.activeHint == nil, "Dealing clears the hint")
        _ = vm2.findHint()
        vm2.startNewGame()
        expect(vm2.activeHint == nil, "A new game clears the hint")
    }

    // MARK: - Double-click

    static func testDoubleClickPicksTheBestTarget() {
        // 1) Same-suit build beats a different-suit build.
        var vm = SpiderViewModel()
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)], [CovCards.card(.hearts, 6)]]))
        vm.doubleClickMove(card: vm.state.tableau[0].cards[0], from: vm.state.tableau[0])
        expect(vm.state.tableau[2].cards.count == 2 && vm.state.tableau[0].isEmpty, "Double-click prefers the same-suit target")

        // 2) Otherwise any card one rank higher.
        vm = SpiderViewModel()
        board(vm, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]))
        vm.doubleClickMove(card: vm.state.tableau[0].cards[0], from: vm.state.tableau[0])
        expect(vm.state.tableau[1].cards.count == 2, "Double-click falls back to a different-suit target")

        // 3) Otherwise an empty column; the uncovered card flips.
        vm = SpiderViewModel()
        board(vm, [[CovCards.card(.clubs, 9, up: false), CovCards.card(.hearts, 5)], king(), []] + (3..<10).map { _ in king() })
        vm.doubleClickMove(card: vm.state.tableau[0].cards[1], from: vm.state.tableau[0])
        expect(vm.state.tableau[2].cards.count == 1 && vm.state.tableau[0].cards.count == 1 && vm.state.tableau[0].cards[0].faceUp,
               "Double-click falls back to an empty column")

        // 4) Face-down cards, broken runs and dead ends do nothing.
        vm = SpiderViewModel()
        board(vm, [[CovCards.card(.clubs, 9, up: false), CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6), CovCards.card(.hearts, 5)]]
                  + (2..<10).map { _ in king() })
        vm.doubleClickMove(card: vm.state.tableau[0].cards[0], from: vm.state.tableau[0])
        expect(vm.state.movesCount == 0, "Double-clicking a face-down card does nothing")
        vm.doubleClickMove(card: vm.state.tableau[1].cards[0], from: vm.state.tableau[1])
        expect(vm.state.movesCount == 0, "Double-clicking a mixed-suit stack does nothing")
        vm.doubleClickMove(card: vm.state.tableau[5].cards[0], from: vm.state.tableau[5])
        expect(vm.state.movesCount == 0, "Double-clicking a card with nowhere to go does nothing")
    }

    // MARK: - Keyboard

    static func testKeyboardNavigationAndSelection() {
        let vm = SpiderViewModel()
        let col0 = [CovCards.card(.diamonds, 9, up: false), CovCards.card(.spades, 4), CovCards.card(.spades, 3), CovCards.card(.spades, 2)]
        board(vm, [col0, [CovCards.card(.hearts, 3)]] + (2..<10).map { _ in king() },
              stock: (0..<10).map { _ in CovCards.card(.hearts, 2, up: false) })

        expect(vm.activeCursor == nil, "No cursor until the keyboard is used")
        vm.moveCursorDown()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_0", cardIndex: 3), "Down from the stock lands on column 0's top card")
        vm.moveCursorUp()
        vm.moveCursorUp()
        expect(vm.activeCursor?.cardIndex == 1, "Up walks through face-up cards")
        vm.moveCursorUp()
        expect(vm.activeCursor?.pileId == "stock", "Up past the first face-up card goes to the stock")
        vm.moveCursorLeft()   // on the stock row, sideways does nothing
        expect(vm.activeCursor?.pileId == "stock", "Left/right do nothing on the stock row")
        vm.moveCursorDown()
        vm.moveCursorDown()   // already on the top card: stays
        expect(vm.activeCursor?.cardIndex == 3, "Back down to the top card")
        vm.moveCursorUp()
        vm.moveCursorDown()
        expect(vm.activeCursor?.cardIndex == 3, "Down walks back down a column")

        vm.moveCursorLeft()
        expect(vm.activeCursor?.pileId == "tableau_9", "Left from column 0 wraps to column 9")
        vm.moveCursorRight()
        expect(vm.activeCursor?.pileId == "tableau_0", "Right from column 9 wraps to column 0")
        vm.moveCursorRight()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_1", cardIndex: 0), "Right moves to column 1's top card")
        vm.moveCursorLeft()

        // Select the 2♠ with Space, move to column 1 and drop it on the 3♥.
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "tableau_0" && vm.selectedCardsIndex == 3, "Space selects the card under the cursor")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil, "Space on the same pile again deselects")
        vm.performSpaceAction()
        vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.state.tableau[1].cards.map { $0.rank } == [3, 2] && vm.state.movesCount == 1, "Space on a legal target moves the selection")
        expect(vm.selectedCardsSource == nil, "Selection is cleared after the move")

        // An illegal drop clears the selection without moving anything.
        vm.moveCursorLeft()
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == "tableau_0", "Selected the 3♠ run top")
        vm.moveCursorRight(); vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil && vm.state.movesCount == 1, "Illegal drop does nothing and clears the selection")

        // Space on the stock deals a row.
        vm.moveCursorUp()
        expect(vm.activeCursor?.pileId == "stock", "Cursor on the stock")
        vm.performSpaceAction()
        expect(vm.state.stock.isEmpty && vm.state.movesCount == 2, "Space on the stock deals")

        // A cursor on an empty column has no card; Space there picks nothing up.
        board(vm, [[], king()] + (2..<10).map { _ in king() })
        vm.clearKeyboardCursor()
        vm.moveCursorDown()
        expect(vm.activeCursor == KeyboardCursor(pileId: "tableau_0", cardIndex: nil), "Cursor on an empty column has no card")
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil, "Nothing to pick up from an empty column")
        // A selection whose pile no longer exists is dropped safely.
        vm.selectedCardsSource = "tableau_gone"
        vm.selectedCardsIndex = 0
        vm.moveCursorRight()
        vm.performSpaceAction()
        expect(vm.selectedCardsSource == nil && vm.selectedCardsIndex == nil, "A stale selection is cleared")

        // Clearing resets everything.
        vm.clearKeyboardCursor()
        expect(vm.activeCursor == nil && vm.selectedCardsSource == nil && vm.selectedCardsIndex == nil, "clearKeyboardCursor resets the cursor")
        vm.enableKeyboardCursorIfNeeded()
        expect(vm.activeCursor?.pileId == "stock", "Enabling the cursor starts on the stock")
        vm.enableKeyboardCursorIfNeeded()
        expect(vm.activeCursor?.pileId == "stock", "Enabling twice changes nothing")
    }

    // MARK: - Point popups

    static func testPointPopups() {
        let vm = SpiderViewModel()
        let five = CovCards.card(.hearts, 5)
        board(vm, padded([[five], [CovCards.card(.spades, 6)]]))
        vm.sharedOptions.honeyMode = true
        vm.moveCards([five], from: vm.state.tableau[0], to: vm.state.tableau[1])
        expect(vm.pointPopup?.displayText == "-1" && vm.pointPopup?.isPositive == false && vm.pointPopup?.cardId == five.id,
               "Honey Mode shows a -1 over the moved card")
        vm.undoLastAction()
        expect(vm.pointPopup == nil, "Undo dismisses the popup")

        let ace = CovCards.card(.spades, 1)
        board(vm, padded([CovCards.run(.spades, from: 13, through: 2), [ace]]))
        vm.moveCards([ace], from: vm.state.tableau[1], to: vm.state.tableau[0])
        expect(vm.pointPopup?.displayText == "+100" && vm.pointPopup?.isPositive == true && vm.pointPopup?.cardId == ace.id,
               "A finished run shows +100 over the run's ace")

        let quiet = SpiderViewModel()
        quiet.sharedOptions.honeyMode = false
        board(quiet, padded([[CovCards.card(.hearts, 5)], [CovCards.card(.spades, 6)]]))
        quiet.moveCards([quiet.state.tableau[0].cards[0]], from: quiet.state.tableau[0], to: quiet.state.tableau[1])
        expect(quiet.pointPopup == nil, "No popup with Honey Mode off")
    }
}
