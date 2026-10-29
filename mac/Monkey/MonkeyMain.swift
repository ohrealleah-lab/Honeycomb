import Foundation

// monkey_runner night  --minutes 30 --out ../monkey [--seed <hex>]
//     The overnight run (`make monkey`).
// monkey_runner replay --case ../monkey/cases/<id>.json
//     Replays one saved problem and prints its steps (`make monkey-replay`).
// monkey_runner child  ...
//     One game in its own process; only the two commands above start these.
@main
struct MonkeyRunner {
    static func main() {
        setbuf(stdout, nil)
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? ""
        var options: [String: String] = [:]
        var flags: Set<String> = []
        var i = 1
        while i < args.count {
            let key = args[i]
            if i + 1 < args.count, !args[i + 1].hasPrefix("--") {
                options[key] = args[i + 1]
                i += 2
            } else {
                flags.insert(key)
                i += 1
            }
        }

        switch command {
        case "night":
            let seed = options["--seed"].flatMap { UInt64($0, radix: 16) } ?? UInt64(Date().timeIntervalSince1970 * 1000)
            print("Monkey night run, seed \(String(seed, radix: 16)).")
            var night = MonkeyNight(outDir: URL(fileURLWithPath: options["--out"] ?? "../monkey"),
                                    minutes: Double(options["--minutes"] ?? "30") ?? 30,
                                    rng: SplitMix64(seed: seed))
            exit(night.run())

        case "replay":
            guard let path = options["--case"], let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let saved = try? JSONDecoder().decode(MonkeyCase.self, from: data) else {
                print("Usage: monkey_runner replay --case <case.json>")
                exit(64)
            }
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("honeycomb-monkey-replay-\(getpid())")
            try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: work) }
            let result = MonkeyProcess.run(["child", "--case", path, "--describe"], in: work, timeout: 60)
            print("\(result.setup ?? saved.game)\n")
            for (step, line) in (result.steps ?? []).enumerated() { print("\(step + 1). \(line)") }
            if let rule = result.rule {
                print("\nStill happens: \(rule.plain). \(result.detail)")
            } else {
                print("\nPassed: this problem no longer happens.")
            }

        case "child":
            let log = URL(fileURLWithPath: options["--log"] ?? "/dev/null")
            let result = URL(fileURLWithPath: options["--result"] ?? "/dev/null")
            if let path = options["--case"] {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                      let saved = try? JSONDecoder().decode(MonkeyCase.self, from: data) else { exit(64) }
                exit(MonkeyChild.run(gameName: saved.game, startMode: saved.startMode, seed: saved.seedValue,
                                     actions: saved.actions, stepCount: saved.actions.count,
                                     log: log, result: result, describe: flags.contains("--describe")))
            }
            exit(MonkeyChild.run(gameName: options["--game"] ?? "", startMode: options["--mode"] ?? "",
                                 seed: options["--seed"].flatMap { UInt64($0, radix: 16) } ?? 0, actions: nil,
                                 stepCount: Int(options["--steps"] ?? "") ?? MonkeyNight.stepsPerGame,
                                 log: log, result: result, describe: flags.contains("--describe")))

        default:
            print("Usage: monkey_runner night|replay|child …")
            exit(64)
        }
    }
}
