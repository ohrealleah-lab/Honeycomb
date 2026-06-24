import Foundation
import AppKit
import Observation

public struct CustomCardBack: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var relativePath: String  // Filename in App Support directory
    public var scale: Double          // Selected slider scale factor (e.g. 1.25)
    public var offsetX: Double        // Horizontal offset
    public var offsetY: Double        // Vertical offset
    
    public init(id: UUID = UUID(), name: String, relativePath: String, scale: Double, offsetX: Double = 0.0, offsetY: Double = 0.0) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    enum CodingKeys: String, CodingKey {
        case id, name, relativePath, scale, offsetX, offsetY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.relativePath = try container.decode(String.self, forKey: .relativePath)
        self.scale = try container.decode(Double.self, forKey: .scale)
        self.offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.0
        self.offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0.0
    }
}

@Observable
public final class CustomCardBackManager {
    public static let shared = CustomCardBackManager()

    public let defaultThemes = ["Vulpera", "Moogle", "Dingwall"]

    private var imageCache: [String: NSImage] = [:]
    private var thumbnailCache: [String: NSImage] = [:]
    
    public var deletedDefaultDecks: [String] = [] {
        didSet {
            UserDefaults.standard.set(deletedDefaultDecks, forKey: "deleted_default_decks")
        }
    }
    
    public var customCardBacks: [CustomCardBack] = []
    
    public var activeDecks: [String] {
        let remainingDefaults = defaultThemes.filter { !deletedDefaultDecks.contains($0) }
        let customNames = customCardBacks.map { $0.name }
        return remainingDefaults + customNames
    }
    
    private init() {
        loadCustomCardBacks()
        self.deletedDefaultDecks = UserDefaults.standard.stringArray(forKey: "deleted_default_decks") ?? []
    }
    
    private var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("SoliBee")
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }
    
    public func loadCustomCardBacks() {
        if let data = UserDefaults.standard.data(forKey: "custom_card_backs"),
           let decoded = try? JSONDecoder().decode([CustomCardBack].self, from: data) {
            self.customCardBacks = decoded
        } else {
            self.customCardBacks = []
        }
    }
    
    public func saveCustomCardBacks() {
        if let encoded = try? JSONEncoder().encode(customCardBacks) {
            UserDefaults.standard.set(encoded, forKey: "custom_card_backs")
        }
    }
    
    public func isDefaultTheme(_ name: String) -> Bool {
        return defaultThemes.contains(name)
    }
    
    public func addCustomCardBack(name: String, image: NSImage, scale: Double, offsetX: Double = 0.0, offsetY: Double = 0.0) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty,
              !defaultThemes.contains(cleanedName),
              !customCardBacks.contains(where: { $0.name == cleanedName }) else {
            return false
        }

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let fileURL = appSupportDirectory.appendingPathComponent(filename)

        var pngData: Data? = nil
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep {
                pngData = bitmapRep.representation(using: .png, properties: [:])
                if pngData != nil { break }
            }
        }
        if pngData == nil {
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData) {
                pngData = bitmap.representation(using: .png, properties: [:])
            }
        }
        guard let finalPngData = pngData else { return false }

        do {
            try finalPngData.write(to: fileURL)
            let newBack = CustomCardBack(id: id, name: cleanedName, relativePath: filename, scale: scale, offsetX: offsetX, offsetY: offsetY)
            customCardBacks.append(newBack)
            saveCustomCardBacks()
            return true
        } catch {
            return false
        }
    }

    /// Saves raw GIF data preserving animation frames. Use this instead of addCustomCardBack when the source file is a GIF.
    public func addCustomCardBackGIF(name: String, data: Data, scale: Double, offsetX: Double = 0.0, offsetY: Double = 0.0) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty,
              !defaultThemes.contains(cleanedName),
              !customCardBacks.contains(where: { $0.name == cleanedName }) else {
            return false
        }

        let id = UUID()
        let filename = "\(id.uuidString).gif"
        let fileURL = appSupportDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            let newBack = CustomCardBack(id: id, name: cleanedName, relativePath: filename, scale: scale, offsetX: offsetX, offsetY: offsetY)
            customCardBacks.append(newBack)
            saveCustomCardBacks()
            return true
        } catch {
            return false
        }
    }

    public func isGIF(for relativePath: String) -> Bool {
        relativePath.lowercased().hasSuffix(".gif")
    }

    public func gifURL(for relativePath: String) -> URL? {
        guard isGIF(for: relativePath) else { return nil }
        return getFileURL(for: relativePath)
    }
    
    public func removeCustomCardBack(_ customBack: CustomCardBack) {
        let fileURL = appSupportDirectory.appendingPathComponent(customBack.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
        customCardBacks.removeAll { $0.id == customBack.id }
        saveCustomCardBacks()
    }
    
    public func deleteDeck(name: String) -> Bool {
        let currentActive = activeDecks
        guard currentActive.count > 1 else {
            return false
        }
        
        if isDefaultTheme(name) {
            if !deletedDefaultDecks.contains(name) {
                deletedDefaultDecks.append(name)
                return true
            }
        } else if let customBack = customCardBacks.first(where: { $0.name == name }) {
            removeCustomCardBack(customBack)
            return true
        }
        return false
    }
    
    public func getFileURL(for relativePath: String) -> URL {
        return appSupportDirectory.appendingPathComponent(relativePath)
    }
    
    public func image(for relativePath: String) -> NSImage? {
        if let cached = imageCache[relativePath] { return cached }
        let fileURL = getFileURL(for: relativePath)
        guard let img = NSImage(contentsOf: fileURL) else { return nil }
        imageCache[relativePath] = img
        return img
    }

    public func thumbnail(for relativePath: String) -> NSImage? {
        if let cached = thumbnailCache[relativePath] { return cached }
        guard let full = image(for: relativePath) else { return nil }
        let targetSize = NSSize(width: 120, height: 170)
        let thumb = NSImage(size: targetSize)
        thumb.lockFocus()
        full.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: full.size),
                  operation: .copy,
                  fraction: 1.0)
        thumb.unlockFocus()
        thumbnailCache[relativePath] = thumb
        return thumb
    }

    public func invalidateCache(for relativePath: String) {
        imageCache.removeValue(forKey: relativePath)
        thumbnailCache.removeValue(forKey: relativePath)
    }
    
    public func resetDefaultCardBacks() {
        deletedDefaultDecks = []
    }
}
