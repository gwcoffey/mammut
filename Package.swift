// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mammut",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mammut", targets: ["mammut"]),
        .library(name: "MastodonApi", targets: ["MastodonApi"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.20.0")
    ],
    targets: [
        .target(
            name: "MastodonApi",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "FlyingFox", package: "FlyingFox")
            ]),
        .executableTarget(
            name: "mammut",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                "MastodonApi"
            ]
        ),
        .testTarget(
            name: "mammutTests",
            dependencies: ["mammut"]
        ),
    ]
)
