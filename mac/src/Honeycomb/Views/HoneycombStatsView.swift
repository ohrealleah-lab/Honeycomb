import SwiftUI

public struct HoneycombStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
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
            Text(coordinator.L(.honeycombStatistics))
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 12)

            Divider()

            // Two columns instead of one long list — Col1 is match/streak/gameplay stats,
            // Col2 is card-collection progress — so this sheet doesn't stretch so tall.
            // Mirrors the same split on Windows (MainWindow.axaml.cs's
            // PopulateHoneycombStats/StatsDynamicRowsCol1/Col2).
            ScrollView {
                HStack(alignment: .top, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRowView(label: coordinator.L(.gamesPlayed), value: "\(stats.gamesPlayed)")
                        StatRowView(label: coordinator.L(.statMatchesWon), value: "\(stats.matchesWon)")
                        StatRowView(label: coordinator.L(.statMatchesLost), value: "\(stats.matchesLost)")
                        StatRowView(label: coordinator.L(.statMatchesDrawn), value: "\(stats.matchesDrawn)")
                        StatRowView(label: coordinator.L(.statSwarmsToDeath), value: "\(stats.suddenDeathCount)")
                        StatRowView(label: coordinator.L(.winRate), value: String(format: "%.1f%%", winRate))

                        Divider()

                        StatRowView(label: coordinator.L(.statCurrentWinStreak), value: "\(stats.currentWinStreak)")
                        StatRowView(label: coordinator.L(.statLongestWinStreak), value: "\(stats.longestWinStreak)")
                        StatRowView(label: coordinator.L(.statFlawlessVictoriesMac), value: "\(stats.flawlessVictories)")
                        StatRowView(label: coordinator.L(.statBabyBeeWins), value: "\(stats.easyWins)")
                        StatRowView(label: coordinator.L(.statHoneyBeeWins), value: "\(stats.mediumWins)")
                        StatRowView(label: coordinator.L(.statQueenBeeWins), value: "\(stats.hardWins)")
                        StatRowView(label: coordinator.L(.statKillerBeeWins), value: "\(stats.ultraHardWins)")

                        Divider()

                        StatRowView(label: coordinator.L(.statTotalCardsFlipped), value: "\(stats.cardsCaptured)")
                        StatRowView(label: coordinator.L(.statQueensFalls), value: "\(stats.fallenAces)")
                        StatRowView(label: coordinator.L(.statHiveMindsTriggered), value: "\(stats.samePlusTriggers)")
                        StatRowView(label: coordinator.L(.statCardsStolen), value: "\(stats.cardsStolen)")
                        StatRowView(label: coordinator.L(.statTimesStartedOver), value: "\(stats.timesStartedOver)")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        StatRowView(label: coordinator.L(.statCardsUnlockedLabel), value: coordinator.L(.statCardsUnlockedValueFmt, totalUnlocked, totalCards, String(format: "%.0f%%", unlockedPercent)))

                        ForEach(suitOrder, id: \.code) { entry in
                            let progress = suitProgress(entry.code)
                            StatRowView(label: coordinator.L(.statSuitUnlockedFmt, entry.label), value: "\(progress.unlocked)/\(progress.total)")
                        }

                        Divider()

                        ForEach(1...5, id: \.self) { star in
                            let progress = starProgress(star)
                            StatRowView(label: coordinator.L(.statStarUnlockedFmt, star), value: "\(progress.unlocked)/\(progress.total)")
                        }
                    }
                }
                .padding(.horizontal, 36)
            }

            Divider()

            HStack {
                Button(coordinator.L(.resetStats)) {
                    showingResetConfirmation = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .font(.system(.body))
                .alert(coordinator.L(.resetStatisticsTitle), isPresented: $showingResetConfirmation) {
                    Button(coordinator.L(.reset), role: .destructive) { viewModel.resetStatistics() }
                    Button(coordinator.L(.cancel), role: .cancel) {}
                } message: {
                    Text(coordinator.L(.resetStatisticsBodyGeneric))
                }

                Spacer()

                Button(coordinator.L(.close)) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 680, height: 480)
        .background {
            if let image = NSImage(named: "Solibee") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.15)
            }
        }
        .background(
            Color(NSColor.windowBackgroundColor)
                .overlay(Color.primary.opacity(0.04))
        )
    }
}
