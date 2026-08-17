import SwiftUI
import UIKit

/// Full-screen Themes sheet — replaces the old in-slide-down-menu Themes tab. Sections:
/// Saved Themes, Background & Felt (unified grid, mirrors mac's BackgroundSelectorView
/// merging felt presets + backgrounds into one picker), Card Backs, Card Colors, and
/// Face Card Art.
struct ThemesFullScreenView: View {
    // @Bindable (not @Environment) — several sections below need $coordinator.xxx
    // bindings (Toggle, ColorPicker) in their own computed properties, not just inside
    // body, where a local `@Bindable var coordinator = coordinator` shadow trick would
    // otherwise be enough.
    @Bindable var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingSavedThemes = false
    @State private var showingSaveThemeAlert = false
    @State private var newThemeName = ""
    @State private var themeToDelete: SoliBeeTheme? = nil
    @State private var themeSaveError: String? = nil

    @State private var customBackgrounds = IOSCustomBackgroundManager.shared
    @State private var showingBackgroundImportSheet = false
    @State private var backgroundPendingDelete: IOSCustomBackgroundManager.Entry? = nil

    @State private var showingFaceArtSheet = false
    @State private var showingCardBacksSheet = false
    @State private var showingCardColorsSheet = false

    private let gridColumns = [GridItem(.adaptive(minimum: 74), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    savedThemesSection
                    backgroundAndFeltSection
                    if coordinator.feltColor == .custom && coordinator.customBackgroundName == nil {
                        feltColorSection
                    }
                    customizationSection
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.themesPanelTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingBackgroundImportSheet) {
            CustomBackgroundImportSheet { name in
                coordinator.customBackgroundName = name
            }
        }
        .sheet(isPresented: $showingFaceArtSheet) { CustomFaceCardArtSheet() }
        .sheet(isPresented: $showingCardBacksSheet) { CardBacksSheet(coordinator: coordinator) }
        .sheet(isPresented: $showingCardColorsSheet) { CustomCardColorsSheet(coordinator: coordinator) }
        .alert(coordinator.L(.themeNameFieldPlaceholder), isPresented: $showingSaveThemeAlert) {
            TextField(coordinator.L(.themeNameFieldPlaceholder), text: $newThemeName)
            Button(coordinator.L(.cancel), role: .cancel) { newThemeName = "" }
            Button(coordinator.L(.save)) { saveCurrentAsTheme() }
        }
        .alert(coordinator.L(.deleteThemeTitle), isPresented: .init(
            get: { themeToDelete != nil },
            set: { if !$0 { themeToDelete = nil } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) { themeToDelete = nil }
            Button(coordinator.L(.delete), role: .destructive) {
                if let t = themeToDelete { ThemeManager.shared.deleteTheme(id: t.id) }
                themeToDelete = nil
            }
        } message: {
            Text(coordinator.L(.deleteThemeConfirmFmt, themeToDelete?.name ?? ""))
        }
        .alert(coordinator.L(.renameThemeTitle), isPresented: .init(
            get: { themeSaveError != nil },
            set: { if !$0 { themeSaveError = nil } }
        )) {
            Button(coordinator.L(.ok), role: .cancel) { themeSaveError = nil }
        } message: {
            Text(themeSaveError ?? "")
        }
        .alert(coordinator.L(.removeBackgroundAlertTitle), isPresented: .init(
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
            Text(coordinator.L(.removeImportedImageBody))
        }
    }

    // MARK: Saved Themes

    private var savedThemesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeading(coordinator.L(.savedThemesHeader))
                Spacer()
                Button {
                    isEditingSavedThemes.toggle()
                } label: {
                    Image(systemName: "pencil")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(ThemeManager.shared.themes) { theme in
                        savedThemeTile(theme)
                    }
                    addThemeTile
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func savedThemeTile(_ theme: SoliBeeTheme) -> some View {
        let isActive = ThemeManager.shared.activeThemeId == theme.id
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeColor(theme))
                    .frame(width: 90, height: 120)
                    .overlay(
                        cardBackThumbnailView(theme.cardBackTheme)
                            .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3), lineWidth: 1))

                if isEditingSavedThemes {
                    Button {
                        themeToDelete = theme
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.white, .red)
                            .font(.title3)
                    }
                    .padding(4)
                }
            }
            Text(theme.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(width: 90)

            if isActive {
                Text(coordinator.L(.deckActiveBadge))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            } else {
                Button(coordinator.L(.applyThemeButton)) {
                    coordinator.applyTheme(theme)
                }
                .font(.caption2.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }

    private var addThemeTile: some View {
        Button {
            newThemeName = ""
            showingSaveThemeAlert = true
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 90, height: 120)
                    .overlay(Image(systemName: "plus").font(.title2.weight(.bold)).foregroundStyle(.secondary))
                Text(coordinator.L(.saveAsNewTheme))
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 90)
            }
        }
        .buttonStyle(.plain)
    }

    private func themeColor(_ theme: SoliBeeTheme) -> Color {
        theme.feltColor == .custom
            ? Color(red: theme.customFeltRed, green: theme.customFeltGreen, blue: theme.customFeltBlue)
            : theme.feltColor.primaryColor
    }

    private func saveCurrentAsTheme() {
        let name = newThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if ThemeManager.shared.nameExists(name) {
            themeSaveError = coordinator.L(.themeNameExistsErrorFmt, name)
            return
        }
        let theme = SoliBeeTheme(
            name: name,
            cardBackTheme: coordinator.cardBackTheme,
            feltColor: coordinator.feltColor,
            customFeltRed: coordinator.customFeltRed,
            customFeltGreen: coordinator.customFeltGreen,
            customFeltBlue: coordinator.customFeltBlue,
            faceArts: [],
            customCardColors: coordinator.customCardColors,
            customBackgroundName: coordinator.customBackgroundName
        )
        ThemeManager.shared.addTheme(theme)
        newThemeName = ""
    }

    // MARK: Background & Felt

    private var backgroundAndFeltSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.backgroundLabel))
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    ForEach(FeltColorTheme.allCases.filter { $0 != .custom }, id: \.self) { theme in
                        feltTile(theme)
                    }
                    customFeltTile
                    ForEach(customBackgrounds.backgrounds) { entry in
                        backgroundTile(entry)
                    }
                    addBackgroundTile
                }
                Toggle(coordinator.L(.feltVignetteToggle), isOn: $coordinator.showFeltVignette)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func feltTile(_ theme: FeltColorTheme) -> some View {
        let isSelected = coordinator.feltColor == theme && coordinator.customBackgroundName == nil
        return Button {
            coordinator.feltColor = theme
            coordinator.customBackgroundName = nil
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.primaryColor)
                    .frame(width: 70, height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
                Text(localizedFeltName(theme)).font(.caption2).foregroundStyle(.primary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var customFeltTile: some View {
        let isSelected = coordinator.feltColor == .custom && coordinator.customBackgroundName == nil
        return Button {
            coordinator.feltColor = .custom
            coordinator.customBackgroundName = nil
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(FeltColorTheme.custom.primaryColor)
                    .frame(width: 70, height: 70)
                    .overlay(Image(systemName: "paintbrush.pointed.fill").foregroundStyle(.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
                Text(coordinator.L(.feltCustomShort)).font(.caption2).foregroundStyle(.primary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func backgroundTile(_ entry: IOSCustomBackgroundManager.Entry) -> some View {
        let isSelected = coordinator.customBackgroundName == entry.name
        return Button {
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
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
                // No caption — unlike card backs, custom backgrounds are never shown
                // with a name anywhere; this blank line just keeps row heights aligned
                // with the felt-color tiles beside it, which do have captions.
                Text(" ").font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture { backgroundPendingDelete = entry }
    }

    private var addBackgroundTile: some View {
        Button {
            showingBackgroundImportSheet = true
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .overlay(Image(systemName: "plus").font(.title3.weight(.bold)).foregroundStyle(.secondary))
                Text(coordinator.L(.addPhotoShort)).font(.caption2).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Felt Color (custom)

    private var feltColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(coordinator.L(.customFeltColorLabel))
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center)
                        )
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(customFeltColorBinding.wrappedValue)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    // Native ColorPicker overlaid invisibly on top — gives the real
                    // system color picker behavior while the rings above show the
                    // current selection at a glance.
                    ColorPicker("", selection: customFeltColorBinding)
                        .labelsHidden()
                        .opacity(0.02)
                        .frame(width: 70, height: 70)
                        .contentShape(Rectangle())
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(coordinator.L(.customFeltColorLabel)).font(.subheadline.weight(.semibold))
                    Text(themeHexString(customFeltColorBinding.wrappedValue))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var customFeltColorBinding: Binding<Color> {
        Binding(
            get: { Color(red: coordinator.customFeltRed, green: coordinator.customFeltGreen, blue: coordinator.customFeltBlue) },
            set: { newColor in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(newColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                coordinator.customFeltRed = Double(r)
                coordinator.customFeltGreen = Double(g)
                coordinator.customFeltBlue = Double(b)
            }
        )
    }

    // MARK: Customization (Card Backs / Card Colors / Face Card Art)

    // One grouped card of nav rows instead of three sections each repeating their own
    // row's label as a bold heading above it — the row's own text already says what it
    // is, the same reasoning that dropped Options' per-game caption text (see
    // OptionsFullScreenView).
    private var customizationSection: some View {
        VStack(spacing: 0) {
            customizationRow(systemImage: "rectangle.stack", title: coordinator.L(.menuSectionCardBack)) {
                showingCardBacksSheet = true
            }
            Divider().padding(.leading, 44)
            customizationRow(systemImage: "paintpalette", title: coordinator.L(.customCardColorHeading)) {
                showingCardColorsSheet = true
            }
            Divider().padding(.leading, 44)
            customizationRow(systemImage: "person.crop.rectangle", title: coordinator.L(.faceCardArtNavRow)) {
                showingFaceArtSheet = true
            }
        }
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func customizationRow(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
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

    // MARK: Shared helpers

    private func localizedFeltName(_ theme: FeltColorTheme) -> String {
        switch theme {
        case .feltGreen:  return coordinator.L(.feltGreen)
        case .crimson:    return coordinator.L(.feltCrimson)
        case .royalBlue:  return coordinator.L(.feltRoyalBlue)
        case .charcoal:   return coordinator.L(.feltCharcoal)
        case .desert:     return coordinator.L(.feltDesert)
        case .custom:     return coordinator.L(.feltCustomColor)
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.title3.weight(.bold))
    }
}

/// Shared hex-string formatter for color swatches across the Themes sheet and its
/// pushed sub-screens (Card Colors, Card Backs' theme previews).
func themeHexString(_ color: Color) -> String {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
}
