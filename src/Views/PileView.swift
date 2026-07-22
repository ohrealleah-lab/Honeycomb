import SwiftUI

private struct FeltColorKey: EnvironmentKey {
    static let defaultValue: FeltColorTheme = .feltGreen
}

private struct ActiveCardBackThemeKey: EnvironmentKey {
    static let defaultValue: String = "Moogle"
}

private struct ActiveCustomCardColorsKey: EnvironmentKey {
    static let defaultValue: CustomCardColorGroup = CustomCardColorGroup()
}

extension EnvironmentValues {
    public var feltColor: FeltColorTheme {
        get { self[FeltColorKey.self] }
        set { self[FeltColorKey.self] = newValue }
    }
    public var activeCardBackTheme: String {
        get { self[ActiveCardBackThemeKey.self] }
        set { self[ActiveCardBackThemeKey.self] = newValue }
    }
    public var activeCustomCardColors: CustomCardColorGroup {
        get { self[ActiveCustomCardColorsKey.self] }
        set { self[ActiveCustomCardColorsKey.self] = newValue }
    }
}

// MARK: - Generic Empty Pile Placeholder

public struct EmptyPileView: View {
    @Environment(\.feltColor) private var feltColor
    let symbol: String?
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    
    public init(symbol: String? = nil, isFocused: Bool = false, isSelected: Bool = false) {
        self.symbol = symbol
        self.isFocused = isFocused
        self.isSelected = isSelected
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.04))
            .frame(width: 128, height: 181)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
            )
            .overlay(
                Group {
                    if let sym = symbol {
                        Text(sym)
                            .font(.system(size: 51))
                            .foregroundColor(Color.white.opacity(0.2))
                    }
                }
            )
            .modifier(KeyboardFocusHighlightModifier(isFocused: isFocused, isSelected: isSelected))
    }
}

// MARK: - Stock Pile View

public struct StockPileView: View {
    let pile: Pile
    let stackSpacing: CGFloat
    let canRecycle: Bool
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    
    public var body: some View {
        ZStack {
            if pile.isEmpty {
                EmptyPileView(symbol: canRecycle ? "↺" : nil, isFocused: isFocused, isSelected: isSelected)
                    .transition(.opacity)
            } else {
                CardView(card: Card(suit: .spades, rank: 1, faceUp: false), isAnimated: true, isFocused: isFocused, isSelected: isSelected)
                    .transition(.asymmetric(
                        insertion: .offset(x: 128 + stackSpacing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: 128, height: 181)
        .contentShape(Rectangle())
    }
}

// MARK: - Waste Pile View

public struct WastePileView: View {
    let pile: Pile
    let isDrawThree: Bool
    let wasteDisplayCount: Int
    let stackSpacing: CGFloat
    let draggedCardIDs: Set<UUID>
    let isHinted: Bool
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    
    public var body: some View {
        ZStack {
            if pile.isEmpty {
                EmptyPileView(isFocused: isFocused, isSelected: isSelected)
                    .transition(.opacity)
            } else {
                ZStack {
                    if isDrawThree {
                        let cardsToShow = Array(pile.cards.suffix(wasteDisplayCount))
                        
                        ZStack(alignment: .leading) {
                            EmptyPileView()
                                .opacity(0)
                            
                            ForEach(Array(cardsToShow.enumerated()), id: \.element.id) { index, card in
                                let isTopCard = index == cardsToShow.count - 1
                                CardView(card: card, isFocused: isFocused && isTopCard, isSelected: isSelected && isTopCard)
                                    .modifier(HintHighlightModifier(isHighlighted: isHinted && isTopCard))
                                    .opacity(draggedCardIDs.contains(card.id) ? 0.0 : 1.0)
                                    .offset(x: CGFloat(index) * 42)
                                    .transition(.asymmetric(
                                        insertion: .offset(x: -(128 + stackSpacing) - CGFloat(index) * 42).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                                    .gesture(
                                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                            .onChanged { val in
                                                if index == cardsToShow.count - 1 {
                                                    onDragStarted(card, [card], val.startLocation)
                                                    onDragChanged(val.translation)
                                                }
                                            }
                                            .onEnded { _ in
                                                if index == cardsToShow.count - 1 {
                                                    onDragEnded()
                                                }
                                            }
                                    )
                                    .highPriorityGesture(
                                        TapGesture(count: 2)
                                            .onEnded {
                                                if index == cardsToShow.count - 1 {
                                                    onDoubleClick(card)
                                                }
                                            }
                                    )
                            }
                        }
                        .frame(width: 128 + CGFloat(max(0, cardsToShow.count - 1)) * 42, height: 181, alignment: .leading)
                    } else {
                        if let topCard = pile.topCard {
                            CardView(card: topCard, isFocused: isFocused, isSelected: isSelected)
                                .id(topCard.id)
                                .modifier(HintHighlightModifier(isHighlighted: isHinted))
                                .opacity(draggedCardIDs.contains(topCard.id) ? 0.0 : 1.0)
                                .transition(.asymmetric(
                                    insertion: .offset(x: -(128 + stackSpacing)).combined(with: .opacity),
                                    removal: .opacity
                                ))
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
                // No transition of its own: the individual card(s) inside already carry
                // their own slide+fade transition. Adding one here too double-nests with
                // theirs, which mutes the slide on the empty->non-empty edge (e.g. the
                // very first draw of a game).
                .transition(.identity)
            }
        }
        .frame(width: isDrawThree ? 212 : 128, height: 181, alignment: .leading)
    }
}

// MARK: - Foundation Pile View

public struct FoundationPileView: View {
    let pile: Pile
    let suit: Card.Suit
    public var isFocused: Bool = false
    public var isSelected: Bool = false
    // Point Highlights: the "+N"/"+$0.50" popup shown when this pile's top card is the
    // one the ViewModel just scored via (e.g. a move that just landed here).
    public var pointPopup: CardPointPopup? = nil
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    public var body: some View {
        if pile.isEmpty {
            EmptyPileView(symbol: "A", isFocused: isFocused, isSelected: isSelected)
        } else {
            CardView(
                card: pile.topCard!, isFocused: isFocused, isSelected: isSelected,
                pointPopupText: pointPopup?.cardId == pile.topCard!.id ? pointPopup?.displayText : nil
            )
                .gesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .global)
                        .onChanged { val in
                            onDragStarted(pile.topCard!, [pile.topCard!], val.startLocation)
                            onDragChanged(val.translation)
                        }
                        .onEnded { _ in
                            onDragEnded()
                        }
                )
        }
    }
}

// MARK: - Tableau Pile View (Vertical Stack)

public struct TableauPileView: View {
    let pile: Pile
    let draggedCardIDs: Set<UUID>
    let activeHint: GameViewModel.HintMove?
    public var isFocused: Bool = false
    public var focusedCardIndex: Int? = nil
    public var isSelected: Bool = false
    public var selectedCardIndex: Int? = nil
    // Point Highlights: the "+N"/"-N" popup shown when this pile's top card is the one
    // the ViewModel just scored via (a move landing here, or a revealed face-down card).
    public var pointPopup: CardPointPopup? = nil
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void

    private var totalHeight: CGFloat {
        if pile.isEmpty {
            return 181
        }
        return offsetForCard(at: pile.cards.count - 1) + 181
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
                
                let cardIsFocused = isFocused && index == focusedCardIndex
                let cardIsSelected = isSelected && index == selectedCardIndex
                let isTopCard = index == pile.cards.count - 1

                CardView(
                    card: card, isFocused: cardIsFocused, isSelected: cardIsSelected,
                    pointPopupText: isTopCard && pointPopup?.cardId == card.id ? pointPopup?.displayText : nil
                )
                    .modifier(HintHighlightModifier(isHighlighted: isCardHighlighted))
                    .opacity(draggedCardIDs.contains(card.id) ? 0.0 : 1.0)
                    .offset(y: offsetForCard(at: index))
                    .gesture(
                        DragGesture(minimumDistance: 5, coordinateSpace: .global)
                            .onChanged { val in
                                guard card.faceUp else { return }
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
                                if card.faceUp && index == pile.cards.count - 1 {
                                    onDoubleClick(card)
                                }
                            }
                    )
            }
        }
        .frame(width: 128, height: totalHeight, alignment: .top)
    }
    
    private func offsetForCard(at index: Int) -> CGFloat {
        var yOffset: CGFloat = 0
        for i in 0..<index {
            yOffset += pile.cards[i].faceUp ? 32 : 20
        }
        return yOffset
    }
}
