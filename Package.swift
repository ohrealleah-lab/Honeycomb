// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoliBee",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SoliBee", targets: ["SoliBee"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SoliBee",
            dependencies: [],
            path: "src"
        ),
        .testTarget(
            name: "SoliBeeTests",
            dependencies: ["SoliBee"],
            path: "SoliBeeTests"
        )
    ]
)
