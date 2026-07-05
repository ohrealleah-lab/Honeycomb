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

    public init() {
        let saved = UserDefaults.standard.string(forKey: "selectedGameMode") ?? GameMode.klondike.rawValue
        self.gameMode = GameMode(rawValue: saved) ?? .klondike
    }

    // MARK: - Shared option sync

    private func syncSharedOptions(from old: GameMode, to new: GameMode) {
        let isSoundEnabled:   Bool
        let hideHintButton:   Bool
        let hideStatsButton:  Bool
        let showFeltVignette: Bool
        let customCardColors: CustomCardColorGroup
        // isTimed is only read from solitaire games — VP/BJ don't have a real timer preference
        let isTimed:          Bool?

        switch old {
        case .klondike:
            isSoundEnabled    = klondikeViewModel.options.isSoundEnabled
            hideHintButton    = klondikeViewModel.options.hideHintButton
            hideStatsButton   = klondikeViewModel.options.hideStatsButton
            showFeltVignette  = klondikeViewModel.options.showFeltVignette
            customCardColors  = klondikeViewModel.options.customCardColors
            isTimed           = klondikeViewModel.options.isTimed
        case .beecell:
            isSoundEnabled    = beecellViewModel.options.isSoundEnabled
            hideHintButton    = beecellViewModel.options.hideHintButton
            hideStatsButton   = beecellViewModel.options.hideStatsButton
            showFeltVignette  = beecellViewModel.options.showFeltVignette
            customCardColors  = beecellViewModel.options.customCardColors
            isTimed           = beecellViewModel.options.isTimed
        case .spider:
            isSoundEnabled    = spiderViewModel.options.isSoundEnabled
            hideHintButton    = spiderViewModel.options.hideHintButton
            hideStatsButton   = spiderViewModel.options.hideStatsButton
            showFeltVignette  = spiderViewModel.options.showFeltVignette
            customCardColors  = spiderViewModel.options.customCardColors
            isTimed           = spiderViewModel.options.isTimed
        case .videoPoker:
            isSoundEnabled    = videoPokerViewModel.options.isSoundEnabled
            hideHintButton    = videoPokerViewModel.options.hideHintButton
            hideStatsButton   = videoPokerViewModel.options.hideStatsButton
            showFeltVignette  = videoPokerViewModel.options.showFeltVignette
            customCardColors  = videoPokerViewModel.options.customCardColors
            isTimed           = nil  // don't propagate VP's timer concept to solitaire games
        case .blackjack:
            isSoundEnabled    = blackjackViewModel.options.isSoundEnabled
            hideHintButton    = false
            hideStatsButton   = blackjackViewModel.options.hideStatsButton
            showFeltVignette  = blackjackViewModel.options.showFeltVignette
            customCardColors  = blackjackViewModel.options.customCardColors
            isTimed           = nil  // don't propagate BJ's timer concept to solitaire games
        }

        if old != .klondike {
            klondikeViewModel.options.isSoundEnabled   = isSoundEnabled
            klondikeViewModel.options.hideHintButton   = hideHintButton
            klondikeViewModel.options.hideStatsButton  = hideStatsButton
            klondikeViewModel.options.showFeltVignette = showFeltVignette
            klondikeViewModel.options.customCardColors = customCardColors
            if let isTimed { klondikeViewModel.options.isTimed = isTimed }
        }
        if old != .beecell {
            beecellViewModel.options.isSoundEnabled   = isSoundEnabled
            beecellViewModel.options.hideHintButton   = hideHintButton
            beecellViewModel.options.hideStatsButton  = hideStatsButton
            beecellViewModel.options.showFeltVignette = showFeltVignette
            beecellViewModel.options.customCardColors = customCardColors
            if let isTimed { beecellViewModel.options.isTimed = isTimed }
        }
        if old != .spider {
            spiderViewModel.options.isSoundEnabled   = isSoundEnabled
            spiderViewModel.options.hideHintButton   = hideHintButton
            spiderViewModel.options.hideStatsButton  = hideStatsButton
            spiderViewModel.options.showFeltVignette = showFeltVignette
            spiderViewModel.options.customCardColors = customCardColors
            if let isTimed { spiderViewModel.options.isTimed = isTimed }
        }
        if old != .videoPoker {
            videoPokerViewModel.options.isSoundEnabled   = isSoundEnabled
            videoPokerViewModel.options.hideHintButton   = hideHintButton
            videoPokerViewModel.options.hideStatsButton  = hideStatsButton
            videoPokerViewModel.options.showFeltVignette = showFeltVignette
            videoPokerViewModel.options.customCardColors = customCardColors
        }
        if old != .blackjack {
            blackjackViewModel.options.isSoundEnabled   = isSoundEnabled
            blackjackViewModel.options.hideStatsButton  = hideStatsButton
            blackjackViewModel.options.showFeltVignette = showFeltVignette
            blackjackViewModel.options.customCardColors = customCardColors
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
        if theme.feltColor == .custom {
            UserDefaults.standard.set(theme.customFeltRed,   forKey: "custom_felt_red")
            UserDefaults.standard.set(theme.customFeltGreen, forKey: "custom_felt_green")
            UserDefaults.standard.set(theme.customFeltBlue,  forKey: "custom_felt_blue")
        }
        
        // Save the theme's custom card colors globally so new views load it on init
        if let encoded = try? JSONEncoder().encode(theme.customCardColors) {
            UserDefaults.standard.set(encoded, forKey: "customCardColors")
        }

        var k = klondikeViewModel.options
        k.cardBackTheme = theme.cardBackTheme
        k.feltColor     = theme.feltColor
        k.customCardColors = theme.customCardColors
        k.customFeltColorRevision += 1
        klondikeViewModel.options = k

        var b = beecellViewModel.options
        b.cardBackTheme = theme.cardBackTheme
        b.feltColor     = theme.feltColor
        b.customCardColors = theme.customCardColors
        b.customFeltColorRevision += 1
        beecellViewModel.options = b

        var s = spiderViewModel.options
        s.cardBackTheme = theme.cardBackTheme
        s.feltColor     = theme.feltColor
        s.customCardColors = theme.customCardColors
        s.customFeltColorRevision += 1
        spiderViewModel.options = s

        var v = videoPokerViewModel.options
        v.cardBackTheme = theme.cardBackTheme
        v.feltColor     = theme.feltColor
        v.customCardColors = theme.customCardColors
        v.customFeltColorRevision += 1
        videoPokerViewModel.options = v

        var bj = blackjackViewModel.options
        bj.cardBackTheme = theme.cardBackTheme
        bj.feltColor     = theme.feltColor
        bj.customCardColors = theme.customCardColors
        bj.customFeltColorRevision += 1
        blackjackViewModel.options = bj

        CustomFaceCardArtManager.shared.restore(theme.faceArts)
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
