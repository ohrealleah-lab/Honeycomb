import SwiftUI
import PhotosUI

/// Import flow for a custom table background: pick a photo, pinch/drag to position it
/// (cropped to roughly the device's own aspect ratio so the preview matches what
/// IOSBackgroundLayer will actually show full-screen), save. No name field — unlike
/// card backs, backgrounds are never shown with a label anywhere in the UI, so `Entry
/// .name` only needs to be a unique lookup key internally; it's generated silently.
struct CustomBackgroundImportSheet: View {
    var onImported: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var manager = IOSCustomBackgroundManager.shared

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    @State private var errorMessage: String? = nil

    @State private var scale: CGFloat = 1.0
    @State private var offsetXFraction: CGFloat = 0
    @State private var offsetYFraction: CGFloat = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(previewImage == nil ? coordinator.L(.touchChoosePhoto) : coordinator.L(.touchChooseDifferentPhoto),
                              systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: photoItem) {
                        Task {
                            guard let data = try? await photoItem?.loadTransferable(type: Data.self),
                                  let image = UIImage(data: data) else { return }
                            previewImage = image
                            scale = 1; offsetXFraction = 0; offsetYFraction = 0
                            errorMessage = nil
                        }
                    }
                }

                if let previewImage {
                    Section(coordinator.L(.touchPinchZoomReposition)) {
                        ImageCropEditor(image: previewImage, aspect: 19.5 / 9.0,
                                       scale: $scale, offsetXFraction: $offsetXFraction, offsetYFraction: $offsetYFraction,
                                       width: 140)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        Button(coordinator.L(.touchResetPositionButton)) {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1; offsetXFraction = 0; offsetYFraction = 0
                            }
                        }
                        .font(.footnote)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle(coordinator.L(.addBackgroundTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(coordinator.L(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.addShort)) { save() }
                        .disabled(previewImage == nil)
                }
            }
        }
    }

    private func save() {
        guard let previewImage else { return }
        let generatedName = UUID().uuidString
        if manager.addCustomBackground(name: generatedName, image: previewImage, scale: scale,
                                        offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction) {
            onImported(generatedName)
            dismiss()
        } else {
            errorMessage = coordinator.L(.touchNameAlreadyTakenError)
        }
    }
}
