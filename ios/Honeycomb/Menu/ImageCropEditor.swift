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
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .updating($pinchDelta) { value, state, _ in state = value }
                    .onEnded { value in scale = max(0.5, min(3.0, scale * value)) },
                DragGesture()
                    .updating($dragDelta) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offsetXFraction += value.translation.width / width
                        offsetYFraction += value.translation.height / height
                    }
            )
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
