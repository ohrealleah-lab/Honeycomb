import SwiftUI

/// Custom Card Color picker, its own full screen (matches mac's dedicated section) —
/// pulled out of ThemesFullScreenView's inline grid so it's a nav row + push, like Face
/// Card Art and Card Backs.
struct CustomCardColorsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 16)], spacing: 16) {
                    cardColorSwatch(coordinator.L(.redSuitTextLabel), binding: $coordinator.customCardColors.redSuitColor)
                    cardColorSwatch(coordinator.L(.blackSuitTextLabel), binding: $coordinator.customCardColors.blackSuitColor)
                    cardColorSwatch(coordinator.L(.cardBackgroundLabel), binding: $coordinator.customCardColors.backgroundColor)
                    cardColorSwatch(coordinator.L(.hintHighlightLabel), binding: $coordinator.customCardColors.hintHighlightColor)
                }
                .padding(16)
            }
            .navigationTitle(coordinator.L(.customCardColorHeading))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(coordinator.L(.reset)) {
                        coordinator.customCardColors.reset()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                }
            }
        }
    }

    private func cardColorSwatch(_ label: String, binding: Binding<Color>) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(binding.wrappedValue).frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                ColorPicker("", selection: binding)
                    .labelsHidden()
                    .opacity(0.02)
                    .frame(width: 54, height: 54)
                    .contentShape(Rectangle())
            }
            Text(label).font(.caption2.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
            Text(themeHexString(binding.wrappedValue)).font(.caption2.monospaced()).foregroundStyle(.secondary)
        }
    }
}
