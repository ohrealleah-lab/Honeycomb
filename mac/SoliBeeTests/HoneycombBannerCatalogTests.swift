import Foundation

// Regression coverage for BannerCatalog (shared/Honeycomb/Models/BannerCatalog.swift)
// and its generated companion BannerID.swift — both produced from
// Honeycomb_Fun_Messages.xlsx by tools/generate_banner_catalog.py. The main risk
// this guards against is drift: every BannerID case must have a matching catalog
// entry (and vice versa), which a hand-edit to either the enum or the JSON without
// re-running the generator would silently break.
struct HoneycombBannerCatalogTests {
    static func run() {
        testEveryBannerIDHasACatalogEntry()
        testEveryEntryHasAtLeastOneMessage()
        testGatedEntriesHaveChanceAndFallback()
        testUngatedEntriesHaveNoGateFields()
        testFireReturnsContentForEveryID()
        testTokenSubstitution()
    }

    static func testEveryBannerIDHasACatalogEntry() {
        for id in BannerID.allCases {
            guard BannerCatalog.shared.definition(for: id) != nil else {
                fatalError("❌ HoneycombBannerCatalogTests: BannerID.\(id.rawValue) has no matching catalog entry — was the JSON regenerated without regenerating the enum, or vice versa?")
            }
        }
    }

    static func testEveryEntryHasAtLeastOneMessage() {
        for id in BannerID.allCases {
            guard let def = BannerCatalog.shared.definition(for: id), !def.messages.isEmpty else {
                fatalError("❌ HoneycombBannerCatalogTests: \(id.rawValue) has zero messages")
            }
        }
    }

    static func testGatedEntriesHaveChanceAndFallback() {
        for id in BannerID.allCases {
            guard let def = BannerCatalog.shared.definition(for: id), def.gated else { continue }
            guard def.gateChance != nil else {
                fatalError("❌ HoneycombBannerCatalogTests: \(id.rawValue) is gated but has no gateChance")
            }
            guard def.fallback != nil else {
                fatalError("❌ HoneycombBannerCatalogTests: \(id.rawValue) is gated but has no fallback")
            }
        }
    }

    static func testUngatedEntriesHaveNoGateFields() {
        for id in BannerID.allCases {
            guard let def = BannerCatalog.shared.definition(for: id), !def.gated else { continue }
            guard def.gateChance == nil, def.fallback == nil else {
                fatalError("❌ HoneycombBannerCatalogTests: \(id.rawValue) isn't gated but has gateChance/fallback set")
            }
        }
    }

    static func testFireReturnsContentForEveryID() {
        // Runs each id several times to exercise both the gated (fallback) and
        // ungated (message) branches at least once for gated entries.
        for id in BannerID.allCases {
            for _ in 0..<20 {
                switch BannerCatalog.shared.fire(id) {
                case .message, .fallback:
                    continue
                case .none:
                    fatalError("❌ HoneycombBannerCatalogTests: fire(\(id.rawValue)) returned .none — every valid id should always produce content")
                }
            }
        }
    }

    static func testTokenSubstitution() {
        guard let result = try? {
            switch BannerCatalog.shared.fire(.gameplayOpponentIsWinningByTwoCardsAndIsAboutToPlaceThe, tokens: ["OpponentName": "Baby Bee"]) {
            case .message(let text): return text
            case .fallback(let text): return text
            case .none: throw NSError(domain: "test", code: 0)
            }
        }() else {
            fatalError("❌ HoneycombBannerCatalogTests: token substitution test couldn't fire its banner")
        }
        guard result.contains("Baby Bee"), !result.contains("{OpponentName}") else {
            fatalError("❌ HoneycombBannerCatalogTests: token substitution failed — got \"\(result)\"")
        }
    }
}
