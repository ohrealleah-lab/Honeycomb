import SwiftUI

@main
struct SoliBeeApp: App {
    @State private var viewModel = GameViewModel()
    
    var body: some Scene {
        WindowGroup {
            GameView(viewModel: viewModel)
                .environment(viewModel)
                .navigationTitle("SoliBee Solitaire")
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    viewModel.startNewGame()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Restart Game") {
                    viewModel.restartCurrentGame()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Undo") {
                    viewModel.undoLastAction()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.canUndo)
                
                Divider()
                
                Button("Draw 1 Card") {
                    viewModel.state.drawMode = .drawOne
                    viewModel.startNewGame()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
                
                Button("Draw 3 Cards") {
                    viewModel.state.drawMode = .drawThree
                    viewModel.startNewGame()
                }
                .keyboardShortcut("3", modifiers: [.command, .option])
                
                Divider()
                
                Button("Reset Statistics") {
                    viewModel.resetStatistics()
                }
            }
            
            CommandGroup(replacing: .toolbar) {
                Button("Zoom In") {
                    viewModel.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Zoom Out") {
                    viewModel.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Reset Zoom") {
                    viewModel.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)
                
                Divider()
                
                Button("Make Current Zoom Default") {
                    viewModel.makeCurrentZoomDefault()
                }
            }
        }
    }
}
