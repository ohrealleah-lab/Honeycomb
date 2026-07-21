import SwiftUI

public struct HoneycombStatsView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: HoneycombViewModel

    @State private var profile = HoneycombProfileManager.shared
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
        VStack(spacing: 20) {
            HStack {
                Text("Honeycomb Statistics")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .padding()
            }
            .padding()
            
            let stats = viewModel.stats
            let decisiveGames = stats.gamesPlayed - stats.matchesDrawn
            let winRate = decisiveGames > 0 ? Double(stats.matchesWon) / Double(decisiveGames) * 100 : 0
            
            ScrollView {
                VStack(spacing: 15) {
                    StatRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                    StatRow(label: "Matches Won", value: "\(stats.matchesWon)")
                    StatRow(label: "Matches Lost", value: "\(stats.matchesLost)")
                    StatRow(label: "Matches Drawn", value: "\(stats.matchesDrawn)")
                    StatRow(label: "Win Rate", value: String(format: "%.1f%%", winRate))
                    
                    Divider().padding(.vertical, 5)
                    
                    StatRow(label: "Current Win Streak", value: "\(stats.currentWinStreak)")
                    StatRow(label: "Longest Win Streak", value: "\(stats.longestWinStreak)")
                    StatRow(label: "Flawless Victories (10-0 Sweep)", value: "\(stats.flawlessVictories)")
                    StatRow(label: "Ultra Hard Wins", value: "\(stats.ultraHardWins)")

                    Divider().padding(.vertical, 5)

                    StatRow(label: "Total Cards Flipped", value: "\(stats.cardsCaptured)")
                    StatRow(label: "Same/Plus Combos Triggered", value: "\(stats.samePlusTriggers)")

                    Divider().padding(.vertical, 5)

                    let totalUnlocked = profile.unlockedCardIds.count
                    let totalCards = db.allCards.count
                    let unlockedPercent = totalCards > 0 ? Double(totalUnlocked) / Double(totalCards) * 100 : 0
                    StatRow(label: "Cards Unlocked", value: "\(totalUnlocked)/\(totalCards) (\(String(format: "%.0f%%", unlockedPercent)))")

                    ForEach(suitOrder, id: \.code) { entry in
                        let progress = suitProgress(entry.code)
                        StatRow(label: "\(entry.label) Unlocked", value: "\(progress.unlocked)/\(progress.total)")
                    }

                    Divider().padding(.vertical, 5)

                    ForEach(1...5, id: \.self) { star in
                        let progress = starProgress(star)
                        StatRow(label: "\(star)★ Unlocked", value: "\(progress.unlocked)/\(progress.total)")
                    }
                }
                .padding()
                .background(Color.black.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .frame(width: 400, height: 600)
        .onAppear {
            profile = HoneycombProfileManager.shared
        }
    }
}

fileprivate struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.title3)
    }
}
