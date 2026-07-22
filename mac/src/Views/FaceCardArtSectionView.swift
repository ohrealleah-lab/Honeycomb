import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Identifiable image for face card import

struct FaceCardIdentifiableImage: Identifiable {
    let id = UUID()
    let slot: FaceCardSlot
    let image: NSImage
    let rawData: Data       // PNG bytes or raw GIF bytes
    let isGIF: Bool
}

// MARK: - Mini card preview for a face card slot

struct FaceCardSlotTileView: View {
    let slot: FaceCardSlot

    private var cardColor: Color { slot.isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.1, blue: 0.1) }

    var body: some View {
        // Read directly from the manager so SwiftUI's @Observable tracking only re-renders
        // this tile when its specific slot entry in faceArts changes.
        let art = CustomFaceCardArtManager.shared.art(for: slot)
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.white).frame(width: 60, height: 85)

            Group {
                if let art, let img = CustomFaceCardArtManager.shared.image(for: art) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 70)
                        .scaleEffect(CGFloat(art.scale))
                        .offset(x: CGFloat(art.offsetX) * (60.0 / 128.0),
                                y: CGFloat(art.offsetY) * (60.0 / 128.0))
                        .opacity(art.isEnabled ? 1.0 : 0.3)
                } else {
                    defaultPreview
                }
            }
            .frame(width: 60, height: 85)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.85), lineWidth: 0.5)
                .frame(width: 60, height: 85)
        }
    }

    @ViewBuilder
    private var defaultPreview: some View {
        if slot.rank == 1 {
            Text(slot.suitSymbol).font(.system(size: 30)).foregroundColor(cardColor)
        } else {
            VStack(spacing: 0) {
                Text(slot.rankLabel).font(.system(size: 20, weight: .bold)).foregroundColor(cardColor)
                Text(slot.suitSymbol).font(.system(size: 14)).foregroundColor(cardColor)
            }
        }
    }
}

// MARK: - Face card art editor

struct FaceCardArtEditorView: View {
    let slot: FaceCardSlot
    let image: NSImage
    let rawData: Data
    let isGIF: Bool
    let existingArt: CustomFaceArt?
    let onSave: (Double, Double, Double) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var scale: Double
    @State private var offsetX: Double
    @State private var offsetY: Double

    private var cardColor: Color { slot.isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.1, blue: 0.1) }

    init(slot: FaceCardSlot, image: NSImage, rawData: Data, isGIF: Bool,
         existingArt: CustomFaceArt?, onSave: @escaping (Double, Double, Double) -> Void,
         onDelete: (() -> Void)?, onCancel: @escaping () -> Void) {
        self.slot = slot
        self.image = image
        self.rawData = rawData
        self.isGIF = isGIF
        self.existingArt = existingArt
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _scale = State(initialValue: existingArt?.scale ?? 1.0)
        _offsetX = State(initialValue: existingArt?.offsetX ?? 0.0)
        _offsetY = State(initialValue: existingArt?.offsetY ?? 0.0)
    }

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Edit \(slot.rankLabel)\(slot.suitSymbol) Art")
                    .font(.display(18)).foregroundColor(.primary).padding(.top)

                // Card preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white).frame(width: 128, height: 181).shadow(radius: 4)

                    // Corner indices
                    HStack(alignment: .center, spacing: 1) {
                        Text(slot.rankLabel).font(.system(size: 17, weight: .bold))
                        Text(slot.suitSymbol).font(.system(size: 14))
                    }
                    .foregroundColor(cardColor)
                    .padding(.leading, 8).padding(.top, 8)
                    .frame(width: 128, height: 181, alignment: .topLeading)

                    HStack(alignment: .center, spacing: 1) {
                        Text(slot.rankLabel).font(.system(size: 17, weight: .bold))
                        Text(slot.suitSymbol).font(.system(size: 14))
                    }
                    .foregroundColor(cardColor)
                    .rotationEffect(.degrees(180))
                    .padding(.trailing, 8).padding(.bottom, 8)
                    .frame(width: 128, height: 181, alignment: .bottomTrailing)

                    // Custom art in center area
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 77, height: 122)
                            .scaleEffect(CGFloat(scale))
                            .offset(x: CGFloat(offsetX), y: CGFloat(offsetY))
                    }
                    .frame(width: 86, height: 138)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                        .frame(width: 128, height: 181)
                }
                .frame(width: 150, height: 200)

                // Scale
                sliderRow(label: "Scale", value: $scale, in: 0.5...3.0,
                          format: String(format: "%.2fx", scale))

                // Horizontal offset
                sliderRow(label: "Horizontal", value: $offsetX, in: -100...100,
                          format: String(format: "%.0f px", offsetX))

                // Vertical offset
                sliderRow(label: "Vertical", value: $offsetY, in: -100...100,
                          format: String(format: "%.0f px", offsetY))

                // Buttons
                HStack(spacing: 12) {
                    if onDelete != nil {
                        themedEditorButton("Remove", tint: .red) { onDelete?() }
                    }
                    themedEditorButton("Reset", tint: .secondary) {
                        scale = 1.0; offsetX = 0; offsetY = 0
                    }
                    Spacer()
                    themedEditorButton("Cancel", tint: .primary, shortcut: .cancelAction) { onCancel() }
                    themedEditorButton("Save", tint: .primary, shortcut: .defaultAction) { onSave(scale, offsetX, offsetY) }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 340, height: 520)
    }

    private func sliderRow(label: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.display(12)).foregroundColor(.secondary)
                Spacer()
                Text(format).font(.display(12)).foregroundColor(.primary)
            }
            Slider(value: value, in: range).frame(width: 200)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Face card art section

struct FaceCardArtSectionView: View {
    @State private var pendingImport: FaceCardIdentifiableImage? = nil
    @State private var editingExistingSlot: FaceCardSlot? = nil
    @State private var slotToDelete: FaceCardSlot? = nil
    @State private var showingDeleteAlert = false

    private let spadeSlots: [FaceCardSlot]   = [.spadeAce,   .spadeJack,   .spadeQueen,   .spadeKing]
    private let clubSlots: [FaceCardSlot]    = [.clubAce,    .clubJack,    .clubQueen,    .clubKing]
    private let heartSlots: [FaceCardSlot]   = [.heartAce,   .heartJack,   .heartQueen,   .heartKing]
    private let diamondSlots: [FaceCardSlot] = [.diamondAce, .diamondJack, .diamondQueen, .diamondKing]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Face Card Art")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)

            VStack(spacing: 8) {
                slotRow(slots: spadeSlots)
                slotRow(slots: clubSlots)
                slotRow(slots: heartSlots)
                slotRow(slots: diamondSlots)
            }
        }
        .sheet(item: $pendingImport) { item in
            FaceCardArtEditorView(
                slot: item.slot,
                image: item.image,
                rawData: item.rawData,
                isGIF: item.isGIF,
                existingArt: CustomFaceCardArtManager.shared.art(for: item.slot),
                onSave: { scale, offsetX, offsetY in
                    _ = CustomFaceCardArtManager.shared.add(
                        slot: item.slot,
                        imageData: item.rawData,
                        isGIF: item.isGIF,
                        scale: scale,
                        offsetX: offsetX,
                        offsetY: offsetY
                    )
                    pendingImport = nil
                },
                onDelete: CustomFaceCardArtManager.shared.art(for: item.slot) != nil ? {
                    CustomFaceCardArtManager.shared.remove(slot: item.slot)
                    pendingImport = nil
                } : nil,
                onCancel: { pendingImport = nil }
            )
        }
        .sheet(item: $editingExistingSlot) { slot in
            if let art = CustomFaceCardArtManager.shared.art(for: slot),
               let img = CustomFaceCardArtManager.shared.image(for: art) {
                FaceCardArtEditorView(
                    slot: slot,
                    image: img,
                    rawData: Data(),
                    isGIF: CustomFaceCardArtManager.shared.isGIF(art),
                    existingArt: art,
                    onSave: { scale, offsetX, offsetY in
                        var updated = art
                        updated.scale = scale
                        updated.offsetX = offsetX
                        updated.offsetY = offsetY
                        CustomFaceCardArtManager.shared.update(updated)
                        editingExistingSlot = nil
                    },
                    onDelete: {
                        CustomFaceCardArtManager.shared.remove(slot: slot)
                        editingExistingSlot = nil
                    },
                    onCancel: { editingExistingSlot = nil }
                )
            }
        }
        .alert("Remove Art", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { slotToDelete = nil }
            Button("Remove", role: .destructive) {
                if let slot = slotToDelete { CustomFaceCardArtManager.shared.remove(slot: slot) }
                slotToDelete = nil
            }
        } message: { Text("Remove the custom art for this slot?") }
    }

    private func slotRow(slots: [FaceCardSlot]) -> some View {
        HStack(spacing: 12) {
            ForEach(slots) { slot in
                slotTile(slot)
            }
        }
    }

    private func slotTile(_ slot: FaceCardSlot) -> some View {
        let art = CustomFaceCardArtManager.shared.art(for: slot)
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Fixed-size anchor so the ZStack never resizes
                Color.clear.frame(width: 70, height: 95)

                FaceCardSlotTileView(slot: slot)
                    .onTapGesture(count: 2) {
                        if art != nil { editingExistingSlot = slot }
                    }
                    .onTapGesture(count: 1) {
                        if art == nil { selectImage(for: slot) }
                    }

                Button {
                    slotToDelete = slot
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Remove art")
                .opacity(art != nil ? 1 : 0)
            }

            Toggle("", isOn: Binding(
                get: { art?.isEnabled ?? false },
                set: { CustomFaceCardArtManager.shared.setEnabled($0, for: slot) }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.7)
            .frame(height: 20)
            .opacity(art != nil ? 1 : 0)

            Text(slot.displayName)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private func selectImage(for slot: FaceCardSlot) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .gif]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let ext = url.pathExtension.lowercased()
        guard ["jpg", "jpeg", "png", "gif"].contains(ext) else {
            showError("File must be .jpg, .png, or .gif.")
            return
        }
        guard let image = NSImage(contentsOf: url) else {
            showError("Could not load the selected image.")
            return
        }

        let isGIF = ext == "gif"
        let rawData: Data?
        if isGIF {
            rawData = try? Data(contentsOf: url)
        } else {
            rawData = CustomFaceCardArtManager.shared.pngData(from: image)
        }
        guard let data = rawData else {
            showError("Could not read image data.")
            return
        }
        pendingImport = FaceCardIdentifiableImage(slot: slot, image: image, rawData: data, isGIF: isGIF)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Consolidated art panel (card backs + face cards)

public struct CustomArtPanelView: View {
    @Binding var cardBackTheme: String
    @Binding var feltColor: FeltColorTheme

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardDeckSelectorView(cardBackTheme: $cardBackTheme, feltColor: $feltColor)

            Divider().background(Color.white.opacity(0.2))

            FaceCardArtSectionView()
        }
    }
}
