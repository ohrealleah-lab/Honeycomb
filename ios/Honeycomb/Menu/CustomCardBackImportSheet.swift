import SwiftUI
import PhotosUI

/// Import flow for a user's own card-back image: pick a photo, pinch/drag to position
/// it within the card frame, name it, save. This is the touch-native counterpart to
/// mac's scale/offset sliders — pinch-to-zoom and drag-to-pan read more naturally on a
/// touchscreen than slider controls do. Static images only; unlike mac's
/// CustomCardBackManager, GIF animation isn't supported here.
struct CustomCardBackImportSheet: View {
    /// Called with the new theme's name once the import succeeds, so the caller can
    /// select it immediately rather than leaving the player to find it in the row.
    var onImported: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var manager = IOSCustomCardBackManager.shared

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    @State private var name: String = ""
    @State private var errorMessage: String? = nil

    // Crop state, edited live by ImageCropEditor's pinch/drag gestures.
    @State private var scale: CGFloat = 1.0
    @State private var offsetXFraction: CGFloat = 0
    @State private var offsetYFraction: CGFloat = 0

    private static let cardAspect: CGFloat = 181.0 / 128.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(previewImage == nil ? "Choose Photo" : "Choose a Different Photo",
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
                    Section("Pinch to zoom, drag to reposition") {
                        ImageCropEditor(image: previewImage, aspect: Self.cardAspect,
                                       scale: $scale, offsetXFraction: $offsetXFraction, offsetYFraction: $offsetYFraction)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        Button("Reset Position") {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1; offsetXFraction = 0; offsetYFraction = 0
                            }
                        }
                        .font(.footnote)
                    }
                }

                Section {
                    TextField("Name", text: $name)
                        .onChange(of: name) { errorMessage = nil }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Add Card Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(previewImage == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let previewImage else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if manager.addCustomCardBack(name: cleaned, image: previewImage, scale: scale,
                                      offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction) {
            onImported(cleaned)
            dismiss()
        } else {
            errorMessage = "That name is already taken — pick another."
        }
    }
}
