// swift-tools-version: 5.9
import PackageDescription

// Root package compiling the shared game logic (shared/) together with the macOS app
// (mac/src) as a single module — same flat-module layout the app has always used, just
// with the platform-agnostic code physically separated so the iOS app can compile the
// shared/ tree directly. Platform-specific code inside shared/ is fenced with
// `#if canImport(AppKit)`.
let package = Package(
    name: "Honeycomb",
    platforms: [
        .macOS(.v14), .iOS(.v17)
    ],
    products: [
        .executable(name: "Honeycomb", targets: ["Honeycomb"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Honeycomb",
            dependencies: [],
            path: ".",
            exclude: [
                // Non-source trees under the package root ("."), kept out of the scan
                // so SPM never warns about (or slows down on) their contents.
                "ios",
                "windows",
                "README.md",
                "count_cards.ps1",
                "parse_cards.ps1",
                // Resource files living inside the compiled source dirs.
                "mac/src/Info.plist",
                "mac/src/AppIcon.icns",
                "mac/src/priest.png",
                "mac/src/moogle.jpg",
                "mac/src/dingwall.jpg",
                "mac/src/shuffle.aiff",
                "mac/src/snap.aiff",
                "mac/src/victory.aiff",
            ],
            sources: ["shared", "mac/src"]
        ),
        .testTarget(
            name: "SoliBeeTests",
            dependencies: ["Honeycomb"],
            path: "mac/SoliBeeTests"
        )
    ]
)
