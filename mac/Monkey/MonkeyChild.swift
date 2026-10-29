import Foundation

// A saved failing run: everything needed to replay it exactly, plus the plain-English
// steps the report shows.
struct MonkeyCase: Codable {
    var id: String
    var game: String
    var startMode: String
    var seed: String          // hex, so it survives any JSON tool
    var rule: MonkeyRule
    var detail: String
    var firstFound: String    // yyyy-MM-dd
    var setup: String
    var steps: [String]
    var actions: [MonkeyAction]

    var seedValue: UInt64 { UInt64(seed, radix: 16) ?? 0 }
}

// What a child run writes back for the night runner to read.
struct ChildResult: Codable {
    var setup: String
    var broke: Bool = false
    var rule: MonkeyRule?
    var detail: String?
    var step: Int?            // 0-based step that broke the rule
    var steps: [String]?      // plain descriptions, when asked for
    var wins = 0
}

// One game played (or replayed) in its own process, so a crash or freeze only ends that
// game. Each step is appended to `log` before it runs, so a crash still leaves the exact
// steps behind.
enum MonkeyChild {
    static func run(gameName: String, startMode: String, seed: UInt64, actions given: [MonkeyAction]?,
                    stepCount: Int, log: URL, result: URL, describe: Bool) -> Int32 {
        MonkeySandbox.prepare()
        guard let gameType = MonkeyGames.named(gameName) else {
            FileHandle.standardError.write(Data("Unknown game \(gameName)\n".utf8))
            return 64
        }
        DealShuffle.seeded = SplitMix64(seed: seed)
        var rng = SplitMix64(seed: seed ^ 0xA5A5_5A5A_C3C3_3C3C)
        let game = gameType.init(startMode: startMode)

        FileManager.default.createFile(atPath: log.path, contents: nil)
        let logHandle = try? FileHandle(forWritingTo: log)
        defer { try? logHandle?.close() }
        let encoder = JSONEncoder()

        var report = ChildResult(setup: game.setupDescription, steps: describe ? [] : nil)
        let total = given?.count ?? stepCount
        for step in 0..<total {
            let action = given?[step] ?? game.randomAction(&rng)
            if let line = try? encoder.encode(action) {
                logHandle?.write(line + Data("\n".utf8))
            }
            if describe {
                report.steps?.append(game.describe(action))
                report.wins = game.wins
                save(report, to: result)
            }
            let started = Date()
            do {
                try game.perform(action)
                let took = Date().timeIntervalSince(started)
                let limit: TimeInterval = action.kind == .autocomplete ? 20 : 3
                if took > limit {
                    throw RuleBroken(rule: .slowStep, detail: "This step took \(String(format: "%.1f", took)) seconds.")
                }
            } catch let broken as RuleBroken {
                report.broke = true
                report.rule = broken.rule
                report.detail = broken.detail
                report.step = step
                report.wins = game.wins
                save(report, to: result)
                return 3
            } catch {
                report.broke = true
                report.rule = .crash
                report.detail = "\(error)"
                report.step = step
                report.wins = game.wins
                save(report, to: result)
                return 3
            }
        }
        report.wins = game.wins
        save(report, to: result)
        return 0
    }

    private static func save(_ report: ChildResult, to url: URL) {
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
