import Foundation

// The overnight run: re-check every saved problem, play new random games until time runs
// out, shrink anything new to its fewest steps, then rewrite the report. Only the saved
// cases feed the report, so it stays byte-identical on nights where nothing changed.
struct MonkeyNight {
    static let stepsPerGame = 1500
    static let newProblemsPerNight = 3

    let outDir: URL
    let minutes: Double
    var rng: SplitMix64
    let work = FileManager.default.temporaryDirectory.appendingPathComponent("honeycomb-monkey-night-\(getpid())")

    var casesDir: URL { outDir.appendingPathComponent("cases") }

    mutating func run() -> Int32 {
        try? FileManager.default.createDirectory(at: casesDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        // 1. Saved problems: keep the ones that still happen, drop the ones that are fixed.
        var open: [MonkeyCase] = []
        for (url, saved) in loadCases() {
            let rerun = replay(game: saved.game, startMode: saved.startMode, seed: saved.seedValue, actions: saved.actions,
                               timeout: saved.rule == .freeze ? 30 : 20)
            if rerun.rule == saved.rule {
                open.append(saved)
                print("Still open: \(saved.id)")
            } else {
                try? FileManager.default.removeItem(at: url)
                print("Fixed: \(saved.id)")
            }
        }

        // 2. New random games until time is up, rotating through the games.
        var known = Set(open.map { "\($0.game)|\($0.rule.rawValue)" })
        var newFound = 0, gamesPlayed = 0, failures = 0, wins = 0
        let deadline = Date().addingTimeInterval(minutes * 60)
        while Date() < deadline {
            let gameType = MonkeyGames.all[gamesPlayed % MonkeyGames.all.count]
            let startMode = gameType.randomStartMode(&rng)
            let seed = rng.next()
            gamesPlayed += 1
            let result = runChild(["child", "--game", gameType.gameName, "--mode", startMode,
                                   "--seed", String(seed, radix: 16), "--steps", String(Self.stepsPerGame)], timeout: 120)
            wins += result.wins
            guard let rule = result.rule else { continue }
            failures += 1
            let key = "\(gameType.gameName)|\(rule.rawValue)"
            print("Found \(key) (seed \(String(seed, radix: 16))): \(result.detail)")
            guard !known.contains(key), newFound < Self.newProblemsPerNight else { continue }
            known.insert(key)
            newFound += 1
            open.append(saveNewCase(game: gameType.gameName, startMode: startMode, seed: seed, rule: rule, found: result))
        }

        MonkeyReport.write(cases: open, to: outDir.appendingPathComponent("REPORT.md"))
        print("Played \(gamesPlayed) runs of up to \(Self.stepsPerGame) steps (\(wins) games won); \(failures) hit a problem; \(newFound) new; \(open.count) open in all.")
        return 0
    }

    // MARK: - Cases

    private func loadCases() -> [(URL, MonkeyCase)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: casesDir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.path < $1.path }.compactMap { url in
            guard let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(MonkeyCase.self, from: data) else { return nil }
            return (url, saved)
        }
    }

    private func saveNewCase(game: String, startMode: String, seed: UInt64, rule: MonkeyRule, found: ChildRun) -> MonkeyCase {
        var actions = found.actions
        var detail = found.detail
        let timeout: TimeInterval = rule == .freeze ? 30 : 20
        let replays = replay(game: game, startMode: startMode, seed: seed, actions: actions, timeout: timeout).rule == rule
        if replays {
            actions = shrink(game: game, startMode: startMode, seed: seed, rule: rule, actions: actions)
        }
        let final = replay(game: game, startMode: startMode, seed: seed, actions: actions, timeout: timeout, describe: true)
        if final.rule == rule { detail = final.detail }
        if !replays { detail += " (It didn't happen again on replay, so it may depend on timing.)" }

        let seedHex = String(seed, radix: 16)
        let saved = MonkeyCase(
            id: "\(game.lowercased())-\(rule.rawValue)-\(seedHex.prefix(8))",
            game: game, startMode: startMode, seed: seedHex, rule: rule, detail: detail,
            firstFound: Self.today(), setup: final.setup ?? game, steps: final.steps ?? [], actions: actions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(saved) {
            try? data.write(to: casesDir.appendingPathComponent("\(saved.id).json"))
        }
        print("Saved \(saved.id): \(actions.count) steps.")
        return saved
    }

    // Takes steps away (big chunks first, then single steps) for as long as the same rule
    // still breaks, keeping the shortest list that shows it.
    private func shrink(game: String, startMode: String, seed: UInt64, rule: MonkeyRule, actions: [MonkeyAction]) -> [MonkeyAction] {
        let maxTries = rule == .freeze ? 12 : rule == .crash ? 150 : 400
        let timeout: TimeInterval = rule == .freeze ? 30 : 20
        let deadline = Date().addingTimeInterval(5 * 60)
        var best = actions, tries = 0
        var chunk = max(1, best.count / 2)
        while true {
            var start = 0, removedAny = false
            while start < best.count {
                guard tries < maxTries, Date() < deadline else { return best }
                tries += 1
                var candidate = best
                candidate.removeSubrange(start..<min(start + chunk, best.count))
                let result = replay(game: game, startMode: startMode, seed: seed, actions: candidate, timeout: timeout)
                if result.rule == rule {
                    best = result.actions
                    removedAny = true
                } else {
                    start += chunk
                }
            }
            if !removedAny {
                if chunk == 1 { return best }
                chunk /= 2
            }
            chunk = max(1, min(chunk, best.count / 2))
        }
    }

    // MARK: - Child processes

    private func replay(game: String, startMode: String, seed: UInt64, actions: [MonkeyAction],
                        timeout: TimeInterval, describe: Bool = false) -> ChildRun {
        let caseURL = work.appendingPathComponent("replay.json")
        let replayCase = MonkeyCase(id: "replay", game: game, startMode: startMode, seed: String(seed, radix: 16),
                                    rule: .crash, detail: "", firstFound: "", setup: "", steps: [], actions: actions)
        try? JSONEncoder().encode(replayCase).write(to: caseURL)
        return runChild(["child", "--case", caseURL.path] + (describe ? ["--describe"] : []), timeout: timeout)
    }

    private func runChild(_ arguments: [String], timeout: TimeInterval) -> ChildRun {
        MonkeyProcess.run(arguments, in: work, timeout: timeout)
    }

    static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// How one child run ended. `rule` is nil when every step passed; `actions` runs up to and
// including the step that broke.
struct ChildRun {
    var rule: MonkeyRule?
    var detail = ""
    var actions: [MonkeyAction] = []
    var setup: String?
    var steps: [String]?
    var wins = 0
}

enum MonkeyProcess {
    static func run(_ arguments: [String], in work: URL, timeout: TimeInterval) -> ChildRun {
        let log = work.appendingPathComponent("actions.jsonl")
        let result = work.appendingPathComponent("result.json")
        let errors = work.appendingPathComponent("stderr.txt")
        for url in [log, result, errors] { try? FileManager.default.removeItem(at: url) }
        FileManager.default.createFile(atPath: errors.path, contents: nil)

        let process = Process()
        process.executableURL = Bundle.main.executableURL
        process.arguments = arguments + ["--log", log.path, "--result", result.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = try? FileHandle(forWritingTo: errors)
        do { try process.run() } catch {
            return ChildRun(rule: .crash, detail: "The monkey couldn't start a game: \(error).")
        }

        let deadline = Date().addingTimeInterval(timeout)
        var timedOut = false
        while process.isRunning {
            if Date() > deadline {
                timedOut = true
                kill(process.processIdentifier, SIGKILL)
                break
            }
            usleep(10_000)
        }
        process.waitUntilExit()

        let report = (try? Data(contentsOf: result)).flatMap { try? JSONDecoder().decode(ChildResult.self, from: $0) }
        var run = ChildRun(setup: report?.setup, steps: report?.steps, wins: report?.wins ?? 0)
        if timedOut {
            run.rule = .freeze
            run.detail = "The game stopped responding (still busy after \(Int(timeout)) seconds)."
        } else if process.terminationReason == .uncaughtSignal {
            run.rule = .crash
            // Signal 5 is Swift stopping the app at one of its safety checks (an
            // optimized build doesn't print which one).
            run.detail = crashMessage(errors) ?? (process.terminationStatus == SIGTRAP
                ? "The game crashed at one of Swift's safety checks (for example, reading past the end of a list)."
                : "The game crashed (signal \(process.terminationStatus)).")
        } else if process.terminationStatus == 3, let report, report.broke, let rule = report.rule {
            run.rule = rule
            run.detail = report.detail ?? ""
        } else if process.terminationStatus != 0 {
            run.rule = .crash
            run.detail = crashMessage(errors) ?? "The game exited with code \(process.terminationStatus)."
        }
        guard run.rule != nil else { return run }

        // The log holds every step started; a rule break also says which step it was.
        let decoder = JSONDecoder()
        let logged = ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").compactMap {
            try? decoder.decode(MonkeyAction.self, from: Data($0.utf8))
        }
        if let step = report?.step, report?.broke == true, run.rule == report?.rule {
            run.actions = Array(logged.prefix(step + 1))
        } else {
            run.actions = logged
        }
        return run
    }

    // Swift's own crash line, e.g. "Fatal error: Index out of range".
    private static func crashMessage(_ errors: URL) -> String? {
        let text = (try? String(contentsOf: errors, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").first { line in
            ["Fatal error", "fatal error", "Precondition failed", "Assertion failed"].contains { line.contains($0) }
        }.map { String($0.trimmingCharacters(in: .whitespaces)) }
    }
}
