import Foundation
import SwiftUI
import AppKit

// Settings, themes and saved stats: every saved format must keep decoding the way old
// versions wrote it (missing fields take defaults, garbage falls back instead of crashing),
// and changes must survive a relaunch.
struct SettingsPersistenceTests {
    static func run() {
        UISound.isHeadlessMode = true
        testPerGameOptionsDecodeOldSaves()
        testStatsDecodeOldSaves()
        testSharedGameOptionsDefaultsPersistenceAndSideEffects()
        testFeltColorThemes()
        testCustomCardColorGroupSavesAndOldSaves()
        testSavedThemesDecodeOldSavesAndKeepFaceArtSlotNames()
        testThemeManagerLifecycle()
        testThemeManagerCleansUpDeletedAssets()
        testGameModeNames()
    }

    static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        try? JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - Per-game options

    static func testPerGameOptionsDecodeOldSaves() {
        // Klondike
        expect(decode(GameOptions.self, "{}") == GameOptions(), "An empty Klondike save decodes to the defaults")
        let partial = decode(GameOptions.self, "{\"isVegasScoring\":true,\"drawMode\":\"drawOne\"}")
        expect(partial?.isVegasScoring == true && partial?.drawMode == .drawOne && partial?.isTimed == true && partial?.isStatusBarVisible == true && partial?.deckCount == 1,
               "A partial Klondike save keeps what it has and defaults the rest")
        let wrongType = decode(GameOptions.self, "{\"isTimed\":\"yes\",\"drawMode\":\"sideways\",\"deckCount\":\"two\"}")
        expect(wrongType == GameOptions(), "Wrong-typed values fall back to defaults instead of failing the whole save")
        var full = GameOptions(isTimed: false, isStatusBarVisible: false, isVegasScoring: true, isDrawConstraintsEnabled: true, deckCount: 2, drawMode: .drawOne)
        let roundTrip = (try? JSONEncoder().encode(full)).flatMap { try? JSONDecoder().decode(GameOptions.self, from: $0) }
        expect(roundTrip == full, "Klondike options round-trip")
        full.drawMode = .drawThree
        expect(roundTrip != full, "...and differ when changed")

        // Spider
        expect(decode(SpiderOptions.self, "{}") == SpiderOptions(), "Empty Spider save → defaults (1 suit)")
        expect(decode(SpiderOptions.self, "{\"suitCount\":4}") == SpiderOptions(suitCount: 4, isTimed: true), "Spider keeps the saved suit count")
        let spiderRT = (try? JSONEncoder().encode(SpiderOptions(suitCount: 2, isTimed: false))).flatMap { try? JSONDecoder().decode(SpiderOptions.self, from: $0) }
        expect(spiderRT == SpiderOptions(suitCount: 2, isTimed: false), "Spider options round-trip")

        // Beecell
        expect(decode(BeecellOptions.self, "{}") == BeecellOptions(), "Empty Beecell save → defaults (1 deck)")
        expect(decode(BeecellOptions.self, "{\"deckCount\":2}")?.deckCount == 2, "Beecell keeps 2 decks")
        let beeRT = (try? JSONEncoder().encode(BeecellOptions(deckCount: 2, isTimed: false))).flatMap { try? JSONDecoder().decode(BeecellOptions.self, from: $0) }
        expect(beeRT == BeecellOptions(deckCount: 2, isTimed: false), "Beecell options round-trip")

        // Video Poker & Blackjack
        let vp = decode(VideoPokerOptions.self, "{}")
        expect(vp == VideoPokerOptions() && vp?.variant == .jacksOrBetter && vp?.playMode == .single && vp?.startingCredits == 100 && vp?.betPerHand == 1,
               "Empty Video Poker save → defaults")
        let vp2 = decode(VideoPokerOptions.self, "{\"variant\":\"Bonus Poker\",\"startingCredits\":300}")
        expect(vp2?.variant == .bonusPoker && vp2?.startingCredits == 300 && vp2?.betPerHand == 1, "Partial Video Poker save")
        expect(decode(BlackjackOptions.self, "{}") == BlackjackOptions() && decode(BlackjackOptions.self, "{\"startingCredits\":42}")?.startingCredits == 42,
               "Blackjack options decode")
        expect(VideoPokerVariant.allCases.count == 3 && VideoPokerPlayMode.allCases.count == 2 && !VideoPokerPlayMode.tripleEnabled,
               "Three variants; Triple Play stays hidden")
    }

    static func testStatsDecodeOldSaves() {
        let g = decode(GameStatistics.self, "{\"gamesWon\":4}")
        expect(g?.gamesWon == 4 && g?.gamesPlayed == 0 && g?.currentStreak == 0 && g?.shortestWinTime == 0, "Sparse Klondike stats decode")
        expect(decode(GameStatistics.self, "{}") == GameStatistics(), "Empty Klondike stats → zeros")
        var s = GameStatistics(gamesPlayed: 10, gamesWon: 4, currentStreak: 2, longestStreak: 3, totalWinningTime: 300, winningGamesCount: 3, shortestWinTime: 70)
        let rt = (try? JSONEncoder().encode(s)).flatMap { try? JSONDecoder().decode(GameStatistics.self, from: $0) }
        expect(rt == s, "Klondike stats round-trip")
        expect(s.winPercentage == 40.0 && s.averageWinningTime == 100.0, "Win % and average time")
        s.gamesPlayed = 0
        expect(s.winPercentage == 0, "No games → 0%")

        let sp = decode(SpiderModeStats.self, "{\"gamesWon\":2}")
        expect(sp?.gamesWon == 2 && sp?.highScore == 500, "Sparse Spider mode stats default the high score to 500")
        let spiderAll = SpiderStatistics(statsBySuits: [1: SpiderModeStats(gamesPlayed: 3, gamesWon: 2), 4: SpiderModeStats(highScore: 900)])
        let spiderRT = (try? JSONEncoder().encode(spiderAll)).flatMap { try? JSONDecoder().decode(SpiderStatistics.self, from: $0) }
        expect(spiderRT == spiderAll, "Per-suit Spider stats round-trip")
        let mode = decode(ModeStats.self, "{\"highScore\":55}")
        expect(mode?.highScore == 55 && mode?.gamesWon == 0, "Sparse Beecell mode stats decode")
        let beeAll = BeecellStatistics(statsByMode: ["1deck": ModeStats(gamesWon: 5), "2deck": ModeStats(currentStreak: 2)])
        let beeRT = (try? JSONEncoder().encode(beeAll)).flatMap { try? JSONDecoder().decode(BeecellStatistics.self, from: $0) }
        expect(beeRT == beeAll, "Per-deck Beecell stats round-trip")
        expect(decode(VideoPokerStatistics.self, "{}")?.handsPlayed == 0 && decode(BlackjackStatistics.self, "{}")?.handsPlayed == 0, "Empty casino stats decode")
        let bj = decode(BlackjackStatistics.self, "{\"blackjacks\":3,\"pushes\":1}")
        expect(bj?.blackjacks == 3 && bj?.pushes == 1 && bj?.handsWon == 0, "Sparse Blackjack stats decode")
    }

    // MARK: - Shared options

    static func testSharedGameOptionsDefaultsPersistenceAndSideEffects() {
        withCleanDefaults([]) {
            let o = SharedGameOptions()
            expect(o.isSoundEnabled && !o.noStressMode && o.honeyMode && !o.manuallyDismissBanners && !o.hideHintButton,
                   "Fresh install: sound on, No Stress off, Honey Mode on, banners auto-dismiss, Hint button shown")
            expect(UISound.isEnabled && BannerCatalog.honeyModeEnabled, "...and the app-wide switches follow")

            var fired = 0
            o.onNoStressModeChange = { fired += 1 }
            o.noStressMode = true
            expect(fired == 1, "Turning No Stress on notifies the active game")
            o.noStressMode = true
            expect(fired == 1, "Setting it to the same value notifies nobody")
            o.noStressMode = false
            expect(fired == 2, "Turning it off notifies again")
            o.noStressMode = true

            o.isSoundEnabled = false
            expect(!UISound.isEnabled, "Muting Sound mutes the app")
            o.honeyMode = false
            expect(!BannerCatalog.honeyModeEnabled, "Honey Mode off switches off flavor banners")
            o.manuallyDismissBanners = true
            o.hideHintButton = true

            let again = SharedGameOptions()
            expect(!again.isSoundEnabled && again.noStressMode && !again.honeyMode && again.manuallyDismissBanners && again.hideHintButton,
                   "Every shared setting survives a relaunch")
            expect(!UISound.isEnabled && !BannerCatalog.honeyModeEnabled, "...and re-applies the app-wide switches at launch")
        }
    }

    // MARK: - Felt colours

    static func rgb(_ color: Color) -> (r: Double, g: Double, b: Double) {
        guard let c = NSColor(color).usingColorSpace(.deviceRGB) else { return (-1, -1, -1) }
        return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }

    static func testFeltColorThemes() {
        withCleanDefaults(["custom_felt_red", "custom_felt_green", "custom_felt_blue"]) {
            expect(FeltColorTheme.allCases.count == 6, "Six felt colours")
            for theme in FeltColorTheme.allCases {
                let json = (try? JSONEncoder().encode(theme)).flatMap { try? JSONDecoder().decode(FeltColorTheme.self, from: $0) }
                expect(json == theme, "\(theme) round-trips")
            }
            expect(FeltColorTheme.feltGreen.primaryColor == Color(red: 0.0, green: 0.5, blue: 0.0), "Felt green")
            expect(FeltColorTheme.crimson.primaryColor == Color(red: 0.55, green: 0.05, blue: 0.15), "Crimson")
            expect(FeltColorTheme.royalBlue.primaryColor == Color(red: 0.1, green: 0.2, blue: 0.5), "Royal blue")
            expect(FeltColorTheme.charcoal.primaryColor == Color(red: 0.18, green: 0.18, blue: 0.18), "Charcoal")
            expect(FeltColorTheme.desert.primaryColor == Color(red: 0.76, green: 0.59, blue: 0.48), "Desert")
            expect(FeltColorTheme.feltGreen.statusBarColor == Color(red: 0.0, green: 0.45, blue: 0.0), "Felt green status bar is a touch darker")
            expect(FeltColorTheme.crimson.statusBarColor != FeltColorTheme.crimson.primaryColor && FeltColorTheme.royalBlue.statusBarColor != FeltColorTheme.royalBlue.primaryColor
                   && FeltColorTheme.charcoal.statusBarColor != FeltColorTheme.charcoal.primaryColor && FeltColorTheme.desert.statusBarColor != FeltColorTheme.desert.primaryColor,
                   "Every preset has its own status-bar shade")

            // Custom felt: purple until the player picks something.
            expect(FeltColorTheme.custom.primaryColor == Color(red: 0.35, green: 0.15, blue: 0.45), "Unset custom felt shows the default purple")
            expect(FeltColorTheme.custom.statusBarColor == Color(red: 0.3, green: 0.12, blue: 0.38), "...with a matching status bar")
            UserDefaults.standard.set(0.8, forKey: "custom_felt_red")
            UserDefaults.standard.set(0.4, forKey: "custom_felt_green")
            UserDefaults.standard.set(0.2, forKey: "custom_felt_blue")
            expect(FeltColorTheme.custom.primaryColor == Color(red: 0.8, green: 0.4, blue: 0.2), "Custom felt uses the saved colour")
            let bar = rgb(FeltColorTheme.custom.statusBarColor)
            expect(abs(bar.r - 0.75) < 0.01 && abs(bar.g - 0.35) < 0.01 && abs(bar.b - 0.15) < 0.01, "...status bar 0.05 darker (got \(bar))")
            UserDefaults.standard.set(0.02, forKey: "custom_felt_red")
            UserDefaults.standard.set(0.0, forKey: "custom_felt_green")
            UserDefaults.standard.set(0.01, forKey: "custom_felt_blue")
            let floor = rgb(FeltColorTheme.custom.statusBarColor)
            expect(floor.r == 0 && floor.g == 0 && floor.b == 0, "Status-bar shade never goes below zero (got \(floor))")
        }
    }

    // MARK: - Custom card colours

    static func testCustomCardColorGroupSavesAndOldSaves() {
        // A save from before the hint-highlight and button colours existed keeps its colours.
        let old = decode(CustomCardColorGroup.self, "{\"isEnabled\":true,\"bgRed\":0.25,\"redSuitBlue\":0.6}")
        expect(old?.isEnabled == true && old?.bgRed == 0.25 && old?.redSuitBlue == 0.6, "Saved colours survive")
        expect(old?.bgGreen == 1.0 && old?.outlineAlpha == 0.85 && old?.shadowAlpha == 0.15, "Missing card colours take their defaults")
        expect(old?.hintHighlightGreen == 0.843 && old?.hintHighlightRed == 1.0 && old?.buttonRed == 1.0 && old?.buttonAlpha == 1.0,
               "Missing highlight and button colours take their defaults (gold highlight, white buttons)")
        expect(decode(CustomCardColorGroup.self, "{}") == CustomCardColorGroup(), "An empty save is the default group")

        var g = CustomCardColorGroup()
        g.isEnabled = true
        g.bgRed = 0.1; g.outlineBlue = 0.2; g.blackSuitGreen = 0.3; g.redSuitAlpha = 0.4; g.shadowRed = 0.5
        g.hintHighlightBlue = 0.6; g.buttonGreen = 0.7
        let rt = (try? JSONEncoder().encode(g)).flatMap { try? JSONDecoder().decode(CustomCardColorGroup.self, from: $0) }
        expect(rt == g, "Every colour component round-trips")

        // Setting a colour stores its components and switches the scheme on (except the hint highlight).
        var c = CustomCardColorGroup()
        c.backgroundColor = Color(red: 0.2, green: 0.4, blue: 0.6)
        expect(c.isEnabled && abs(c.bgRed - 0.2) < 0.02 && abs(c.bgGreen - 0.4) < 0.02 && abs(c.bgBlue - 0.6) < 0.02 && c.bgAlpha == 1.0,
               "backgroundColor stores its components and enables the scheme")
        c.reset()
        c.blackSuitColor = Color(red: 0.1, green: 0.2, blue: 0.3)
        expect(c.isEnabled && abs(c.blackSuitBlue - 0.3) < 0.02, "blackSuitColor")
        c.reset()
        c.redSuitColor = Color(red: 0.9, green: 0.1, blue: 0.1)
        expect(c.isEnabled && abs(c.redSuitRed - 0.9) < 0.02, "redSuitColor")
        c.reset()
        c.shadowColor = Color(red: 0.0, green: 0.0, blue: 0.5)
        expect(c.isEnabled && abs(c.shadowBlue - 0.5) < 0.02, "shadowColor")
        c.reset()
        c.hintHighlightColor = Color(red: 0.1, green: 0.9, blue: 0.2)
        expect(!c.isEnabled && abs(c.hintHighlightGreen - 0.9) < 0.02, "The hint highlight colour doesn't switch the card colours on")
        _ = c.backgroundColor; _ = c.outlineColor; _ = c.blackSuitColor; _ = c.redSuitColor; _ = c.shadowColor; _ = c.hintHighlightColor
        expect(c.toolbarButtonColor == .white, "Top-bar buttons stay white while custom colours are off")
        c.buttonColor = Color(red: 1.0, green: 0.0, blue: 0.5)
        expect(c.isEnabled && abs(c.buttonBlue - 0.5) < 0.02 && abs(c.buttonGreen) < 0.02, "Setting the button colour enables the scheme")
        expect(c.toolbarButtonColor == c.buttonColor && c.toolbarButtonColor != .white, "...and the top bar uses it")
        c.reset()
        expect(c == CustomCardColorGroup() && c.toolbarButtonColor == .white, "Reset restores everything, including white buttons")
    }

    // MARK: - Saved themes

    static func testSavedThemesDecodeOldSavesAndKeepFaceArtSlotNames() {
        let id = UUID()
        let minimal = "{\"id\":\"\(id.uuidString)\",\"name\":\"Old\",\"cardBackTheme\":\"Solibee\",\"feltColor\":\"crimson\"}"
        let t = decode(SoliBeeTheme.self, minimal)
        expect(t?.id == id && t?.name == "Old" && t?.feltColor == .crimson, "A theme saved before extra fields existed still loads")
        expect(t?.customFeltRed == 0 && t?.customFeltBlue == 0 && t?.faceArts.isEmpty == true && t?.customCardColors == CustomCardColorGroup() && t?.customBackgroundName == nil,
               "...with defaults for the newer fields")
        expect(decode(SoliBeeTheme.self, "{\"name\":\"no id\"}") == nil, "A theme without its required fields is rejected, not half-loaded")

        let rich = SoliBeeTheme(name: "Rich", cardBackTheme: "Moogle", feltColor: .custom, customFeltRed: 0.1, customFeltGreen: 0.2, customFeltBlue: 0.3,
                                faceArts: [CustomFaceArt(slot: .heartKing, relativePath: "FaceArt/k.png", scale: 1.5, offsetX: 2, offsetY: -3, isEnabled: false)],
                                customCardColors: { var g = CustomCardColorGroup(); g.isEnabled = true; g.bgRed = 0.5; return g }(),
                                customBackgroundName: "Sunset")
        let back = (try? JSONEncoder().encode(rich)).flatMap { try? JSONDecoder().decode(SoliBeeTheme.self, from: $0) }
        expect(back?.id == rich.id && back?.cardBackTheme == "Moogle" && back?.customFeltGreen == 0.2 && back?.customBackgroundName == "Sunset"
               && back?.customCardColors.bgRed == 0.5 && back?.faceArts == rich.faceArts, "A full theme round-trips")

        // Face-art slots saved under the old black/red names map onto the suit slots.
        let legacy: [(String, FaceCardSlot)] = [
            ("blackAce", .spadeAce), ("redAce", .heartAce), ("blackJack", .spadeJack), ("redJack", .heartJack),
            ("blackQueen", .spadeQueen), ("redQueen", .heartQueen), ("blackKing", .spadeKing), ("redKing", .heartKing),
            ("clubQueen", .clubQueen),
        ]
        for (raw, slot) in legacy {
            expect(decode(FaceCardSlot.self, "\"\(raw)\"") == slot, "Old face-art slot name \(raw) → \(slot)")
        }
        expect(decode(FaceCardSlot.self, "\"nonsense\"") == nil, "An unknown slot name is rejected")
        expect(FaceCardSlot.allCases.count == 16 && Set(FaceCardSlot.allCases.map { $0.id }).count == 16, "16 distinct slots")
        for slot in FaceCardSlot.allCases {
            let suit: Card.Suit
            switch slot.suitSymbol {
            case "♠": suit = .spades
            case "♣": suit = .clubs
            case "♥": suit = .hearts
            default:  suit = .diamonds
            }
            expect(slot.isRed == suit.isRed, "\(slot) colour matches its suit")
            expect(FaceCardSlot.slot(rank: slot.rank, suit: suit) == slot, "\(slot) is found again by rank and suit")
            expect(slot.displayName == "\(slot.rankLabel)\(slot.suitSymbol)", "Display name \(slot.displayName)")
        }
        expect(FaceCardSlot.slot(rank: 5, suit: .hearts) == nil && FaceCardSlot.slot(rank: 10, suit: .spades) == nil, "Only A/J/Q/K have art slots")
        let art = CustomFaceArt(slot: .spadeAce, relativePath: "a.png")
        expect(art.scale == 1.0 && art.offsetX == 0 && art.offsetY == 0 && art.isEnabled, "New face art defaults: centred, full size, enabled")
    }

    // MARK: - Theme manager

    static func testThemeManagerLifecycle() {
        let keys = ["solibee_themes", "solibee_active_theme_id", "solibee_deleted_default_themes"]
        withCleanDefaults(keys) {
            let tm = ThemeManager.shared
            let savedThemes = tm.themes
            let savedActive = tm.activeThemeId
            defer { tm.themes = savedThemes; tm.activeThemeId = savedActive }

            tm.themes = []
            tm.activeThemeId = nil
            let a = SoliBeeTheme(name: "Alpha", cardBackTheme: "Solibee", feltColor: .feltGreen, customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0, faceArts: [])
            let b = SoliBeeTheme(name: "Beta", cardBackTheme: "Moogle", feltColor: .royalBlue, customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0, faceArts: [])
            tm.addTheme(a); tm.addTheme(b)
            let stored = UserDefaults.standard.data(forKey: "solibee_themes").flatMap { try? JSONDecoder().decode([SoliBeeTheme].self, from: $0) }
            expect(stored?.map { $0.name } == ["Alpha", "Beta"], "Added themes are saved")

            expect(tm.nameExists("alpha") && tm.nameExists("  BETA  ") && !tm.nameExists("Gamma"), "Name check ignores case and surrounding spaces")

            var changed = a
            changed.cardBackTheme = "Vulpera"
            tm.updateTheme(changed)
            expect(tm.themes.first { $0.id == a.id }?.cardBackTheme == "Vulpera", "Update overwrites a saved theme in place")
            let ghost = SoliBeeTheme(name: "Ghost", cardBackTheme: "x", feltColor: .charcoal, customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0, faceArts: [])
            tm.updateTheme(ghost)
            expect(tm.themes.count == 2, "Updating a theme that was never saved does nothing")

            expect(!tm.renameTheme(id: a.id, newName: "beta"), "Can't rename onto another theme's name")
            expect(!tm.renameTheme(id: a.id, newName: "   "), "Can't rename to blank")
            expect(!tm.renameTheme(id: ghost.id, newName: "Whatever"), "Unknown theme can't be renamed")
            expect(tm.renameTheme(id: a.id, newName: "  Alpha  "), "Renaming to its own name (trimmed) is allowed")
            expect(tm.renameTheme(id: a.id, newName: "Gamma") && tm.themes.first { $0.id == a.id }?.name == "Gamma", "A fresh name is accepted and saved")
            expect(UserDefaults.standard.data(forKey: "solibee_themes").flatMap { try? JSONDecoder().decode([SoliBeeTheme].self, from: $0) }?.first?.name == "Gamma",
                   "...persistently")

            // Active theme id is remembered, and forgotten when its theme is deleted.
            tm.activeThemeId = a.id
            expect(UserDefaults.standard.string(forKey: "solibee_active_theme_id") == a.id.uuidString, "Active theme is saved")
            tm.deleteTheme(id: ghost.id)
            expect(tm.themes.count == 2 && tm.activeThemeId == a.id, "Deleting an unknown id does nothing")
            tm.deleteTheme(id: a.id)
            expect(tm.themes.map { $0.name } == ["Beta"] && tm.activeThemeId == nil, "Deleting the active theme clears the active theme")
            expect(UserDefaults.standard.string(forKey: "solibee_active_theme_id") == nil, "...and its saved id")

            // Deleting a built-in theme remembers it so it doesn't reappear.
            let builtIn = SoliBeeTheme(name: "Desert", cardBackTheme: "Vulpera", feltColor: .desert, customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0, faceArts: [])
            tm.addTheme(builtIn)
            tm.deleteTheme(id: builtIn.id)
            expect((UserDefaults.standard.stringArray(forKey: "solibee_deleted_default_themes") ?? []).contains("desert"),
                   "Deleting a built-in theme is remembered")
            tm.addTheme(builtIn)
            tm.deleteTheme(id: builtIn.id)
            expect((UserDefaults.standard.stringArray(forKey: "solibee_deleted_default_themes") ?? []).filter { $0 == "desert" }.count == 1,
                   "...without duplicates")
        }
    }

    static func testThemeManagerCleansUpDeletedAssets() {
        let keys = ["solibee_themes", "solibee_active_theme_id", "solibee_deleted_default_themes"]
        withCleanDefaults(keys) {
            let tm = ThemeManager.shared
            let savedThemes = tm.themes
            let savedActive = tm.activeThemeId
            defer { tm.themes = savedThemes; tm.activeThemeId = savedActive }

            let art = CustomFaceArt(slot: .spadeAce, relativePath: "FaceArt/ace.png")
            let other = CustomFaceArt(slot: .heartKing, relativePath: "FaceArt/king.png")
            var one = SoliBeeTheme(name: "One", cardBackTheme: "MyBack", feltColor: .feltGreen, customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0, faceArts: [art, other])
            one.customBackgroundName = "Beach"
            var two = SoliBeeTheme(name: "Two", cardBackTheme: "Solibee", feltColor: .crimson, customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0, faceArts: [art])
            two.customBackgroundName = "Mountain"
            tm.themes = [one, two]

            tm.clearBackgroundReferences(named: "Beach")
            expect(tm.themes[0].customBackgroundName == nil && tm.themes[1].customBackgroundName == "Mountain", "Deleting a background clears just the themes that used it")

            tm.clearCardBackReferences(named: "MyBack", fallback: "Solibee")
            expect(tm.themes[0].cardBackTheme == "Solibee" && tm.themes[1].cardBackTheme == "Solibee", "Deleting a card back resets themes to the default back")

            tm.clearFaceArtReferences(relativePath: "FaceArt/ace.png")
            expect(tm.themes[0].faceArts == [other] && tm.themes[1].faceArts.isEmpty, "Deleting face art removes it from every theme that used it")

            let saved = UserDefaults.standard.data(forKey: "solibee_themes").flatMap { try? JSONDecoder().decode([SoliBeeTheme].self, from: $0) }
            expect(saved?[0].faceArts == [other] && saved?[0].customBackgroundName == nil, "...and the cleanup is saved")

            // Nothing referencing the asset: nothing changes.
            let before = tm.themes.map { $0.name }
            tm.clearBackgroundReferences(named: "Nowhere")
            tm.clearCardBackReferences(named: "Nowhere", fallback: "x")
            tm.clearFaceArtReferences(relativePath: "Nowhere.png")
            expect(tm.themes.map { $0.name } == before, "Clearing an unused asset leaves themes alone")
        }
    }

    // MARK: - Game modes

    static func testGameModeNames() {
        expect(GameMode.allCases.count == 6, "Six games")
        expect(GameMode.allCases.map { $0.displayName } == ["Klondike Solibee", "Beecell", "Spider Solibee", "Video Poker", "Video Blackjack", "Honeycomb"],
               "Game picker names")
        for mode in GameMode.allCases {
            expect(GameMode(rawValue: mode.rawValue) == mode && mode.id == mode.rawValue, "\(mode) round-trips through its saved name")
            let en = mode.localizedDisplayName(language: .english)
            let es = mode.localizedDisplayName(language: .spanish)
            expect(!en.isEmpty && !es.isEmpty, "\(mode) has a name in both languages")
        }
        expect(GameMode.iOSStoreSafeCases == GameMode.allCases, "iOS lineup is unchanged")
        expect(GameMode(rawValue: "Tejas Hold'em") == nil, "A retired game name isn't a valid mode")
    }
}
