import Foundation
import AppKit
import Observation

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
        let dir = base.appendingPathComponent("SoliBee").appendingPathComponent("FaceArt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // Pre-folder-structure location — files used to be dumped flat here alongside card
    // backs and (later) background images. Not created; only read from during migration.
    private var legacyAppSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("SoliBee")
    }

    // One-time migration from the flat layout into FaceArt/. Moves whatever it can;
    // anything that fails to move (permissions, etc.) is left in place rather than
    // pruned, so a failed move never loses the user's file.
    private func migrateLegacyFilesIfNeeded() {
        let legacyDir = legacyAppSupportDirectory
        let newDir = appSupportDirectory
        for entry in faceArts {
            let newURL = newDir.appendingPathComponent(entry.relativePath)
            guard !FileManager.default.fileExists(atPath: newURL.path) else { continue }
            let legacyURL = legacyDir.appendingPathComponent(entry.relativePath)
            guard FileManager.default.fileExists(atPath: legacyURL.path) else { continue }
            try? FileManager.default.moveItem(at: legacyURL, to: newURL)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "custom_face_arts"),
           let decoded = try? JSONDecoder().decode([CustomFaceArt].self, from: data) {
            faceArts = decoded
        }
        migrateLegacyFilesIfNeeded()
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
        ThemeManager.shared.invalidateActiveTheme()
        return true
    }

    public func update(_ updated: CustomFaceArt) {
        if let idx = faceArts.firstIndex(where: { $0.slot == updated.slot }) {
            faceArts[idx] = updated
            save()
            ThemeManager.shared.invalidateActiveTheme()
        }
    }

    public func remove(slot: FaceCardSlot, deleteFile: Bool = true) {
        if let existing = art(for: slot) {
            // Don't delete the underlying file if any saved theme still references this
            // exact art — otherwise applying that theme later silently drops the slot
            // with no indication anything went wrong.
            let stillReferencedBySavedTheme = ThemeManager.shared.themeReferencingFaceArt(relativePath: existing.relativePath) != nil
            if deleteFile && !stillReferencedBySavedTheme {
                let fileURL = appSupportDirectory.appendingPathComponent(existing.relativePath)
                try? FileManager.default.removeItem(at: fileURL)
            }
            imageCache.removeValue(forKey: existing.relativePath)
            faceArts.removeAll { $0.slot == slot }
            save()
            ThemeManager.shared.invalidateActiveTheme()
        }
    }

    public func setEnabled(_ enabled: Bool, for slot: FaceCardSlot) {
        if let idx = faceArts.firstIndex(where: { $0.slot == slot }) {
            faceArts[idx].isEnabled = enabled
            save()
            ThemeManager.shared.invalidateActiveTheme()
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
        ImageEncoding.pngData(from: image)
    }
}
