import Foundation
import AppKit
import Observation

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

@Observable
public final class CustomFaceCardArtManager {
    public static let shared = CustomFaceCardArtManager()

    public var faceArts: [CustomFaceArt] = []
    @ObservationIgnored private var imageCache: [String: NSImage] = [:]

    // Face card art renders in a 77×122 frame; cache at 2× for retina.
    private static let displaySize = NSSize(width: 154, height: 244)

    private init() { load(); preloadImages() }

    private var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SoliBee")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "custom_face_arts"),
           let decoded = try? JSONDecoder().decode([CustomFaceArt].self, from: data) {
            faceArts = decoded
        }
        pruneOrphanedEntries()
    }

    private func pruneOrphanedEntries() {
        let dir = appSupportDirectory
        let before = faceArts.count
        faceArts = faceArts.filter {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path)
        }
        if faceArts.count != before {
            save()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(faceArts) {
            UserDefaults.standard.set(encoded, forKey: "custom_face_arts")
        }
        preloadImages()
    }

    private func scaled(_ source: NSImage, to size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: size),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    /// Warms the image cache on a background thread so scrolling never blocks on disk I/O.
    public func preloadImages() {
        // Snapshot missing paths on the calling (main) thread — safe Dictionary read.
        let toLoad = faceArts
            .filter { imageCache[$0.relativePath] == nil }
            .map { (path: $0.relativePath, url: appSupportDirectory.appendingPathComponent($0.relativePath)) }
        guard !toLoad.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for item in toLoad {
                guard let img = NSImage(contentsOf: item.url) else { continue }
                let display = self.scaled(img, to: Self.displaySize)
                DispatchQueue.main.async { self.imageCache[item.path] = display }
            }
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
            }
            imageCache.removeValue(forKey: existing.relativePath)
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
        // Cache miss — load and scale synchronously (fallback; preloadImages() should prevent this).
        let url = appSupportDirectory.appendingPathComponent(art.relativePath)
        guard let img = NSImage(contentsOf: url) else { return nil }
        let display = scaled(img, to: Self.displaySize)
        imageCache[art.relativePath] = display
        return display
    }

    public func gifURL(for art: CustomFaceArt) -> URL? {
        guard art.relativePath.lowercased().hasSuffix(".gif") else { return nil }
        return appSupportDirectory.appendingPathComponent(art.relativePath)
    }

    /// Replaces the active face art set with the given arts (skipping any whose files are missing).
    public func restore(_ arts: [CustomFaceArt]) {
        let dir = appSupportDirectory
        faceArts = arts.filter {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path)
        }
        save()
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
