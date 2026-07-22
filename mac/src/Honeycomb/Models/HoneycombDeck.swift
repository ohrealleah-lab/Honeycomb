import Foundation
import Observation

public struct HoneycombDeckState: Codable, Equatable {
    public var name: String = ""
    public var cardIds: [Int] = []
}

@Observable
public class HoneycombProfileManager {
    public static let shared = HoneycombProfileManager()
    
    public private(set) var unlockedCardIds: Set<Int> = []
    public var savedDecks: [HoneycombDeckState] = []
    public private(set) var favoriteCardIds: Set<Int> = []

    private let unlockedKey = "honeycomb_unlocked_cards"
    private let decksKey = "honeycomb_saved_decks"
    private let favoritesKey = "honeycomb_favorite_cards"
    
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
            // Put the starter cards in deck 0, named "Default", if it's the first time.
            // (Options.activeDeckIndex already defaults to 0, so this is also the
            // active deck — there's always an active deck to save changes to.)
            let starters = Array(unlockedCardIds)
            if starters.count == 5 {
                savedDecks[0].name = "Default"
                savedDecks[0].cardIds = starters
            }
            saveDecks()
        }

        if let data = UserDefaults.standard.array(forKey: favoritesKey) as? [Int] {
            favoriteCardIds = Set(data)
        }
    }

    public func unlockCard(id: Int) {
        unlockedCardIds.insert(id)
        saveUnlockedCards()
    }

    public var isCardBankFull: Bool {
        unlockedCardIds.count >= HoneycombDatabase.shared.allCards.count
    }

    // The composition a never-played Deck 1 starts with: three 1-star, two 2-star.
    private static let defaultStarterComposition: [Int] = [1, 1, 1, 2, 2]

    // Pure core of Start Over, factored out so it's testable without touching the
    // shared singleton's real persisted UserDefaults state: wipes every saved deck
    // except Deck 1 (index 0), renames it "Default", and regenerates it with freshly
    // drawn cards that match its previous star-tier composition — so a player who
    // built up a deck of e.g. a 5-star, a 4-star, and three 3-stars gets that same
    // composition back (new specific cards, reseeded stats) rather than the literal
    // same card ids. A never-played Deck 1 (empty) falls back to the default starter
    // composition. The caller is responsible for also making Deck 1 the active deck.
    public static func computeStartOverDecks(
        currentDecks: [HoneycombDeckState],
        starLookup: (Int) -> Int?,
        randomCard: (Int) -> Int?
    ) -> [HoneycombDeckState] {
        var decks = Array(repeating: HoneycombDeckState(), count: 5)
        decks[0].name = "Default"
        let previousCardIds = currentDecks[0].cardIds
        let starComposition = previousCardIds.isEmpty
            ? defaultStarterComposition
            : previousCardIds.compactMap(starLookup)
        decks[0].cardIds = starComposition.compactMap(randomCard)
        return decks
    }

    // Wipes saved decks and the card bank back to just Deck 1 (savedDecks[0]) — the
    // reroll/reseed of HoneycombDatabase itself is a separate call the caller makes
    // right after this, since that's shared match/AI state this manager doesn't own.
    public func startOver() {
        let db = HoneycombDatabase.shared
        savedDecks = HoneycombProfileManager.computeStartOverDecks(
            currentDecks: savedDecks,
            starLookup: { db.card(id: $0)?.stars },
            randomCard: { stars in db.randomCards(stars: stars, count: 1).first?.id }
        )
        unlockedCardIds = Set(savedDecks[0].cardIds)
        favoriteCardIds = []
        saveUnlockedCards()
        saveDecks()
        saveFavorites()
    }

    public func toggleFavorite(id: Int) {
        if favoriteCardIds.contains(id) {
            favoriteCardIds.remove(id)
        } else {
            favoriteCardIds.insert(id)
        }
        saveFavorites()
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

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteCardIds), forKey: favoritesKey)
    }
    
    private func saveDecks() {
        if let encoded = try? JSONEncoder().encode(savedDecks) {
            UserDefaults.standard.set(encoded, forKey: decksKey)
        }
    }
}
