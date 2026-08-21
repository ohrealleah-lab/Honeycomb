import SwiftUI

struct AboutHoneycombView: View {
    @State private var checker = UpdateChecker.shared
    @Environment(\.openURL) private var openURL
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 10) {
            Text(coordinator.L(.appName))
                .font(.system(size: 32, weight: .black))

            Text(coordinator.L(.cardSuiteLabel))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(2)

            Divider().padding(.vertical, 4)

            Text(coordinator.L(.versionFmt, checker.currentVersion))
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text(coordinator.L(.copyrightNotice))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(coordinator.L(.dedication))
                .font(.system(size: 11))
                .italic()
                .foregroundColor(.secondary)
                .padding(.top, 2)

            Divider().padding(.vertical, 4)

            checkForUpdatesSection
        }
        .padding(32)
        .frame(width: 320)
        .background {
            if let image = NSImage(named: "Solibee") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.15)
            }
        }
    }

    @ViewBuilder
    private var checkForUpdatesSection: some View {
        switch checker.manualCheckState {
        case .idle:
            Button(coordinator.L(.checkForUpdates)) {
                checker.checkNow()
            }
            .buttonStyle(.link)
            .font(.system(size: 12))

        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(coordinator.L(.checkingForUpdates))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .upToDate:
            VStack(spacing: 4) {
                Text(coordinator.L(.upToDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button(coordinator.L(.checkAgain)) { checker.checkNow() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }

        case .failed:
            VStack(spacing: 4) {
                Text(coordinator.L(.updateCheckFailed))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button(coordinator.L(.tryAgain)) { checker.checkNow() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }

        case .newerAvailable(let outcome):
            VStack(spacing: 8) {
                Text(coordinator.L(.newerVersionAvailableFmt, outcome.latestVersion))
                    .font(.system(size: 12, weight: .semibold))
                Button(coordinator.L(.viewRelease)) {
                    openURL(outcome.releaseURL)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
