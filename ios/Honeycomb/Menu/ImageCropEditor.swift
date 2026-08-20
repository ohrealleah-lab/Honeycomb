import SwiftUI

/// Pinch-to-zoom + drag-to-reposition crop preview, shared by the card-back and face-
/// card-art import flows. The touch-native counterpart to mac's scale/offset sliders.
/// Scale/offset are read/written as bindings so callers can seed an existing crop
/// (re-editing) or start fresh (import).
struct ImageCropEditor: View {
    let image: UIImage
    let aspect: CGFloat // height / width
    @Binding var scale: CGFloat
    @Binding var offsetXFraction: CGFloat
    @Binding var offsetYFraction: CGFloat

    @GestureState private var pinchDelta: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero

    var width: CGFloat = 180

    // A real two-finger pinch usually spreads its touches wider than the crop box
    // itself — MagnifyGesture only recognizes a pinch whose touches land inside the
    // bounds of the view it's attached to, so gesture-recognizing only the box's own
    // small width/height (as this used to) meant a natural pinch easily put one or
    // both fingers outside the hit-testable area and the gesture never started. This
    // padding is invisible (added only to the hit area via an .overlay below, not to
    // the visible image) but gives the pinch plenty of room past the thumbnail's edges.
    private static let hitPadding: CGFloat = 80

    var body: some View {
        let height = width * aspect
        return GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale * pinchDelta)
                .offset(x: offsetXFraction * geo.size.width + dragDelta.width,
                        y: offsetYFraction * geo.size.height + dragDelta.height)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
        .overlay {
            // Overlay rather than growing this view's own .frame()/.contentShape()
            // directly — an overlay's content can extend past its container's bounds
            // for hit-testing without changing the container's own reported layout
            // size, so this doesn't push the "Reset Position" link or anything else
            // below it down the screen.
            Color.clear
                .frame(width: width + Self.hitPadding * 2, height: height + Self.hitPadding * 2)
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        // MagnifyGesture, not the older MagnificationGesture — on iOS 26
                        // the deprecated MagnificationGesture wasn't reliably recognized
                        // when combined with a DragGesture via SimultaneousGesture (pinch
                        // produced no scale change at all, only the drag component
                        // fired). MagnifyGesture's value is a struct with a
                        // `.magnification` field rather than a bare CGFloat.
                        MagnifyGesture()
                            .updating($pinchDelta) { value, state, _ in state = value.magnification }
                            .onEnded { value in
                                // Floor of 1.0, not 0.5 — .aspectRatio(.fill) already
                                // scales the image to exactly cover its frame at 1.0;
                                // going lower reopens a gap at the frame's edges (see
                                // IOSCustomBackground.swift's matching render-time clamp
                                // for the full explanation), so there's no framing
                                // benefit to allowing it, only a way to save a crop that
                                // silently breaks when re-rendered at a different aspect
                                // ratio (e.g. a background viewed in a new orientation).
                                scale = max(1.0, min(3.0, scale * value.magnification))
                            },
                        DragGesture()
                            .updating($dragDelta) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                offsetXFraction += value.translation.width / width
                                offsetYFraction += value.translation.height / height
                            }
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
