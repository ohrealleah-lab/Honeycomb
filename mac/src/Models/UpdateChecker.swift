import Foundation
import Observation
import Sparkle

// Thin wrapper around Sparkle's SPUStandardUpdaterController. Sparkle owns the actual
// check/download/verify/relaunch cycle, the automatic-check cadence (SUScheduledCheckInterval
// in Info.plist), and its own "skip this version" / last-checked persistence internally —
// this class used to hand-roll all of that against the raw GitHub API (see git history),
// which is redundant now that Sparkle does the same job natively with its own UI.
@Observable
public class UpdateChecker {
    public static let shared = UpdateChecker()

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    // Manual "Check for Updates" button (About page) — always live, shows Sparkle's own
    // native "a new version is available" / "you're up to date" alert.
    public func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
