import SwiftUI

/// Radial confetti burst for a big win — ported from mac's WinParticleView
/// (mac/src/Views/GameUIStyles.swift). Mac centers on a fixed (300, 90) point tuned to
/// its own window layout; sized via GeometryReader here instead so it centers itself
/// correctly over whatever card-row area it's overlaid on, at any screen size.
struct WinParticleView: View {
    let active: Bool

    @State private var particles: [Particle] = []
    @State private var spread = false
    @State private var opacity: Double = 0

    struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let speed: CGFloat
        let color: Color
        let scale: CGFloat
    }

    private let colors: [Color] = [.yellow, .orange, .white, .cyan, Color(red: 1, green: 0.84, blue: 0)]

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            ZStack {
                ForEach(particles) { p in
                    let rad = p.angle * .pi / 180
                    let tx = spread ? cx + cos(rad) * p.speed : cx
                    let ty = spread ? cy + sin(rad) * p.speed : cy
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: 7 * p.scale, height: 3 * p.scale)
                        .rotationEffect(.degrees(p.angle))
                        .position(x: tx, y: ty)
                        .animation(.easeOut(duration: 0.45), value: spread)
                }
            }
        }
        .opacity(opacity)
        .animation(.easeIn(duration: 0.35).delay(0.3), value: opacity)
        .onChange(of: active) { _, on in
            if on { burst() }
        }
        .allowsHitTesting(false)
    }

    private func burst() {
        let count = 36
        particles = (0..<count).map { i in
            Particle(
                angle: Double(i) / Double(count) * 360,
                // Smaller than mac's 70...170 — this overlays a compact card row, not
                // a full desktop window, so particles that travel too far read as
                // flying off the edge of the visible area instead of a contained burst.
                speed: CGFloat.random(in: 50...120),
                color: colors.randomElement()!,
                scale: CGFloat.random(in: 0.7...1.6)
            )
        }
        spread = false
        opacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { spread = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { opacity = 0 }
    }
}
