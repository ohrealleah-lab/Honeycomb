import SwiftUI
#if os(iOS)
import UIKit

/// User-imported custom table backgrounds on iOS, mirroring mac's CustomBackgroundManager
/// (which, unlike card backs, has no bundled options — a custom background is always
/// user-imported or absent, falling back to the felt color). Static images only, same
/// scale + offset-fraction crop model as card backs/face art.
@Observable
public final class IOSCustomBackgroundManager {
    public static let shared = IOSCustomBackgroundManager()

    public struct Entry: Codable, Identifiable, Equatable {
        public var id: UUID
        public var name: String
        public var relativePath: String
        public var scale: Double = 1.0
        public var offsetXFraction: Double = 0.0
        public var offsetYFraction: Double = 0.0
    }

    public private(set) var backgrounds: [Entry] = []

    @ObservationIgnored private var imageCache: [String: UIImage] = [:]
    private let defaultsKey = "ios_custom_backgrounds"

    private var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Honeycomb").appendingPathComponent("Backgrounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            backgrounds = decoded
        }
        let dir = storageDirectory
        let before = backgrounds.count
        backgrounds = backgrounds.filter { FileManager.default.fileExists(atPath: dir.appendingPathComponent($0.relativePath).path) }
        if backgrounds.count != before { persist() }
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(backgrounds) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    @discardableResult
    public func addCustomBackground(name: String, image: UIImage, scale: Double = 1.0,
                                     offsetXFraction: Double = 0.0, offsetYFraction: Double = 0.0) -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !backgrounds.contains(where: { $0.name == cleaned }),
              let data = image.pngData() else { return false }

        let id = UUID()
        let filename = "\(id.uuidString).png"
        let url = storageDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
        } catch {
            return false
        }
        backgrounds.append(Entry(id: id, name: cleaned, relativePath: filename,
                                 scale: scale, offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction))
        persist()
        return true
    }

    public func removeCustomBackground(_ entry: Entry) {
        let url = storageDirectory.appendingPathComponent(entry.relativePath)
        try? FileManager.default.removeItem(at: url)
        imageCache.removeValue(forKey: entry.relativePath)
        backgrounds.removeAll { $0.id == entry.id }
        persist()
    }

    public func entry(named name: String) -> Entry? {
        backgrounds.first { $0.name == name }
    }

    public func image(for entry: Entry) -> UIImage? {
        if let cached = imageCache[entry.relativePath] { return cached }
        guard let image = UIImage(contentsOfFile: storageDirectory.appendingPathComponent(entry.relativePath).path) else { return nil }
        imageCache[entry.relativePath] = image
        return image
    }
}

/// Drop-in replacement for `coordinator.currentFeltColor.ignoresSafeArea()` across the
/// six game views: renders the active custom background (cropped per its saved scale/
/// offset) if one is set, falling back to the felt color otherwise — mirroring mac's
/// BackgroundLayerView. Also applies the Felt Vignette when enabled (previously exposed
/// as a toggle in the menu with nothing behind it — the setting existed and persisted,
/// it just never drew anything on iOS).
public struct IOSBackgroundLayer: View {
    @Environment(AppCoordinator.self) private var coordinator

    public init() {}

    public var body: some View {
        ZStack {
            GeometryReader { geo in
                if let name = coordinator.customBackgroundName,
                   let entry = IOSCustomBackgroundManager.shared.entry(named: name),
                   let image = IOSCustomBackgroundManager.shared.image(for: entry) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(entry.scale)
                        .offset(x: entry.offsetXFraction * geo.size.width, y: entry.offsetYFraction * geo.size.height)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    coordinator.currentFeltColor
                }
            }

            if coordinator.showFeltVignette {
                RadialGradient(
                    gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.34)]),
                    center: .center, startRadius: 100, endRadius: 680
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}
#endif
