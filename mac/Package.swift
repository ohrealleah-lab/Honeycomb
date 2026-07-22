// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Honeycomb",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Honeycomb", targets: ["Honeycomb"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        .executableTarget(
            name: "Honeycomb",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "src"
        ),
        .testTarget(
            name: "SoliBeeTests",
            dependencies: ["Honeycomb"],
            path: "SoliBeeTests"
        )
    ]
)
