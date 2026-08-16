import SwiftUI
import PhotosUI

/// Card Back picker, its own full screen (matches mac's dedicated Card Back section) —
/// pulled out of ThemesFullScreenView's inline grid so it's a nav row + push, like Face
/// Card Art.
struct CardBacksSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coordinator: AppCoordinator

    @State private var customCardBacks = IOSCustomCardBackManager.shared
    @State private var showingImportSheet = false
    @State private var entryPendingDelete: IOSCustomCardBackManager.Entry? = nil

    private let gridColumns = [GridItem(.adaptive(minimum: 74), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                let allNames = BundledCardBackImage.allThemeNames + customCardBacks.customCardBacks.map(\.name)
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    addCardBackTile
                    ForEach(allNames, id: \.self) { name in
                        cardBackTile(name, isCustom: customCardBacks.customCardBacks.contains { $0.name == name })
                    }
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.menuSectionCardBack))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            CustomCardBackImportSheet { name in
                coordinator.cardBackTheme = name
            }
        }
        .alert(coordinator.L(.removeCardBackAlertTitle), isPresented: .init(
            get: { entryPendingDelete != nil },
            set: { if !$0 { entryPendingDelete = nil } }
        )) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.remove), role: .destructive) {
                if let entry = entryPendingDelete {
                    if coordinator.cardBackTheme == entry.name { coordinator.cardBackTheme = "Solibee" }
                    customCardBacks.removeCustomCardBack(entry)
                }
            }
        } message: {
            Text(coordinator.L(.removeImportedImageBody))
        }
    }

    private func cardBackTile(_ name: String, isCustom: Bool) -> some View {
        let isSelected = coordinator.cardBackTheme == name
        return Button {
            coordinator.cardBackTheme = name
        } label: {
            VStack(spacing: 4) {
                cardBackThumbnailView(name)
                    .frame(width: 70, height: 70 * CardDimensions.aspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0))
                Text(name).font(.caption2).foregroundStyle(.primary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard isCustom else { return }
                entryPendingDelete = customCardBacks.customCardBacks.first { $0.name == name }
            }
        )
    }

    private var addCardBackTile: some View {
        Button {
            showingImportSheet = true
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
}

/// Renders a card back's thumbnail (bundled or custom), by name. Free function so both
/// this sheet and ThemesFullScreenView's saved-theme tiles can share it without either
/// depending on the other.
@ViewBuilder
func cardBackThumbnailView(_ name: String) -> some View {
    if let image = BundledCardBackImage.uiImage(for: name) {
        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
    } else if let entry = IOSCustomCardBackManager.shared.entry(named: name),
              let image = IOSCustomCardBackManager.shared.image(for: entry) {
        CroppedCardBackImage(image: image, entry: entry)
    } else {
        Color.gray.opacity(0.3)
    }
}
