import SwiftUI
import CoreText

@main
struct HoneycombiOSApp: App {
    @State private var coordinator: AppCoordinator

    init() {
        UISound.backend = IOSSoundBackend()
        _coordinator = State(initialValue: AppCoordinator())
        // Card rank-letter script candidates being compared against the system-
        // provided Noteworthy-Bold currently in use (see TouchCardView.swift) — mirrors
        // mac's own SoliBeeApp.swift font registration (Parisienne/LilyScriptOne), same
        // CoreText API, since neither of these ships on iOS by default. Both are OFL-
        // licensed, sourced from Google Fonts. Dancing Script is registered under its
        // variable font's own default-instance PostScript name ("DancingScript-
        // Regular") rather than one of its named Medium/SemiBold/Bold instances —
        // whether those are separately addressable via Font.custom on iOS, as opposed
        // to only the default instance, hasn't been confirmed live.
        for name in ["MarckScript-Regular", "DancingScript-Regular"] {
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
