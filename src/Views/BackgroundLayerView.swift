import SwiftUI
import AppKit

/// Renders a CustomBackground image with its scale/offset applied, always filling the
/// container (aspect fill, cropping overflow). Shared between the live board (full
/// window) and the editor's small mock preview so the two can never drift out of sync —
/// same code path, different frame size.
struct CustomBackgroundRenderView: View {
    let background: CustomBackground
    let image: NSImage
    // Offsets are stored in full-board point space. The small mock editor preview passes
    // a fraction here (previewWidth / referenceBoardWidth) so a saved offset looks
    // proportionally the same in both places — same idea as CardBackPreviewView's
    // (60.0 / 128.0) normalization for its smaller card thumbnail. The live board leaves
    // this at 1.0 (full scale, no normalization needed).
    var offsetScale: CGFloat = 1.0

    // Measured once via the hidden GeometryReader probe below and cached, rather than
    // wrapping the image directly in a GeometryReader — that used to force a fresh
    // layout/measurement pass on every re-render (e.g. every mouse-move frame during a
    // card drag), even though the container size is unchanged except on window resize.
    @State private var containerSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color.clear
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { containerSize = geo.size }
                            .onChange(of: geo.size) { _, newSize in containerSize = newSize }
                    }
                )

            if containerSize != .zero {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: containerSize.width, height: containerSize.height)
                    .scaleEffect(CGFloat(background.scale))
                    .offset(x: CGFloat(background.offsetX) * offsetScale, y: CGFloat(background.offsetY) * offsetScale)
                    .clipped()
            }
        }
    }
}

/// The board's background layer — either the active custom background image, or the
/// standard felt color fallback (missing file, no background selected, etc.).
struct BackgroundLayerView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    var body: some View {
        if let background = coordinator.activeCustomBackground,
           let image = CustomBackgroundManager.shared.image(for: background.relativePath) {
            CustomBackgroundRenderView(background: background, image: image)
        } else {
            coordinator.currentFeltColor
        }
    }
}
