import Foundation

final class KlondikeMonkey: MonkeyGame {
    static let gameName = "Klondike"

    // "drawOne-standard", "drawThree-vegas", etc.
    static func randomStartMode(_ rng: inout SplitMix64) -> String {
        (rng.chance(0.5) ? "drawOne" : "drawThree") + (rng.chance(0.25) ? "-vegas" : "-standard")
    }

    private var shared: SharedGameOptions
    private var vm: GameViewModel
    private let startMode: String

    // What Undo should give back, newest last — mirrors the view model's own 100-step stack.
    private var undoShadow: [GameState] = []
    private var dealStart: GameState
    // Mirrors the view model's private movedThisDeal: set by any move, kept through
    // Undo/Restart, cleared by a fresh deal.
    private var movedThisDeal = false
    private(set) var wins = 0

    init(startMode: String) {
        self.startMode = startMode
        var options = GameOptions()
        options.drawMode = startMode.hasPrefix("drawOne") ? .drawOne : .drawThree
        options.isVegasScoring = startMode.hasSuffix("vegas")
        MonkeySandbox.saveOptions(options, key: "solitaire_options")
        shared = MonkeySandbox.quietSharedOptions()
        vm = GameViewModel(sharedOptions: shared)
        dealStart = vm.state
    }

    var setupDescription: String {
        "Klondike, \(startMode.hasPrefix("drawOne") ? "Draw 1" : "Draw 3"), \(startMode.hasSuffix("vegas") ? "Vegas scoring" : "standard scoring")"
    }

    // MARK: - Piles

    private func pile(_ id: String?) -> Pile? {
        let s = vm.state
        return ([s.stock, s.waste] + s.foundations + s.tableau).first { $0.id == id }
    }

    private func pileName(_ id: String) -> String {
        if id == "stock" { return "the stock" }
        if id == "waste" { return "the waste pile" }
        if let i = vm.state.foundations.firstIndex(where: { $0.id == id }) { return "foundation \(i + 1)" }
        return "column \(pileNumber(id) ?? 0)"
    }

    // A card the Mac board lets you pick up: any face-up tableau card (with everything on
    // top of it), or the top card of the waste pile or a foundation.
    private func canGrab(_ pile: Pile, _ index: Int) -> Bool {
        guard pile.cards.indices.contains(index), pile.cards[index].faceUp else { return false }
        switch pile.type {
        case .tableau: return true
        case .waste, .foundation: return index == pile.cards.count - 1
        case .stock, .freeCell: return false
        }
    }

    private func grabs() -> [(pile: Pile, index: Int)] {
        let s = vm.state
        return ([s.waste] + s.foundations + s.tableau).flatMap { pile in
            pile.cards.indices.filter { canGrab(pile, $0) }.map { (pile, $0) }
        }
    }

    private var dropTargets: [Pile] { vm.state.foundations + vm.state.tableau }

    // What the board would move for this drag, the way GameView's drop does it (Smart Drop
    // trims the grabbed stack to the longest part that fits), or nil if it'd snap back.
    private func resolvedDrop(_ source: Pile, _ index: Int, onto target: Pile) -> [Card]? {
        guard source.id != target.id, canGrab(source, index) else { return nil }
        return SmartDrop.resolve(cards: Array(source.cards[index...])) { vm.isValidMove(cards: $0, to: target) }
    }

    // MARK: - Choosing a step

    func randomAction(_ rng: inout SplitMix64) -> MonkeyAction {
        let modeChange = randomModeChange(&rng)
        // After a win the board is covered by the win screen: only game-level choices remain.
        if vm.state.hasWon || rng.chance(0.006) || (vm.isStuck && rng.chance(0.3)) {
            return gameLevelAction(&rng, modeChange: modeChange)
        }
        if vm.isAutocompleteAvailable && rng.chance(0.7) { return MonkeyAction(kind: .autocomplete) }

        switch Double.random(in: 0..<1, using: &rng) {
        case ..<0.62:
            let legal = grabs().flatMap { grab in
                dropTargets.filter { resolvedDrop(grab.pile, grab.index, onto: $0) != nil }
                    .map { MonkeyAction(kind: .move, from: grab.pile.id, index: grab.index, to: $0.id) }
            }
            // Useful moves first: cards home, then moves that turn a card over, then cards
            // off the waste. Otherwise mostly draw, the way a player would.
            let home = legal.filter { pile($0.to)?.type == .foundation && pile($0.from)?.type != .foundation }
            let reveals = legal.filter { move in
                guard let source = pile(move.from), source.type == .tableau, let index = move.index, index > 0 else { return false }
                return !source.cards[index - 1].faceUp
            }
            let fromWaste = legal.filter { $0.from == vm.state.waste.id }
            if home.isEmpty && reveals.isEmpty && fromWaste.isEmpty && rng.chance(0.7) { return MonkeyAction(kind: .draw) }
            return pickMove(&rng, tiers: [home, reveals, fromWaste], legal: legal) ?? MonkeyAction(kind: .draw)
        case ..<0.66:
            // A drop the rules may well refuse.
            guard let grab = rng.pick(grabs()), let target = rng.pick(dropTargets) else { return MonkeyAction(kind: .draw) }
            return MonkeyAction(kind: .move, from: grab.pile.id, index: grab.index, to: target.id)
        case ..<0.86:
            return MonkeyAction(kind: .draw)
        case ..<0.90:
            let tops = ([vm.state.waste] + vm.state.tableau).filter { !$0.isEmpty }
            guard let target = rng.pick(tops) else { return MonkeyAction(kind: .draw) }
            return MonkeyAction(kind: .tap, from: target.id, index: target.cards.count - 1)
        case ..<0.97: return MonkeyAction(kind: .undo)
        default: return MonkeyAction(kind: .hint)
        }
    }

    private func randomModeChange(_ rng: inout SplitMix64) -> MonkeyAction {
        MonkeyAction(kind: .mode, value: rng.pick(["drawOne", "drawThree", "vegas", "standard"]))
    }

    // MARK: - Describing a step (before it happens)

    func describe(_ action: MonkeyAction) -> String {
        let s = vm.state
        switch action.kind {
        case .draw:
            if !s.stock.isEmpty { return s.drawMode == .drawOne ? "Click the stock to draw a card." : "Click the stock to draw cards." }
            return vm.canRecycleStock ? "Click the empty stock to turn the waste pile back over." : "Click the empty stock (nothing should happen)."
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
            return "Double-click \(cardName(card)) on \(pileName(source.id))."
        case .undo: return "Click Undo."
        case .hint: return "Click Hint."
        case .autocomplete: return "Click Autocomplete."
        case .restart: return "Choose Restart Game."
        case .newGame: return "Choose New Game."
        case .mode:
            let label = ["drawOne": "Draw 1", "drawThree": "Draw 3", "vegas": "Vegas scoring on", "standard": "Vegas scoring off"][action.value ?? ""] ?? "?"
            return "In Options, switch to \(label) and click OK."
        case .noStress: return "Turn No Stress Mode \(shared.noStressMode ? "off" : "on")."
        case .relaunch: return "Quit the app and open it again."
        }
    }

    // MARK: - Doing a step and checking the rules

    func perform(_ action: MonkeyAction) throws {
        let before = vm.state
        var expectedStats = vm.statistics

        switch action.kind {
        case .draw:
            guard !before.hasWon else { break }
            vm.drawCard()
            noteMove(from: before)
        case .move:
            guard !before.hasWon, let source = pile(action.from), let index = action.index, let target = pile(action.to) else { break }
            if let cards = resolvedDrop(source, index, onto: target) {
                vm.moveCards(cards, from: source, to: target)
            }
            noteMove(from: before)
        case .tap:
            guard !before.hasWon, let source = pile(action.from), let card = source.topCard else { break }
            vm.doubleClickMoveToFoundation(card: card, from: source)
            noteMove(from: before)
        case .undo:
            vm.undoLastAction()
            try checkUndo(before: before)
        case .hint:
            vm.findHint()
            try require(same(vm.state, before), .hintLeavesBoard, boardDiff(expected: before, actual: vm.state))
        case .autocomplete:
            guard vm.isAutocompleteAvailable, !vm.isAutoplayRunning else { break }  // the button isn't shown
            vm.runAutocomplete()
            guard runMainQueue(until: { !vm.isAutoplayRunning }, limit: 20) else {
                throw RuleBroken(rule: .slowStep, detail: "Autocomplete was still moving cards after 20 seconds.")
            }
            noteMove(from: before)
            try require(vm.state.hasWon, .autocompleteWins,
                        "Autocomplete stopped with \(vm.state.foundations.reduce(0) { $0 + $1.cards.count }) of 52 cards on the foundations.")
        case .restart:
            vm.restartCurrentGame()
            undoShadow.removeAll()
            try require(same(vm.state, dealStart), .restartRestores, boardDiff(expected: dealStart, actual: vm.state))
            if before.hasWon {
                expectedStats.gamesPlayed += 1
                movedThisDeal = false
            }
        case .newGame:
            vm.startNewGame()
            expectNewDeal(&expectedStats, countsAsPlayed: true, wasWon: before.hasWon)
        case .mode:
            var options = vm.options
            switch action.value {
            case "drawOne": options.drawMode = .drawOne
            case "drawThree": options.drawMode = .drawThree
            case "vegas": options.isVegasScoring = true
            default: options.isVegasScoring = false
            }
            let dealsAgain = options.drawMode != vm.options.drawMode || options.isVegasScoring != vm.options.isVegasScoring
            // Turning Vegas on or off re-deals without counting a game played; a draw-mode
            // change counts as a new game (see GameViewModel.handleOptionsChanged).
            let countsAsPlayed = options.isVegasScoring == vm.options.isVegasScoring
            vm.options = options
            if dealsAgain { expectNewDeal(&expectedStats, countsAsPlayed: countsAsPlayed, wasWon: before.hasWon) }
        case .noStress:
            shared.noStressMode.toggle()
            vm.reactToNoStressModeChange()
            try require(same(vm.state, before), .boardShape, "Turning No Stress Mode on or off changed the board. " + boardDiff(expected: before, actual: vm.state))
        case .relaunch:
            try relaunch()
            expectedStats = vm.statistics
        }

        if !before.hasWon && vm.state.hasWon { wins += 1 }
        try checkStats(expected: expectedStats, wonThisStep: !before.hasWon && vm.state.hasWon)
        try checkBoard()
    }

    // A player move: if it changed the board, Undo should now give back `before`.
    private func noteMove(from before: GameState) {
        guard !same(vm.state, before) else { return }
        undoShadow.append(before)
        if undoShadow.count > 100 { undoShadow.removeFirst() }
        movedThisDeal = true
    }

    private func expectNewDeal(_ stats: inout GameStatistics, countsAsPlayed: Bool, wasWon: Bool) {
        if movedThisDeal && !wasWon { stats.currentStreak = 0 }
        if countsAsPlayed { stats.gamesPlayed += 1 }
        undoShadow.removeAll()
        movedThisDeal = false
        dealStart = vm.state
    }

    private func checkUndo(before: GameState) throws {
        guard !before.hasWon, let previous = undoShadow.popLast() else {
            try require(same(vm.state, before), .undoRestores, "Undo had nothing to undo, but the board changed. " + boardDiff(expected: before, actual: vm.state))
            return
        }
        var expected = previous
        // Standard scoring: Undo takes back the undone move's points a second time (settled rule).
        if !vm.options.isVegasScoring {
            expected.score = previous.score - max(0, before.score - previous.score)
        }
        try require(same(vm.state, expected), .undoRestores, boardDiff(expected: expected, actual: vm.state))
    }

    // Quit and reopen: settings and stats must load back exactly as they were saved.
    private func relaunch() throws {
        let options = vm.options, stats = vm.statistics, highScore = vm.highScore, noStress = shared.noStressMode
        shared = MonkeySandbox.quietSharedOptions()
        vm = GameViewModel(sharedOptions: shared)
        var expectedStats = stats
        expectedStats.gamesPlayed += 1  // opening the app deals a new game
        let problems = [
            valueDiff("No Stress Mode", noStress, shared.noStressMode),
            valueDiff("The Klondike options", options, vm.options),
            expectedStats == vm.statistics ? nil : "The Klondike stats should be \(statsText(expectedStats)) but came back as \(statsText(vm.statistics)).",
            valueDiff("The high score", highScore, vm.highScore),
        ].compactMap { $0 }
        try require(problems.isEmpty, .savedReopensSame, problems.joined(separator: " "))
        undoShadow.removeAll()
        movedThisDeal = false
        dealStart = vm.state
    }

    private func checkStats(expected: GameStatistics, wonThisStep: Bool) throws {
        let actual = vm.statistics
        var expected = expected
        if wonThisStep {
            expected.gamesWon += 1
            expected.currentStreak += 1
            expected.longestStreak = max(expected.longestStreak, expected.currentStreak)
            // Win times depend on the clock, so they aren't predicted.
            expected.totalWinningTime = actual.totalWinningTime
            expected.winningGamesCount = actual.winningGamesCount
            expected.shortestWinTime = actual.shortestWinTime
        }
        try require(actual == expected, .statsAddUp, "Stats should be \(statsText(expected)) but are \(statsText(actual)).")
        try require(actual.gamesWon <= actual.gamesPlayed && actual.currentStreak <= actual.longestStreak && actual.longestStreak <= actual.gamesWon,
                    .statsAddUp, "Stats don't make sense together: \(statsText(actual)).")
    }

    private func statsText(_ s: GameStatistics) -> String {
        "played \(s.gamesPlayed), won \(s.gamesWon), streak \(s.currentStreak), best streak \(s.longestStreak)"
    }

    private func checkBoard() throws {
        let s = vm.state
        let allCards = s.stock.cards + s.waste.cards + s.foundations.flatMap(\.cards) + s.tableau.flatMap(\.cards)
        try checkCardsKept(allCards, suits: Card.Suit.allCases, copies: 1)
        try require(s.stock.cards.allSatisfy { !$0.faceUp }, .boardShape, "A card in the stock is face up.")
        try require(s.waste.cards.allSatisfy(\.faceUp), .boardShape, "A card in the waste pile is face down.")
        for foundation in s.foundations { try checkFoundation(foundation, name: pileName(foundation.id)) }
        for column in s.tableau {
            try checkFaceDownUnderneath(column, name: pileName(column.id))
            let faceUp = column.cards.filter(\.faceUp)
            try require(zip(faceUp, faceUp.dropFirst()).allSatisfy { $0.rank == $1.rank + 1 && $0.isRed != $1.isRed }, .boardShape,
                        "\(pileName(column.id))'s face-up cards aren't a proper run: \(pileText(column)).")
        }
        let shownLimit = min(s.drawMode == .drawOne ? 1 : 3, s.waste.cards.count)
        try require(s.wasteDisplayCount <= shownLimit && (s.waste.isEmpty || s.wasteDisplayCount >= 1), .boardShape,
                    "The waste pile shows \(s.wasteDisplayCount) card(s) while holding \(s.waste.cards.count).")
        let onFoundations = s.foundations.reduce(0) { $0 + $1.cards.count }
        try require(s.hasWon == (onFoundations == 52), .winMatchesBoard,
                    "The game says \(s.hasWon ? "won" : "not won") with \(onFoundations) of 52 cards on the foundations.")
    }

    // MARK: - Comparing boards

    // The clock keeps running through everything, so it's left out of board comparisons.
    private func same(_ a: GameState, _ b: GameState) -> Bool {
        withoutClock(a) == withoutClock(b)
    }

    private func withoutClock(_ state: GameState) -> GameState {
        var copy = state
        copy.timerSeconds = 0
        copy.isTimerActive = false
        return copy
    }

    private func boardDiff(expected: GameState, actual: GameState) -> String {
        let e = withoutClock(expected), a = withoutClock(actual)
        let lines = pileDiffs(expected: [e.stock, e.waste] + e.foundations + e.tableau,
                              actual: [a.stock, a.waste] + a.foundations + a.tableau, name: pileName) + [
            valueDiff("The score", e.score, a.score),
            valueDiff("The move count", e.movesCount, a.movesCount),
            valueDiff("The times the stock was turned over", e.recyclesCount, a.recyclesCount),
            valueDiff("The number of waste cards showing", e.wasteDisplayCount, a.wasteDisplayCount),
            valueDiff("The won flag", e.hasWon, a.hasWon),
        ].compactMap { $0 }
        return lines.joined(separator: " ")
    }
}
