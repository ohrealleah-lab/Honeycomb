import SwiftUI

struct BouncingCard: Identifiable {
    let id = UUID()
    let card: Card
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var trail: [CGPoint] = []
}

public struct WinAnimationView: View {
    let foundations: [Pile]
    let onFinished: () -> Void
    
    @State private var activeCards: [BouncingCard] = []
    @State private var cardsQueue: [Card] = []
    @State private var lastSpawnTime: Date = Date()
    
    public init(foundations: [Pile], onFinished: @escaping () -> Void) {
        self.foundations = foundations
        self.onFinished = onFinished
    }
    
    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    // Update physics and draw trails
                    for index in activeCards.indices {
                        let card = activeCards[index]
                        
                        // Draw trail points (signature retro Solitaire cascade trail)
                        for point in card.trail {
                            if let symbol = context.resolveSymbol(id: card.id) {
                                context.draw(symbol, at: point)
                            }
                        }
                        
                        // Draw current position
                        if let symbol = context.resolveSymbol(id: card.id) {
                            context.draw(symbol, at: CGPoint(x: card.x, y: card.y))
                        }
                    }
                } symbols: {
                    ForEach(activeCards) { bouncing in
                        CardView(card: bouncing.card)
                            .tag(bouncing.id)
                    }
                }
                .onAppear {
                    setupAnimationQueue(screenSize: geo.size)
                }
                .onChange(of: timeline.date) { _, newDate in
                    updatePhysics(screenSize: geo.size, currentDate: newDate)
                }
            }
            .background(Color.clear)
        }
    }
    
    // MARK: - Setup Spawning Queue
    
    private func setupAnimationQueue(screenSize: CGSize) {
        // Collect cards from foundation in reverse order (Kings down to Aces)
        var queue: [Card] = []
        for rank in (1...13).reversed() {
            for foundation in foundations {
                if let card = foundation.cards.first(where: { $0.rank == rank }) {
                    queue.append(card)
                }
            }
        }
        self.cardsQueue = queue
        self.activeCards = []
        self.lastSpawnTime = Date()
    }
    
    // MARK: - Physics & Particle Updates
    
    private func updatePhysics(screenSize: CGSize, currentDate: Date) {
        // 1. Spawn a new card from the queue if interval elapsed
        if !cardsQueue.isEmpty && currentDate.timeIntervalSince(lastSpawnTime) > 0.4 {
            let nextCard = cardsQueue.removeFirst()
            
            // Determine starting foundation position (X coordinate)
            let foundationIndex = foundations.firstIndex { pile in
                pile.cards.contains { $0.id == nextCard.id }
            } ?? 0
            
            // Approximate screen locations for foundations (roughly in the right half of the board)
            let startX = screenSize.width * 0.5 + CGFloat(foundationIndex) * 98 + 40
            let startY: CGFloat = 80 // Foundation row height
            
            // Random horizontal speed, initial slight upward jump
            let vx = CGFloat.random(in: -4...4)
            let vy = CGFloat.random(in: -6...(-2))
            
            let bouncing = BouncingCard(card: nextCard, x: startX, y: startY, vx: vx, vy: vy)
            activeCards.append(bouncing)
            lastSpawnTime = currentDate
        }
        
        // 2. Physics logic loop
        let gravity: CGFloat = 0.28
        let elasticity: CGFloat = 0.85
        let cardWidth: CGFloat = 80
        let cardHeight: CGFloat = 112
        
        var remainingCards: [BouncingCard] = []
        
        for var bouncing in activeCards {
            // Append current position to trail (preserving history)
            bouncing.trail.append(CGPoint(x: bouncing.x, y: bouncing.y))
            if bouncing.trail.count > 50 {
                bouncing.trail.removeFirst()
            }
            
            // Update kinematics
            bouncing.x += bouncing.vx
            bouncing.y += bouncing.vy
            bouncing.vy += gravity
            
            // Floor bounce
            let floorLimit = screenSize.height - cardHeight * 0.5
            if bouncing.y >= floorLimit {
                bouncing.y = floorLimit
                bouncing.vy = -bouncing.vy * elasticity
            }
            
            // Keep active if it remains on-screen
            let leftLimit = -cardWidth
            let rightLimit = screenSize.width + cardWidth
            if bouncing.x > leftLimit && bouncing.x < rightLimit {
                remainingCards.append(bouncing)
            }
        }
        
        activeCards = remainingCards
        
        // 3. Trigger callback if queue and active animations have all completed
        if cardsQueue.isEmpty && activeCards.isEmpty {
            onFinished()
        }
    }
}
