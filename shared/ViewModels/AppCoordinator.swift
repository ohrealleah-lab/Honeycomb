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

    public let sharedOptions: SharedGameOptions
    public let klondikeViewModel: GameViewModel
    public let beecellViewModel: BeecellViewModel
    public let spiderViewModel: SpiderViewModel
    public let videoPokerViewModel: VideoPokerViewModel
    public let blackjackViewModel: BlackjackViewModel
    public let honeycombViewModel: HoneycombViewModel

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
    // Hides the centered Solibee watermark drawn behind every game's board. Same
    // plain app-wide display setting pattern as showFeltVignette above.
    public var hideBee: Bool {
        didSet { UserDefaults.standard.set(hideBee, forKey: "global_hide_bee") }
    }

    // MARK: - Bee watermark per-game scale
    // One raw stored value per game, plus currentGameWatermarkScale below as the single
    // read/write surface GameWatermarkView uses. Calibrated per platform (see the
    // default constants in init()) — the calibration slider that produced these values
    // has been removed on both mac and iOS now that they're final.
    public var klondikeWatermarkScale: Double {
        didSet { UserDefaults.standard.set(klondikeWatermarkScale, forKey: "watermark_scale_klondike") }
    }
    public var beecellWatermarkScale: Double {
        didSet { UserDefaults.standard.set(beecellWatermarkScale, forKey: "watermark_scale_beecell") }
    }
    public var spiderWatermarkScale: Double {
        didSet { UserDefaults.standard.set(spiderWatermarkScale, forKey: "watermark_scale_spider") }
    }
    public var videoPokerWatermarkScale: Double {
        didSet { UserDefaults.standard.set(videoPokerWatermarkScale, forKey: "watermark_scale_videoPoker") }
    }
    public var blackjackWatermarkScale: Double {
        didSet { UserDefaults.standard.set(blackjackWatermarkScale, forKey: "watermark_scale_blackjack") }
    }
    public var honeycombWatermarkScale: Double {
        didSet { UserDefaults.standard.set(honeycombWatermarkScale, forKey: "watermark_scale_honeycomb") }
    }
    public var currentGameWatermarkScale: Double {
        get {
            switch gameMode {
            case .klondike:   return klondikeWatermarkScale
            case .beecell:    return beecellWatermarkScale
            case .spider:     return spiderWatermarkScale
            case .videoPoker: return videoPokerWatermarkScale
            case .blackjack:  return blackjackWatermarkScale
            case .honeycomb:  return honeycombWatermarkScale
            }
        }
        set {
            switch gameMode {
            case .klondike:   klondikeWatermarkScale = newValue
            case .beecell:    beecellWatermarkScale = newValue
            case .spider:     spiderWatermarkScale = newValue
            case .videoPoker: videoPokerWatermarkScale = newValue
            case .blackjack:  blackjackWatermarkScale = newValue
            case .honeycomb:  honeycombWatermarkScale = newValue
            }
        }
    }

    // MARK: - Bee watermark per-game position
    // Same shape as the scale block above — one raw X/Y pair per game, plus
    // currentGameWatermarkOffsetX/Y as the single read/write surface.
    public var klondikeWatermarkOffsetX: Double {
        didSet { UserDefaults.standard.set(klondikeWatermarkOffsetX, forKey: "watermark_offsetX_klondike") }
    }
    public var klondikeWatermarkOffsetY: Double {
        didSet { UserDefaults.standard.set(klondikeWatermarkOffsetY, forKey: "watermark_offsetY_klondike") }
    }
    public var beecellWatermarkOffsetX: Double {
        didSet { UserDefaults.standard.set(beecellWatermarkOffsetX, forKey: "watermark_offsetX_beecell") }
    }
    public var beecellWatermarkOffsetY: Double {
        didSet { UserDefaults.standard.set(beecellWatermarkOffsetY, forKey: "watermark_offsetY_beecell") }
    }
    public var spiderWatermarkOffsetX: Double {
        didSet { UserDefaults.standard.set(spiderWatermarkOffsetX, forKey: "watermark_offsetX_spider") }
    }
    public var spiderWatermarkOffsetY: Double {
        didSet { UserDefaults.standard.set(spiderWatermarkOffsetY, forKey: "watermark_offsetY_spider") }
    }
    public var videoPokerWatermarkOffsetX: Double {
        didSet { UserDefaults.standard.set(videoPokerWatermarkOffsetX, forKey: "watermark_offsetX_videoPoker") }
    }
    public var videoPokerWatermarkOffsetY: Double {
        didSet { UserDefaults.standard.set(videoPokerWatermarkOffsetY, forKey: "watermark_offsetY_videoPoker") }
    }
    public var blackjackWatermarkOffsetX: Double {
        didSet { UserDefaults.standard.set(blackjackWatermarkOffsetX, forKey: "watermark_offsetX_blackjack") }
    }
    public var blackjackWatermarkOffsetY: Double {
        didSet { UserDefaults.standard.set(blackjackWatermarkOffsetY, forKey: "watermark_offsetY_blackjack") }
    }
    public var honeycombWatermarkOffsetX: Double {
        didSet { UserDefaults.standard.set(honeycombWatermarkOffsetX, forKey: "watermark_offsetX_honeycomb") }
    }
    public var honeycombWatermarkOffsetY: Double {
        didSet { UserDefaults.standard.set(honeycombWatermarkOffsetY, forKey: "watermark_offsetY_honeycomb") }
    }
    public var currentGameWatermarkOffsetX: Double {
        get {
            switch gameMode {
            case .klondike:   return klondikeWatermarkOffsetX
            case .beecell:    return beecellWatermarkOffsetX
            case .spider:     return spiderWatermarkOffsetX
            case .videoPoker: return videoPokerWatermarkOffsetX
            case .blackjack:  return blackjackWatermarkOffsetX
            case .honeycomb:  return honeycombWatermarkOffsetX
            }
        }
        set {
            switch gameMode {
            case .klondike:   klondikeWatermarkOffsetX = newValue
            case .beecell:    beecellWatermarkOffsetX = newValue
            case .spider:     spiderWatermarkOffsetX = newValue
            case .videoPoker: videoPokerWatermarkOffsetX = newValue
            case .blackjack:  blackjackWatermarkOffsetX = newValue
            case .honeycomb:  honeycombWatermarkOffsetX = newValue
            }
        }
    }
    public var currentGameWatermarkOffsetY: Double {
        get {
            switch gameMode {
            case .klondike:   return klondikeWatermarkOffsetY
            case .beecell:    return beecellWatermarkOffsetY
            case .spider:     return spiderWatermarkOffsetY
            case .videoPoker: return videoPokerWatermarkOffsetY
            case .blackjack:  return blackjackWatermarkOffsetY
            case .honeycomb:  return honeycombWatermarkOffsetY
            }
        }
        set {
            switch gameMode {
            case .klondike:   klondikeWatermarkOffsetY = newValue
            case .beecell:    beecellWatermarkOffsetY = newValue
            case .spider:     spiderWatermarkOffsetY = newValue
            case .videoPoker: videoPokerWatermarkOffsetY = newValue
            case .blackjack:  blackjackWatermarkOffsetY = newValue
            case .honeycomb:  honeycombWatermarkOffsetY = newValue
            }
        }
    }

    // MARK: - Bee watermark per-game scale/position (iOS landscape variant)
    // iOS is the only platform that distinguishes orientation (mac has no landscape/
    // portrait concept) — GameWatermarkView picks between this set and the plain
    // properties above based on the board's actual rendered aspect ratio. Same
    // one-raw-value-per-game + single-read/write-surface shape as the portrait fields.
    public var klondikeWatermarkScaleLandscape: Double {
        didSet { UserDefaults.standard.set(klondikeWatermarkScaleLandscape, forKey: "watermark_scale_landscape_klondike") }
    }
    public var beecellWatermarkScaleLandscape: Double {
        didSet { UserDefaults.standard.set(beecellWatermarkScaleLandscape, forKey: "watermark_scale_landscape_beecell") }
    }
    public var spiderWatermarkScaleLandscape: Double {
        didSet { UserDefaults.standard.set(spiderWatermarkScaleLandscape, forKey: "watermark_scale_landscape_spider") }
    }
    public var videoPokerWatermarkScaleLandscape: Double {
        didSet { UserDefaults.standard.set(videoPokerWatermarkScaleLandscape, forKey: "watermark_scale_landscape_videoPoker") }
    }
    public var blackjackWatermarkScaleLandscape: Double {
        didSet { UserDefaults.standard.set(blackjackWatermarkScaleLandscape, forKey: "watermark_scale_landscape_blackjack") }
    }
    public var honeycombWatermarkScaleLandscape: Double {
        didSet { UserDefaults.standard.set(honeycombWatermarkScaleLandscape, forKey: "watermark_scale_landscape_honeycomb") }
    }
    public var currentGameWatermarkScaleLandscape: Double {
        get {
            switch gameMode {
            case .klondike:   return klondikeWatermarkScaleLandscape
            case .beecell:    return beecellWatermarkScaleLandscape
            case .spider:     return spiderWatermarkScaleLandscape
            case .videoPoker: return videoPokerWatermarkScaleLandscape
            case .blackjack:  return blackjackWatermarkScaleLandscape
            case .honeycomb:  return honeycombWatermarkScaleLandscape
            }
        }
        set {
            switch gameMode {
            case .klondike:   klondikeWatermarkScaleLandscape = newValue
            case .beecell:    beecellWatermarkScaleLandscape = newValue
            case .spider:     spiderWatermarkScaleLandscape = newValue
            case .videoPoker: videoPokerWatermarkScaleLandscape = newValue
            case .blackjack:  blackjackWatermarkScaleLandscape = newValue
            case .honeycomb:  honeycombWatermarkScaleLandscape = newValue
            }
        }
    }
    public var klondikeWatermarkOffsetXLandscape: Double {
        didSet { UserDefaults.standard.set(klondikeWatermarkOffsetXLandscape, forKey: "watermark_offsetX_landscape_klondike") }
    }
    public var klondikeWatermarkOffsetYLandscape: Double {
        didSet { UserDefaults.standard.set(klondikeWatermarkOffsetYLandscape, forKey: "watermark_offsetY_landscape_klondike") }
    }
    public var beecellWatermarkOffsetXLandscape: Double {
        didSet { UserDefaults.standard.set(beecellWatermarkOffsetXLandscape, forKey: "watermark_offsetX_landscape_beecell") }
    }
    public var beecellWatermarkOffsetYLandscape: Double {
        didSet { UserDefaults.standard.set(beecellWatermarkOffsetYLandscape, forKey: "watermark_offsetY_landscape_beecell") }
    }
    public var spiderWatermarkOffsetXLandscape: Double {
        didSet { UserDefaults.standard.set(spiderWatermarkOffsetXLandscape, forKey: "watermark_offsetX_landscape_spider") }
    }
    public var spiderWatermarkOffsetYLandscape: Double {
        didSet { UserDefaults.standard.set(spiderWatermarkOffsetYLandscape, forKey: "watermark_offsetY_landscape_spider") }
    }
    public var videoPokerWatermarkOffsetXLandscape: Double {
        didSet { UserDefaults.standard.set(videoPokerWatermarkOffsetXLandscape, forKey: "watermark_offsetX_landscape_videoPoker") }
    }
    public var videoPokerWatermarkOffsetYLandscape: Double {
        didSet { UserDefaults.standard.set(videoPokerWatermarkOffsetYLandscape, forKey: "watermark_offsetY_landscape_videoPoker") }
    }
    public var blackjackWatermarkOffsetXLandscape: Double {
        didSet { UserDefaults.standard.set(blackjackWatermarkOffsetXLandscape, forKey: "watermark_offsetX_landscape_blackjack") }
    }
    public var blackjackWatermarkOffsetYLandscape: Double {
        didSet { UserDefaults.standard.set(blackjackWatermarkOffsetYLandscape, forKey: "watermark_offsetY_landscape_blackjack") }
    }
    public var honeycombWatermarkOffsetXLandscape: Double {
        didSet { UserDefaults.standard.set(honeycombWatermarkOffsetXLandscape, forKey: "watermark_offsetX_landscape_honeycomb") }
    }
    public var honeycombWatermarkOffsetYLandscape: Double {
        didSet { UserDefaults.standard.set(honeycombWatermarkOffsetYLandscape, forKey: "watermark_offsetY_landscape_honeycomb") }
    }
    public var currentGameWatermarkOffsetXLandscape: Double {
        get {
            switch gameMode {
            case .klondike:   return klondikeWatermarkOffsetXLandscape
            case .beecell:    return beecellWatermarkOffsetXLandscape
            case .spider:     return spiderWatermarkOffsetXLandscape
            case .videoPoker: return videoPokerWatermarkOffsetXLandscape
            case .blackjack:  return blackjackWatermarkOffsetXLandscape
            case .honeycomb:  return honeycombWatermarkOffsetXLandscape
            }
        }
        set {
            switch gameMode {
            case .klondike:   klondikeWatermarkOffsetXLandscape = newValue
            case .beecell:    beecellWatermarkOffsetXLandscape = newValue
            case .spider:     spiderWatermarkOffsetXLandscape = newValue
            case .videoPoker: videoPokerWatermarkOffsetXLandscape = newValue
            case .blackjack:  blackjackWatermarkOffsetXLandscape = newValue
            case .honeycomb:  honeycombWatermarkOffsetXLandscape = newValue
            }
        }
    }
    public var currentGameWatermarkOffsetYLandscape: Double {
        get {
            switch gameMode {
            case .klondike:   return klondikeWatermarkOffsetYLandscape
            case .beecell:    return beecellWatermarkOffsetYLandscape
            case .spider:     return spiderWatermarkOffsetYLandscape
            case .videoPoker: return videoPokerWatermarkOffsetYLandscape
            case .blackjack:  return blackjackWatermarkOffsetYLandscape
            case .honeycomb:  return honeycombWatermarkOffsetYLandscape
            }
        }
        set {
            switch gameMode {
            case .klondike:   klondikeWatermarkOffsetYLandscape = newValue
            case .beecell:    beecellWatermarkOffsetYLandscape = newValue
            case .spider:     spiderWatermarkOffsetYLandscape = newValue
            case .videoPoker: videoPokerWatermarkOffsetYLandscape = newValue
            case .blackjack:  blackjackWatermarkOffsetYLandscape = newValue
            case .honeycomb:  honeycombWatermarkOffsetYLandscape = newValue
            }
        }
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

    // MARK: - App-wide Sound/No Stress Mode/Honey Mode/Manually Dismiss Banners/Hide
    // Hint Button — true single source of truth via sharedOptions (see
    // SharedGameOptions.swift). AppCoordinator and all 6 game ViewModels hold the
    // exact same SharedGameOptions instance, so these are thin passthroughs, not
    // separate stored state — there's nothing left to keep in sync. (This used to be a
    // real bug: each game's own Options struct carried an independent duplicate field,
    // silently overwritten on every mode switch by whichever game you'd most recently
    // left "won".)
    public var isSoundEnabled: Bool {
        get { sharedOptions.isSoundEnabled }
        set { sharedOptions.isSoundEnabled = newValue }
    }
    public var noStressMode: Bool {
        get { sharedOptions.noStressMode }
        set { sharedOptions.noStressMode = newValue }
    }
    public var honeyMode: Bool {
        get { sharedOptions.honeyMode }
        set { sharedOptions.honeyMode = newValue }
    }
    public var manuallyDismissBanners: Bool {
        get { sharedOptions.manuallyDismissBanners }
        set { sharedOptions.manuallyDismissBanners = newValue }
    }
    public var hideHintButton: Bool {
        get { sharedOptions.hideHintButton }
        set { sharedOptions.hideHintButton = newValue }
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
    // dominantColor is persisted on CustomBackground itself (sampled once at import,
    // or via a one-time backfill for older ones) — falls back to currentFeltColor only
    // for the brief window before that backfill finishes for a pre-existing background.
    public var currentAccentTint: Color {
        guard let background = activeCustomBackground, let sampled = background.dominantColor
        else { return currentFeltColor }
        return sampled
    }
    #else
    // iOS has its own IOSCustomBackgroundManager (no dominant-color sampling yet) —
    // falls back to the felt color, same graceful-fallback this returns on mac before
    // an async sample finishes.
    public var currentAccentTint: Color { currentFeltColor }
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
        let sharedOptions = SharedGameOptions()
        self.sharedOptions = sharedOptions
        klondikeViewModel   = GameViewModel(sharedOptions: sharedOptions)
        beecellViewModel    = BeecellViewModel(sharedOptions: sharedOptions)
        spiderViewModel     = SpiderViewModel(sharedOptions: sharedOptions)
        videoPokerViewModel = VideoPokerViewModel(sharedOptions: sharedOptions)
        blackjackViewModel  = BlackjackViewModel(sharedOptions: sharedOptions)
        honeycombViewModel  = HoneycombViewModel(sharedOptions: sharedOptions)

        let saved = UserDefaults.standard.string(forKey: "selectedGameMode") ?? GameMode.klondike.rawValue
        self.gameMode = GameMode(rawValue: saved) ?? .klondike

        self.feltColor = FeltColorTheme(rawValue: UserDefaults.standard.string(forKey: "global_felt_color") ?? "") ?? .feltGreen
        self.cardBackTheme = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Solibee"
        self.showFeltVignette = UserDefaults.standard.object(forKey: "showFeltVignette") != nil
            ? UserDefaults.standard.bool(forKey: "showFeltVignette") : true
        self.hideBee = UserDefaults.standard.object(forKey: "global_hide_bee") != nil
            ? UserDefaults.standard.bool(forKey: "global_hide_bee") : false

        // Defaults below are calibrated per platform — mac's own values (dialed in via
        // mac's WatermarkScaleCalibrationSlider before it was removed there) and iOS's
        // own values (dialed in via iOS's own portrait/landscape sliders, also now
        // removed). Both platforms' calibration is done, so these are final constants,
        // not placeholders.
        #if os(iOS)
        let defaultKlondikeScale = 1.299, defaultKlondikeOffsetX = 0.0, defaultKlondikeOffsetY = -24.3
        let defaultBeecellScale = 1.297, defaultBeecellOffsetX = 0.0, defaultBeecellOffsetY = -24.2
        let defaultSpiderScale = 1.301, defaultSpiderOffsetX = 0.0, defaultSpiderOffsetY = -22.3
        let defaultVideoPokerScale = 1.881, defaultVideoPokerOffsetX = 0.0, defaultVideoPokerOffsetY = 15.3
        let defaultBlackjackScale = 1.880, defaultBlackjackOffsetX = 0.0, defaultBlackjackOffsetY = -15.3
        let defaultHoneycombScale = 1.440, defaultHoneycombOffsetX = -15.7, defaultHoneycombOffsetY = 75.8

        let defaultKlondikeScaleLandscape = 1.299, defaultKlondikeOffsetXLandscape = 0.0, defaultKlondikeOffsetYLandscape = 110.2
        let defaultBeecellScaleLandscape = 1.297, defaultBeecellOffsetXLandscape = 0.0, defaultBeecellOffsetYLandscape = 110.3
        let defaultSpiderScaleLandscape = 1.301, defaultSpiderOffsetXLandscape = 0.0, defaultSpiderOffsetYLandscape = 93.2
        let defaultVideoPokerScaleLandscape = 1.881, defaultVideoPokerOffsetXLandscape = 0.0, defaultVideoPokerOffsetYLandscape = 0.0
        let defaultBlackjackScaleLandscape = 1.880, defaultBlackjackOffsetXLandscape = 0.0, defaultBlackjackOffsetYLandscape = 0.0
        let defaultHoneycombScaleLandscape = 1.202, defaultHoneycombOffsetXLandscape = -12.8, defaultHoneycombOffsetYLandscape = 14.7
        #else
        let defaultKlondikeScale = 1.299, defaultKlondikeOffsetX = 0.0, defaultKlondikeOffsetY = 110.2
        let defaultBeecellScale = 1.297, defaultBeecellOffsetX = 0.0, defaultBeecellOffsetY = 110.3
        let defaultSpiderScale = 1.301, defaultSpiderOffsetX = 0.0, defaultSpiderOffsetY = 93.2
        let defaultVideoPokerScale = 1.881, defaultVideoPokerOffsetX = 0.0, defaultVideoPokerOffsetY = 0.0
        let defaultBlackjackScale = 1.880, defaultBlackjackOffsetX = 0.0, defaultBlackjackOffsetY = 0.0
        // Honeycomb (mac only) now anchors inside the board VStack's background at a
        // 600x600 base size instead of scaledToFit-ing the whole window (see
        // HoneycombView.swift) — same fix as Blackjack/Video Poker above. 1.202/-12.8/67.2
        // was calibrated against that old whole-window layer and means nothing against the
        // new anchor, so this resets to a neutral starting point (1.0/0/0) pending a fresh
        // eyeball pass. iOS's Honeycomb watermark is untouched, still reading
        // defaultHoneycombScale/OffsetX/OffsetY from the #if os(iOS) branch above.
        let defaultHoneycombScale = 1.0, defaultHoneycombOffsetX = 0.0, defaultHoneycombOffsetY = 0.0

        // mac has no orientation concept and never reads these — reusing the portrait
        // numbers just gives its copies *a* sane value; never surfaced in mac's UI.
        let defaultKlondikeScaleLandscape = defaultKlondikeScale, defaultKlondikeOffsetXLandscape = defaultKlondikeOffsetX, defaultKlondikeOffsetYLandscape = defaultKlondikeOffsetY
        let defaultBeecellScaleLandscape = defaultBeecellScale, defaultBeecellOffsetXLandscape = defaultBeecellOffsetX, defaultBeecellOffsetYLandscape = defaultBeecellOffsetY
        let defaultSpiderScaleLandscape = defaultSpiderScale, defaultSpiderOffsetXLandscape = defaultSpiderOffsetX, defaultSpiderOffsetYLandscape = defaultSpiderOffsetY
        let defaultVideoPokerScaleLandscape = defaultVideoPokerScale, defaultVideoPokerOffsetXLandscape = defaultVideoPokerOffsetX, defaultVideoPokerOffsetYLandscape = defaultVideoPokerOffsetY
        let defaultBlackjackScaleLandscape = defaultBlackjackScale, defaultBlackjackOffsetXLandscape = defaultBlackjackOffsetX, defaultBlackjackOffsetYLandscape = defaultBlackjackOffsetY
        let defaultHoneycombScaleLandscape = defaultHoneycombScale, defaultHoneycombOffsetXLandscape = defaultHoneycombOffsetX, defaultHoneycombOffsetYLandscape = defaultHoneycombOffsetY
        #endif

        self.klondikeWatermarkScale = UserDefaults.standard.object(forKey: "watermark_scale_klondike") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_klondike") : defaultKlondikeScale
        self.beecellWatermarkScale = UserDefaults.standard.object(forKey: "watermark_scale_beecell") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_beecell") : defaultBeecellScale
        self.spiderWatermarkScale = UserDefaults.standard.object(forKey: "watermark_scale_spider") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_spider") : defaultSpiderScale
        self.videoPokerWatermarkScale = UserDefaults.standard.object(forKey: "watermark_scale_videoPoker") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_videoPoker") : defaultVideoPokerScale
        self.blackjackWatermarkScale = UserDefaults.standard.object(forKey: "watermark_scale_blackjack") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_blackjack") : defaultBlackjackScale
        self.honeycombWatermarkScale = UserDefaults.standard.object(forKey: "watermark_scale_honeycomb") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_honeycomb") : defaultHoneycombScale
        self.klondikeWatermarkOffsetX = UserDefaults.standard.object(forKey: "watermark_offsetX_klondike") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_klondike") : defaultKlondikeOffsetX
        self.klondikeWatermarkOffsetY = UserDefaults.standard.object(forKey: "watermark_offsetY_klondike") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_klondike") : defaultKlondikeOffsetY
        self.beecellWatermarkOffsetX = UserDefaults.standard.object(forKey: "watermark_offsetX_beecell") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_beecell") : defaultBeecellOffsetX
        self.beecellWatermarkOffsetY = UserDefaults.standard.object(forKey: "watermark_offsetY_beecell") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_beecell") : defaultBeecellOffsetY
        self.spiderWatermarkOffsetX = UserDefaults.standard.object(forKey: "watermark_offsetX_spider") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_spider") : defaultSpiderOffsetX
        self.spiderWatermarkOffsetY = UserDefaults.standard.object(forKey: "watermark_offsetY_spider") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_spider") : defaultSpiderOffsetY
        self.videoPokerWatermarkOffsetX = UserDefaults.standard.object(forKey: "watermark_offsetX_videoPoker") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_videoPoker") : defaultVideoPokerOffsetX
        self.videoPokerWatermarkOffsetY = UserDefaults.standard.object(forKey: "watermark_offsetY_videoPoker") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_videoPoker") : defaultVideoPokerOffsetY
        self.blackjackWatermarkOffsetX = UserDefaults.standard.object(forKey: "watermark_offsetX_blackjack") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_blackjack") : defaultBlackjackOffsetX
        self.blackjackWatermarkOffsetY = UserDefaults.standard.object(forKey: "watermark_offsetY_blackjack") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_blackjack") : defaultBlackjackOffsetY
        self.honeycombWatermarkOffsetX = UserDefaults.standard.object(forKey: "watermark_offsetX_honeycomb") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_honeycomb") : defaultHoneycombOffsetX
        self.honeycombWatermarkOffsetY = UserDefaults.standard.object(forKey: "watermark_offsetY_honeycomb") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_honeycomb") : defaultHoneycombOffsetY

        // Landscape variant — final calibrated defaults (see the platform-conditional
        // block above).
        self.klondikeWatermarkScaleLandscape = UserDefaults.standard.object(forKey: "watermark_scale_landscape_klondike") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_landscape_klondike") : defaultKlondikeScaleLandscape
        self.beecellWatermarkScaleLandscape = UserDefaults.standard.object(forKey: "watermark_scale_landscape_beecell") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_landscape_beecell") : defaultBeecellScaleLandscape
        self.spiderWatermarkScaleLandscape = UserDefaults.standard.object(forKey: "watermark_scale_landscape_spider") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_landscape_spider") : defaultSpiderScaleLandscape
        self.videoPokerWatermarkScaleLandscape = UserDefaults.standard.object(forKey: "watermark_scale_landscape_videoPoker") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_landscape_videoPoker") : defaultVideoPokerScaleLandscape
        self.blackjackWatermarkScaleLandscape = UserDefaults.standard.object(forKey: "watermark_scale_landscape_blackjack") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_landscape_blackjack") : defaultBlackjackScaleLandscape
        self.honeycombWatermarkScaleLandscape = UserDefaults.standard.object(forKey: "watermark_scale_landscape_honeycomb") != nil
            ? UserDefaults.standard.double(forKey: "watermark_scale_landscape_honeycomb") : defaultHoneycombScaleLandscape
        self.klondikeWatermarkOffsetXLandscape = UserDefaults.standard.object(forKey: "watermark_offsetX_landscape_klondike") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_landscape_klondike") : defaultKlondikeOffsetXLandscape
        self.klondikeWatermarkOffsetYLandscape = UserDefaults.standard.object(forKey: "watermark_offsetY_landscape_klondike") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_landscape_klondike") : defaultKlondikeOffsetYLandscape
        self.beecellWatermarkOffsetXLandscape = UserDefaults.standard.object(forKey: "watermark_offsetX_landscape_beecell") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_landscape_beecell") : defaultBeecellOffsetXLandscape
        self.beecellWatermarkOffsetYLandscape = UserDefaults.standard.object(forKey: "watermark_offsetY_landscape_beecell") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_landscape_beecell") : defaultBeecellOffsetYLandscape
        self.spiderWatermarkOffsetXLandscape = UserDefaults.standard.object(forKey: "watermark_offsetX_landscape_spider") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_landscape_spider") : defaultSpiderOffsetXLandscape
        self.spiderWatermarkOffsetYLandscape = UserDefaults.standard.object(forKey: "watermark_offsetY_landscape_spider") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_landscape_spider") : defaultSpiderOffsetYLandscape
        self.videoPokerWatermarkOffsetXLandscape = UserDefaults.standard.object(forKey: "watermark_offsetX_landscape_videoPoker") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_landscape_videoPoker") : defaultVideoPokerOffsetXLandscape
        self.videoPokerWatermarkOffsetYLandscape = UserDefaults.standard.object(forKey: "watermark_offsetY_landscape_videoPoker") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_landscape_videoPoker") : defaultVideoPokerOffsetYLandscape
        self.blackjackWatermarkOffsetXLandscape = UserDefaults.standard.object(forKey: "watermark_offsetX_landscape_blackjack") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_landscape_blackjack") : defaultBlackjackOffsetXLandscape
        self.blackjackWatermarkOffsetYLandscape = UserDefaults.standard.object(forKey: "watermark_offsetY_landscape_blackjack") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_landscape_blackjack") : defaultBlackjackOffsetYLandscape
        self.honeycombWatermarkOffsetXLandscape = UserDefaults.standard.object(forKey: "watermark_offsetX_landscape_honeycomb") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetX_landscape_honeycomb") : defaultHoneycombOffsetXLandscape
        self.honeycombWatermarkOffsetYLandscape = UserDefaults.standard.object(forKey: "watermark_offsetY_landscape_honeycomb") != nil
            ? UserDefaults.standard.double(forKey: "watermark_offsetY_landscape_honeycomb") : defaultHoneycombOffsetYLandscape

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

        // isSoundEnabled/noStressMode/honeyMode/manuallyDismissBanners/hideHintButton
        // need no init here — sharedOptions (constructed above) already loaded them
        // from UserDefaults itself, and these are just computed passthroughs to it.
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

        observeFaceArtChangesForLiveSave()

        // No Stress Mode's timer start/stop reaction is dispatched only to whichever
        // game is currently active — sharedOptions is one instance shared by every
        // game, so if each ViewModel reacted to its own change independently, toggling
        // No Stress Mode would also spuriously resume a *backgrounded* game's stopped
        // timer on an abandoned hand nobody is looking at (the exact bug
        // testBackgroundGameTimerDoesNotResumeFromAnotherGamesOptionsSync guards
        // against). Video Poker/Blackjack/Honeycomb have no timer, so they're skipped.
        sharedOptions.onNoStressModeChange { [weak self] in
            guard let self else { return }
            switch self.gameMode {
            case .klondike:   self.klondikeViewModel.reactToNoStressModeChange()
            case .beecell:    self.beecellViewModel.reactToNoStressModeChange()
            case .spider:     self.spiderViewModel.reactToNoStressModeChange()
            case .videoPoker, .blackjack, .honeycomb: break
            }
        }
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

    // Honeycomb-only counterpart to debugFireBanner above, for BannerCatalog's full
    // flavor-text catalog (DebugBannerCatalogMenu) rather than the fixed
    // win/loss/same/plus/suddenDeath DebugBannerKind set — same switch-game-mode-first
    // pattern so it can be fired from Mac's always-visible menu bar regardless of which
    // game is currently on screen.
    public func debugFireCatalogBanner(_ id: BannerID) {
        let delay: Double = (gameMode != .honeycomb) ? 0.35 : 0
        if gameMode != .honeycomb { gameMode = .honeycomb }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.honeycombViewModel.debugFireCatalogBanner(id)
        }
    }
}
