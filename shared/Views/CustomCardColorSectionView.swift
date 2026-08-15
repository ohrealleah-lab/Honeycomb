import SwiftUI

struct CustomCardColorSectionView: View {
    @Binding var customCardColors: CustomCardColorGroup
    @State private var isShowingResetConfirm = false
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(coordinator.L(.customCardColorHeading))
                    .font(.system(.body).bold())
                Spacer()
                Button(coordinator.L(.reset)) {
                    isShowingResetConfirm = true
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .confirmationDialog(
                    coordinator.L(.resetCardColorsConfirmBody),
                    isPresented: $isShowingResetConfirm
                ) {
                    Button(coordinator.L(.reset), role: .destructive) { customCardColors.reset() }
                    Button(coordinator.L(.cancel), role: .cancel) { }
                }
            }

            VStack(spacing: 8) {
                HStack {
                    Text(coordinator.L(.cardBackgroundLabel))
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.backgroundColor)
                        .labelsHidden()
                }

                HStack {
                    Text(coordinator.L(.cardOutlineLabel))
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.outlineColor)
                        .labelsHidden()
                }

                HStack {
                    Text(coordinator.L(.blackSuitTextLabel))
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.blackSuitColor)
                        .labelsHidden()
                }

                HStack {
                    Text(coordinator.L(.redSuitTextLabel))
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.redSuitColor)
                        .labelsHidden()
                }

                HStack {
                    Text(coordinator.L(.hintHighlightLabel))
                        .font(.system(.body))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.hintHighlightColor)
                        .labelsHidden()
                }
            }
        }
    }
}
