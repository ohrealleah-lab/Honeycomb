import SwiftUI

/// Procedural standard playing card for the iOS games that use `Card` (Klondike,
/// BeeCell, Spider, Video Poker, Blackjack). Draws rank/suit with text and SF Symbols
/// until the mac image pipeline (face art PNGs, custom card backs) is ported.
struct TouchCardView: View {
    let card: Card
    let width: CGFloat

    var height: CGFloat { width * 181.0 / 128.0 }

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
            if card.faceUp {
                RoundedRectangle(cornerRadius: width * 0.07)
                    .fill(faceColor)
                RoundedRectangle(cornerRadius: width * 0.07)
                    .stroke(Color.black.opacity(0.25), lineWidth: 1)

                cornerIndex
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(width * 0.06)
                cornerIndex
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(width * 0.06)

                if card.rank >= 11 {
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
    let isHighlighted: Bool
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? Color.yellow : Color.clear, lineWidth: 4)
                    .shadow(color: isHighlighted ? .yellow : .clear, radius: 4)
            )
            .animation(isHighlighted ? .easeInOut(duration: 0.5).repeatCount(4, autoreverses: true) : nil,
                       value: isHighlighted)
    }
}
