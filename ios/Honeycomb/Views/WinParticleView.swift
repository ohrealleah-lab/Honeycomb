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

    enum ParticleShape {
        case rectangle
        case circle
        case thinRibbon
        case star
    }

    struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let speed: CGFloat
        let color: Color
        let scale: CGFloat
        let shape: ParticleShape
        let blur: CGFloat
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
                    
                    Group {
                        switch p.shape {
                        case .rectangle:
                            RoundedRectangle(cornerRadius: 2)
                                .fill(p.color)
                                .frame(width: 7 * p.scale, height: 3 * p.scale)
                        case .circle:
                            Circle()
                                .fill(p.color)
                                .frame(width: 5 * p.scale, height: 5 * p.scale)
                        case .thinRibbon:
                            RoundedRectangle(cornerRadius: 1)
                                .fill(p.color)
                                .frame(width: 9 * p.scale, height: 2 * p.scale)
                        case .star:
                            Image(systemName: "star.fill")
                                .resizable()
                                .foregroundColor(p.color)
                                .frame(width: 6 * p.scale, height: 6 * p.scale)
                        }
                    }
                    .rotationEffect(.degrees(p.angle))
                    .position(x: tx, y: ty)
                    .blur(radius: p.blur)
                    .animation(.easeOut(duration: 0.66), value: spread)
                }
            }
        }
        .opacity(opacity)
        // Same burst mechanic as always (radial fly-out + fade), just retimed —
        // scaled ~1.47x from the original 0.05/0.45/0.3/0.35 timings so the whole
        // burst lasts ~1.4s, matching Windows' WinParticleSystem duration (and mac's
        // matching retime in GameUIStyles.swift).
        .animation(.easeIn(duration: 0.52).delay(0.44), value: opacity)
        .onChange(of: active) { _, on in
            if on { burst() }
        }
        .allowsHitTesting(false)
    }

    private func burst() {
        let count = 72
        particles = (0..<count).map { i in
            let isBackground = Bool.random()
            let scale = CGFloat.random(in: 0.7...1.6) * (isBackground ? 0.7 : 1.0)
            let blur: CGFloat = isBackground ? CGFloat.random(in: 0.5...1.5) : 0
            let shape: ParticleShape = [.rectangle, .rectangle, .circle, .thinRibbon, .star].randomElement()!
            
            return Particle(
                angle: Double(i) / Double(count) * 360,
                // Smaller than mac's 70...170 — this overlays a compact card row, not
                // a full desktop window, so particles that travel too far read as
                // flying off the edge of the visible area instead of a contained burst.
                speed: CGFloat.random(in: 50...120) * (isBackground ? 0.8 : 1.0),
                color: colors.randomElement()!,
                scale: scale,
                shape: shape,
                blur: blur
            )
        }
        spread = false
        opacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) { spread = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) { opacity = 0 }
    }
}
