import SwiftUI
import PhotosUI

/// Grid of all 16 face-card slots (A/J/Q/K x 4 suits) — tap an empty slot to import art
/// for it, tap a filled slot to re-crop/replace/remove it, toggle enabled without losing
/// the saved image. Mirrors mac's per-slot face art grid but as a single sheet rather
/// than a dedicated settings section.
struct CustomFaceCardArtSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var manager = IOSCustomFaceArtManager.shared
    @State private var editingSlot: FaceCardSlot? = nil
    @State private var isEditingFaceArt = false
    @State private var slotPendingDelete: FaceCardSlot? = nil

    // Fixed 4 columns (not .adaptive) — FaceCardSlot.allCases is already suit-major (all
    // 4 spades, then clubs, hearts, diamonds), so exactly 4 columns lines each suit up on
    // its own row instead of an adaptive column count splitting suits across row breaks.
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(FaceCardSlot.allCases) { slot in
                        slotTile(slot)
                    }
                }
                .padding()
            }
            .navigationTitle(coordinator.L(.faceCardArtNavRow))
            .navigationBarTitleDisplayMode(.inline)
            // Fewer, wider columns need more vertical room for all 4 rows to sit
            // comfortably — the default iPad form-sheet size (fixed, not content-driven)
            // otherwise leaves the bottom row cramped against the sheet's edge.
            .presentationDetents([.large])
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(coordinator.L(.back)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isEditingFaceArt.toggle()
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .sheet(item: $editingSlot) { slot in
                FaceArtImportSheet(slot: slot)
            }
            .alert(coordinator.L(.removeFaceArtAlertTitle), isPresented: .init(
                get: { slotPendingDelete != nil },
                set: { if !$0 { slotPendingDelete = nil } }
            )) {
                Button(coordinator.L(.cancel), role: .cancel) {}
                Button(coordinator.L(.remove), role: .destructive) {
                    if let slot = slotPendingDelete { manager.removeArt(for: slot) }
                    slotPendingDelete = nil
                }
            } message: {
                Text(coordinator.L(.removeImportedImageBody))
            }
        }
    }

    private func slotTile(_ slot: FaceCardSlot) -> some View {
        let entry = manager.entry(for: slot)
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Button {
                    editingSlot = slot
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .aspectRatio((1.0 / CardDimensions.aspectRatio), contentMode: .fit)
                        if let entry, let image = manager.image(for: entry) {
                            ImageCropDisplay(image: image, entry: entry)
                                .aspectRatio((1.0 / CardDimensions.aspectRatio), contentMode: .fit)
                                .opacity(entry.isEnabled ? 1 : 0.3)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            VStack(spacing: 2) {
                                Text(slot.rankLabel).font(.title3.bold())
                                Text(slot.suitSymbol).font(.title3)
                            }
                            .foregroundStyle(slot.isRed ? .red : .black)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)

                if isEditingFaceArt && entry != nil {
                    Button {
                        slotPendingDelete = slot
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.white, .red)
                            .font(.title3)
                    }
                    .padding(4)
                }
            }
            Text(slot.displayName).font(.caption2).foregroundStyle(.primary)
        }
    }
}

/// Import/edit flow for a single face-card slot: pick a photo, crop, save (or replace an
/// existing image), with an enable toggle and remove action when art already exists.
private struct FaceArtImportSheet: View {
    let slot: FaceCardSlot
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @State private var manager = IOSCustomFaceArtManager.shared

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var previewImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var offsetXFraction: CGFloat = 0
    @State private var offsetYFraction: CGFloat = 0
    @State private var isEnabled: Bool = true

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
                        }
                    }
                }

                if let previewImage {
                    Section(coordinator.L(.touchPinchZoomReposition)) {
                        ImageCropEditor(image: previewImage, aspect: CardDimensions.aspectRatio,
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

                    if manager.entry(for: slot) != nil {
                        Section {
                            Toggle(coordinator.L(.touchEnabledToggle), isOn: $isEnabled)
                        }
                    }
                }

                if manager.entry(for: slot) != nil {
                    Section {
                        Button(coordinator.L(.removeArtTitle), role: .destructive) {
                            manager.removeArt(for: slot)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(slot.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(coordinator.L(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.save)) { save() }
                        .disabled(previewImage == nil)
                }
            }
        }
        .onAppear {
            if let entry = manager.entry(for: slot), let image = manager.image(for: entry) {
                previewImage = image
                scale = entry.scale
                offsetXFraction = entry.offsetXFraction
                offsetYFraction = entry.offsetYFraction
                isEnabled = entry.isEnabled
            }
        }
    }

    private func save() {
        guard let previewImage else { return }
        manager.setArt(slot: slot, image: previewImage, scale: scale,
                       offsetXFraction: offsetXFraction, offsetYFraction: offsetYFraction)
        manager.setEnabled(isEnabled, for: slot)
        dismiss()
    }
}
