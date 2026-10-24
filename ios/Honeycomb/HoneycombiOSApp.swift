import SwiftUI
import CoreText

@main
struct HoneycombiOSApp: App {
    @State private var coordinator: AppCoordinator

    init() {
        UISound.backend = IOSSoundBackend()
        _coordinator = State(initialValue: AppCoordinator())
        // Card rank-letter script font (see TouchCardView.swift) — not shipped on iOS by
        // default, so it's bundled (OFL-licensed, from Google Fonts) and registered here.
        for name in ["MarckScript-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            IOSRouterView(coordinator: coordinator)
                .environment(coordinator)
                // App-wide tint so toolbar buttons (Done/Cancel/Reset, etc.) render
                // with a real color instead of default black-on-glass, which was hard
                // to see against light menu backgrounds. Yellow text was worse (too
                // low-contrast to read on white) — standard iOS blue reads reliably.
                .tint(.blue)
        }
    }
}
