import SwiftUI

/// Themes section embedded in each game's Options sheet.
/// Pass the current local @State values so "Save current as Theme" snapshots
/// the pending (not-yet-committed) options.
struct ThemesSectionView: View {
    let currentCardBackTheme: String
    let currentFeltColor: FeltColorTheme
    let currentCustomCardColors: CustomCardColorGroup

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var showingSaveRow = false
    @State private var newThemeName = ""
    @State private var saveError: String? = nil
    @State private var themeToDelete: SoliBeeTheme? = nil

    private var manager: ThemeManager { ThemeManager.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Themes")
                    .font(.system(.body, design: .monospaced).bold())
                Spacer()
                Button("Save current as Theme…") {
                    newThemeName = ""
                    saveError = nil
                    showingSaveRow = true
                }
                .font(.system(size: 12, design: .monospaced))
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
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red)
                }
            }

            if manager.themes.isEmpty {
                Text("No saved themes yet.")
                    .font(.system(size: 12, design: .monospaced))
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
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                Text(theme.cardBackTheme)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Apply") {
                coordinator.applyTheme(theme)
                dismiss()
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

        let r = UserDefaults.standard.double(forKey: "custom_felt_red")
        let g = UserDefaults.standard.double(forKey: "custom_felt_green")
        let b = UserDefaults.standard.double(forKey: "custom_felt_blue")

        let theme = SoliBeeTheme(
            name: name,
            cardBackTheme: currentCardBackTheme,
            isDarkMode: false,
            feltColor: currentFeltColor,
            customFeltRed: r,
            customFeltGreen: g,
            customFeltBlue: b,
            faceArts: CustomFaceCardArtManager.shared.faceArts,
            customCardColors: currentCustomCardColors
        )
        manager.addTheme(theme)
        showingSaveRow = false
        newThemeName = ""
        saveError = nil
    }
}
