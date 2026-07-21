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
    @State private var themeToApply: SoliBeeTheme? = nil
    @State private var themeToUpdate: SoliBeeTheme? = nil

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
        .alert("Warning", isPresented: Binding(
            get: { themeToApply != nil },
            set: { if !$0 { themeToApply = nil } }
        )) {
            Button("Cancel", role: .cancel) { themeToApply = nil }
            Button("Accept", role: .destructive) {
                if let t = themeToApply { coordinator.applyTheme(t) }
                themeToApply = nil
                isOptionsPresented = false
            }
        } message: {
            Text("Applying a new theme will remove your custom card art. Cancel and save as a new theme, if needed.")
        }
        .alert("Update Theme", isPresented: Binding(
            get: { themeToUpdate != nil },
            set: { if !$0 { themeToUpdate = nil } }
        )) {
            Button("Cancel", role: .cancel) { themeToUpdate = nil }
            Button("Update") {
                if let t = themeToUpdate { updateTheme(t) }
                themeToUpdate = nil
            }
        } message: {
            Text("Are you sure you want to update \"\(themeToUpdate?.name ?? "")\"?")
        }
    }

    // Skip the warning if the user is currently on a saved, non-Default theme (nothing
    // of theirs is at risk since it's already captured by that theme), or if there's no
    // active custom face art to lose in the first place.
    private func shouldWarnBeforeApplying() -> Bool {
        guard !CustomFaceCardArtManager.shared.faceArts.isEmpty else { return false }
        guard let activeId = manager.activeThemeId,
              let activeTheme = manager.themes.first(where: { $0.id == activeId }) else {
            return true
        }
        return activeTheme.name.lowercased() == "default"
    }

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
                Text(theme.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(theme.cardBackTheme)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if manager.activeThemeId == theme.id {
                Button("Update") {
                    themeToUpdate = theme
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .focusable(false)
            }

            Button("Apply") {
                if shouldWarnBeforeApplying() {
                    themeToApply = theme
                } else {
                    coordinator.applyTheme(theme)
                    isOptionsPresented = false
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .focusable(false)

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

    private func updateTheme(_ theme: SoliBeeTheme) {
        let updated = SoliBeeTheme(
            id: theme.id,
            name: theme.name,
            cardBackTheme: coordinator.cardBackTheme,
            feltColor: coordinator.feltColor,
            customFeltRed: coordinator.customFeltRed,
            customFeltGreen: coordinator.customFeltGreen,
            customFeltBlue: coordinator.customFeltBlue,
            faceArts: CustomFaceCardArtManager.shared.faceArts,
            customCardColors: coordinator.customCardColors,
            customBackgroundName: coordinator.customBackgroundName
        )
        manager.updateTheme(updated)
    }
}
