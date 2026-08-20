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

    // Face cards (and Ace) show just the rank letter, centered — mac uses Apple
    // Chancery here, but that font isn't actually part of iOS's bundled font catalog
    // (confirmed live: it silently falls back to the system font instead of erroring).
    // Went through Snell Roundhand (capital Q reads as "2" — confirmed by rendering the
    // actual font file, not just eyeballing it on a card), Savoye LET, and
    // Noteworthy-Bold (both genuine iOS system fonts, both read as hard to read overall
    // at card size) before landing here. Marck Script is not a system font — bundled
    // and registered at launch in HoneycombiOSApp.swift, OFL-licensed from Google
    // Fonts, PostScript name "MarckScript-Regular" (it only ships as a single static
    // weight, no Light/Bold variants to choose between).
    //
    // Rendered as raw vector geometry (RankLetterPath below) instead of a SwiftUI
    // Text — Marck Script's cursive swashes on K/J/A overhang past the glyph's own
    // typographic box, and *every* attempt to keep that overhang from getting clipped
    // while still going through Text failed: moving it to an unclipped ZStack sibling
    // (escaping the card's own .clipShape), then .fixedSize() (escaping the
    // lineLimit/minimumScaleFactor fit-to-box behavior), then an explicit oversized
    // frame (which instead inflated the whole card's reported layout size and broke
    // the tableau). Confirmed by rendering the letter huge and green each time — it
    // kept hard-clipping on exactly the side each glyph's own overhang predicts, well
    // inside the card's visible bounds, meaning something in Text's own rendering
    // pipeline was clipping to a box narrower than the true ink regardless of any of
    // the SwiftUI-level fixes above. A Path has no such internal box — it draws
    // exactly the geometry it's given — so this bypasses Text/CoreText entirely for
    // these four letters.
    @ViewBuilder
    private var rankLetterOverlay: some View {
        if card.faceUp, customFaceArtImage == nil, card.rank >= 11 || card.rank == 1 {
            RankLetterPath(rankText: rankText, fontSize: width * 0.56)
                .fill(suitColor)
                .frame(width: width, height: height)
                .allowsHitTesting(false)
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
        // rankLetterOverlay is a sibling in THIS ZStack, not chained onto cardFace via
        // .overlay — SwiftUI's .clipShape turned out to clip .overlay content applied
        // later in the same modifier chain too (confirmed by literally rendering the
        // letter oversized and green: it hard-cut at the card edge with zero bleed onto
        // the felt behind it, instead of spilling past it). A true ZStack sibling,
        // outside cardFace's own clipped modifier chain entirely, isn't subject to that.
        ZStack {
            cardFace
            rankLetterOverlay
        }
        .overlay(
            RoundedRectangle(cornerRadius: width * (10.0 / 128.0))
                .stroke(outlineColor, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
    }

    private var cardFace: some View {
        ZStack {
            // White (or custom-color) backing behind BOTH faces, matching mac's
            // CardView (`.background(... : Color.white)` applied outside its own
            // faceUp/faceDown branch) — without this, any card back or face-art image
            // with transparency (e.g. the Vulpera theme's priest.png) let whatever's
            // behind the card bleed through instead of showing a solid card.
            RoundedRectangle(cornerRadius: width * (10.0 / 128.0))
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
                    // The rank letter itself renders in rankLetterOverlay (see below,
                    // applied after .clipShape) rather than here — kept as an empty
                    // branch just so this if/else-if/else still reads as "what does this
                    // rank show", matching the branches beside it.
                    Color.clear
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
        .clipShape(RoundedRectangle(cornerRadius: width * (10.0 / 128.0)))
    }

    private var cornerIndex: some View {
        // Matches mac's CardFrontView corner index exactly — an HStack (rank, then a
        // smaller suit symbol beside it), not stacked vertically. Was a VStack with the
        // suit below the rank, which reads as a completely different card layout next
        // to mac's side-by-side rank+suit.
        HStack(alignment: .center, spacing: 1) {
            Text(rankText)
                .font(.system(size: width * 0.17, weight: .bold, design: .monospaced))
            Image(systemName: suitSymbol)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: width * 0.1)
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

// Raw vector outline for the big center rank letter on face cards/Aces (see
// TouchCardView.rankLetterOverlay for why this exists instead of a SwiftUI Text).
// Path data extracted directly from MarckScript-Regular.ttf's glyf table via
// fontTools (each on/off-curve point converted to move/line/quadCurve commands),
// normalized to fractions of the font's 1000-unit em square with Y already flipped
// to SwiftUI's Y-down convention. ink bounds (also read from the same font, via
// fontTools' BoundsPen) are each glyph's true painted extent — used to center the
// ink itself at the shape's frame center, not the glyph's typographic box, which is
// nowhere near the ink's actual center for a script font like this one.
struct RankLetterPath: Shape {
    let rankText: String
    let fontSize: CGFloat

    // Where to center each glyph — the ink's true area-weighted centroid, not its
    // bounding-box midpoint. A script "A"'s long thin entry swoop reaches far to the
    // left/down but covers very little actual area, so centering by bounding box (as
    // this used to) let that thin swoop drag the *box* center away from where the
    // eye actually reads the letter's center, leaving the dense body looking
    // off-center. Computed by rasterizing each glyph and averaging the ink pixel
    // coordinates (numpy on a PIL render of the same .ttf), not eyeballed.
    private var inkCenter: CGPoint {
        switch rankText {
        case "A": return CGPoint(x: 0.4150, y: -0.2380)
        case "J": return CGPoint(x: 0.2885, y: -0.1900)
        case "Q": return CGPoint(x: 0.3243, y: -0.2613)
        case "K": return CGPoint(x: 0.3955, y: -0.2677)
        default: return .zero
        }
    }

    // Marck Script draws Q noticeably more compact than A/J/K — its ink is only
    // ~666 units tall (of the font's 1000-unit em) vs. J's ~938, A's ~767, K's ~769 —
    // so at one shared fontSize it reads visibly smaller next to the other three.
    // Scales Q up 25% from its original size; A/K need no correction.
    private var sizeScale: CGFloat {
        rankText == "Q" ? 1.1875 : 1.0
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch rankText {
        case "A":
            path.move(to: CGPoint(x: 0.74600, y: -0.29800))
            path.addLine(to: CGPoint(x: 0.74100, y: -0.23800))
            path.addQuadCurve(to: CGPoint(x: 0.69150, y: -0.24000), control: CGPoint(x: 0.71800, y: -0.24000))
            path.addQuadCurve(to: CGPoint(x: 0.64700, y: -0.23900), control: CGPoint(x: 0.66500, y: -0.24000))
            path.addQuadCurve(to: CGPoint(x: 0.62900, y: 0.00000), control: CGPoint(x: 0.63300, y: -0.12900))
            path.addLine(to: CGPoint(x: 0.55900, y: 0.00000))
            path.addQuadCurve(to: CGPoint(x: 0.55300, y: -0.06900), control: CGPoint(x: 0.55300, y: -0.02600))
            path.addQuadCurve(to: CGPoint(x: 0.55550, y: -0.14350), control: CGPoint(x: 0.55300, y: -0.11200))
            path.addQuadCurve(to: CGPoint(x: 0.56200, y: -0.20600), control: CGPoint(x: 0.55800, y: -0.17500))
            path.addQuadCurve(to: CGPoint(x: 0.56600, y: -0.24200), control: CGPoint(x: 0.56600, y: -0.23700))
            path.addQuadCurve(to: CGPoint(x: 0.50000, y: -0.24300), control: CGPoint(x: 0.55200, y: -0.24300))
            path.addQuadCurve(to: CGPoint(x: 0.42800, y: -0.24100), control: CGPoint(x: 0.44800, y: -0.24300))
            path.addQuadCurve(to: CGPoint(x: 0.21400, y: -0.00450), control: CGPoint(x: 0.31200, y: -0.08500))
            path.addQuadCurve(to: CGPoint(x: 0.01800, y: 0.07600), control: CGPoint(x: 0.11600, y: 0.07600))
            path.addQuadCurve(to: CGPoint(x: -0.06250, y: 0.04700), control: CGPoint(x: -0.03000, y: 0.07600))
            path.addQuadCurve(to: CGPoint(x: -0.09500, y: -0.03000), control: CGPoint(x: -0.09500, y: 0.01800))
            path.addQuadCurve(to: CGPoint(x: 0.04350, y: -0.19600), control: CGPoint(x: -0.09500, y: -0.12100))
            path.addQuadCurve(to: CGPoint(x: 0.40200, y: -0.29700), control: CGPoint(x: 0.18200, y: -0.27100))
            path.addQuadCurve(to: CGPoint(x: 0.49900, y: -0.42050), control: CGPoint(x: 0.42800, y: -0.33700))
            path.addQuadCurve(to: CGPoint(x: 0.63900, y: -0.56600), control: CGPoint(x: 0.57000, y: -0.50400))
            path.addQuadCurve(to: CGPoint(x: 0.68650, y: -0.66350), control: CGPoint(x: 0.66900, y: -0.63600))
            path.addQuadCurve(to: CGPoint(x: 0.72100, y: -0.69100), control: CGPoint(x: 0.70400, y: -0.69100))
            path.addQuadCurve(to: CGPoint(x: 0.74900, y: -0.67800), control: CGPoint(x: 0.73800, y: -0.69100))
            path.addQuadCurve(to: CGPoint(x: 0.76000, y: -0.64450), control: CGPoint(x: 0.76000, y: -0.66500))
            path.addQuadCurve(to: CGPoint(x: 0.73750, y: -0.58450), control: CGPoint(x: 0.76000, y: -0.62400))
            path.addQuadCurve(to: CGPoint(x: 0.69100, y: -0.46250), control: CGPoint(x: 0.71500, y: -0.54500))
            path.addQuadCurve(to: CGPoint(x: 0.65800, y: -0.30700), control: CGPoint(x: 0.66700, y: -0.38000))
            path.addQuadCurve(to: CGPoint(x: 0.74600, y: -0.29800), control: CGPoint(x: 0.71000, y: -0.30700))
            path.closeSubpath()
            path.move(to: CGPoint(x: 0.23600, y: -0.08900))
            path.addQuadCurve(to: CGPoint(x: 0.36100, y: -0.23900), control: CGPoint(x: 0.31900, y: -0.16800))
            path.addQuadCurve(to: CGPoint(x: 0.10150, y: -0.17600), control: CGPoint(x: 0.19300, y: -0.22900))
            path.addQuadCurve(to: CGPoint(x: 0.01000, y: -0.06300), control: CGPoint(x: 0.01000, y: -0.12300))
            path.addQuadCurve(to: CGPoint(x: 0.02750, y: -0.02200), control: CGPoint(x: 0.01000, y: -0.03700))
            path.addQuadCurve(to: CGPoint(x: 0.07400, y: -0.00700), control: CGPoint(x: 0.04500, y: -0.00700))
            path.addQuadCurve(to: CGPoint(x: 0.23600, y: -0.08900), control: CGPoint(x: 0.15200, y: -0.00700))
            path.closeSubpath()
            path.move(to: CGPoint(x: 0.57800, y: -0.30700))
            path.addQuadCurve(to: CGPoint(x: 0.59650, y: -0.39250), control: CGPoint(x: 0.58500, y: -0.34100))
            path.addQuadCurve(to: CGPoint(x: 0.61000, y: -0.45300), control: CGPoint(x: 0.60800, y: -0.44400))
            path.addQuadCurve(to: CGPoint(x: 0.54300, y: -0.38550), control: CGPoint(x: 0.56200, y: -0.40700))
            path.addQuadCurve(to: CGPoint(x: 0.47600, y: -0.30300), control: CGPoint(x: 0.52400, y: -0.36400))
            path.addQuadCurve(to: CGPoint(x: 0.51750, y: -0.30450), control: CGPoint(x: 0.49300, y: -0.30400))
            path.addQuadCurve(to: CGPoint(x: 0.55800, y: -0.30600), control: CGPoint(x: 0.54200, y: -0.30500))
            path.addQuadCurve(to: CGPoint(x: 0.57800, y: -0.30700), control: CGPoint(x: 0.57400, y: -0.30700))
            path.closeSubpath()
        case "J":
            path.move(to: CGPoint(x: 0.57400, y: -0.62200))
            path.addQuadCurve(to: CGPoint(x: 0.67350, y: -0.61450), control: CGPoint(x: 0.63500, y: -0.62200))
            path.addQuadCurve(to: CGPoint(x: 0.71200, y: -0.58400), control: CGPoint(x: 0.71200, y: -0.60700))
            path.addQuadCurve(to: CGPoint(x: 0.68000, y: -0.54500), control: CGPoint(x: 0.71200, y: -0.56400))
            path.addQuadCurve(to: CGPoint(x: 0.53950, y: -0.38950), control: CGPoint(x: 0.60100, y: -0.49700))
            path.addQuadCurve(to: CGPoint(x: 0.41300, y: -0.07200), control: CGPoint(x: 0.47800, y: -0.28200))
            path.addQuadCurve(to: CGPoint(x: 0.50200, y: -0.06700), control: CGPoint(x: 0.47200, y: -0.07200))
            path.addLine(to: CGPoint(x: 0.49600, y: -0.02700))
            path.addQuadCurve(to: CGPoint(x: 0.44600, y: -0.03200), control: CGPoint(x: 0.46800, y: -0.03200))
            path.addQuadCurve(to: CGPoint(x: 0.39700, y: -0.02700), control: CGPoint(x: 0.42400, y: -0.03200))
            path.addQuadCurve(to: CGPoint(x: 0.33150, y: 0.11100), control: CGPoint(x: 0.36600, y: 0.05800))
            path.addQuadCurve(to: CGPoint(x: 0.24300, y: 0.21000), control: CGPoint(x: 0.29700, y: 0.16400))
            path.addQuadCurve(to: CGPoint(x: 0.12300, y: 0.28600), control: CGPoint(x: 0.18900, y: 0.25600))
            path.addQuadCurve(to: CGPoint(x: 0.01050, y: 0.31600), control: CGPoint(x: 0.05700, y: 0.31600))
            path.addQuadCurve(to: CGPoint(x: -0.06300, y: 0.29050), control: CGPoint(x: -0.03600, y: 0.31600))
            path.addQuadCurve(to: CGPoint(x: -0.09000, y: 0.22300), control: CGPoint(x: -0.09000, y: 0.26500))
            path.addQuadCurve(to: CGPoint(x: -0.03000, y: 0.09600), control: CGPoint(x: -0.09000, y: 0.15900))
            path.addQuadCurve(to: CGPoint(x: 0.12850, y: -0.01000), control: CGPoint(x: 0.03000, y: 0.03300))
            path.addQuadCurve(to: CGPoint(x: 0.33600, y: -0.06400), control: CGPoint(x: 0.22700, y: -0.05300))
            path.addQuadCurve(to: CGPoint(x: 0.36700, y: -0.15900), control: CGPoint(x: 0.33800, y: -0.06800))
            path.addQuadCurve(to: CGPoint(x: 0.47050, y: -0.39750), control: CGPoint(x: 0.41300, y: -0.30900))
            path.addQuadCurve(to: CGPoint(x: 0.60900, y: -0.54400), control: CGPoint(x: 0.52800, y: -0.48600))
            path.addQuadCurve(to: CGPoint(x: 0.56400, y: -0.54600), control: CGPoint(x: 0.59200, y: -0.54600))
            path.addQuadCurve(to: CGPoint(x: 0.28000, y: -0.48300), control: CGPoint(x: 0.39100, y: -0.54600))
            path.addQuadCurve(to: CGPoint(x: 0.16900, y: -0.34100), control: CGPoint(x: 0.16900, y: -0.42000))
            path.addQuadCurve(to: CGPoint(x: 0.19950, y: -0.24650), control: CGPoint(x: 0.16900, y: -0.29000))
            path.addQuadCurve(to: CGPoint(x: 0.28600, y: -0.15700), control: CGPoint(x: 0.23000, y: -0.20300))
            path.addLine(to: CGPoint(x: 0.26200, y: -0.12400))
            path.addQuadCurve(to: CGPoint(x: 0.09900, y: -0.34600), control: CGPoint(x: 0.09900, y: -0.21200))
            path.addQuadCurve(to: CGPoint(x: 0.16550, y: -0.48800), control: CGPoint(x: 0.09900, y: -0.42400))
            path.addQuadCurve(to: CGPoint(x: 0.34050, y: -0.58700), control: CGPoint(x: 0.23200, y: -0.55200))
            path.addQuadCurve(to: CGPoint(x: 0.57400, y: -0.62200), control: CGPoint(x: 0.44900, y: -0.62200))
            path.closeSubpath()
            path.move(to: CGPoint(x: 0.32300, y: -0.02000))
            path.addQuadCurve(to: CGPoint(x: 0.10250, y: 0.05450), control: CGPoint(x: 0.19300, y: -0.00700))
            path.addQuadCurve(to: CGPoint(x: 0.01200, y: 0.19200), control: CGPoint(x: 0.01200, y: 0.11600))
            path.addQuadCurve(to: CGPoint(x: 0.02700, y: 0.23300), control: CGPoint(x: 0.01200, y: 0.21800))
            path.addQuadCurve(to: CGPoint(x: 0.06900, y: 0.24800), control: CGPoint(x: 0.04200, y: 0.24800))
            path.addQuadCurve(to: CGPoint(x: 0.16550, y: 0.21600), control: CGPoint(x: 0.11500, y: 0.24800))
            path.addQuadCurve(to: CGPoint(x: 0.26050, y: 0.12200), control: CGPoint(x: 0.21600, y: 0.18400))
            path.addQuadCurve(to: CGPoint(x: 0.32300, y: -0.02000), control: CGPoint(x: 0.30500, y: 0.06000))
            path.closeSubpath()
        case "Q":
            path.move(to: CGPoint(x: 0.62500, y: -0.11100))
            path.addLine(to: CGPoint(x: 0.68500, y: -0.07700))
            path.addQuadCurve(to: CGPoint(x: 0.53100, y: 0.02700), control: CGPoint(x: 0.61400, y: 0.02700))
            path.addQuadCurve(to: CGPoint(x: 0.43400, y: -0.01200), control: CGPoint(x: 0.47400, y: 0.02700))
            path.addQuadCurve(to: CGPoint(x: 0.35600, y: -0.10600), control: CGPoint(x: 0.40100, y: -0.04400))
            path.addQuadCurve(to: CGPoint(x: 0.15300, y: -0.00100), control: CGPoint(x: 0.24400, y: -0.00100))
            path.addQuadCurve(to: CGPoint(x: 0.06400, y: -0.04000), control: CGPoint(x: 0.09800, y: -0.00100))
            path.addQuadCurve(to: CGPoint(x: 0.03000, y: -0.14400), control: CGPoint(x: 0.03000, y: -0.07900))
            path.addQuadCurve(to: CGPoint(x: 0.06850, y: -0.29600), control: CGPoint(x: 0.03000, y: -0.20900))
            path.addQuadCurve(to: CGPoint(x: 0.16600, y: -0.45850), control: CGPoint(x: 0.10700, y: -0.38300))
            path.addQuadCurve(to: CGPoint(x: 0.30250, y: -0.58650), control: CGPoint(x: 0.22500, y: -0.53400))
            path.addQuadCurve(to: CGPoint(x: 0.45000, y: -0.63900), control: CGPoint(x: 0.38000, y: -0.63900))
            path.addQuadCurve(to: CGPoint(x: 0.53350, y: -0.59950), control: CGPoint(x: 0.50100, y: -0.63900))
            path.addQuadCurve(to: CGPoint(x: 0.56600, y: -0.49050), control: CGPoint(x: 0.56600, y: -0.56000))
            path.addQuadCurve(to: CGPoint(x: 0.51950, y: -0.32700), control: CGPoint(x: 0.56600, y: -0.42100))
            path.addQuadCurve(to: CGPoint(x: 0.39900, y: -0.15000), control: CGPoint(x: 0.47300, y: -0.23300))
            path.addQuadCurve(to: CGPoint(x: 0.43700, y: -0.09850), control: CGPoint(x: 0.42200, y: -0.11800))
            path.addQuadCurve(to: CGPoint(x: 0.47950, y: -0.05700), control: CGPoint(x: 0.45200, y: -0.07900))
            path.addQuadCurve(to: CGPoint(x: 0.53350, y: -0.03500), control: CGPoint(x: 0.50700, y: -0.03500))
            path.addQuadCurve(to: CGPoint(x: 0.59000, y: -0.05950), control: CGPoint(x: 0.56000, y: -0.03500))
            path.addQuadCurve(to: CGPoint(x: 0.62500, y: -0.11100), control: CGPoint(x: 0.62000, y: -0.08400))
            path.closeSubpath()
            path.move(to: CGPoint(x: 0.31400, y: -0.54500))
            path.addQuadCurve(to: CGPoint(x: 0.18850, y: -0.38750), control: CGPoint(x: 0.24300, y: -0.49400))
            path.addQuadCurve(to: CGPoint(x: 0.13400, y: -0.19700), control: CGPoint(x: 0.13400, y: -0.28100))
            path.addQuadCurve(to: CGPoint(x: 0.16000, y: -0.11000), control: CGPoint(x: 0.13400, y: -0.13900))
            path.addQuadCurve(to: CGPoint(x: 0.21300, y: -0.21150), control: CGPoint(x: 0.17900, y: -0.17600))
            path.addQuadCurve(to: CGPoint(x: 0.28800, y: -0.24700), control: CGPoint(x: 0.24700, y: -0.24700))
            path.addQuadCurve(to: CGPoint(x: 0.31200, y: -0.24400), control: CGPoint(x: 0.30300, y: -0.24700))
            path.addQuadCurve(to: CGPoint(x: 0.37000, y: -0.18900), control: CGPoint(x: 0.33400, y: -0.23800))
            path.addQuadCurve(to: CGPoint(x: 0.44250, y: -0.31950), control: CGPoint(x: 0.41400, y: -0.24800))
            path.addQuadCurve(to: CGPoint(x: 0.47100, y: -0.44450), control: CGPoint(x: 0.47100, y: -0.39100))
            path.addQuadCurve(to: CGPoint(x: 0.44850, y: -0.53250), control: CGPoint(x: 0.47100, y: -0.49800))
            path.addQuadCurve(to: CGPoint(x: 0.38600, y: -0.56700), control: CGPoint(x: 0.42600, y: -0.56700))
            path.addQuadCurve(to: CGPoint(x: 0.31400, y: -0.54500), control: CGPoint(x: 0.34600, y: -0.56700))
            path.closeSubpath()
            path.move(to: CGPoint(x: 0.22000, y: -0.08100))
            path.addLine(to: CGPoint(x: 0.22800, y: -0.08200))
            path.addQuadCurve(to: CGPoint(x: 0.32800, y: -0.14400), control: CGPoint(x: 0.27900, y: -0.08700))
            path.addQuadCurve(to: CGPoint(x: 0.27400, y: -0.17800), control: CGPoint(x: 0.30000, y: -0.17800))
            path.addQuadCurve(to: CGPoint(x: 0.25150, y: -0.17500), control: CGPoint(x: 0.26000, y: -0.17800))
            path.addQuadCurve(to: CGPoint(x: 0.22700, y: -0.15000), control: CGPoint(x: 0.24300, y: -0.17200))
            path.addQuadCurve(to: CGPoint(x: 0.19600, y: -0.08500), control: CGPoint(x: 0.21100, y: -0.12800))
            path.addQuadCurve(to: CGPoint(x: 0.22000, y: -0.08100), control: CGPoint(x: 0.21000, y: -0.08100))
            path.closeSubpath()
        case "K":
            path.move(to: CGPoint(x: 0.82400, y: -0.60000))
            path.addLine(to: CGPoint(x: 0.88700, y: -0.56900))
            path.addQuadCurve(to: CGPoint(x: 0.73550, y: -0.38400), control: CGPoint(x: 0.82300, y: -0.46500))
            path.addQuadCurve(to: CGPoint(x: 0.50300, y: -0.22300), control: CGPoint(x: 0.64800, y: -0.30300))
            path.addQuadCurve(to: CGPoint(x: 0.57200, y: 0.00950), control: CGPoint(x: 0.53100, y: -0.07800))
            path.addQuadCurve(to: CGPoint(x: 0.67900, y: 0.10700), control: CGPoint(x: 0.61300, y: 0.09700))
            path.addLine(to: CGPoint(x: 0.67900, y: 0.15300))
            path.addQuadCurve(to: CGPoint(x: 0.65800, y: 0.15400), control: CGPoint(x: 0.67100, y: 0.15400))
            path.addQuadCurve(to: CGPoint(x: 0.52850, y: 0.06100), control: CGPoint(x: 0.59100, y: 0.15400))
            path.addQuadCurve(to: CGPoint(x: 0.41600, y: -0.21400), control: CGPoint(x: 0.46600, y: -0.03200))
            path.addQuadCurve(to: CGPoint(x: 0.28500, y: -0.00050), control: CGPoint(x: 0.37300, y: -0.07900))
            path.addQuadCurve(to: CGPoint(x: 0.10200, y: 0.07800), control: CGPoint(x: 0.19700, y: 0.07800))
            path.addQuadCurve(to: CGPoint(x: 0.02150, y: 0.05150), control: CGPoint(x: 0.05300, y: 0.07800))
            path.addQuadCurve(to: CGPoint(x: -0.01000, y: -0.02150), control: CGPoint(x: -0.01000, y: 0.02500))
            path.addQuadCurve(to: CGPoint(x: 0.03200, y: -0.11800), control: CGPoint(x: -0.01000, y: -0.06800))
            path.addQuadCurve(to: CGPoint(x: 0.14700, y: -0.20200), control: CGPoint(x: 0.07400, y: -0.16800))
            path.addLine(to: CGPoint(x: 0.17000, y: -0.16600))
            path.addQuadCurve(to: CGPoint(x: 0.08000, y: -0.04600), control: CGPoint(x: 0.08000, y: -0.10200))
            path.addQuadCurve(to: CGPoint(x: 0.09800, y: -0.00250), control: CGPoint(x: 0.08000, y: -0.01900))
            path.addQuadCurve(to: CGPoint(x: 0.14500, y: 0.01400), control: CGPoint(x: 0.11600, y: 0.01400))
            path.addQuadCurve(to: CGPoint(x: 0.26250, y: -0.04350), control: CGPoint(x: 0.21300, y: 0.01400))
            path.addQuadCurve(to: CGPoint(x: 0.35100, y: -0.24500), control: CGPoint(x: 0.31200, y: -0.10100))
            path.addQuadCurve(to: CGPoint(x: 0.45100, y: -0.48200), control: CGPoint(x: 0.40000, y: -0.42600))
            path.addQuadCurve(to: CGPoint(x: 0.51800, y: -0.53900), control: CGPoint(x: 0.47400, y: -0.50800))
            path.addQuadCurve(to: CGPoint(x: 0.37700, y: -0.51550), control: CGPoint(x: 0.44900, y: -0.53700))
            path.addQuadCurve(to: CGPoint(x: 0.25100, y: -0.45150), control: CGPoint(x: 0.30500, y: -0.49400))
            path.addQuadCurve(to: CGPoint(x: 0.19700, y: -0.35700), control: CGPoint(x: 0.19700, y: -0.40900))
            path.addQuadCurve(to: CGPoint(x: 0.25800, y: -0.25000), control: CGPoint(x: 0.19700, y: -0.29000))
            path.addLine(to: CGPoint(x: 0.23800, y: -0.21900))
            path.addQuadCurve(to: CGPoint(x: 0.15000, y: -0.28900), control: CGPoint(x: 0.18200, y: -0.24600))
            path.addQuadCurve(to: CGPoint(x: 0.11800, y: -0.37800), control: CGPoint(x: 0.11800, y: -0.33200))
            path.addQuadCurve(to: CGPoint(x: 0.18700, y: -0.49700), control: CGPoint(x: 0.11800, y: -0.44100))
            path.addQuadCurve(to: CGPoint(x: 0.35650, y: -0.58400), control: CGPoint(x: 0.25600, y: -0.55300))
            path.addQuadCurve(to: CGPoint(x: 0.55400, y: -0.61500), control: CGPoint(x: 0.45700, y: -0.61500))
            path.addQuadCurve(to: CGPoint(x: 0.61400, y: -0.58900), control: CGPoint(x: 0.61400, y: -0.61500))
            path.addQuadCurve(to: CGPoint(x: 0.57900, y: -0.54600), control: CGPoint(x: 0.61400, y: -0.57200))
            path.addQuadCurve(to: CGPoint(x: 0.48050, y: -0.42100), control: CGPoint(x: 0.51500, y: -0.49800))
            path.addQuadCurve(to: CGPoint(x: 0.42400, y: -0.24100), control: CGPoint(x: 0.44600, y: -0.34400))
            path.addQuadCurve(to: CGPoint(x: 0.64250, y: -0.38050), control: CGPoint(x: 0.53800, y: -0.28300))
            path.addQuadCurve(to: CGPoint(x: 0.82400, y: -0.60000), control: CGPoint(x: 0.74700, y: -0.47800))
            path.closeSubpath()
        default:
            break
        }

        let scale = fontSize * sizeScale
        let transform = CGAffineTransform(translationX: -inkCenter.x, y: -inkCenter.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY))
        return path.applying(transform)
    }
}
