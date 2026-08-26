import SwiftUI
#if os(iOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if os(iOS)
// Lazily loads and caches the watermark art bundled alongside mac's images (see
// project.yml's ../mac/images/backgrounds/hcblack.jpeg resource entry). Kept separate
// from BundledCardBackImage — this is watermark-only art, not a selectable card-back
// theme.
private enum WatermarkImage {
    static let cached: UIImage? = {
        guard let path = Bundle.main.path(forResource: "hcblack", ofType: "png") else { return nil }
        return UIImage(contentsOfFile: path)
    }()
}
#endif

/// Centered bee watermark drawn behind the board, shared by both platforms.
/// Hidden entirely when coordinator.hideBee is on; otherwise scaled/positioned per the
/// active game's calibrated coordinator.currentGameWatermarkScale/OffsetX/OffsetY (see
/// AppCoordinator's "Bee watermark per-game scale"/"per-game position" sections). iOS
/// additionally picks between the portrait and landscape value sets based on the
/// board's own rendered aspect ratio (via GeometryReader, not UIDevice.orientation —
/// more reliable across rotation lock/face-up/iPad multitasking) — mac has no
/// orientation concept, so it always uses the plain (portrait-named) properties.
struct GameWatermarkView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    var body: some View {
        if !coordinator.hideBee {
            #if os(iOS)
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                let scale = isLandscape ? coordinator.currentGameWatermarkScaleLandscape : coordinator.currentGameWatermarkScale
                let offsetX = isLandscape ? coordinator.currentGameWatermarkOffsetXLandscape : coordinator.currentGameWatermarkOffsetX
                let offsetY = isLandscape ? coordinator.currentGameWatermarkOffsetYLandscape : coordinator.currentGameWatermarkOffsetY
                if let image = WatermarkImage.cached {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(x: offsetX, y: offsetY)
                        .opacity(0.15)
                        .allowsHitTesting(false)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            #elseif canImport(AppKit)
            if let image = NSImage(named: "hcblack") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(coordinator.currentGameWatermarkScale)
                    .offset(x: coordinator.currentGameWatermarkOffsetX, y: coordinator.currentGameWatermarkOffsetY)
                    .opacity(0.15)
                    .allowsHitTesting(false)
            }
            #endif
        }
    }
}
