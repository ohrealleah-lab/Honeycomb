import Foundation

final class SpiderMonkey: MonkeyGame {
    static let gameName = "Spider"

    // The suit count: "1", "2" or "4".
    static func randomStartMode(_ rng: inout SplitMix64) -> String {
        rng.pick(["1", "2", "4"])!
    }

    private var shared: SharedGameOptions
    private var vm: SpiderViewModel
    private let startMode: String

    private var undoShadow: [SpiderState] = []
    private var dealStart: SpiderState
    private var movedThisDeal = false
    private(set) var wins = 0

    init(startMode: String) {
        self.startMode = startMode
        var options = SpiderOptions()
        options.suitCount = Int(startMode) ?? 1
        MonkeySandbox.saveOptions(options, key: "spider_options")
        shared = MonkeySandbox.quietSharedOptions()
        vm = SpiderViewModel(sharedOptions: shared)
        dealStart = vm.state
    }

    var setupDescription: String {
        "Spider, \(startMode) suit\(startMode == "1" ? "" : "s")"
    }

    // MARK: - Piles

    private func pile(_ id: String?) -> Pile? {
        vm.state.tableau.first { $0.id == id }
    }

    private func pileName(_ id: String) -> String {
        if id == "stock" { return "the stock" }
        if let i = vm.state.foundations.firstIndex(where: { $0.id == id }) { return "foundation \(i + 1)" }
        return "column \(pileNumber(id) ?? 0)"
    }

    // SpiderView only lets you pick up a card when it and everything on top of it is one
    // same-suit descending run.
    private func canGrab(_ pile: Pile, _ index: Int) -> Bool {
        pile.cards.indices.contains(index) && vm.isValidDragSequence(Array(pile.cards[index...]))
    }

    private func grabs() -> [(pile: Pile, index: Int)] {
        vm.state.tableau.flatMap { pile in pile.cards.indices.filter { canGrab(pile, $0) }.map { (pile, $0) } }
    }

    // SpiderView's drop: Smart Drop, with each candidate also checked as a grabbable run.
    private func resolvedDrop(_ source: Pile, _ index: Int, onto target: Pile) -> [Card]? {
        guard source.id != target.id, canGrab(source, index) else { return nil }
        return SmartDrop.resolve(cards: Array(source.cards[index...])) { candidate in
            vm.isValidDragSequence(candidate) && vm.isValidMove(cards: candidate, to: target)
        }
    }

    // MARK: - Choosing a step

    func randomAction(_ rng: inout SplitMix64) -> MonkeyAction {
        let modeChange = MonkeyAction(kind: .mode, value: rng.pick(["1", "2", "4"]))
        if vm.state.hasWon || rng.chance(0.006) || (vm.isStuck && rng.chance(0.3)) {
            return gameLevelAction(&rng, modeChange: modeChange)
        }
        if vm.isAutocompleteAvailable && rng.chance(0.7) { return MonkeyAction(kind: .autocomplete) }

        switch Double.random(in: 0..<1, using: &rng) {
        case ..<0.70:
            let legal = grabs().flatMap { grab in
                vm.state.tableau.filter { resolvedDrop(grab.pile, grab.index, onto: $0) != nil }
                    .map { MonkeyAction(kind: .move, from: grab.pile.id, index: grab.index, to: $0.id) }
            }
            // Useful moves first: ones that turn a card over, then same-suit builds that
            // don't just break up another same-suit run. Otherwise deal a new row.
            let reveals = legal.filter { move in
                guard let source = pile(move.from), let index = move.index, index > 0 else { return false }
                return !source.cards[index - 1].faceUp
            }
            let builds = legal.filter { move in
                guard let source = pile(move.from), let index = move.index, let top = pile(move.to)?.topCard else { return false }
                let card = source.cards[index]
                let alreadyBuilt = index > 0 && source.cards[index - 1].faceUp
                    && source.cards[index - 1].suit == card.suit && source.cards[index - 1].rank == card.rank + 1
                return card.suit == top.suit && !alreadyBuilt
            }
            if reveals.isEmpty && builds.isEmpty && !vm.state.stock.isEmpty && rng.chance(0.6) { return MonkeyAction(kind: .draw) }
            return pickMove(&rng, tiers: [reveals, builds], legal: legal) ?? MonkeyAction(kind: .draw)
        case ..<0.74:
            guard let grab = rng.pick(grabs()), let target = rng.pick(vm.state.tableau) else { return MonkeyAction(kind: .draw) }
            return MonkeyAction(kind: .move, from: grab.pile.id, index: grab.index, to: target.id)
        case ..<0.86:
            return MonkeyAction(kind: .draw)
        case ..<0.90:
            guard let grab = rng.pick(grabs()) else { return MonkeyAction(kind: .draw) }
            return MonkeyAction(kind: .tap, from: grab.pile.id, index: grab.index)
        case ..<0.97: return MonkeyAction(kind: .undo)
        default: return MonkeyAction(kind: .hint)
        }
    }

    // MARK: - Describing a step (before it happens)

    func describe(_ action: MonkeyAction) -> String {
        switch action.kind {
        case .draw:
            if vm.state.stock.isEmpty { return "Click the empty stock (nothing should happen)." }
            return vm.hasEmptyTableauColumn ? "Click the stock while a column is empty (it should refuse to deal)." : "Click the stock to deal a row."
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
            guard let source = pile(action.from), let index = action.index, source.cards.indices.contains(index) else {
                return "Double-click a card that's no longer there (nothing should happen)."
            }
            return "Double-click \(cardName(source.cards[index])) in \(pileName(source.id))."
        case .undo: return "Click Undo."
        case .hint: return "Click Hint."
        case .autocomplete: return "Click Autocomplete."
        case .restart: return "Choose Restart Game."
        case .newGame: return "Choose New Game."
        case .mode: return "In Options, switch to \(action.value ?? "?") suit\(action.value == "1" ? "" : "s") and click OK."
        case .noStress: return "Turn No Stress Mode \(shared.noStressMode ? "off" : "on")."
        case .relaunch: return "Quit the app and open it again."
        case .play, .rematch, .quit, .steal, .startOver: return "(not a Spider step)"
        }
    }

    // MARK: - Doing a step and checking the rules

    func perform(_ action: MonkeyAction) throws {
        let before = vm.state
        let suitsBefore = vm.options.suitCount
        var expectedStats = vm.statistics

        switch action.kind {
        case .draw:
            guard !before.hasWon else { break }
            vm.drawFromStock()
            noteMove(from: before)
        case .move:
            guard !before.hasWon, let source = pile(action.from), let index = action.index, let target = pile(action.to) else { break }
            if let cards = resolvedDrop(source, index, onto: target) {
                vm.moveCards(cards, from: source, to: target)
            }
            noteMove(from: before)
        case .tap:
            guard !before.hasWon, let source = pile(action.from), let index = action.index, source.cards.indices.contains(index) else { break }
            vm.doubleClickMove(card: source.cards[index], from: source)
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
            // Settled rule: Spider only offers Autocomplete when it will finish the game.
            try require(vm.state.hasWon, .autocompleteWins,
                        "Autocomplete stopped with \(vm.state.foundations.filter { !$0.isEmpty }.count) of 8 runs cleared.")
        case .restart:
            vm.restartCurrentGame()
            undoShadow.removeAll()
            try require(same(vm.state, dealStart), .restartRestores, boardDiff(expected: dealStart, actual: vm.state))
            if before.hasWon {
                expectedStats.statsBySuits[suitsBefore, default: SpiderModeStats()].gamesPlayed += 1
                movedThisDeal = false
            }
        case .newGame:
            vm.startNewGame()
            expectNewDeal(&expectedStats, abandoned: suitsBefore, wasWon: before.hasWon)
        case .mode:
            let suits = Int(action.value ?? "") ?? 1
            guard suits != suitsBefore else { break }
            var options = vm.options
            options.suitCount = suits
            vm.options = options
            expectNewDeal(&expectedStats, abandoned: suitsBefore, wasWon: before.hasWon)
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

    private func noteMove(from before: SpiderState) {
        guard !same(vm.state, before) else { return }
        undoShadow.append(before)
        if undoShadow.count > 100 { undoShadow.removeFirst() }
        movedThisDeal = true
    }

    // A fresh deal counts as played in the (possibly new) current suit count, and abandons
    // the old deal's streak if it had been played and not won.
    private func expectNewDeal(_ stats: inout SpiderStatistics, abandoned: Int, wasWon: Bool) {
        if movedThisDeal && !wasWon { stats.statsBySuits[abandoned, default: SpiderModeStats()].currentStreak = 0 }
        stats.statsBySuits[vm.options.suitCount, default: SpiderModeStats()].gamesPlayed += 1
        undoShadow.removeAll()
        movedThisDeal = false
        dealStart = vm.state
    }

    private func checkUndo(before: SpiderState) throws {
        guard !before.hasWon, let previous = undoShadow.popLast() else {
            try require(same(vm.state, before), .undoRestores, "Undo had nothing to undo, but the board changed. " + boardDiff(expected: before, actual: vm.state))
            return
        }
        try require(same(vm.state, previous), .undoRestores, boardDiff(expected: previous, actual: vm.state))
    }

    private func relaunch() throws {
        let options = vm.options, stats = vm.statistics, noStress = shared.noStressMode
        shared = MonkeySandbox.quietSharedOptions()
        vm = SpiderViewModel(sharedOptions: shared)
        var expectedStats = stats
        expectedStats.statsBySuits[options.suitCount, default: SpiderModeStats()].gamesPlayed += 1  // opening the app deals a new game
        let problems = [
            valueDiff("No Stress Mode", noStress, shared.noStressMode),
            valueDiff("The Spider options", options, vm.options),
            expectedStats == vm.statistics ? nil : "The Spider stats should be \(statsText(expectedStats)) but came back as \(statsText(vm.statistics)).",
        ].compactMap { $0 }
        try require(problems.isEmpty, .savedReopensSame, problems.joined(separator: " "))
        undoShadow.removeAll()
        movedThisDeal = false
        dealStart = vm.state
    }

    private func checkStats(expected: SpiderStatistics, wonThisStep: Bool) throws {
        let actual = vm.statistics
        var expected = expected
        if wonThisStep {
            let suits = vm.options.suitCount
            var mode = expected.statsBySuits[suits] ?? SpiderModeStats()
            let actualMode = actual.statsBySuits[suits] ?? SpiderModeStats()
            mode.gamesWon += 1
            mode.currentStreak += 1
            mode.longestStreak = max(mode.longestStreak, mode.currentStreak)
            // The high score and win times depend on the clock, so they aren't predicted.
            mode.highScore = actualMode.highScore
            mode.totalWinningTime = actualMode.totalWinningTime
            mode.winningGamesCount = actualMode.winningGamesCount
            mode.shortestWinTime = actualMode.shortestWinTime
            expected.statsBySuits[suits] = mode
        }
        try require(actual == expected, .statsAddUp, "Stats should be \(statsText(expected)) but are \(statsText(actual)).")
        for (suits, s) in actual.statsBySuits {
            try require(s.gamesWon <= s.gamesPlayed && s.currentStreak <= s.longestStreak && s.longestStreak <= s.gamesWon,
                        .statsAddUp, "\(suits)-suit stats don't make sense together: \(statsText(actual)).")
        }
    }

    private func statsText(_ stats: SpiderStatistics) -> String {
        let modes = stats.statsBySuits.keys.sorted().map { suits in
            let s = stats.statsBySuits[suits]!
            return "\(suits) suit: played \(s.gamesPlayed), won \(s.gamesWon), streak \(s.currentStreak), best streak \(s.longestStreak)"
        }
        return modes.isEmpty ? "empty" : modes.joined(separator: "; ")
    }

    private func checkBoard() throws {
        let s = vm.state
        let suits: [Card.Suit] = switch vm.options.suitCount {
        case 1: [.spades]
        case 2: [.spades, .hearts]
        default: [.spades, .hearts, .diamonds, .clubs]
        }
        let allCards = s.stock.cards + s.foundations.flatMap(\.cards) + s.tableau.flatMap(\.cards)
        try checkCardsKept(allCards, suits: suits, copies: 8 / suits.count)
        try require(s.stock.cards.allSatisfy { !$0.faceUp }, .boardShape, "A card in the stock is face up.")
        try require(s.stock.cards.count % 10 == 0, .boardShape, "The stock holds \(s.stock.cards.count) cards, which isn't a whole number of rows.")
        for foundation in s.foundations where !foundation.isEmpty {
            let isRun = foundation.cards.count == 13 && foundation.cards.enumerated().allSatisfy { i, card in
                card.rank == 13 - i && card.suit == foundation.cards[0].suit
            }
            try require(isRun, .boardShape, "\(pileName(foundation.id)) isn't one complete King-to-Ace run: \(pileText(foundation)).")
        }
        for column in s.tableau {
            try checkFaceDownUnderneath(column, name: pileName(column.id))
            // A finished King-to-Ace run on top of a column is always cleared away.
            let top13 = column.cards.suffix(13)
            let finished = top13.count == 13 && top13.enumerated().allSatisfy { i, card in
                card.faceUp && card.rank == 13 - i && card.suit == top13.first!.suit
            }
            try require(!finished, .boardShape, "\(pileName(column.id)) ends in a complete King-to-Ace run that wasn't cleared.")
        }
        try require(s.score >= 0, .boardShape, "The score went below zero: \(s.score).")
        let cleared = s.foundations.reduce(0) { $0 + $1.cards.count }
        try require(s.hasWon == (cleared == 104), .winMatchesBoard,
                    "The game says \(s.hasWon ? "won" : "not won") with \(cleared / 13) of 8 runs cleared.")
    }

    // MARK: - Comparing boards

    private func same(_ a: SpiderState, _ b: SpiderState) -> Bool {
        withoutClock(a) == withoutClock(b)
    }

    private func withoutClock(_ state: SpiderState) -> SpiderState {
        var copy = state
        copy.timerSeconds = 0
        copy.isTimerActive = false
        return copy
    }

    private func boardDiff(expected: SpiderState, actual: SpiderState) -> String {
        let e = withoutClock(expected), a = withoutClock(actual)
        let lines = pileDiffs(expected: [e.stock] + e.foundations + e.tableau,
                              actual: [a.stock] + a.foundations + a.tableau, name: pileName) + [
            valueDiff("The score", e.score, a.score),
            valueDiff("The move count", e.movesCount, a.movesCount),
            valueDiff("The won flag", e.hasWon, a.hasWon),
        ].compactMap { $0 }
        return lines.joined(separator: " ")
    }
}
