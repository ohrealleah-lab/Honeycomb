import SwiftUI
import AppKit

// MARK: - Press Button Style

struct PressButtonStyle: ButtonStyle {
    var playClick: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && playClick { UISound.click() }
            }
    }
}

// MARK: - Hover Button Style (adds tick on hover)

struct HoverToolbarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : (isHovered ? 1.04 : 1.0))
            .brightness(configuration.isPressed ? -0.08 : (isHovered ? 0.06 : 0))
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                if hovering && !isHovered { UISound.tick() }
                isHovered = hovering
            }
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UISound.click() }
            }
    }
}

// MARK: - UI Sound

enum UISound {
    static func click() {
        NSSound(named: "Tink")?.play()
    }
    static func tick() {
        let sound = NSSound(named: "Pop")
        sound?.volume = 0.25
        sound?.play()
    }
}

// MARK: - Felt Vignette

struct FeltVignetteView: View {
    var intensity: Double = 0.45
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.black.opacity(intensity)
            ]),
            center: .center,
            startRadius: 100,
            endRadius: 680
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Win Particle Burst

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

    private let cx: CGFloat = 300
    private let cy: CGFloat = 90

    var body: some View {
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
                speed: CGFloat.random(in: 70...170),
                color: colors.randomElement()!,
                scale: CGFloat.random(in: 0.7...1.6)
            )
        }
        spread  = false
        opacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            spread = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            opacity = 0
        }
    }
}

// MARK: - Display Font

extension Font {
    /// Condensed bold display font for headings, labels, and UI chrome.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
            .width(.condensed)
    }
}
