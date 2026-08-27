import SwiftUI
import CoreText

// Opts out of macOS's secure-restorable-state machinery — a simple card game has
// no real use for window-restoration security, and this app doesn't need it.
// Added while investigating a multi-second launch stall that intermittently trips
// "Application Not Responding" on the Dock icon shortly after launch: the stall
// traces to AppKit's window/state-restoration bookkeeping and reproduces even in
// Apple's own TextEdit (there, on quit rather than launch, so it's not visibly
// flagged). This flag didn't reliably eliminate the stall in testing — it's kept
// anyway since it's a legitimate, zero-downside opt-out for an app like this one,
// not because it's confirmed to be the actual fix. The stall itself looks like a
// flaky, machine-level daemon issue outside this codebase's control.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }
}

@main
struct SoliBeeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()

    init() {
        UISound.backend = MacUISoundBackend()
        for name in ["Parisienne-Regular", "LilyScriptOne-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRouterView(coordinator: coordinator)
                .navigationTitle(coordinator.L(.appNavigationTitle))
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(coordinator.L(.newGame)) {
                    coordinator.startNewGame()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button(coordinator.L(.restart)) {
                    coordinator.restartCurrentGame()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button(coordinator.L(.undo)) {
                    coordinator.undoLastAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!coordinator.canUndo)

                Divider()

                Button(coordinator.L(.resetStatisticsTitle)) {
                    let alert = NSAlert()
                    alert.messageText = coordinator.L(.resetStatisticsTitle)
                    alert.informativeText = coordinator.L(.resetStatisticsBody)
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: coordinator.L(.reset))
                    alert.addButton(withTitle: coordinator.L(.cancel))
                    if alert.runModal() == .alertFirstButtonReturn {
                        coordinator.resetStatistics()
                    }
                }

                Button(coordinator.L(.resetDefaultCardBacks)) {
                    CustomCardBackManager.shared.resetDefaultCardBacks()
                }

                Divider()

            }

            CommandGroup(replacing: .appInfo) {
                AboutMenuCommand(coordinator: coordinator)
            }

            CommandGroup(replacing: .help) {
                HelpMenuCommands(coordinator: coordinator)
            }

            CommandGroup(replacing: .toolbar) {
                Toggle(coordinator.L(.stayOnTop), isOn: Binding(
                    get: { coordinator.stayOnTop },
                    set: { coordinator.stayOnTop = $0 }
                ))
            }

//            CommandMenu(coordinator.L(.debugBannersMenu)) {
//                DebugBannerCommands(coordinator: coordinator)
//            }
        }

        // Each of these is its own Scene/WindowGroup — SwiftUI's environment doesn't
        // propagate across sibling WindowGroups, so every one needs its own
        // .environment(coordinator), same as AppRouterView's for the main window.
        // Without this, @Environment(AppCoordinator.self) inside these views (used
        // for L()) fatal-errors at runtime the moment the window opens.
        WindowGroup(coordinator.L(.helpKlondike), id: "klondike-help") {
            KlondikeHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.helpFreecell), id: "beecell-help") {
            BeecellHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.helpSpider), id: "spider-help") {
            SpiderHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.helpVideopoker), id: "videopoker-help") {
            VideoPokerHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.helpBlackjack), id: "blackjack-help") {
            BlackjackHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.helpHoneycomb), id: "honeycomb-help") {
            HoneycombHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.helpThemes), id: "themes-help") {
            ThemesHelpView().environment(coordinator)
        }
        .windowResizability(.contentSize)

        WindowGroup(coordinator.L(.aboutHoneycomb), id: "about-honeycomb") {
            AboutHoneycombView().environment(coordinator)
        }
        .windowResizability(.contentSize)
    }
}

private struct AboutMenuCommand: View {
    @Environment(\.openWindow) private var openWindow
    let coordinator: AppCoordinator

    var body: some View {
        Button(coordinator.L(.aboutHoneycomb)) { openWindow(id: "about-honeycomb") }
    }
}

private struct HelpMenuCommands: View {
    @Environment(\.openWindow) private var openWindow
    let coordinator: AppCoordinator

    var body: some View {
        Button(coordinator.L(.helpKlondike))   { openWindow(id: "klondike-help") }
        Button(coordinator.L(.helpFreecell))   { openWindow(id: "beecell-help") }
        Button(coordinator.L(.helpSpider))     { openWindow(id: "spider-help") }
        Button(coordinator.L(.helpVideopoker)) { openWindow(id: "videopoker-help") }
        Button(coordinator.L(.helpBlackjack))  { openWindow(id: "blackjack-help") }
        Button(coordinator.L(.helpHoneycomb))  { openWindow(id: "honeycomb-help") }
        Button(coordinator.L(.helpThemes))     { openWindow(id: "themes-help") }
    }
}
