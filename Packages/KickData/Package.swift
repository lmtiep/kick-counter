// swift-tools-version: 6.0
import PackageDescription

// Requires Xcode (SwiftData macros); built and tested on CI only.
let package = Package(
    name: "KickData",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KickData", targets: ["KickData"])],
    dependencies: [.package(path: "../KickCore")],
    targets: [
        .target(name: "KickData", dependencies: ["KickCore"]),
        .testTarget(name: "KickDataTests", dependencies: ["KickData"], resources: [.copy("Fixtures")]),
    ]
)
