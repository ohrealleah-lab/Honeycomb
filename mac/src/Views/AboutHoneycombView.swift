import SwiftUI

struct AboutHoneycombView: View {
    @State private var checker = UpdateChecker.shared

    private var versionString: String {
        "Version \(checker.currentVersion)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Honeycomb")
                .font(.system(size: 32, weight: .black))

            Text("CARD SUITE")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(2)

            Divider().padding(.vertical, 4)

            Text(versionString)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("© 2026 Leahbee. All rights reserved.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("For Rhinestone.")
                .font(.system(size: 11))
                .italic()
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Divider().padding(.vertical, 4)

            // Sparkle owns the actual check/download/install flow and shows its own
            // native alert from here — this button just kicks it off.
            Button("Check for Updates…") {
                checker.checkForUpdates()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
        }
        .padding(32)
        .frame(width: 320)
    }
}
