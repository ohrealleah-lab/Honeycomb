import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Card back view for platforms where the mac's full CardBackView (bundle art + custom
/// user-imported decks, GIF support) hasn't been ported. Tries the bundled theme art
/// first (Moogle, Dingwall, Forest, etc.), then a user-imported custom card back
/// (IOSCustomCardBackManager), falling back to a procedural honeycomb design if neither
/// matches. GIF-animated custom backs aren't supported yet — imports are flattened to a
/// static image.
struct HoneycombSimpleCardBack: View {
    @Environment(\.activeCardBackTheme) private var theme: String

    var body: some View {
        Group {
            #if os(iOS)
            if let image = BundledCardBackImage.uiImage(for: theme) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // Some bundled art (e.g. Vulpera's priest.png) is a character
                    // illustration on a mostly-transparent canvas, not a full-bleed card
                    // back. That's invisible on a full card face, but in a tightly
                    // overlapping tableau stack (Klondike's/Spider's face-down piles) only
                    // a thin sliver of each card shows, and that sliver can land entirely
                    // within the transparent margin — reading as "no card back at all"
                    // instead of the intended art. A dark backing behind the image (rather
                    // than relying on TouchCardView's white card-face fill showing through)
                    // keeps every sliver reading as "this is a themed card back," not blank.
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            } else if let entry = IOSCustomCardBackManager.shared.entry(named: theme),
                      let image = IOSCustomCardBackManager.shared.image(for: entry) {
                CroppedCardBackImage(image: image, entry: entry)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            } else {
                ProceduralHoneycombCardBack()
            }
            #else
            ProceduralHoneycombCardBack()
            #endif
        }
    }
}

#if os(iOS)
/// Renders a custom card-back image at its saved crop (scale + position), sized to
/// whatever frame the caller gives it. Offset is stored as a fraction of card width/
/// height rather than raw points, so the same crop looks identical whether it's drawn
/// as a 44pt menu thumbnail or a 150pt board card.
struct CroppedCardBackImage: View {
    let image: UIImage
    let entry: IOSCustomCardBackManager.Entry

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(entry.scale)
                .offset(x: entry.offsetXFraction * geo.size.width,
                        y: entry.offsetYFraction * geo.size.height)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
    }
}
#endif

#if os(iOS)
/// Lazily loads and caches the mac app's bundled card-back art (copied into the iOS
/// target's resources by project.yml) so both platforms show identical default themes.
/// Custom user-imported decks (mac's CustomCardBackManager, stored in Application
/// Support) aren't ported — an unrecognized theme name here just means "not bundled,"
/// and callers fall back to the procedural design.
enum BundledCardBackImage {
    private static let fileByTheme: [String: (resource: String, ext: String)] = [
        "Moogle": ("moogle", "jpg"),
        "Dingwall": ("dingwall", "jpg"),
        "Vulpera": ("priest", "png"),
        "Forest": ("Forest", "png"),
        "On The Water": ("On The Water", "png"),
        "Pareidolic": ("Pareidolic", "png"),
        "Pareidolic 2": ("Pareidolic 2", "png"),
        "Red Sky": ("Red Sky", "png"),
        "Sunset": ("Sunset", "png"),
        "Solibee": ("Solibee", "png"),
    ]

    static let allThemeNames: [String] = ["Moogle", "Vulpera", "Forest", "On The Water", "Pareidolic", "Pareidolic 2", "Red Sky", "Sunset", "Solibee"]

    private static var cache: [String: UIImage] = [:]

    static func uiImage(for theme: String) -> UIImage? {
        if let cached = cache[theme] { return cached }
        guard let (resource, ext) = fileByTheme[theme],
              let path = Bundle.main.path(forResource: resource, ofType: ext),
              let image = UIImage(contentsOfFile: path) else { return nil }
        cache[theme] = image
        return image
    }
}

/// User-imported custom card backs on iOS. A deliberately smaller counterpart to mac's
/// CustomCardBackManager: static images only (no GIF animation), stored as flat PNGs
/// under Application Support/Honeycomb/CardBacks, with an in-memory cache. Names must
/// be unique and can't collide with a bundled theme name.
@Observable
public final class IOSCustomCardBackManager {
    public static let shared = IOSCustomCardBackManager()

    public struct Entry: Codable, Identifiable, Equatable {
        public var id: UUID
        public var name: String
        public var relativePath: String
        // Crop, matching mac's CustomCardBack model but with offsets stored as
        // fractions of card width/height (see CroppedCardBackImage) rather than raw
        // points, since iOS renders card backs at far more different sizes than mac does.
        public var scale: Double = 1.0
        public var offsetXFraction: Double = 0.0
        public var offsetYFraction: Double = 0.0
    }

    public private(set) var customCardBacks: [Entry] = []

    @ObservationIgnored private var imageCache: [String: UIImage] = [:]
    private let defaultsKey = "ios_custom_card_backs"

    private var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Honeycomb").appendingPathComponent("CardBacks")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            customCardBacks = decoded
        }
        // Drop any entry whose backing file has gone missing rather than let it linger
        // as a theme name that silently falls back to the procedural design forever.
        let dir = storageDirectory
        let before = customCardBacks.count
        customCardBacks = customCardBacks.filter { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path) }
        if customCardBacks.count != before { persist() }
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(customCardBacks) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    /// - Returns: whether the import succeeded (fails on a blank/duplicate/reserved name).
    @discardableResult
    public func addCustomCardBack(name: String, image: UIImage, scale: Double = 1.0,
                                   offsetXFraction: Double = 0.0, offsetYFraction: Double = 0.0) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !BundledCardBackImage.allThemeNames.contains(cleaned),
              !customCardBacks.contains(where: { $0.name == cleaned }),
              let data = image.pngData() else { return false }

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let url = storageDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            return false
        }
        customCardBacks.append(Entry(id: id, name: cleaned, relativePath: filename,
                                     scale: scale, offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction))
        persist()
        return true
    }

    /// Updates an existing entry's crop in place (re-editing after import) without
    /// touching the stored image file.
    public func updateCrop(id: UUID, scale: Double, offsetXFraction: Double, offsetYFraction: Double) {
        guard let index = customCardBacks.firstIndex(where: { $0.id == id }) else { return }
        customCardBacks[index].scale = scale
        customCardBacks[index].offsetXFraction = offsetXFraction
        customCardBacks[index].offsetYFraction = offsetYFraction
        persist()
    }

    public func removeCustomCardBack(_ entry: Entry) {
        let url = storageDirectory.appendingPathComponent(entry.relativePath)
        try? FileManager.default.removeItem(at: url)
        imageCache.removeValue(forKey: entry.relativePath)
        customCardBacks.removeAll { $0.id == entry.id }
        persist()
    }

    public func entry(named name: String) -> Entry? {
        customCardBacks.first { $0.name == name }
    }

    public func image(for entry: Entry) -> UIImage? {
        if let cached = imageCache[entry.relativePath] { return cached }
        guard let image = UIImage(contentsOfFile: storageDirectory.appendingPathComponent(entry.relativePath).path) else { return nil }
        imageCache[entry.relativePath] = image
        return image
    }

    public func image(named name: String) -> UIImage? {
        guard let entry = entry(named: name) else { return nil }
        return image(for: entry)
    }
}
#endif

/// The original procedural design: a honeycomb cluster in muted gold over a deep
/// navy-to-indigo gradient, with a double border. Used when no bundled art matches the
/// active theme.
private struct ProceduralHoneycombCardBack: View {
    private static let honey = Color(red: 0.94, green: 0.75, blue: 0.27)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(colors: [Color(red: 0.13, green: 0.11, blue: 0.32),
                                            Color(red: 0.06, green: 0.05, blue: 0.17)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let cell = w * 0.24
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                ZStack {
                    // Center comb cell, filled; six neighbors outlined around it.
                    Image(systemName: "hexagon.fill")
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: cell)
                        .foregroundStyle(Self.honey.opacity(0.85))
                        .position(center)

                    ForEach(0..<6, id: \.self) { i in
                        let angle = Double(i) * .pi / 3 + .pi / 6
                        Image(systemName: "hexagon")
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: cell)
                            .foregroundStyle(Self.honey.opacity(0.45))
                            .position(x: center.x + cos(angle) * cell * 0.92,
                                      y: center.y + sin(angle) * cell * 0.92)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            RoundedRectangle(cornerRadius: 6)
                .stroke(Self.honey.opacity(0.55), lineWidth: 1.5)
            RoundedRectangle(cornerRadius: 4)
                .inset(by: 3)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}
