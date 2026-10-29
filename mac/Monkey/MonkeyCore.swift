import Foundation

// The overnight monkey test: plays thousands of random but legal actions in Klondike,
// Beecell and Spider, checking rules that must always hold after every step. Each run is
// driven by a seed, so a failure replays exactly and can be shrunk to the fewest steps that
// still show it. See ../../monkey/REPORT.md for what it last found.

// One step the monkey takes, in the same terms the Mac board uses (a pile and a card
// position in it), so a saved case still reads sensibly and replays after unrelated
// steps are removed. Plain optional fields rather than an enum with payloads so the case
// files stay readable JSON.
struct MonkeyAction: Codable, Equatable {
    var kind: Kind
    var from: String? = nil   // pile id the card is grabbed from
    var index: Int? = nil     // card position in `from` (0 = bottom of the pile)
    var to: String? = nil     // pile id it is dropped on
    var value: String? = nil  // the new setting, for `.mode`; "confirm"/"cancel" for `.steal`
    var cell: Int? = nil      // Honeycomb board square, 0-8 (row by row from the top left)

    enum Kind: String, Codable {
        case draw, move, tap, undo, hint, autocomplete, restart, newGame, mode, noStress, relaunch
        case play, rematch, quit, steal, startOver  // Honeycomb
    }
}

// The rules checked after every step. `plain` is what the report says went wrong.
enum MonkeyRule: String, Codable {
    case cardsKept = "cards-kept"
    case boardShape = "board-shape"
    case winMatchesBoard = "win-matches-board"
    case undoRestores = "undo-restores"
    case restartRestores = "restart-restores"
    case hintLeavesBoard = "hint-leaves-board"
    case autocompleteWins = "autocomplete-wins"
    case statsAddUp = "stats-add-up"
    case savedReopensSame = "saved-reopens-same"
    case turnNeverComes = "turn-never-comes"
    case legalMoveRefused = "legal-move-refused"
    case refusedMoveChanged = "refused-move-changed"
    case hintIsLegal = "hint-is-legal"
    case cardBankChanges = "card-bank-changes"
    case settingsLocked = "settings-locked"
    case dealFollowsSettings = "deal-follows-settings"
    case slowStep = "slow-step"
    case crash = "crash"
    case freeze = "freeze"

    var plain: String {
        switch self {
        case .cardsKept: return "A card went missing or was duplicated"
        case .boardShape: return "The board ended up in a shape the rules don't allow"
        case .winMatchesBoard: return "The game's \"won\" flag didn't match the board"
        case .undoRestores: return "Undo didn't give back exactly the board from before"
        case .restartRestores: return "Restart didn't give back the original deal"
        case .hintLeavesBoard: return "Asking for a hint changed the board"
        case .autocompleteWins: return "Autocomplete was offered but didn't finish the game"
        case .statsAddUp: return "The stats didn't add up"
        case .savedReopensSame: return "Saved settings or stats came back different after reopening the app"
        case .turnNeverComes: return "The game got stuck waiting for a turn that never came"
        case .legalMoveRefused: return "The game refused a move the rules allow"
        case .refusedMoveChanged: return "A move the game refused still changed the board, or it allowed a move it should refuse"
        case .hintIsLegal: return "Hint suggested a move the rules don't allow"
        case .cardBankChanges: return "The Card Bank changed when it shouldn't have, or didn't when it should"
        case .settingsLocked: return "A setting changed the match in progress instead of waiting for the next one"
        case .dealFollowsSettings: return "A new match didn't follow the chosen rules, difficulty or deck"
        case .slowStep: return "One step took far too long"
        case .crash: return "The app crashed"
        case .freeze: return "The app froze"
        }
    }
}

struct RuleBroken: Error {
    let rule: MonkeyRule
    let detail: String
}

func require(_ condition: @autoclosure () -> Bool, _ rule: MonkeyRule, _ detail: @autoclosure () -> String) throws {
    if !condition() { throw RuleBroken(rule: rule, detail: detail()) }
}

// What every game's driver provides. A driver owns its view model, picks random actions
// a player could really take, performs them through the same calls the Mac views make,
// and checks the rules afterwards.
protocol MonkeyGame: AnyObject {
    static var gameName: String { get }
    static func randomStartMode(_ rng: inout SplitMix64) -> String
    init(startMode: String)
    var setupDescription: String { get }
    var wins: Int { get }   // games won so far, to show the monkey plays deep enough to win
    static var stepsPerRun: Int { get }
    static var runTimeout: TimeInterval { get }
    func timeLimit(for action: MonkeyAction) -> TimeInterval
    func randomAction(_ rng: inout SplitMix64) -> MonkeyAction
    func describe(_ action: MonkeyAction) -> String
    func perform(_ action: MonkeyAction) throws
}

extension MonkeyGame {
    static var stepsPerRun: Int { 1500 }
    static var runTimeout: TimeInterval { 120 }
    func timeLimit(for action: MonkeyAction) -> TimeInterval { action.kind == .autocomplete ? 20 : 3 }
}

enum MonkeyGames {
    static let all: [any MonkeyGame.Type] = [KlondikeMonkey.self, BeecellMonkey.self, SpiderMonkey.self, HoneycombMonkey.self]

    static func named(_ name: String) -> (any MonkeyGame.Type)? {
        all.first { $0.gameName.lowercased() == name.lowercased() }
    }
}

// Keeps a monkey run away from anything real: its own preferences (a bare executable gets
// a domain named after itself, never the app's com.leah.Honeycomb), a throwaway folder for
// custom art, no sound, and no animation pauses.
enum MonkeySandbox {
    static func prepare() {
        let domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        precondition(!domain.lowercased().contains("honeycomb"), "Monkey refused to clear preferences domain \(domain)")
        UserDefaults.standard.removePersistentDomain(forName: domain)
        AppSupportLocation.testOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("honeycomb-monkey-\(getpid())")
        UISound.isEnabled = false
        AutoplayPacing.stepDelay = 0
    }

    // Shared options with sound off, the way every monkey view model is built.
    static func quietSharedOptions() -> SharedGameOptions {
        let options = SharedGameOptions()
        options.isSoundEnabled = false
        return options
    }

    static func saveOptions<T: Encodable>(_ options: T, key: String) {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// Lets queued main-thread work run (Autocomplete's next move, short UI timers) until
// `done` is true. Returns false if that didn't happen within `limit` seconds.
func runMainQueue(until done: () -> Bool, limit: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(limit)
    while !done() {
        if Date() > deadline { return false }
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
    }
    return true
}

extension SplitMix64 {
    mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < probability
    }

    mutating func pick<T>(_ items: [T]) -> T? {
        items.isEmpty ? nil : items[Int.random(in: 0..<items.count, using: &self)]
    }
}

// Game-level choices (a new deal, Restart, a settings change, reopening the app). Drivers
// only take one now and then, or when the game is won or stuck, so most games get played
// deep enough to reach wins and Autocomplete.
func gameLevelAction(_ rng: inout SplitMix64, modeChange: MonkeyAction) -> MonkeyAction {
    switch Double.random(in: 0..<1, using: &rng) {
    case ..<0.35: return MonkeyAction(kind: .newGame)
    case ..<0.6: return MonkeyAction(kind: .restart)
    case ..<0.75: return modeChange
    case ..<0.9: return MonkeyAction(kind: .relaunch)
    default: return MonkeyAction(kind: .noStress)
    }
}

// Most of the time, a move from the best non-empty tier; otherwise any legal move.
func pickMove(_ rng: inout SplitMix64, tiers: [[MonkeyAction]], legal: [MonkeyAction]) -> MonkeyAction? {
    if rng.chance(0.8), let best = tiers.first(where: { !$0.isEmpty }) { return rng.pick(best) }
    return rng.pick(legal)
}

// MARK: - Shared rule checks

func cardName(_ card: Card) -> String { "\(card.rankString)\(card.suit.symbol)" }

private func cardKey(_ card: Card) -> String { "\(card.suit.rawValue)-\(card.rank)" }

// Every card the deal started with is still on the board exactly once.
func checkCardsKept(_ cards: [Card], suits: [Card.Suit], copies: Int) throws {
    var expected: [String: Int] = [:]
    for suit in suits {
        for rank in 1...13 { expected["\(suit.rawValue)-\(rank)", default: 0] += copies }
    }
    var actual: [String: Int] = [:]
    for card in cards { actual[cardKey(card), default: 0] += 1 }
    if actual != expected {
        let missing = expected.filter { actual[$0.key, default: 0] < $0.value }.map(\.key).sorted()
        let extra = actual.filter { expected[$0.key, default: 0] < $0.value }.map(\.key).sorted()
        throw RuleBroken(rule: .cardsKept, detail: "Board has \(cards.count) cards. Missing: \(missing.isEmpty ? "none" : missing.joined(separator: ", ")). Extra: \(extra.isEmpty ? "none" : extra.joined(separator: ", ")).")
    }
    try require(Set(cards.map(\.id)).count == cards.count, .cardsKept, "Two cards on the board share the same identity.")
}

// A foundation is built up from the Ace in one suit.
func checkFoundation(_ pile: Pile, name: String) throws {
    for (position, card) in pile.cards.enumerated() {
        try require(card.rank == position + 1 && card.suit == pile.cards[0].suit && card.faceUp, .boardShape,
                     "\(name) isn't a clean Ace-up run of one suit: \(pile.cards.map(cardName).joined(separator: " ")).")
    }
}

// In a tableau column, face-down cards only ever sit underneath face-up ones, and the top
// card of a non-empty column is face up.
func checkFaceDownUnderneath(_ pile: Pile, name: String) throws {
    if let firstUp = pile.cards.firstIndex(where: { $0.faceUp }) {
        try require(pile.cards[firstUp...].allSatisfy { $0.faceUp }, .boardShape, "\(name) has a face-down card on top of a face-up one.")
    } else {
        try require(pile.cards.isEmpty, .boardShape, "\(name)'s top card is face down.")
    }
}

// Face-down cards are shown in brackets, e.g. "(Q♣) 7♥ 6♠".
func pileText(_ pile: Pile) -> String {
    pile.cards.isEmpty ? "empty" : pile.cards.map { $0.faceUp ? cardName($0) : "(\(cardName($0)))" }.joined(separator: " ")
}

// Plain lines naming each pile that isn't what it should be, for a failure's detail.
func pileDiffs(expected: [Pile], actual: [Pile], name: (String) -> String) -> [String] {
    var lines = zip(expected, actual).compactMap { e, a in
        e == a ? nil : "\(name(e.id)) should be [\(pileText(e))] but is [\(pileText(a))]."
    }
    if expected.count != actual.count {
        lines.append("There should be \(expected.count) piles of this kind but there are \(actual.count).")
    }
    return lines
}

func valueDiff<T: Equatable>(_ label: String, _ expected: T, _ actual: T) -> String? {
    expected == actual ? nil : "\(label) should be \(expected) but is \(actual)."
}

func pileNumber(_ id: String) -> Int? {
    id.split(separator: "_").last.flatMap { Int($0) }.map { $0 + 1 }
}
