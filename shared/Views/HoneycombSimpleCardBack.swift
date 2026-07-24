import SwiftUI

/// Procedural card back used on platforms where the image-based CardBackView (bundle
/// art + custom card backs) hasn't been ported yet. Fills whatever frame the caller
/// gives it, like CardBackView does.
struct HoneycombSimpleCardBack: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.35),
                                            Color(red: 0.08, green: 0.06, blue: 0.2)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            GeometryReader { geo in
                Image(systemName: "hexagon.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width * 0.45)
                    .foregroundStyle(Color.yellow.opacity(0.25))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
        }
    }
}
