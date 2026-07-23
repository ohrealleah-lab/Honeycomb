import SwiftUI

public struct HoneycombStatsView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: HoneycombViewModel

    @State private var profile = HoneycombProfileManager.shared
    @State private var showingResetConfirmation = false
    private let db = HoneycombDatabase.shared

    private var suitOrder: [(code: String, label: String)] {
        [("S", "Spades"), ("H", "Hearts"), ("D", "Diamonds"), ("C", "Clubs")]
    }

    private func suitProgress(_ suit: String) -> (unlocked: Int, total: Int) {
        let cards = db.allCards.filter { $0.suit == suit }
        let unlocked = cards.filter { profile.unlockedCardIds.contains($0.id) }.count
        return (unlocked, cards.count)
    }

    private func starProgress(_ star: Int) -> (unlocked: Int, total: Int) {
        let cards = db.allCards.filter { $0.stars == star }
        let unlocked = cards.filter { profile.unlockedCardIds.contains($0.id) }.count
        return (unlocked, cards.count)
    }

    public var body: some View {
        let stats = viewModel.stats
        let decisiveGames = stats.gamesPlayed - stats.matchesDrawn
        let winRate = decisiveGames > 0 ? Double(stats.matchesWon) / Double(decisiveGames) * 100 : 0
        let totalUnlocked = profile.unlockedCardIds.count
        let totalCards = db.allCards.count
        let unlockedPercent = totalCards > 0 ? Double(totalUnlocked) / Double(totalCards) * 100 : 0

        VStack(spacing: 20) {
            Text("Honeycomb Statistics")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                    StatRow(label: "Matches Won", value: "\(stats.matchesWon)")
                    StatRow(label: "Matches Lost", value: "\(stats.matchesLost)")
                    StatRow(label: "Matches Drawn", value: "\(stats.matchesDrawn)")
                    StatRow(label: "Most Sudden Deaths", value: "\(stats.suddenDeathCount)")
                    StatRow(label: "Win Rate", value: String(format: "%.1f%%", winRate))

                    Divider()

                    StatRow(label: "Current Win Streak", value: "\(stats.currentWinStreak)")
                    StatRow(label: "Longest Win Streak", value: "\(stats.longestWinStreak)")
                    StatRow(label: "Flawless Victories (10-0 Sweep)", value: "\(stats.flawlessVictories)")
                    StatRow(label: "Baby Bee Wins", value: "\(stats.easyWins)")
                    StatRow(label: "Honey Bee Wins", value: "\(stats.mediumWins)")
                    StatRow(label: "Queen Bee Wins", value: "\(stats.hardWins)")
                    StatRow(label: "Killer Bee Wins", value: "\(stats.ultraHardWins)")

                    Divider()

                    StatRow(label: "Total Cards Flipped", value: "\(stats.cardsCaptured)")
                    StatRow(label: "Fallen Aces", value: "\(stats.fallenAces)")
                    StatRow(label: "Same/Plus Combos Triggered", value: "\(stats.samePlusTriggers)")
                    StatRow(label: "Cards Stolen", value: "\(stats.cardsStolen)")
                    StatRow(label: "Times Started Over", value: "\(stats.timesStartedOver)")

                    Divider()

                    StatRow(label: "Cards Unlocked", value: "\(totalUnlocked)/\(totalCards) (\(String(format: "%.0f%%", unlockedPercent)))")

                    ForEach(suitOrder, id: \.code) { entry in
                        let progress = suitProgress(entry.code)
                        StatRow(label: "\(entry.label) Unlocked", value: "\(progress.unlocked)/\(progress.total)")
                    }

                    Divider()

                    ForEach(1...5, id: \.self) { star in
                        let progress = starProgress(star)
                        StatRow(label: "\(star)\u{2605} Unlocked", value: "\(progress.unlocked)/\(progress.total)")
                    }
                }
                .padding(.horizontal, 36)
            }

            Divider()

            HStack {
                Button("Reset Stats") {
                    showingResetConfirmation = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .font(.system(.body))
                .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
                    Button("Reset", role: .destructive) { viewModel.resetStatistics() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently clear all statistics. This cannot be undone.")
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 440, height: 560)
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
    }
}

fileprivate struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(.system(.body))
    }
}
