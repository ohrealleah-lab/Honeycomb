import SwiftUI
import AppKit
import UniformTypeIdentifiers

private struct IdentifiableBackgroundImage: Identifiable {
    let id = UUID()
    let image: NSImage
    let data: Data
}

// A single unified sheet-presentation state for both the "Add Custom" and
// "double-click to re-edit" flows. Two separate `.sheet(item:)` modifiers stacked on
// the same parent view is unreliable in SwiftUI — only the first one reliably
// presents — so both flows now share one `.sheet(item:)` driven by this enum.
private enum BackgroundEditorMode: Identifiable {
    case adding(IdentifiableBackgroundImage)
    case editingExisting(CustomBackground, NSImage)

    var id: String {
        switch self {
        case .adding(let item): return "add-\(item.id)"
        case .editingExisting(let background, _): return "edit-\(background.id)"
        }
    }
}

public struct BackgroundSelectorView: View {
    @Binding var customBackgroundName: String?

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @State private var editorMode: BackgroundEditorMode? = nil
    @State private var showingDeleteConfirmation = false
    @State private var backgroundToDelete: String? = nil
    @State private var backgroundInUseByTheme: (backgroundName: String, themeName: String)? = nil
    @State private var showSaveError = false

    public init(customBackgroundName: Binding<String?>) {
        self._customBackgroundName = customBackgroundName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Background:")
                    .font(.system(.body).bold())

                Picker("", selection: Binding(
                    get: { customBackgroundName ?? "" },
                    set: { customBackgroundName = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None (Felt Color)").tag("")
                    ForEach(CustomBackgroundManager.shared.customBackgrounds) { background in
                        Text(background.name).tag(background.name)
                    }
                }
                .font(.system(.body))
                .fixedSize()

                Spacer()

                Button("Add Custom…") { selectImage() }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }

            if let name = customBackgroundName,
               let background = CustomBackgroundManager.shared.customBackgrounds.first(where: { $0.name == name }) {
                HStack(spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        backgroundThumbnail(background)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let image = CustomBackgroundManager.shared.image(for: background.relativePath) {
                                    editorMode = .editingExisting(background, image)
                                }
                            }
                            .help("Click to edit scale and position")

                        Button {
                            deleteBackgroundByName(name)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.white))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                        .help("Delete background")
                    }

                    Text(name)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
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
                        Text("Could not save the background. The image may be corrupt or the disk is full.")
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
        .alert("Delete Background", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { backgroundToDelete = nil }
            Button("Delete", role: .destructive) {
                if let name = backgroundToDelete { confirmDelete(name) }
                backgroundToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this background?")
        }
        .alert("Background In Use", isPresented: Binding(
            get: { backgroundInUseByTheme != nil },
            set: { if !$0 { backgroundInUseByTheme = nil } }
        )) {
            Button("OK", role: .cancel) { backgroundInUseByTheme = nil }
        } message: {
            if let info = backgroundInUseByTheme {
                Text("This background is used by \"\(info.themeName)\". Please delete the theme first.")
            }
        }
    }

    private func backgroundThumbnail(_ background: CustomBackground) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.1))
            if let thumb = CustomBackgroundManager.shared.thumbnail(for: background.relativePath) {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.85), lineWidth: 0.5)
        }
        .frame(width: 60, height: 38)
    }

    // Two-step delete: first tap checks for theme references and either shows the
    // in-use alert (blocking deletion) or arms backgroundToDelete + shows the
    // confirmation alert. The confirmation alert's Delete button calls confirmDelete(_:).
    private func deleteBackgroundByName(_ name: String) {
        if let usedByTheme = ThemeManager.shared.themeReferencingBackground(named: name) {
            backgroundInUseByTheme = (backgroundName: name, themeName: usedByTheme.name)
            return
        }
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
            showAlert(title: "Error", message: "File must be .jpg or .png!", style: .warning)
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            showAlert(title: "Error", message: "Could not load the selected image file.", style: .critical)
            return
        }

        guard data.count <= CustomBackgroundManager.maxImportBytes else {
            showAlert(title: "Image Too Large", message: "That image is larger than 25 MB. Please choose a smaller file.", style: .warning)
            return
        }

        guard let image = NSImage(data: data) else {
            showAlert(title: "Error", message: "Could not load the selected image file.", style: .critical)
            return
        }

        editorMode = .adding(IdentifiableBackgroundImage(image: image, data: data))
    }

    private func showAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
