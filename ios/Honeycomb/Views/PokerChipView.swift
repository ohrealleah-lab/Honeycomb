import SwiftUI

/// Pure-vector casino chip button — no image assets. Used by Blackjack's iPad/iPhone
/// landscape bet row (see BlackjackTouchView.bettingGridLandscape) in place of the
/// rectangular casinoButton chips portrait still uses; the two are visually distinct
/// by design, matching the request for a dedicated chip look on the landscape tray.
struct PokerChipView: View {
    let label: String
    let baseColor: Color
    let stripeColor: Color
    let textColor: Color
    var diameter: CGFloat = 46
    let action: () -> Void

    // Real casino chips have a fixed number of edge marks regardless of chip size — a
    // dashed circular stroke instead produces however many dash/gap segments happen to
    // fit the circumference at a given diameter (not a fixed count, and rarely a clean
    // divisor of it, so the pattern visibly seams where it wraps back to the start).
    // Six explicit marks, placed by rotating one shape around the center, always
    // renders exactly six, evenly spaced, at any diameter.
    private let edgeMarkCount = 6

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [baseColor.opacity(0.92), baseColor],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter / 2
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)

                ForEach(0..<edgeMarkCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: diameter * 0.02)
                        .fill(stripeColor)
                        .frame(width: diameter * 0.10, height: diameter * 0.16)
                        .offset(y: -diameter * 0.40)
                        .rotationEffect(.degrees(Double(i) / Double(edgeMarkCount) * 360))
                }

                Circle()
                    .fill(baseColor)
                    .frame(width: diameter * 0.62, height: diameter * 0.62)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.25), lineWidth: 1)
                    )

                Text(label)
                    .font(.system(size: diameter * 0.32, weight: .black, design: .rounded))
                    .foregroundStyle(textColor)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(PokerChipButtonStyle())
        .accessibilityLabel(label)
    }
}

struct PokerChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UISound.click() }
            }
    }
}
