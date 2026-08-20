import SwiftUI
#if os(iOS)
import UIKit

/// User-imported custom face-card art on iOS: one image per FaceCardSlot (16 total —
/// A/J/Q/K x 4 suits, matching mac). A deliberately smaller counterpart to mac's
/// CustomFaceCardArtManager: static images only (no GIF animation), stored as flat PNGs
/// under Application Support/Honeycomb/FaceArt. Crop uses the same scale + offset-
/// fraction model as IOSCustomCardBackManager, so it looks right at any render size.
@Observable
public final class IOSCustomFaceArtManager {
    public static let shared = IOSCustomFaceArtManager()

    public struct Entry: Codable, Identifiable, Equatable {
        public var id: UUID
        public var slot: FaceCardSlot
        public var relativePath: String
        public var scale: Double = 1.0
        public var offsetXFraction: Double = 0.0
        public var offsetYFraction: Double = 0.0
        public var isEnabled: Bool = true
    }

    public private(set) var faceArts: [Entry] = []

    @ObservationIgnored private var imageCache: [String: UIImage] = [:]
    private let defaultsKey = "ios_custom_face_arts"

    private var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Honeycomb").appendingPathComponent("FaceArt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            faceArts = decoded
        }
        let dir = storageDirectory
        let before = faceArts.count
        faceArts = faceArts.filter { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path) }
        if faceArts.count != before { persist() }
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(faceArts) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    public func entry(for slot: FaceCardSlot) -> Entry? {
        faceArts.first { $0.slot == slot }
    }

    public func enabledEntry(for slot: FaceCardSlot) -> Entry? {
        faceArts.first { $0.slot == slot && $0.isEnabled }
    }

    /// Replaces any existing art for this slot (one image per slot, like mac).
    @discardableResult
    public func setArt(slot: FaceCardSlot, image: UIImage, scale: Double, offsetXFraction: Double, offsetYFraction: Double) -> Bool {
        guard let data = image.pngData() else { return false }
        removeArt(for: slot)
        let id = UUID()
        let filename = "\(id.uuidString).png"
        let url = storageDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            return false
        }
        faceArts.append(Entry(id: id, slot: slot, relativePath: filename,
                              scale: scale, offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction))
        persist()
        return true
    }

    public func setEnabled(_ enabled: Bool, for slot: FaceCardSlot) {
        guard let index = faceArts.firstIndex(where: { $0.slot == slot }) else { return }
        faceArts[index].isEnabled = enabled
        persist()
    }

    public func removeArt(for slot: FaceCardSlot) {
        guard let existing = entry(for: slot) else { return }
        // iOS themes don't currently snapshot face art (see ThemesFullScreenView's
        // saveCurrentAsTheme, which always saves faceArts: []), so this is a no-op
        // today — kept for parity with the background/card-back cleanup in case that
        // changes.
        ThemeManager.shared.clearFaceArtReferences(relativePath: existing.relativePath)
        let url = storageDirectory.appendingPathComponent(existing.relativePath)
        try? FileManager.default.removeItem(at: url)
        imageCache.removeValue(forKey: existing.relativePath)
        faceArts.removeAll { $0.slot == slot }
        persist()
    }

    public func image(for entry: Entry) -> UIImage? {
        if let cached = imageCache[entry.relativePath] { return cached }
        guard let image = UIImage(contentsOfFile: storageDirectory.appendingPathComponent(entry.relativePath).path) else { return nil }
        imageCache[entry.relativePath] = image
        return image
    }
}

/// Renders a custom face-art image at its saved crop (scale + position fraction),
/// sized to whatever frame the caller gives it — same value-based approach as
/// CroppedCardBackImage, just taking raw values instead of a card-back Entry so it
/// works for both card backs and face art without a shared protocol.
struct ImageCropDisplay: View {
    let image: UIImage
    let scale: Double
    let offsetXFraction: Double
    let offsetYFraction: Double

    init(image: UIImage, entry: IOSCustomFaceArtManager.Entry) {
        self.image = image
        self.scale = entry.scale
        self.offsetXFraction = entry.offsetXFraction
        self.offsetYFraction = entry.offsetYFraction
    }

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                // Matches ImageCropEditor's preview (.fill) — was .fit, so a cropped
                // face-art image displayed smaller/letterboxed than what the player
                // saw and framed while cropping it.
                .aspectRatio(contentMode: .fill)
                // max(scale, 1.0) — see IOSCustomBackground.swift's matching clamp:
                // .aspectRatio(.fill) already covers geo.size at scale 1.0, so a saved
                // scale below that reopens a gap wherever this renders at a different
                // size/aspect ratio than it was originally cropped against.
                .scaleEffect(max(scale, 1.0))
                .offset(x: offsetXFraction * geo.size.width,
                        y: offsetYFraction * geo.size.height)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }
}
#endif
