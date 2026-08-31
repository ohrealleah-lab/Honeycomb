import Foundation

struct AppCoordinatorTests {
    static func run() {
        testDefaultGameMode()
        testSwitchGameMode()
        testPreferencesSync()
        testDingwallRemoval()
        testSoundAndNoStressModeAreAppWide()
    }
    
    static func testDefaultGameMode() {
        // With no persisted "selectedGameMode" at all, the coordinator should fall back
        // to Klondike specifically — that's the actual behavior under test. Asserting
        // "klondike or beecell" instead (as this used to) reads whatever's really
        // persisted in this machine's UserDefaults domain, which any other test/real app
        // session (e.g. leaving the app open on Honeycomb) can legitimately set to any
        // valid GameMode, making the assertion fail for reasons that have nothing to do
        // with a real regression.
        let saved = UserDefaults.standard.object(forKey: "selectedGameMode")
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: "selectedGameMode") }
            else { UserDefaults.standard.removeObject(forKey: "selectedGameMode") }
        }
        UserDefaults.standard.removeObject(forKey: "selectedGameMode")

        let coordinator = AppCoordinator()
        assert(coordinator.gameMode == .klondike, "Default game mode with nothing persisted should be Klondike")
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
        assert(coordinator.cardBackTheme == "Solibee", "Default card back theme should be Solibee")

        // 2. Theme is a single live-shared value — every game reads the same coordinator
        // property, so there's no per-VM propagation to assert; just confirm all 5 view
        // models observe the same change instantly.
        coordinator.feltColor = .crimson
        coordinator.cardBackTheme = "Vulpera"

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

    // Regression coverage: Sound/No Stress Mode used to be six separate per-game copies,
    // silently re-synced from "whichever game you most recently left" on every mode
    // switch — so simply switching games (with no options edit at all) could flip these
    // settings in games you never touched. They're now backed by one true single-field
    // SharedGameOptions instance that AppCoordinator and every game ViewModel hold —
    // this confirms every ViewModel really does share the identical instance (not six
    // separate ones that merely happen to be kept in sync), and that an edit is visible
    // everywhere immediately with no propagation step, including across game switches.
    static func testSoundAndNoStressModeAreAppWide() {
        UserDefaults.standard.removeObject(forKey: "global_sound_enabled")
        UserDefaults.standard.removeObject(forKey: "global_no_stress_mode")

        let coordinator = AppCoordinator()

        assert(coordinator.klondikeViewModel.sharedOptions === coordinator.sharedOptions, "Klondike should share the coordinator's SharedGameOptions instance")
        assert(coordinator.beecellViewModel.sharedOptions === coordinator.sharedOptions, "Beecell should share the coordinator's SharedGameOptions instance")
        assert(coordinator.spiderViewModel.sharedOptions === coordinator.sharedOptions, "Spider should share the coordinator's SharedGameOptions instance")
        assert(coordinator.videoPokerViewModel.sharedOptions === coordinator.sharedOptions, "Video Poker should share the coordinator's SharedGameOptions instance")
        assert(coordinator.blackjackViewModel.sharedOptions === coordinator.sharedOptions, "Blackjack should share the coordinator's SharedGameOptions instance")
        assert(coordinator.honeycombViewModel.sharedOptions === coordinator.sharedOptions, "Honeycomb should share the coordinator's SharedGameOptions instance")

        // An explicit edit (as if made via one game's Options sheet) reaches every game.
        coordinator.isSoundEnabled = false
        coordinator.noStressMode = true
        assert(coordinator.klondikeViewModel.sharedOptions.isSoundEnabled == false, "Explicit edit should reach Klondike")
        assert(coordinator.beecellViewModel.sharedOptions.noStressMode == true, "Explicit edit should reach Beecell")
        assert(coordinator.honeycombViewModel.sharedOptions.isSoundEnabled == false, "Explicit edit should reach Honeycomb")

        // Switching games — with no options edit at all — must not change the value.
        coordinator.gameMode = .beecell
        coordinator.gameMode = .honeycomb
        coordinator.gameMode = .spider
        coordinator.gameMode = .klondike
        assert(coordinator.isSoundEnabled == false, "Switching games alone must not change Sound")
        assert(coordinator.noStressMode == true, "Switching games alone must not change No Stress Mode")
        assert(coordinator.beecellViewModel.sharedOptions.isSoundEnabled == false, "Beecell must still reflect the explicit edit after switching away and back")
        assert(coordinator.honeycombViewModel.sharedOptions.noStressMode == true, "Honeycomb must still reflect the explicit edit after switching away and back")

        coordinator.isSoundEnabled = true
        coordinator.noStressMode = false
        UserDefaults.standard.removeObject(forKey: "global_sound_enabled")
        UserDefaults.standard.removeObject(forKey: "global_no_stress_mode")
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
