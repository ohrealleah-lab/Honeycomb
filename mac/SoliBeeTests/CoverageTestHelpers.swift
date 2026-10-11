import Foundation

// Shared plumbing for the coverage-focused suites (SpiderGameplayTests,
// SettingsPersistenceTests, AppCoordinatorBehaviorTests, ...). Each suite builds fixed
// card layouts instead of relying on random deals, so a failure always means the rules
// changed, never "unlucky shuffle".

/// Fails the whole test run with a clear "❌" message (the runner has no XCTest to
/// report through, so a trap is how every suite signals failure).
func expect(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String,
            file: StaticString = #fileID, line: UInt = #line) {
    if !condition() { fatalError("❌ \(message()) [\(file):\(line)]") }
}

/// The UserDefaults keys behind SharedGameOptions (Sound, No Stress, Honey, ...).
let sharedGameOptionKeys = [
    "global_sound_enabled", "global_no_stress_mode", "global_honey_mode",
    "global_manually_dismiss_banners", "global_hide_hint_button"
]

/// Runs `body` with the given UserDefaults keys (plus, optionally, the shared-option keys)
/// cleared to a fresh-install state, then puts every key — and the two process-wide
/// globals SharedGameOptions pokes (UISound.isEnabled, BannerCatalog.honeyModeEnabled) —
/// back exactly as they were.
///
/// `preserving` keys are backed up and restored too, but left untouched while the test runs.
func withCleanDefaults(_ keys: [String], preserving: [String] = [], includeSharedOptions: Bool = true, _ body: () -> Void) {
    UISound.isHeadlessMode = true
    let allKeys = keys + (includeSharedOptions ? sharedGameOptionKeys : [])
    let saved = (allKeys + preserving).map { ($0, UserDefaults.standard.object(forKey: $0)) }
    let savedSound = UISound.isEnabled
    let savedHoney = BannerCatalog.honeyModeEnabled
    let savedLanguage = BannerCatalog.currentLanguage
    for key in allKeys { UserDefaults.standard.removeObject(forKey: key) }
    defer {
        for (key, value) in saved {
            if let value { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UISound.isEnabled = savedSound
        BannerCatalog.honeyModeEnabled = savedHoney
        BannerCatalog.currentLanguage = savedLanguage
    }
    body()
}

/// Spins the main run loop until `done()` is true (or `timeout` passes). Used for the few
/// behaviours that are animated with DispatchQueue.asyncAfter (Spider Autocomplete).
func pumpRunLoop(timeout: TimeInterval = 3, until done: () -> Bool) {
    let end = Date().addingTimeInterval(timeout)
    while !done() && Date() < end {
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
    }
}

/// Card-building shorthand for fixed layouts.
enum CovCards {
    static func card(_ suit: Card.Suit, _ rank: Int, up: Bool = true) -> Card {
        Card(suit: suit, rank: rank, faceUp: up)
    }

    /// A foundation-style run of one suit: A, 2, 3 … `top`.
    static func ascending(_ suit: Card.Suit, through top: Int) -> [Card] {
        top < 1 ? [] : (1...top).map { Card(suit: suit, rank: $0, faceUp: true) }
    }

    /// A face-up run of one suit from `high` down to `low` (e.g. K→2).
    static func run(_ suit: Card.Suit, from high: Int, through low: Int) -> [Card] {
        stride(from: high, through: low, by: -1).map { Card(suit: suit, rank: $0, faceUp: true) }
    }
}
