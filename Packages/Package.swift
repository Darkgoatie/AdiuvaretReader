// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReaderPackages",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReaderDesign", targets: ["ReaderDesign"]),
        .library(name: "ReaderStore", targets: ["ReaderStore"]),
        .library(name: "ReaderFormats", targets: ["ReaderFormats"]),
        .library(name: "ReaderFiles", targets: ["ReaderFiles"]),
        .library(name: "ReaderAssistant", targets: ["ReaderAssistant"]),
    ],
    targets: [
        .target(name: "ReaderDesign", path: "ReaderDesign/Sources/ReaderDesign", resources: [.copy("Resources/Fonts")]),
        .target(name: "ReaderStore", path: "ReaderStore/Sources/ReaderStore"),
        .target(name: "ReaderFormats", path: "ReaderFormats/Sources/ReaderFormats"),
        .testTarget(name: "ReaderFormatsTests", dependencies: ["ReaderFormats"], path: "ReaderFormats/Tests/ReaderFormatsTests"),
        .target(name: "ReaderFiles", path: "ReaderFiles/Sources/ReaderFiles"),
        .testTarget(name: "ReaderFilesTests", dependencies: ["ReaderFiles"], path: "ReaderFiles/Tests/ReaderFilesTests"),
        .target(name: "ReaderAssistant", path: "ReaderAssistant/Sources/ReaderAssistant"),
        .testTarget(name: "ReaderAssistantTests", dependencies: ["ReaderAssistant"], path: "ReaderAssistant/Tests/ReaderAssistantTests"),
        .testTarget(name: "ReaderStoreTests", dependencies: ["ReaderStore"], path: "ReaderStore/Tests/ReaderStoreTests"),
        .testTarget(name: "ReaderDesignTests", dependencies: ["ReaderDesign"], path: "ReaderDesign/Tests/ReaderDesignTests"),
    ],
    swiftLanguageModes: [.v6]
)
