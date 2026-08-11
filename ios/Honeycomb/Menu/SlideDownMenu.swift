import SwiftUI

/// Top-docked slide-down menu — the iOS replacement for the mac toolbar's dropdown +
/// options/stats buttons. Opens to 50% of screen height; game selection, per-game
/// settings (injected by the active game's view), themes, and stats live here.
struct SlideDownMenu<GameSettings: View>: View {
    @Binding var isOpen: Bool
    @Bindable var coordinator: AppCoordinator
    var onShowStats: () -> Void
    @ViewBuilder var gameSettings: () -> GameSettings

    private enum MenuTab: String, CaseIterable {
        case games = "Game Selection"
        case options = "Options"
        case themes = "Themes"
    }
    @State private var selectedTab: MenuTab = .games

    @State private var customCardBacks = IOSCustomCardBackManager.shared
    @State private var showingImportSheet = false
    @State private var entryPendingDelete: IOSCustomCardBackManager.Entry? = nil
    @State private var showingFaceArtSheet = false

    @State private var customBackgrounds = IOSCustomBackgroundManager.shared
    @State private var showingBackgroundImportSheet = false
    @State private var backgroundPendingDelete: IOSCustomBackgroundManager.Entry? = nil

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
                                Text(tab.rawValue).tag(tab)
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
                                case .themes:
                                    themeSection
                                    faceCardArtRow
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
            Toggle(coordinator.L(.feltVignetteToggle), isOn: $coordinator.showFeltVignette)

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

            sectionTitle("Background").padding(.top, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    addBackgroundButton
                    // "None" clears back to the felt color — always available, not
                    // removable, mirrors mac's default (no background) state.
                    Button {
                        coordinator.customBackgroundName = nil
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(coordinator.currentFeltColor)
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.accentColor, lineWidth: coordinator.customBackgroundName == nil ? 3 : 0)
                            )
                            Text("None").font(.caption2).foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    ForEach(customBackgrounds.backgrounds) { entry in
                        backgroundButton(entry)
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
        .sheet(isPresented: $showingBackgroundImportSheet) {
            CustomBackgroundImportSheet { name in
                coordinator.customBackgroundName = name
            }
        }
        .alert("Remove Card Back?", isPresented: .init(
            get: { entryPendingDelete != nil },
            set: { if !$0 { entryPendingDelete = nil } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.remove), role: .destructive) {
                if let entry = entryPendingDelete {
                    if coordinator.cardBackTheme == entry.name { coordinator.cardBackTheme = "Solibee" }
                    customCardBacks.removeCustomCardBack(entry)
                }
            }
        } message: {
            Text("This removes the imported image. It can't be undone.")
        }
        .alert("Remove Background?", isPresented: .init(
            get: { backgroundPendingDelete != nil },
            set: { if !$0 { backgroundPendingDelete = nil } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.remove), role: .destructive) {
                if let entry = backgroundPendingDelete {
                    if coordinator.customBackgroundName == entry.name { coordinator.customBackgroundName = nil }
                    customBackgrounds.removeCustomBackground(entry)
                }
            }
        } message: {
            Text("This removes the imported image. It can't be undone.")
        }
    }

    private func backgroundButton(_ entry: IOSCustomBackgroundManager.Entry) -> some View {
        Button {
            coordinator.customBackgroundName = entry.name
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let image = customBackgrounds.image(for: entry) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.accentColor, lineWidth: coordinator.customBackgroundName == entry.name ? 3 : 0)
                )
                Text(entry.name).font(.caption2).foregroundStyle(.primary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            backgroundPendingDelete = entry
        }
    }

    private var addBackgroundButton: some View {
        Button {
            showingBackgroundImportSheet = true
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.3))
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
                Text(coordinator.L(.addShort)).font(.caption2).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func cardBackButton(_ name: String, isCustom: Bool) -> some View {
        Button {
            coordinator.cardBackTheme = name
        } label: {
            VStack(spacing: 4) {
                cardBackThumbnail(name)
                    .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
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
                .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
                Text(coordinator.L(.addShort))
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

    private var helpRow: some View {
        Button {
            showingHelp = true
        } label: {
            HStack {
                Label("How to Play", systemImage: "questionmark.circle")
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

    // Applies to the standard-card games (Klondike/BeeCell/Spider/Video Poker/
    // Blackjack) via TouchCardView, not to Honeycomb's own card art — but kept
    // reachable from every game's menu since it's a persistent global customization,
    // same as the card-back theme above.
    private var faceCardArtRow: some View {
        Button {
            showingFaceArtSheet = true
        } label: {
            HStack {
                Label("Face Card Art", systemImage: "person.crop.rectangle")
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingFaceArtSheet) { CustomFaceCardArtSheet() }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}
