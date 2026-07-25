import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Card back view for platforms where the mac's full CardBackView (bundle art + custom
/// user-imported decks, GIF support) hasn't been ported. Renders the same bundled theme
/// art the mac app ships (Moogle, Dingwall, Forest, etc. — see BundledCardBackImage)
/// when the active theme matches one of those bundled names; falls back to a procedural
/// honeycomb design for anything else (custom decks aren't supported here yet, so an
/// unrecognized theme name means the mac-side custom deck manager hasn't been ported).
struct HoneycombSimpleCardBack: View {
    @Environment(\.activeCardBackTheme) private var theme: String

    var body: some View {
        Group {
            #if os(iOS)
            if let image = BundledCardBackImage.uiImage(for: theme) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
    ]

    static let allThemeNames: [String] = ["Moogle", "Vulpera", "Forest", "On The Water", "Pareidolic", "Pareidolic 2", "Red Sky", "Sunset"]

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
