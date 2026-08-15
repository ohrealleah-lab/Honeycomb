import Foundation

// Regression coverage for the class of "stats are silently wrong" bugs found during
// the pre-production ultra review: none of these crash or look wrong on screen in the
// moment, so manual playtesting essentially can't catch them — only a test that plays
// a scripted sequence and asserts the exact resulting numbers can. Each test here
// mirrors a specific bug fixed in that pass; see git history for the corresponding
// fix if one of these ever fails.
struct StatsRegressionTests {
    static func run() {
        testSuddenDeathEntryDoesNotRecordStatsYet()
        testHoneycombResetStatisticsClearsEveryField()
        testKlondikeNoStressWinDoesNotInflateAverageTime()
        testKlondikeResetStatisticsClearsStreaksAndHighScoreAndSurvivesRelaunch()
        testBeecellDeckCountSwitchResetsAbandonedModeNotNewMode()
        testSpiderSuitCountSwitchResetsAbandonedModeNotNewMode()
    }

    // MARK: - Honeycomb

    // Forces a tied 9-card board (5 player-owned cells + a leftover opponent hand card
    // = 5-5) with Sudden Death active, so the final placement lands in settleMatch's
    // .suddenDeath branch instead of a normal win/loss/tie. That branch used to call
    // stats.recordGame() immediately (a "draw"), then record the real result again once
    // the tie-break resolved — double-counting gamesPlayed and zeroing the win streak
    // before the Sudden Death winner was even known. Fixed by removing that premature
    // call entirely; this asserts stats are untouched at the moment Sudden Death starts.
    static func testSuddenDeathEntryDoesNotRecordStatsYet() {
        UISound.isHeadlessMode = true
        let statsKey = "honeycomb_stats"
        let saved = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = [.suddenDeath]
        vm.stats = HoneycombStats()

        func mkFortressCard(_ id: Int, owner: CardOwner) -> HoneycombCard {
            HoneycombCard(data: HoneycombCardData(id: id, name: "C\(id)", stars: 3, stats: [10, 10, 10, 10], suit: "S"), owner: owner)
        }
        func mkWeakCard(_ id: Int, owner: CardOwner) -> HoneycombCard {
            HoneycombCard(data: HoneycombCardData(id: id, name: "C\(id)", stars: 1, stats: [1, 1, 1, 1], suit: "S"), owner: owner)
        }

        // 4 player + 4 opponent fortress cells pre-filled (8 of 9). One more opponent
        // card sits unplayed in hand (a leftover from the 5-vs-5 hand split), and the
        // player's last card is placed via the real API below to fill the board:
        // final tally is playerCells(5) + playerHand(0) = 5, opponentCells(4) +
        // opponentHand(1) = 5 — an exact tie, routing into the Sudden Death branch.
        var board = HoneycombBoard()
        for i in 0..<4 { board.cells[i].card = mkFortressCard(i, owner: .player) }
        for i in 4..<8 { board.cells[i].card = mkFortressCard(i, owner: .opponent) }
        vm.board = board
        vm.playerHand = [mkWeakCard(100, owner: .player)]
        vm.opponentHand = [mkFortressCard(200, owner: .opponent)]

        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)

        guard vm.matchOutcome == .suddenDeathPending else {
            fatalError("❌ StatsRegressionTests: forced 5-5 board with Sudden Death active didn't route into the tie-break (matchOutcome=\(vm.matchOutcome), matchResult=\(vm.matchResult))")
        }
        guard vm.stats == HoneycombStats() else {
            fatalError("❌ StatsRegressionTests: entering Sudden Death touched stats before the tie-break resolved (stats=\(vm.stats)) — the premature recordGame() call regressed")
        }
    }

    static func testHoneycombResetStatisticsClearsEveryField() {
        UISound.isHeadlessMode = true
        let statsKey = "honeycomb_stats"
        let saved = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        let vm = HoneycombViewModel()
        var stats = HoneycombStats()
        stats.gamesPlayed = 10
        stats.matchesWon = 6
        stats.matchesLost = 3
        stats.matchesDrawn = 1
        stats.cardsCaptured = 40
        stats.currentWinStreak = 3
        stats.longestWinStreak = 5
        stats.flawlessVictories = 2
        stats.samePlusTriggers = 7
        stats.suddenDeathCount = 1
        vm.stats = stats

        vm.resetStatistics()

        guard vm.stats == HoneycombStats() else {
            fatalError("❌ StatsRegressionTests: Honeycomb resetStatistics() left fields non-default (stats=\(vm.stats))")
        }
    }

    // MARK: - Klondike

    // No Stress Mode never starts the timer, so a win in that mode calls
    // recordWin(timeInSeconds: 0). Before the fix, winningGamesCount and
    // totalWinningTime were incremented unconditionally, so every zero-time win
    // silently dragged averageWinningTime (totalWinningTime / winningGamesCount) down
    // — a No-Stress player's very real timed wins looked faster than they actually were.
    static func testKlondikeNoStressWinDoesNotInflateAverageTime() {
        let vm = GameViewModel()
        vm.resetStatistics()

        vm.recordWin(timeInSeconds: 0)

        guard vm.gamesWon == 1 else {
            fatalError("❌ StatsRegressionTests: a No-Stress win (timeInSeconds: 0) didn't count as a win (gamesWon=\(vm.gamesWon))")
        }
        guard vm.statistics.winningGamesCount == 0 && vm.statistics.totalWinningTime == 0 && vm.statistics.shortestWinTime == 0 else {
            fatalError("❌ StatsRegressionTests: a zero-time (No Stress Mode) win polluted averageWinningTime's inputs (winningGamesCount=\(vm.statistics.winningGamesCount), totalWinningTime=\(vm.statistics.totalWinningTime), shortestWinTime=\(vm.statistics.shortestWinTime))")
        }

        // A real timed win afterward must still count normally.
        vm.recordWin(timeInSeconds: 60)
        guard vm.gamesWon == 2, vm.statistics.winningGamesCount == 1, vm.statistics.totalWinningTime == 60 else {
            fatalError("❌ StatsRegressionTests: a real timed win after a No-Stress win didn't record correctly (gamesWon=\(vm.gamesWon), winningGamesCount=\(vm.statistics.winningGamesCount), totalWinningTime=\(vm.statistics.totalWinningTime))")
        }
    }

    // resetStatistics() used to only zero gamesWon/gamesPlayed/highScore, leaving
    // currentStreak/longestStreak/totalWinningTime/winningGamesCount/shortestWinTime
    // (and the OTHER scoring mode's stored high score) untouched — Reset Stats visibly
    // did nothing for most of the stats sheet. Also: gamesWon/gamesPlayed are re-derived
    // from separate legacy "gamesWon"/"gamesPlayed" UserDefaults keys on every launch
    // (see GameViewModel.init), so this test constructs a FRESH GameViewModel after
    // resetting to confirm the reset actually survives a relaunch, not just the
    // in-memory value.
    static func testKlondikeResetStatisticsClearsStreaksAndHighScoreAndSurvivesRelaunch() {
        let legacyKeys = ["gamesWon", "gamesPlayed", "highScore", "highScoreVegas", "solitaire_statistics"]
        let saved = legacyKeys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }

        let vm = GameViewModel()
        vm.resetStatistics() // clean, known baseline before this test's own data

        vm.recordWin(timeInSeconds: 42)
        vm.highScore = 999

        guard vm.statistics.currentStreak == 1, vm.statistics.totalWinningTime == 42, vm.highScore == 999 else {
            fatalError("❌ StatsRegressionTests: setup for the reset test didn't take (currentStreak=\(vm.statistics.currentStreak), totalWinningTime=\(vm.statistics.totalWinningTime), highScore=\(vm.highScore))")
        }

        vm.resetStatistics()

        guard vm.statistics.currentStreak == 0,
              vm.statistics.longestStreak == 0,
              vm.statistics.totalWinningTime == 0,
              vm.statistics.winningGamesCount == 0,
              vm.statistics.shortestWinTime == 0,
              vm.gamesWon == 0,
              vm.gamesPlayed == 0,
              vm.highScore == 0
        else {
            fatalError("❌ StatsRegressionTests: Klondike resetStatistics() left a field non-default (statistics=\(vm.statistics), gamesWon=\(vm.gamesWon), gamesPlayed=\(vm.gamesPlayed), highScore=\(vm.highScore))")
        }

        // The regression this guards against: gamesWon/gamesPlayed are overwritten from
        // legacy flat UserDefaults keys at init (see GameViewModel.init above) — a reset
        // that only touched the in-memory `statistics` struct would silently "come back"
        // on next launch even though this vm's own gamesWon/gamesPlayed read as 0 right
        // now. Checked directly against the persisted keys rather than by constructing a
        // new GameViewModel(), since init() itself calls startNewGame() (gamesPlayed += 1)
        // as part of dealing the fresh game — a legitimate "played" that would otherwise
        // make a same-process relaunch check indistinguishable from a real regression.
        guard UserDefaults.standard.integer(forKey: "gamesWon") == 0,
              UserDefaults.standard.integer(forKey: "gamesPlayed") == 0
        else {
            fatalError("❌ StatsRegressionTests: Klondike's Reset Stats didn't persist — legacy gamesWon/gamesPlayed UserDefaults keys weren't actually cleared (gamesWon key=\(UserDefaults.standard.integer(forKey: "gamesWon")), gamesPlayed key=\(UserDefaults.standard.integer(forKey: "gamesPlayed")))")
        }
    }

    // MARK: - Beecell / Spider mode-switch streak attribution

    // options.didSet has already applied the NEW deck count by the time
    // handleOptionsChanged runs its abandoned-game streak reset — before the fix, that
    // reset read the (already-new) currentModeKey and zeroed the WRONG mode's streak.
    static func testBeecellDeckCountSwitchResetsAbandonedModeNotNewMode() {
        let optionsKey = "beecell_options"
        let statsKey = "beecell_statistics"
        let savedOptions = UserDefaults.standard.data(forKey: optionsKey)
        let savedStats = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let savedOptions { UserDefaults.standard.set(savedOptions, forKey: optionsKey) }
            else { UserDefaults.standard.removeObject(forKey: optionsKey) }
            if let savedStats { UserDefaults.standard.set(savedStats, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        let vm = BeecellViewModel()
        var opts = vm.options
        opts.deckCount = 1
        vm.options = opts

        var stats = vm.statistics
        stats.statsByMode["1deck"] = ModeStats(currentStreak: 5)
        stats.statsByMode["2deck"] = ModeStats(currentStreak: 3)
        vm.statistics = stats

        // Simulate an abandoned mid-game (moves made, not won) before the deck-count
        // switch — this is what makes handleOptionsChanged's streak-reset branch fire.
        vm.state.movesCount = 1

        var switched = vm.options
        switched.deckCount = 2
        vm.options = switched

        guard vm.statistics.statsByMode["1deck"]?.currentStreak == 0 else {
            fatalError("❌ StatsRegressionTests: switching Beecell to 2-deck didn't reset the ABANDONED 1-deck mode's streak (got \(vm.statistics.statsByMode["1deck"]?.currentStreak ?? -1))")
        }
        guard vm.statistics.statsByMode["2deck"]?.currentStreak == 3 else {
            fatalError("❌ StatsRegressionTests: switching Beecell to 2-deck incorrectly reset the NEW 2-deck mode's streak instead of the abandoned 1-deck one (got \(vm.statistics.statsByMode["2deck"]?.currentStreak ?? -1))")
        }
    }

    static func testSpiderSuitCountSwitchResetsAbandonedModeNotNewMode() {
        let optionsKey = "spider_options"
        let statsKey = "spider_statistics"
        let savedOptions = UserDefaults.standard.data(forKey: optionsKey)
        let savedStats = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let savedOptions { UserDefaults.standard.set(savedOptions, forKey: optionsKey) }
            else { UserDefaults.standard.removeObject(forKey: optionsKey) }
            if let savedStats { UserDefaults.standard.set(savedStats, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        let vm = SpiderViewModel()
        var opts = vm.options
        opts.suitCount = 1
        vm.options = opts

        var stats = vm.statistics
        stats.statsBySuits[1] = SpiderModeStats(currentStreak: 4)
        stats.statsBySuits[2] = SpiderModeStats(currentStreak: 2)
        vm.statistics = stats

        vm.state.movesCount = 1

        var switched = vm.options
        switched.suitCount = 2
        vm.options = switched

        guard vm.statistics.statsBySuits[1]?.currentStreak == 0 else {
            fatalError("❌ StatsRegressionTests: switching Spider to 2 suits didn't reset the ABANDONED 1-suit mode's streak (got \(vm.statistics.statsBySuits[1]?.currentStreak ?? -1))")
        }
        guard vm.statistics.statsBySuits[2]?.currentStreak == 2 else {
            fatalError("❌ StatsRegressionTests: switching Spider to 2 suits incorrectly reset the NEW 2-suit mode's streak instead of the abandoned 1-suit one (got \(vm.statistics.statsBySuits[2]?.currentStreak ?? -1))")
        }
    }
}
