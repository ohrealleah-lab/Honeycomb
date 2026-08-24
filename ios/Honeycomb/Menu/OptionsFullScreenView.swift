import SwiftUI

/// Full-screen Options sheet — matches ThemesFullScreenView's styling (solid
/// NavigationStack, Done button, section headings, nav rows that push into their own
/// sheets) rather than the half-height panel Options used to share with Game Selection.
struct OptionsFullScreenView<GameSettings: View>: View {
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    var onShowStats: () -> Void
    // hideHintBinding is nil for the two games with no hint feature (Video Poker,
    // Blackjack) — Hide Hint only renders when a binding is supplied. Unlike Sound/
    // No Stress Mode/Honey Mode/Manually Dismiss Banners (all coordinator-bound, so
    // genuinely shared app-wide), Hide Hint stays a per-game options field; grouping
    // it under "Global" here is a display choice, not a claim it's shared state.
    var hideHintBinding: Binding<Bool>? = nil
    // Klondike/Beecell/Spider/Honeycomb/Video Poker restart the current game when No
    // Stress Mode changes (it affects what's dealt/shown); Blackjack deliberately
    // doesn't (isFreePlay reads the option live — see BlackjackSettingsSection).
    var onNoStressModeChange: (() -> Void)? = nil
    // Matches each game's own mid-play gating exactly (Honeycomb/Video Poker/
    // Blackjack lock settings during a match/hand; Klondike/Beecell/Spider don't) —
    // this section can't infer that from the outside, so callers pass it in.
    var isGlobalSectionDisabled: Bool = false
    var globalSectionUnlockNote: String? = nil
    // Some games (Beecell) have no settings beyond the global toggles — showing an
    // empty "Beecell" card below Global would just be a blank box, so this section
    // is opt-out rather than always-on.
    var showsGameSection: Bool = true
    @ViewBuilder var gameSettings: () -> GameSettings

    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    languageSection
                    if showsGameSection {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeading(coordinator.gameMode.localizedDisplayName(language: coordinator.language))
                            gameSettings()
                                .padding(12)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    globalSection
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

    // Sound/No Stress Mode/Honey Mode/Hide Hint/Manually Dismiss Banners, split out
    // of each game's own settings section into one shared card — previously every
    // game repeated the same five toggles inline above its own game-specific
    // settings, with no visual distinction between "applies everywhere" and
    // "this game only". Sound/No Stress Mode/Honey Mode/Manually Dismiss Banners
    // bind straight to the coordinator (see AppCoordinator's "single source of
    // truth" fields), so they're identical no matter which game's Options this is.
    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.globalOptionsSection))
            VStack(alignment: .leading, spacing: 8) {
                Toggle(coordinator.L(.soundShort), isOn: $coordinator.isSoundEnabled)
                Toggle(coordinator.L(.noStressMode), isOn: $coordinator.noStressMode)
                    .onChange(of: coordinator.noStressMode) { _, _ in onNoStressModeChange?() }
                Toggle(coordinator.L(.honeyMode), isOn: $coordinator.honeyMode)
                if let hideHintBinding {
                    Toggle(coordinator.L(.hideHintButton), isOn: hideHintBinding)
                }
                Toggle(coordinator.L(.manuallyDismissBanners), isOn: $coordinator.manuallyDismissBanners)
            }
            .disabledDuringGameplay(isGlobalSectionDisabled)
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            if isGlobalSectionDisabled, let globalSectionUnlockNote {
                Text(globalSectionUnlockNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
