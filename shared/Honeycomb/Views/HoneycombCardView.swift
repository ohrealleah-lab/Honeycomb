import SwiftUI

// Shared 3D card-flip timing — every "a Honeycomb card turns over" moment (the
// ownership/reveal flips below, and the mac port's match-start deal-flip in
// HoneycombView) uses these same values, so they all read as one consistent
// animation rather than independently-tuned look-alikes.
public enum HoneycombFlipTiming {
    public static let duration: Double = 0.4
    public static let midpointDelay: Double = 0.2
}

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
    // Point Highlights: which of this card's N/E/S/W stats (0=Top,1=Right,2=Bottom,
    // 3=Left) just won a capture, briefly flashed gold before the flip happens.
    public var highlightedStatIndices: Set<Int> = []
    // True for exactly one brief window (viewModel.captureAttackerIds) when this card
    // is the one that just directly caused a capture — the placed card itself, or a
    // Hive Swarm reveal that captured a neighbor. Drives ruleTriggerScale below: the
    // ATTACKING card pops, not whatever it captured.
    public var isCaptureAttacker: Bool = false

    @Environment(\.activeCustomCardColors) private var customCardColors: CustomCardColorGroup

    @State private var flipDegrees: Double = 0.0
    @State private var statPulseScale: CGFloat = 1.0
    @State private var pointHighlightPulseScale: CGFloat = 1.0
    // Rule-trigger pop — a capture flipping this card to its new owner, whether from
    // an ordinary placement, a combo chain, or a Hive Swarm reveal's own capture (see
    // the card.owner onChange below; there's deliberately no separate Hive Swarm-
    // specific trigger, so a reveal that captures nothing doesn't pop): scales the
    // *whole* card 1.2x for 1s. Applied as its own .scaleEffect at the very end of the
    // modifier chain (after background/clipShape/border/shadow/badge below), not
    // grouped in with the flip's mirror
    // scaleEffect near the top — that one only wraps the inner content ZStack, before
    // the white background/border/shadow are added, so combining them there scaled
    // the numbers/suit up while the card's own background/border/shadow stayed at
    // their original size, leaving the enlarged content overflowing past the card's
    // edge instead of the whole card growing together. Deliberately NOT wired to
    // Pollination/Smoked Out's modifier changes — those recompute for every
    // matching-suit card on the board on every placement (see HoneycombBoard's
    // updateModifiers), so the pop fired far too often and read as noise rather than
    // a capture-specific "something just happened" beat.
    @State private var ruleTriggerScale: CGFloat = 1.0
    // Guards ruleTriggerScale's delayed reset-to-1.0 against a second trigger firing
    // before the first one's 1s hold elapses (e.g. a combo chain flipping this same
    // card again as one of its own neighbors within a beat of its first capture) —
    // same pattern as modifierGlowGeneration below, without which the earlier
    // trigger's stale dispatch would cut the later one's hold short.
    @State private var ruleTriggerGeneration: Int = 0
    // Ascension/Descension badge: glows brightly for ~1s after the modifier changes,
    // then the glow (not the number itself) fades out — same hold-then-fade timing as
    // the Solitaire point popups. Guarded by a generation counter since the modifier is
    // recomputed every turn and can change again mid-fade.
    @State private var modifierGlowOpacity: Double = 0.0
    @State private var modifierGlowGeneration: Int = 0
    // The owner actually rendered — lags one half-flip behind `card.owner` so the
    // ownership-dependent border color swaps at the rotation's 90° midpoint (when the
    // card is edge-on and invisible) instead of instantly at the start of the
    // animation, before the flip has even begun to turn.
    @State private var displayedOwner: CardOwner
    // Same lag, but for Bomb Shelter's face-down -> face-up reveal: without this, the
    // face content would swap the instant `card.isFaceDown` flips (i.e. immediately,
    // full-frontal, before any rotation has happened), defeating the point of a reveal
    // animation. Lagging it to the rotation's midpoint makes the card visibly turn over
    // to show what was underneath, the same way an ownership flip already does for color.
    @State private var displayedIsFaceDown: Bool
    // rotation3DEffect doesn't cull the back face by default, so past 90° the (already
    // new) content would render mirrored/backwards. This snaps on at the same midpoint
    // as the owner swap above and applies a horizontal flip that cancels the
    // rotation's own mirroring back out, so the second half of the animation reads
    // normally instead of showing backwards text.
    @State private var isPastFlipMidpoint: Bool = false

    public init(card: HoneycombCard, size: CGSize, isFlipped: Bool, useOwnershipColoring: Bool = true, stealHighlight: Bool = false, highlightedStatIndices: Set<Int> = [], isCaptureAttacker: Bool = false) {
        self.card = card
        self.size = size
        self.isFlipped = isFlipped
        self.useOwnershipColoring = useOwnershipColoring
        self.stealHighlight = stealHighlight
        self.highlightedStatIndices = highlightedStatIndices
        self.isCaptureAttacker = isCaptureAttacker
        _displayedOwner = State(initialValue: card.owner)
        _displayedIsFaceDown = State(initialValue: card.isFaceDown)
    }

    // Matches every other game's CardView rank index: 17pt bold monospaced at the
    // standard 128pt-wide card. Honeycomb cards render at several different sizes
    // (board/hand vs. deck-manager thumbnails), so this scales proportionally to size
    // while landing exactly on 17pt (24pt on iOS) at the standard width.
    #if os(iOS)
    private static let baseNumberFontSize: CGFloat = 24.0
    #else
    private static let baseNumberFontSize: CGFloat = 17.0
    #endif
    private var numberFontSize: CGFloat { size.width * (Self.baseNumberFontSize / CardDimensions.width) }
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
            if isFlipped || displayedIsFaceDown {
                // The themed CardBackView (bundle images + custom card backs) is still
                // macOS-only; iOS renders a procedural back until it's ported.
                #if canImport(AppKit)
                CardBackView(size: size)
                #else
                HoneycombSimpleCardBack()
                #endif
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
                    .foregroundColor(statColor(for: 0))
                    .scaleEffect(statScale(for: 0))
                    .position(x: size.width / 2, y: numberPadding + numberGlyphHalfHeight)

                // West (Left)
                Text(statString(card.data.stats[3]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(statColor(for: 3))
                    .scaleEffect(statScale(for: 3))
                    .position(x: numberPadding + numberGlyphHalfWidth, y: size.height / 2)

                // East (Right)
                Text(statString(card.data.stats[1]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(statColor(for: 1))
                    .scaleEffect(statScale(for: 1))
                    .position(x: size.width - (numberPadding + numberGlyphHalfWidth), y: size.height / 2)

                // South (Bottom)
                Text(statString(card.data.stats[2]))
                    .font(.system(size: numberFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(statColor(for: 2))
                    .scaleEffect(statScale(for: 2))
                    .position(x: size.width / 2, y: size.height - (numberPadding + numberGlyphHalfHeight))

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
            withAnimation(.easeInOut(duration: HoneycombFlipTiming.duration)) {
                flipDegrees += 180
            }
            // The card is edge-on (invisible) right at the midpoint — swap the rendered
            // owner and snap the mirror correction on with no animation of their own, so
            // both changes are hidden inside the moment the card can't be seen face-on.
            DispatchQueue.main.asyncAfter(deadline: .now() + HoneycombFlipTiming.midpointDelay) {
                displayedOwner = newOwner
                isPastFlipMidpoint.toggle()
            }
            // No ruleTriggerScale pop here — this is the *captured* card's own flip.
            // The pop belongs to whichever card did the capturing, driven by
            // isCaptureAttacker below, not to the card that just got flipped.
        }
        .onChange(of: card.isFaceDown) { oldValue, newValue in
            guard oldValue != newValue else { return }
            withAnimation(.easeInOut(duration: HoneycombFlipTiming.duration)) {
                flipDegrees += 180
            }
            // Same edge-on-midpoint trick as the ownership flip above: swap which face is
            // showing (and the mirror correction) at the moment the card is invisible.
            DispatchQueue.main.asyncAfter(deadline: .now() + HoneycombFlipTiming.midpointDelay) {
                displayedIsFaceDown = newValue
                isPastFlipMidpoint.toggle()
            }
        }
        // Capture-attacker pop: `.onChange` covers a card that's already on screen when
        // it becomes the attacker (a Hive Swarm reveal capturing a neighbor — this same
        // view instance persists from before the reveal), while `.onAppear` covers the
        // far more common case — a freshly-placed card that captures immediately, whose
        // HoneycombCardView mounts for the very first time already flagged as the
        // attacker, too late for `.onChange` to ever see a false -> true transition.
        .onChange(of: isCaptureAttacker) { _, newValue in
            if newValue { triggerRulePop() }
        }
        .onAppear {
            if isCaptureAttacker { triggerRulePop() }
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
                if newMod != 0 {
                    modifierGlowGeneration += 1
                    let generation = modifierGlowGeneration
                    modifierGlowOpacity = 1.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        guard modifierGlowGeneration == generation else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            modifierGlowOpacity = 0.0
                        }
                    }
                } else {
                    modifierGlowOpacity = 0.0
                }
            }
        }
        .onChange(of: highlightedStatIndices) { _, newValue in
            guard !newValue.isEmpty else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                pointHighlightPulseScale = 1.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeIn(duration: 0.2)) {
                    pointHighlightPulseScale = 1.0
                }
            }
        }
        // White backing — behind both face-up cards and the card back image alike,
        // so transparent card-back images (e.g. Vulpera sticker) don't show the
        // felt through transparent areas. The card back image now fills to the full
        // card size so this no longer creates a visible border rim.
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // Thin standard border (matches CardView's outlineColor) — applied to both the
        // face-up card and CardBackView alike, unlike the face-only content above.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
        // Ascension/Descension badge — same top-right corner spot as the Solitaire
        // point popups (proportional to this view's own size, since Honeycomb cards
        // render at several different sizes), so it reads as the same "here's what just
        // happened to your points" language across every game.
        .overlay(alignment: .topTrailing) {
            if !isFlipped && card.modifier != 0 {
                Text(card.modifier > 0 ? "+\(card.modifier)" : "\(card.modifier)")
                    .font(.system(size: size.width * (24.0 / 128.0), weight: .black, design: .monospaced))
                    .foregroundColor(currentColor)
                    .shadow(color: .white.opacity(modifierGlowOpacity), radius: size.width * (3.0 / 128.0))
                    .shadow(color: currentColor.opacity(0.9 * modifierGlowOpacity), radius: size.width * (6.0 / 128.0))
                    .padding(.top, size.height * (10.0 / 181.0))
                    .padding(.trailing, size.width * (10.0 / 128.0))
            }
        }
        // Whole-card rule-trigger pop — applied last, after background/border/shadow/
        // badge above, so the entire composed card (not just the inner suit/number
        // content) grows together. See ruleTriggerScale's own comment for why this
        // can't share the flip-mirror scaleEffect nearer the top of this chain.
        .scaleEffect(ruleTriggerScale)
    }

    // Only ever called from the card.owner onChange above — this card just flipped to
    // a new owner via a capture (direct, combo-chained, or a Hive Swarm reveal's own
    // capture). Scales up immediately, holds at 1.2x for 1s, then eases back to 1.0x.
    // ruleTriggerGeneration
    // ensures only the most recent trigger's delayed reset actually fires, so a second
    // trigger landing inside the first one's hold window (e.g. this card getting
    // captured, then immediately re-captured back in a fast exchange) extends the pop
    // instead of getting cut short by the first trigger's now-stale scale-down.
    private func triggerRulePop() {
        ruleTriggerGeneration += 1
        let generation = ruleTriggerGeneration
        withAnimation(.easeOut(duration: 0.2)) {
            ruleTriggerScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard ruleTriggerGeneration == generation else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                ruleTriggerScale = 1.0
            }
        }
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

    // Point Highlights: the specific N/E/S/W stat that just won a capture flashes gold
    // and briefly scales up, overriding the normal ownership color for that one number.
    private func statColor(for index: Int) -> Color {
        highlightedStatIndices.contains(index) ? .yellow : currentColor
    }

    private func statScale(for index: Int) -> CGFloat {
        highlightedStatIndices.contains(index) ? statPulseScale * pointHighlightPulseScale : statPulseScale
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
