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

    private var outlineColor: Color {
        customColors.isEnabled ? customColors.outlineColor : Color.black.opacity(0.85)
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

    // Whether this card is showing a user-imported custom face art image.
    private var customFaceArtImage: (entry: IOSCustomFaceArtManager.Entry, image: UIImage)? {
        guard let slot = FaceCardSlot.slot(rank: card.rank, suit: card.suit),
              let entry = IOSCustomFaceArtManager.shared.enabledEntry(for: slot),
              let image = IOSCustomFaceArtManager.shared.image(for: entry) else { return nil }
        return (entry, image)
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
                if let art = customFaceArtImage {
                    // Inset well clear of the corner rank/suit index rather than relying on
                    // z-order — the corner index (padded 6% from the edge, sized ~12% of
                    // card width for the suit icon, ~29% of card height once the rank text
                    // above it is included) previously overlapped a centered 70%-of-card art
                    // window by several percent of the card's width/height. That's a small
                    // fraction of the *card*, but a large fraction of the tiny corner icon
                    // itself, which is why a busy photo visibly ate into the suit glyph.
                    // These fractions keep the art's bounding box outside that zone on all
                    // four corners (both index copies), with a bit of safety margin since a
                    // fresh contrast/backing attempt at the corner (rather than shrinking
                    // the art) made the overlap look worse, not better — a visible white box
                    // seam instead of a slightly-crowded corner.
                    ImageCropDisplay(image: art.image, entry: art.entry)
                        .frame(width: width * 0.56, height: height * 0.42)
                } else if card.rank >= 11 || card.rank == 1 {
                    // Face cards (and Ace) show just the rank letter, centered — mac uses
                    // Apple Chancery here, but that font isn't actually part of iOS's
                    // bundled font catalog (confirmed live: it silently falls back to the
                    // system font instead of erroring). Snell Roundhand was tried first as
                    // the closest same-spirit substitute, but its capital Q reads as "2"
                    // (confirmed by rendering the actual font file, not just eyeballing it
                    // on a card) — Savoye LET is another genuine iOS-bundled script font
                    // whose Q is an unambiguous loop-and-tail, so it replaces Snell
                    // Roundhand here entirely.
                    //
                    // The offset below isn't decorative — Savoye LET's declared line-height
                    // box is much taller than its actual glyph ink (lots of unused
                    // descender space baked into the font), so centering the raw Text
                    // (which centers that whole box) visibly pushes every letter up and
                    // left of the card's true center. Value found empirically: rendered
                    // live in the simulator with a marker at the card's true center,
                    // measured the pixel gap to each glyph's ink centroid across multiple
                    // ranks (J/Q/K/A), and converged on this offset — not a guess.
                    Text(rankText)
                        .font(.custom("SavoyeLetPlain", size: width * 0.56))
                        .foregroundStyle(suitColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .offset(x: width * 0.01, y: width * 0.15)
                } else {
                    // Numbered cards (2-10): mac's CardCenterSuitView lays out rank-many
                    // small pips in the traditional card pattern (Self.suitPositions,
                    // ported below) rather than one big centered icon — this used to just
                    // show a single suit.symbol at width*0.4, which read as oversized next
                    // to the corner index (a 3.3x center:corner ratio vs mac's ~2.3x single-
                    // pip:corner ratio, on top of mac showing several small pips instead of
                    // one large one at all). Every position/size below is mac's own literal
                    // point value divided by 128 (mac's base card width, the reference
                    // frame CardView.swift's pip layout and font size 32 are authored
                    // against) so it carries over as a fraction of iOS's `width` unchanged.
                    // Pip size uses a smaller fraction than mac's literal 32/128 = 0.25:
                    // mac renders each pip as `Text(suit.symbol)` at that font size, whose
                    // glyph ink sits well inside its em-box, while `Image(systemName:)
                    // .resizable()` fills its given frame edge-to-edge — the same frame
                    // width reads visibly larger with the Image approach. The tightest
                    // constraint isn't the horizontal gap between columns (52pt apart in
                    // mac's space, plenty of room) but the vertical gap between the two
                    // inner rows on 9s/10s (only 28pt apart, ≈0.22 of card width) — 0.22
                    // was still tall enough for those pips to touch top-to-bottom, so
                    // dropped further to leave real clearance under that spacing.
                    ForEach(Array((Self.suitPositions[card.rank] ?? []).enumerated()), id: \.offset) { _, pos in
                        Image(systemName: suitSymbol)
                            .resizable().aspectRatio(contentMode: .fit)
                            .frame(width: width * 0.16)
                            .foregroundStyle(suitColor)
                            .rotationEffect(.degrees(pos.isUpsideDown ? 180 : 0))
                            .position(x: width / 2 + pos.x / 128 * width,
                                      y: height / 2 + pos.y / 128 * width)
                    }
                }

                cornerIndex
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(width * 0.06)
                cornerIndex
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(width * 0.06)
            } else {
                HoneycombSimpleCardBack()
            }
        }
        .frame(width: width, height: height)
        // A ZStack doesn't clip its children by default — without this, an oversized
        // face-card letter (or any other content that overflows its nominal size) bleeds
        // past the card's rounded-rect edge into whatever's behind/beside it instead of
        // just being cut off, which in a tight tableau stack reads as a misshapen or
        // oversized card rather than clipped text.
        .clipShape(RoundedRectangle(cornerRadius: width * 0.07))
        // Matches mac's CardView outline (`Color.black.opacity(0.85)` at lineWidth 0.75
        // by default, or the user's custom outline color when enabled), applied
        // unconditionally like mac's — not just when face up. Drawn as an overlay (on
        // top of everything, not as a ZStack sibling underneath the content) because a
        // face-down card's HoneycombSimpleCardBack fills the frame edge-to-edge and was
        // completely burying the stroke drawn beneath it — face-up content is inset/
        // centered and never had this problem, which is why only face-down cards showed
        // a barely-visible border. A face-down card in a deep tableau stack (Klondike's
        // stock, Spider's initial deal) needs the same edge definition an overlapping
        // face-up card does, or adjacent card boundaries disappear into each other.
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.07)
                .stroke(outlineColor, lineWidth: 0.75)
        )
        // Matches mac's CardView exactly — in a tightly overlapping tableau, this subtle
        // shadow (not just the thin 0.75pt stroke above) is what actually separates
        // adjacent card edges visually; without it stacked cards read as one flat block.
        .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
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

    // Ported directly from mac's CardView.swift (CardCenterSuitView.suitPositions) —
    // every x/y here is mac's own literal point value, authored against mac's 128pt-
    // wide base card, and divided by 128 at the call site above rather than re-derived,
    // so both platforms lay out the same rank the same way.
    private struct SuitPosition {
        let x: CGFloat
        let y: CGFloat
        let isUpsideDown: Bool
    }

    private static let suitPositions: [Int: [SuitPosition]] = [
        2: [SuitPosition(x: 0, y: -42, isUpsideDown: false), SuitPosition(x: 0, y: 42, isUpsideDown: true)],
        3: [SuitPosition(x: 0, y: -42, isUpsideDown: false), SuitPosition(x: 0, y: 0, isUpsideDown: false), SuitPosition(x: 0, y: 42, isUpsideDown: true)],
        4: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true)],
        5: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: 0, y: 0, isUpsideDown: false), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true)],
        6: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: -26, y: 0, isUpsideDown: false), SuitPosition(x: 26, y: 0, isUpsideDown: false), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true)],
        7: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: -26, y: 0, isUpsideDown: false), SuitPosition(x: 26, y: 0, isUpsideDown: false), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true), SuitPosition(x: 0, y: -21, isUpsideDown: false)],
        8: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: -26, y: 0, isUpsideDown: false), SuitPosition(x: 26, y: 0, isUpsideDown: false), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true), SuitPosition(x: 0, y: -21, isUpsideDown: false), SuitPosition(x: 0, y: 21, isUpsideDown: true)],
        9: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: -26, y: -14, isUpsideDown: false), SuitPosition(x: 26, y: -14, isUpsideDown: false), SuitPosition(x: -26, y: 14, isUpsideDown: true), SuitPosition(x: 26, y: 14, isUpsideDown: true), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true), SuitPosition(x: 0, y: 0, isUpsideDown: false)],
        10: [SuitPosition(x: -26, y: -42, isUpsideDown: false), SuitPosition(x: 26, y: -42, isUpsideDown: false), SuitPosition(x: -26, y: -14, isUpsideDown: false), SuitPosition(x: 26, y: -14, isUpsideDown: false), SuitPosition(x: -26, y: 14, isUpsideDown: true), SuitPosition(x: 26, y: 14, isUpsideDown: true), SuitPosition(x: -26, y: 42, isUpsideDown: true), SuitPosition(x: 26, y: 42, isUpsideDown: true), SuitPosition(x: 0, y: -27, isUpsideDown: false), SuitPosition(x: 0, y: 27, isUpsideDown: true)]
    ]
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
