import SwiftUI

struct AppRouterView: View {
    @Bindable var coordinator: AppCoordinator
    @State private var updateChecker = UpdateChecker.shared
    @Environment(\.openURL) private var openURL

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
        .animation(.easeInOut(duration: 0.25), value: coordinator.gameMode)
        .environment(coordinator)
        .alert(
            "Update Available",
            isPresented: Binding(
                get: { updateChecker.pendingAutomaticPrompt != nil },
                set: { if !$0 { updateChecker.dismissAutomaticPrompt() } }
            )
        ) {
            if let outcome = updateChecker.pendingAutomaticPrompt {
                Button("Don't Ask Again") { updateChecker.declineUpdate() }
                Button("View Release") { openURL(outcome.releaseURL) }
            }
        } message: {
            if let outcome = updateChecker.pendingAutomaticPrompt {
                Text("Version \(outcome.latestVersion) of Honeycomb is available. You're on \(updateChecker.currentVersion).")
            }
        }
    }
}
