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
        // Matches mac's Font.display(14, weight: .black) exactly — mac's helper adds
        // .width(.condensed) on top of the same size/weight, which iOS's plain
        // .system(size:weight:) was missing, making iOS button labels read visibly
        // wider/looser than mac's at the same size.
        .font(.system(size: 14, weight: .black, design: .default).width(.condensed))
        .foregroundColor(disabled ? textColor.opacity(0.4) : textColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // No .frame(maxWidth: .infinity) — matches mac's casinoButton, which sizes to
        // its own content rather than stretching to fill its row. The row itself then
        // reads as one natural-width control cluster centered under the cards (its
        // parent VStack's default center alignment), same as mac, instead of a full-
        // width bar with buttons spread apart by Spacers.
        .background(disabled ? Color.gray.opacity(0.3) : color)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
    .buttonStyle(CasinoButtonPressStyle())
    .disabled(disabled)
    .accessibilityLabel(label)
}
