import SwiftUI

@main
struct SoliBeeApp: App {
    @State private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            AppRouterView(coordinator: coordinator)
                .navigationTitle("Solibee Solitaire")
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    coordinator.startNewGame()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Restart Game") {
                    coordinator.restartCurrentGame()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Undo") {
                    coordinator.undoLastAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!coordinator.canUndo)
                
                Divider()
                
                Button("Draw 1 Card") {
                    if coordinator.gameMode == .klondike {
                        coordinator.klondikeViewModel.state.drawMode = .drawOne
                        coordinator.klondikeViewModel.startNewGame()
                    } else if coordinator.gameMode == .beecell {
                        coordinator.beecellViewModel.options.deckCount = 1
                        coordinator.beecellViewModel.startNewGame()
                    } else if coordinator.gameMode == .spider {
                        coordinator.spiderViewModel.options.suitCount = 1
                        coordinator.spiderViewModel.startNewGame()
                    }
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                
                Button("Draw 3 Cards") {
                    if coordinator.gameMode == .klondike {
                        coordinator.klondikeViewModel.state.drawMode = .drawThree
                        coordinator.klondikeViewModel.startNewGame()
                    } else if coordinator.gameMode == .beecell {
                        coordinator.beecellViewModel.options.deckCount = 2
                        coordinator.beecellViewModel.startNewGame()
                    } else if coordinator.gameMode == .spider {
                        coordinator.spiderViewModel.options.suitCount = 2
                        coordinator.spiderViewModel.startNewGame()
                    }
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                
                Divider()
                
                Button("Reset Statistics") {
                    coordinator.resetStatistics()
                }
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
    }
}
