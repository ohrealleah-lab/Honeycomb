import SwiftUI

// MARK: - Spider Stock View
public struct SpiderStockView: View {
    let cardCount: Int
    
    public init(cardCount: Int) {
        self.cardCount = cardCount
    }
    
    public var body: some View {
        let dealsRemaining = cardCount / 10
        
        ZStack {
            if dealsRemaining == 0 {
                EmptyPileView(symbol: "∅")
            } else {
                // Render overlapping card backs to represent remaining deals (max 5)
                let visibleCount = min(5, dealsRemaining)
                ForEach(0..<visibleCount, id: \.self) { index in
                    CardView(card: Card(suit: .spades, rank: 1, faceUp: false),
                             isAnimated: index == visibleCount - 1)
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
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    
    public init(
        pile: Pile,
        draggedCardIDs: Set<UUID>,
        onDragStarted: @escaping (Card, [Card], CGPoint) -> Void,
        onDragChanged: @escaping (CGSize) -> Void,
        onDragEnded: @escaping () -> Void,
        onDoubleClick: @escaping (Card) -> Void
    ) {
        self.pile = pile
        self.draggedCardIDs = draggedCardIDs
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onDoubleClick = onDoubleClick
    }
    
    private func totalHeight(offset: CGFloat) -> CGFloat {
        if pile.isEmpty {
            return 181
        }
        return CGFloat(pile.cards.count - 1) * offset + 181
    }
    
    public var body: some View {
        let cardCount = pile.cards.count
        // Dynamically compress card overlap offset if pile gets deep to prevent clipping
        let offset: CGFloat = cardCount > 10 ? max(12.0, 32.0 - CGFloat(cardCount - 10) * 1.5) : 32.0
        
        ZStack(alignment: .top) {
            EmptyPileView()
            
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { index, card in
                CardView(card: card)
                    .opacity(draggedCardIDs.contains(card.id) ? 0.0 : 1.0)
                    .offset(y: CGFloat(index) * offset)
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { val in
                                // Can only drag if this card and subsequent cards form a valid Spider drag sequence
                                let dragStack = Array(pile.cards[index..<pile.cards.count])
                                
                                // Call viewModel's check or do check locally
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
        .frame(width: 128, height: totalHeight(offset: offset), alignment: .top)
    }
    
    private func isValidSequence(_ cards: [Card]) -> Bool {
        guard !cards.isEmpty else { return false }
        guard cards.allSatisfy({ $0.faceUp }) else { return false }
        
        let suit = cards[0].suit
        for i in 1..<cards.count {
            if cards[i].suit != suit || cards[i].rank != cards[i-1].rank - 1 {
                return false
            }
        }
        return true
    }
}
