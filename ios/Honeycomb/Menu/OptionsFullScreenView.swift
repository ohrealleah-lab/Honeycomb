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
                VStack(alignment: .leading, spacing: 16) {
                    languageSection
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeading(coordinator.gameMode.localizedDisplayName(language: coordinator.language))
                        gameSettings()
                            .padding(12)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    }
                    navigationSection
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.options))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                        .buttonStyle(.borderedProminent)
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

    // Global setting (not per-game), so it's the same regardless of which game Options
    // was opened from — matches mac's OptionsSheetShell placement/reasoning, which puts
    // this above the per-game content for the same reason.
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.language))
            Picker(coordinator.L(.language), selection: $coordinator.language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // One grouped card (matching ThemesFullScreenView's customizationSection pattern)
    // instead of two separately-spaced cards — keeps Statistics and How to Play
    // visually and physically close together, and cuts the extra padding/gap between
    // them so the whole sheet fits without scrolling on most screens.
    private var navigationSection: some View {
        VStack(spacing: 0) {
            navigationRow(systemImage: "chart.bar", title: coordinator.L(.statisticsNavRow)) {
                dismiss()
                onShowStats()
            }
            Divider().padding(.leading, 44)
            navigationRow(systemImage: "questionmark.circle", title: coordinator.L(.howToPlayNavRow)) {
                showingHelp = true
            }
        }
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func navigationRow(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage).frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }
}
