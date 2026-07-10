import SwiftUI

// MARK: - Freecell Temp Storage Cell View
public struct FreeCellView: View {
    let pile: Pile
    let draggedCardIDs: Set<UUID>
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    
    public init(
        pile: Pile,
        draggedCardIDs: Set<UUID>,
        isFocused: Bool = false,
        isSelected: Bool = false,
        onDragStarted: @escaping (Card, [Card], CGPoint) -> Void,
        onDragChanged: @escaping (CGSize) -> Void,
        onDragEnded: @escaping () -> Void,
        onDoubleClick: @escaping (Card) -> Void
    ) {
        self.pile = pile
        self.draggedCardIDs = draggedCardIDs
        self.isFocused = isFocused
        self.isSelected = isSelected
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
        self.onDoubleClick = onDoubleClick
    }
    
    public var body: some View {
        ZStack {
            EmptyPileView(isFocused: isFocused && pile.isEmpty, isSelected: isSelected && pile.isEmpty)
            
            if let topCard = pile.topCard {
                CardView(card: topCard, isFocused: isFocused, isSelected: isSelected)
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
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    public init(
        pile: Pile,
        draggedCardIDs: Set<UUID>,
        isFocused: Bool = false,
        isSelected: Bool = false,
        onDragStarted: @escaping (Card, [Card], CGPoint) -> Void,
        onDragChanged: @escaping (CGSize) -> Void,
        onDragEnded: @escaping () -> Void
    ) {
        self.pile = pile
        self.draggedCardIDs = draggedCardIDs
        self.isFocused = isFocused
        self.isSelected = isSelected
        self.onDragStarted = onDragStarted
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }
    
    public var body: some View {
        ZStack {
            EmptyPileView(symbol: "A", isFocused: isFocused && pile.isEmpty, isSelected: isSelected && pile.isEmpty)
            
            if let topCard = pile.topCard {
                CardView(card: topCard, isFocused: isFocused, isSelected: isSelected)
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
    let activeHint: BeecellViewModel.HintMove?
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    
    public init(
        pile: Pile,
        draggedCardIDs: Set<UUID>,
        activeHint: BeecellViewModel.HintMove?,
        isFocused: Bool = false,
        isSelected: Bool = false,
        onDragStarted: @escaping (Card, [Card], CGPoint) -> Void,
        onDragChanged: @escaping (CGSize) -> Void,
        onDragEnded: @escaping () -> Void,
        onDoubleClick: @escaping (Card) -> Void
    ) {
        self.pile = pile
        self.draggedCardIDs = draggedCardIDs
        self.activeHint = activeHint
        self.isFocused = isFocused
        self.isSelected = isSelected
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
        let isSource = activeHint?.sourcePileId == pile.id
        let isTarget = activeHint?.targetPileId == pile.id
        let hintStartIndex = isSource ? pile.cards.firstIndex(where: { $0.id == activeHint?.card.id }) : nil
        
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
                
                let cardIsFocused = isFocused && index == pile.cards.count - 1
                let cardIsSelected = isSelected && index == pile.cards.count - 1
                
                CardView(card: card, isFocused: cardIsFocused, isSelected: cardIsSelected)
                    .modifier(HintHighlightModifier(isHighlighted: isCardHighlighted))
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
