import SwiftUI

/// iOS counterpart of the mac app's AppRouterView: switches the visible game on
/// `coordinator.gameMode`, exactly like the mac router.
struct IOSRouterView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            coordinator.currentFeltColor.ignoresSafeArea()

            switch coordinator.gameMode {
            case .klondike:
                KlondikeTouchView(viewModel: coordinator.klondikeViewModel)
            case .beecell:
                BeecellTouchView(viewModel: coordinator.beecellViewModel)
            case .spider:
                SpiderTouchView(viewModel: coordinator.spiderViewModel)
            case .videoPoker, .blackjack:
                // Not offered on iOS (App Review no longer allows simulated-gambling
                // features under an individual developer account). Only reachable here
                // via a persisted gameMode from an older build — snap back to Klondike.
                Color.clear.onAppear { coordinator.gameMode = .klondike }
            case .honeycomb:
                HoneycombTouchView(viewModel: coordinator.honeycombViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.gameMode)
    }
}
