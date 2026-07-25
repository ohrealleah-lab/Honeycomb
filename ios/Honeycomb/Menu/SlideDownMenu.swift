import SwiftUI

/// Top-docked slide-down menu — the iOS replacement for the mac toolbar's dropdown +
/// options/stats buttons. Opens to 50% of screen height; game selection, per-game
/// settings (injected by the active game's view), themes, and stats live here.
struct SlideDownMenu<GameSettings: View>: View {
    @Binding var isOpen: Bool
    @Bindable var coordinator: AppCoordinator
    var onShowStats: () -> Void
    @ViewBuilder var gameSettings: () -> GameSettings

    @State private var customCardBacks = IOSCustomCardBackManager.shared
    @State private var showingImportSheet = false
    @State private var entryPendingDelete: IOSCustomCardBackManager.Entry? = nil

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
                Image(systemName: "xmark.circle.fill")
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

            sectionTitle("Card Back").padding(.top, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Leads the row (not trailing) so it's visible without scrolling —
                    // buried at the end of 8 bundled themes, it was easy to miss entirely.
                    addCardBackButton
                    ForEach(BundledCardBackImage.allThemeNames, id: \.self) { name in
                        cardBackButton(name, isCustom: false)
                    }
                    ForEach(customCardBacks.customCardBacks) { entry in
                        cardBackButton(entry.name, isCustom: true)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            CustomCardBackImportSheet { name in
                coordinator.cardBackTheme = name
            }
        }
        .alert("Remove Card Back?", isPresented: .init(
            get: { entryPendingDelete != nil },
            set: { if !$0 { entryPendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let entry = entryPendingDelete {
                    if coordinator.cardBackTheme == entry.name { coordinator.cardBackTheme = "Solibee" }
                    customCardBacks.removeCustomCardBack(entry)
                }
            }
        } message: {
            Text("This removes the imported image. It can't be undone.")
        }
    }

    private func cardBackButton(_ name: String, isCustom: Bool) -> some View {
        Button {
            coordinator.cardBackTheme = name
        } label: {
            VStack(spacing: 4) {
                cardBackThumbnail(name)
                    .frame(width: 44, height: 44 * 181.0 / 128.0)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.accentColor,
                                    lineWidth: coordinator.cardBackTheme == name ? 3 : 0)
                    )
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        // Custom (user-imported) card backs can be removed with a long-press;
        // bundled themes are always available and aren't deletable.
        .onLongPressGesture {
            guard isCustom else { return }
            entryPendingDelete = customCardBacks.customCardBacks.first { $0.name == name }
        }
    }

    private var addCardBackButton: some View {
        Button {
            showingImportSheet = true
        } label: {
            VStack(spacing: 4) {
                // Solid fill rather than a dashed/secondary-colored outline — the latter
                // blended into the menu's translucent backdrop closely enough to be
                // functionally invisible even though the button still worked.
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.3))
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44 * 181.0 / 128.0)
                Text("Add")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cardBackThumbnail(_ name: String) -> some View {
        if let image = BundledCardBackImage.uiImage(for: name) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
        } else if let entry = IOSCustomCardBackManager.shared.entry(named: name),
                  let image = IOSCustomCardBackManager.shared.image(for: entry) {
            CroppedCardBackImage(image: image, entry: entry)
        } else {
            Color.gray.opacity(0.3)
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
