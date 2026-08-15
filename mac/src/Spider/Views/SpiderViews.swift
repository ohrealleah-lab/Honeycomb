import SwiftUI

// MARK: - Spider Stock View
public struct SpiderStockView: View {
    let cardCount: Int
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    
    public init(cardCount: Int, isFocused: Bool = false, isSelected: Bool = false) {
        self.cardCount = cardCount
        self.isFocused = isFocused
        self.isSelected = isSelected
    }
    
    public var body: some View {
        let dealsRemaining = cardCount / 10
        
        ZStack {
            if dealsRemaining == 0 {
                EmptyPileView(symbol: "∅", isFocused: isFocused, isSelected: isSelected)
            } else {
                // Render overlapping card backs to represent remaining deals (max 5)
                let visibleCount = min(5, dealsRemaining)
                ForEach(0..<visibleCount, id: \.self) { index in
                    CardView(card: Card(suit: .spades, rank: 1, faceUp: false),
                             isAnimated: index == visibleCount - 1,
                             isFocused: isFocused && index == visibleCount - 1,
                             isSelected: isSelected && index == visibleCount - 1)
                        .offset(x: CGFloat(index) * 2.5, y: 0)
                }
            }
        }
    }
}

// MARK: - Spider Tableau Column View
public struct SpiderTableauView: View {
    let pile: Pile
    let draggedCardIDs: Set<UUID>
    let activeHint: SpiderViewModel.SpiderHintMove?
    public var isFocused: Bool = false
    public var focusedCardIndex: Int? = nil
    public var isSelected: Bool = false
    public var selectedCardIndex: Int? = nil
    // Point Highlights: the "-1"/"+100" popup shown when this pile's top card is the
    // one the ViewModel just scored via.
    public var pointPopup: CardPointPopup? = nil
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    let isValidSequence: ([Card]) -> Bool

    public init(
        pile: Pile,
        draggedCardIDs: Set<UUID>,
        activeHint: SpiderViewModel.SpiderHintMove?,
        isFocused: Bool = false,
        focusedCardIndex: Int? = nil,
        isSelected: Bool = false,
        selectedCardIndex: Int? = nil,
        pointPopup: CardPointPopup? = nil,
        onDragStarted: @escaping (Card, [Card], CGPoint) -> Void,
        onDragChanged: @escaping (CGSize) -> Void,
        onDragEnded: @escaping () -> Void,
        onDoubleClick: @escaping (Card) -> Void,
        isValidSequence: @escaping ([Card]) -> Bool
    ) {
        self.pile = pile
        self.draggedCardIDs = draggedCardIDs
        self.activeHint = activeHint
        self.isFocused = isFocused
        self.focusedCardIndex = focusedCardIndex
        self.isSelected = isSelected
        self.selectedCardIndex = selectedCardIndex
        self.pointPopup = pointPopup
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onDoubleClick = onDoubleClick
        self.isValidSequence = isValidSequence
    }
    
    // Face-down cards get tighter spacing than face-up ones (20pt vs 32pt) — same
    // split Klondike's TableauPileView uses, since a face-down card back doesn't need
    // room to show a rank/suit corner the way a face-up card does. Spider's own
    // uniform-32pt offset (ignoring faceUp/faceDown) used to apply the wide face-up
    // spacing to face-down cards too, making a face-down run look far more spread out
    // than the equivalent run in Klondike or the Windows port (whose shared PileView
    // already makes this same 32/20 split for Tableau piles).
    private static let faceUpOffset: CGFloat = 32
    private static let faceDownOffset: CGFloat = 20

    // Spider tableaus can run much deeper than Klondike's (up to 19+ cards in a
    // single column from the initial deal alone), so — matching this view's own
    // preexisting behavior — spacing compresses once a pile gets deep, to keep it
    // from running off the bottom of the window. Applied as a multiplier to both the
    // face-up and face-down base offsets, rather than a flat value, so the two stay
    // proportional to each other at any depth instead of the compression only ever
    // having applied to the (previously single) face-up-sized offset.
    private static func compressionRatio(cardCount: Int) -> CGFloat {
        guard cardCount > 10 else { return 1.0 }
        return max(12.0, faceUpOffset - CGFloat(cardCount - 10) * 1.5) / faceUpOffset
    }

    private func offsetForCard(at index: Int, compressionRatio: CGFloat) -> CGFloat {
        var yOffset: CGFloat = 0
        for i in 0..<index {
            let base = pile.cards[i].faceUp ? Self.faceUpOffset : Self.faceDownOffset
            yOffset += base * compressionRatio
        }
        return yOffset
    }

    private func totalHeight(compressionRatio: CGFloat) -> CGFloat {
        if pile.isEmpty {
            return 181
        }
        return offsetForCard(at: pile.cards.count - 1, compressionRatio: compressionRatio) + 181
    }

    public var body: some View {
        let cardCount = pile.cards.count
        let compressionRatio = Self.compressionRatio(cardCount: cardCount)

        let isSource = activeHint?.sourcePileId == pile.id
        let isTarget = activeHint?.targetPileId == pile.id
        let hintStartIndex = (activeHint?.sourcePileId == pile.id) ? pile.cards.firstIndex(where: { $0.id == activeHint?.card.id }) : nil
        
        ZStack(alignment: .top) {
            EmptyPileView(isFocused: isFocused && pile.isEmpty, isSelected: isSelected && pile.isEmpty)
                .modifier(HintHighlightModifier(isHighlighted: isTarget && pile.isEmpty))
            
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { index, card in
                let isCardHighlighted: Bool = {
                    if let startIndex = hintStartIndex {
                        return index >= startIndex
                    }
                    if isTarget {
                        return index == pile.cards.count - 1
                    }
                    return false
                }()
                
                let cardIsFocused = isFocused && index == focusedCardIndex
                let cardIsSelected = isSelected && index == selectedCardIndex
                let isTopCard = index == pile.cards.count - 1

                CardView(
                    card: card, isFocused: cardIsFocused, isSelected: cardIsSelected,
                    pointPopupText: isTopCard && pointPopup?.cardId == card.id ? pointPopup?.displayText : nil
                )
                    .modifier(HintHighlightModifier(isHighlighted: isCardHighlighted))
                    .opacity(draggedCardIDs.contains(card.id) ? 0.0 : 1.0)
                    .offset(y: offsetForCard(at: index, compressionRatio: compressionRatio))
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { val in
                                // Can only drag if this card and subsequent cards form a valid Spider drag sequence
                                let dragStack = Array(pile.cards[index..<pile.cards.count])

                                if isValidSequence(dragStack) {
                                    onDragStarted(card, dragStack, val.startLocation)
                                    onDragChanged(val.translation)
                                }
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                onDoubleClick(card)
                            }
                    )
            }
        }
        .frame(width: 128, height: totalHeight(compressionRatio: compressionRatio), alignment: .top)
    }
}
