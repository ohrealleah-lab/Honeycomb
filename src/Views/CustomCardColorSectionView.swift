import SwiftUI

struct CustomCardColorSectionView: View {
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator
    @Binding var customCardColors: CustomCardColorGroup
    @State private var isShowingResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Card Color")
                    .font(.system(.body).bold())
                Spacer()
                Button("Reset") {
                    isShowingResetConfirm = true
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .confirmationDialog(
                    "Are you sure you want to reset the card colors to default?",
                    isPresented: $isShowingResetConfirm
                ) {
                    Button("Reset", role: .destructive) { customCardColors.reset() }
                    Button("Cancel", role: .cancel) { }
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Card Background")
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.backgroundColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Card Outline")
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.outlineColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Black Suit Text")
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.blackSuitColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Red Suit Text")
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.redSuitColor)
                        .labelsHidden()
                }

                HStack {
                    Text("Honeycomb Player Highlight")
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { coordinator.honeycombPlayerHighlightColor },
                        set: { coordinator.honeycombPlayerHighlightColor = $0 }
                    ))
                    .labelsHidden()
                }

                HStack {
                    Text("Honeycomb Opponent Highlight")
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { coordinator.honeycombOpponentHighlightColor },
                        set: { coordinator.honeycombOpponentHighlightColor = $0 }
                    ))
                    .labelsHidden()
                }
            }
        }
    }
}
