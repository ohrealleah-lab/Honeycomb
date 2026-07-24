import SwiftUI

/// Top-docked slide-down menu — the iOS replacement for the mac toolbar's dropdown +
/// options/stats buttons. Opens to 50% of screen height; game selection, per-game
/// settings (injected by the active game's view), themes, and stats live here.
struct SlideDownMenu<GameSettings: View>: View {
    @Binding var isOpen: Bool
    @Bindable var coordinator: AppCoordinator
    var onShowStats: () -> Void
    @ViewBuilder var gameSettings: () -> GameSettings

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
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                gameSelectionSection
                                gameSettings()
                                themeSection
                                statsRow
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
            Text("Menu").font(.headline)
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Close menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Game")
            ForEach(GameMode.allCases) { mode in
                Button {
                    coordinator.gameMode = mode
                    close()
                } label: {
                    HStack {
                        Text(mode.displayName)
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

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Theme")
            HStack(spacing: 12) {
                ForEach(FeltColorTheme.allCases.filter { $0 != .custom }, id: \.self) { theme in
                    Button {
                        coordinator.feltColor = theme
                    } label: {
                        Circle()
                            .fill(theme.primaryColor)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle().stroke(Color.white,
                                                lineWidth: coordinator.feltColor == theme ? 3 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.rawValue)
                }
            }
            Toggle("Felt Vignette", isOn: $coordinator.showFeltVignette)
        }
    }

    private var statsRow: some View {
        Button {
            close()
            onShowStats()
        } label: {
            HStack {
                Label("Statistics", systemImage: "chart.bar")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
