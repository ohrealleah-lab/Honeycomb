import Foundation

public class HoneycombDatabase {
    public static let shared = HoneycombDatabase()
    public private(set) var allCards: [HoneycombCardData] = []
    
    private init() {
        loadCards()
    }
    
    private func loadCards() {
        var url = Bundle.main.url(forResource: "cards_db", withExtension: "json")
        if url == nil {
            let possiblePaths = [
                "src/Honeycomb/cards_db.json",
                "cards_db.json",
                "Testing Agent/cards_db.json"
            ]
            for path in possiblePaths {
                let fileUrl = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    url = fileUrl
                    break
                }
            }
        }
        
        guard let finalUrl = url else {
            print("Error: Could not find cards_db.json in bundle or working directory.")
            return
        }
        do {
            let data = try Data(contentsOf: finalUrl)
            let decoder = JSONDecoder()
            allCards = try decoder.decode([HoneycombCardData].self, from: data)
        } catch {
            print("Error decoding cards_db.json: \(error)")
        }
    }
    
    public func card(id: Int) -> HoneycombCardData? {
        return allCards.first { $0.id == id }
    }
    
    public func randomCards(stars: Int, count: Int) -> [HoneycombCardData] {
        let pool = allCards.filter { $0.stars == stars }
        guard !pool.isEmpty else { return [] }
        var result: [HoneycombCardData] = []
        for _ in 0..<count {
            result.append(pool.randomElement()!)
        }
        return result
    }

    // Same star-tier pool as randomCards, but biased toward whichever cards are
    // actually strong under the match's current rules — under Reverse (where low
    // values capture high ones), a uniformly random pick within a tier could hand the
    // AI cards with a high total stat budget that are a *liability* rather than a
    // strength, letting a player farm high-star/high-value cards off a supposedly
    // "hard" opponent by simply enabling Reverse. Picks from the best-suited ~40% of
    // the tier (by total stat, ascending under Reverse or descending otherwise) rather
    // than always the single best card, so decks still vary match to match.
    public func rulesAwareCards(stars: Int, count: Int, preferLowStats: Bool) -> [HoneycombCardData] {
        let pool = allCards.filter { $0.stars == stars }
        guard !pool.isEmpty else { return [] }
        let sorted = pool.sorted { a, b in
            let totalA = a.stats.reduce(0, +)
            let totalB = b.stats.reduce(0, +)
            return preferLowStats ? totalA < totalB : totalA > totalB
        }
        let candidateCount = max(count, Int(ceil(Double(sorted.count) * 0.4)))
        let candidates = Array(sorted.prefix(candidateCount))
        var result: [HoneycombCardData] = []
        for _ in 0..<count {
            result.append(candidates.randomElement()!)
        }
        return result
    }
}
