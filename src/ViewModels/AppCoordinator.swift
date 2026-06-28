import Foundation
import Observation
import SwiftUI
import AppKit

@Observable
public final class AppCoordinator {
    public var gameMode: GameMode {
        didSet {
            UserDefaults.standard.set(gameMode.rawValue, forKey: "selectedGameMode")
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
        let isTimed:         Bool
        let isSoundEnabled:  Bool
        let hideHintButton:  Bool
        let hideStatsButton: Bool
        let isDarkMode:      Bool

        switch old {
        case .klondike:
            isTimed         = klondikeViewModel.options.isTimed
            isSoundEnabled  = klondikeViewModel.options.isSoundEnabled
            hideHintButton  = klondikeViewModel.options.hideHintButton
            hideStatsButton = klondikeViewModel.options.hideStatsButton
            isDarkMode      = klondikeViewModel.options.isDarkMode
        case .beecell:
            isTimed         = beecellViewModel.options.isTimed
            isSoundEnabled  = beecellViewModel.options.isSoundEnabled
            hideHintButton  = beecellViewModel.options.hideHintButton
            hideStatsButton = beecellViewModel.options.hideStatsButton
            isDarkMode      = beecellViewModel.options.isDarkMode
        case .spider:
            isTimed         = spiderViewModel.options.isTimed
            isSoundEnabled  = spiderViewModel.options.isSoundEnabled
            hideHintButton  = spiderViewModel.options.hideHintButton
            hideStatsButton = spiderViewModel.options.hideStatsButton
            isDarkMode      = spiderViewModel.options.isDarkMode
        case .videoPoker:
            isTimed         = videoPokerViewModel.options.isTimed
            isSoundEnabled  = videoPokerViewModel.options.isSoundEnabled
            hideHintButton  = videoPokerViewModel.options.hideHintButton
            hideStatsButton = videoPokerViewModel.options.hideStatsButton
            isDarkMode      = videoPokerViewModel.options.isDarkMode
        case .blackjack:
            isTimed         = blackjackViewModel.options.isTimed
            isSoundEnabled  = blackjackViewModel.options.isSoundEnabled
            hideHintButton  = false
            hideStatsButton = blackjackViewModel.options.hideStatsButton
            isDarkMode      = blackjackViewModel.options.isDarkMode
        }

        if new != .klondike {
            klondikeViewModel.options.isTimed         = isTimed
            klondikeViewModel.options.isSoundEnabled  = isSoundEnabled
            klondikeViewModel.options.hideHintButton  = hideHintButton
            klondikeViewModel.options.hideStatsButton = hideStatsButton
            klondikeViewModel.options.isDarkMode      = isDarkMode
        }
        if new != .beecell {
            beecellViewModel.options.isTimed         = isTimed
            beecellViewModel.options.isSoundEnabled  = isSoundEnabled
            beecellViewModel.options.hideHintButton  = hideHintButton
            beecellViewModel.options.hideStatsButton = hideStatsButton
            beecellViewModel.options.isDarkMode      = isDarkMode
        }
        if new != .spider {
            spiderViewModel.options.isTimed         = isTimed
            spiderViewModel.options.isSoundEnabled  = isSoundEnabled
            spiderViewModel.options.hideHintButton  = hideHintButton
            spiderViewModel.options.hideStatsButton = hideStatsButton
            spiderViewModel.options.isDarkMode      = isDarkMode
        }
        if new != .videoPoker {
            videoPokerViewModel.options.isTimed         = isTimed
            videoPokerViewModel.options.isSoundEnabled  = isSoundEnabled
            videoPokerViewModel.options.hideHintButton  = hideHintButton
            videoPokerViewModel.options.hideStatsButton = hideStatsButton
            videoPokerViewModel.options.isDarkMode      = isDarkMode
        }
        if new != .blackjack {
            blackjackViewModel.options.isTimed         = isTimed
            blackjackViewModel.options.isSoundEnabled  = isSoundEnabled
            blackjackViewModel.options.hideStatsButton = hideStatsButton
            blackjackViewModel.options.isDarkMode      = isDarkMode
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
        case .klondike:  klondikeViewModel.zoomIn()
        case .beecell:   beecellViewModel.zoomIn()
        case .spider:    spiderViewModel.zoomIn()
        case .videoPoker, .blackjack: break
        }
    }

    public func zoomOut() {
        switch gameMode {
        case .klondike:  klondikeViewModel.zoomOut()
        case .beecell:   beecellViewModel.zoomOut()
        case .spider:    spiderViewModel.zoomOut()
        case .videoPoker, .blackjack: break
        }
    }

    public func resetZoom() {
        switch gameMode {
        case .klondike:  klondikeViewModel.resetZoom()
        case .beecell:   beecellViewModel.resetZoom()
        case .spider:    spiderViewModel.resetZoom()
        case .videoPoker, .blackjack: break
        }
    }

    public func makeCurrentZoomDefault() {
        switch gameMode {
        case .klondike:  klondikeViewModel.makeCurrentZoomDefault()
        case .beecell:   beecellViewModel.makeCurrentZoomDefault()
        case .spider:    spiderViewModel.makeCurrentZoomDefault()
        case .videoPoker, .blackjack: break
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

        var k = klondikeViewModel.options
        k.cardBackTheme = theme.cardBackTheme
        k.isDarkMode    = theme.isDarkMode
        k.feltColor     = theme.feltColor
        k.customFeltColorRevision += 1
        klondikeViewModel.options = k

        var b = beecellViewModel.options
        b.cardBackTheme = theme.cardBackTheme
        b.isDarkMode    = theme.isDarkMode
        b.feltColor     = theme.feltColor
        b.customFeltColorRevision += 1
        beecellViewModel.options = b

        var s = spiderViewModel.options
        s.cardBackTheme = theme.cardBackTheme
        s.isDarkMode    = theme.isDarkMode
        s.feltColor     = theme.feltColor
        s.customFeltColorRevision += 1
        spiderViewModel.options = s

        var v = videoPokerViewModel.options
        v.cardBackTheme = theme.cardBackTheme
        v.isDarkMode    = theme.isDarkMode
        v.feltColor     = theme.feltColor
        v.customFeltColorRevision += 1
        videoPokerViewModel.options = v

        var bj = blackjackViewModel.options
        bj.cardBackTheme = theme.cardBackTheme
        bj.isDarkMode    = theme.isDarkMode
        bj.feltColor     = theme.feltColor
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
}
