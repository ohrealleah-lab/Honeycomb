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
}
