import SwiftUI

struct BouncingCard: Identifiable {
    let id = UUID()
    let card: Card
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat  // pixels per second
    var vy: CGFloat  // pixels per second
    var trail: [CGPoint] = []
}

public struct WinAnimationView: View {
    let foundations: [Pile]
    let pileFrames: [String: CGRect]
    let zoomScale: CGFloat
    let onFinished: () -> Void

    @State private var activeCards: [BouncingCard] = []
    @State private var cardsQueue: [Card] = []
    @State private var lastSpawnTime: Date = Date()
    @State private var lastFrameDate: Date? = nil

    public init(foundations: [Pile], pileFrames: [String: CGRect], zoomScale: CGFloat, onFinished: @escaping () -> Void) {
        self.foundations = foundations
        self.pileFrames = pileFrames
        self.zoomScale = zoomScale
        self.onFinished = onFinished
    }

    public var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    for card in activeCards {
                        // Draw trail points
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
                            .scaleEffect(zoomScale)
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
        .allowsHitTesting(false)
    }

    // MARK: - Setup Spawning Queue

    private func setupAnimationQueue(screenSize: CGSize) {
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
        self.lastFrameDate = nil
    }

    // MARK: - Physics & Particle Updates

    private func updatePhysics(screenSize: CGSize, currentDate: Date) {
        // Compute delta time, clamped to avoid large jumps on first frame or after pauses
        let dt: CGFloat
        if let last = lastFrameDate {
            dt = CGFloat(min(currentDate.timeIntervalSince(last), 1.0 / 30.0))
        } else {
            dt = 1.0 / 60.0
        }
        lastFrameDate = currentDate

        // Spawn a new card from the queue if interval elapsed
        if !cardsQueue.isEmpty && currentDate.timeIntervalSince(lastSpawnTime) > 0.4 {
            let nextCard = cardsQueue.removeFirst()

            let foundationIndex = foundations.firstIndex { pile in
                pile.cards.contains { $0.id == nextCard.id }
            } ?? 0

            let pileId = foundations[foundationIndex].id
            let startX: CGFloat
            let startY: CGFloat
            if let frame = pileFrames[pileId] {
                startX = frame.midX
                startY = frame.midY
            } else {
                startX = screenSize.width * 0.5 + CGFloat(foundationIndex) * 98 + 40
                startY = 80
            }

            // Velocities in pixels per second (equivalent to original ±4 and -6…-2 px/frame @ 60 fps)
            let vx = CGFloat.random(in: -240...240)
            let vy = CGFloat.random(in: -360...(-120))

            activeCards.append(BouncingCard(card: nextCard, x: startX, y: startY, vx: vx, vy: vy))
            lastSpawnTime = currentDate
        }

        // Physics constants (pixels/s and pixels/s²)
        let gravity: CGFloat = 980     // ≈ 0.28 px/frame² × 60² fps
        let elasticity: CGFloat = 0.85
        let cardWidth: CGFloat = 128 * zoomScale
        let cardHeight: CGFloat = 181 * zoomScale

        var remainingCards: [BouncingCard] = []

        for var bouncing in activeCards {
            bouncing.trail.append(CGPoint(x: bouncing.x, y: bouncing.y))
            if bouncing.trail.count > 50 {
                bouncing.trail.removeFirst()
            }

            // Integrate with dt for frame-rate-independent motion
            bouncing.x += bouncing.vx * dt
            bouncing.y += bouncing.vy * dt
            bouncing.vy += gravity * dt

            // Floor bounce
            let floorLimit = screenSize.height - cardHeight * 0.5
            if bouncing.y >= floorLimit {
                bouncing.y = floorLimit
                bouncing.vy = -abs(bouncing.vy) * elasticity
                bouncing.vx *= 0.97
            }

            let leftLimit = -cardWidth
            let rightLimit = screenSize.width + cardWidth
            if bouncing.x > leftLimit && bouncing.x < rightLimit {
                remainingCards.append(bouncing)
            }
        }

        activeCards = remainingCards

        if cardsQueue.isEmpty && activeCards.isEmpty {
            onFinished()
        }
    }
}
