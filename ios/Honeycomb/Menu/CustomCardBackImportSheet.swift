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
    @Environment(AppCoordinator.self) private var coordinator
    @State private var manager = IOSCustomCardBackManager.shared

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    // Auto-generated, never shown or edited — the row itself no longer labels tiles
    // by name, so there's nothing for the player to name.
    @State private var name: String = ""
    @State private var errorMessage: String? = nil

    // Crop state, edited live by ImageCropEditor's pinch/drag gestures.
    @State private var scale: CGFloat = 1.0
    @State private var offsetXFraction: CGFloat = 0
    @State private var offsetYFraction: CGFloat = 0

    private static let cardAspect: CGFloat = CardDimensions.aspectRatio

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
                        ImageCropEditor(image: previewImage, aspect: Self.cardAspect,
                                       scale: $scale, offsetXFraction: $offsetXFraction, offsetYFraction: $offsetYFraction)
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
            .onAppear {
                name = Self.nextDefaultName(base: coordinator.L(.cardBackDefaultName),
                                             existing: BundledCardBackImage.allThemeNames + manager.customCardBacks.map(\.name))
            }
            .navigationTitle(coordinator.L(.touchAddCardBackTitle))
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

    /// First unused name of the form "Default", "Default 1", "Default 2", ... against
    /// both bundled theme names and already-saved custom card backs.
    private static func nextDefaultName(base: String, existing: [String]) -> String {
        guard existing.contains(base) else { return base }
        var n = 1
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    private func save() {
        guard let previewImage else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if manager.addCustomCardBack(name: cleaned, image: previewImage, scale: scale,
                                      offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction) {
            onImported(cleaned)
            dismiss()
        } else {
            errorMessage = coordinator.L(.touchNameAlreadyTakenError)
        }
    }
}
