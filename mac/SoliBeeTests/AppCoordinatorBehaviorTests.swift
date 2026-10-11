import Foundation
import SwiftUI

// What the app coordinator does for the player: remembers the last game and every look-and-feel
// setting across a relaunch, applies saved themes without corrupting other themes, stops the
// clock of the game you leave, and routes New Game / Restart / Undo / Reset Stats to the game
// that's on screen.
struct AppCoordinatorBehaviorTests {
    typealias Metric = ReferenceWritableKeyPath<AppCoordinator, Double>

    static let games = ["klondike", "beecell", "spider", "videoPoker", "blackjack", "honeycomb"]

    static var watermarkKeys: [String] {
        games.flatMap { g in
            ["watermark_scale_\(g)", "watermark_offsetX_\(g)", "watermark_offsetY_\(g)",
             "watermark_scale_landscape_\(g)", "watermark_offsetX_landscape_\(g)", "watermark_offsetY_landscape_\(g)"]
        }
    }

    // Everything AppCoordinator (and the six view models it builds) reads or writes.
    static var clearedKeys: [String] {
        [
            "selectedGameMode", "global_felt_color", "cardBackTheme", "showFeltVignette", "global_hide_bee", "appLanguage",
            "stayOnTop", "customCardColors", "custom_felt_red", "custom_felt_green", "custom_felt_blue", "custom_background_name",
            "solibee_themes", "solibee_active_theme_id", "solibee_deleted_default_themes",
            "solitaire_options", "solitaire_statistics", "gamesWon", "gamesPlayed", "highScore", "highScoreVegas",
            "beecell_options", "beecell_statistics", "spider_options", "spider_statistics",
            "videopoker_options", "videopoker_statistics", "blackjack_options", "blackjack_statistics",
        ] + watermarkKeys
    }

    // The Honeycomb view model and the face-art manager persist their own data when a
    // coordinator is built or a theme applied; keep the player's real copies safe.
    static let preservedKeys = [
        "honeycomb_stats", "honeycomb_options", "honeycomb_unlocked_cards", "honeycomb_saved_decks",
        "honeycomb_favorite_cards", "honeycomb_card_seed", "HoneycombFirstPlayedDate", "HoneycombHasShownOneYearBanner",
        "custom_face_arts",
    ]

    /// Fresh-install defaults, with ThemeManager and the face-art manager put back afterwards.
    static func sandbox(_ body: () -> Void) {
        withCleanDefaults(clearedKeys, preserving: preservedKeys) {
            let tm = ThemeManager.shared
            let savedThemes = tm.themes
            let savedActive = tm.activeThemeId
            let savedArts = CustomFaceCardArtManager.shared.faceArts
            defer {
                tm.themes = savedThemes
                tm.activeThemeId = savedActive
                CustomFaceCardArtManager.shared.restore(savedArts)
            }
            tm.themes = []
            tm.activeThemeId = nil
            body()
        }
    }

    static func run() {
        UISound.isHeadlessMode = true
        sandbox(testLastGameAndGameSwitching)
        sandbox(testWatermarkPositionsSavePerGameAndOrientation)
        sandbox(testLookAndFeelSettingsSurviveRelaunch)
        sandbox(testCorruptSavedSettingsFallBackToDefaults)
        sandbox(testSharedSettingsPassThroughToEveryGame)
        sandbox(testApplyingAndLiveSavingThemes)
        sandbox(testCancellingThemeEditsRestoresTheSavedTheme)
        sandbox(testNewGameRestartUndoAndResetRouteToTheVisibleGame)
        sandbox(testLeavingAGameStopsItsClockAndNoStressOnlyTouchesTheVisibleGame)
        sandbox(testWinAnimationHook)
    }

    // MARK: - Game switching

    static func testLastGameAndGameSwitching() {
        let c = AppCoordinator()
        expect(c.gameMode == .klondike, "Fresh install opens on Klondike")
        for mode in GameMode.allCases {
            c.gameMode = mode
            expect(UserDefaults.standard.string(forKey: "selectedGameMode") == mode.rawValue, "\(mode) is remembered as the last game")
            expect(AppCoordinator().gameMode == mode, "The app reopens on \(mode)")
        }
        UserDefaults.standard.set("Tejas Hold'em", forKey: "selectedGameMode")
        expect(AppCoordinator().gameMode == .klondike, "An unknown saved game (e.g. a retired one) opens Klondike")

        // Coming back to Video Poker / Blackjack with a finished round clears it.
        let r = AppCoordinator()
        r.videoPokerViewModel.deal()
        r.videoPokerViewModel.state.heldIndices = [0]
        r.videoPokerViewModel.draw()
        expect(r.videoPokerViewModel.state.phase == .result, "Video Poker round finished")
        r.gameMode = .videoPoker
        expect(r.videoPokerViewModel.state.phase == .deal && r.videoPokerViewModel.state.hand.isEmpty, "Entering Video Poker resets a finished round")
        r.blackjackViewModel.state.phase = .result
        r.blackjackViewModel.state.playerHands = [BlackjackHand(cards: [CovCards.card(.hearts, 10), CovCards.card(.spades, 9)], bet: 1)]
        r.gameMode = .blackjack
        expect(r.blackjackViewModel.state.phase == .betting && r.blackjackViewModel.state.playerHands.isEmpty, "Entering Blackjack resets a finished round")
        r.gameMode = .spider
        r.gameMode = .spider   // same game again: harmless
        expect(r.gameMode == .spider, "Re-selecting the current game is harmless")
    }

    // MARK: - Watermark positions

    static func testWatermarkPositionsSavePerGameAndOrientation() {
        let perGame: [(GameMode, [Metric])] = [
            (.klondike, [\.klondikeWatermarkScale, \.klondikeWatermarkOffsetX, \.klondikeWatermarkOffsetY,
                         \.klondikeWatermarkScaleLandscape, \.klondikeWatermarkOffsetXLandscape, \.klondikeWatermarkOffsetYLandscape]),
            (.beecell, [\.beecellWatermarkScale, \.beecellWatermarkOffsetX, \.beecellWatermarkOffsetY,
                        \.beecellWatermarkScaleLandscape, \.beecellWatermarkOffsetXLandscape, \.beecellWatermarkOffsetYLandscape]),
            (.spider, [\.spiderWatermarkScale, \.spiderWatermarkOffsetX, \.spiderWatermarkOffsetY,
                       \.spiderWatermarkScaleLandscape, \.spiderWatermarkOffsetXLandscape, \.spiderWatermarkOffsetYLandscape]),
            (.videoPoker, [\.videoPokerWatermarkScale, \.videoPokerWatermarkOffsetX, \.videoPokerWatermarkOffsetY,
                           \.videoPokerWatermarkScaleLandscape, \.videoPokerWatermarkOffsetXLandscape, \.videoPokerWatermarkOffsetYLandscape]),
            (.blackjack, [\.blackjackWatermarkScale, \.blackjackWatermarkOffsetX, \.blackjackWatermarkOffsetY,
                          \.blackjackWatermarkScaleLandscape, \.blackjackWatermarkOffsetXLandscape, \.blackjackWatermarkOffsetYLandscape]),
            (.honeycomb, [\.honeycombWatermarkScale, \.honeycombWatermarkOffsetX, \.honeycombWatermarkOffsetY,
                          \.honeycombWatermarkScaleLandscape, \.honeycombWatermarkOffsetXLandscape, \.honeycombWatermarkOffsetYLandscape]),
        ]
        let current: [Metric] = [\.currentGameWatermarkScale, \.currentGameWatermarkOffsetX, \.currentGameWatermarkOffsetY,
                                 \.currentGameWatermarkScaleLandscape, \.currentGameWatermarkOffsetXLandscape, \.currentGameWatermarkOffsetYLandscape]
        func value(_ gameIndex: Int, _ metricIndex: Int) -> Double { Double(gameIndex + 1) * 10 + Double(metricIndex) + 0.25 }

        let c = AppCoordinator()
        for entry in perGame {
            expect(entry.1.allSatisfy { c[keyPath: $0].isFinite }, "\(entry.0) has sane default bee positions")
        }
        for (g, entry) in perGame.enumerated() {
            c.gameMode = entry.0
            for (m, path) in current.enumerated() { c[keyPath: path] = value(g, m) }
        }
        // Each game kept its own values; editing one never touched another.
        for (g, entry) in perGame.enumerated() {
            for (m, path) in entry.1.enumerated() {
                expect(c[keyPath: path] == value(g, m), "\(entry.0) metric \(m) is its own value, got \(c[keyPath: path])")
            }
        }
        // …and they all come back after a relaunch.
        let again = AppCoordinator()
        for (g, entry) in perGame.enumerated() {
            for (m, path) in entry.1.enumerated() {
                expect(again[keyPath: path] == value(g, m), "\(entry.0) metric \(m) survives a relaunch, got \(again[keyPath: path])")
            }
        }
        for (g, entry) in perGame.enumerated() {
            again.gameMode = entry.0
            for (m, path) in current.enumerated() {
                expect(again[keyPath: path] == value(g, m), "currentGame accessor follows the visible game (\(entry.0), \(m))")
            }
        }
    }

    // MARK: - Look & feel

    static func testLookAndFeelSettingsSurviveRelaunch() {
        let c = AppCoordinator()
        expect(c.feltColor == .feltGreen && c.cardBackTheme == "Solibee" && c.showFeltVignette && !c.hideBee && c.language == .english && !c.stayOnTop,
               "Fresh install look: green felt, Solibee back, vignette on, bee shown, English")
        expect(c.customCardColors == CustomCardColorGroup() && c.customFeltRed == 0 && c.customBackgroundName == nil, "No custom colours or background")
        expect(c.currentFeltColor == FeltColorTheme.feltGreen.primaryColor, "Felt colour resolves to green")

        c.feltColor = .royalBlue
        c.cardBackTheme = "Moogle"
        c.showFeltVignette = false
        c.hideBee = true
        c.language = .spanish
        c.stayOnTop = true
        var colors = CustomCardColorGroup()
        colors.isEnabled = true; colors.bgRed = 0.3; colors.buttonBlue = 0.2
        c.customCardColors = colors
        c.customFeltRed = 0.6; c.customFeltGreen = 0.5; c.customFeltBlue = 0.4
        c.customBackgroundName = "Sunset"
        expect(BannerCatalog.currentLanguage == .spanish, "Changing the language switches the banner language right away")

        let again = AppCoordinator()
        expect(again.feltColor == .royalBlue && again.cardBackTheme == "Moogle", "Felt colour and card back survive a relaunch")
        expect(!again.showFeltVignette && again.hideBee && again.language == .spanish && again.stayOnTop, "Vignette, bee, language and stay-on-top survive")
        expect(again.customCardColors == colors, "Custom card colours survive")
        expect(again.customFeltRed == 0.6 && again.customFeltGreen == 0.5 && again.customFeltBlue == 0.4 && again.customBackgroundName == "Sunset",
               "Custom felt and background survive")
        expect(BannerCatalog.currentLanguage == .spanish, "...and the language is applied at launch")

        again.customBackgroundName = nil
        expect(UserDefaults.standard.object(forKey: "custom_background_name") == nil && AppCoordinator().customBackgroundName == nil,
               "Clearing the background forgets it")

        // currentFeltColor resolves the custom felt.
        again.feltColor = .custom
        expect(again.currentFeltColor == Color(red: 0.6, green: 0.5, blue: 0.4), "Custom felt colour is used")
        again.customFeltRed = 0; again.customFeltGreen = 0; again.customFeltBlue = 0
        expect(again.currentFeltColor == Color(red: 0.35, green: 0.15, blue: 0.45), "Unset custom felt shows the default purple")
        _ = again.currentAccentTint
        expect(again.activeCustomBackground == nil, "No active custom background")
    }

    static func testCorruptSavedSettingsFallBackToDefaults() {
        UserDefaults.standard.set("neon", forKey: "global_felt_color")
        UserDefaults.standard.set("klingon", forKey: "appLanguage")
        UserDefaults.standard.set(Data("junk".utf8), forKey: "customCardColors")
        let c = AppCoordinator()
        expect(c.feltColor == .feltGreen, "Unknown felt colour → green")
        expect(c.language == .english, "Unknown language → English")
        expect(c.customCardColors == CustomCardColorGroup(), "Unreadable custom colours → defaults")
    }

    // MARK: - Shared settings

    static func testSharedSettingsPassThroughToEveryGame() {
        let c = AppCoordinator()
        expect(c.isSoundEnabled && !c.noStressMode && c.honeyMode && !c.manuallyDismissBanners && !c.hideHintButton, "Shared settings start at their defaults")
        c.isSoundEnabled = false
        c.noStressMode = true
        c.honeyMode = false
        c.manuallyDismissBanners = true
        c.hideHintButton = true
        for vm in [c.klondikeViewModel.sharedOptions, c.beecellViewModel.sharedOptions, c.spiderViewModel.sharedOptions,
                   c.videoPokerViewModel.sharedOptions, c.blackjackViewModel.sharedOptions, c.honeycombViewModel.sharedOptions] {
            expect(!vm.isSoundEnabled && vm.noStressMode && !vm.honeyMode && vm.manuallyDismissBanners && vm.hideHintButton,
                   "Every game sees the same shared settings")
        }
        let again = AppCoordinator()
        expect(!again.isSoundEnabled && again.noStressMode && !again.honeyMode && again.manuallyDismissBanners && again.hideHintButton,
               "Shared settings survive a relaunch")
        expect(!UISound.isEnabled && !BannerCatalog.honeyModeEnabled, "...and are applied to the sound and banner systems")
    }

    // MARK: - Themes

    static func theme(_ name: String, back: String, felt: FeltColorTheme, rgb: (Double, Double, Double) = (0, 0, 0), colors: CustomCardColorGroup = CustomCardColorGroup()) -> SoliBeeTheme {
        SoliBeeTheme(name: name, cardBackTheme: back, feltColor: felt, customFeltRed: rgb.0, customFeltGreen: rgb.1, customFeltBlue: rgb.2,
                     faceArts: [], customCardColors: colors, customBackgroundName: nil)
    }

    /// Themes as JSON with sorted keys, so two encodings of the same themes compare equal.
    static func stableJSON(_ themes: [SoliBeeTheme]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(themes)) ?? Data()
    }

    static func testApplyingAndLiveSavingThemes() {
        let tm = ThemeManager.shared
        var vivid = CustomCardColorGroup(); vivid.isEnabled = true; vivid.bgRed = 0.5
        let a = theme("A", back: "Vulpera", felt: .crimson, colors: vivid)
        let b = theme("B", back: "Moogle", felt: .custom, rgb: (0.9, 0.8, 0.7))
        let c3 = theme("C", back: "Solibee", felt: .charcoal, rgb: (0.5, 0.5, 0.5))
        tm.themes = [a, b, c3]

        let c = AppCoordinator()
        c.applyTheme(a)
        expect(c.feltColor == .crimson && c.cardBackTheme == "Vulpera" && c.customCardColors == vivid && c.customBackgroundName == nil, "Applying a theme sets the look")
        expect(tm.activeThemeId == a.id && UserDefaults.standard.string(forKey: "solibee_active_theme_id") == a.id.uuidString, "...and remembers which theme is active")

        // Edits while a theme is active are saved into it (live), except the vignette.
        c.feltColor = .royalBlue
        c.cardBackTheme = "Pareidolic"
        expect(tm.themes.first { $0.id == a.id }?.feltColor == .royalBlue && tm.themes.first { $0.id == a.id }?.cardBackTheme == "Pareidolic",
               "Changing felt or card back updates the active theme")
        c.customFeltRed = 0.3; c.customFeltGreen = 0.2; c.customFeltBlue = 0.1
        c.customBackgroundName = "Sunset"
        var cc = vivid; cc.bgRed = 0.9
        c.customCardColors = cc
        let live = tm.themes.first { $0.id == a.id }
        expect(live?.customFeltRed == 0.3 && live?.customFeltGreen == 0.2 && live?.customFeltBlue == 0.1 && live?.customBackgroundName == "Sunset" && live?.customCardColors == cc,
               "...including custom felt, background and card colours")
        let before = stableJSON(tm.themes)
        c.showFeltVignette = false
        expect(stableJSON(tm.themes) == before, "The vignette isn't part of a theme")

        // Switching to another theme leaves the previous one exactly as the player left it.
        c.applyTheme(b)
        expect(tm.themes.first { $0.id == a.id }?.feltColor == .royalBlue && tm.themes.first { $0.id == a.id }?.customBackgroundName == "Sunset",
               "Applying theme B doesn't overwrite theme A")
        expect(c.feltColor == .custom && c.customFeltRed == 0.9 && c.customFeltGreen == 0.8 && c.customFeltBlue == 0.7 && tm.activeThemeId == b.id,
               "A custom-felt theme brings its own felt colour")
        c.applyTheme(c3)
        expect(c.feltColor == .charcoal && c.customFeltRed == 0.9, "A preset-felt theme leaves the custom felt colour alone")
        expect(tm.themes.first { $0.id == b.id }?.feltColor == .custom && tm.themes.first { $0.id == b.id }?.customFeltRed == 0.9,
               "...and theme B is intact")

        // With no active theme nothing is saved anywhere.
        tm.activeThemeId = nil
        let snapshot = stableJSON(tm.themes)
        c.feltColor = .desert
        c.cardBackTheme = "Forest"
        expect(stableJSON(tm.themes) == snapshot, "With no active theme, edits don't touch any saved theme")
    }

    static func testCancellingThemeEditsRestoresTheSavedTheme() {
        let tm = ThemeManager.shared
        let original = theme("Orig", back: "Moogle", felt: .royalBlue)
        tm.themes = [original]
        let c = AppCoordinator()
        c.applyTheme(original)

        // The player opens Preferences, tweaks things (each tweak saves into the theme), then cancels.
        c.feltColor = .crimson
        c.cardBackTheme = "Forest"
        c.showFeltVignette = false
        expect(tm.themes[0].feltColor == .crimson, "The tweak was live-saved into the theme")
        c.revertThemeEditing(feltColor: .royalBlue, cardBackTheme: "Moogle", showFeltVignette: true,
                             customCardColors: CustomCardColorGroup(), customBackgroundName: nil,
                             customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                             activeThemeId: original.id, activeThemeSnapshot: original)
        expect(c.feltColor == .royalBlue && c.cardBackTheme == "Moogle" && c.showFeltVignette, "Cancel puts the on-screen look back")
        expect(tm.themes[0].feltColor == .royalBlue && tm.themes[0].cardBackTheme == "Moogle", "...and puts the saved theme back too")
        expect(tm.activeThemeId == original.id, "...and the same theme is still active")

        // Cancelling after having switched themes mid-session goes back to the original active theme.
        let other = theme("Other", back: "Solibee", felt: .desert)
        tm.themes.append(other)
        c.applyTheme(other)
        c.revertThemeEditing(feltColor: .royalBlue, cardBackTheme: "Moogle", showFeltVignette: true,
                             customCardColors: CustomCardColorGroup(), customBackgroundName: nil,
                             customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                             activeThemeId: original.id, activeThemeSnapshot: original)
        expect(tm.activeThemeId == original.id && c.feltColor == .royalBlue, "Cancel undoes an Apply made during the session")

        // No theme was active when the session began.
        c.revertThemeEditing(feltColor: .feltGreen, cardBackTheme: "Solibee", showFeltVignette: true,
                             customCardColors: CustomCardColorGroup(), customBackgroundName: nil,
                             customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                             activeThemeId: nil, activeThemeSnapshot: nil)
        expect(tm.activeThemeId == nil && c.feltColor == .feltGreen && c.cardBackTheme == "Solibee", "Cancel with no theme active clears the active theme")
    }

    // MARK: - Routing

    static func testNewGameRestartUndoAndResetRouteToTheVisibleGame() {
        let c = AppCoordinator()

        // Klondike
        c.gameMode = .klondike
        let kStock = c.klondikeViewModel.state.stock.cards.map { $0.id }
        c.klondikeViewModel.drawCard()
        expect(c.canUndo, "Klondike: a draw can be undone")
        c.undoLastAction()
        expect(c.klondikeViewModel.state.stock.cards.map { $0.id } == kStock && !c.canUndo, "Undo reaches the Klondike game")
        c.klondikeViewModel.drawCard()
        c.restartCurrentGame()
        expect(c.klondikeViewModel.state.stock.cards.map { $0.id } == kStock, "Restart reaches the Klondike game")
        c.startNewGame()
        expect(c.klondikeViewModel.state.stock.cards.map { $0.id } != kStock, "New Game deals a fresh Klondike deal")
        c.resetStatistics()
        expect(c.klondikeViewModel.gamesPlayed == 0 && c.klondikeViewModel.gamesWon == 0, "Reset Stats reaches Klondike")

        // Spider
        c.gameMode = .spider
        let spiderCards = c.spiderViewModel.state.stock.cards.map { $0.id }
        c.spiderViewModel.drawFromStock()
        expect(c.canUndo, "Spider: a deal can be undone")
        c.undoLastAction()
        expect(c.spiderViewModel.state.stock.cards.map { $0.id } == spiderCards, "Undo reaches Spider")
        c.spiderViewModel.drawFromStock()
        c.restartCurrentGame()
        expect(c.spiderViewModel.state.stock.cards.map { $0.id } == spiderCards, "Restart reaches Spider")
        c.startNewGame()
        expect(c.spiderViewModel.state.stock.cards.map { $0.id } != spiderCards, "New Game reaches Spider")
        c.resetStatistics()
        expect(c.spiderViewModel.gamesPlayed == 0, "Reset Stats reaches Spider")

        // Beecell
        c.gameMode = .beecell
        let beeDeal = c.beecellViewModel.state.tableau.map { $0.cards.map { $0.id } }
        let top = c.beecellViewModel.state.tableau[0].cards.last!
        c.beecellViewModel.moveCards([top], from: c.beecellViewModel.state.tableau[0], to: c.beecellViewModel.state.freeCells[0])
        expect(c.canUndo, "Beecell: a move can be undone")
        c.undoLastAction()
        expect(c.beecellViewModel.state.tableau.map { $0.cards.map { $0.id } } == beeDeal, "Undo reaches Beecell")
        c.beecellViewModel.moveCards([top], from: c.beecellViewModel.state.tableau[0], to: c.beecellViewModel.state.freeCells[0])
        c.restartCurrentGame()
        expect(c.beecellViewModel.state.tableau.map { $0.cards.map { $0.id } } == beeDeal, "Restart reaches Beecell")
        c.startNewGame()
        expect(c.beecellViewModel.state.tableau.map { $0.cards.map { $0.id } } != beeDeal, "New Game reaches Beecell")
        c.resetStatistics()
        expect(c.beecellViewModel.currentModeStats == ModeStats(), "Reset Stats reaches Beecell")

        // Video Poker and Blackjack have no undo; New Game / Restart / Reset reach them.
        c.gameMode = .videoPoker
        expect(!c.canUndo, "Video Poker has no undo")
        c.undoLastAction()
        c.videoPokerViewModel.state.sessionCredits = 7
        c.startNewGame()
        expect(c.videoPokerViewModel.state.sessionCredits == c.videoPokerViewModel.options.startingCredits, "New Game reaches Video Poker")
        c.videoPokerViewModel.statistics.handsWon = 5
        c.resetStatistics()
        expect(c.videoPokerViewModel.statistics.handsWon == 0, "Reset Stats reaches Video Poker")
        c.videoPokerViewModel.state.sessionCredits = 7
        c.restartCurrentGame()
        expect(c.videoPokerViewModel.state.sessionCredits == c.videoPokerViewModel.options.startingCredits, "Restart reaches Video Poker")

        c.gameMode = .blackjack
        expect(!c.canUndo, "Blackjack has no undo")
        c.undoLastAction()
        c.blackjackViewModel.state.sessionCredits = 7
        c.startNewGame()
        expect(c.blackjackViewModel.state.sessionCredits == c.blackjackViewModel.options.startingCredits, "New Game reaches Blackjack")
        c.blackjackViewModel.statistics.handsWon = 5
        c.resetStatistics()
        expect(c.blackjackViewModel.statistics.handsWon == 0, "Reset Stats reaches Blackjack")
        c.blackjackViewModel.state.sessionCredits = 7
        c.restartCurrentGame()
        expect(c.blackjackViewModel.state.sessionCredits == c.blackjackViewModel.options.startingCredits, "Restart reaches Blackjack")

        // Honeycomb
        c.gameMode = .honeycomb
        expect(!c.canUndo, "Honeycomb has nothing to undo before a match")
        c.undoLastAction()
        c.honeycombViewModel.stats.matchesWon = 4
        c.resetStatistics()
        expect(c.honeycombViewModel.stats == HoneycombStats(), "Reset Stats reaches Honeycomb")
    }

    static func testLeavingAGameStopsItsClockAndNoStressOnlyTouchesTheVisibleGame() {
        let c = AppCoordinator()
        c.gameMode = .spider
        c.spiderViewModel.drawFromStock()
        expect(c.spiderViewModel.state.isTimerActive, "Spider's clock runs after the first move")
        c.gameMode = .klondike
        expect(!c.spiderViewModel.state.isTimerActive, "Leaving Spider stops its clock")
        c.gameMode = .beecell
        let top = c.beecellViewModel.state.tableau[0].cards.last!
        c.beecellViewModel.moveCards([top], from: c.beecellViewModel.state.tableau[0], to: c.beecellViewModel.state.freeCells[0])
        expect(c.beecellViewModel.state.isTimerActive, "Beecell's clock runs")
        c.gameMode = .klondike
        expect(!c.beecellViewModel.state.isTimerActive, "Leaving Beecell stops its clock")
        c.klondikeViewModel.drawCard()
        c.gameMode = .spider
        expect(!c.klondikeViewModel.state.isTimerActive, "Leaving Klondike stops its clock")

        // No Stress Mode toggled while Spider is on screen reaches Spider only.
        c.gameMode = .spider
        c.spiderViewModel.state.isTimerActive = false
        c.spiderViewModel.startTimerIfNeeded()
        c.spiderViewModel.state.timerSeconds = 12
        c.klondikeViewModel.state.timerSeconds = 9
        c.noStressMode = true
        expect(!c.spiderViewModel.state.isTimerActive && c.spiderViewModel.state.timerSeconds == 0, "No Stress on: the visible game's clock stops and zeroes")
        expect(c.klondikeViewModel.state.timerSeconds == 9 && !c.klondikeViewModel.state.isTimerActive, "...and a game in the background is left alone")
        c.noStressMode = false
        expect(c.spiderViewModel.state.isTimerActive, "No Stress off: the visible game's clock restarts")
        expect(!c.klondikeViewModel.state.isTimerActive, "...but not the background game's")
        c.spiderViewModel.stopTimer()

        // Video Poker / Blackjack / Honeycomb have no clock to react.
        c.gameMode = .videoPoker
        c.noStressMode = true
        c.noStressMode = false
        c.gameMode = .blackjack
        c.noStressMode = true
        c.gameMode = .honeycomb
        c.noStressMode = false
        expect(c.videoPokerViewModel.state.phase == .deal && c.blackjackViewModel.state.phase == .betting, "No Stress toggles are harmless on clock-less games")
    }

    // MARK: - Win animation

    static func testWinAnimationHook() {
        let c = AppCoordinator()
        c.gameMode = .klondike
        c.triggerWinAnimation()
        expect(c.klondikeViewModel.state.hasWon && c.klondikeViewModel.state.foundations.count == 4
               && c.klondikeViewModel.state.foundations.allSatisfy { $0.cards.count == 13 }, "Klondike win animation fills four foundations")
        c.gameMode = .beecell
        c.triggerWinAnimation()
        expect(c.beecellViewModel.state.hasWon && c.beecellViewModel.state.foundations.allSatisfy { $0.cards.count == 13 }, "Beecell win animation")
        c.gameMode = .spider
        c.triggerWinAnimation()
        expect(c.spiderViewModel.state.hasWon && c.spiderViewModel.state.foundations.allSatisfy { $0.cards.count == 13 }, "Spider win animation")
        c.gameMode = .videoPoker
        c.triggerWinAnimation()
        c.gameMode = .blackjack
        c.triggerWinAnimation()
        c.gameMode = .honeycomb
        c.triggerWinAnimation()
        expect(c.videoPokerViewModel.state.phase == .deal && c.blackjackViewModel.state.phase == .betting, "Poker, Blackjack and Honeycomb have no win cascade")
    }
}
