import SwiftUI

/// iOS counterpart of the mac app's AppRouterView: switches the visible game on
/// `coordinator.gameMode`, exactly like the mac router. Game views are placeholders
/// until the touch-first layouts land (Phase 4 of the port).
struct IOSRouterView: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            coordinator.currentFeltColor.ignoresSafeArea()

            switch coordinator.gameMode {
            case .klondike:
                GamePlaceholderView(title: "Klondike")
            case .beecell:
                GamePlaceholderView(title: "BeeCell")
            case .spider:
                GamePlaceholderView(title: "Spider")
            case .videoPoker:
                GamePlaceholderView(title: "Video Poker")
            case .blackjack:
                GamePlaceholderView(title: "Blackjack")
            case .honeycomb:
                GamePlaceholderView(title: "Honeycomb")
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.gameMode)
    }
}

/// Temporary stand-in for a game's board view. Proves the shared coordinator,
/// routing, theme color, and game switching all work on iOS before the real
/// touch layouts are built.
struct GamePlaceholderView: View {
    @Environment(AppCoordinator.self) private var coordinator
    let title: String

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Touch layout coming soon")
                .foregroundStyle(.white.opacity(0.7))

            // Temporary switcher so game routing is testable before the
            // slide-down menu exists.
            Menu("Switch Game") {
                ForEach(GameMode.allCases) { mode in
                    Button(mode.displayName) {
                        coordinator.gameMode = mode
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
