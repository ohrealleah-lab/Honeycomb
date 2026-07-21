import SwiftUI

public struct HoneycombCardView: View {
    public let card: HoneycombCard
    public let size: CGSize
    public let isFlipped: Bool
    // Board and hand cards indicate ownership by recoloring the suit icon/stats
    // themselves (black = player, red = opponent, overriding the suit's natural color)
    // rather than a border — this is false only for the deck manager, which always
    // shows the player's own collection and where a card's natural suit color is what's
    // meaningful to see, not ownership (which is constant there anyway).
    public var useOwnershipColoring: Bool = true
    // Overrides the ownership coloring with a yellow border — used at game end to mark
    // cards the opponent originally played, which the player can steal regardless of
    // who currently owns them on the board.
    public var stealHighlight: Bool = false

    @Environment(\.activeCustomCardColors) private var customCardColors: CustomCardColorGroup

    @State private var flipDegrees: Double = 0.0
    @State private var statPulseScale: CGFloat = 1.0
    // The owner actually rendered — lags one half-flip behind `card.owner` so the
    // ownership-dependent border color swaps at the rotation's 90° midpoint (when the
    // card is edge-on and invisible) instead of instantly at the start of the
    // animation, before the flip has even begun to turn.
    @State private var displayedOwner: CardOwner
    // rotation3DEffect doesn't cull the back face by default, so past 90° the (already
    // new) content would render mirrored/backwards. This snaps on at the same midpoint
    // as the owner swap above and applies a horizontal flip that cancels the
    // rotation's own mirroring back out, so the second half of the animation reads
    // normally instead of showing backwards text.
    @State private var isPastFlipMidpoint: Bool = false

    public init(card: HoneycombCard, size: CGSize, isFlipped: Bool, useOwnershipColoring: Bool = true, stealHighlight: Bool = false) {
        self.card = card
        self.size = size
        self.isFlipped = isFlipped
        self.useOwnershipColoring = useOwnershipColoring
        self.stealHighlight = stealHighlight
        _displayedOwner = State(initialValue: card.owner)
    }

    // Matches every other game's CardView rank index: 17pt bold monospaced at the
    // standard 128pt-wide card. Honeycomb cards render at several different sizes
    // (board/hand vs. deck-manager thumbnails), so this scales proportionally to size
    // while landing exactly on 17pt at the standard width.
    private var numberFontSize: CGFloat { size.width * (17.0 / 128.0) }
    // Approximate half-width/height of a single monospaced-digit glyph at that font
    // size, used to keep the fixed 3pt gap measured from the glyph's visible edge
    // rather than its baseline position.
    private var numberGlyphHalfWidth: CGFloat { numberFontSize * 0.3 }
    private var numberGlyphHalfHeight: CGFloat { numberFontSize * 0.35 }
    // Scales with card size like everything else here (was a fixed 18pt regardless of
    // size, which looked fine at the board's 190pt cards but ate a much bigger share of
    // the much smaller Deck Builder thumbnails, squeezing the suit/stars/numbers
    // together). 13pt at the standard 128pt-wide card (5pt closer to the edge than
    // before), same reference point as numberFontSize above.
    private var numberPadding: CGFloat { size.width * (13.0 / 128.0) }

    public var body: some View {
        ZStack {
            if isFlipped {
                CardBackView()
            } else {
                // Large Center Suit (Like an Ace) — dead center of the card.
                Image(systemName: suitIcon(card.data.suit))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width * 0.4)
                    .foregroundColor(currentColor)
                    .position(x: size.width / 2, y: size.height / 2)

                // North (Top) — 3pt gap from the border, same font size/weight/design as
                // the rank index on every other game's CardView (17pt bold monospaced at
                // the standard 128pt-wide card). Always shows the card's *base* stat —
                // any active Ascension/Descension modifier is shown separately as a
                // +N/-N badge over the suit, not baked into these numbers.
                Text(statString(card.data.stats[0]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
                    .scaleEffect(statPulseScale)
                    .position(x: size.width / 2, y: numberPadding + numberGlyphHalfHeight)

                // West (Left)
                Text(statString(card.data.stats[3]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
                    .scaleEffect(statPulseScale)
                    .position(x: numberPadding + numberGlyphHalfWidth, y: size.height / 2)

                // East (Right)
                Text(statString(card.data.stats[1]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
                    .scaleEffect(statPulseScale)
                    .position(x: size.width - (numberPadding + numberGlyphHalfWidth), y: size.height / 2)

                // South (Bottom)
                Text(statString(card.data.stats[2]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
                    .scaleEffect(statPulseScale)
                    .position(x: size.width / 2, y: size.height - (numberPadding + numberGlyphHalfHeight))

                // Ascension/Descension modifier badge — sits to the northeast of the
                // suit, clear of both the suit/stars cluster and the North/East
                // numbers, so it doesn't get lost in the middle of the card and reads
                // clearly as a separate bonus/penalty. Colored (not white, since it's
                // no longer sitting on top of the colored suit — it's on the plain
                // white card background here) and sized up for emphasis.
                if card.modifier != 0 {
                    Text(card.modifier > 0 ? "+\(card.modifier)" : "\(card.modifier)")
                        .font(.system(size: size.width * 0.22, weight: .black, design: .monospaced))
                        .foregroundColor(card.modifier > 0 ? .green : .red)
                        .position(x: size.width * 0.72, y: size.height * 0.28)
                }

                // Stars — dead center of the card, over the suit icon (declared after
                // it in this ZStack, so they render on top). White, with a row split
                // for 4-5 stars instead of one wide row: 4 stars stack as 2-over-2;
                // 5 stars split 3-over-2 for Hearts/Diamonds, 2-over-3 for Spades/Clubs.
                starsView
                    .position(x: size.width / 2, y: size.height / 2)

                // Steal-eligible border — at game end, once the player chooses "Steal
                // Card", a card still owned by the opponent gets a yellow highlight
                // (ownership coloring above already marks it red; this calls it out as
                // specifically stealable). Ownership itself is no longer shown via a
                // border — see `currentColor`.
                if stealHighlight {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: 14)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(x: isPastFlipMidpoint ? -1 : 1, y: 1)
        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
        .onChange(of: card.owner) { oldOwner, newOwner in
            guard oldOwner != newOwner else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                flipDegrees += 180
            }
            // The card is edge-on (invisible) right at the midpoint — swap the rendered
            // owner and snap the mirror correction on with no animation of their own, so
            // both changes are hidden inside the moment the card can't be seen face-on.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                displayedOwner = newOwner
                isPastFlipMidpoint.toggle()
            }
        }
        .onChange(of: card.modifier) { oldMod, newMod in
            if oldMod != newMod {
                withAnimation(.easeOut(duration: 0.15)) {
                    statPulseScale = 1.4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeIn(duration: 0.2)) {
                        statPulseScale = 1.0
                    }
                }
            }
        }
        // White backing — applied to both the face-up card and CardBackView alike (like
        // CardView's own `.background(Color.white)`), so a card-back image with
        // transparent edges doesn't let the felt show through underneath it.
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // Thin standard border (matches CardView's outlineColor) — applied to both the
        // face-up card and CardBackView alike, unlike the face-only content above.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
    }
    
    private func statString(_ stat: Int) -> String {
        return stat >= 10 ? "A" : "\(stat)"
    }
    
    private func suitIcon(_ suit: String) -> String {
        switch suit {
        case "S": return "suit.spade.fill"
        case "H": return "suit.heart.fill"
        case "D": return "suit.diamond.fill"
        case "C": return "suit.club.fill"
        default: return "questionmark"
        }
    }
    
    // Board and hand cards: suit icon and N/E/S/W numbers are colored by *ownership*,
    // not the card's actual suit — always black for the player, always red for the
    // opponent (a heart or diamond under opponent control is red the same as a spade or
    // club would be), replacing the old colored-border ownership indicator. Only the
    // deck manager (useOwnershipColoring: false) keeps the natural suit coloring, since
    // it always shows the player's own collection. Both paths honor the app-wide
    // "Custom Card Color" theme (Black/Red Suit Text) when enabled.
    private var currentColor: Color {
        if useOwnershipColoring {
            return suitColor(isRed: displayedOwner == .opponent)
        }
        let isRed = card.data.suit == "H" || card.data.suit == "D"
        return suitColor(isRed: isRed)
    }

    private func suitColor(isRed: Bool) -> Color {
        if customCardColors.isEnabled {
            return isRed ? customCardColors.redSuitColor : customCardColors.blackSuitColor
        }
        return isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    // Sized so a row of 3 still fits inside the *visible* suit glyph (not just its
    // bounding box) — hearts/spades/clubs/diamonds all narrow sharply in the middle
    // band where the stars sit (a heart's waist, a spade/club's stem, a diamond's
    // point), so this needs real headroom below the suit's 0.4×card-width frame.
    private func starImage() -> some View {
        Image(systemName: "star.fill")
            .foregroundColor(.white)
            .font(.system(size: size.width * 0.06))
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
    }

    @ViewBuilder
    private var starsView: some View {
        let count = card.data.stars
        let isHeartOrDiamond = card.data.suit == "H" || card.data.suit == "D"
        switch count {
        case 4:
            VStack(spacing: 2) {
                HStack(spacing: 2) { starImage(); starImage() }
                HStack(spacing: 2) { starImage(); starImage() }
            }
        case 5:
            VStack(spacing: 1) {
                if isHeartOrDiamond {
                    HStack(spacing: 1) { starImage(); starImage(); starImage() }
                    HStack(spacing: 1) { starImage(); starImage() }
                } else {
                    HStack(spacing: 1) { starImage(); starImage() }
                    HStack(spacing: 1) { starImage(); starImage(); starImage() }
                }
            }
        default:
            HStack(spacing: 1) {
                ForEach(0..<count, id: \.self) { _ in starImage() }
            }
        }
    }
}
