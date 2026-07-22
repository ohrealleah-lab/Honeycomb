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

    var body: some View {
        Color.clear
            .overlay(
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(CGFloat(background.scale))
                    .offset(x: CGFloat(background.offsetX) * offsetScale, y: CGFloat(background.offsetY) * offsetScale)
            )
            .clipped()
    }
}

/// The board's background layer — either the active custom background image, or the
/// standard felt color fallback (missing file, no background selected, etc.).
struct BackgroundLayerView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    @State private var loadTrigger: UUID = UUID()

    var body: some View {
        GeometryReader { geo in
            Group {
                if let background = coordinator.activeCustomBackground,
                   let image = CustomBackgroundManager.shared.image(for: background.relativePath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(CGFloat(background.scale))
                        .offset(x: CGFloat(background.offsetX), y: CGFloat(background.offsetY))
                        .clipped()
                } else {
                    coordinator.currentFeltColor
                }
            }
            .id(loadTrigger)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomBackgroundLoaded"))) { _ in
                loadTrigger = UUID()
            }
        }
    }
}
