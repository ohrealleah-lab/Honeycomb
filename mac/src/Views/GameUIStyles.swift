import SwiftUI
import AppKit

// MARK: - Width Measurement

/// Publishes the width of whatever it's attached to, for toolbars/action-button rows that
/// need to know their own available width to decide when to swap text labels for
/// icon-only buttons. Same GeometryReader-in-background idiom already used elsewhere in
/// this codebase for pile-frame tracking.
private struct MeasuredWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Reports this view's rendered width into `width` on every layout pass.
    func measureWidth(into width: Binding<CGFloat>) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(key: MeasuredWidthKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(MeasuredWidthKey.self) { width.wrappedValue = $0 }
    }
}

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
    static var isHeadlessMode: Bool = false

    static func click() {
        guard isEnabled, !isHeadlessMode else { return }
        NSSound(named: "Tink")?.play()
    }
    static func tick() {
        guard isEnabled, !isHeadlessMode else { return }
        let sound = NSSound(named: "Pop")
        sound?.volume = 0.25
        sound?.play()
    }

    // Shared game-effect player (shuffle/snap/victory/etc.) used by every game's ViewModel.
    // `respectHeadlessMode` defaults to false to preserve each game's pre-existing behavior —
    // only BlackjackViewModel checked isHeadlessMode before this was consolidated.
    static func play(named name: String, enabled: Bool, respectHeadlessMode: Bool = false) {
        guard enabled, !(respectHeadlessMode && isHeadlessMode) else { return }

        if let soundURL = Bundle.main.url(forResource: name, withExtension: "aiff"),
           let sound = NSSound(contentsOf: soundURL, byReference: true) {
            sound.play()
            return
        }

        let systemName: String
        switch name {
        case "shuffle": systemName = "Blow"
        case "snap": systemName = "Tink"
        case "victory": systemName = "Hero"
        default: systemName = name
        }

        NSSound(named: NSSound.Name(systemName))?.play()
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

/// Pill-shaped toolbar button used by Blackjack/VideoPoker's own toolbars (white text
/// on the felt, dimmed when `disabled`). Distinct from `ThemedEditorButton` below,
/// which targets modal editors sitting on an adaptive light/dark window background.
struct GameToolbarButton: View {
    let label: String
    var systemImage: String? = nil
    var isCompact: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isCompact, let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Text(label)
                        .font(.display(16))
                        .lineLimit(1)
                }
            }
            .foregroundColor(disabled ? .white.opacity(0.4) : .white)
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(disabled ? Color.white.opacity(0.4) : Color.white, lineWidth: 1))
        }
        .buttonStyle(HoverToolbarButtonStyle())
        .disabled(disabled)
        .focusable(false)
        .accessibilityLabel(label)
    }
}

/// The toolbar's game-picker trigger + popover, shared by all 5 games so their pickers
/// can't visually drift from each other. A plain Button (not SwiftUI's `Menu`) — `Menu`
/// is backed by AppKit's NSPopUpButton, which under width pressure can render its
/// truncated title using system default styling instead of respecting this label's
/// custom colors (first surfaced on Klondike, whose toolbar sits closest to the width
/// floor of all 5 games). A plain Button never has that failure mode.
struct GameSelectionDropdown: View {
    @Bindable var coordinator: AppCoordinator

    // Solitaire games deal a fresh hand on entry; Video Poker/Blackjack have no
    // equivalent "start a new game" action to fire when switching to them.
    private static let gamesThatStartNewGame: Set<GameMode> = [.klondike, .beecell, .spider]

    @State private var isShowingMenu = false

    var body: some View {
        Button(action: { isShowingMenu = true }) {
            HStack(spacing: 4) {
                Text("Game Selection")
                    .font(.display(16))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.15))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
        }
        .buttonStyle(HoverToolbarButtonStyle())
        .focusable(false)
        .popover(isPresented: $isShowingMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(GameMode.allCases) { mode in
                    row(for: mode)
                }
            }
            .padding(6)
            .frame(width: 190)
        }
    }

    private func row(for mode: GameMode) -> some View {
        let isActive = coordinator.gameMode == mode
        return Button(action: {
            isShowingMenu = false
            guard coordinator.gameMode != mode else { return }
            coordinator.gameMode = mode
            if Self.gamesThatStartNewGame.contains(mode) { coordinator.startNewGame() }
        }) {
            HStack(spacing: 8) {
                Text(mode.displayName)
                    .font(.display(16, weight: isActive ? .bold : .regular))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

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

/// A button style that disables the default macOS hover effect and click dimming.
public struct NoHoverButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
