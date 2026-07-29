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
                    StatRowView(label: "Games Played", value: "\(stats.gamesPlayed)")
                    StatRowView(label: "Matches Won", value: "\(stats.matchesWon)")
                    StatRowView(label: "Matches Lost", value: "\(stats.matchesLost)")
                    StatRowView(label: "Matches Drawn", value: "\(stats.matchesDrawn)")
                    StatRowView(label: "Most Sudden Deaths", value: "\(stats.suddenDeathCount)")
                    StatRowView(label: "Win Rate", value: String(format: "%.1f%%", winRate))

                    Divider()

                    StatRowView(label: "Current Win Streak", value: "\(stats.currentWinStreak)")
                    StatRowView(label: "Longest Win Streak", value: "\(stats.longestWinStreak)")
                    StatRowView(label: "Flawless Victories (10-0 Sweep)", value: "\(stats.flawlessVictories)")
                    StatRowView(label: "Baby Bee Wins", value: "\(stats.easyWins)")
                    StatRowView(label: "Honey Bee Wins", value: "\(stats.mediumWins)")
                    StatRowView(label: "Queen Bee Wins", value: "\(stats.hardWins)")
                    StatRowView(label: "Killer Bee Wins", value: "\(stats.ultraHardWins)")

                    Divider()

                    StatRowView(label: "Total Cards Flipped", value: "\(stats.cardsCaptured)")
                    StatRowView(label: "Fallen Aces", value: "\(stats.fallenAces)")
                    StatRowView(label: "Same/Plus Combos Triggered", value: "\(stats.samePlusTriggers)")
                    StatRowView(label: "Cards Stolen", value: "\(stats.cardsStolen)")
                    StatRowView(label: "Times Started Over", value: "\(stats.timesStartedOver)")

                    Divider()

                    StatRowView(label: "Cards Unlocked", value: "\(totalUnlocked)/\(totalCards) (\(String(format: "%.0f%%", unlockedPercent)))")

                    ForEach(suitOrder, id: \.code) { entry in
                        let progress = suitProgress(entry.code)
                        StatRowView(label: "\(entry.label) Unlocked", value: "\(progress.unlocked)/\(progress.total)")
                    }

                    Divider()

                    ForEach(1...5, id: \.self) { star in
                        let progress = starProgress(star)
                        StatRowView(label: "\(star)\u{2605} Unlocked", value: "\(progress.unlocked)/\(progress.total)")
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
