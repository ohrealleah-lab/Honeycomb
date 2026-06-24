import Foundation
import AppKit
import Observation

public enum FaceCardSlot: String, Codable, CaseIterable, Identifiable {
    case blackAce, redAce
    case blackJack, redJack
    case blackQueen, redQueen
    case blackKing, redKing

    public var id: String { rawValue }

    public var rankLabel: String {
        switch self {
        case .blackAce, .redAce:     return "A"
        case .blackJack, .redJack:   return "J"
        case .blackQueen, .redQueen: return "Q"
        case .blackKing, .redKing:   return "K"
        }
    }

    public var rank: Int {
        switch self {
        case .blackAce, .redAce:     return 1
        case .blackJack, .redJack:   return 11
        case .blackQueen, .redQueen: return 12
        case .blackKing, .redKing:   return 13
        }
    }

    public var isRed: Bool {
        switch self {
        case .redAce, .redJack, .redQueen, .redKing: return true
        default: return false
        }
    }

    public var suitSymbol: String { isRed ? "♥" : "♠" }

    public var displayName: String { "\(rankLabel)\(suitSymbol)" }

    public static func slot(rank: Int, isRed: Bool) -> FaceCardSlot? {
        switch (rank, isRed) {
        case (1,  false): return .blackAce
        case (1,  true):  return .redAce
        case (11, false): return .blackJack
        case (11, true):  return .redJack
        case (12, false): return .blackQueen
        case (12, true):  return .redQueen
        case (13, false): return .blackKing
        case (13, true):  return .redKing
        default:          return nil
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

@Observable
public final class CustomFaceCardArtManager {
    public static let shared = CustomFaceCardArtManager()

    public var faceArts: [CustomFaceArt] = []
    private var imageCache: [String: NSImage] = [:]

    private init() { load() }

    private var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("SoliBee")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "custom_face_arts"),
           let decoded = try? JSONDecoder().decode([CustomFaceArt].self, from: data) {
            faceArts = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(faceArts) {
            UserDefaults.standard.set(encoded, forKey: "custom_face_arts")
        }
    }

    public func art(for slot: FaceCardSlot) -> CustomFaceArt? {
        faceArts.first { $0.slot == slot }
    }

    public func enabledArt(for slot: FaceCardSlot) -> CustomFaceArt? {
        faceArts.first { $0.slot == slot && $0.isEnabled }
    }

    public func add(slot: FaceCardSlot, imageData: Data, isGIF: Bool, scale: Double, offsetX: Double, offsetY: Double) -> Bool {
        let id = UUID()
        let ext = isGIF ? "gif" : "png"
        let filename = "\(id.uuidString).\(ext)"
        let fileURL = appSupportDirectory.appendingPathComponent(filename)
        do {
            try imageData.write(to: fileURL)
        } catch {
            return false
        }
        // Remove previous art for this slot if any
        remove(slot: slot, deleteFile: true)
        let art = CustomFaceArt(id: id, slot: slot, relativePath: filename, scale: scale, offsetX: offsetX, offsetY: offsetY, isEnabled: true)
        faceArts.append(art)
        save()
        return true
    }

    public func update(_ updated: CustomFaceArt) {
        if let idx = faceArts.firstIndex(where: { $0.slot == updated.slot }) {
            faceArts[idx] = updated
            save()
        }
    }

    public func remove(slot: FaceCardSlot, deleteFile: Bool = true) {
        if let existing = art(for: slot) {
            if deleteFile {
                let fileURL = appSupportDirectory.appendingPathComponent(existing.relativePath)
                try? FileManager.default.removeItem(at: fileURL)
                imageCache.removeValue(forKey: existing.relativePath)
            }
            faceArts.removeAll { $0.slot == slot }
            save()
        }
    }

    public func setEnabled(_ enabled: Bool, for slot: FaceCardSlot) {
        if let idx = faceArts.firstIndex(where: { $0.slot == slot }) {
            faceArts[idx].isEnabled = enabled
            save()
        }
    }

    public func image(for art: CustomFaceArt) -> NSImage? {
        if let cached = imageCache[art.relativePath] { return cached }
        let url = appSupportDirectory.appendingPathComponent(art.relativePath)
        guard let img = NSImage(contentsOf: url) else { return nil }
        imageCache[art.relativePath] = img
        return img
    }

    public func gifURL(for art: CustomFaceArt) -> URL? {
        guard art.relativePath.lowercased().hasSuffix(".gif") else { return nil }
        return appSupportDirectory.appendingPathComponent(art.relativePath)
    }

    public func isGIF(_ art: CustomFaceArt) -> Bool {
        art.relativePath.lowercased().hasSuffix(".gif")
    }

    public func pngData(from image: NSImage) -> Data? {
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep,
               let data = bitmapRep.representation(using: .png, properties: [:]) {
                return data
            }
        }
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            return bitmap.representation(using: .png, properties: [:])
        }
        return nil
    }
}
