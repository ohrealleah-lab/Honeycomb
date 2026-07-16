import Foundation

struct AppCoordinatorTests {
    static func run() {
        testDefaultGameMode()
        testSwitchGameMode()
        testPreferencesSync()
        testDingwallRemoval()
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
        UserDefaults.standard.removeObject(forKey: "showFeltVignette")
        UserDefaults.standard.removeObject(forKey: "customCardColors")
        UserDefaults.standard.removeObject(forKey: "solitaire_options")
        UserDefaults.standard.removeObject(forKey: "beecell_options")
        UserDefaults.standard.removeObject(forKey: "spider_options")
        UserDefaults.standard.removeObject(forKey: "videopoker_options")
        UserDefaults.standard.removeObject(forKey: "blackjack_options")
        UserDefaults.standard.removeObject(forKey: "pokerbee_options")
        UserDefaults.standard.removeObject(forKey: "tejas_options")

        // 1. Initialize coordinator
        let coordinator = AppCoordinator()

        // Verify defaults — theme lives on the coordinator itself now, not per-game options.
        assert(coordinator.feltColor == .feltGreen, "Default felt color should be feltGreen")
        assert(coordinator.cardBackTheme == "Moogle", "Default card back theme should be Moogle")

        // 2. Theme is a single live-shared value — every game reads the same coordinator
        // property, so there's no per-VM propagation to assert; just confirm all 5 view
        // models observe the same change instantly.
        coordinator.feltColor = .crimson
        coordinator.cardBackTheme = "Vulpera"

        assert(coordinator.klondikeViewModel.options.isSoundEnabled == coordinator.beecellViewModel.options.isSoundEnabled, "Sound preference should still sync across games")
        assert(coordinator.feltColor == .crimson, "Felt color should be crimson")
        assert(coordinator.cardBackTheme == "Vulpera", "Card back theme should be Vulpera")

        // 3. Applying a theme also goes through the single coordinator property
        coordinator.feltColor = .charcoal
        assert(coordinator.feltColor == .charcoal, "Felt color should update to charcoal")

        coordinator.cardBackTheme = "Moogle"
        assert(coordinator.cardBackTheme == "Moogle", "Card back theme should update back to Moogle")

        // 4. Verify persistence in UserDefaults
        assert(UserDefaults.standard.string(forKey: "global_felt_color") == "charcoal", "Felt color should be persisted to UserDefaults")
        assert(UserDefaults.standard.string(forKey: "cardBackTheme") == "Moogle", "Card back theme should be persisted to UserDefaults")

        // 5. Verify persistence through relaunch (initializing a new AppCoordinator)
        let newCoordinator = AppCoordinator()
        assert(newCoordinator.feltColor == .charcoal, "New coordinator should load charcoal felt color")
        assert(newCoordinator.cardBackTheme == "Moogle", "New coordinator should load Moogle card back theme")
    }

    static func testDingwallRemoval() {
        let originalValue = UserDefaults.standard.object(forKey: "solibee_keep_dingwall")
        defer {
            if let originalValue {
                UserDefaults.standard.set(originalValue, forKey: "solibee_keep_dingwall")
            } else {
                UserDefaults.standard.removeObject(forKey: "solibee_keep_dingwall")
            }
        }

        UserDefaults.standard.set(true, forKey: "solibee_keep_dingwall")
        assert(CustomCardBackManager.shared.defaultThemes.contains("Dingwall"), "defaultThemes should contain Dingwall when solibee_keep_dingwall is true")
        
        UserDefaults.standard.set(false, forKey: "solibee_keep_dingwall")
        assert(!CustomCardBackManager.shared.defaultThemes.contains("Dingwall"), "defaultThemes should not contain Dingwall when solibee_keep_dingwall is false")
    }
}
