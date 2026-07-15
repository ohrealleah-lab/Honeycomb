import Foundation
import Observation
import SwiftUI
import AppKit

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
            case .videoPoker, .blackjack: break
            }
            syncSharedOptions(from: oldValue, to: gameMode)
        }
    }

    public let klondikeViewModel   = GameViewModel()
    public let beecellViewModel    = BeecellViewModel()
    public let spiderViewModel     = SpiderViewModel()
    public let videoPokerViewModel = VideoPokerViewModel()
    public let blackjackViewModel  = BlackjackViewModel()

    // MARK: - App-wide theme (single source of truth for all 5 games, live-shared —
    // not per-game, not copy-on-mode-switch). Persisted to the same UserDefaults keys
    // every game's Options struct used to write independently before this refactor, so
    // existing users' last-used theme carries over with no migration step.
    public var feltColor: FeltColorTheme {
        didSet { UserDefaults.standard.set(feltColor.rawValue, forKey: "global_felt_color") }
    }
    public var cardBackTheme: String {
        didSet { UserDefaults.standard.set(cardBackTheme, forKey: "cardBackTheme") }
    }
    public var showFeltVignette: Bool {
        didSet { UserDefaults.standard.set(showFeltVignette, forKey: "showFeltVignette") }
    }
    public var customCardColors: CustomCardColorGroup {
        didSet {
            if let encoded = try? JSONEncoder().encode(customCardColors) {
                UserDefaults.standard.set(encoded, forKey: "customCardColors")
            }
        }
    }
    public var customFeltRed: Double {
        didSet { UserDefaults.standard.set(customFeltRed, forKey: "custom_felt_red") }
    }
    public var customFeltGreen: Double {
        didSet { UserDefaults.standard.set(customFeltGreen, forKey: "custom_felt_green") }
    }
    public var customFeltBlue: Double {
        didSet { UserDefaults.standard.set(customFeltBlue, forKey: "custom_felt_blue") }
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
        }
    }

    public var activeCustomBackground: CustomBackground? {
        guard let customBackgroundName else { return nil }
        return CustomBackgroundManager.shared.customBackgrounds.first { $0.name == customBackgroundName }
    }

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
    // The NSWindow currently hosting the active game mode's view, kept up to date
    // by each game view's WindowAccessor so window-level actions (e.g. "make current
    // window size default") can be triggered from menu commands that don't own a window.
    @ObservationIgnored public weak var activeWindow: NSWindow?

    public init() {
        let saved = UserDefaults.standard.string(forKey: "selectedGameMode") ?? GameMode.klondike.rawValue
        self.gameMode = GameMode(rawValue: saved) ?? .klondike

        self.feltColor = FeltColorTheme(rawValue: UserDefaults.standard.string(forKey: "global_felt_color") ?? "") ?? .feltGreen
        self.cardBackTheme = UserDefaults.standard.string(forKey: "cardBackTheme") ?? "Moogle"
        self.showFeltVignette = UserDefaults.standard.object(forKey: "showFeltVignette") != nil
            ? UserDefaults.standard.bool(forKey: "showFeltVignette") : true
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

        // Each view model sets UISound.isEnabled from its own persisted setting as it
        // initializes above; re-assert it from the actually-active mode here so the
        // last view model to init doesn't silently win if settings ever drift out of sync.
        switch gameMode {
        case .klondike:   UISound.isEnabled = klondikeViewModel.options.isSoundEnabled
        case .beecell:    UISound.isEnabled = beecellViewModel.options.isSoundEnabled
        case .spider:     UISound.isEnabled = spiderViewModel.options.isSoundEnabled
        case .videoPoker: UISound.isEnabled = videoPokerViewModel.options.isSoundEnabled
        case .blackjack:  UISound.isEnabled = blackjackViewModel.options.isSoundEnabled
        }
    }

    // MARK: - Shared option sync (genuinely per-game gameplay prefs only — theme fields
    // above are a single live-shared store and need no propagation on mode switch)

    private func syncSharedOptions(from old: GameMode, to new: GameMode) {
        let isSoundEnabled:   Bool
        // hideHintButton is only read from games that actually have a Hint button —
        // Blackjack doesn't, so it's Optional like isTimed rather than a hardcoded
        // placeholder that would otherwise get force-propagated to the other games.
        let hideHintButton:   Bool?
        let noStressMode:     Bool
        // isTimed is only read from solitaire games — VP/BJ don't have a real timer preference
        let isTimed:          Bool?

        switch old {
        case .klondike:
            isSoundEnabled    = klondikeViewModel.options.isSoundEnabled
            hideHintButton    = klondikeViewModel.options.hideHintButton
            noStressMode      = klondikeViewModel.options.noStressMode
            isTimed           = klondikeViewModel.options.isTimed
        case .beecell:
            isSoundEnabled    = beecellViewModel.options.isSoundEnabled
            hideHintButton    = beecellViewModel.options.hideHintButton
            noStressMode      = beecellViewModel.options.noStressMode
            isTimed           = beecellViewModel.options.isTimed
        case .spider:
            isSoundEnabled    = spiderViewModel.options.isSoundEnabled
            hideHintButton    = spiderViewModel.options.hideHintButton
            noStressMode      = spiderViewModel.options.noStressMode
            isTimed           = spiderViewModel.options.isTimed
        case .videoPoker:
            isSoundEnabled    = videoPokerViewModel.options.isSoundEnabled
            hideHintButton    = videoPokerViewModel.options.hideHintButton
            noStressMode      = videoPokerViewModel.options.noStressMode
            isTimed           = nil  // don't propagate VP's timer concept to solitaire games
        case .blackjack:
            isSoundEnabled    = blackjackViewModel.options.isSoundEnabled
            hideHintButton    = nil  // Blackjack has no Hint button/preference to propagate
            noStressMode      = blackjackViewModel.options.noStressMode
            isTimed           = nil  // don't propagate BJ's timer concept to solitaire games
        }

        if old != .klondike {
            klondikeViewModel.options.isSoundEnabled   = isSoundEnabled
            klondikeViewModel.options.noStressMode     = noStressMode
            if let hideHintButton { klondikeViewModel.options.hideHintButton = hideHintButton }
            if let isTimed { klondikeViewModel.options.isTimed = isTimed }
        }
        if old != .beecell {
            beecellViewModel.options.isSoundEnabled   = isSoundEnabled
            beecellViewModel.options.noStressMode     = noStressMode
            if let hideHintButton { beecellViewModel.options.hideHintButton = hideHintButton }
            if let isTimed { beecellViewModel.options.isTimed = isTimed }
        }
        if old != .spider {
            spiderViewModel.options.isSoundEnabled   = isSoundEnabled
            spiderViewModel.options.noStressMode     = noStressMode
            if let hideHintButton { spiderViewModel.options.hideHintButton = hideHintButton }
            if let isTimed { spiderViewModel.options.isTimed = isTimed }
        }
        if old != .videoPoker {
            videoPokerViewModel.options.isSoundEnabled   = isSoundEnabled
            videoPokerViewModel.options.noStressMode     = noStressMode
            if let hideHintButton { videoPokerViewModel.options.hideHintButton = hideHintButton }
        }
        if old != .blackjack {
            blackjackViewModel.options.isSoundEnabled   = isSoundEnabled
            blackjackViewModel.options.noStressMode     = noStressMode
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
        }
    }

    public func restartCurrentGame() {
        switch gameMode {
        case .klondike:   klondikeViewModel.restartCurrentGame()
        case .beecell:    beecellViewModel.restartCurrentGame()
        case .spider:     spiderViewModel.restartCurrentGame()
        case .videoPoker: videoPokerViewModel.restartCurrentGame()
        case .blackjack:  blackjackViewModel.restartCurrentGame()
        }
    }

    public func undoLastAction() {
        switch gameMode {
        case .klondike:  klondikeViewModel.undoLastAction()
        case .beecell:   beecellViewModel.undoLastAction()
        case .spider:    spiderViewModel.undoLastAction()
        case .videoPoker, .blackjack: break
        }
    }

    public var canUndo: Bool {
        switch gameMode {
        case .klondike:  return klondikeViewModel.canUndo
        case .beecell:   return beecellViewModel.canUndo
        case .spider:    return spiderViewModel.canUndo
        case .videoPoker, .blackjack: return false
        }
    }

    public func zoomIn() {
        switch gameMode {
        case .klondike:   klondikeViewModel.zoomIn()
        case .beecell:    beecellViewModel.zoomIn()
        case .spider:     spiderViewModel.zoomIn()
        case .videoPoker: videoPokerViewModel.zoomIn()
        case .blackjack:  blackjackViewModel.zoomIn()
        }
    }

    public func zoomOut() {
        switch gameMode {
        case .klondike:   klondikeViewModel.zoomOut()
        case .beecell:    beecellViewModel.zoomOut()
        case .spider:     spiderViewModel.zoomOut()
        case .videoPoker: videoPokerViewModel.zoomOut()
        case .blackjack:  blackjackViewModel.zoomOut()
        }
    }

    public func resetZoom() {
        switch gameMode {
        case .klondike:   klondikeViewModel.resetZoom()
        case .beecell:    beecellViewModel.resetZoom()
        case .spider:     spiderViewModel.resetZoom()
        case .videoPoker: videoPokerViewModel.resetZoom()
        case .blackjack:  blackjackViewModel.resetZoom()
        }
    }

    public func makeCurrentZoomDefault() {
        switch gameMode {
        case .klondike:   klondikeViewModel.makeCurrentZoomDefault()
        case .beecell:    beecellViewModel.makeCurrentZoomDefault()
        case .spider:     spiderViewModel.makeCurrentZoomDefault()
        case .videoPoker: videoPokerViewModel.makeCurrentZoomDefault()
        case .blackjack:  blackjackViewModel.makeCurrentZoomDefault()
        }
    }

    public func makeCurrentWindowSizeDefault() {
        guard let window = activeWindow else { return }
        let size = window.contentView?.frame.size ?? window.frame.size
        switch gameMode {
        case .klondike:   klondikeViewModel.makeCurrentWindowSizeDefault(size)
        case .beecell:    beecellViewModel.makeCurrentWindowSizeDefault(size)
        case .spider:     spiderViewModel.makeCurrentWindowSizeDefault(size)
        case .videoPoker: videoPokerViewModel.makeCurrentWindowSizeDefault(size)
        case .blackjack:  blackjackViewModel.makeCurrentWindowSizeDefault(size)
        }
    }

    public func resetStatistics() {
        switch gameMode {
        case .klondike:   klondikeViewModel.resetStatistics()
        case .beecell:    beecellViewModel.resetStatistics()
        case .spider:     spiderViewModel.resetStatistics()
        case .videoPoker: videoPokerViewModel.resetStatistics()
        case .blackjack:  blackjackViewModel.resetStatistics()
        }
    }

    public func applyTheme(_ theme: SoliBeeTheme) {
        cardBackTheme = theme.cardBackTheme
        feltColor     = theme.feltColor
        customCardColors = theme.customCardColors
        if theme.feltColor == .custom {
            customFeltRed   = theme.customFeltRed
            customFeltGreen = theme.customFeltGreen
            customFeltBlue  = theme.customFeltBlue
        }
        customBackgroundName = theme.customBackgroundName
        
        if let name = customBackgroundName,
           let bg = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }) {
            print("[DEBUG] AppCoordinator.applyTheme: resolved custom background name '\(name)' to relativePath '\(bg.relativePath)'. Calling image(for:).")
            let _ = CustomBackgroundManager.shared.image(for: bg.relativePath)
        } else {
            print("[DEBUG] AppCoordinator.applyTheme: customBackgroundName is \(customBackgroundName ?? "nil"), bg resolved? \(customBackgroundName != nil ? String(describing: CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == customBackgroundName! }) != nil) : "N/A")")
        }

        CustomFaceCardArtManager.shared.restore(theme.faceArts)
        ThemeManager.shared.activeThemeId = theme.id
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
        case .videoPoker, .blackjack:
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
            }
        }
    }
}
