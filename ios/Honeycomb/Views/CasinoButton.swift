import SwiftUI

// Shared button styling for Blackjack/VideoPoker's touch action rows (Hit/Stand/Double/
// Split, Deal/Draw, chip/bet controls, Rebuy) — mirrors mac's casinoButton exactly (see
// mac/src/Blackjack/Views/BlackjackView.swift and mac/src/VideoPoker/Views/
// VideoPokerView.swift) so the two platforms read as the same game, not a system-default
// button bar next to a colored, bordered one.
struct CasinoButtonPressStyle: ButtonStyle {
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

func casinoButton(
    _ label: String,
    systemImage: String? = nil,
    color: Color,
    textColor: Color = .white,
    disabled: Bool = false,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Group {
            if let systemImage {
                Label(label, systemImage: systemImage)
            } else {
                Text(label)
            }
        }
        .font(.system(size: 14, weight: .black))
        .foregroundColor(disabled ? textColor.opacity(0.4) : textColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(disabled ? Color.gray.opacity(0.3) : color)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
    .buttonStyle(CasinoButtonPressStyle())
    .disabled(disabled)
    .accessibilityLabel(label)
}
