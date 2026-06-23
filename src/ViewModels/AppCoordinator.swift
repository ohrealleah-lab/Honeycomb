import Foundation
import Observation
import SwiftUI
import AppKit

@Observable
public final class AppCoordinator {
    public var gameMode: GameMode {
        didSet {
            UserDefaults.standard.set(gameMode.rawValue, forKey: "selectedGameMode")
        }
    }
    
    public let klondikeViewModel = GameViewModel()
    public let beecellViewModel = BeecellViewModel()
    public let spiderViewModel = SpiderViewModel()
    
    public init() {
        let saved = UserDefaults.standard.string(forKey: "selectedGameMode") ?? GameMode.klondike.rawValue
        self.gameMode = GameMode(rawValue: saved) ?? .klondike
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
