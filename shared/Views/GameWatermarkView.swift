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
/// Hidden entirely when coordinator.hideBee is on; otherwise scaled per the active
/// game's coordinator.currentGameWatermarkScale (see AppCoordinator's "Bee watermark
/// per-game scale" section — that value is TEMPORARY dev-calibration data for now).
struct GameWatermarkView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    var body: some View {
        if !coordinator.hideBee {
            #if os(iOS)
            if let image = WatermarkImage.cached {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(coordinator.currentGameWatermarkScale)
                    .opacity(0.15)
                    .allowsHitTesting(false)
            }
            #elseif canImport(AppKit)
            if let image = NSImage(named: "hcblack") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(coordinator.currentGameWatermarkScale)
                    .opacity(0.15)
                    .allowsHitTesting(false)
            }
            #endif
        }
    }
}
