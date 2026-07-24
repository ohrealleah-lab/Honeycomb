import SwiftUI

@main
struct HoneycombiOSApp: App {
    @State private var coordinator: AppCoordinator

    init() {
        UISound.backend = IOSSoundBackend()
        _coordinator = State(initialValue: AppCoordinator())
    }

    var body: some Scene {
        WindowGroup {
            IOSRouterView(coordinator: coordinator)
                .environment(coordinator)
        }
    }
}
