// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PixelCanvas",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PixelCanvas",
            targets: ["PixelCanvas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/Canvas", from: "2.1.0"),
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "PixelCanvas",
            dependencies: [
                "Canvas",
                "CoreGraphicsExtensions",
            ]),
    ]
)
