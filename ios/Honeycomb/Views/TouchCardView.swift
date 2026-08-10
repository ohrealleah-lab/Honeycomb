import SwiftUI

/// Procedural standard playing card for the iOS games that use `Card` (Klondike,
/// BeeCell, Spider, Video Poker, Blackjack). Draws rank/suit with text and SF Symbols
/// until the mac image pipeline (face art PNGs, custom card backs) is ported.
struct TouchCardView: View {
    let card: Card
    let width: CGFloat

    var height: CGFloat { width * CardDimensions.aspectRatio }

    @Environment(\.activeCustomCardColors) private var customColors: CustomCardColorGroup

    private var isRed: Bool { card.suit == .hearts || card.suit == .diamonds }

    private var suitColor: Color {
        if customColors.isEnabled {
            return isRed ? customColors.redSuitColor : customColors.blackSuitColor
        }
        return isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    private var faceColor: Color {
        customColors.isEnabled ? customColors.backgroundColor : .white
    }

    private var rankText: String {
        switch card.rank {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(card.rank)"
        }
    }

    private var suitSymbol: String {
        switch card.suit {
        case .spades: return "suit.spade.fill"
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        }
    }

    var body: some View {
        ZStack {
            // White (or custom-color) backing behind BOTH faces, matching mac's
            // CardView (`.background(... : Color.white)` applied outside its own
            // faceUp/faceDown branch) — without this, any card back or face-art image
            // with transparency (e.g. the Vulpera theme's priest.png) let whatever's
            // behind the card bleed through instead of showing a solid card.
            RoundedRectangle(cornerRadius: width * 0.07)
                .fill(faceColor)

            if card.faceUp {
                // Matches mac's CardView outline (`Color.black.opacity(0.85)` at
                // lineWidth 0.75) — this was opacity 0.25 before, which nearly
                // disappeared between overlapping tableau cards at the smaller sizes
                // Klondike/Spider/BeeCell use on iPhone portrait.
                RoundedRectangle(cornerRadius: width * 0.07)
                    .stroke(Color.black.opacity(0.85), lineWidth: 0.75)

                cornerIndex
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(width * 0.06)
                cornerIndex
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(width * 0.06)

                if let slot = FaceCardSlot.slot(rank: card.rank, suit: card.suit),
                   let entry = IOSCustomFaceArtManager.shared.enabledEntry(for: slot),
                   let image = IOSCustomFaceArtManager.shared.image(for: entry) {
                    ImageCropDisplay(image: image, entry: entry)
                        .frame(width: width * 0.7, height: height * 0.7)
                } else if card.rank >= 11 {
                    // Face cards: large letter over the suit, like the mac dark-mode letters.
                    VStack(spacing: height * 0.02) {
                        Text(rankText)
                            .font(.system(size: width * 0.42, weight: .black, design: .serif))
                        Image(systemName: suitSymbol)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: width * 0.22)
                    }
                    .foregroundStyle(suitColor)
                } else {
                    Image(systemName: suitSymbol)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(width: width * 0.4)
                        .foregroundStyle(suitColor)
                }
            } else {
                HoneycombSimpleCardBack()
            }
        }
        .frame(width: width, height: height)
    }

    private var cornerIndex: some View {
        VStack(spacing: 1) {
            Text(rankText)
                .font(.system(size: width * 0.17, weight: .bold, design: .monospaced))
            Image(systemName: suitSymbol)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: width * 0.12)
        }
        .foregroundStyle(suitColor)
        .fixedSize()
    }
}

/// Pulsing yellow hint outline shared by the iOS game views.
struct TouchHintHighlight: ViewModifier {
    var isHighlighted: Bool
    @State private var phase: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .modifier(TouchHintAnimatable(isHighlighted: isHighlighted, phase: phase))
            .onChange(of: isHighlighted) {
                if isHighlighted {
                    phase = 0.0
                    withAnimation(.linear(duration: 1.8)) {
                        phase = 1.0
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.1)) {
                        phase = 0.0
                    }
                }
            }
    }
}

struct TouchHintAnimatable: AnimatableModifier {
    @Environment(AppCoordinator.self) private var coordinator
    var isHighlighted: Bool
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let opacity = isHighlighted ? (1 - cos(phase * .pi * 4)) / 2 : 0.0
        let highlightColor = coordinator.customCardColors.hintHighlightColor

        return content
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(highlightColor, lineWidth: 4)
                        .shadow(color: highlightColor, radius: 4)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(highlightColor, lineWidth: 4)
                        .shadow(color: highlightColor, radius: 4)
                }
                .opacity(opacity)
            )
    }
}
