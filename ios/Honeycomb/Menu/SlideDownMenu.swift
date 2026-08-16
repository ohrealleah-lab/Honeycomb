import SwiftUI

/// Which tab SlideDownMenu opens to. Hoisted out of SlideDownMenu (not nested/private)
/// so a game's topBar buttons can pass a specific tab in — e.g. an Options button jumps
/// straight to `.options` instead of always landing on `.games`.
enum MenuTab: String, CaseIterable {
    case games = "Game Selection"
    case options = "Options"

    func localizedLabel(_ coordinator: AppCoordinator) -> String {
        switch self {
        case .games:   return coordinator.L(.menuTabGameSelection)
        case .options: return coordinator.L(.options)
        }
    }
}

/// Top-docked slide-down menu — the iOS replacement for the mac toolbar's dropdown +
/// options/stats buttons. Opens to 50% of screen height; game selection, per-game
/// settings (injected by the active game's view), themes, and stats live here.
struct SlideDownMenu<GameSettings: View>: View {
    @Binding var isOpen: Bool
    @Binding var selectedTab: MenuTab
    @Bindable var coordinator: AppCoordinator
    var onShowStats: () -> Void
    @ViewBuilder var gameSettings: () -> GameSettings

    @State private var showingHelp = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if isOpen {
                    // Dim + tap-to-dismiss backdrop
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { close() }
                        .transition(.opacity)

                    VStack(spacing: 0) {
                        header
                        Divider().overlay(Color.white.opacity(0.2))

                        Picker("", selection: $selectedTab) {
                            ForEach(MenuTab.allCases, id: \.self) { tab in
                                Text(tab.localizedLabel(coordinator)).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                switch selectedTab {
                                case .games:
                                    gameSelectionSection
                                case .options:
                                    gameSettings()
                                    statsRow
                                    helpRow
                                }
                            }
                            .padding(16)
                        }
                    }
                    .frame(height: geo.size.height * 0.5)
                    .frame(maxWidth: 500)
                    .background(.ultraThinMaterial)
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
                    .shadow(radius: 12, y: 4)
                    .transition(.move(edge: .top))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isOpen)
    }

    private func close() { isOpen = false }

    private var header: some View {
        HStack {
            Text(coordinator.L(.menuHeaderTitle)).font(.headline)
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(coordinator.L(.closeMenuA11y))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(coordinator.L(.menuSectionGame))
            ForEach(GameMode.allCases) { mode in
                Button {
                    coordinator.gameMode = mode
                    close()
                } label: {
                    HStack {
                        Text(mode.localizedDisplayName(language: coordinator.language))
                        Spacer()
                        if coordinator.gameMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(coordinator.gameMode == mode ? Color.accentColor.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var statsRow: some View {
        Button {
            close()
            onShowStats()
        } label: {
            HStack {
                Label(coordinator.L(.statisticsNavRow), systemImage: "chart.bar")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }

    private var helpRow: some View {
        Button {
            showingHelp = true
        } label: {
            HStack {
                Label(coordinator.L(.howToPlayNavRow), systemImage: "questionmark.circle")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingHelp) {
            switch coordinator.gameMode {
            case .klondike:
                KlondikeHelpView()
            case .beecell:
                BeecellHelpView()
            case .spider:
                SpiderHelpView()
            case .videoPoker:
                VideoPokerHelpView()
            case .blackjack:
                BlackjackHelpView()
            case .honeycomb:
                HoneycombHelpView()
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
