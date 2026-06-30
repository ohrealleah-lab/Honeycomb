import SwiftUI

// MARK: - Freecell Temp Storage Cell View
public struct FreeCellView: View {
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
    
    public var body: some View {
        ZStack {
            EmptyPileView()
            
            if let topCard = pile.topCard {
                CardView(card: topCard)
                    .opacity(draggedCardIDs.contains(topCard.id) ? 0.0 : 1.0)
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { val in
                                onDragStarted(topCard, [topCard], val.startLocation)
                                onDragChanged(val.translation)
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                onDoubleClick(topCard)
                            }
                    )
            }
        }
    }
}

// MARK: - Freecell Foundation Pile View
public struct BeecellFoundationView: View {
    let pile: Pile
    let draggedCardIDs: Set<UUID>
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    public init(
        pile: Pile,
        draggedCardIDs: Set<UUID>,
        onDragStarted: @escaping (Card, [Card], CGPoint) -> Void,
        onDragChanged: @escaping (CGSize) -> Void,
        onDragEnded: @escaping () -> Void
    ) {
        self.pile = pile
        self.draggedCardIDs = draggedCardIDs
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }
    
    public var body: some View {
        ZStack {
            EmptyPileView(symbol: "A")
            
            if let topCard = pile.topCard {
                CardView(card: topCard)
                    .opacity(draggedCardIDs.contains(topCard.id) ? 0.0 : 1.0)
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { val in
                                onDragStarted(topCard, [topCard], val.startLocation)
                                onDragChanged(val.translation)
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )
            }
        }
    }
}

// MARK: - Freecell Tableau Column View (All cards face-up)
public struct BeecellTableauView: View {
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
    
    private var totalHeight: CGFloat {
        if pile.isEmpty {
            return 181
        }
        return CGFloat(pile.cards.count - 1) * 32 + 181
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            EmptyPileView()
            
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { index, card in
                CardView(card: card)
                    .opacity(draggedCardIDs.contains(card.id) ? 0.0 : 1.0)
                    .offset(y: CGFloat(index) * 32)
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { val in
                                let dragStack = Array(pile.cards[index..<pile.cards.count])
                                onDragStarted(card, dragStack, val.startLocation)
                                onDragChanged(val.translation)
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )
                    .highPriorityGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                if index == pile.cards.count - 1 {
                                    onDoubleClick(card)
                                }
                            }
                    )
            }
        }
        .frame(width: 128, height: totalHeight, alignment: .top)
    }
}
