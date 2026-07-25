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

    // Committed crop state (persisted between gestures) plus the in-flight gesture
    // deltas (@GestureState below), combined for live feedback during the gesture and
    // saved into `scale`/`offsetXFraction`/`offsetYFraction` once it ends.
    @State private var scale: CGFloat = 1.0
    @State private var offsetXFraction: CGFloat = 0
    @State private var offsetYFraction: CGFloat = 0
    @GestureState private var pinchDelta: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero

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
                        cropPreview(previewImage)
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

    private func cropPreview(_ image: UIImage) -> some View {
        let width: CGFloat = 180
        let height = width * Self.cardAspect
        return GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale * pinchDelta)
                .offset(x: offsetXFraction * geo.size.width + dragDelta.width,
                        y: offsetYFraction * geo.size.height + dragDelta.height)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .updating($pinchDelta) { value, state, _ in state = value }
                    .onEnded { value in scale = max(0.5, min(3.0, scale * value)) },
                DragGesture()
                    .updating($dragDelta) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offsetXFraction += value.translation.width / width
                        offsetYFraction += value.translation.height / height
                    }
            )
        )
        .frame(maxWidth: .infinity, alignment: .center)
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
