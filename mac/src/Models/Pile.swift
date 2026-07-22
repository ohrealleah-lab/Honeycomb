import Foundation

public struct Pile: Identifiable, Equatable, Codable {
    public enum PileType: String, Codable {
        case stock
        case waste
        case tableau
        case foundation
        case freeCell
    }
    
    public let id: String
    public let type: PileType
    public var cards: [Card]
    
    public init(id: String, type: PileType, cards: [Card] = []) {
        self.id = id
        self.type = type
        self.cards = cards
    }
    
    public var isEmpty: Bool {
        cards.isEmpty
    }
    
    public var topCard: Card? {
        cards.last
    }
}
