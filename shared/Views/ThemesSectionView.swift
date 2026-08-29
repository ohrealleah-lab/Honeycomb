import SwiftUI

/// Themes section embedded in each game's Options sheet.
/// Reads the live app-wide theme straight off AppCoordinator — theme fields
/// are shared and live-previewed there, so there's nothing pending to snapshot.
struct ThemesSectionView: View {
    @Environment(AppCoordinator.self) private var coordinator

    @State private var showingSaveRow = false
    @State private var newThemeName = ""
    @State private var saveError: String? = nil
    @State private var themeToDelete: SoliBeeTheme? = nil
    @State private var renamingThemeId: UUID? = nil
    @State private var renameText: String = ""
    @State private var renameError: String? = nil
    @FocusState private var renameFieldFocused: Bool
    // Forces a re-render once CustomBackgroundManager finishes its one-time backfill
    // of a pre-existing background's dominant color (new backgrounds have it the
    // instant they're imported — see CustomBackground.dominantColor), same pattern
    // BackgroundLayerView already uses for its own async image load.
    @State private var accentColorTrigger: UUID = UUID()

    private var manager: ThemeManager { ThemeManager.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(coordinator.L(.themesPanelTitle))
                    .font(.system(.body).bold())
                Spacer()
                Button(coordinator.L(.saveAsNewTheme)) {
                    newThemeName = ""
                    saveError = nil
                    showingSaveRow = true
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            if showingSaveRow {
                HStack(spacing: 8) {
                    TextField(coordinator.L(.themeNameFieldPlaceholder), text: $newThemeName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onSubmit { saveTheme() }

                    Button(coordinator.L(.save)) { saveTheme() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(coordinator.L(.cancel)) {
                        showingSaveRow = false
                        saveError = nil
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                }

                if let err = saveError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            // Fills whatever vertical room the caller (ThemesOptionsView's sidebar)
            // gives this view, rather than shrink-wrapping to content height — that
            // used to leave the list box sitting at the top of the sidebar with a big
            // empty gap of the sidebar's own background showing below it, reading as a
            // box nested inside an emptier box instead of one filled panel.
            Group {
                if manager.themes.isEmpty {
                    Text(coordinator.L(.noSavedThemesYet))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(manager.themes) { theme in
                                themeRow(theme)
                                if theme.id != manager.themes.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .frame(maxHeight: .infinity)
        }
        .alert(coordinator.L(.deleteThemeTitle), isPresented: Binding(
            get: { themeToDelete != nil },
            set: { if !$0 { themeToDelete = nil } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) { themeToDelete = nil }
            Button(coordinator.L(.delete), role: .destructive) {
                if let t = themeToDelete { manager.deleteTheme(id: t.id) }
                themeToDelete = nil
            }
        } message: {
            Text(coordinator.L(.deleteThemeConfirmFmt, themeToDelete?.name ?? ""))
        }
        .alert(coordinator.L(.renameThemeTitle), isPresented: Binding(
            get: { renameError != nil },
            set: { if !$0 { renameError = nil } }
        )) {
            Button(coordinator.L(.ok), role: .cancel) { renameError = nil }
        } message: {
            Text(renameError ?? "")
        }
        // Merely changing this @State (not .id()-ing the view) is enough to make
        // SwiftUI re-evaluate body — an .id() here would also reset renamingThemeId/
        // renameText, discarding an in-progress rename if a sample happens to land
        // mid-edit.
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomBackgroundLoaded"))) { _ in
            accentColorTrigger = UUID()
        }
    }

    // Applying a theme used to warn about losing custom face art, back when Apply/Update
    // were separate actions and unsaved face-art edits could be silently discarded. Now
    // every live edit (including face art, via liveSaveActiveTheme()) is continuously
    // captured into whichever theme is active, so there's nothing left to lose — Apply
    // just switches which already-saved snapshot is current.
    // Same felt-color resolution the swatch already used — factored out so the active
    // row's background tint (below) can share it instead of duplicating the logic.
    // When the theme has its own wallpaper (customBackgroundName), prefer that
    // wallpaper's persisted dominant color over feltColor — feltColor is often just a
    // stale/default value in that case and has nothing to do with what the theme
    // actually looks like on screen. dominantColor is nil only for a background saved
    // before this existed, until CustomBackgroundManager's one-time backfill finishes;
    // the .onReceive(CustomBackgroundLoaded) below already forces a redraw once it does.
    private func themeColor(_ theme: SoliBeeTheme) -> Color {
        #if canImport(AppKit)
        if let backgroundName = theme.customBackgroundName,
           let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == backgroundName }),
           let sampled = background.dominantColor {
            return sampled
        }
        #endif
        return theme.feltColor == .custom
            ? Color(red: theme.customFeltRed, green: theme.customFeltGreen, blue: theme.customFeltBlue)
            : theme.feltColor.primaryColor
    }

    // Back to one row now that the sidebar's wider (300pt, up from 240pt) — there's
    // enough room for the name, Apply/Active, and trash to all sit together again
    // without truncating names like "Honeycomb".
    private func themeRow(_ theme: SoliBeeTheme) -> some View {
        HStack(spacing: 10) {
            // Colour swatch — the active theme's swatch uses currentAccentTint (same as
            // the row background below) so it reflects a sampled wallpaper color too,
            // not just the felt-color fallback; other rows resolve their own wallpaper's
            // dominant color the same way via themeColor(_:) below.
            RoundedRectangle(cornerRadius: 3)
                .fill(manager.activeThemeId == theme.id ? coordinator.currentAccentTint : themeColor(theme))
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 1) {
                if renamingThemeId == theme.id {
                    TextField(coordinator.L(.themeNameFieldPlaceholder), text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .focused($renameFieldFocused)
                        .onSubmit { commitRename(theme) }
                        .onChange(of: renameFieldFocused) { _, isFocused in
                            if !isFocused && renamingThemeId == theme.id { commitRename(theme) }
                        }
                } else {
                    Text(theme.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        // Double-click to rename — matches the interaction Windows added
                        // alongside its disabled "Active" button.
                        .onTapGesture(count: 2) { beginRename(theme) }
                }
                // Explicit "Active" caption — a lone disabled button wasn't a reliable
                // enough "which theme is this" signal on its own (easy to miss, not
                // colorblind-safe).
                Text(manager.activeThemeId == theme.id ? coordinator.L(.deckActiveBadge) : theme.cardBackTheme)
                    .font(.system(size: 10))
                    .foregroundColor(manager.activeThemeId == theme.id ? .accentColor : .secondary)
            }

            Spacer()

            if manager.activeThemeId == theme.id {
                // Every live edit (felt/card back/colors/face art) is continuously
                // saved into the active theme now — see AppCoordinator.liveSaveActiveTheme()
                // — so there's nothing left to "Update"; this button just states fact.
                Button(coordinator.L(.deckActiveBadge)) {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
            } else {
                Button(coordinator.L(.applyThemeButton)) {
                    coordinator.applyTheme(theme)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .focusable(false)
            }

            Button(role: .destructive) {
                themeToDelete = theme
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .focusable(false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        // Tints the active row with its own theme's felt/background color — a stronger,
        // more immediate "this one" signal than the small swatch + "Active" caption
        // alone, at a low enough opacity that the row's text stays legible over any
        // theme color, light or dark. Uses currentAccentTint (not themeColor(theme))
        // specifically for the active row — when the active theme's background is a
        // wallpaper, coordinator is already live-synced to it, so this picks up the
        // wallpaper's sampled dominant color instead of a felt color that may have
        // nothing to do with what's actually on screen.
        .background(manager.activeThemeId == theme.id ? coordinator.currentAccentTint.opacity(0.25) : Color.clear)
    }

    private func saveTheme() {
        let name = newThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if manager.nameExists(name) {
            saveError = coordinator.L(.themeNameExistsErrorFmt, name)
            return
        }

        // iOS's IOSCustomFaceArtManager uses its own Entry type (not CustomFaceArt), and
        // applyTheme() already only restores faceArts on platforms that can import
        // AppKit (see its #if canImport(AppKit) guard) — so there's nothing meaningful
        // to round-trip through a saved theme on iOS yet.
        #if canImport(AppKit)
        let faceArts = CustomFaceCardArtManager.shared.faceArts
        #else
        let faceArts: [CustomFaceArt] = []
        #endif

        let theme = SoliBeeTheme(
            name: name,
            cardBackTheme: coordinator.cardBackTheme,
            feltColor: coordinator.feltColor,
            customFeltRed: coordinator.customFeltRed,
            customFeltGreen: coordinator.customFeltGreen,
            customFeltBlue: coordinator.customFeltBlue,
            faceArts: faceArts,
            customCardColors: coordinator.customCardColors,
            customBackgroundName: coordinator.customBackgroundName
        )
        manager.addTheme(theme)
        showingSaveRow = false
        newThemeName = ""
        saveError = nil
    }

    private func beginRename(_ theme: SoliBeeTheme) {
        renameText = theme.name
        renamingThemeId = theme.id
        renameFieldFocused = true
    }

    private func commitRename(_ theme: SoliBeeTheme) {
        renamingThemeId = nil
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != theme.name else { return }
        if !manager.renameTheme(id: theme.id, newName: trimmed) {
            renameError = trimmed.isEmpty
                ? coordinator.L(.themeNameEmptyError)
                : coordinator.L(.themeNameExistsErrorFmt, trimmed)
        }
    }
}
