import SwiftUI

struct AboutHoneycombView: View {
    @State private var checker = UpdateChecker.shared
    @Environment(\.openURL) private var openURL

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

            checkForUpdatesSection
        }
        .padding(32)
        .frame(width: 320)
    }

    @ViewBuilder
    private var checkForUpdatesSection: some View {
        switch checker.manualCheckState {
        case .idle:
            Button("Check for Updates…") {
                checker.checkNow()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))

        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking for updates…")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .upToDate:
            VStack(spacing: 4) {
                Text("You're up to date.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button("Check Again") { checker.checkNow() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }

        case .failed:
            VStack(spacing: 4) {
                Text("Couldn't check for updates. Check your internet connection.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { checker.checkNow() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }

        case .newerAvailable(let outcome):
            VStack(spacing: 8) {
                Text("Version \(outcome.latestVersion) is available.")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 10) {
                    Button("Don't Ask Again") {
                        checker.declineUpdate()
                    }
                    Button("View Release") {
                        openURL(outcome.releaseURL)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
