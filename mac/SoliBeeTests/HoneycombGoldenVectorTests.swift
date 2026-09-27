import Foundation

// Cross-platform parity for HoneycombBoard's capture engine (Same, Plus, Fallen Ace,
// Reverse, Ascension/Descension, combo cascades, Capped Brood reveals). Mac is the
// source of truth: this suite GENERATES shared/Honeycomb/TestVectors/
// honeycomb_capture_vectors.json from the Swift engine (deterministic seed), and every
// run VERIFIES the checked-in file still matches it. Android (HoneycombGoldenVectorTests.kt)
// and Windows (HoneycombGoldenVectorTests.cs) replay the same file against their own
// engines, so any port that drifts from Mac fails its own test suite.
//
// Regenerate after an intentional rules change:
//   cd mac && HONEYCOMB_REGEN_VECTORS=1 make test
// then commit the updated JSON — Android/Windows will fail until their engines match.
struct HoneycombGoldenVectorTests {
    static let caseCount = 800
    static let seed: UInt64 = 0x48_6F_6E_65_79 // "Honey"

    static var vectorsURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // SoliBeeTests
            .deletingLastPathComponent()      // mac
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent("shared/Honeycomb/TestVectors/honeycomb_capture_vectors.json")
    }

    static func run() {
        if ProcessInfo.processInfo.environment["HONEYCOMB_REGEN_VECTORS"] == "1" {
            let cases = generateCases()
            let root: [String: Any] = [
                "version": 1,
                "seed": String(seed),
                "note": "Generated from the Mac (Swift) HoneycombBoard engine by mac/SoliBeeTests/HoneycombGoldenVectorTests.swift. Do not hand-edit; regenerate with `cd mac && HONEYCOMB_REGEN_VECTORS=1 make test`.",
                "cases": cases
            ]
            let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try! FileManager.default.createDirectory(at: vectorsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try! data.write(to: vectorsURL)
            print("   ↳ regenerated \(cases.count) vectors → \(vectorsURL.path)")
        }
        verifyFile()
    }

    // MARK: - Verify

    private static func verifyFile() {
        guard let data = try? Data(contentsOf: vectorsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cases = root["cases"] as? [[String: Any]] else {
            fatalError("❌ HoneycombGoldenVectorTests: couldn't read \(vectorsURL.path) — run with HONEYCOMB_REGEN_VECTORS=1")
        }
        for c in cases {
            let actual = replay(c)
            let expected = c["expect"] as! [String: Any]
            guard NSDictionary(dictionary: actual).isEqual(to: expected) else {
                fatalError("❌ HoneycombGoldenVectorTests: case \(c["name"] ?? "?") diverged from the checked-in vector.\n  expected: \(expected)\n  actual:   \(actual)\nIf the rules change was intentional, regenerate with HONEYCOMB_REGEN_VECTORS=1.")
            }
        }
    }

    // Applies one vector's board + op to the Swift engine and returns its "expect" dict.
    private static func replay(_ c: [String: Any]) -> [String: Any] {
        let rules = (c["rules"] as! [String]).map(rule(from:))
        var board = HoneycombBoard()
        board.ascensionDescensionSuits = Set(c["ascensionSuits"] as! [String])
        let cells = c["board"] as! [Any]
        for (i, raw) in cells.enumerated() {
            if let d = raw as? [String: Any] { board.cells[i].card = card(from: d) }
        }
        let op = c["op"] as! [String: Any]
        let index = op["index"] as! Int
        let flips: [Int]
        if op["kind"] as! String == "reveal" {
            flips = board.revealFaceDownCard(at: index, rules: rules)
        } else {
            flips = board.placeCard(card(from: op["card"] as! [String: Any]), at: index, rules: rules)
        }
        return expectation(board: board, flips: flips)
    }

    private static func expectation(board: HoneycombBoard, flips: [Int]) -> [String: Any] {
        [
            "owners": board.cells.map { cell -> Any in cell.card.map { $0.owner == .player ? "player" : "opponent" } ?? NSNull() },
            "modifiers": board.cells.map { cell -> Any in cell.card.map { $0.modifier } ?? NSNull() },
            "faceDown": board.cells.map { cell -> Any in cell.card.map { $0.isFaceDown } ?? NSNull() },
            // Flip ORDER isn't part of the contract (Swift iterates a Set/Dictionary for
            // Same/Plus triggers, so even Mac's own order varies run to run) — only which
            // cells flipped, and how many times.
            "flips": flips.sorted(),
            "sameTriggered": board.lastSameTriggered,
            "plusTriggered": board.lastPlusTriggered,
            "fallenAceTriggered": board.lastFallenAceTriggered,
            "comboFlipCount": board.lastComboFlipCount,
            "samePlusTriggers": board.sessionSamePlusTriggers,
            "fallenAceCaptures": board.sessionFallenAceCaptures
        ]
    }

    private static func rule(from s: String) -> HoneycombRule {
        switch s {
        case "ascension": return .ascension
        case "descension": return .descension
        case "same": return .same
        case "plus": return .plus
        case "fallenAce": return .fallenAce
        case "reverse": return .reverse
        default: fatalError("unknown rule \(s)")
        }
    }

    private static func card(from d: [String: Any]) -> HoneycombCard {
        let owner: CardOwner = (d["owner"] as! String) == "player" ? .player : .opponent
        var c = HoneycombCard(
            data: HoneycombCardData(id: d["id"] as! Int, name: "V\(d["id"] as! Int)", stars: 3, stats: d["stats"] as! [Int], suit: d["suit"] as! String),
            owner: owner
        )
        c.isFaceDown = d["faceDown"] as! Bool
        return c
    }

    // MARK: - Generate

    // SplitMix64 — tiny, deterministic across runs/platforms, so regenerating from the
    // same seed reproduces the same file byte for byte.
    private struct RNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func int(_ n: Int) -> Int { Int(next() % UInt64(n)) }
        mutating func chance(_ p: Double) -> Bool { Double(next() % 10_000) / 10_000 < p }
    }

    private static let suits = ["S", "H", "D", "C"]

    private static func generateCases() -> [[String: Any]] {
        var rng = RNG(state: seed)
        var cases: [[String: Any]] = []
        var nextCardId = 1

        // Stats are drawn from a small pool most of the time so Same/Plus matches,
        // 1-vs-10 Fallen Ace edges and ties actually occur often, not just by luck.
        func stat() -> Int {
            if rng.chance(0.75) { return [1, 10, 5, 5, 3][rng.int(5)] }
            return 1 + rng.int(10)
        }
        func mkCard(faceDown: Bool) -> [String: Any] {
            defer { nextCardId += 1 }
            return [
                "id": nextCardId,
                "stats": [stat(), stat(), stat(), stat()],
                "suit": suits[rng.int(4)],
                "owner": rng.chance(0.5) ? "player" : "opponent",
                "faceDown": faceDown
            ]
        }

        for i in 0..<caseCount {
            var rules: [String] = []
            switch rng.int(4) {
            case 0: rules.append("ascension")
            case 1: rules.append("descension")
            default: break
            }
            for (r, p) in [("same", 0.6), ("plus", 0.6), ("fallenAce", 0.5), ("reverse", 0.25)] where rng.chance(p) { rules.append(r) }

            var ascSuits: [String] = []
            if rng.chance(0.8) {
                let a = suits[rng.int(4)], b = suits[rng.int(4)]
                ascSuits = Array(Set([a, b])).sorted()
            }

            let isReveal = rng.chance(0.15)
            // The center (4 neighbors) is where Same/Plus/combos actually happen.
            let target = rng.chance(0.4) ? 4 : rng.int(9)
            var board: [Any] = Array(repeating: NSNull(), count: 9)
            let others = (0..<9).filter { $0 != target }
            for idx in others where rng.chance(0.75) {
                board[idx] = mkCard(faceDown: rng.chance(0.08))
            }
            var op: [String: Any] = ["index": target]
            if isReveal {
                board[target] = mkCard(faceDown: true)
                op["kind"] = "reveal"
            } else {
                op["kind"] = "place"
                op["card"] = mkCard(faceDown: rng.chance(0.05))
            }

            var c: [String: Any] = [
                "name": String(format: "case_%03d", i),
                "rules": rules,
                "ascensionSuits": ascSuits,
                "board": board,
                "op": op
            ]
            c["expect"] = replay(c)
            cases.append(c)
        }

        // Guard against a generator change silently producing vectors that never exercise
        // the interesting rules — the file is only as good as its coverage.
        func count(_ key: String, _ pred: (Any) -> Bool) -> Int {
            cases.filter { pred(($0["expect"] as! [String: Any])[key]!) }.count
        }
        let same = count("sameTriggered") { $0 as! Bool }
        let plus = count("plusTriggered") { $0 as! Bool }
        let ace = count("fallenAceTriggered") { $0 as! Bool }
        let combo = count("comboFlipCount") { ($0 as! Int) > 0 }
        guard same >= 15, plus >= 15, ace >= 10, combo >= 10 else {
            fatalError("❌ HoneycombGoldenVectorTests: weak coverage (same \(same), plus \(plus), fallenAce \(ace), combo \(combo)) — tune the generator")
        }
        print("   ↳ coverage: same \(same), plus \(plus), fallenAce \(ace), combo \(combo)")
        return cases
    }
}
