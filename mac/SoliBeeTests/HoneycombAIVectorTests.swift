import Foundation

// Cross-platform parity for the Honeycomb AI and Hint searches. Mac is the source of
// truth: this suite GENERATES shared/Honeycomb/TestVectors/honeycomb_ai_vectors.json from
// the Swift HoneycombAI (deterministic seed) and every run VERIFIES the checked-in file
// still matches. Android (HoneycombAIVectorTests.kt) and Windows (HoneycombAIVectorTests.cs)
// replay the same positions against their own AI.
//
// What's compared (only the parts that are deterministic on every platform):
//   - Medium (greedy 1-ply): the best immediate capture count AND the full set of moves
//     achieving it — no pruning, so the tie set is exact.
//   - Hard (5 plies) / Ultra Hard (6 plies, Fallen Ace weighted) / Hint: the root minimax
//     score. Alpha-beta pruning changes how that value is found, never the value itself;
//     the set of tied moves is NOT compared, since pruning bounds depend on each port's
//     candidate ordering and can make equal-looking ties differ legitimately.
// The random tie-break (and Easy's coin flip) is deliberately outside the contract.
//
// Regenerate after an intentional AI/evaluation change:
//   cd mac && HONEYCOMB_REGEN_VECTORS=1 make test
struct HoneycombAIVectorTests {
    static let caseCount = 200
    static let seed: UInt64 = 0x41_49_42_65_65 // "AIBee"

    static var vectorsURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("shared/Honeycomb/TestVectors/honeycomb_ai_vectors.json")
    }

    static func run() {
        if ProcessInfo.processInfo.environment["HONEYCOMB_REGEN_VECTORS"] == "1" {
            let cases = generateCases()
            let root: [String: Any] = [
                "version": 1,
                "seed": String(seed),
                "note": "Generated from the Mac (Swift) HoneycombAI by mac/SoliBeeTests/HoneycombAIVectorTests.swift. Do not hand-edit; regenerate with `cd mac && HONEYCOMB_REGEN_VECTORS=1 make test`.",
                "cases": cases
            ]
            let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try! data.write(to: vectorsURL)
            print("   ↳ regenerated \(cases.count) AI vectors → \(vectorsURL.path)")
        }
        verifyFile()
    }

    private static func verifyFile() {
        guard let data = try? Data(contentsOf: vectorsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cases = root["cases"] as? [[String: Any]] else {
            fatalError("❌ HoneycombAIVectorTests: couldn't read \(vectorsURL.path) — run with HONEYCOMB_REGEN_VECTORS=1")
        }
        for c in cases {
            let actual = evaluate(c)
            let expected = c["expect"] as! [String: Any]
            guard NSDictionary(dictionary: actual).isEqual(to: expected) else {
                fatalError("❌ HoneycombAIVectorTests: case \(c["name"] ?? "?") diverged.\n  expected: \(expected)\n  actual:   \(actual)")
            }
        }
    }

    // MARK: - Evaluate one position

    private static func evaluate(_ c: [String: Any]) -> [String: Any] {
        let rules = (c["rules"] as! [String]).map(rule(from:))
        var board = HoneycombBoard()
        board.ascensionDescensionSuits = Set(c["ascensionSuits"] as! [String])
        for (i, raw) in (c["board"] as! [Any]).enumerated() {
            guard let d = raw as? [String: Any] else { continue }
            var card = HoneycombCard(data: cardData(d), owner: (d["owner"] as! String) == "player" ? .player : .opponent)
            card.isFaceDown = d["faceDown"] as! Bool
            board.cells[i].card = card
        }
        // Mirrors what the ViewModel does when it places cards: modifiers are live board
        // state, recomputed on every placement — replay them for the starting position.
        board = withModifiers(board, rules: rules)
        let aiHand = (c["aiHand"] as! [[String: Any]]).map(cardData)
        let playerHand = (c["playerHand"] as! [[String: Any]]).map(cardData)
        let empties = board.cells.indices.filter { board.cells[$0].card == nil }

        let greedy = HoneycombAI.greedySearch(board: board, opponentDeck: aiHand, eligibleHands: Array(aiHand.indices), empties: empties, rules: rules)
        let hard = HoneycombAI.minimaxSearch(board: board, opponentDeck: aiHand, playerDeck: playerHand, eligibleHands: Array(aiHand.indices), empties: empties, rules: rules, lookaheadPlies: 5, weighFallenAce: false)
        let ultra = HoneycombAI.minimaxSearch(board: board, opponentDeck: aiHand, playerDeck: playerHand, eligibleHands: Array(aiHand.indices), empties: empties, rules: rules, lookaheadPlies: 6, weighFallenAce: true)
        let hint = HoneycombAI.hintSearchScore(board: board, playerDeck: playerHand, opponentDeck: aiHand, eligibleHands: Array(playerHand.indices), empties: empties, rules: rules)

        return [
            "mediumScore": greedy.score,
            "mediumMoves": greedy.moves.map { [$0.handIndex, $0.boardIndex] }.sorted { ($0[0], $0[1]) < ($1[0], $1[1]) },
            "hardScore": hard.score,
            "ultraHardScore": ultra.score,
            "hintScore": hint
        ]
    }

    // Recomputes Ascension/Descension modifiers for a hand-built board the same way
    // HoneycombBoard.placeCard does, by re-placing its cards (captures skipped).
    private static func withModifiers(_ board: HoneycombBoard, rules: [HoneycombRule]) -> HoneycombBoard {
        var rebuilt = HoneycombBoard()
        rebuilt.ascensionDescensionSuits = board.ascensionDescensionSuits
        for i in board.cells.indices {
            if let card = board.cells[i].card { _ = rebuilt.placeCard(card, at: i, rules: rules, skipCaptures: true) }
        }
        return rebuilt
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

    private static func cardData(_ d: [String: Any]) -> HoneycombCardData {
        HoneycombCardData(id: d["id"] as! Int, name: "V\(d["id"] as! Int)", stars: 3, stats: d["stats"] as! [Int], suit: d["suit"] as! String)
    }

    // MARK: - Generate

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
        func stat() -> Int { rng.chance(0.5) ? [1, 10, 5, 5, 3][rng.int(5)] : 1 + rng.int(10) }
        func data() -> [String: Any] {
            defer { nextCardId += 1 }
            return ["id": nextCardId, "stats": [stat(), stat(), stat(), stat()], "suit": suits[rng.int(4)]]
        }

        for i in 0..<caseCount {
            var rules: [String] = []
            switch rng.int(4) {
            case 0: rules.append("ascension")
            case 1: rules.append("descension")
            default: break
            }
            for (r, p) in [("same", 0.5), ("plus", 0.5), ("fallenAce", 0.4), ("reverse", 0.2)] where rng.chance(p) { rules.append(r) }
            var ascSuits: [String] = []
            if rng.chance(0.8) { ascSuits = Array(Set([suits[rng.int(4)], suits[rng.int(4)]])).sorted() }

            // Late-game positions (2-5 open cells) keep Ultra Hard's full 6-ply search fast
            // enough to run hundreds of cases on every platform's test suite.
            let emptyCount = 2 + rng.int(4)
            var cells = Array(0..<9)
            for k in stride(from: 8, to: 0, by: -1) { cells.swapAt(k, rng.int(k + 1)) }
            let open = Set(cells.prefix(emptyCount))
            var board: [Any] = []
            for idx in 0..<9 {
                if open.contains(idx) {
                    board.append(NSNull())
                } else {
                    var d = data()
                    d["owner"] = rng.chance(0.5) ? "player" : "opponent"
                    d["faceDown"] = rng.chance(0.05)
                    board.append(d)
                }
            }
            let aiCount = 1 + rng.int(min(3, emptyCount))
            let playerCount = max(1, min(3, emptyCount - aiCount + rng.int(2)))
            let c0: [String: Any] = [
                "name": String(format: "ai_%03d", i),
                "rules": rules,
                "ascensionSuits": ascSuits,
                "board": board,
                "aiHand": (0..<aiCount).map { _ in data() },
                "playerHand": (0..<playerCount).map { _ in data() }
            ]
            var c = c0
            c["expect"] = evaluate(c0)
            cases.append(c)
        }
        return cases
    }
}
