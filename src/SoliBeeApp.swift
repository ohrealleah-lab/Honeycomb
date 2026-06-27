import SwiftUI

@main
struct SoliBeeApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            AppRouterView(coordinator: coordinator)
                .navigationTitle("SoliBee Suite")
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

                Button("Play Winning Animation") {
                    coordinator.triggerWinAnimation()
                }
            }

            CommandGroup(replacing: .appInfo) {
                Button("About SoliBee") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }

            CommandGroup(replacing: .help) {
                HelpMenuCommands()
            }

            CommandGroup(replacing: .toolbar) {
                Button("Zoom In") {
                    coordinator.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    coordinator.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Zoom") {
                    coordinator.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Make Current Zoom Default") {
                    coordinator.makeCurrentZoomDefault()
                }
            }
        }

        WindowGroup("Klondike Solitaire Help", id: "klondike-help") {
            KlondikeHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Beecell Help", id: "beecell-help") {
            BeecellHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Spider Solibee Help", id: "spider-help") {
            SpiderHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Video Poker Help", id: "videopoker-help") {
            VideoPokerHelpView()
        }
        .windowResizability(.contentSize)

        WindowGroup("Blackjack Help", id: "blackjack-help") {
            BlackjackHelpView()
        }
        .windowResizability(.contentSize)
    }
}

private struct HelpMenuCommands: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Klondike Solitaire Help") { openWindow(id: "klondike-help") }
        Button("Beecell Help")            { openWindow(id: "beecell-help") }
        Button("Spider Solibee Help")     { openWindow(id: "spider-help") }
        Button("Video Poker Help")        { openWindow(id: "videopoker-help") }
        Button("Blackjack Help")          { openWindow(id: "blackjack-help") }
    }
}
