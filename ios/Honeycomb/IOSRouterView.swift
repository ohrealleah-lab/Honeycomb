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
            case .videoPoker:
                VideoPokerTouchView(viewModel: coordinator.videoPokerViewModel)
            case .blackjack:
                BlackjackTouchView(viewModel: coordinator.blackjackViewModel)
            case .honeycomb:
                HoneycombTouchView(viewModel: coordinator.honeycombViewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.gameMode)
    }
}
