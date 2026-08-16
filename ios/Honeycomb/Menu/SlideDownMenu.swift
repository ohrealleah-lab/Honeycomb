import SwiftUI

/// Top-docked slide-down panel for Game Selection — the iOS replacement for mac's
/// toolbar dropdown. Options and Themes each get their own full-screen sheet (see
/// OptionsFullScreenView, ThemesFullScreenView); this stays a half-height panel since
/// picking a game benefits from still seeing the board peek out behind it.
struct SlideDownMenu: View {
    @Binding var isOpen: Bool
    @Bindable var coordinator: AppCoordinator

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
                            gameSelectionSection
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
            Text(coordinator.L(.menuTabGameSelection)).font(.headline)
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

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
