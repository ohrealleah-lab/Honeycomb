import Foundation
import AppKit
import SwiftUI
import Observation
import CoreImage
import ImageIO

public struct CustomBackground: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var relativePath: String  // Filename in App Support/Backgrounds directory
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double
    // Sampled once (at import time for a new background, or via a one-time backfill
    // for one saved before this existed — see
    // CustomBackgroundManager.backfillDominantColorsIfNeeded()) and persisted here,
    // rather than re-sampled from the decoded image on every access. Lets UI that
    // wants "this theme's actual on-screen color" (a saved-theme swatch, the active
    // theme's accent tint) read it instantly with no dependency on that background's
    // full image being loaded at all.
    public var dominantColorRed: Double?
    public var dominantColorGreen: Double?
    public var dominantColorBlue: Double?

    public var dominantColor: Color? {
        guard let r = dominantColorRed, let g = dominantColorGreen, let b = dominantColorBlue else { return nil }
        return Color(red: r, green: g, blue: b)
    }

    public init(id: UUID = UUID(), name: String, relativePath: String, scale: Double = 1.0,
                offsetX: Double = 0.0, offsetY: Double = 0.0,
                dominantColorRed: Double? = nil, dominantColorGreen: Double? = nil, dominantColorBlue: Double? = nil) {
        self.id = id
        self.name = name
        self.relativePath = relativePath
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.dominantColorRed = dominantColorRed
        self.dominantColorGreen = dominantColorGreen
        self.dominantColorBlue = dominantColorBlue
    }

    enum CodingKeys: String, CodingKey {
        case id, name, relativePath, scale, offsetX, offsetY
        case dominantColorRed, dominantColorGreen, dominantColorBlue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.relativePath = try container.decode(String.self, forKey: .relativePath)
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        self.offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.0
        self.offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0.0
        self.dominantColorRed = try container.decodeIfPresent(Double.self, forKey: .dominantColorRed)
        self.dominantColorGreen = try container.decodeIfPresent(Double.self, forKey: .dominantColorGreen)
        self.dominantColorBlue = try container.decodeIfPresent(Double.self, forKey: .dominantColorBlue)
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
    // Guards backfillDominantColorsIfNeeded()'s one-time sampling pass for backgrounds
    // saved before CustomBackground.dominantColor existed — keyed by background id
    // (not path) since that's what identifies the persisted entry being updated.
    @ObservationIgnored private var dominantColorBackfillInFlight: Set<UUID> = []

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
        backfillDominantColorsIfNeeded()
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
        // Sampled from the image already in hand, before it's even written to disk —
        // no separate load/decode needed later just to know this theme's color.
        let dominantColor = Self.averageColorComponents(of: cappedImage)

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let fileURL = appSupportDirectory.appendingPathComponent(filename)

        do {
            try finalPngData.write(to: fileURL)
            let newBackground = CustomBackground(id: id, name: cleanedName, relativePath: filename, scale: scale,
                                                  offsetX: offsetX, offsetY: offsetY,
                                                  dominantColorRed: dominantColor?.red,
                                                  dominantColorGreen: dominantColor?.green,
                                                  dominantColorBlue: dominantColor?.blue)
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

    // Fast, bounded-time decode for the synchronous "priority" preload path.
    // ImageIO's thumbnail generator can downsample *during* decode instead of
    // fully decoding the source at its original resolution first — critical for
    // a large legacy background (e.g. an uncapped multi-thousand-pixel import
    // from before addCustomBackground started downscaling on save), where
    // NSImage(contentsOf:) followed by scaled(_:maxDimension:) would decode
    // every source pixel before throwing most of them away, slow enough to
    // visibly flash the felt-color fallback on launch.
    private static func fastDownscaledImage(at url: URL, maxDimension: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
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
    }

    // One-time migration for backgrounds saved before CustomBackground.dominantColor
    // existed — new imports get it computed immediately in addCustomBackground(_:)
    // from the image already in hand, no reload needed, so this only ever has
    // work to do for pre-existing entries. Runs off the main thread per entry (a
    // fresh decode at full-ish resolution, not the already-cached/downscaled
    // in-memory image) since this is a rare, one-time cost, not something any UI
    // is blocked waiting on; each result is persisted immediately so it's never
    // needed again for that entry, then broadcasts the same CustomBackgroundLoaded
    // notification the Themes sidebar (and anything else showing a swatch) already
    // listens for to pick up the now-accurate color.
    private func backfillDominantColorsIfNeeded() {
        let missing = customBackgrounds.filter { $0.dominantColor == nil }
        guard !missing.isEmpty else { return }
        for background in missing {
            guard !dominantColorBackfillInFlight.contains(background.id) else { continue }
            dominantColorBackfillInFlight.insert(background.id)
            let url = appSupportDirectory.appendingPathComponent(background.relativePath)
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let components = NSImage(contentsOf: url).flatMap(Self.averageColorComponents(of:))
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.dominantColorBackfillInFlight.remove(background.id)
                    guard let components,
                          let idx = self.customBackgrounds.firstIndex(where: { $0.id == background.id })
                    else { return }
                    self.customBackgrounds[idx].dominantColorRed = components.red
                    self.customBackgrounds[idx].dominantColorGreen = components.green
                    self.customBackgrounds[idx].dominantColorBlue = components.blue
                    self.saveCustomBackgrounds()
                    NotificationCenter.default.post(name: NSNotification.Name("CustomBackgroundLoaded"), object: nil)
                }
            }
        }
    }

    // Average color of the wallpaper (via CIAreaAverage — a fast, well-established
    // "dominant color" approximation, not a true color-cluster analysis). Returns raw
    // components rather than a Color so both the save-time computation (persisted as
    // CustomBackground.dominantColorRed/Green/Blue) and this backfill path can share
    // one implementation.
    private static func averageColorComponents(of image: NSImage) -> (red: Double, green: Double, blue: Double)? {
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
        return (Double(pixel[0]) / 255.0, Double(pixel[1]) / 255.0, Double(pixel[2]) / 255.0)
    }

    /// Warms the image cache. Any paths in `priorityPaths` are loaded
    /// synchronously on the calling thread first (so the very first SwiftUI
    /// render already has a non-nil image and skips the Color fallback), using a
    /// bounded-time downscaled decode (see fastDownscaledImage(at:maxDimension:))
    /// regardless of the file's on-disk size — unlike NSImage(contentsOf:), which
    /// must fully decode a source image at its original resolution before
    /// anything can downscale it, so a large legacy background (e.g. one
    /// imported before addCustomBackground started capping resolution) used to
    /// make this synchronous pass slow enough to visibly flash the felt-color
    /// fallback on every launch, or previously even get silently excluded from
    /// this "priority" pass entirely by a since-removed file-size cap. Everything
    /// not in priorityPaths is still dispatched to a background thread as before.
    public func preloadImages(priorityPaths: Set<String> = []) {
        let toLoad = customBackgrounds
            .filter { imageCache[$0.relativePath] == nil }
            .map { (path: $0.relativePath, url: appSupportDirectory.appendingPathComponent($0.relativePath)) }
        guard !toLoad.isEmpty else { return }

        // Synchronous pass: load priority images immediately so the first
        // SwiftUI render frame already has the active background in cache.
        let (priority, deferred) = toLoad.reduce(
            into: ([(path: String, url: URL)](), [(path: String, url: URL)]())) { result, item in
            if priorityPaths.contains(item.path) {
                result.0.append(item)
            } else {
                result.1.append(item)
            }
        }
        for item in priority {
            guard let img = Self.fastDownscaledImage(at: item.url, maxDimension: Self.maxDisplayDimension) else { continue }
            imageCache[item.path] = img
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
