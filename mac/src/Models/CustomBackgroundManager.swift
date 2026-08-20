import Foundation
import AppKit
import SwiftUI
import Observation
import CoreImage

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

    // Ceiling on a "priority" (synchronous, on the calling thread) preload — see
    // preloadImages(priorityPaths:) below. Above this, even the active background
    // goes through the async path instead, so a pathologically large file (e.g. one
    // imported before addCustomBackground started capping resolution, see below)
    // can't block the main thread at app launch for an unbounded amount of time.
    private static let maxSynchronousPreloadBytes = 4 * 1024 * 1024

    // Excluded from observation so cache writes don't trigger SwiftUI re-renders across the board.
    @ObservationIgnored private var imageCache: [String: NSImage] = [:]
    @ObservationIgnored private var thumbnailCache: [String: NSImage] = [:]
    @ObservationIgnored private var loadsInFlight: Set<String> = []
    // Sampled once per wallpaper (not recomputed per-frame) — used wherever a solid
    // "opaque background" tint needs to represent an active wallpaper theme instead of
    // a plain felt color (see AppCoordinator.currentAccentTint).
    @ObservationIgnored private var dominantColorCache: [String: Color] = [:]
    @ObservationIgnored private var dominantColorLoadsInFlight: Set<String> = []

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

        // Capped to the same maxDisplayDimension the app ever actually shows —
        // saving the source at full resolution (a phone photo can be tens of MB)
        // makes every later load slower for no visual benefit, and specifically
        // risks a multi-second synchronous decode at app launch if this ends up
        // the active background (see preloadImages(priorityPaths:) above).
        let cappedImage = scaled(image, maxDimension: Self.maxDisplayDimension)
        guard let finalPngData = ImageEncoding.pngData(from: cappedImage) else { return false }

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

    /// Deletion always succeeds — any saved theme still referencing this background by
    /// name gets its reference cleared (falls back to felt) rather than blocking the
    /// delete.
    public func removeCustomBackground(_ background: CustomBackground) {
        ThemeManager.shared.clearBackgroundReferences(named: background.name)
        let fileURL = appSupportDirectory.appendingPathComponent(background.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
        invalidateCache(for: background.relativePath)
        customBackgrounds.removeAll { $0.id == background.id }
        saveCustomBackgrounds()
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
        if let cached = imageCache[relativePath] {
            return cached
        }

        guard !loadsInFlight.contains(relativePath) else {
            return nil
        }
        loadsInFlight.insert(relativePath)

        // Never block the main thread — large images can take time to load and scale.
        // Load in background; bump imageLoadTick so the BackgroundLayerView re-renders.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fileURL = getFileURL(for: relativePath)

            guard let img = NSImage(contentsOf: fileURL) else {
                DispatchQueue.main.async {
                    self.loadsInFlight.remove(relativePath)
                }
                return
            }

            let display = scaled(img, maxDimension: Self.maxDisplayDimension)
            DispatchQueue.main.async {
                self.imageCache[relativePath] = display
                self.loadsInFlight.remove(relativePath)
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
        dominantColorCache.removeValue(forKey: relativePath)
    }

    // Average color of the wallpaper (via CIAreaAverage — a fast, well-established
    // "dominant color" approximation, not a true color-cluster analysis) so UI
    // elsewhere can tint an "opaque background" indicator to match a wallpaper theme
    // instead of falling back to a plain felt color that may have nothing to do with
    // what's actually on screen. Same nil-until-cached, async-then-cache pattern as
    // image(for:) — returns nil (caller falls back to felt color) until the sample is
    // ready, then posts the same CustomBackgroundLoaded notification image(for:) uses
    // so already-rendered views (BackgroundLayerView's loadTrigger pattern) pick it up.
    public func dominantColor(for relativePath: String) -> Color? {
        if let cached = dominantColorCache[relativePath] { return cached }
        // Needs the already-decoded image; if it's not cached yet, image(for:) is
        // already fetching it (or about to be asked to) — bail for now, this'll
        // resolve on the next CustomBackgroundLoaded-triggered re-render.
        guard let source = imageCache[relativePath] else { return nil }
        guard !dominantColorLoadsInFlight.contains(relativePath) else { return nil }
        dominantColorLoadsInFlight.insert(relativePath)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let sampled = Self.averageColor(of: source)
            DispatchQueue.main.async {
                guard let self else { return }
                if let sampled { self.dominantColorCache[relativePath] = sampled }
                self.dominantColorLoadsInFlight.remove(relativePath)
                NotificationCenter.default.post(name: NSNotification.Name("CustomBackgroundLoaded"), object: nil)
            }
        }
        return nil
    }

    private static func averageColor(of image: NSImage) -> Color? {
        guard let tiffData = image.tiffRepresentation, let ciImage = CIImage(data: tiffData) else { return nil }
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y,
                                     z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector
        ]), let outputImage = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: nil)
        return Color(red: Double(pixel[0]) / 255.0, green: Double(pixel[1]) / 255.0, blue: Double(pixel[2]) / 255.0)
    }

    /// Warms the image cache. Any paths in `priorityPaths` are loaded
    /// synchronously on the calling thread first (so the very first SwiftUI
    /// render already has a non-nil image and skips the Color fallback) — unless
    /// the file is larger than maxSynchronousPreloadBytes, in which case it's
    /// treated as deferred instead. Without this, a single oversized background
    /// (e.g. one imported before addCustomBackground started capping resolution)
    /// can block the main thread for seconds at app launch, before the first
    /// SwiftUI Scene even renders — which can trip macOS's "Application Not
    /// Responding" check even though the app recovers fine once it catches up.
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
            let size = (try? FileManager.default.attributesOfItem(atPath: item.url.path))?[.size] as? Int
            if priorityPaths.contains(item.path), let size, size <= Self.maxSynchronousPreloadBytes {
                result.0.append(item)
            } else {
                result.1.append(item)
            }
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
