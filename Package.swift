// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Peekaboo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Peekaboo", targets: ["Peekaboo"]),
    ],
    targets: [
        .target(
            name: "NotchKit",
            path: "Sources/NotchKit"
        ),
        .executableTarget(
            name: "Peekaboo",
            dependencies: ["NotchKit"],
            path: "Sources/Peekaboo"
        ),
        .testTarget(
            name: "NotchKitTests",
            dependencies: ["NotchKit"],
            path: "Tests/NotchKitTests"
        ),
    ]
)
