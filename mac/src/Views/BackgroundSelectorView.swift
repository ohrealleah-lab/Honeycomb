import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct IdentifiableBackgroundImage: Identifiable {
    public let id = UUID()
    let image: NSImage
    let data: Data
}

// A single unified sheet-presentation state for both the "Add Custom" and
// "double-click to re-edit" flows. Two separate `.sheet(item:)` modifiers stacked on
// the same parent view is unreliable in SwiftUI — only the first one reliably
// presents — so both flows now share one `.sheet(item:)` driven by this enum. Not
// `private` (and passed in as a Binding rather than owned here) so ThemesOptionsView's
// hero preview can also drive it — double-tapping the hero preview opens the same
// "editingExisting" sheet as this view's own trigger, matching Windows'
// DeckBackgroundBackdrop_DoubleTapped consolidating what used to be a separate small
// thumbnail's click target.
public enum BackgroundEditorMode: Identifiable {
    case adding(IdentifiableBackgroundImage)
    case editingExisting(CustomBackground, NSImage)

    public var id: String {
        switch self {
        case .adding(let item): return "add-\(item.id)"
        case .editingExisting(let background, _): return "edit-\(background.id)"
        }
    }
}

// One merged picker over both felt presets and custom backgrounds (rather than two
// separate dropdowns each covering half of "what's behind the cards") — selecting a
// felt case clears customBackgroundName, selecting a background leaves feltColor alone
// (it becomes just the fallback for whenever no background image is set). addCustom is
// a momentary action, not a real selection — it never gets stored back into
// customBackgroundName/feltColor, so the picker's displayed value snaps back to
// whichever of those is actually true the instant this triggers the file picker.
private enum FeltOrBackgroundSelection: Hashable {
    case felt(FeltColorTheme)
    case background(String)
    case addCustom
}

public struct BackgroundSelectorView: View {
    @Binding var customBackgroundName: String?
    @Binding var feltColor: FeltColorTheme
    @Binding var showFeltVignette: Bool
    @Binding var editorMode: BackgroundEditorMode?

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @State private var showingDeleteConfirmation = false
    @State private var backgroundToDelete: String? = nil
    @State private var showSaveError = false

    public init(customBackgroundName: Binding<String?>, feltColor: Binding<FeltColorTheme>, showFeltVignette: Binding<Bool>, editorMode: Binding<BackgroundEditorMode?>) {
        self._customBackgroundName = customBackgroundName
        self._feltColor = feltColor
        self._showFeltVignette = showFeltVignette
        self._editorMode = editorMode
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(coordinator.L(.backgroundLabel))
                    .font(.system(.body).bold())

                Picker("", selection: Binding<FeltOrBackgroundSelection>(
                    get: {
                        if let name = customBackgroundName { return .background(name) }
                        return .felt(feltColor)
                    },
                    set: { newValue in
                        switch newValue {
                        case .felt(let f):
                            feltColor = f
                            customBackgroundName = nil
                        case .background(let name):
                            customBackgroundName = name
                        case .addCustom:
                            selectImage()
                        }
                    }
                )) {
                    Text(coordinator.L(.feltGreen)).tag(FeltOrBackgroundSelection.felt(.feltGreen))
                    Text(coordinator.L(.feltCrimson)).tag(FeltOrBackgroundSelection.felt(.crimson))
                    Text(coordinator.L(.feltRoyalBlue)).tag(FeltOrBackgroundSelection.felt(.royalBlue))
                    Text(coordinator.L(.feltCharcoal)).tag(FeltOrBackgroundSelection.felt(.charcoal))
                    Text(coordinator.L(.feltDesert)).tag(FeltOrBackgroundSelection.felt(.desert))
                    Text(coordinator.L(.feltCustomColor)).tag(FeltOrBackgroundSelection.felt(.custom))
                    if !CustomBackgroundManager.shared.customBackgrounds.isEmpty {
                        Divider()
                        ForEach(CustomBackgroundManager.shared.customBackgrounds) { background in
                            Text(background.name).tag(FeltOrBackgroundSelection.background(background.name))
                        }
                    }
                    Divider()
                    Text(coordinator.L(.addCustomBackgroundOption)).tag(FeltOrBackgroundSelection.addCustom)
                }
                .font(.system(.body))
                .fixedSize()

                Spacer()
            }

            // Felt Vignette always lives on its own row (not gated on a custom
            // background being set); Delete Current Wallpaper joins it to the right —
            // only when there's actually a custom background active to delete — instead
            // of Vignette sharing the picker's row, for a cleaner top row. No thumbnail
            // swatch here anymore — the hero preview above already shows the background
            // live, and double-tapping it opens the same edit-position sheet this row
            // used to link to directly (matching Windows, which consolidated its old
            // thumbnail's click target the same way).
            HStack(spacing: 12) {
                Toggle(coordinator.L(.feltVignetteToggle), isOn: $showFeltVignette)
                    .font(.system(.body))

                if let name = customBackgroundName,
                   CustomBackgroundManager.shared.customBackgrounds.contains(where: { $0.name == name }) {
                    // deleteBackgroundByName still runs the same "in use by a saved
                    // theme" check first (blocking with an explanatory alert) before
                    // showing the plain "are you sure" confirmation — unchanged from
                    // when this was an icon button.
                    Button(coordinator.L(.deleteCurrentWallpaper)) {
                        deleteBackgroundByName(name)
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }

                Spacer()
            }
        }
        .sheet(item: $editorMode) { mode in
            switch mode {
            case .adding(let item):
                VStack(spacing: 0) {
                    CustomBackgroundEditorView(image: item.image, showFeltVignette: coordinator.showFeltVignette) { name, scale, offsetX, offsetY in
                        let saved = CustomBackgroundManager.shared.addCustomBackground(
                            name: name, imageData: item.data, scale: scale, offsetX: offsetX,
                            offsetY: offsetY
                        )
                        if saved {
                            customBackgroundName = name
                            showSaveError = false
                            editorMode = nil
                        } else {
                            showSaveError = true
                        }
                    } onCancel: {
                        showSaveError = false
                        editorMode = nil
                    }
                    if showSaveError {
                        Text(coordinator.L(.couldNotSaveBackgroundError))
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            case .editingExisting(let background, let image):
                CustomBackgroundEditorView(image: image, existingBackground: background, showFeltVignette: coordinator.showFeltVignette) { _, scale, offsetX, offsetY in
                    var updated = background
                    updated.scale = scale
                    updated.offsetX = offsetX
                    updated.offsetY = offsetY
                    CustomBackgroundManager.shared.updateCustomBackground(updated)
                    editorMode = nil
                } onCancel: {
                    editorMode = nil
                }
            }
        }
        .alert(coordinator.L(.deleteBackgroundTitle), isPresented: $showingDeleteConfirmation) {
            Button(coordinator.L(.cancel), role: .cancel) { backgroundToDelete = nil }
            Button(coordinator.L(.delete), role: .destructive) {
                if let name = backgroundToDelete { confirmDelete(name) }
                backgroundToDelete = nil
            }
        } message: {
            Text(coordinator.L(.deleteBackgroundBody))
        }
    }

    // Arms backgroundToDelete + shows the confirmation alert. The confirmation alert's
    // Delete button calls confirmDelete(_:), which also clears any saved theme's
    // reference to this background (see ThemeManager.clearBackgroundReferences).
    private func deleteBackgroundByName(_ name: String) {
        backgroundToDelete = name
        showingDeleteConfirmation = true
    }

    private func confirmDelete(_ name: String) {
        if customBackgroundName == name {
            customBackgroundName = nil
        }
        if let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }) {
            CustomBackgroundManager.shared.removeCustomBackground(background)
        }
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let ext = url.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png"].contains(ext) else {
            showAlert(title: coordinator.L(.errorTitle), message: coordinator.L(.fileMustBeJpgPngError), style: .warning)
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            showAlert(title: coordinator.L(.errorTitle), message: coordinator.L(.couldNotLoadSelectedImageFileError), style: .critical)
            return
        }

        guard data.count <= CustomBackgroundManager.maxImportBytes else {
            showAlert(title: coordinator.L(.imageTooLargeTitle), message: coordinator.L(.imageTooLargeMessage), style: .warning)
            return
        }

        guard let image = NSImage(data: data) else {
            showAlert(title: coordinator.L(.errorTitle), message: coordinator.L(.couldNotLoadSelectedImageFileError), style: .critical)
            return
        }

        editorMode = .adding(IdentifiableBackgroundImage(image: image, data: data))
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: coordinator.L(.ok))
        alert.runModal()
    }
}
