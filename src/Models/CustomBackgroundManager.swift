import Foundation
import AppKit
import SwiftUI
import Observation

public struct CustomBackground: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var relativePath: String  // Filename in App Support/Backgrounds directory
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(id: UUID = UUID(), name: String, relativePath: String, scale: Double = 1.0,
                offsetX: Double = 0.0, offsetY: Double = 0.0) {
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
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        self.offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.0
        self.offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0.0
    }
}

@Observable
public final class CustomBackgroundManager {
    public static let shared = CustomBackgroundManager()

    // Imports over this size are rejected outright (spec's "Huge Images" edge case) —
    // no downscaling, just a friendly error surfaced by the picker UI.
    public static let maxImportBytes = 25 * 1024 * 1024

    // Excluded from observation so cache writes don't trigger SwiftUI re-renders across the board.
    @ObservationIgnored private var imageCache: [String: NSImage] = [:]
    @ObservationIgnored private var thumbnailCache: [String: NSImage] = [:]
    @ObservationIgnored private var loadsInFlight: Set<String> = []

    public var imageLoadTick: Int = 0

    public var customBackgrounds: [CustomBackground] = []

    private init() {
        loadCustomBackgrounds()
    }

    private var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SoliBee").appendingPathComponent("Backgrounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func loadCustomBackgrounds() {
        if let data = UserDefaults.standard.data(forKey: "custom_backgrounds"),
           let decoded = try? JSONDecoder().decode([CustomBackground].self, from: data) {
            self.customBackgrounds = decoded
        } else {
            self.customBackgrounds = []
        }
        pruneOrphanedEntries()
        preloadImages()
    }

    // Satisfies the spec's "Missing File" edge case: if a background's file was
    // manually deleted outside the app, the entry (and any reference to it) quietly
    // disappears rather than pointing at nothing.
    private func pruneOrphanedEntries() {
        let dir = appSupportDirectory
        let before = customBackgrounds.count
        customBackgrounds = customBackgrounds.filter {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path)
        }
        if customBackgrounds.count != before {
            saveCustomBackgrounds()
        }
    }

    public func saveCustomBackgrounds() {
        if let encoded = try? JSONEncoder().encode(customBackgrounds) {
            UserDefaults.standard.set(encoded, forKey: "custom_backgrounds")
        }
    }

    public func addCustomBackground(name: String, imageData: Data, scale: Double, offsetX: Double,
                                     offsetY: Double) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty,
              !customBackgrounds.contains(where: { $0.name == cleanedName }),
              imageData.count <= Self.maxImportBytes,
              let image = NSImage(data: imageData) else {
            return false
        }

        guard let finalPngData = ImageEncoding.pngData(from: image) else { return false }

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let fileURL = appSupportDirectory.appendingPathComponent(filename)

        do {
            try finalPngData.write(to: fileURL)
            let newBackground = CustomBackground(id: id, name: cleanedName, relativePath: filename, scale: scale,
                                                  offsetX: offsetX, offsetY: offsetY)
            customBackgrounds.append(newBackground)
            saveCustomBackgrounds()
            preloadImages()
            return true
        } catch {
            return false
        }
    }

    /// Updates an existing background's visual settings (scale/offset) in place.
    /// Name/relativePath never change here — renaming isn't supported, matching
    /// CustomCardBackManager/CustomFaceCardArtManager, which don't support it either.
    public func updateCustomBackground(_ updated: CustomBackground) {
        guard let idx = customBackgrounds.firstIndex(where: { $0.id == updated.id }) else { return }
        customBackgrounds[idx] = updated
        saveCustomBackgrounds()
    }

    /// Returns `true` on success. Returns `false` (without touching anything) if a saved
    /// theme still references this background — the UI layer is expected to have already
    /// blocked this path with an alert, but a manager-level guard ensures correctness
    /// even for any future direct callers that bypass the UI.
    @discardableResult
    public func removeCustomBackground(_ background: CustomBackground) -> Bool {
        // Block deletion entirely when a theme references this background by name.
        // Unlike the previous approach (skip file delete but always remove list entry),
        // we leave both the file and the list entry intact so the theme reference never
        // dangles — the UI already surfaces the friendly "please delete the theme first"
        // alert before reaching this point, so in practice this guard is a safety net.
        guard ThemeManager.shared.themeReferencingBackground(named: background.name) == nil else {
            return false
        }
        let fileURL = appSupportDirectory.appendingPathComponent(background.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
        invalidateCache(for: background.relativePath)
        customBackgrounds.removeAll { $0.id == background.id }
        saveCustomBackgrounds()
        return true
    }

    public func getFileURL(for relativePath: String) -> URL {
        appSupportDirectory.appendingPathComponent(relativePath)
    }

    // Board-scale display cache — longer edge capped here for retina sharpness without
    // wasting memory on huge source photos. Aspect ratio is always preserved (no
    // padding): CustomBackgroundRenderView does the actual aspect-fill crop against the
    // real window size at render time, so baking any particular target aspect in here
    // would show up as visible padding bars whenever a photo doesn't match it.
    private static let maxDisplayDimension: CGFloat = 2400
    // Cap for the small picker dropdown thumbnail.
    private static let maxThumbnailDimension: CGFloat = 240

    private func scaled(_ source: NSImage, maxDimension: CGFloat) -> NSImage {
        let srcSize = source.size
        guard srcSize.width > 0, srcSize.height > 0 else { return source }
        let scale = min(maxDimension / max(srcSize.width, srcSize.height), 1.0)
        guard scale < 1.0 else { return source }
        let targetSize = NSSize(width: srcSize.width * scale, height: srcSize.height * scale)
        let result = NSImage(size: targetSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: targetSize),
                    from: NSRect(origin: .zero, size: srcSize),
                    operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    public func image(for relativePath: String) -> NSImage? {
        print("[DEBUG] image(for:) called with path: \(relativePath)")
        if let cached = imageCache[relativePath] { 
            print("[DEBUG] -> cache hit")
            return cached 
        }
        
        guard !loadsInFlight.contains(relativePath) else { 
            print("[DEBUG] -> already-in-flight-skip")
            return nil 
        }
        print("[DEBUG] -> newly-scheduled")
        loadsInFlight.insert(relativePath)

        // Never block the main thread — large images can take time to load and scale.
        // Load in background; bump imageLoadTick so the BackgroundLayerView re-renders.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fileURL = getFileURL(for: relativePath)
            
            print("[DEBUG] before NSImage(contentsOf: \(fileURL.path))")
            guard let img = NSImage(contentsOf: fileURL) else {
                print("[DEBUG] NSImage(contentsOf:) failed! Returning nil.")
                DispatchQueue.main.async {
                    self.loadsInFlight.remove(relativePath)
                }
                return
            }
            print("[DEBUG] after NSImage(contentsOf:), success")
            
            let display = scaled(img, maxDimension: Self.maxDisplayDimension)
            DispatchQueue.main.async {
                self.imageCache[relativePath] = display
                self.loadsInFlight.remove(relativePath)
                print("[DEBUG] posting CustomBackgroundLoaded notification")
                NotificationCenter.default.post(name: NSNotification.Name("CustomBackgroundLoaded"), object: nil)
            }
        }
        return nil
    }

    public func thumbnail(for relativePath: String) -> NSImage? {
        if let cached = thumbnailCache[relativePath] { return cached }
        guard let display = image(for: relativePath) else { return nil }
        let thumb = scaled(display, maxDimension: Self.maxThumbnailDimension)
        thumbnailCache[relativePath] = thumb
        return thumb
    }

    public func invalidateCache(for relativePath: String) {
        imageCache.removeValue(forKey: relativePath)
        thumbnailCache.removeValue(forKey: relativePath)
    }

    /// Warms the image cache. Any paths in `priorityPaths` are loaded
    /// synchronously on the calling thread first (so the very first SwiftUI
    /// render already has a non-nil image and skips the Color fallback).
    /// Everything else is dispatched to a background thread as before.
    public func preloadImages(priorityPaths: Set<String> = []) {
        let toLoad = customBackgrounds
            .filter { imageCache[$0.relativePath] == nil }
            .map { (path: $0.relativePath, url: appSupportDirectory.appendingPathComponent($0.relativePath)) }
        guard !toLoad.isEmpty else { return }

        // Synchronous pass: load priority images immediately so the first
        // SwiftUI render frame already has the active background in cache.
        let (priority, deferred) = toLoad.reduce(
            into: ([(path: String, url: URL)](), [(path: String, url: URL)]())) { result, item in
            if priorityPaths.contains(item.path) { result.0.append(item) }
            else { result.1.append(item) }
        }
        for item in priority {
            guard let img = NSImage(contentsOf: item.url) else { continue }
            imageCache[item.path] = scaled(img, maxDimension: Self.maxDisplayDimension)
        }

        // Async pass: load everything else without blocking the main thread.
        guard !deferred.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for item in deferred {
                guard let img = NSImage(contentsOf: item.url) else { continue }
                let display = self.scaled(img, maxDimension: Self.maxDisplayDimension)
                DispatchQueue.main.async { 
                    self.imageCache[item.path] = display 
                    NotificationCenter.default.post(name: NSNotification.Name("CustomBackgroundLoaded"), object: nil)
                }
            }
        }
    }
}
