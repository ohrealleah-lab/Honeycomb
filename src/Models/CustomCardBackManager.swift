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

    public let defaultThemes = ["Vulpera", "Moogle", "Dingwall", "Forest", "On The Water", "Pareidolic", "Pareidolic 2", "Red Sky", "Sunset"]

    // Excluded from observation so cache writes don't trigger SwiftUI re-renders across the board.
    @ObservationIgnored private var imageCache: [String: NSImage] = [:]
    @ObservationIgnored private var thumbnailCache: [String: NSImage] = [:]
    
    public var deletedDefaultDecks: [String] = [] {
        didSet {
            UserDefaults.standard.set(deletedDefaultDecks, forKey: "deleted_default_decks")
        }
    }
    
    public var customCardBacks: [CustomCardBack] = [] {
        didSet { _customCardBacksByName = Dictionary(uniqueKeysWithValues: customCardBacks.map { ($0.name, $0) }) }
    }

    @ObservationIgnored private var _customCardBacksByName: [String: CustomCardBack] = [:]

    public func customCardBack(named name: String) -> CustomCardBack? {
        _customCardBacksByName[name]
    }
    
    public var activeDecks: [String] {
        let remainingDefaults = defaultThemes.filter { !deletedDefaultDecks.contains($0) }
        let customNames = customCardBacks.map { $0.name }
        return remainingDefaults + customNames
    }
    
    private init() {
        loadCustomCardBacks()
        self.deletedDefaultDecks = UserDefaults.standard.stringArray(forKey: "deleted_default_decks") ?? []
        preloadImages()
    }
    
    private var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let appSupport = base.appendingPathComponent("SoliBee")
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
        pruneOrphanedEntries()
    }

    private func pruneOrphanedEntries() {
        let dir = appSupportDirectory
        let before = customCardBacks.count
        customCardBacks = customCardBacks.filter {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path)
        }
        if customCardBacks.count != before {
            saveCustomCardBacks()
        }
    }
    
    public func saveCustomCardBacks() {
        if let encoded = try? JSONEncoder().encode(customCardBacks) {
            UserDefaults.standard.set(encoded, forKey: "custom_card_backs")
        }
        preloadImages()
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
        invalidateCache(for: customBack.relativePath)
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
    
    // Card backs render at 120×173; cache at 2× for retina displays.
    private static let displaySize = NSSize(width: 240, height: 346)
    // Carousel thumbnail size.
    private static let thumbSize = NSSize(width: 120, height: 170)

    private func scaled(_ source: NSImage, to size: NSSize) -> NSImage {
        // Preserve aspect ratio (matching SwiftUI's .aspectRatio(contentMode: .fit))
        let srcSize = source.size
        guard srcSize.width > 0, srcSize.height > 0 else { return source }
        let scale = min(size.width / srcSize.width, size.height / srcSize.height)
        let drawSize = NSSize(width: srcSize.width * scale, height: srcSize.height * scale)
        let drawOrigin = NSPoint(x: (size.width - drawSize.width) / 2,
                                 y: (size.height - drawSize.height) / 2)
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: drawOrigin, size: drawSize),
                    from: NSRect(origin: .zero, size: srcSize),
                    operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    public func image(for relativePath: String) -> NSImage? {
        if let cached = imageCache[relativePath] { return cached }
        let fileURL = getFileURL(for: relativePath)
        guard let img = NSImage(contentsOf: fileURL) else { return nil }
        let display = scaled(img, to: Self.displaySize)
        imageCache[relativePath] = display
        return display
    }

    public func thumbnail(for relativePath: String) -> NSImage? {
        if let cached = thumbnailCache[relativePath] { return cached }
        // Derive thumbnail from the already-scaled display image to avoid re-loading.
        guard let display = image(for: relativePath) else { return nil }
        let thumb = scaled(display, to: Self.thumbSize)
        thumbnailCache[relativePath] = thumb
        return thumb
    }

    public func invalidateCache(for relativePath: String) {
        imageCache.removeValue(forKey: relativePath)
        thumbnailCache.removeValue(forKey: relativePath)
    }

    /// Warms the image cache on a background thread so first-access during scrolling is instant.
    public func preloadImages() {
        // Snapshot missing paths on the calling (main) thread — safe Dictionary read.
        let toLoad = customCardBacks
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
    
    public func resetDefaultCardBacks() {
        deletedDefaultDecks = []
    }
}
