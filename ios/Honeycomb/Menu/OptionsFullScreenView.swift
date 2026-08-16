import SwiftUI

/// Full-screen Options sheet — matches ThemesFullScreenView's styling (solid
/// NavigationStack, Done button, section headings, nav rows that push into their own
/// sheets) rather than the half-height panel Options used to share with Game Selection.
struct OptionsFullScreenView<GameSettings: View>: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    var onShowStats: () -> Void
    @ViewBuilder var gameSettings: () -> GameSettings

    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeading(coordinator.L(.options))
                        gameSettings()
                    }
                    statsRow
                    helpRow
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.options))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingHelp) {
            switch coordinator.gameMode {
            case .klondike:   KlondikeHelpView()
            case .beecell:    BeecellHelpView()
            case .spider:     SpiderHelpView()
            case .videoPoker: VideoPokerHelpView()
            case .blackjack:  BlackjackHelpView()
            case .honeycomb:  HoneycombHelpView()
            }
        }
    }

    private var statsRow: some View {
        Button {
            dismiss()
            onShowStats()
        } label: {
            HStack {
                Image(systemName: "chart.bar")
                Text(coordinator.L(.statisticsNavRow))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var helpRow: some View {
        Button {
            showingHelp = true
        } label: {
            HStack {
                Image(systemName: "questionmark.circle")
                Text(coordinator.L(.howToPlayNavRow))
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }
}
