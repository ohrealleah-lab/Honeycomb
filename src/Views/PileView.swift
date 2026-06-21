import SwiftUI

private struct FeltColorKey: EnvironmentKey {
    static let defaultValue: FeltColorTheme = .feltGreen
}

extension EnvironmentValues {
    public var feltColor: FeltColorTheme {
        get { self[FeltColorKey.self] }
        set { self[FeltColorKey.self] = newValue }
    }
}

// MARK: - Generic Empty Pile Placeholder

public struct EmptyPileView: View {
    @Environment(\.feltColor) private var feltColor
    let symbol: String?
    
    public init(symbol: String? = nil) {
        self.symbol = symbol
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(feltColor.statusBarColor)
            .frame(width: 80, height: 112)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
            )
            .overlay(
                Group {
                    if let sym = symbol {
                        Text(sym)
                            .font(.system(size: 32))
                            .foregroundColor(Color.white.opacity(0.2))
                    }
                }
            )
    }
}

// MARK: - Stock Pile View

public struct StockPileView: View {
    let pile: Pile
    let stackSpacing: CGFloat
    let canRecycle: Bool
    
    public var body: some View {
        ZStack {
            if pile.isEmpty {
                EmptyPileView(symbol: canRecycle ? "↺" : nil)
                    .transition(.opacity)
            } else {
                CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                    .transition(.asymmetric(
                        insertion: .offset(x: 80 + stackSpacing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: 80, height: 112)
        .contentShape(Rectangle())
    }
}

// MARK: - Waste Pile View

public struct WastePileView: View {
    let pile: Pile
    let isDrawThree: Bool
    let stackSpacing: CGFloat
    let draggedCardIDs: Set<UUID>
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    
    public var body: some View {
        ZStack {
            if pile.isEmpty {
                EmptyPileView()
                    .transition(.opacity)
            } else {
                ZStack {
                    if isDrawThree {
                        let maxShow = 3
                        let cardsToShow = Array(pile.cards.suffix(maxShow))
                        
                        ZStack(alignment: .leading) {
                            EmptyPileView()
                                .opacity(0)
                            
                            ForEach(Array(cardsToShow.enumerated()), id: \.element.id) { index, card in
                                CardView(card: card)
                                    .opacity(draggedCardIDs.contains(card.id) ? 0.0 : 1.0)
                                    .offset(x: CGFloat(index) * 26)
                                    .transition(.asymmetric(
                                        insertion: .offset(x: -(80 + stackSpacing) - CGFloat(index) * 26).combined(with: .opacity),
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
                        .frame(width: 80 + CGFloat(max(0, cardsToShow.count - 1)) * 26, height: 112, alignment: .leading)
                    } else {
                        if let topCard = pile.topCard {
                            CardView(card: topCard)
                                .id(topCard.id)
                                .opacity(draggedCardIDs.contains(topCard.id) ? 0.0 : 1.0)
                                .transition(.asymmetric(
                                    insertion: .offset(x: -(80 + stackSpacing)).combined(with: .opacity),
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
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .offset(x: -(80 + stackSpacing)).combined(with: .opacity)
                ))
            }
        }
        .frame(width: isDrawThree ? 132 : 80, height: 112, alignment: .leading)
    }
}

// MARK: - Foundation Pile View

public struct FoundationPileView: View {
    let pile: Pile
    let suit: Card.Suit
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    public var body: some View {
        if pile.isEmpty {
            EmptyPileView(symbol: "A")
        } else {
            CardView(card: pile.topCard!)
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
    let onDragStarted: (Card, [Card], CGPoint) -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onDoubleClick: (Card) -> Void
    
    public var body: some View {
        ZStack(alignment: .top) {
            EmptyPileView()
            
            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { index, card in
                CardView(card: card)
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
    }
    
    private func offsetForCard(at index: Int) -> CGFloat {
        var yOffset: CGFloat = 0
        for i in 0..<index {
            yOffset += pile.cards[i].faceUp ? 20 : 12
        }
        return yOffset
    }
}
