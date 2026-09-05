import SwiftUI
import UIKit

/// Full-screen Themes sheet — replaces the old in-slide-down-menu Themes tab. Sections,
/// top to bottom: Saved Themes (carousel), Card Back (carousel), Background & Felt
/// (unified grid, mirrors mac's BackgroundSelectorView merging felt presets +
/// backgrounds into one picker), Custom Card Color (grid). Card Back and Custom Card
/// Color used to be separate pushed sheets reached via a nav-row list; they're inline
/// sections now, each with its own header like Background & Felt.
/// (Face Card Art also exists as a sheet but its entry point is commented out below —
/// not ready to ship yet.)
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
    @State private var isEditingBackgrounds = false

    // Face Card Art is pulled from iOS for now — not ready to ship — but left in place
    // (not deleted) so it's a one-line revert to bring back. See the matching comment
    // at this sheet's .sheet(isPresented:) below. Its former home (a grouped row list
    // alongside Card Back/Card Colors) went away when those two became their own
    // inline sections — reviving Face Card Art will need a new presentation spot.
    // @State private var showingFaceArtSheet = false

    @State private var customCardBacks = IOSCustomCardBackManager.shared
    @State private var showingCardBackImportSheet = false
    // Name, not an Entry — deletion now covers bundled defaults too (no Entry exists
    // for those, just a name string), routed through IOSCustomCardBackManager's
    // unified deleteCardBack(name:).
    @State private var cardBackNamePendingDelete: String? = nil
    @State private var isEditingCardBacks = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    savedThemesSection
                    cardBackSection
                    backgroundAndFeltSection
                    customCardColorSection
                    if coordinator.feltColor == .custom && coordinator.customBackgroundName == nil {
                        feltColorSection
                    }
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.themesPanelTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(coordinator.L(.done)) { dismiss() }
                        .fontWeight(.semibold)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showingBackgroundImportSheet) {
            CustomBackgroundImportSheet { name in
                coordinator.customBackgroundName = name
            }
        }
        // Face Card Art sheet wiring — disabled for now, see the @State declaration above.
        // .sheet(isPresented: $showingFaceArtSheet) { CustomFaceCardArtSheet() }
        .sheet(isPresented: $showingCardBackImportSheet) {
            CustomCardBackImportSheet { name in
                coordinator.cardBackTheme = name
            }
        }
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
        // Matches mac's CustomCardArtSectionView exactly (deleteCardBackTitle +
        // deleteNamedCardBackConfirmFmt) — now shared by bundled and custom card backs
        // alike, not just custom ("This removes the imported image" doesn't apply to a
        // bundled default, since nothing was imported).
        .alert(coordinator.L(.deleteCardBackTitle), isPresented: .init(
            get: { cardBackNamePendingDelete != nil },
            set: { if !$0 { cardBackNamePendingDelete = nil } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.delete), role: .destructive) {
                if let name = cardBackNamePendingDelete {
                    deleteCardBack(named: name)
                }
            }
        } message: {
            Text(coordinator.L(.deleteNamedCardBackConfirmFmt, cardBackNamePendingDelete ?? ""))
        }
    }

    // Matches mac's CustomCardArtSectionView.deleteDeckByName(_:) — reassign the active
    // selection to another still-available deck *before* deleting, mirroring mac's own
    // fallback-to-first-other-active-deck (not a hardcoded name, since any bundled
    // default including "Solibee" can now be deleted too).
    private func deleteCardBack(named name: String) {
        let active = customCardBacks.activeDeckNames
        guard active.count > 1 else { return }
        if coordinator.cardBackTheme == name, let firstOther = active.first(where: { $0 != name }) {
            coordinator.cardBackTheme = firstOther
        }
        customCardBacks.deleteCardBack(name: name)
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
                themeBackgroundView(theme)
                    .overlay(
                        cardBackThumbnailView(theme.cardBackTheme)
                            .frame(width: 44, height: 44 * CardDimensions.aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.5), lineWidth: 1))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3), lineWidth: 1))

                if isEditingSavedThemes {
                    // .buttonStyle(.plain) — see cardBackTile/backgroundTile's identical
                    // delete buttons: without it, iOS's default style pads the hit-testing
                    // region out to a 44x44pt minimum regardless of the icon's own size,
                    // which reaches into the neighboring tile in this same tight carousel.
                    Button {
                        themeToDelete = theme
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.white, .red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
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

    // Saved-theme swatch needs to show the theme's actual background, not just its felt
    // color — a theme saved with a custom photo background should preview that photo,
    // mirroring how backgroundTile below renders custom backgrounds.
    private func themeBackgroundView(_ theme: SoliBeeTheme) -> some View {
        Group {
            if let name = theme.customBackgroundName,
               let entry = customBackgrounds.entry(named: name),
               let image = customBackgrounds.image(for: entry) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                themeColor(theme)
            }
        }
        .frame(width: 90, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            HStack {
                sectionHeading(coordinator.L(.backgroundLabel))
                Spacer()
                Button {
                    isEditingBackgrounds.toggle()
                } label: {
                    Image(systemName: "pencil")
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                // Carousel, matching Saved Themes/Card Back above — was a LazyVGrid
                // wrapping onto multiple rows; a single scrolling row per request.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(FeltColorTheme.allCases.filter { $0 != .custom }, id: \.self) { theme in
                            feltTile(theme)
                        }
                        customFeltTile
                        ForEach(customBackgrounds.backgrounds) { entry in
                            backgroundTile(entry)
                        }
                        addBackgroundTile
                    }
                    .padding(.vertical, 2)
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
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.primaryColor)
                .frame(width: 70, height: 70)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
        }
        .buttonStyle(.plain)
    }

    private var customFeltTile: some View {
        let isSelected = coordinator.feltColor == .custom && coordinator.customBackgroundName == nil
        return Button {
            coordinator.feltColor = .custom
            coordinator.customBackgroundName = nil
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(FeltColorTheme.custom.primaryColor)
                .frame(width: 70, height: 70)
                .overlay(Image(systemName: "paintbrush.pointed.fill").foregroundStyle(.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
        }
        .buttonStyle(.plain)
    }

    private func backgroundTile(_ entry: IOSCustomBackgroundManager.Entry) -> some View {
        let isSelected = coordinator.customBackgroundName == entry.name
        return ZStack(alignment: .topTrailing) {
            Button {
                coordinator.customBackgroundName = entry.name
            } label: {
                Group {
                    if let image = customBackgrounds.image(for: entry) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                // See cardBackTile — .clipShape alone doesn't reliably constrain a
                // Button's hit-testing to the clipped shape; needs this too.
                .contentShape(Rectangle())
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
            }
            .buttonStyle(.plain)

            if isEditingBackgrounds {
                // .buttonStyle(.plain) — without it this Button falls back to
                // iOS's default style, which pads its hit-testing region out to a
                // 44x44pt minimum tap target regardless of the icon's own size.
                // Same fix as cardBackTile's delete button, for the same reason:
                // in a tight 70pt-tile/14pt-gap carousel, that invisible inflation
                // reaches into the neighboring tile.
                Button {
                    backgroundPendingDelete = entry
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.white, .red)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .frame(width: 70, height: 70)
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

    // MARK: Card Back

    // Same carousel shape as savedThemesSection above (horizontal ScrollView, add-tile
    // last) rather than the grid backgroundAndFeltSection uses — a card back's own
    // aspect ratio reads better as a single scrolling row than wrapped into a grid.
    private var cardBackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Trailing colon added here, not in the localized string itself — the
                // same key is also used as a plain (colon-less) navigation title by the
                // now-dormant CardBacksSheet.
                sectionHeading(coordinator.L(.menuSectionCardBack) + ":")
                Spacer()
                // Only worth showing once there's something to restore — a bundled
                // default deleted via the (–) below. Matches mac's
                // resetDefaultCardBacks(), which has the same underlying method but
                // never got its own UI there either.
                if isEditingCardBacks && !customCardBacks.deletedDefaultDecks.isEmpty {
                    Button(coordinator.L(.reset)) {
                        customCardBacks.resetDeletedDefaults()
                    }
                    .font(.subheadline)
                    .padding(.trailing, 8)
                }
                Button {
                    isEditingCardBacks.toggle()
                } label: {
                    Image(systemName: "pencil")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(customCardBacks.activeDeckNames, id: \.self) { name in
                        cardBackTile(name)
                    }
                    addCardBackTile
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func cardBackTile(_ name: String) -> some View {
        let isSelected = coordinator.cardBackTheme == name
        // Matches mac's hide-the-delete-button-once-only-one-remains pattern — rather
        // than a "last card back" warning nobody can ever trigger, the (–) itself just
        // isn't offered on whichever tile would leave zero behind.
        let canDelete = customCardBacks.activeDeckNames.count > 1
        // Explicit frame on the ZStack itself, not just the image inside it — a
        // custom card back's thumbnail (CroppedCardBackImage) wraps its content in
        // a GeometryReader, which reports size to the surrounding HStack
        // differently than a bundled tile's plain Image does. Without pinning the
        // whole tile to a known width, the row's layout math can drift right at
        // the boundary between a plain-Image tile and a GeometryReader one next to
        // it — the drawn position stays correct but hit-testing shifts onto the
        // neighboring tile, which is exactly what made Solibee's delete button
        // (sitting right before the custom card backs) register taps on the tile
        // to its right instead.
        return ZStack(alignment: .topTrailing) {
            Button {
                coordinator.cardBackTheme = name
            } label: {
                cardBackThumbnailView(name)
                    .frame(width: 70, height: 70 * CardDimensions.aspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // Belt-and-suspenders: .clipShape above already constrains hit-testing
                    // to this same shape, but pin it explicitly in case that's not holding
                    // for some reason not yet identified.
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
            }
            .buttonStyle(.plain)

            if isEditingCardBacks && canDelete {
                // .buttonStyle(.plain) here too — without it, this Button falls back
                // to iOS's default style, which pads its hit-testing region out to
                // (at least) a 44x44pt minimum tap target regardless of how small
                // the icon itself is drawn. Centered on a topTrailing icon this size
                // in a 70pt-wide tile with only 14pt between tiles, that inflated
                // region reached a few points into the neighboring tile — the
                // residual overlap left after pinning the tile's own width above,
                // which only fixed the *layout* drift, not this separate hit-area
                // inflation.
                Button {
                    cardBackNamePendingDelete = name
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.white, .red)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .frame(width: 70, height: 70 * CardDimensions.aspectRatio)
    }

    private var addCardBackTile: some View {
        Button {
            showingCardBackImportSheet = true
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 70, height: 70 * CardDimensions.aspectRatio)
                    .overlay(Image(systemName: "plus").font(.title3.weight(.bold)).foregroundStyle(.secondary))
                Text(coordinator.L(.addShort)).font(.caption2).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Custom Card Color

    private var customCardColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                // Trailing colon added here, not in the localized string itself — the
                // same key is also used as a plain (colon-less) navigation title by the
                // now-dormant CustomCardColorsSheet.
                sectionHeading(coordinator.L(.customCardColorHeading) + ":")
                Spacer()
                Button(coordinator.L(.reset)) {
                    coordinator.customCardColors.reset()
                }
                .font(.subheadline)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 16) {
                cardColorSwatch(coordinator.L(.cardBackgroundLabel), binding: $coordinator.customCardColors.backgroundColor)
                cardColorSwatch(coordinator.L(.cardOutlineLabel), binding: $coordinator.customCardColors.outlineColor)
                cardColorSwatch(coordinator.L(.blackSuitTextLabel), binding: $coordinator.customCardColors.blackSuitColor)
                cardColorSwatch(coordinator.L(.redSuitTextLabel), binding: $coordinator.customCardColors.redSuitColor)
                cardColorSwatch(coordinator.L(.hintHighlightLabel), binding: $coordinator.customCardColors.hintHighlightColor)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func cardColorSwatch(_ label: String, binding: Binding<Color>) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(binding.wrappedValue).frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                ColorPicker("", selection: binding)
                    .labelsHidden()
                    .opacity(0.02)
                    .frame(width: 54, height: 54)
                    .contentShape(Rectangle())
            }
            Text(label).font(.caption2.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            Text(themeHexString(binding.wrappedValue)).font(.caption2.monospaced()).foregroundStyle(.secondary)
        }
    }

    // MARK: Shared helpers

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
