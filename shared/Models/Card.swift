import Foundation

public struct Card: Identifiable, Equatable, Hashable, Codable {
    public enum Suit: String, CaseIterable, Codable, Hashable {
        case hearts
        case diamonds
        case spades
        case clubs
        
        public var isRed: Bool {
            self == .hearts || self == .diamonds
        }
        
        public var symbol: String {
            switch self {
            case .hearts: return "♥"
            case .diamonds: return "♦"
            case .spades: return "♠"
            case .clubs: return "♣"
            }
        }
    }
    
    public let id: UUID
    public let suit: Suit
    public let rank: Int // 1 (Ace) to 13 (King)
    public var faceUp: Bool
    
    public init(id: UUID = UUID(), suit: Suit, rank: Int, faceUp: Bool = false) {
        self.id = id
        self.suit = suit
        self.rank = rank
        self.faceUp = faceUp
    }
    
    public var isRed: Bool { suit.isRed }
    public var isBlack: Bool { !suit.isRed }
    
    public var isFaceCard: Bool {
        rank == 11 || rank == 12 || rank == 13
    }

    
    public var rankString: String {
        switch rank {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return String(rank)
        }
    }
}
