import Foundation

struct AppCoordinatorTests {
    static func run() {
        testDefaultGameMode()
        testSwitchGameMode()
        testPreferencesSync()
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
    
    static func testPreferencesSync() {
        // Clear previous state for a clean test
        UserDefaults.standard.removeObject(forKey: "global_felt_color")
        UserDefaults.standard.removeObject(forKey: "cardBackTheme")
        UserDefaults.standard.removeObject(forKey: "solitaire_options")
        UserDefaults.standard.removeObject(forKey: "beecell_options")
        UserDefaults.standard.removeObject(forKey: "spider_options")
        UserDefaults.standard.removeObject(forKey: "videopoker_options")
        UserDefaults.standard.removeObject(forKey: "blackjack_options")
        UserDefaults.standard.removeObject(forKey: "pokerbee_options")
        UserDefaults.standard.removeObject(forKey: "tejas_options")
        
        // 1. Initialize coordinator
        let coordinator = AppCoordinator()
        
        // Verify defaults
        assert(coordinator.klondikeViewModel.options.feltColor == .feltGreen, "Default felt color should be feltGreen")
        assert(coordinator.klondikeViewModel.options.cardBackTheme == "Moogle", "Default card back theme should be Moogle")
        
        coordinator.klondikeViewModel.options.feltColor = .crimson
        coordinator.klondikeViewModel.options.cardBackTheme = "Vulpera"
        
        // Assert real-time propagation via notifications to Beecell and Spider ViewModels
        assert(coordinator.beecellViewModel.options.feltColor == .crimson, "Beecell felt color should sync to crimson")
        assert(coordinator.beecellViewModel.options.cardBackTheme == "Vulpera", "Beecell card back theme should sync to Vulpera")
        assert(coordinator.spiderViewModel.options.feltColor == .crimson, "Spider felt color should sync to crimson")
        assert(coordinator.spiderViewModel.options.cardBackTheme == "Vulpera", "Spider card back theme should sync to Vulpera")
        
        // 3. Change preferences on Beecell ViewModel
        coordinator.beecellViewModel.options.feltColor = .charcoal
        assert(coordinator.klondikeViewModel.options.feltColor == .charcoal, "Klondike felt color should sync to charcoal")
        assert(coordinator.spiderViewModel.options.feltColor == .charcoal, "Spider felt color should sync to charcoal")
        
        // 4. Change preferences on Spider ViewModel
        var spiderOpts = coordinator.spiderViewModel.options
        spiderOpts.cardBackTheme = "Moogle"
        coordinator.spiderViewModel.options = spiderOpts
        
        assert(coordinator.klondikeViewModel.options.cardBackTheme == "Moogle", "Klondike card back theme should sync back to Moogle")
        assert(coordinator.beecellViewModel.options.cardBackTheme == "Moogle", "Beecell card back theme should sync back to Moogle")
        
        // 5. Verify persistence in UserDefaults
        assert(UserDefaults.standard.string(forKey: "global_felt_color") == "charcoal", "Felt color should be persisted to UserDefaults")
        assert(UserDefaults.standard.string(forKey: "cardBackTheme") == "Moogle", "Card back theme should be persisted to UserDefaults")
        
        // 6. Verify persistence through relaunch (initializing a new AppCoordinator)
        let newCoordinator = AppCoordinator()
        assert(newCoordinator.klondikeViewModel.options.feltColor == .charcoal, "New Klondike VM should load charcoal felt color")
        assert(newCoordinator.klondikeViewModel.options.cardBackTheme == "Moogle", "New Klondike VM should load Moogle card back theme")
        assert(newCoordinator.beecellViewModel.options.feltColor == .charcoal, "New Beecell VM should load charcoal felt color")
        assert(newCoordinator.beecellViewModel.options.cardBackTheme == "Moogle", "New Beecell VM should load Moogle card back theme")
        assert(newCoordinator.spiderViewModel.options.feltColor == .charcoal, "New Spider VM should load charcoal felt color")
        assert(newCoordinator.spiderViewModel.options.cardBackTheme == "Moogle", "New Spider VM should load Moogle card back theme")
    }
}
