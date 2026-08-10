import SwiftUI

/// Themes section embedded in each game's Options sheet.
/// Reads the live app-wide theme straight off AppCoordinator — theme fields
/// are shared and live-previewed there, so there's nothing pending to snapshot.
struct ThemesSectionView: View {
    @Binding var isOptionsPresented: Bool

    @Environment(AppCoordinator.self) private var coordinator

    @State private var showingSaveRow = false
    @State private var newThemeName = ""
    @State private var saveError: String? = nil
    @State private var themeToDelete: SoliBeeTheme? = nil
    @State private var renamingThemeId: UUID? = nil
    @State private var renameText: String = ""
    @State private var renameError: String? = nil
    @FocusState private var renameFieldFocused: Bool

    private var manager: ThemeManager { ThemeManager.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Themes")
                    .font(.system(.body).bold())
                Spacer()
                Button("Save as New Theme") {
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
                    TextField("Theme name", text: $newThemeName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onSubmit { saveTheme() }

                    Button("Save") { saveTheme() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Cancel") {
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

            if manager.themes.isEmpty {
                Text("No saved themes yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(manager.themes) { theme in
                        themeRow(theme)
                        if theme.id != manager.themes.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12), lineWidth: 1))
            }
        }
        .alert("Delete Theme", isPresented: Binding(
            get: { themeToDelete != nil },
            set: { if !$0 { themeToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { themeToDelete = nil }
            Button("Delete", role: .destructive) {
                if let t = themeToDelete { manager.deleteTheme(id: t.id) }
                themeToDelete = nil
            }
        } message: {
            Text("Delete \"\(themeToDelete?.name ?? "")\"? This cannot be undone.")
        }
        .alert("Rename Theme", isPresented: Binding(
            get: { renameError != nil },
            set: { if !$0 { renameError = nil } }
        )) {
            Button("OK", role: .cancel) { renameError = nil }
        } message: {
            Text(renameError ?? "")
        }
    }

    // Applying a theme used to warn about losing custom face art, back when Apply/Update
    // were separate actions and unsaved face-art edits could be silently discarded. Now
    // every live edit (including face art, via liveSaveActiveTheme()) is continuously
    // captured into whichever theme is active, so there's nothing left to lose — Apply
    // just switches which already-saved snapshot is current.
    private func themeRow(_ theme: SoliBeeTheme) -> some View {
        HStack(spacing: 10) {
            // Colour swatch
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.feltColor == .custom
                      ? Color(red: theme.customFeltRed, green: theme.customFeltGreen, blue: theme.customFeltBlue)
                      : theme.feltColor.primaryColor)
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.2), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 1) {
                if renamingThemeId == theme.id {
                    TextField("Theme name", text: $renameText)
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
                Text(manager.activeThemeId == theme.id ? "Active" : theme.cardBackTheme)
                    .font(.system(size: 10))
                    .foregroundColor(manager.activeThemeId == theme.id ? .accentColor : .secondary)
            }

            Spacer()

            if manager.activeThemeId == theme.id {
                // Every live edit (felt/card back/colors/face art) is continuously
                // saved into the active theme now — see AppCoordinator.liveSaveActiveTheme()
                // — so there's nothing left to "Update"; this button just states fact.
                Button("Active") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
            } else {
                Button("Apply") {
                    coordinator.applyTheme(theme)
                    isOptionsPresented = false
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
    }

    private func saveTheme() {
        let name = newThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if manager.nameExists(name) {
            saveError = "A theme named \"\(name)\" already exists."
            return
        }

        let theme = SoliBeeTheme(
            name: name,
            cardBackTheme: coordinator.cardBackTheme,
            feltColor: coordinator.feltColor,
            customFeltRed: coordinator.customFeltRed,
            customFeltGreen: coordinator.customFeltGreen,
            customFeltBlue: coordinator.customFeltBlue,
            faceArts: CustomFaceCardArtManager.shared.faceArts,
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
                ? "Theme name can't be empty."
                : "A theme named \"\(trimmed)\" already exists."
        }
    }
}
