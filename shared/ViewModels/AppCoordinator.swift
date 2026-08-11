import Foundation
import Observation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public extension Notification.Name {
    /// Posted after every CustomFaceCardArtManager mutation (add/update/remove/
    /// setEnabled) so AppCoordinator can live-save the active theme without that
    /// (mac-only, not part of the iOS target) manager needing a coordinator reference
    /// of its own. Declared here in shared code — not in CustomFaceCardArtManager.swift
    /// itself — so it's visible when this file compiles for iOS too, even though nothing
    /// posts it there yet.
    static let customFaceCardArtDidChange = Notification.Name("customFaceCardArtDidChange")
}

@Observable
public final class AppCoordinator {
    public var gameMode: GameMode {
        didSet {
            UserDefaults.standard.set(gameMode.rawValue, forKey: "selectedGameMode")
            // Stop the outgoing game's timer — state and credits are preserved
            switch oldValue {
            case .klondike:   klondikeViewModel.stopTimer()
            case .beecell:    beecellViewModel.stopTimer()
            case .spider:     spiderViewModel.stopTimer()
            case .videoPoker, .blackjack, .honeycomb: break
            }
            // Entering Poker/Blackjack with a finished round still sitting in .result
            // (e.g. left mid-banner on a previous visit) resets the board instead of
            // showing — and replaying the banner for — a round that's already over.
            switch gameMode {
            case .videoPoker: videoPokerViewModel.resetIfRoundOver()
            case .blackjack:  blackjackViewModel.resetIfRoundOver()
            default: break
            }
            syncSharedOptions(from: oldValue, to: gameMode)
            // Reassert the real Sound/No Stress Mode values on every switch — mainly
            // defensive, since nothing besides applySharedCommonOptionsToAllGames itself
            // should ever change these per-game fields, but this guarantees switching
            // games can never be the thing that changes what they're set to (the exact
            // bug this replaced: syncSharedOptions used to broadcast whichever game you
            // just left onto every other game, including these two fields).
            applySharedCommonOptionsToAllGames()
            #if canImport(AppKit)
            applyWindowSizeForCurrentGameMode()
            #endif
        }
    }

    #if canImport(AppKit)
    // Updates the window's minimum size for the newly-selected game.
    // We intentionally avoid resetting the window size when switching games so that
    // the user's manual resizing is preserved across the entire app.
    private func applyWindowSizeForCurrentGameMode() {
        guard let window = activeWindow else { return }
        let minSize: NSSize
        switch gameMode {
        case .klondike:
            minSize = GameView.minWindowSize
        case .beecell:
            minSize = BeecellView.minWindowSize
        case .spider:
            minSize = SpiderView.minWindowSize
        case .videoPoker:
            minSize = VideoPokerView.minWindowSize
        case .blackjack:
            minSize = BlackjackView.minWindowSize
        case .honeycomb:
            minSize = HoneycombView.minWindowSize
        }
        window.contentMinSize = minSize
    }
    #endif

    public let klondikeViewModel   = GameViewModel()
    public let beecellViewModel    = BeecellViewModel()
    public let spiderViewModel     = SpiderViewModel()
    public let videoPokerViewModel = VideoPokerViewModel()
    public let blackjackViewModel  = BlackjackViewModel()
    public let honeycombViewModel  = HoneycombViewModel()

    // MARK: - App-wide theme (single source of truth for all 5 games, live-shared —
    // not per-game, not copy-on-mode-switch). Persisted to the same UserDefaults keys
    // every game's Options struct used to write independently before this refactor, so
    // existing users' last-used theme carries over with no migration step.
    public var feltColor: FeltColorTheme {
        didSet {
            UserDefaults.standard.set(feltColor.rawValue, forKey: "global_felt_color")
            liveSaveActiveTheme()
        }
    }
    public var cardBackTheme: String {
        didSet {
            UserDefaults.standard.set(cardBackTheme, forKey: "cardBackTheme")
            liveSaveActiveTheme()
        }
    }
    // Not part of SoliBeeTheme on either platform — a plain app-wide display setting,
    // not something a saved theme preset snapshots — so it deliberately does NOT trigger
    // liveSaveActiveTheme() below.
    public var showFeltVignette: Bool {
        didSet { UserDefaults.standard.set(showFeltVignette, forKey: "showFeltVignette") }
    }
    // App-wide UI language — not a theme field (no SoliBeeTheme entry, no
    // liveSaveActiveTheme), same single-source pattern as the theme fields above.
    // Every L() call reads this directly, and since AppCoordinator is @Observable,
    // assigning it re-renders every view that called L() during its last render —
    // no restart needed.
    public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            BannerCatalog.currentLanguage = language
        }
    }
    #if canImport(AppKit)
    // Keeps the main game window floating above other apps' windows. Applied via
    // applyWindowLevel() both here and from activeWindow's didSet, so a saved "on"
    // preference takes effect immediately on the next launch, not just on toggle.
    public var stayOnTop: Bool {
        didSet {
            UserDefaults.standard.set(stayOnTop, forKey: "stayOnTop")
            applyWindowLevel()
        }
    }
    #endif
    public var customCardColors: CustomCardColorGroup {
        didSet {
            if let encoded = try? JSONEncoder().encode(customCardColors) {
                UserDefaults.standard.set(encoded, forKey: "customCardColors")
            }
            liveSaveActiveTheme()
        }
    }
    public var customFeltRed: Double {
        didSet {
            UserDefaults.standard.set(customFeltRed, forKey: "custom_felt_red")
            liveSaveActiveTheme()
        }
    }
    public var customFeltGreen: Double {
        didSet {
            UserDefaults.standard.set(customFeltGreen, forKey: "custom_felt_green")
            liveSaveActiveTheme()
        }
    }
    public var customFeltBlue: Double {
        didSet {
            UserDefaults.standard.set(customFeltBlue, forKey: "custom_felt_blue")
            liveSaveActiveTheme()
        }
    }
    // nil means "no custom background — render Felt Color instead". App-wide/live-shared,
    // same as the felt color fields above.
    public var customBackgroundName: String? {
        didSet {
            if let customBackgroundName {
                UserDefaults.standard.set(customBackgroundName, forKey: "custom_background_name")
            } else {
                UserDefaults.standard.removeObject(forKey: "custom_background_name")
            }
            liveSaveActiveTheme()
        }
    }

    // MARK: - App-wide Sound/No Stress Mode (single source of truth, same pattern as the
    // theme fields above). These used to live only per-game and get silently overwritten
    // on every mode switch by syncSharedOptions (whichever game you'd most recently left
    // "won"), so switching games alone could flip Sound/No Stress Mode in five games you
    // never touched. Each game's Options struct still carries its own isSoundEnabled/
    // noStressMode fields (for Codable/backward-compat reasons and because some game
    // logic reads options.noStressMode directly), but those are now always kept in sync
    // *from* these coordinator properties via applySharedCommonOptionsToAllGames() —
    // never the other way around — so there's one real value, not six.
    public var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "global_sound_enabled")
            applySharedCommonOptionsToAllGames()
        }
    }
    public var noStressMode: Bool {
        didSet {
            UserDefaults.standard.set(noStressMode, forKey: "global_no_stress_mode")
            applySharedCommonOptionsToAllGames()
        }
    }
    // "Honey Mode (Flavor)" — renamed and repurposed from the old per-game Point
    // Highlights toggle. Single app-wide switch, same true-single-source pattern as
    // isSoundEnabled/noStressMode above: controls both the "+N"/"-N" score popups
    // (each game's own options.honeyMode guard, same spot showPointHighlights used to
    // gate) and, via BannerCatalog.honeyModeEnabled, whether Repeatable Flavor/Ambiance
    // banners fire at all. Achievement/Milestone banners are never affected. No
    // migration from the old per-game showPointHighlights values — everyone gets a
    // fresh default of on.
    public var honeyMode: Bool {
        didSet {
            UserDefaults.standard.set(honeyMode, forKey: "global_honey_mode")
            applySharedCommonOptionsToAllGames()
            BannerCatalog.honeyModeEnabled = honeyMode
        }
    }
    // When on, banners/toasts stay up (no auto-dismiss timer) and the game is
    // effectively paused until the player clicks the banner or a card, at which point
    // it dismisses and the banner queue resumes. Same true-single-source pattern as
    // isSoundEnabled/noStressMode/honeyMode above. Default off — preserves the existing
    // auto-dismiss behavior unless the player opts in.
    public var manuallyDismissBanners: Bool {
        didSet {
            UserDefaults.standard.set(manuallyDismissBanners, forKey: "global_manually_dismiss_banners")
            applySharedCommonOptionsToAllGames()
        }
    }

    private func applySharedCommonOptionsToAllGames() {
        klondikeViewModel.options.isSoundEnabled   = isSoundEnabled
        beecellViewModel.options.isSoundEnabled    = isSoundEnabled
        spiderViewModel.options.isSoundEnabled     = isSoundEnabled
        videoPokerViewModel.options.isSoundEnabled = isSoundEnabled
        blackjackViewModel.options.isSoundEnabled  = isSoundEnabled
        honeycombViewModel.options.isSoundEnabled  = isSoundEnabled
        klondikeViewModel.options.noStressMode   = noStressMode
        beecellViewModel.options.noStressMode    = noStressMode
        spiderViewModel.options.noStressMode     = noStressMode
        videoPokerViewModel.options.noStressMode = noStressMode
        blackjackViewModel.options.noStressMode  = noStressMode
        honeycombViewModel.options.noStressMode  = noStressMode
        klondikeViewModel.options.honeyMode   = honeyMode
        beecellViewModel.options.honeyMode    = honeyMode
        spiderViewModel.options.honeyMode     = honeyMode
        videoPokerViewModel.options.honeyMode = honeyMode
        blackjackViewModel.options.honeyMode  = honeyMode
        honeycombViewModel.options.honeyMode  = honeyMode
        klondikeViewModel.options.manuallyDismissBanners   = manuallyDismissBanners
        beecellViewModel.options.manuallyDismissBanners    = manuallyDismissBanners
        spiderViewModel.options.manuallyDismissBanners     = manuallyDismissBanners
        videoPokerViewModel.options.manuallyDismissBanners = manuallyDismissBanners
        blackjackViewModel.options.manuallyDismissBanners  = manuallyDismissBanners
        honeycombViewModel.options.manuallyDismissBanners  = manuallyDismissBanners
    }

    #if canImport(AppKit)
    public var activeCustomBackground: CustomBackground? {
        guard let customBackgroundName else { return nil }
        return CustomBackgroundManager.shared.customBackgrounds.first { $0.name == customBackgroundName }
    }
    #endif

    // Resolves .custom against the live customFeltRed/Green/Blue properties (rather than
    // FeltColorTheme.primaryColor's raw UserDefaults read) so SwiftUI's Observation
    // tracking picks up custom-color edits automatically — no more manual .id() bump.
    public var currentFeltColor: Color {
        guard feltColor == .custom else { return feltColor.primaryColor }
        if customFeltRed == 0 && customFeltGreen == 0 && customFeltBlue == 0 {
            return Color(red: 0.35, green: 0.15, blue: 0.45)
        }
        return Color(red: customFeltRed, green: customFeltGreen, blue: customFeltBlue)
    }

    #if canImport(AppKit)
    // What "this is the active/selected thing" UI tints (a saved theme's row, a saved
    // deck's row, the deck builder's tray) should use for their opaque background —
    // currentFeltColor when the active background is plain felt, but the wallpaper's
    // own sampled average color when a custom background image is active, since the
    // felt color setting is otherwise unrelated to what's actually showing on screen.
    // Returns currentFeltColor (not nil) until the async sample finishes, same
    // graceful-fallback pattern CustomBackgroundManager.image(for:) already uses.
    public var currentAccentTint: Color {
        guard let background = activeCustomBackground,
              let sampled = CustomBackgroundManager.shared.dominantColor(for: background.relativePath)
        else { return currentFeltColor }
        return sampled
    }
    #endif
    // The NSWindow currently hosting the active game mode's view, kept up to date
    // by each game view's WindowAccessor so window-level actions (e.g. "make current
    // window size default") can be triggered from menu commands that don't own a window.
    // There's only ever one underlying window for the whole app (switching games swaps
    // SwiftUI content within it, not the window itself), so re-applying stayOnTop here
    // covers every game with no per-game code.
    #if canImport(AppKit)
    @ObservationIgnored public weak var activeWindow: NSWindow? {
        didSet { applyWindowLevel() }
    }

    private func applyWindowLevel() {
        activeWindow?.level = stayOnTop ? .floating : .normal
    }
    #endif

    public init() {
        let saved = UserDefaults.standard.string(forKey: "selectedGameMode") ?? GameMode.klondike.rawValue
        self.gameMode = GameMode(rawValue: saved) ?? .klondike

        self.feltColor = FeltColorTheme(rawValue: UserDefaults.standard.string(forKey: "global_felt_color") ?? "") ?? .feltGreen
        self.cardBackTheme = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Solibee"
        self.showFeltVignette = UserDefaults.standard.object(forKey: "showFeltVignette") != nil
            ? UserDefaults.standard.bool(forKey: "showFeltVignette") : true
        self.language = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .english
        #if canImport(AppKit)
        self.stayOnTop = UserDefaults.standard.object(forKey: "stayOnTop") != nil
            ? UserDefaults.standard.bool(forKey: "stayOnTop") : false
        #endif
        if let data = UserDefaults.standard.data(forKey: "customCardColors"),
           let decoded = try? JSONDecoder().decode(CustomCardColorGroup.self, from: data) {
            self.customCardColors = decoded
        } else {
            self.customCardColors = CustomCardColorGroup()
        }
        self.customFeltRed   = UserDefaults.standard.double(forKey: "custom_felt_red")
        self.customFeltGreen = UserDefaults.standard.double(forKey: "custom_felt_green")
        self.customFeltBlue  = UserDefaults.standard.double(forKey: "custom_felt_blue")
        self.customBackgroundName = UserDefaults.standard.string(forKey: "custom_background_name")

        // One-time migration: fall back to Klondike's already-persisted per-game value
        // (rather than a hardcoded default) so existing users don't see a surprise reset
        // the first time this app-wide value replaces the old six-copies scheme.
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "global_sound_enabled") != nil
            ? UserDefaults.standard.bool(forKey: "global_sound_enabled")
            : klondikeViewModel.options.isSoundEnabled
        self.noStressMode = UserDefaults.standard.object(forKey: "global_no_stress_mode") != nil
            ? UserDefaults.standard.bool(forKey: "global_no_stress_mode")
            : klondikeViewModel.options.noStressMode
        // No migration from the old per-game showPointHighlights value — always
        // defaults to on for every install, per product decision.
        self.honeyMode = UserDefaults.standard.object(forKey: "global_honey_mode") != nil
            ? UserDefaults.standard.bool(forKey: "global_honey_mode")
            : true
        // No migration — always defaults to off, preserving today's auto-dismiss
        // behavior for everyone unless they explicitly opt in.
        self.manuallyDismissBanners = UserDefaults.standard.object(forKey: "global_manually_dismiss_banners") != nil
            ? UserDefaults.standard.bool(forKey: "global_manually_dismiss_banners")
            : false
        BannerCatalog.honeyModeEnabled = self.honeyMode
        BannerCatalog.currentLanguage = self.language

        #if canImport(AppKit)
        // Synchronously warm the cache for whichever background is active so that
        // BackgroundLayerView never renders a transient Color fallback on first paint.
        // (preloadImages() is otherwise async and would cause a hit-testing race window.)
        if let name = self.customBackgroundName,
           let bg = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }) {
            CustomBackgroundManager.shared.preloadImages(priorityPaths: [bg.relativePath])
        }

        // Same fix for custom card backs — synchronously preload the active card back
        // so CardBackView never renders the tiny Circle fallback on first paint.
        let activeCardBack = self.cardBackTheme
        if let cb = CustomCardBackManager.shared.customCardBack(named: activeCardBack) {
            CustomCardBackManager.shared.preloadImages(priorityPaths: [cb.relativePath])
        } else {
            // Active theme is a built-in — still kick off async preload for any custom backs.
            CustomCardBackManager.shared.preloadImages()
        }
        #endif

        // Each view model set UISound.isEnabled from its own (possibly stale, pre-
        // migration) persisted setting as it initialized above; force every game's
        // isSoundEnabled/noStressMode to the one real value now that it's been resolved,
        // which also reasserts UISound.isEnabled from it (see options.didSet in each
        // ViewModel) so nothing can silently win by being the last one to init.
        applySharedCommonOptionsToAllGames()

        observeFaceArtChangesForLiveSave()
    }

    // MARK: - Shared option sync (genuinely per-game gameplay prefs only — theme fields
    // above are a single live-shared store and need no propagation on mode switch)

    // Each game's Options struct conforms to HasCommonGameOptions (see
    // CommonGameOptions.swift), exposing just the fields that are conceptually shared
    // across games (sound, no-stress, hint visibility, point highlights, timer) as
    // Optionals where that game doesn't have the concept. Reading `commonOptions` off
    // the outgoing game and assigning it to every other game's `commonOptions` handles
    // the propagation generically — a `nil` field is left untouched by the setter, so
    // e.g. Video Poker's lack of `isTimed` naturally doesn't clobber the solitaire
    // games' timer preference.
    private func syncSharedOptions(from old: GameMode, to new: GameMode) {
        let common: CommonGameOptions
        switch old {
        case .klondike:   common = klondikeViewModel.options.commonOptions
        case .beecell:    common = beecellViewModel.options.commonOptions
        case .spider:     common = spiderViewModel.options.commonOptions
        case .videoPoker: common = videoPokerViewModel.options.commonOptions
        case .blackjack:  common = blackjackViewModel.options.commonOptions
        case .honeycomb:  common = honeycombViewModel.options.commonOptions
        }

        if old != .klondike   { klondikeViewModel.options.commonOptions = common }
        if old != .beecell    { beecellViewModel.options.commonOptions = common }
        if old != .spider     { spiderViewModel.options.commonOptions = common }
        if old != .videoPoker { videoPokerViewModel.options.commonOptions = common }
        if old != .blackjack  { blackjackViewModel.options.commonOptions = common }
        if old != .honeycomb  { honeycombViewModel.options.commonOptions = common }
    }

    // MARK: - Game actions

    public func startNewGame() {
        switch gameMode {
        case .klondike:  klondikeViewModel.startNewGame()
        case .beecell:   beecellViewModel.startNewGame()
        case .spider:    spiderViewModel.startNewGame()
        case .videoPoker: videoPokerViewModel.startNewGame()
        case .blackjack:  blackjackViewModel.startNewGame()
        case .honeycomb:  honeycombViewModel.startNewGame()
        }
    }

    public func restartCurrentGame() {
        switch gameMode {
        case .klondike:   klondikeViewModel.restartCurrentGame()
        case .beecell:    beecellViewModel.restartCurrentGame()
        case .spider:     spiderViewModel.restartCurrentGame()
        case .videoPoker: videoPokerViewModel.restartCurrentGame()
        case .blackjack:  blackjackViewModel.restartCurrentGame()
        case .honeycomb:  honeycombViewModel.restartCurrentGame()
        }
    }

    public func undoLastAction() {
        switch gameMode {
        case .klondike:  klondikeViewModel.undoLastAction()
        case .beecell:   beecellViewModel.undoLastAction()
        case .spider:    spiderViewModel.undoLastAction()
        case .honeycomb: honeycombViewModel.undoLastAction()
        case .videoPoker, .blackjack: break
        }
    }

    public var canUndo: Bool {
        switch gameMode {
        case .klondike:  return klondikeViewModel.canUndo
        case .beecell:   return beecellViewModel.canUndo
        case .spider:    return spiderViewModel.canUndo
        case .honeycomb: return honeycombViewModel.canUndo
        case .videoPoker, .blackjack: return false
        }
    }

    public func resetStatistics() {
        switch gameMode {
        case .klondike:   klondikeViewModel.resetStatistics()
        case .beecell:    beecellViewModel.resetStatistics()
        case .spider:     spiderViewModel.resetStatistics()
        case .videoPoker: videoPokerViewModel.resetStatistics()
        case .blackjack:  blackjackViewModel.resetStatistics()
        case .honeycomb:  honeycombViewModel.resetStatistics()
        }
    }

    public func applyTheme(_ theme: SoliBeeTheme) {
        // Reentrancy guard for liveSaveActiveTheme() below: applyTheme is *loading*
        // already-saved data back in, field by field — without this, each individual
        // field's didSet would fire while activeThemeId still points at whichever theme
        // was active *before* this call (it's only reassigned at the very end here), so
        // every one of those live-saves would silently overwrite the OLD theme's saved
        // preset with the NEW theme's values, corrupting it one field at a time.
        isApplyingTheme = true
        defer { isApplyingTheme = false }

        cardBackTheme = theme.cardBackTheme
        feltColor     = theme.feltColor
        customCardColors = theme.customCardColors
        if theme.feltColor == .custom {
            customFeltRed   = theme.customFeltRed
            customFeltGreen = theme.customFeltGreen
            customFeltBlue  = theme.customFeltBlue
        }
        customBackgroundName = theme.customBackgroundName

        #if canImport(AppKit)
        if let name = customBackgroundName,
           let bg = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }) {
            let _ = CustomBackgroundManager.shared.image(for: bg.relativePath)
        }

        CustomFaceCardArtManager.shared.restore(theme.faceArts)
        #endif
        ThemeManager.shared.activeThemeId = theme.id
    }

    // MARK: - Live-save into the active theme (mirrors Windows' NotifySettingsChanged ->
    // ThemeService.UpdateTheme live-save). Called from every theme-relevant field's
    // didSet above, and from CustomFaceCardArtManager's mutators via
    // notifyFaceArtChangedForLiveSave() below. No-ops when there's no active theme (the
    // user hasn't applied/saved one, or last deleted it) or while applyTheme() itself is
    // in the middle of loading a theme in (see isApplyingTheme).
    @ObservationIgnored private var isApplyingTheme = false

    private func liveSaveActiveTheme() {
        guard !isApplyingTheme,
              let activeThemeId = ThemeManager.shared.activeThemeId,
              let existing = ThemeManager.shared.themes.first(where: { $0.id == activeThemeId })
        else { return }

        // CustomFaceCardArtManager is mac-only (not part of the iOS target) — iOS has no
        // face-art customization concept yet, so its themes simply keep whatever faceArts
        // they already had rather than trying to read a manager that doesn't exist there.
        #if canImport(AppKit)
        let faceArts = CustomFaceCardArtManager.shared.faceArts
        #else
        let faceArts = existing.faceArts
        #endif

        let updated = SoliBeeTheme(
            id: activeThemeId,
            name: existing.name,
            cardBackTheme: cardBackTheme,
            feltColor: feltColor,
            customFeltRed: customFeltRed,
            customFeltGreen: customFeltGreen,
            customFeltBlue: customFeltBlue,
            faceArts: faceArts,
            customCardColors: customCardColors,
            customBackgroundName: customBackgroundName
        )
        ThemeManager.shared.updateTheme(updated)
    }

    // CustomFaceCardArtManager has no AppCoordinator reference (and shouldn't gain one
    // just for this), so it posts a notification on each mutation instead — mirrors how
    // Windows' PreferencesView already listens for FaceCardArtChangedMessage separately
    // from its own NotifySettingsChanged funnel. Registered once in init() below.
    private func observeFaceArtChangesForLiveSave() {
        NotificationCenter.default.addObserver(
            forName: .customFaceCardArtDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.liveSaveActiveTheme()
        }
    }

    public func triggerWinAnimation() {
        let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
        func fullFoundations(count: Int) -> [Pile] {
            (0..<count).map { i in
                let suit = suits[i % suits.count]
                let cards = (1...13).map { rank in Card(suit: suit, rank: rank, faceUp: true) }
                return Pile(id: "foundation_demo_\(i)", type: .foundation, cards: cards)
            }
        }
        switch gameMode {
        case .klondike:
            klondikeViewModel.state.foundations = fullFoundations(count: 4)
            klondikeViewModel.state.hasWon = true
        case .beecell:
            let count = max(beecellViewModel.state.foundations.count, 4)
            beecellViewModel.state.foundations = fullFoundations(count: count)
            beecellViewModel.state.hasWon = true
        case .spider:
            let count = max(spiderViewModel.state.foundations.count, 4)
            spiderViewModel.state.foundations = fullFoundations(count: count)
            spiderViewModel.state.hasWon = true
        case .videoPoker, .blackjack, .honeycomb:
            break   // no card-cascade win animation for poker/casino modes
        }
    }

    // MARK: - Debug banner triggers

    public func debugFireBanner(_ kind: DebugBannerKind, for game: GameMode) {
        let delay: Double = (gameMode != game) ? 0.35 : 0
        if gameMode != game { gameMode = game }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            switch game {
            case .klondike:   self.klondikeViewModel.debugBannerRequest   = kind
            case .beecell:    self.beecellViewModel.debugBannerRequest    = kind
            case .spider:     self.spiderViewModel.debugBannerRequest     = kind
            case .videoPoker: self.videoPokerViewModel.debugBannerRequest = kind
            case .blackjack:  self.blackjackViewModel.debugBannerRequest  = kind
            case .honeycomb:  self.honeycombViewModel.debugBannerRequest  = kind
            }
        }
    }
}
