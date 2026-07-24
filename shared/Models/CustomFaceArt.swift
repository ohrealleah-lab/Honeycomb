import Foundation

// Face-card art slot + per-slot art metadata. Pure Codable data shared across platforms;
// the NSImage-based manager that loads the actual art stays mac-side
// (mac/src/Models/CustomFaceCardArtManager.swift).
public enum FaceCardSlot: String, Codable, CaseIterable, Identifiable {
    case spadeAce, clubAce, heartAce, diamondAce
    case spadeJack, clubJack, heartJack, diamondJack
    case spadeQueen, clubQueen, heartQueen, diamondQueen
    case spadeKing, clubKing, heartKing, diamondKing

    public var id: String { rawValue }

    public var rankLabel: String {
        switch self {
        case .spadeAce, .clubAce, .heartAce, .diamondAce:     return "A"
        case .spadeJack, .clubJack, .heartJack, .diamondJack:   return "J"
        case .spadeQueen, .clubQueen, .heartQueen, .diamondQueen: return "Q"
        case .spadeKing, .clubKing, .heartKing, .diamondKing:   return "K"
        }
    }

    public var rank: Int {
        switch self {
        case .spadeAce, .clubAce, .heartAce, .diamondAce:     return 1
        case .spadeJack, .clubJack, .heartJack, .diamondJack:   return 11
        case .spadeQueen, .clubQueen, .heartQueen, .diamondQueen: return 12
        case .spadeKing, .clubKing, .heartKing, .diamondKing:   return 13
        }
    }

    public var isRed: Bool {
        switch self {
        case .heartAce, .diamondAce, .heartJack, .diamondJack, .heartQueen, .diamondQueen, .heartKing, .diamondKing:
            return true
        default:
            return false
        }
    }

    public var suitSymbol: String {
        switch self {
        case .spadeAce, .spadeJack, .spadeQueen, .spadeKing: return "♠"
        case .clubAce, .clubJack, .clubQueen, .clubKing: return "♣"
        case .heartAce, .heartJack, .heartQueen, .heartKing: return "♥"
        case .diamondAce, .diamondJack, .diamondQueen, .diamondKing: return "♦"
        }
    }

    public var displayName: String { "\(rankLabel)\(suitSymbol)" }

    public static func slot(rank: Int, suit: Card.Suit) -> FaceCardSlot? {
        switch (rank, suit) {
        case (1, .spades): return .spadeAce
        case (1, .clubs): return .clubAce
        case (1, .hearts): return .heartAce
        case (1, .diamonds): return .diamondAce
        case (11, .spades): return .spadeJack
        case (11, .clubs): return .clubJack
        case (11, .hearts): return .heartJack
        case (11, .diamonds): return .diamondJack
        case (12, .spades): return .spadeQueen
        case (12, .clubs): return .clubQueen
        case (12, .hearts): return .heartQueen
        case (12, .diamonds): return .diamondQueen
        case (13, .spades): return .spadeKing
        case (13, .clubs): return .clubKing
        case (13, .hearts): return .heartKing
        case (13, .diamonds): return .diamondKing
        default: return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "blackAce":    self = .spadeAce
        case "redAce":      self = .heartAce
        case "blackJack":   self = .spadeJack
        case "redJack":     self = .heartJack
        case "blackQueen":  self = .spadeQueen
        case "redQueen":    self = .heartQueen
        case "blackKing":   self = .spadeKing
        case "redKing":     self = .heartKing
        default:
            if let value = FaceCardSlot(rawValue: raw) {
                self = value
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid FaceCardSlot raw value: \(raw)")
            }
        }
    }
}

public struct CustomFaceArt: Codable, Identifiable, Equatable {
    public var id: UUID
    public var slot: FaceCardSlot
    public var relativePath: String
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double
    public var isEnabled: Bool

    public init(id: UUID = UUID(), slot: FaceCardSlot, relativePath: String,
                scale: Double = 1.0, offsetX: Double = 0.0, offsetY: Double = 0.0, isEnabled: Bool = true) {
        self.id = id
        self.slot = slot
        self.relativePath = relativePath
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.isEnabled = isEnabled
    }
}
