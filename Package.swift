// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenAI",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "OpenAI",
            targets: ["OpenAI"]),
    ],
    targets: [
        .target(
            name: "OpenAI",
            dependencies: []),
        .testTarget(
            name: "OpenAITests",
            dependencies: ["OpenAI"]),
    ]
)
