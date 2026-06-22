import Foundation

struct AppCoordinatorTests {
    static func run() {
        testDefaultGameMode()
        testSwitchGameMode()
    }
    
    static func testDefaultGameMode() {
        let coordinator = AppCoordinator()
        assert(coordinator.gameMode == .klondike || coordinator.gameMode == .beecell, "Default game mode must be valid")
    }
    
    static func testSwitchGameMode() {
        let coordinator = AppCoordinator()
        coordinator.gameMode = .beecell
        assert(coordinator.gameMode == .beecell, "Game mode should change to beecell")
        
        coordinator.gameMode = .klondike
        assert(coordinator.gameMode == .klondike, "Game mode should change back to klondike")
    }
}
