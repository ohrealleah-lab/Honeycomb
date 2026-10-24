import Foundation

/// Where the custom card back / face art / background managers keep their image files:
/// ~/Library/Application Support/SoliBee/<folder>. `testOverride` is for tests only (the app
/// never sets it): it stands in for Application Support so tests can add and delete real
/// files without ever touching a player's own art.
enum AppSupportLocation {
    static var testOverride: URL?

    static var baseDirectory: URL {
        testOverride
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
