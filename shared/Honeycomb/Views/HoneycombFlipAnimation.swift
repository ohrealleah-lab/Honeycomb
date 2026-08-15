import SwiftUI

// Deal-flip: reuses the exact same 3D flip mechanism as HoneycombCardView's own
// ownership/reveal flips (rotate 180° over HoneycombFlipTiming.duration, swap
// content at the edge-on midpoint, un-mirror the second half) rather than a
// separate SwiftUI transition — so every "a Honeycomb card turns over" moment in
// the app shares one implementation. `front` is the face-down placeholder shown
// before `isRevealed` flips true; `back` is the real, face-up interactive card.
// Shared by Mac's HoneycombView.swift and iOS's HoneycombTouchView.swift so the
// two platforms can't drift out of sync.
public struct HoneycombFlipContainer<Front: View, Back: View>: View {
    let isRevealed: Bool
    @ViewBuilder let front: () -> Front
    @ViewBuilder let back: () -> Back

    @State private var flipDegrees: Double = 0
    @State private var isPastMidpoint: Bool = false
    @State private var displayedRevealed: Bool

    public init(isRevealed: Bool, @ViewBuilder front: @escaping () -> Front, @ViewBuilder back: @escaping () -> Back) {
        self.isRevealed = isRevealed
        self.front = front
        self.back = back
        _displayedRevealed = State(initialValue: isRevealed)
    }

    public var body: some View {
        Group {
            if displayedRevealed { back() } else { front() }
        }
        .scaleEffect(x: isPastMidpoint ? -1 : 1, y: 1)
        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
        .onChange(of: isRevealed) { oldValue, newValue in
            guard oldValue != newValue else { return }
            withAnimation(.easeInOut(duration: HoneycombFlipTiming.duration)) {
                flipDegrees += 180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + HoneycombFlipTiming.midpointDelay) {
                displayedRevealed = newValue
                isPastMidpoint.toggle()
            }
        }
    }
}

// Nectar Exchange's Lift/Touchdown scale+shadow — 1.5x scale and a deep shadow
// while lifting/moving, smoothly back to 1.0x/no shadow on landing. zIndex lifts
// the animating card above the board cells its interpolated position passes over
// mid-flight (the hand columns sit either side of the board in the same HStack,
// so without this the card would render underneath the board during the cross).
// Shared by Mac's HoneycombView.swift and iOS's HoneycombTouchView.swift.
public struct SwapLiftEffect: ViewModifier {
    let isAnimating: Bool
    let phase: HoneycombViewModel.SwapAnimationPhase

    public init(isAnimating: Bool, phase: HoneycombViewModel.SwapAnimationPhase) {
        self.isAnimating = isAnimating
        self.phase = phase
    }

    private var isElevated: Bool {
        isAnimating && (phase == .lifting || phase == .moving)
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isElevated ? 1.5 : 1.0)
            .shadow(color: .black.opacity(isElevated ? 0.5 : 0), radius: isElevated ? 20 : 0)
            .zIndex(isAnimating ? 100 : 0)
    }
}
