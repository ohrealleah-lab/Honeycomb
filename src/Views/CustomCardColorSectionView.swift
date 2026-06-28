import SwiftUI

struct CustomCardColorSectionView: View {
    @Binding var customCardColors: CustomCardColorGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Card Color")
                    .font(.system(.body, design: .monospaced).bold())
                Spacer()
                Button("Reset") {
                    customCardColors.reset()
                }
                .font(.system(size: 12, design: .monospaced))
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Card Background")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.backgroundColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Card Outline")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.outlineColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Black Suit Text")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.blackSuitColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Red Suit Text")
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    ColorPicker("", selection: $customCardColors.redSuitColor)
                        .labelsHidden()
                }
            }
        }
    }
}
