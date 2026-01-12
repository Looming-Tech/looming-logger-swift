// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LoomingLogger",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "LoomingLogger",
            targets: ["LoomingLogger"]
        ),
    ],
    targets: [
        .target(
            name: "LoomingLogger",
            dependencies: [],
            path: "Sources/LoomingLogger"
        ),
        .testTarget(
            name: "LoomingLoggerTests",
            dependencies: ["LoomingLogger"],
            path: "Tests/LoomingLoggerTests"
        ),
    ]
)
