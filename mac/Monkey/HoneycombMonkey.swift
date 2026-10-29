import Foundation

// Honeycomb runs in headless mode (as the unit tests do): the AI answers each move at
// once instead of after its pause, and Swap/Sudden Death skip their animations.
final class HoneycombMonkey: MonkeyGame {
    static let gameName = "Honeycomb"
    // Hard and Ultra Hard think for up to a few seconds a move, so runs are shorter.
    static let stepsPerRun = 150
    static let runTimeout: TimeInterval = 600

    // The difficulty at the start: mostly Easy and Medium, Hard/Ultra Hard 15% of runs.
    static func randomStartMode(_ rng: inout SplitMix64) -> String {
        if rng.chance(0.15) { return rng.chance(0.5) ? "hard" : "ultraHard" }
        return rng.chance(0.5) ? "easy" : "medium"
    }

    private static let difficulties: [String: HoneycombDifficulty] = [
        "easy": .easy, "medium": .medium, "hard": .hard, "ultraHard": .ultraHard,
    ]
    private static let squareNames = ["top-left", "top-middle", "top-right", "middle-left", "center",
                                      "middle-right", "bottom-left", "bottom-middle", "bottom-right"]

    private var shared: SharedGameOptions
    private var vm: HoneycombViewModel
    private let startMode: String
    private(set) var wins = 0

    // What Undo should give back, newest last.
    private struct Snapshot: Equatable {
        var board: HoneycombBoard
        var playerHand: [HoneycombCard]
        var opponentHand: [HoneycombCard]
        var isPlayerTurn: Bool
    }
    private var undoShadow: [Snapshot] = []
    // The last genuinely new match's rules and difficulty, which every Rematch replays.
    private var freshRules: Set<HoneycombRule> = []
    private var freshDifficulty: HoneycombDifficulty = .easy

    init(startMode: String) {
        self.startMode = startMode
        UISound.isHeadlessMode = true
        var options = HoneycombViewModel.Options()
        options.difficulty = Self.difficulties[startMode] ?? .easy
        MonkeySandbox.saveOptions(options, key: "honeycomb_options")
        shared = MonkeySandbox.quietSharedOptions()
        vm = HoneycombViewModel(sharedOptions: shared)
    }

    var setupDescription: String {
        "Honeycomb, \((Self.difficulties[startMode] ?? .easy).displayName) opponent, on the setup screen with the starter deck"
    }

    func timeLimit(for action: MonkeyAction) -> TimeInterval { 15 }

    private var bank: Set<Int> { HoneycombProfileManager.shared.unlockedCardIds }

    private var snapshot: Snapshot {
        Snapshot(board: vm.board, playerHand: vm.playerHand, opponentHand: vm.opponentHand, isPlayerTurn: vm.isPlayerTurn)
    }

    private var matchInProgress: Bool { vm.gameState == .playing || vm.gameState == .suddenDeath }

    // MARK: - Choosing a step

    func randomAction(_ rng: inout SplitMix64) -> MonkeyAction {
        let setting = randomSetting(&rng)
        switch vm.gameState {
        case .setup, .suddenDeath:
            switch Double.random(in: 0..<1, using: &rng) {
            case ..<0.8: return MonkeyAction(kind: .newGame)
            case ..<0.9: return setting
            case ..<0.95: return MonkeyAction(kind: .noStress)
            default: return MonkeyAction(kind: .relaunch)
            }
        case .gameOver:
            if vm.matchOutcome == .win && rng.chance(0.5) {
                let stealable = vm.board.cells.indices.filter { i in vm.board.cells[i].card.map(vm.isStealEligible) ?? false }
                let cell = (rng.chance(0.8) ? rng.pick(stealable) : nil) ?? Int.random(in: 0..<9, using: &rng)
                return MonkeyAction(kind: .steal, value: rng.chance(0.85) ? "confirm" : "cancel", cell: cell)
            }
            switch Double.random(in: 0..<1, using: &rng) {
            case ..<0.45: return MonkeyAction(kind: .rematch)
            case ..<0.75: return MonkeyAction(kind: .newGame)
            case ..<0.80: return MonkeyAction(kind: .quit)
            case ..<0.89: return setting
            case ..<0.93: return MonkeyAction(kind: .noStress)
            case ..<0.995: return MonkeyAction(kind: .relaunch)
            default: return MonkeyAction(kind: .startOver)
            }
        case .playing:
            if rng.chance(0.03) {
                return rng.pick([MonkeyAction(kind: .newGame), MonkeyAction(kind: .restart), MonkeyAction(kind: .quit),
                                 setting, MonkeyAction(kind: .noStress), MonkeyAction(kind: .relaunch)])!
            }
            switch Double.random(in: 0..<1, using: &rng) {
            case ..<0.06: return MonkeyAction(kind: .undo)
            case ..<0.10: return MonkeyAction(kind: .hint)
            case ..<0.18:
                // Any card onto any square: often one the game must refuse.
                return MonkeyAction(kind: .play, index: Int.random(in: 0..<max(1, vm.playerHand.count), using: &rng),
                                    cell: Int.random(in: 0..<9, using: &rng))
            default:
                let hands = vm.mandatedPlayerHandIndex.map { [$0] } ?? Array(vm.playerHand.indices)
                let squares = vm.board.cells.indices.filter { vm.board.cells[$0].card == nil }
                guard let hand = rng.pick(hands), let square = rng.pick(squares) else { return MonkeyAction(kind: .newGame) }
                return MonkeyAction(kind: .play, index: hand, cell: square)
            }
        }
    }

    private func randomSetting(_ rng: inout SplitMix64) -> MonkeyAction {
        let rule = rng.pick(HoneycombRule.allCases)!.rawValue
        let other = rng.pick(HoneycombRule.allCases)!.rawValue
        let value = rng.pick([
            "difficulty:" + rng.pick(Array(Self.difficulties.keys).sorted())!,
            "deck:\(Int.random(in: 0..<5, using: &rng))",
            "ban:" + rule, "ban:Normal Mode", "unban:" + rule, "unban:Normal Mode",
            "normal:on", "normal:off",
            "pick:" + rule, "pick:" + [rule, other].sorted().joined(separator: ","), "pick:none",
        ])!
        return MonkeyAction(kind: .mode, value: value)
    }

    // MARK: - Describing a step (before it happens)

    private func cardText(_ card: HoneycombCard) -> String {
        "\(card.data.name) (\(card.data.stars)★)"
    }

    func describe(_ action: MonkeyAction) -> String {
        switch action.kind {
        case .play:
            let square = Self.squareNames[safe: action.cell ?? -1] ?? "a square"
            guard let index = action.index, vm.playerHand.indices.contains(index) else {
                return "Try to play a card that isn't in your hand onto the \(square) square (nothing should happen)."
            }
            let refused = isLegalPlay(handIndex: index, cell: action.cell ?? -1) ? "" : " The game should refuse it."
            return "Play \(cardText(vm.playerHand[index])), card \(index + 1) in your hand, onto the \(square) square.\(refused)"
        case .undo: return "Click Undo."
        case .hint: return "Click Hint."
        case .newGame:
            return matchInProgress ? "Click New Match in the middle of the match (it counts as a loss)." : "Click New Match."
        case .restart: return "Choose Restart (it counts as a loss mid-match)."
        case .rematch: return "Click Rematch."
        case .quit: return matchInProgress ? "Click Quit Match and confirm (it counts as a loss)." : "Click Quit Match."
        case .steal:
            let square = Self.squareNames[safe: action.cell ?? -1] ?? "a square"
            let name = vm.board.cells[safe: action.cell ?? -1]?.card.map(cardText) ?? "an empty square"
            return "Click Take a Card, pick \(name) on the \(square) square, then \(action.value == "cancel" ? "cancel" : "confirm")."
        case .mode: return "In the rules settings, \(settingText(action.value ?? ""))."
        case .noStress: return "Turn No Stress Mode \(shared.noStressMode ? "off" : "on")."
        case .relaunch: return "Quit the app and open it again, then go back to Honeycomb."
        case .startOver: return "In the Card Bank, choose Start Over and confirm."
        case .draw, .move, .tap, .autocomplete: return "(not a Honeycomb step)"
        }
    }

    private func settingText(_ value: String) -> String {
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        let detail = parts.count > 1 ? parts[1] : ""
        switch parts.first ?? "" {
        case "difficulty": return "set the opponent to \(Self.difficulties[detail]?.displayName ?? detail)"
        case "deck": return "make Deck \((Int(detail) ?? 0) + 1) the active deck"
        case "ban": return "ban \(detail)"
        case "unban": return "unban \(detail)"
        case "normal": return detail == "on" ? "turn Normal Mode on (no rules)" : "turn Normal Mode off"
        case "pick": return detail == "none" ? "clear the picked rules (back to roulette)" : "pick the rules \(detail.replacingOccurrences(of: ",", with: " and "))"
        default: return value
        }
    }

    // MARK: - Doing a step and checking the rules

    func perform(_ action: MonkeyAction) throws {
        let before = snapshot
        let stateBefore = vm.gameState
        let statsBefore = vm.stats
        let bankBefore = bank
        let rulesBefore = vm.activeRules
        let difficultyBefore = vm.matchDifficulty
        let noStressBefore = vm.noStressModeThisMatch
        var expected = statsBefore
        var bankChange: Int? = nil       // a card that should now be in the bank
        var bankMayReset = false
        var dealt: Bool? = nil           // a match was dealt: true if fresh, false if a rematch

        switch action.kind {
        case .play:
            guard stateBefore == .playing, let cell = action.cell, (0..<9).contains(cell) else { break }
            let index = action.index ?? -1
            let legal = isLegalPlay(handIndex: index, cell: cell)
            let accepted = vm.playerPlayCard(handIndex: index, boardIndex: cell)
            if !accepted {
                try require(!legal, .legalMoveRefused, "Playing card \(index + 1) onto the \(Self.squareNames[cell]) square was refused, though that square was empty and the card was allowed.")
                try require(snapshot == before, .refusedMoveChanged, "The refused move still changed the board or hands.")
                break
            }
            try require(legal, .refusedMoveChanged, "The game accepted card \(index + 1) onto the \(Self.squareNames[cell]) square, which the rules don't allow.")
            undoShadow.append(before)
            try settle()
            if vm.stats.suddenDeathCount > statsBefore.suddenDeathCount {
                try require(rulesBefore.contains(.suddenDeath), .statsAddUp, "Sudden Death started in a match without the Swarm to the Death rule.")
                expected.suddenDeathCount += 1
                undoShadow.removeAll()  // a new round starts with nothing to undo
            }
            if vm.gameState == .gameOver {
                undoShadow.removeAll()
                switch vm.matchOutcome {
                case .win:
                    expected.recordGame(won: true, drawn: false, captures: 0, sessionCombos: 0, flawless: false, difficulty: difficultyBefore)
                    wins += 1
                case .loss: expected.recordGame(won: false, drawn: false, captures: 0, sessionCombos: 0, flawless: false)
                default: expected.recordGame(won: false, drawn: true, captures: 0, sessionCombos: 0, flawless: false)
                }
            }
        case .undo:
            guard vm.canUndo else { break }  // the button is disabled
            vm.undoLastAction()
            guard let previous = undoShadow.popLast() else {
                throw RuleBroken(rule: .undoRestores, detail: "Undo was offered with no move of yours to undo.")
            }
            try require(snapshot == previous, .undoRestores, snapshotDiff(expected: previous, actual: snapshot))
        case .hint:
            guard stateBefore == .playing else { break }
            vm.findHint()
            try require(snapshot == before, .hintLeavesBoard, snapshotDiff(expected: before, actual: snapshot))
            if let hint = vm.activeHint {
                try require(isLegalPlay(handIndex: hint.handIndex, cell: hint.boardIndex), .hintIsLegal,
                            "Hint suggested card \(hint.handIndex + 1) onto square \(hint.boardIndex + 1), which isn't a legal move.")
            }
        case .newGame, .restart:
            if matchInProgress { expected.recordGame(won: false, drawn: false, captures: 0, sessionCombos: 0, flawless: false) }
            if action.kind == .newGame { vm.startNewGame() } else { vm.restartCurrentGame() }
            dealt = true
            try settle()
        case .rematch:
            guard stateBefore == .gameOver else { break }
            let replaysOpponent = vm.canRematch  // otherwise Rematch deals a fresh match
            vm.rematch()
            dealt = !replaysOpponent
            try settle()
        case .quit:
            guard stateBefore != .setup else { break }
            if matchInProgress { expected.recordGame(won: false, drawn: false, captures: 0, sessionCombos: 0, flawless: false) }
            vm.quitMatch()
            try require(vm.gameState == .setup && vm.board.cells.allSatisfy { $0.card == nil }, .boardShape,
                        "After Quit Match the board should be empty on the setup screen.")
        case .steal:
            guard stateBefore == .gameOver, vm.matchOutcome == .win, let cell = action.cell, (0..<9).contains(cell) else { break }
            let card = vm.board.cells[cell].card
            let eligible = card.map { !bankBefore.contains($0.data.id) && (vm.stealProtectionActive || ($0.originalOwner == .opponent && $0.owner == .player)) } ?? false
            let allowed = eligible && !vm.noStressModeThisMatch && !vm.hasStolenThisMatch
            vm.requestSteal(boardIndex: cell)
            if action.value == "cancel" { vm.cancelPendingSteal() } else { vm.confirmPendingSteal() }
            if allowed && action.value != "cancel", let card {
                bankChange = card.data.id
                expected.cardsStolen += 1
            }
        case .mode:
            applySetting(action.value ?? "")
            try require(vm.activeRules == rulesBefore && vm.matchDifficulty == difficultyBefore, .settingsLocked,
                        "Changing a setting changed the current match's rules or opponent.")
        case .noStress:
            shared.noStressMode.toggle()
            try require(vm.noStressModeThisMatch == noStressBefore, .settingsLocked,
                        "Turning No Stress Mode on or off changed the match already being played.")
        case .relaunch:
            try relaunch()
            expected = vm.stats
        case .startOver:
            guard stateBefore != .playing else { break }
            vm.startOver()
            bankMayReset = true
            expected.timesStartedOver += 1
            try require(vm.options.activeDeckIndex == 0, .savedReopensSame, "After Start Over, Deck 1 should be the active deck.")
        case .draw, .move, .tap, .autocomplete:
            break
        }

        if let dealt { try checkDeal(fresh: dealt) }
        try checkStats(expected: expected, before: statsBefore)
        try checkBank(before: bankBefore, added: bankChange, mayReset: bankMayReset)
        try checkBoard()
    }

    // Lets the turn finish: the AI's reply, a Sudden Death round starting.
    private func settle() throws {
        guard runMainQueue(until: { vm.gameState != .suddenDeath && !vm.isAnimatingPlacement }, limit: 10) else {
            throw RuleBroken(rule: .turnNeverComes, detail: "Ten seconds after the move the match was still \(vm.gameState == .suddenDeath ? "waiting to start Sudden Death" : "animating").")
        }
    }

    private func isLegalPlay(handIndex: Int, cell: Int) -> Bool {
        vm.gameState == .playing && vm.isPlayerTurn && !vm.isAnimatingPlacement
            && vm.playerHand.indices.contains(handIndex) && (0..<9).contains(cell) && vm.board.cells[cell].card == nil
            && (vm.mandatedPlayerHandIndex == nil || vm.mandatedPlayerHandIndex == handIndex)
    }

    private func applySetting(_ value: String) {
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        let detail = parts.count > 1 ? parts[1] : ""
        var options = vm.options
        switch parts.first ?? "" {
        case "difficulty": options.difficulty = Self.difficulties[detail] ?? options.difficulty
        case "deck": options.activeDeckIndex = Int(detail) ?? 0
        case "ban": options.bannedRules.insert(detail)
        case "unban": options.bannedRules.remove(detail)
        case "normal": options.forceNormalMode = detail == "on"
        case "pick":
            options.selectedRules = detail == "none" ? [] : Set(detail.split(separator: ",").compactMap { HoneycombRule(rawValue: String($0)) })
        default: return
        }
        vm.options = options
    }

    // A freshly dealt match (or rematch) follows the settings it was dealt under.
    private func checkDeal(fresh: Bool) throws {
        let options = vm.options
        let rules = Set(vm.activeRules)
        try require(vm.gameState == .playing, .dealFollowsSettings, "After dealing, the match isn't being played (it's \(vm.gameState.rawValue)).")
        try require(vm.noStressModeThisMatch == shared.noStressMode, .dealFollowsSettings, "The new match didn't pick up the current No Stress Mode setting.")
        if !fresh {
            try require(rules == freshRules && vm.matchDifficulty == freshDifficulty, .dealFollowsSettings,
                        "Rematch should replay the same rules (\(names(freshRules))) and opponent, but dealt \(names(rules)).")
        } else {
            freshRules = rules
            freshDifficulty = vm.matchDifficulty
            try require(vm.matchDifficulty == options.difficulty, .dealFollowsSettings, "The new match's opponent isn't the chosen difficulty.")
            if options.forceNormalMode {
                try require(rules.isEmpty, .dealFollowsSettings, "Normal Mode is on, but the match has rules: \(names(rules)).")
            } else if !options.selectedRules.isEmpty {
                try require(rules == options.selectedRules, .dealFollowsSettings, "The picked rules are \(names(options.selectedRules)) but the match has \(names(rules)).")
            } else {
                let banned = rules.filter { options.bannedRules.contains($0.rawValue) }
                try require(banned.isEmpty, .dealFollowsSettings, "Banned rules showed up anyway: \(names(banned)).")
                let pairs: [(HoneycombRule, HoneycombRule)] = [(.ascension, .descension), (.order, .chaos), (.allOpen, .threeOpen),
                                                               (.allOpen, .bombShelter), (.threeOpen, .bombShelter)]
                for (a, b) in pairs {
                    try require(!(rules.contains(a) && rules.contains(b)), .dealFollowsSettings, "\(a.rawValue) and \(b.rawValue) can't be rolled together.")
                }
                if vm.matchDifficulty == .easy {
                    try require(rules.isDisjoint(with: [.ascension, .descension, .fallenAce]), .dealFollowsSettings,
                                "An Easy match rolled a rule kept out of Easy: \(names(rules)).")
                }
                let maxRules = vm.matchDifficulty == .hard || vm.matchDifficulty == .ultraHard ? 4 : 2
                try require(rules.count <= maxRules, .dealFollowsSettings, "The roulette rolled \(rules.count) rules: \(names(rules)).")
                let pool = HoneycombRule.allCases.filter { !options.bannedRules.contains($0.rawValue) }
                if options.bannedRules.contains("Normal Mode") && !pool.isEmpty {
                    try require(!rules.isEmpty, .dealFollowsSettings, "Normal Mode is banned, but the match has no rules.")
                }
            }
        }

        let all = allCards
        let mine = all.filter { $0.originalOwner == .player }
        let theirs = all.filter { $0.originalOwner == .opponent }
        // Your saved deck is what you're dealt (No Stress deals its own strong deck instead).
        let deck = HoneycombProfileManager.shared.savedDecks[safe: options.activeDeckIndex]?.cardIds ?? []
        if !vm.noStressModeThisMatch && deck.count == 5 {
            try require(mine.map(\.data.id).sorted() == deck.sorted(), .dealFollowsSettings,
                        "You were dealt cards \(mine.map(\.data.name)) instead of Deck \(options.activeDeckIndex + 1).")
        }
        // Favor New Cards: a fresh opponent always brings a card you don't own yet, if its
        // tiers have one left. (Ascension/Descension can override this: known, left as is.)
        if fresh && !vm.noStressModeThisMatch && rules.isDisjoint(with: [.ascension, .descension]) {
            let owned = bank
            if theirs.allSatisfy({ owned.contains($0.data.id) }) {
                let tiers = Set(theirs.map(\.data.stars))
                let unownedLeft = HoneycombDatabase.shared.allCards.contains { tiers.contains($0.stars) && !owned.contains($0.id) }
                try require(!unownedLeft, .dealFollowsSettings, "Every card the new opponent brought is already in your Card Bank, though new ones were still available.")
            }
        }
    }

    // Reopening the app: stats, options and the Card Bank load back as they were saved.
    private func relaunch() throws {
        let stats = vm.stats, options = vm.options, noStress = shared.noStressMode
        let savedBank = UserDefaults.standard.array(forKey: "honeycomb_unlocked_cards") as? [Int] ?? []
        let savedDecks = UserDefaults.standard.data(forKey: "honeycomb_saved_decks")
            .flatMap { try? JSONDecoder().decode([HoneycombDeckState].self, from: $0) } ?? []
        shared = MonkeySandbox.quietSharedOptions()
        vm = HoneycombViewModel(sharedOptions: shared)
        undoShadow.removeAll()
        let problems = [
            valueDiff("No Stress Mode", noStress, shared.noStressMode),
            valueDiff("The Honeycomb options", options, vm.options),
            stats == vm.stats ? nil : "The Honeycomb stats should be \(statsText(stats)) but came back as \(statsText(vm.stats)).",
            Set(savedBank) == bank ? nil : "The saved Card Bank has \(savedBank.count) cards but the game had \(bank.count).",
            savedDecks == HoneycombProfileManager.shared.savedDecks ? nil : "The saved decks don't match the decks the game had.",
            valueDiff("The screen after reopening", HoneycombGameState.setup.rawValue, vm.gameState.rawValue),
        ].compactMap { $0 }
        try require(problems.isEmpty, .savedReopensSame, problems.joined(separator: " "))
    }

    private func checkStats(expected: HoneycombStats, before: HoneycombStats) throws {
        let actual = vm.stats
        var expected = expected
        // Captures, combos, Fallen Aces and flawless wins depend on the play itself; they
        // only have to stay put unless a match was recorded.
        expected.cardsCaptured = actual.cardsCaptured
        expected.samePlusTriggers = actual.samePlusTriggers
        expected.fallenAces = actual.fallenAces
        expected.flawlessVictories = actual.flawlessVictories
        try require(actual == expected, .statsAddUp, "Stats should be \(statsText(expected)) but are \(statsText(actual)).")
        if actual.gamesPlayed == before.gamesPlayed {
            try require(actual.cardsCaptured == before.cardsCaptured && actual.samePlusTriggers == before.samePlusTriggers
                        && actual.fallenAces == before.fallenAces && actual.flawlessVictories == before.flawlessVictories,
                        .statsAddUp, "Capture or combo stats changed without a match being recorded.")
        }
        let difficultyWins = actual.easyWins + actual.mediumWins + actual.hardWins + actual.ultraHardWins
        try require(actual.gamesPlayed == actual.matchesWon + actual.matchesLost + actual.matchesDrawn
                    && actual.currentWinStreak <= actual.longestWinStreak && actual.longestWinStreak <= actual.matchesWon
                    && difficultyWins == actual.matchesWon && actual.flawlessVictories <= actual.matchesWon,
                    .statsAddUp, "Stats don't make sense together: \(statsText(actual)).")
    }

    private func statsText(_ s: HoneycombStats) -> String {
        "played \(s.gamesPlayed), won \(s.matchesWon), lost \(s.matchesLost), drawn \(s.matchesDrawn), streak \(s.currentWinStreak), best streak \(s.longestWinStreak), stolen \(s.cardsStolen), Sudden Deaths \(s.suddenDeathCount)"
    }

    // The Card Bank only ever gains a card by a real steal (Start Over rebuilds it).
    private func checkBank(before: Set<Int>, added: Int?, mayReset: Bool) throws {
        guard !mayReset else { return }
        let expected = added.map { before.union([$0]) } ?? before
        try require(bank == expected, .cardBankChanges, added == nil
                    ? "The Card Bank went from \(before.count) to \(bank.count) cards without a steal."
                    : "Stealing should have added 1 card to the Card Bank (\(before.count) → \(before.count + 1)), but it has \(bank.count).")
    }

    private var allCards: [HoneycombCard] {
        vm.board.cells.compactMap(\.card) + vm.playerHand + vm.opponentHand
    }

    private func checkBoard() throws {
        try require(vm.board.cells.count == 9, .boardShape, "The board has \(vm.board.cells.count) squares.")
        if vm.gameState != .setup {
            let cards = allCards
            try require(cards.count == 10 && Set(cards.map(\.id)).count == 10, .cardsKept,
                        "The board and hands hold \(cards.count) cards (\(Set(cards.map(\.id)).count) different) instead of 10.")
            let mine = cards.filter { $0.originalOwner == .player }.count
            try require(mine == 5, .cardsKept, "\(mine) of the 10 cards came from your deck instead of 5.")
        }
        if vm.gameState == .playing {
            try require(vm.isPlayerTurn && !vm.isAnimatingPlacement, .turnNeverComes,
                        "After the step it's still \(vm.isPlayerTurn ? "animating" : "the opponent's turn"), but the opponent never moved.")
            try require(!vm.board.isFull, .winMatchesBoard, "The board is full but the match is still being played.")
        }
        if vm.gameState == .gameOver {
            let you = vm.board.playerScore + vm.playerHand.count
            let them = vm.board.opponentScore + vm.opponentHand.count
            let outcome: HoneycombMatchOutcome = you > them ? .win : you < them ? .loss : .tie
            try require(vm.board.isFull, .winMatchesBoard, "The match is over but the board isn't full.")
            try require(vm.matchOutcome == outcome, .winMatchesBoard, "The score is \(you)–\(them) but the result says \(vm.matchOutcome).")
            try require(outcome != .tie || !vm.activeRules.contains(.suddenDeath), .winMatchesBoard,
                        "The match ended in a tie although Swarm to the Death should have started overtime.")
        }
    }

    // MARK: - Comparing

    private func names(_ rules: Set<HoneycombRule>) -> String {
        rules.isEmpty ? "none" : rules.map(\.rawValue).sorted().joined(separator: ", ")
    }

    private func snapshotDiff(expected: Snapshot, actual: Snapshot) -> String {
        var lines: [String] = []
        for i in 0..<9 {
            let e = expected.board.cells[i].card, a = actual.board.cells[i].card
            if e != a {
                lines.append("The \(Self.squareNames[i]) square should hold \(e.map { "\($0.data.name) (\($0.owner.rawValue))" } ?? "nothing") but holds \(a.map { "\($0.data.name) (\($0.owner.rawValue))" } ?? "nothing").")
            }
        }
        if expected.playerHand != actual.playerHand {
            lines.append("Your hand should be \(expected.playerHand.map(\.data.name)) but is \(actual.playerHand.map(\.data.name)).")
        }
        if expected.opponentHand != actual.opponentHand {
            lines.append("The opponent's hand should be \(expected.opponentHand.map(\.data.name)) but is \(actual.opponentHand.map(\.data.name)).")
        }
        if let line = valueDiff("Whose turn it is (yours)", expected.isPlayerTurn, actual.isPlayerTurn) { lines.append(line) }
        return lines.isEmpty ? "Something about the board changed (square identities or card details)." : lines.joined(separator: " ")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
