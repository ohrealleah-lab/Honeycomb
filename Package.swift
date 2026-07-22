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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Honeycomb",
            dependencies: [],
            path: "src"
        ),
        .testTarget(
            name: "SoliBeeTests",
            dependencies: ["Honeycomb"],
            path: "SoliBeeTests"
        )
    ]
)
