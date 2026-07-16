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
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: coordinator.gameMode)
        .environment(coordinator)
    }
}
