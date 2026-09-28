import Foundation

// Cross-platform parity for Video Poker hand scoring (hand name + payout) across all
// three variants and both edge bets (1 coin, and 5 coins where the Royal Flush
// jackpot changes). Mac is the source of truth: this suite GENERATES
// shared/VideoPoker/TestVectors/videopoker_hand_vectors.json from
// VideoPokerViewModel.scoreHand and VERIFIES it every run; Android
// (VideoPokerVectorTests.kt) and Windows (VideoPokerVectorTests.cs) replay it against
// their own evaluators. Regenerate after an intentional pay-table/evaluator change:
//   cd mac && HONEYCOMB_REGEN_VECTORS=1 make test
struct VideoPokerVectorTests {
    static let seed: UInt64 = 0x56_50_6F_6B_72 // "VPokr"
    static let randomHandCount = 3000

    static var vectorsURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/VideoPoker/TestVectors/videopoker_hand_vectors.json")
    }

    static let variants: [(key: String, variant: VideoPokerVariant)] = [
        ("jacksOrBetter", .jacksOrBetter), ("deucesWild", .deucesWild), ("bonusPoker", .bonusPoker)
    ]
    static let suitKeys: [(key: String, suit: Card.Suit)] = [("S", .spades), ("H", .hearts), ("D", .diamonds), ("C", .clubs)]

    static func run() {
        if ProcessInfo.processInfo.environment["HONEYCOMB_REGEN_VECTORS"] == "1" {
            let hands = generateHands()
            let cases = hands.map { hand -> [String: Any] in
                ["hand": hand, "expect": expectation(for: hand)]
            }
            let root: [String: Any] = [
                "version": 1,
                "note": "Generated from the Mac (Swift) VideoPokerViewModel.scoreHand by mac/SoliBeeTests/VideoPokerVectorTests.swift. Cards are \"<rank><suit>\" with rank 1-13 (1 = Ace). expect[variant] = [name@bet1, payout@bet1, name@bet5, payout@bet5]. Do not hand-edit; regenerate with `cd mac && HONEYCOMB_REGEN_VECTORS=1 make test`.",
                "cases": cases
            ]
            try! FileManager.default.createDirectory(at: vectorsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try! JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]).write(to: vectorsURL)
            print("   ↳ regenerated \(cases.count) video poker vectors → \(vectorsURL.path)")
        }
        guard let data = try? Data(contentsOf: vectorsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cases = root["cases"] as? [[String: Any]] else {
            fatalError("❌ VideoPokerVectorTests: couldn't read \(vectorsURL.path) — run with HONEYCOMB_REGEN_VECTORS=1")
        }
        for c in cases {
            let hand = c["hand"] as! [String]
            let actual = expectation(for: hand)
            guard NSDictionary(dictionary: actual).isEqual(to: c["expect"] as! [String: Any]) else {
                fatalError("❌ VideoPokerVectorTests: \(hand) diverged. expected \(c["expect"]!) actual \(actual)")
            }
        }
    }

    private static func cards(_ codes: [String]) -> [Card] {
        codes.map { code in
            let rank = Int(code.dropLast())!
            let suit = suitKeys.first { $0.key == String(code.last!) }!.suit
            return Card(suit: suit, rank: rank, faceUp: true)
        }
    }

    private static func expectation(for hand: [String]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, variant) in variants {
            let one = VideoPokerViewModel.scoreHand(cards(hand), variant: variant, bet: 1)
            let five = VideoPokerViewModel.scoreHand(cards(hand), variant: variant, bet: 5)
            out[key] = [one.name, one.payout, five.name, five.payout]
        }
        return out
    }

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
    }

    private static func code(_ rank: Int, _ suit: Int) -> String { "\(rank)\(suitKeys[suit].key)" }

    // Hand-picked edge cases first (every one a known place evaluators disagree), then a
    // few thousand random hands skewed toward pairs/trips/deuces/suited cards so the
    // paying hands — not just "No Win" — dominate.
    private static func generateHands() -> [[String]] {
        var hands: [[String]] = [
            ["1S", "13S", "12S", "11S", "10S"],   // natural royal
            ["2S", "13S", "12S", "11S", "10S"],   // wild royal (deuce)
            ["1H", "2H", "3H", "4H", "5H"],       // wheel straight flush (ace low) / deuce
            ["1D", "2C", "3H", "4S", "5D"],       // wheel straight
            ["10C", "11D", "12H", "13S", "1C"],   // broadway straight
            ["13C", "1D", "2H", "3S", "4C"],      // not a straight (no wraparound)
            ["2S", "2H", "2D", "2C", "9H"],       // four deuces
            ["2S", "2H", "2D", "9C", "9H"],       // three deuces + pair → five of a kind
            ["2S", "2H", "7D", "7C", "7H"],       // two deuces + trips → five of a kind
            ["1S", "1H", "1D", "1C", "9H"],       // four aces (bonus)
            ["3S", "3H", "3D", "3C", "9H"],       // four threes (bonus 2-4)
            ["5S", "5H", "5D", "5C", "9H"],       // plain quads
            ["11S", "11H", "4D", "7C", "9H"],     // jacks
            ["10S", "10H", "4D", "7C", "9H"],     // tens (no pay in JoB)
            ["1S", "1H", "4D", "7C", "9H"],       // aces pair
            ["2S", "5H", "8D", "11C", "13H"],     // one deuce, nothing
        ]
        var rng = RNG(state: seed)
        while hands.count < randomHandCount {
            var picked = Set<String>()
            let style = rng.int(5)
            while picked.count < 5 {
                var rank = 1 + rng.int(13)
                var suit = rng.int(4)
                switch style {
                case 0: if rng.int(3) == 0 { rank = 2 }                       // deuce-heavy
                case 1: suit = rng.int(4) < 3 ? 0 : suit                      // flush-leaning
                case 2: rank = [1, 11, 12, 13, 10][rng.int(5)]                // high cards / royal-ish
                case 3: rank = 1 + rng.int(4)                                 // low: wheels, bonus 2-4 quads
                default: break
                }
                picked.insert(code(rank, suit))
            }
            hands.append(picked.sorted())
        }
        return hands
    }
}
