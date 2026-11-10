import SwiftUI

struct AppRouterView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            switch coordinator.gameMode {
            case .klondike:
                GameView(viewModel: coordinator.klondikeViewModel)
                    .id(GameMode.klondike.rawValue)
                    .transition(.opacity)
            case .beecell:
                BeecellView(viewModel: coordinator.beecellViewModel)
                    .id(GameMode.beecell.rawValue)
                    .transition(.opacity)
            case .spider:
                SpiderView(viewModel: coordinator.spiderViewModel)
                    .id(GameMode.spider.rawValue)
                    .transition(.opacity)
            case .videoPoker:
                VideoPokerView(viewModel: coordinator.videoPokerViewModel)
                    .id(GameMode.videoPoker.rawValue)
                    .transition(.opacity)
            case .blackjack:
                BlackjackView(viewModel: coordinator.blackjackViewModel)
                    .id(GameMode.blackjack.rawValue)
                    .transition(.opacity)
            case .honeycomb:
                HoneycombView(viewModel: coordinator.honeycombViewModel)
                    .id(GameMode.honeycomb.rawValue)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .background(TransparentWindowApplier(isTransparent: coordinator.isTransparentTable))
        // Faint edge so a fully clear window is still findable and draggable.
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                .allowsHitTesting(false)
                .opacity(coordinator.isTransparentTable ? 1 : 0)
                // Trace the real window edge, not the area below the title bar.
                .ignoresSafeArea()
        )
        .animation(.easeInOut(duration: 0.25), value: coordinator.gameMode)
        .environment(coordinator)
    }
}
