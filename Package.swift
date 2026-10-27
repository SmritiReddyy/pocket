// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pocket",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Pocket", targets: ["Pocket"]),
    ],
    targets: [
        .target(
            name: "NotchKit",
            path: "Sources/NotchKit"
        ),
        .executableTarget(
            name: "Pocket",
            dependencies: ["NotchKit"],
            path: "Sources/Pocket"
        ),
        .testTarget(
            name: "NotchKitTests",
            dependencies: ["NotchKit"],
            path: "Tests/NotchKitTests"
        ),
    ]
)
