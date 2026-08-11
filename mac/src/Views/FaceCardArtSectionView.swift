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
            RoundedRectangle(cornerRadius: 8).fill(Color.white).frame(width: Self.tileWidth, height: Self.tileHeight)

            Group {
                if let art, let img = CustomFaceCardArtManager.shared.image(for: art) {
                    // Inner clip window (~1.12x the art's own base frame, matching
                    // CustomFaceArtImageView's artWidth/clipWidth ratio) — without this,
                    // the only clip boundary was the outer tileWidth×tileHeight frame
                    // below (the whole tile), so a scaleEffect-inflated image had room
                    // to expand and fill nearly the entire card before hitting anything,
                    // instead of being contained the same tight amount gameplay/the
                    // editor now are.
                    ZStack {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: Self.artWidth, height: Self.artHeight)
                            .scaleEffect(CGFloat(art.scale))
                            .offset(x: CGFloat(art.offsetX) * (Self.tileWidth / 128.0),
                                    y: CGFloat(art.offsetY) * (Self.tileWidth / 128.0))
                    }
                    .frame(width: Self.artClipWidth, height: Self.artClipHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(art.isEnabled ? 1.0 : 0.3)
                } else {
                    // "+" hint — clearer click affordance than a flat centered suit
                    // watermark (which read as a rendering glitch, not an empty state),
                    // and the suit itself is already covered by the corner indices.
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .frame(width: Self.tileWidth, height: Self.tileHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Corner indices — same top-left / bottom-right (rotated 180°) rank+suit
            // pattern as the real CardView / FaceCardArtEditorView preview, scaled down
            // to tile size, so these read as actual mini playing cards.
            cornerIndex
                .padding(.leading, 4).padding(.top, 3)
                .frame(width: Self.tileWidth, height: Self.tileHeight, alignment: .topLeading)

            cornerIndex
                .rotationEffect(.degrees(180))
                .padding(.trailing, 4).padding(.bottom, 3)
                .frame(width: Self.tileWidth, height: Self.tileHeight, alignment: .bottomTrailing)

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.85), lineWidth: 0.5)
                .frame(width: Self.tileWidth, height: Self.tileHeight)
        }
        // Matches CardView's own shadow so these mini previews read as real cards
        // instead of flat rectangles sitting on the panel.
        .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
    }

    // Sized up from the original 60×85 so the grid fills more of the panel.
    static let tileWidth: CGFloat = 82
    static let tileHeight: CGFloat = 115
    // Must be tileWidth/tileHeight scaled by the SAME ratio FaceCardArtEditorView's art
    // frame (66×105 — see its own comment for why not the original 77×122) has to a
    // full card (CardDimensions 128×181) — otherwise a given scale/offset value set in
    // the editor renders at a different, more "zoomed in" apparent size here than what
    // the editor actually showed, since scaleEffect/offset are applied relative to this
    // frame, not to the tile as a whole.
    static let artWidth: CGFloat = tileWidth * 66.0 / CardDimensions.width
    static let artHeight: CGFloat = tileHeight * 105.0 / CardDimensions.height
    // The actual containment boundary for scaled/offset art — see the inner ZStack's
    // comment above. Same 74×119-to-128×181 ratio CustomFaceArtImageView's
    // clipWidth/clipHeight use, scaled down to tile size.
    static let artClipWidth: CGFloat = tileWidth * 74.0 / CardDimensions.width
    static let artClipHeight: CGFloat = tileHeight * 119.0 / CardDimensions.height

    private var cornerIndex: some View {
        VStack(spacing: 0) {
            Text(slot.rankLabel).font(.system(size: 11, weight: .bold))
            Text(slot.suitSymbol).font(.system(size: 9))
        }
        .foregroundColor(cardColor)
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

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

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
                Text(coordinator.L(.editFaceCardArtTitleFmt, slot.rankLabel, slot.suitSymbol))
                    .font(.display(18)).foregroundColor(.primary).padding(.top)

                // Card preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white).frame(width: CardDimensions.width, height: CardDimensions.height).shadow(radius: 4)

                    // Custom art in center area — drawn before the corner indices below
                    // (not after) so they always stay legible on top of it, matching
                    // CardFrontView/CustomFaceArtImageView's real gameplay z-order.
                    // 66×105/74×119 (not 77×122/86×138) — sized down from the original
                    // so the art's own clipped edge doesn't crowd the corner indices,
                    // kept in sync with CustomFaceArtImageView's exact numbers.
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 66, height: 105)
                            .scaleEffect(CGFloat(scale))
                            .offset(x: CGFloat(offsetX), y: CGFloat(offsetY))
                    }
                    .frame(width: 74, height: 119)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Corner indices
                    HStack(alignment: .center, spacing: 1) {
                        Text(slot.rankLabel).font(.system(size: 17, weight: .bold))
                        Text(slot.suitSymbol).font(.system(size: 14))
                    }
                    .foregroundColor(cardColor)
                    .padding(.leading, 8).padding(.top, 8)
                    .frame(width: CardDimensions.width, height: CardDimensions.height, alignment: .topLeading)

                    HStack(alignment: .center, spacing: 1) {
                        Text(slot.rankLabel).font(.system(size: 17, weight: .bold))
                        Text(slot.suitSymbol).font(.system(size: 14))
                    }
                    .foregroundColor(cardColor)
                    .rotationEffect(.degrees(180))
                    .padding(.trailing, 8).padding(.bottom, 8)
                    .frame(width: CardDimensions.width, height: CardDimensions.height, alignment: .bottomTrailing)

                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                        .frame(width: 128, height: 181)
                }
                .frame(width: 150, height: 200)

                // Scale
                sliderRow(label: coordinator.L(.scaleShortLabel), value: $scale, in: 0.5...3.0,
                          format: coordinator.L(.scaleFmt, scale))

                // Horizontal offset
                sliderRow(label: coordinator.L(.horizontalShortLabel), value: $offsetX, in: -100...100,
                          format: coordinator.L(.pxOffsetFmt, offsetX))

                // Vertical offset
                sliderRow(label: coordinator.L(.verticalShortLabel), value: $offsetY, in: -100...100,
                          format: coordinator.L(.pxOffsetFmt, offsetY))

                // Buttons
                HStack(spacing: 12) {
                    if onDelete != nil {
                        themedEditorButton(coordinator.L(.remove), tint: .red) { onDelete?() }
                    }
                    themedEditorButton(coordinator.L(.reset), tint: .secondary) {
                        scale = 1.0; offsetX = 0; offsetY = 0
                    }
                    Spacer()
                    themedEditorButton(coordinator.L(.cancel), tint: .primary, shortcut: .cancelAction) { onCancel() }
                    themedEditorButton(coordinator.L(.save), tint: .primary, shortcut: .defaultAction) { onSave(scale, offsetX, offsetY) }
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

    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    private let spadeSlots: [FaceCardSlot]   = [.spadeAce,   .spadeJack,   .spadeQueen,   .spadeKing]
    private let clubSlots: [FaceCardSlot]    = [.clubAce,    .clubJack,    .clubQueen,    .clubKing]
    private let heartSlots: [FaceCardSlot]   = [.heartAce,   .heartJack,   .heartQueen,   .heartKing]
    private let diamondSlots: [FaceCardSlot] = [.diamondAce, .diamondJack, .diamondQueen, .diamondKing]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 3) {
                slotRow(slots: spadeSlots)
                slotRow(slots: clubSlots)
                slotRow(slots: heartSlots)
                slotRow(slots: diamondSlots)
            }
            .frame(maxWidth: .infinity, alignment: .center)
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
        .alert(coordinator.L(.removeArtTitle), isPresented: $showingDeleteAlert) {
            Button(coordinator.L(.cancel), role: .cancel) { slotToDelete = nil }
            Button(coordinator.L(.remove), role: .destructive) {
                if let slot = slotToDelete { CustomFaceCardArtManager.shared.remove(slot: slot) }
                slotToDelete = nil
            }
        } message: { Text(coordinator.L(.removeArtConfirmBody)) }
    }

    private func slotRow(slots: [FaceCardSlot]) -> some View {
        HStack(spacing: 9) {
            ForEach(slots) { slot in
                slotTile(slot)
            }
        }
    }

    private func slotTile(_ slot: FaceCardSlot) -> some View {
        let art = CustomFaceCardArtManager.shared.art(for: slot)
        return VStack(spacing: 1) {
            ZStack(alignment: .topTrailing) {
                // Fixed-size anchor so the ZStack never resizes
                Color.clear.frame(width: FaceCardSlotTileView.tileWidth + 8, height: FaceCardSlotTileView.tileHeight + 8)

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
                .help(coordinator.L(.removeArtTooltip))
                .opacity(art != nil ? 1 : 0)
            }

            Toggle("", isOn: Binding(
                get: { art?.isEnabled ?? false },
                set: { CustomFaceCardArtManager.shared.setEnabled($0, for: slot) }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.6)
            .frame(height: 14)
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
            showError(coordinator.L(.fileMustBeJpgPngGifError))
            return
        }
        guard let image = NSImage(contentsOf: url) else {
            showError(coordinator.L(.couldNotLoadSelectedImageError))
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
            showError(coordinator.L(.couldNotReadImageDataError))
            return
        }
        pendingImport = FaceCardIdentifiableImage(slot: slot, image: image, rawData: data, isGIF: isGIF)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = coordinator.L(.errorTitle)
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: coordinator.L(.ok))
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
