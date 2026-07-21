import Foundation

public struct HoneycombDeckState: Codable, Equatable {
    public var name: String = ""
    public var cardIds: [Int] = []
}

public class HoneycombProfileManager {
    public static let shared = HoneycombProfileManager()
    
    public private(set) var unlockedCardIds: Set<Int> = []
    public var savedDecks: [HoneycombDeckState] = []
    
    private let unlockedKey = "honeycomb_unlocked_cards"
    private let decksKey = "honeycomb_saved_decks"
    
    private init() {
        loadProfile()
    }
    
    private func loadProfile() {
        if let data = UserDefaults.standard.array(forKey: unlockedKey) as? [Int] {
            unlockedCardIds = Set(data)
        } else {
            // Give starter cards: three 1 star cards, two 2 star cards
            let db = HoneycombDatabase.shared
            let ones = db.randomCards(stars: 1, count: 3).map { $0.id }
            let twos = db.randomCards(stars: 2, count: 2).map { $0.id }
            unlockedCardIds = Set(ones + twos)
            saveUnlockedCards()
        }
        
        if let data = UserDefaults.standard.data(forKey: decksKey),
           let decoded = try? JSONDecoder().decode([HoneycombDeckState].self, from: data) {
            savedDecks = decoded
        } else {
            // Initialize 5 empty deck slots
            savedDecks = Array(repeating: HoneycombDeckState(), count: 5)
            // Put the starter cards in deck 0 as a default if it's the first time
            let starters = Array(unlockedCardIds)
            if starters.count == 5 {
                savedDecks[0].cardIds = starters
            }
            saveDecks()
        }
    }
    
    public func unlockCard(id: Int) {
        unlockedCardIds.insert(id)
        saveUnlockedCards()
    }
    
    public func saveDeck(index: Int, name: String, cardIds: [Int]) {
        guard index >= 0 && index < savedDecks.count else { return }
        savedDecks[index].name = name
        savedDecks[index].cardIds = cardIds
        saveDecks()
    }
    
    private func saveUnlockedCards() {
        UserDefaults.standard.set(Array(unlockedCardIds), forKey: unlockedKey)
    }
    
    private func saveDecks() {
        if let encoded = try? JSONEncoder().encode(savedDecks) {
            UserDefaults.standard.set(encoded, forKey: decksKey)
        }
    }
}
