import SwiftUI

struct AppRouterView: View {
    @Bindable var coordinator: AppCoordinator
    
    var body: some View {
        Group {
            switch coordinator.gameMode {
            case .klondike:
                GameView(viewModel: coordinator.klondikeViewModel)
                    .id(GameMode.klondike.rawValue)
            case .beecell:
                BeecellView(viewModel: coordinator.beecellViewModel)
                    .id(GameMode.beecell.rawValue)
            case .spider:
                SpiderView(viewModel: coordinator.spiderViewModel)
                    .id(GameMode.spider.rawValue)
            }
        }
        .environment(coordinator)
    }
}
