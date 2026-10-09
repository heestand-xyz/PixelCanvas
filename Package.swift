// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PixelCanvas",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PixelCanvas",
            targets: ["PixelCanvas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/AsyncGraphics", from: "3.2.2"),
        .package(url: "https://github.com/heestand-xyz/GestureCanvas", from: "1.5.3"),
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "2.0.1"),
        .package(url: "https://github.com/heestand-xyz/TextureMap", from: "2.2.1"),
    ],
    targets: [
        .target(
            name: "PixelCanvas",
            dependencies: [
                "AsyncGraphics",
                "GestureCanvas",
                "CoreGraphicsExtensions",
                "TextureMap",
            ]),
    ]
)
