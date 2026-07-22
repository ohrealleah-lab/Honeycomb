import SwiftUI
import CoreText

@main
struct SoliBeeApp: App {
    @State private var coordinator = AppCoordinator()

    init() {
        for name in ["Parisienne-Regular", "LilyScriptOne-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRouterView(coordinator: coordinator)
                .navigationTitle("Honeycomb Card Suite")
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    // Touching the singleton starts Sparkle's SPUStandardUpdaterController,
                    // which then owns its own automatic-check schedule (SUScheduledCheckInterval
                    // in Info.plist) and shows its own native alert when it finds something.
                    _ = UpdateChecker.shared
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    coordinator.startNewGame()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Restart") {
                    coordinator.restartCurrentGame()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Undo") {
                    coordinator.undoLastAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!coordinator.canUndo)

                Divider()

                Button("Reset Statistics") {
                    let alert = NSAlert()
                    alert.messageText = "Reset Statistics?"
                    alert.informativeText = "This will permanently clear all statistics for the current game. This cannot be undone."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Reset")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        coordinator.resetStatistics()
                    }
                }

                Button("Reset Default Card Backs") {
                    CustomCardBackManager.shared.resetDefaultCardBacks()
                }

                Divider()

                Button("Roll that beautiful bee footage") {
                    coordinator.triggerWinAnimation()
                }
            }

            CommandGroup(replacing: .appInfo) {
                AboutMenuCommand()
            }

            CommandGroup(replacing: .help) {
                HelpMenuCommands()
            }

            CommandGroup(replacing: .toolbar) {
                Toggle("Stay on Top", isOn: Binding(
                    get: { coordinator.stayOnTop },
                    set: { coordinator.stayOnTop = $0 }
                ))
            }
        }

        WindowGroup("Klondike Solitaire Help", id: "klondike-help") {
            KlondikeHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Freecell Help", id: "beecell-help") {
            BeecellHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Spider Solitaire Help", id: "spider-help") {
            SpiderHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Video Poker Help", id: "videopoker-help") {
            VideoPokerHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Video Blackjack Help", id: "blackjack-help") {
            BlackjackHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Honeycomb Help", id: "honeycomb-help") {
            HoneycombHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Themes Help", id: "themes-help") {
            ThemesHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("About Honeycomb", id: "about-honeycomb") {
            AboutHoneycombView()
        }
        .windowResizability(.contentSize)
    }
}

private struct AboutMenuCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About Honeycomb") { openWindow(id: "about-honeycomb") }
    }
}

private struct HelpMenuCommands: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Klondike Solitaire Help") { openWindow(id: "klondike-help") }
        Button("Freecell Help")            { openWindow(id: "beecell-help") }
        Button("Spider Solitaire Help")   { openWindow(id: "spider-help") }
        Button("Video Poker Help")        { openWindow(id: "videopoker-help") }
        Button("Video Blackjack Help")    { openWindow(id: "blackjack-help") }
        Button("Honeycomb Help")          { openWindow(id: "honeycomb-help") }
        Button("Themes Help")             { openWindow(id: "themes-help") }
    }
}
