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
    static var isEnabled: Bool = true

    static func click() {
        guard isEnabled else { return }
        NSSound(named: "Tink")?.play()
    }
    static func tick() {
        guard isEnabled else { return }
        let sound = NSSound(named: "Pop")
        sound?.volume = 0.25
        sound?.play()
    }
}

struct KeyboardFocusHighlightModifier: ViewModifier {
    let isFocused: Bool
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocused ? Color.blue : (isSelected ? Color.orange : Color.clear),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: isSelected ? [6, 4] : [])
                    )
                    .shadow(color: isFocused ? Color.blue.opacity(0.8) : (isSelected ? Color.orange.opacity(0.8) : Color.clear), radius: 6)
            )
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

// MARK: - Hotkey Legend

/// Small, muted strip of local keyboard shortcuts pinned to the bottom of a game's
/// window — pinned outside the scaled board area (not inside boardBaseHeight-style
/// content) so it never needs the per-game min-window-size math to account for it.
struct HotkeyLegendView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.display(11, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
    }
}

// MARK: - Themed Editor Button

/// Pill-shaped button matching the main toolbar's look, for use in modal editors like
/// the custom card-art/card-back panels so they read as part of the same app rather
/// than generic native dialogs. Defaults to `.primary` since these editors sit on an
/// adaptive (light/dark) window background, not the game board's fixed dark felt.
struct ThemedEditorButton: View {
    let title: String
    var tint: Color = .primary
    var shortcut: KeyboardShortcut? = nil
    let action: () -> Void

    var body: some View {
        Group {
            if let shortcut {
                button.keyboardShortcut(shortcut)
            } else {
                button
            }
        }
    }

    private var button: some View {
        Button(action: action) {
            Text(title)
                .font(.display(14))
                .foregroundColor(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tint.opacity(0.15))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(tint, lineWidth: 1))
        }
        .buttonStyle(HoverToolbarButtonStyle())
        .focusable(false)
    }
}

func themedEditorButton(_ title: String, tint: Color = .primary, shortcut: KeyboardShortcut? = nil, action: @escaping () -> Void) -> some View {
    ThemedEditorButton(title: title, tint: tint, shortcut: shortcut, action: action)
}

// MARK: - Display Font

extension Font {
    /// Condensed bold display font for headings, labels, and UI chrome.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
            .width(.condensed)
    }
}
