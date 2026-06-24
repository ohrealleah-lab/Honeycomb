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
    
    public let klondikeViewModel = GameViewModel()
    public let beecellViewModel = BeecellViewModel()
    public let spiderViewModel = SpiderViewModel()
    
    public init() {
        let saved = UserDefaults.standard.string(forKey: "selectedGameMode") ?? GameMode.klondike.rawValue
        self.gameMode = GameMode(rawValue: saved) ?? .klondike
    }
    
    // Copy isTimed, isSoundEnabled, hideHintButton, hideStatsButton from the outgoing game to all others.
    private func syncSharedOptions(from old: GameMode, to new: GameMode) {
        let isTimed: Bool
        let isSoundEnabled: Bool
        let hideHintButton: Bool
        let hideStatsButton: Bool

        switch old {
        case .klondike:
            isTimed = klondikeViewModel.options.isTimed
            isSoundEnabled = klondikeViewModel.options.isSoundEnabled
            hideHintButton = klondikeViewModel.options.hideHintButton
            hideStatsButton = klondikeViewModel.options.hideStatsButton
        case .beecell:
            isTimed = beecellViewModel.options.isTimed
            isSoundEnabled = beecellViewModel.options.isSoundEnabled
            hideHintButton = beecellViewModel.options.hideHintButton
            hideStatsButton = beecellViewModel.options.hideStatsButton
        case .spider:
            isTimed = spiderViewModel.options.isTimed
            isSoundEnabled = spiderViewModel.options.isSoundEnabled
            hideHintButton = spiderViewModel.options.hideHintButton
            hideStatsButton = spiderViewModel.options.hideStatsButton
        }

        if new != .klondike {
            klondikeViewModel.options.isTimed = isTimed
            klondikeViewModel.options.isSoundEnabled = isSoundEnabled
            klondikeViewModel.options.hideHintButton = hideHintButton
            klondikeViewModel.options.hideStatsButton = hideStatsButton
        }
        if new != .beecell {
            beecellViewModel.options.isTimed = isTimed
            beecellViewModel.options.isSoundEnabled = isSoundEnabled
            beecellViewModel.options.hideHintButton = hideHintButton
            beecellViewModel.options.hideStatsButton = hideStatsButton
        }
        if new != .spider {
            spiderViewModel.options.isTimed = isTimed
            spiderViewModel.options.isSoundEnabled = isSoundEnabled
            spiderViewModel.options.hideHintButton = hideHintButton
            spiderViewModel.options.hideStatsButton = hideStatsButton
        }
    }

    public func startNewGame() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.startNewGame()
        case .beecell:
            beecellViewModel.startNewGame()
        case .spider:
            spiderViewModel.startNewGame()
        }
    }
    
    public func restartCurrentGame() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.restartCurrentGame()
        case .beecell:
            beecellViewModel.restartCurrentGame()
        case .spider:
            spiderViewModel.restartCurrentGame()
        }
    }
    
    public func undoLastAction() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.undoLastAction()
        case .beecell:
            beecellViewModel.undoLastAction()
        case .spider:
            spiderViewModel.undoLastAction()
        }
    }
    
    public var canUndo: Bool {
        switch gameMode {
        case .klondike:
            return klondikeViewModel.canUndo
        case .beecell:
            return beecellViewModel.canUndo
        case .spider:
            return spiderViewModel.canUndo
        }
    }
    
    public func zoomIn() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.zoomIn()
        case .beecell:
            beecellViewModel.zoomIn()
        case .spider:
            spiderViewModel.zoomIn()
        }
    }
    
    public func zoomOut() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.zoomOut()
        case .beecell:
            beecellViewModel.zoomOut()
        case .spider:
            spiderViewModel.zoomOut()
        }
    }
    
    public func resetZoom() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.resetZoom()
        case .beecell:
            beecellViewModel.resetZoom()
        case .spider:
            spiderViewModel.resetZoom()
        }
    }
    
    public func makeCurrentZoomDefault() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.makeCurrentZoomDefault()
        case .beecell:
            beecellViewModel.makeCurrentZoomDefault()
        case .spider:
            spiderViewModel.makeCurrentZoomDefault()
        }
    }
    
    public func resetStatistics() {
        switch gameMode {
        case .klondike:
            klondikeViewModel.resetStatistics()
        case .beecell:
            beecellViewModel.resetStatistics()
        case .spider:
            spiderViewModel.resetStatistics()
        }
    }

    public func triggerWinAnimation() {
        let suits: [Card.Suit] = [.spades, .clubs, .diamonds, .hearts]
        func fullFoundations(count: Int) -> [Pile] {
            (0..<count).map { i in
                let suit = suits[i % suits.count]
                let cards = (1...13).map { rank in
                    Card(suit: suit, rank: rank, faceUp: true)
                }
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
        }
    }
}
