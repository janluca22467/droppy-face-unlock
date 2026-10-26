// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FaceUnlock",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FaceUnlock", type: .dynamic, targets: ["FaceUnlock"])
    ],
    dependencies: [
        .package(url: "https://gitlab.com/droppyformac1/droppykit.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "FaceUnlock",
            dependencies: [.product(name: "DroppyKit", package: "droppykit")]
        ),
        .executableTarget(
            name: "FaceUnlockHarness",
            dependencies: [
                "FaceUnlock",
                .product(name: "DroppyKitHarness", package: "droppykit")
            ]
        )
    ]
)
