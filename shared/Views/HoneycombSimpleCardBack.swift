import SwiftUI

/// Procedural card back used on platforms where the image-based CardBackView (bundle
/// art + custom card backs) hasn't been ported yet. Fills whatever frame the caller
/// gives it, like CardBackView does. Design: a honeycomb cluster in muted gold over a
/// deep navy-to-indigo gradient, with a double border.
struct HoneycombSimpleCardBack: View {
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
