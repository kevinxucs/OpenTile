// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "OpenTile", platforms: [.macOS(.v13)], products: [
    .library(name: "OpenTileCore", targets: ["OpenTileCore"]),
    .executable(name: "OpenTile", targets: ["OpenTile"])
], targets: [
    .target(name: "OpenTileCore"),
    .target(name: "OpenTileApp", dependencies: ["OpenTileCore"]),
    .executableTarget(name: "OpenTile", dependencies: ["OpenTileCore", "OpenTileApp"]),
    .testTarget(name: "OpenTileCoreTests", dependencies: ["OpenTileCore"], exclude: ["Fixtures"]),
    .testTarget(name: "OpenTileAppTests", dependencies: ["OpenTileApp"])
], swiftLanguageModes: [.v5])
