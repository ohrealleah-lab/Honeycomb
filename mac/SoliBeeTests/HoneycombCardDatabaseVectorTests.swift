import Foundation

// Cross-platform parity for the Honeycomb card database. Mac GENERATES
// shared/Honeycomb/TestVectors/honeycomb_card_database_vectors.json from
// HoneycombCardGenerator and VERIFIES its own output is unchanged (so a Mac generator
// change is caught — it would re-roll every Mac player's collection). Android/Windows
// check the same ids/names/stars/suits in the same order and that every card obeys the
// tier rules Mac's cards show (edge range, budget, no duplicate stat line per suit).
// They deliberately don't compare exact stat values: each platform's seeded RNG helpers
// consume the stream differently, seeds are per-install and never shared, and forcing
// identical output would re-roll existing Android/Windows collections.
//   cd mac && HONEYCOMB_REGEN_VECTORS=1 make test
struct HoneycombCardDatabaseVectorTests {
    // Kept below 2^63 so Android's signed Long seed covers the same values.
    static let seeds: [UInt64] = [0, 1, 42, 12345, 987_654_321, 0x0123_4567_89AB_CDEF, 0x7FFF_FFFF_FFFF_FFFF]

    static var vectorsURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/Honeycomb/TestVectors/honeycomb_card_database_vectors.json")
    }

    private static func dump(_ seed: UInt64) -> [[Any]] {
        HoneycombCardGenerator.generateAllCards(seed: seed).map { [$0.id, $0.name, $0.stars, $0.stats, $0.suit] }
    }

    static func run() {
        if ProcessInfo.processInfo.environment["HONEYCOMB_REGEN_VECTORS"] == "1" {
            let root: [String: Any] = [
                "version": 1,
                "note": "Generated from the Mac (Swift) HoneycombCardGenerator by mac/SoliBeeTests/HoneycombCardDatabaseVectorTests.swift. Each card is [id, name, stars, stats(top,right,bottom,left), suit]. Do not hand-edit.",
                "databases": seeds.map { ["seed": String($0), "cards": dump($0)] as [String: Any] }
            ]
            try! JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]).write(to: vectorsURL)
            print("   ↳ regenerated card database vectors → \(vectorsURL.path)")
        }
        guard let data = try? Data(contentsOf: vectorsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dbs = root["databases"] as? [[String: Any]] else {
            fatalError("❌ HoneycombCardDatabaseVectorTests: couldn't read \(vectorsURL.path)")
        }
        for db in dbs {
            let seed = UInt64(db["seed"] as! String)!
            guard NSArray(array: dump(seed)).isEqual(to: db["cards"] as! [Any]) else {
                fatalError("❌ HoneycombCardDatabaseVectorTests: seed \(seed) produced a different card database")
            }
        }
    }
}
