import SwiftUI

public enum DebugBannerKind {
    case win, loss, stuck, autocomplete
    case same, plus, suddenDeath
}

struct DebugBannerCommands: View {
    let coordinator: AppCoordinator

    var body: some View {
        Menu("Klondike") {
            Button("Win")          { coordinator.debugFireBanner(.win,         for: .klondike) }
            Button("Loss (Stuck)") { coordinator.debugFireBanner(.stuck,       for: .klondike) }
            Button("Autocomplete") { coordinator.debugFireBanner(.autocomplete, for: .klondike) }
        }
        Menu("Freecell") {
            Button("Win")          { coordinator.debugFireBanner(.win,         for: .beecell) }
            Button("Loss (Stuck)") { coordinator.debugFireBanner(.stuck,       for: .beecell) }
            Button("Autocomplete") { coordinator.debugFireBanner(.autocomplete, for: .beecell) }
        }
        Menu("Spider") {
            Button("Win")          { coordinator.debugFireBanner(.win,         for: .spider) }
            Button("Loss (Stuck)") { coordinator.debugFireBanner(.stuck,       for: .spider) }
            Button("Autocomplete") { coordinator.debugFireBanner(.autocomplete, for: .spider) }
        }
        Menu("Video Poker") {
            Button("Win")  { coordinator.debugFireBanner(.win,  for: .videoPoker) }
            Button("Loss") { coordinator.debugFireBanner(.loss, for: .videoPoker) }
        }
        Menu("Blackjack") {
            Button("Win")  { coordinator.debugFireBanner(.win,  for: .blackjack) }
            Button("Loss") { coordinator.debugFireBanner(.loss, for: .blackjack) }
        }
        Menu("Honeycomb") {
            Button("Win")          { coordinator.debugFireBanner(.win,         for: .honeycomb) }
            Button("Loss")         { coordinator.debugFireBanner(.loss,        for: .honeycomb) }
            Divider()
            Button("Same")         { coordinator.debugFireBanner(.same,        for: .honeycomb) }
            Button("Plus")         { coordinator.debugFireBanner(.plus,        for: .honeycomb) }
            Button("Sudden Death") { coordinator.debugFireBanner(.suddenDeath, for: .honeycomb) }
        }
    }
}
