// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReaderPackages",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReaderDesign", targets: ["ReaderDesign"]),
        .library(name: "ReaderStore", targets: ["ReaderStore"]),
    ],
    targets: [
        .target(name: "ReaderDesign", path: "ReaderDesign/Sources/ReaderDesign", resources: [.copy("Resources/Fonts")]),
        .target(name: "ReaderStore", path: "ReaderStore/Sources/ReaderStore"),
        .testTarget(name: "ReaderStoreTests", dependencies: ["ReaderStore"], path: "ReaderStore/Tests/ReaderStoreTests"),
        .testTarget(name: "ReaderDesignTests", dependencies: ["ReaderDesign"], path: "ReaderDesign/Tests/ReaderDesignTests"),
    ],
    swiftLanguageModes: [.v6]
)
