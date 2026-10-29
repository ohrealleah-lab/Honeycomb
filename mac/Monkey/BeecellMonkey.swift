import Foundation

final class BeecellMonkey: MonkeyGame {
    static let gameName = "Beecell"

    // The deck count: "1" or "2" (2 decks is desktop-only, and this is the Mac build).
    static func randomStartMode(_ rng: inout SplitMix64) -> String {
        rng.chance(0.75) ? "1" : "2"
    }

    private var shared: SharedGameOptions
    private var vm: BeecellViewModel
    private let startMode: String

    private var undoShadow: [BeecellState] = []
    private var dealStart: BeecellState
    private var movedThisDeal = false
    private(set) var wins = 0

    init(startMode: String) {
        self.startMode = startMode
        var options = BeecellOptions()
        options.deckCount = startMode == "2" ? 2 : 1
        MonkeySandbox.saveOptions(options, key: "beecell_options")
        shared = MonkeySandbox.quietSharedOptions()
        vm = BeecellViewModel(sharedOptions: shared)
        dealStart = vm.state
    }

    var setupDescription: String {
        "Beecell, \(startMode == "2" ? "2 decks" : "1 deck")"
    }

    // MARK: - Piles

    private func pile(_ id: String?) -> Pile? {
        let s = vm.state
        return (s.freeCells + s.foundations + s.tableau).first { $0.id == id }
    }

    private func pileName(_ id: String) -> String {
        let s = vm.state
        if let i = s.freeCells.firstIndex(where: { $0.id == id }) { return "free cell \(i + 1)" }
        if let i = s.foundations.firstIndex(where: { $0.id == id }) { return "foundation \(i + 1)" }
        if let i = s.tableau.firstIndex(where: { $0.id == id }) { return "column \(i + 1)" }
        return id
    }

    // BeecellView lets you pick up any tableau card (with everything on top of it) and the
    // top card of a free cell or foundation; Smart Drop sorts out what actually moves.
    private func canGrab(_ pile: Pile, _ index: Int) -> Bool {
        guard pile.cards.indices.contains(index) else { return false }
        return pile.type == .tableau || index == pile.cards.count - 1
    }

    private func grabs() -> [(pile: Pile, index: Int)] {
        let s = vm.state
        return (s.freeCells + s.foundations + s.tableau).flatMap { pile in
            pile.cards.indices.filter { canGrab(pile, $0) }.map { (pile, $0) }
        }
    }

    private var dropTargets: [Pile] { vm.state.freeCells + vm.state.foundations + vm.state.tableau }

    private func resolvedDrop(_ source: Pile, _ index: Int, onto target: Pile) -> [Card]? {
        guard source.id != target.id, canGrab(source, index) else { return nil }
        return SmartDrop.resolve(cards: Array(source.cards[index...])) { vm.isValidMove(cards: $0, to: target) }
    }

    // MARK: - Choosing a step

    func randomAction(_ rng: inout SplitMix64) -> MonkeyAction {
        let modeChange = MonkeyAction(kind: .mode, value: rng.pick(["1", "2"]))
        if vm.state.hasWon || rng.chance(0.006) || (vm.isStuck && rng.chance(0.3)) {
            return gameLevelAction(&rng, modeChange: modeChange)
        }
        if vm.isAutocompleteAvailable && rng.chance(0.7) { return MonkeyAction(kind: .autocomplete) }

        switch Double.random(in: 0..<1, using: &rng) {
        case ..<0.75:
            let legal = grabs().flatMap { grab in
                dropTargets.filter { resolvedDrop(grab.pile, grab.index, onto: $0) != nil }
                    .map { MonkeyAction(kind: .move, from: grab.pile.id, index: grab.index, to: $0.id) }
            }
            // Useful moves first: cards home, then building on another column, then cards
            // back out of the free cells. Parking cards in free cells comes last.
            let home = legal.filter { pile($0.to)?.type == .foundation && pile($0.from)?.type != .foundation }
            let builds = legal.filter { pile($0.from)?.type == .tableau && pile($0.to)?.topCard != nil && pile($0.to)?.type == .tableau }
            let unpark = legal.filter { pile($0.from)?.type == .freeCell && pile($0.to)?.type == .tableau }
            return pickMove(&rng, tiers: [home, builds, unpark], legal: legal) ?? MonkeyAction(kind: .undo)
        case ..<0.79:
            guard let grab = rng.pick(grabs()), let target = rng.pick(dropTargets) else { return MonkeyAction(kind: .undo) }
            return MonkeyAction(kind: .move, from: grab.pile.id, index: grab.index, to: target.id)
        case ..<0.86:
            let tops = (vm.state.freeCells + vm.state.tableau).filter { !$0.isEmpty }
            guard let target = rng.pick(tops) else { return MonkeyAction(kind: .undo) }
            return MonkeyAction(kind: .tap, from: target.id, index: target.cards.count - 1)
        case ..<0.96: return MonkeyAction(kind: .undo)
        default: return MonkeyAction(kind: .hint)
        }
    }

    // MARK: - Describing a step (before it happens)

    func describe(_ action: MonkeyAction) -> String {
        switch action.kind {
        case .draw: return "Click the board (nothing should happen)."
        case .move:
            guard let source = pile(action.from), let index = action.index, source.cards.indices.contains(index),
                  let target = pile(action.to) else { return "Try a drag from a pile that no longer has that card (nothing should happen)." }
            // Smart Drop may move only the top part of the grabbed stack; name what moves.
            let moving = resolvedDrop(source, index, onto: target)
            let card = moving?.first ?? source.cards[index]
            let above = (moving?.count ?? source.cards.count - index) - 1
            let stack = above > 0 ? " (with the \(above) card\(above == 1 ? "" : "s") on top of it)" : ""
            let onto = target.topCard.map { "onto \(cardName($0)) in \(pileName(target.id))" } ?? "onto the empty \(pileName(target.id))"
            let refused = moving == nil ? ". The game should refuse it." : "."
            return "Drag \(cardName(card)) from \(pileName(source.id))\(stack) \(onto)\(refused)"
        case .tap:
            guard let source = pile(action.from), let card = source.topCard else { return "Double-click an empty pile (nothing should happen)." }
            return "Double-click \(cardName(card)) in \(pileName(source.id))."
        case .undo: return "Click Undo."
        case .hint: return "Click Hint."
        case .autocomplete: return "Click Autocomplete."
        case .restart: return "Choose Restart Game."
        case .newGame: return "Choose New Game."
        case .mode: return "In Options, switch to \(action.value == "2" ? "2 decks" : "1 deck") and click OK."
        case .noStress: return "Turn No Stress Mode \(shared.noStressMode ? "off" : "on")."
        case .relaunch: return "Quit the app and open it again."
        case .play, .rematch, .quit, .steal, .startOver: return "(not a Beecell step)"
        }
    }

    // MARK: - Doing a step and checking the rules

    func perform(_ action: MonkeyAction) throws {
        let before = vm.state
        let modeBefore = vm.currentModeKey
        var expectedStats = vm.statistics

        switch action.kind {
        case .draw:
            break  // Beecell has no stock
        case .move:
            guard !before.hasWon, let source = pile(action.from), let index = action.index, let target = pile(action.to) else { break }
            if let cards = resolvedDrop(source, index, onto: target) {
                vm.moveCards(cards, from: source, to: target)
            }
            noteMove(from: before)
        case .tap:
            guard !before.hasWon, let source = pile(action.from), let card = source.topCard else { break }
            vm.doubleClickMove(card: card, from: source)
            noteMove(from: before)
        case .undo:
            vm.undoLastAction()
            try checkUndo(before: before)
        case .hint:
            vm.findHint()
            try require(same(vm.state, before), .hintLeavesBoard, boardDiff(expected: before, actual: vm.state))
        case .autocomplete:
            guard vm.isAutocompleteAvailable, !vm.isAutoplayRunning else { break }
            vm.runAutocomplete()
            guard runMainQueue(until: { !vm.isAutoplayRunning }, limit: 20) else {
                throw RuleBroken(rule: .slowStep, detail: "Autocomplete was still moving cards after 20 seconds.")
            }
            noteMove(from: before)
            // Beecell only offers Autocomplete once it can finish the game (canAutocompleteToCompletion).
            try require(vm.state.hasWon, .autocompleteWins,
                        "Autocomplete stopped with \(vm.state.foundations.reduce(0) { $0 + $1.cards.count }) of \(vm.options.deckCount * 52) cards on the foundations.")
        case .restart:
            vm.restartCurrentGame()
            undoShadow.removeAll()
            try require(same(vm.state, dealStart), .restartRestores, boardDiff(expected: dealStart, actual: vm.state))
            if before.hasWon {
                expectedStats.statsByMode[modeBefore, default: ModeStats()].gamesPlayed += 1
                movedThisDeal = false
            }
        case .newGame:
            vm.startNewGame()
            expectNewDeal(&expectedStats, abandoned: modeBefore, wasWon: before.hasWon)
        case .mode:
            let decks = action.value == "2" ? 2 : 1
            guard decks != vm.options.deckCount else { break }
            var options = vm.options
            options.deckCount = decks
            vm.options = options
            expectNewDeal(&expectedStats, abandoned: modeBefore, wasWon: before.hasWon)
        case .noStress:
            shared.noStressMode.toggle()
            vm.reactToNoStressModeChange()
            try require(same(vm.state, before), .boardShape, "Turning No Stress Mode on or off changed the board. " + boardDiff(expected: before, actual: vm.state))
        case .relaunch:
            try relaunch()
            expectedStats = vm.statistics
        case .play, .rematch, .quit, .steal, .startOver:
            break
        }

        if !before.hasWon && vm.state.hasWon { wins += 1 }
        try checkStats(expected: expectedStats, wonThisStep: !before.hasWon && vm.state.hasWon)
        try checkBoard()
    }

    private func noteMove(from before: BeecellState) {
        guard !same(vm.state, before) else { return }
        undoShadow.append(before)
        if undoShadow.count > 100 { undoShadow.removeFirst() }
        movedThisDeal = true
    }

    private func expectNewDeal(_ stats: inout BeecellStatistics, abandoned: String, wasWon: Bool) {
        if movedThisDeal && !wasWon { stats.statsByMode[abandoned, default: ModeStats()].currentStreak = 0 }
        stats.statsByMode[vm.currentModeKey, default: ModeStats()].gamesPlayed += 1
        undoShadow.removeAll()
        movedThisDeal = false
        dealStart = vm.state
    }

    private func checkUndo(before: BeecellState) throws {
        guard !before.hasWon, let previous = undoShadow.popLast() else {
            try require(same(vm.state, before), .undoRestores, "Undo had nothing to undo, but the board changed. " + boardDiff(expected: before, actual: vm.state))
            return
        }
        try require(same(vm.state, previous), .undoRestores, boardDiff(expected: previous, actual: vm.state))
    }

    private func relaunch() throws {
        let options = vm.options, stats = vm.statistics, noStress = shared.noStressMode
        shared = MonkeySandbox.quietSharedOptions()
        vm = BeecellViewModel(sharedOptions: shared)
        var expectedStats = stats
        expectedStats.statsByMode[vm.currentModeKey, default: ModeStats()].gamesPlayed += 1  // opening the app deals a new game
        let problems = [
            valueDiff("No Stress Mode", noStress, shared.noStressMode),
            valueDiff("The Beecell options", options, vm.options),
            expectedStats == vm.statistics ? nil : "The Beecell stats should be \(statsText(expectedStats)) but came back as \(statsText(vm.statistics)).",
        ].compactMap { $0 }
        try require(problems.isEmpty, .savedReopensSame, problems.joined(separator: " "))
        undoShadow.removeAll()
        movedThisDeal = false
        dealStart = vm.state
    }

    private func checkStats(expected: BeecellStatistics, wonThisStep: Bool) throws {
        let actual = vm.statistics
        var expected = expected
        if wonThisStep {
            let key = vm.currentModeKey
            var mode = expected.statsByMode[key] ?? ModeStats()
            let actualMode = actual.statsByMode[key] ?? ModeStats()
            mode.gamesWon += 1
            mode.currentStreak += 1
            mode.longestStreak = max(mode.longestStreak, mode.currentStreak)
            mode.highScore = actualMode.highScore
            mode.totalWinningTime = actualMode.totalWinningTime
            mode.winningGamesCount = actualMode.winningGamesCount
            mode.shortestWinTime = actualMode.shortestWinTime
            expected.statsByMode[key] = mode
        }
        try require(actual == expected, .statsAddUp, "Stats should be \(statsText(expected)) but are \(statsText(actual)).")
        for (key, s) in actual.statsByMode {
            try require(s.gamesWon <= s.gamesPlayed && s.currentStreak <= s.longestStreak && s.longestStreak <= s.gamesWon,
                        .statsAddUp, "\(key) stats don't make sense together: \(statsText(actual)).")
        }
    }

    private func statsText(_ stats: BeecellStatistics) -> String {
        let modes = stats.statsByMode.keys.sorted().map { key in
            let s = stats.statsByMode[key]!
            return "\(key): played \(s.gamesPlayed), won \(s.gamesWon), streak \(s.currentStreak), best streak \(s.longestStreak)"
        }
        return modes.isEmpty ? "empty" : modes.joined(separator: "; ")
    }

    private func checkBoard() throws {
        let s = vm.state
        let decks = vm.options.deckCount
        let allCards = s.freeCells.flatMap(\.cards) + s.foundations.flatMap(\.cards) + s.tableau.flatMap(\.cards)
        try checkCardsKept(allCards, suits: Card.Suit.allCases, copies: decks)
        try require(allCards.allSatisfy(\.faceUp), .boardShape, "A card is face down (every Beecell card should be face up).")
        try require(s.freeCells.count == 4 * decks && s.foundations.count == 4 * decks && s.tableau.count == (decks == 1 ? 8 : 10), .boardShape,
                    "The board has \(s.freeCells.count) free cells, \(s.foundations.count) foundations and \(s.tableau.count) columns for \(decks) deck(s).")
        for cell in s.freeCells {
            try require(cell.cards.count <= 1, .boardShape, "\(pileName(cell.id)) holds \(cell.cards.count) cards.")
        }
        for foundation in s.foundations { try checkFoundation(foundation, name: pileName(foundation.id)) }
        let onFoundations = s.foundations.reduce(0) { $0 + $1.cards.count }
        try require(s.hasWon == (onFoundations == 52 * decks), .winMatchesBoard,
                    "The game says \(s.hasWon ? "won" : "not won") with \(onFoundations) of \(52 * decks) cards on the foundations.")
    }

    // MARK: - Comparing boards

    private func same(_ a: BeecellState, _ b: BeecellState) -> Bool {
        withoutClock(a) == withoutClock(b)
    }

    private func withoutClock(_ state: BeecellState) -> BeecellState {
        var copy = state
        copy.timerSeconds = 0
        copy.isTimerActive = false
        return copy
    }

    private func boardDiff(expected: BeecellState, actual: BeecellState) -> String {
        let e = withoutClock(expected), a = withoutClock(actual)
        let lines = pileDiffs(expected: e.freeCells + e.foundations + e.tableau,
                              actual: a.freeCells + a.foundations + a.tableau, name: pileName) + [
            valueDiff("The score", e.score, a.score),
            valueDiff("The move count", e.movesCount, a.movesCount),
            valueDiff("The won flag", e.hasWon, a.hasWon),
        ].compactMap { $0 }
        return lines.joined(separator: " ")
    }
}
