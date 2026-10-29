import Foundation

// Writes monkey/REPORT.md from the open cases. The first line is a one-glance status.
// Nothing in it depends on the night it was written, so the file only changes when a
// problem is found or fixed.
enum MonkeyReport {
    static let rules = [
        "Every card is still on the board exactly once.",
        "The board keeps a legal shape (foundations build up in suit, face-down cards stay underneath, Klondike runs alternate colors, a finished Spider run gets cleared).",
        "The game says \"won\" exactly when every card is home.",
        "Undo gives back exactly the board from before the move (in Klondike standard scoring, minus the undone move's points, as designed).",
        "Restart gives back the original deal.",
        "Asking for a hint never changes the board.",
        "Autocomplete, whenever it's offered, finishes the game.",
        "Stats add up: a new game on a played, unwon deal ends the streak (in Honeycomb, leaving a match counts as a loss); a win adds exactly one win; won never exceeds played.",
        "After quitting and reopening, settings and stats come back the same.",
        "Honeycomb: the board and hands always hold the same 10 cards, five from each side.",
        "Honeycomb: a move the rules allow is accepted, one they don't is refused and changes nothing, and Hint only suggests allowed moves.",
        "Honeycomb: the opponent always takes its turn, and a full board always ends the match (or starts Sudden Death) with the right result.",
        "Honeycomb: the Card Bank only gains a card through a real steal (one per match, never in No Stress Mode).",
        "Honeycomb: a new match follows the chosen rules, bans, difficulty and deck, brings a card you don't own yet when it can, and settings changed mid-match wait for the next one.",
        "No step crashes, freezes, or takes far too long.",
    ]

    static func write(cases: [MonkeyCase], to url: URL) {
        let sorted = cases.sorted { ($0.firstFound, $0.id) < ($1.firstFound, $1.id) }
        var text = "# Monkey test report\n\n"
        if sorted.isEmpty {
            text += "✅ **All clear.** No open problems.\n\n"
        } else {
            let newest = sorted.map(\.firstFound).max().map(prettyDate) ?? ""
            text += "❌ **\(sorted.count) open problem\(sorted.count == 1 ? "" : "s")** (newest found \(newest)).\n\n"
        }
        text += """
        Every night a GitHub job plays Klondike, Beecell, Spider and Honeycomb with thousands of random but legal \
        moves and checks the rules at the bottom of this page after every step. A problem stays listed \
        until a later night's re-check shows it's fixed, so this file only changes when something new \
        turns up or something gets fixed. Each night's run is under GitHub → Actions → \
        "Monkey test (nightly)".


        """

        for (number, found) in sorted.enumerated() {
            text += "## Problem \(number + 1): \(found.game): \(found.rule.plain)\n\n"
            text += "- **Found:** \(prettyDate(found.firstFound))\n"
            text += "- **Start:** \(found.setup). The deal comes from a seed, so it can't be set up by hand, but it replays exactly.\n"
            text += "- **What went wrong:** \(found.detail)\n\n"
            text += "**Steps**\n\n"
            for (step, line) in found.steps.enumerated() {
                text += "\(step + 1). \(line)\n"
            }
            text += "\nReplay it: `make -C mac monkey-replay CASE=monkey/cases/\(found.id).json`\n\n"
        }

        text += "## Rules checked after every step\n\n"
        text += rules.map { "- \($0)" }.joined(separator: "\n") + "\n"
        try? Data(text.utf8).write(to: url)
    }

    private static func prettyDate(_ isoDay: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDay) else { return isoDay }
        let printer = DateFormatter()
        printer.locale = Locale(identifier: "en_US_POSIX")
        printer.dateFormat = "MMM d, yyyy"
        return printer.string(from: date)
    }
}
