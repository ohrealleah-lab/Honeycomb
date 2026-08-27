import SwiftUI

struct BouncingCard: Identifiable {
    let id = UUID()
    let card: Card
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat  // pixels per second
    var vy: CGFloat  // pixels per second
    var trail: [CGPoint] = []
    // Cards only used to leave the animation by drifting off the left/right edge — a
    // card that spawns with vx already near 0 damps toward 0 further on every floor
    // bounce (vx *= 0.97 below) and can end up bouncing in place indefinitely,
    // never crossing leftLimit/rightLimit and blocking onFinished() forever. This is
    // the same hard age cutoff Windows' WinAnimationView already has (MaxCardLifetimeSeconds).
    var age: TimeInterval = 0
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

    // Matches Windows' WinAnimationView.MaxCardLifetimeSeconds (bumped from Windows'
    // original 9s to 15s — 9 cut cards off mid-bounce too eagerly).
    private static let maxCardLifetime: TimeInterval = 15

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
        for foundation in foundations {
            for rank in (1...13).reversed() {
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

        // Spawn a new card from the queue if interval elapsed and there's room under
        // the concurrent-card cap. Slowed further from the original 0.4s (then 0.6s) to
        // 0.9s per request — aiming for the classic Windows Solitaire cascade's
        // unhurried, one-card-at-a-time feel rather than a rapid-fire spawn (that game's
        // pace wasn't a fixed spec, it just landed there because its animation loop ran
        // uncapped against period CPU speed). Halved to 0.45s when there are more than 4
        // foundations (Beecell's 2-deck mode, 8 foundations/104 cards) so a bigger deck's
        // total spawn-out time stays roughly the same as a standard deck's, rather than
        // taking twice as long to empty — same ratio Windows' own port already uses for
        // its equivalent Spider case. maxActiveCards is a safety ceiling, not the pacing
        // mechanism: it only matters if it's too low relative to spawnInterval and
        // maxCardLifetime, which would stall spawning into strict one-out-one-in once
        // every slot is occupied by a still-bouncing card — same risk Windows' own
        // maxActiveCards comment describes for its equivalent cap.
        let spawnInterval: TimeInterval = foundations.count > 4 ? 0.45 : 0.9
        let maxActiveCards = foundations.count > 4 ? 40 : 20
        if !cardsQueue.isEmpty && activeCards.count < maxActiveCards
            && currentDate.timeIntervalSince(lastSpawnTime) > spawnInterval {
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
            bouncing.age += dt

            // Floor bounce
            let floorLimit = screenSize.height - cardHeight * 0.5
            if bouncing.y >= floorLimit {
                bouncing.y = floorLimit
                bouncing.vy = -abs(bouncing.vy) * elasticity
                bouncing.vx *= 0.97
            }

            let leftLimit = -cardWidth
            let rightLimit = screenSize.width + cardWidth
            let isOffScreen = bouncing.x <= leftLimit || bouncing.x >= rightLimit
            if !isOffScreen && bouncing.age < Self.maxCardLifetime {
                remainingCards.append(bouncing)
            }
        }

        activeCards = remainingCards

        if cardsQueue.isEmpty && activeCards.isEmpty {
            onFinished()
        }
    }
}
