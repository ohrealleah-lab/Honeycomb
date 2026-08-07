import Foundation

// Regression coverage that the ~50 gameplay conditions wired up around
// HoneycombBannerCatalogTests.swift actually FIRE — HoneycombBannerCatalogTests only
// checks the catalog/BannerCatalog mechanism itself (every id has content, tokens
// substitute, etc.), never that a given gameplay condition (a flawless win, 3 hints
// used, an undo-then-repeat move...) actually calls BannerCatalog.shared.fire() with
// the right id at the right moment. This file drives HoneycombViewModel through its
// real public API and asserts the right banner shows up, either in
// matchResultFlavorText (win/lose overlay flavor) or the mid-match banner queue
// (flashRuleBanner/advanceBannerQueue).
//
// Not covered here (left to manual playtesting — see the test plan discussion):
// the two Nectar Exchange swap-outcome variants (which card gets swapped is random,
// not forceable through the public API) and the rules-banner 80/20 gate's actual
// hit rate (a statistical property, not a pass/fail condition).
struct HoneycombBannerTriggerTests {
    static func run() {
        // Several tests below drive real win/loss outcomes through settleMatch(),
        // which persists stats.recordGame()'s result to the real "honeycomb_stats"
        // UserDefaults key via HoneycombViewModel's own loadStats()/saveStats() —
        // save/restore it around the whole suite so this doesn't corrupt whatever
        // real save data this machine already has (mirrors CrossGameRegressionTests'
        // save/restore of "honeycomb_unlocked_cards"/"selectedGameMode").
        let statsKey = "honeycomb_stats"
        let savedStats = UserDefaults.standard.data(forKey: statsKey)
        defer {
            if let savedStats { UserDefaults.standard.set(savedStats, forKey: statsKey) }
            else { UserDefaults.standard.removeObject(forKey: statsKey) }
        }

        testFlawlessWinFiresFlavorAndMilestone()
        testFlawlessLossFiresFlavor()
        testWinWith4RulesActiveFiresFlavor()
        testThreeHintsUsedFiresBanner()
        testUndoUsedAndRepeatMoveFireBanners()
        testBoardImbalanceFiresBanner()
        testOpponentAboutToPlaceLastCardFiresWarning()
        testSameDifficultyStreakFiresOnFifthMatch()
        testSameDifficultyStreakDoesNotFireOnPlainNewGameStarts()
        testRematchWinStreakFiresOnThirdWin()
        testRematchLossStreakFiresOnThirdLoss()
        testFirstLaunchMilestoneFiresOnFreshStart()
        testLoadingBannerFiresOnViewAppear()
        testLoadingBannerDoesNotFireTwiceInSameSession()
    }

    // MARK: - Helpers

    private static func mkCard(_ id: Int, owner: CardOwner, stats: [Int] = [5, 5, 5, 5], stars: Int = 3, suit: String = "S") -> HoneycombCard {
        HoneycombCard(data: HoneycombCardData(id: id, name: "C\(id)", stars: stars, stats: stats, suit: suit), owner: owner)
    }

    // Unbeatable on every side — used for cards that must survive a neighboring
    // placement without getting captured back, so a forced board's owner counts stay
    // exactly as constructed.
    private static func mkFortressCard(_ id: Int, owner: CardOwner) -> HoneycombCard {
        mkCard(id, owner: owner, stats: [10, 10, 10, 10])
    }

    // Too weak to capture anything — used for the one card actually placed via the
    // public API in these tests, so it can't disturb a fortress board's owner counts.
    private static func mkWeakCard(_ id: Int, owner: CardOwner) -> HoneycombCard {
        mkCard(id, owner: owner, stats: [1, 1, 1, 1])
    }

    private static func drainBannerQueue(_ vm: HoneycombViewModel) -> [String] {
        var result: [String] = []
        var guardCount = 0
        while let banner = vm.flashRuleBanner, guardCount < 50 {
            result.append(banner)
            vm.advanceBannerQueue()
            guardCount += 1
        }
        return result
    }

    private static func catalogMessages(for id: BannerID) -> [String] {
        BannerCatalog.shared.definition(for: id)?.messages ?? []
    }

    // Catalog messages can carry "{Token}" placeholders (e.g. "{OpponentName}
    // prepares a final sting!") that get substituted before the text ever reaches the
    // banner queue/matchResultFlavorText — so matching post-substitution text against
    // the raw catalog string can't be a plain substring check. This instead checks
    // that every literal (non-token) chunk of the raw message shows up in the
    // haystack, in order, which is robust to whatever the token got replaced with.
    private static func literalChunks(of raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: "{}"))
            .enumerated()
            .filter { $0.offset % 2 == 0 && !$0.element.isEmpty }
            .map(\.element)
    }

    private static func matches(_ haystack: String, rawCatalogMessage raw: String) -> Bool {
        let chunks = literalChunks(of: raw)
        // A message that's nothing but a token has no literal text to anchor on —
        // fall back to "did anything at all get queued" (better than a check that can
        // never pass). None of the current catalog entries are actually shaped like
        // this, but it keeps the helper honest if one ever is.
        guard !chunks.isEmpty else { return !haystack.isEmpty }
        return chunks.allSatisfy { haystack.contains($0) }
    }

    private static func queueContainsMessage(_ queue: [String], from ids: [BannerID]) -> Bool {
        let rawMessages = ids.flatMap { catalogMessages(for: $0) }
        return queue.contains { haystack in rawMessages.contains { matches(haystack, rawCatalogMessage: $0) } }
    }

    private static func flavorContainsMessage(_ text: String?, from ids: [BannerID]) -> Bool {
        guard let text else { return false }
        return queueContainsMessage([text], from: ids)
    }

    // MARK: - Win/Lose overlay flavor

    static func testFlawlessWinFiresFlavorAndMilestone() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = []
        vm.stats.matchesWon = 9 // this win should cross the 10-win milestone

        var board = HoneycombBoard()
        for i in 0..<8 {
            board.cells[i].card = mkFortressCard(i, owner: .player)
        }
        vm.board = board
        vm.playerHand = [mkWeakCard(100, owner: .player)]
        vm.opponentHand = []

        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)

        guard vm.matchResult == "You Win!" else {
            fatalError("❌ HoneycombBannerTriggerTests: forced 9-0 board didn't produce a win (matchResult=\(vm.matchResult))")
        }
        guard flavorContainsMessage(vm.matchResultFlavorText, from: [.ruleSpecificPlayerWinsFlawlessOpponentScore0, .gameplayPlayerWinsByTheMaximumPossibleMargin]) else {
            fatalError("❌ HoneycombBannerTriggerTests: flawless win didn't set matchResultFlavorText to a known flawless/max-margin message (got \(vm.matchResultFlavorText ?? "nil"))")
        }
        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.milestonesPlayerReaches10TotalWins]) else {
            fatalError("❌ HoneycombBannerTriggerTests: 10th win didn't fire the milestone banner (queue: \(queued))")
        }
    }

    static func testFlawlessLossFiresFlavor() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = false
        vm.activeRules = []

        var board = HoneycombBoard()
        for i in 0..<8 {
            board.cells[i].card = mkFortressCard(i, owner: .opponent)
        }
        vm.board = board
        vm.opponentHand = [mkWeakCard(200, owner: .opponent)]
        vm.playerHand = []

        vm.aiPlayTurn()

        guard vm.matchResult == "You Lose" else {
            fatalError("❌ HoneycombBannerTriggerTests: forced 0-9 board didn't produce a loss (matchResult=\(vm.matchResult))")
        }
        guard flavorContainsMessage(vm.matchResultFlavorText, from: [.ruleSpecificPlayerLosesFlawless0Captures]) else {
            fatalError("❌ HoneycombBannerTriggerTests: flawless loss didn't set matchResultFlavorText (got \(vm.matchResultFlavorText ?? "nil"))")
        }
    }

    static func testWinWith4RulesActiveFiresFlavor() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        // All four are legality/reveal-only rules — none change capture math, so the
        // forced fortress board's owner counts land exactly as constructed.
        vm.activeRules = [.allOpen, .threeOpen, .order, .chaos]

        var board = HoneycombBoard()
        for i in 0..<5 { board.cells[i].card = mkFortressCard(i, owner: .player) }
        for i in 5..<8 { board.cells[i].card = mkFortressCard(i, owner: .opponent) }
        vm.board = board
        vm.playerHand = [mkWeakCard(300, owner: .player)]
        vm.opponentHand = []

        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)

        guard vm.matchResult == "You Win!" else {
            fatalError("❌ HoneycombBannerTriggerTests: forced 6-3 board didn't produce a win (matchResult=\(vm.matchResult))")
        }
        guard flavorContainsMessage(vm.matchResultFlavorText, from: [.gameplayPlayerWinsAMatchWith4RulesActiveAtOnce]) else {
            fatalError("❌ HoneycombBannerTriggerTests: winning with 4 active rules didn't fire the flavor banner (got \(vm.matchResultFlavorText ?? "nil"))")
        }
    }

    // MARK: - Mid-match toasts

    static func testThreeHintsUsedFiresBanner() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = []
        vm.board = HoneycombBoard()
        vm.playerHand = (1...5).map { mkCard($0, owner: .player) }
        vm.opponentHand = (11...15).map { mkCard($0, owner: .opponent) }

        vm.findHint()
        vm.findHint()
        guard drainBannerQueue(vm).isEmpty else {
            fatalError("❌ HoneycombBannerTriggerTests: 3-hints banner fired too early (before the 3rd hint)")
        }
        vm.findHint()

        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.gameplay3HintsUsedInOneMatch]) else {
            fatalError("❌ HoneycombBannerTriggerTests: 3rd hint didn't fire the banner (queue: \(queued))")
        }
    }

    static func testUndoUsedAndRepeatMoveFireBanners() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = []
        vm.board = HoneycombBoard()
        vm.playerHand = [mkWeakCard(1, owner: .player), mkWeakCard(2, owner: .player)]
        vm.opponentHand = [mkWeakCard(11, owner: .opponent), mkWeakCard(12, owner: .opponent)]

        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 0)
        _ = drainBannerQueue(vm) // clear out whatever this move's own capture banner (if any) queued

        guard vm.canUndo else {
            fatalError("❌ HoneycombBannerTriggerTests: canUndo was false after a player move + AI reply — can't exercise Undo")
        }
        vm.undoLastAction()
        let afterUndo = drainBannerQueue(vm)
        guard queueContainsMessage(afterUndo, from: [.gameplayUndoUsedImmediatelyAfterAPlacement]) else {
            fatalError("❌ HoneycombBannerTriggerTests: Undo didn't fire the 'undo used' banner (queue: \(afterUndo))")
        }

        // Replaying the exact same card onto the exact same cell should fire the
        // repeat-move banner too.
        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 0)
        let afterRepeat = drainBannerQueue(vm)
        guard queueContainsMessage(afterRepeat, from: [.gameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact]) else {
            fatalError("❌ HoneycombBannerTriggerTests: replaying the undone move didn't fire the repeat-move banner (queue: \(afterRepeat))")
        }

        // Negative case: undo again, then play a DIFFERENT cell — must NOT fire.
        guard vm.canUndo else {
            fatalError("❌ HoneycombBannerTriggerTests: canUndo was false on the second round — can't exercise the negative case")
        }
        vm.undoLastAction()
        _ = drainBannerQueue(vm)
        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 1) // different cell than the undone move
        let afterDifferentCell = drainBannerQueue(vm)
        guard !queueContainsMessage(afterDifferentCell, from: [.gameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact]) else {
            fatalError("❌ HoneycombBannerTriggerTests: REGRESSION — playing a DIFFERENT cell after Undo still fired the repeat-move banner (queue: \(afterDifferentCell))")
        }
    }

    static func testBoardImbalanceFiresBanner() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = true
        vm.activeRules = []

        var board = HoneycombBoard()
        board.cells[0].card = mkFortressCard(0, owner: .player)
        for i in 1..<7 { board.cells[i].card = mkFortressCard(i, owner: .opponent) }
        // cells[7] and cells[8] stay empty — one becomes the player's 2nd card below,
        // the other keeps the board short of full so this stays a mid-match toast.
        vm.board = board
        vm.playerHand = [mkWeakCard(400, owner: .player)]
        vm.opponentHand = []

        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 7)

        let playerOwned = vm.board.cells.filter { $0.card?.owner == .player }.count
        let opponentOwned = vm.board.cells.filter { $0.card?.owner == .opponent }.count
        guard playerOwned == 2, opponentOwned == 6 else {
            fatalError("❌ HoneycombBannerTriggerTests: forced board didn't land at 2 player / 6 opponent (got \(playerOwned)/\(opponentOwned))")
        }
        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.gameplayPlayerHasOnly2CardsOnTheBoardVsOpponents6Few]) else {
            fatalError("❌ HoneycombBannerTriggerTests: 2-vs-6 board imbalance didn't fire the banner (queue: \(queued))")
        }
    }

    static func testOpponentAboutToPlaceLastCardFiresWarning() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.gameState = .playing
        vm.isPlayerTurn = false
        vm.activeRules = []

        var board = HoneycombBoard()
        for i in 0..<3 { board.cells[i].card = mkFortressCard(i, owner: .player) }
        for i in 3..<8 { board.cells[i].card = mkFortressCard(i, owner: .opponent) }
        // 3 player-owned vs 5 opponent-owned, 1 empty. The "pre-move" score the trigger
        // checks against is board ownership PLUS whatever's still sitting in each hand
        // (an unplayed card still counts toward that side's eventual score) — the
        // opponent's one card about to be played counts on their side of that formula,
        // so the player needs a leftover (never-played) card of their own for the 3-5
        // board split to net out to exactly a 2-card opponent lead: (5+1) - (3+1) = 2.
        vm.board = board
        vm.opponentHand = [mkWeakCard(500, owner: .opponent)]
        vm.playerHand = [mkWeakCard(501, owner: .player)]

        vm.aiPlayTurn()

        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.gameplayOpponentIsWinningByTwoCardsAndIsAboutToPlaceThe]) else {
            fatalError("❌ HoneycombBannerTriggerTests: opponent's last-card-with-2-lead move didn't fire the warning (queue: \(queued))")
        }
    }

    // MARK: - Streaks

    static func testSameDifficultyStreakFiresOnFifthMatch() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        // Only rematches count toward this streak (confirmed by the banner content
        // owner: plain New Game starts at the same difficulty shouldn't trip it) —
        // one real startNewGame() to populate rematchOpponentDeck, then 4 rematch()
        // calls to reach the 5th consecutive same-difficulty match.
        vm.startNewGame()
        for _ in 1...5 {
            vm.rematch()
        }
        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.gameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow]) else {
            fatalError("❌ HoneycombBannerTriggerTests: 5th rematch at the same difficulty didn't fire the streak banner (queue: \(queued))")
        }
    }

    static func testSameDifficultyStreakDoesNotFireOnPlainNewGameStarts() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        // Same default difficulty every time, but via startNewGame() (not rematch())
        // — should never trip the streak, no matter how many times it repeats.
        for _ in 1...6 {
            vm.startNewGame()
        }
        let queued = drainBannerQueue(vm)
        guard !queueContainsMessage(queued, from: [.gameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow]) else {
            fatalError("❌ HoneycombBannerTriggerTests: REGRESSION — plain New Game starts at the same difficulty fired the rematch-only streak banner (queue: \(queued))")
        }
    }

    // Forces a win by directly overwriting board/hands to an 8-0 fortress split, then
    // playing the 9th card — same technique as testFlawlessWinFiresFlavorAndMilestone,
    // just repeated across a real rematch() chain so the "against the same opponent"
    // streak state (private to HoneycombViewModel) accumulates naturally through the
    // real API instead of being poked directly.
    private static func forceWinViaFortressBoard(_ vm: HoneycombViewModel) {
        vm.activeRules = []
        vm.isPlayerTurn = true
        vm.gameState = .playing
        var board = HoneycombBoard()
        for i in 0..<8 { board.cells[i].card = mkFortressCard(i, owner: .player) }
        vm.board = board
        vm.playerHand = [mkWeakCard(Int.random(in: 10_000...99_999), owner: .player)]
        vm.opponentHand = []
        _ = vm.playerPlayCard(handIndex: 0, boardIndex: 8)
    }

    private static func forceLossViaFortressBoard(_ vm: HoneycombViewModel) {
        vm.activeRules = []
        vm.isPlayerTurn = false
        vm.gameState = .playing
        var board = HoneycombBoard()
        for i in 0..<8 { board.cells[i].card = mkFortressCard(i, owner: .opponent) }
        vm.board = board
        vm.opponentHand = [mkWeakCard(Int.random(in: 10_000...99_999), owner: .opponent)]
        vm.playerHand = []
        vm.aiPlayTurn()
    }

    static func testRematchWinStreakFiresOnThirdWin() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        // One real startNewGame() to populate rematchOpponentDeck (canRematch requires
        // it non-empty) — everything else about this match is immediately overwritten.
        vm.startNewGame()

        forceWinViaFortressBoard(vm) // win #1
        _ = drainBannerQueue(vm)
        guard vm.canRematch else {
            fatalError("❌ HoneycombBannerTriggerTests: canRematch was false after the first forced win — can't build a rematch chain")
        }
        vm.rematch()

        forceWinViaFortressBoard(vm) // win #2
        _ = drainBannerQueue(vm)
        vm.rematch()

        forceWinViaFortressBoard(vm) // win #3 — should trip the streak
        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.gameplay3RematchWinsInARowAgainstTheSameOpponent]) else {
            fatalError("❌ HoneycombBannerTriggerTests: 3rd rematch win in a row didn't fire the streak banner (queue: \(queued))")
        }
    }

    static func testRematchLossStreakFiresOnThirdLoss() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        vm.startNewGame()

        forceLossViaFortressBoard(vm) // loss #1
        _ = drainBannerQueue(vm)
        guard vm.canRematch else {
            fatalError("❌ HoneycombBannerTriggerTests: canRematch was false after the first forced loss — can't build a rematch chain")
        }
        vm.rematch()

        forceLossViaFortressBoard(vm) // loss #2
        _ = drainBannerQueue(vm)
        vm.rematch()

        forceLossViaFortressBoard(vm) // loss #3 — should trip the streak
        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.gameplay3RematchLossesInARowAgainstTheSameOpponent]) else {
            fatalError("❌ HoneycombBannerTriggerTests: 3rd rematch loss in a row didn't fire the streak banner (queue: \(queued))")
        }
    }

    // MARK: - Session-scoped (first launch / loading)

    static func testFirstLaunchMilestoneFiresOnFreshStart() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()
        // init() loads whatever this machine's real "honeycomb_stats" save data says
        // (see the save/restore in run() above) — reset to a clean slate so
        // gamesPlayed == 0 regardless of real play history, since that's the exact
        // condition milestonesFirstLaunchEver fires on.
        vm.stats = HoneycombStats()
        vm.startNewGame()

        let queued = drainBannerQueue(vm)
        guard queueContainsMessage(queued, from: [.milestonesFirstLaunchEver]) else {
            fatalError("❌ HoneycombBannerTriggerTests: first-ever match didn't fire the first-launch milestone (queue: \(queued))")
        }
    }

    // checkLoadingBanner() is no longer called from startNewGame() — it's a screen-
    // transition banner now (fired from HoneycombView's .onAppear when the game's
    // view actually appears, per the product decision that a "loading" toast belongs
    // to a scene transition, not a gameplay action), so this test calls it directly
    // rather than driving it through startNewGame().
    static func testLoadingBannerFiresOnViewAppear() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()

        vm.checkLoadingBanner()

        let queued = drainBannerQueue(vm)
        // Whichever Loading banner today's actual date/time maps to, SOME loading
        // message should be present — this can't pin an exact id without mocking the
        // system clock, so it checks membership across every Loading-location entry.
        let loadingIDs = BannerID.allCases.filter { $0.rawValue.hasPrefix("loading_") }
        guard queueContainsMessage(queued, from: loadingIDs) else {
            fatalError("❌ HoneycombBannerTriggerTests: checkLoadingBanner() didn't fire any Loading banner (queue: \(queued))")
        }
    }

    static func testLoadingBannerDoesNotFireTwiceInSameSession() {
        UISound.isHeadlessMode = true
        let vm = HoneycombViewModel()

        vm.checkLoadingBanner()
        _ = drainBannerQueue(vm)
        vm.checkLoadingBanner() // simulates switching back to this game later

        let queued = drainBannerQueue(vm)
        guard queued.isEmpty else {
            fatalError("❌ HoneycombBannerTriggerTests: REGRESSION — checkLoadingBanner() fired again on a revisit within the same session (queue: \(queued))")
        }
    }
}
