// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vortex",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "Vortex",
            targets: ["Vortex"]
        )
    ],
    targets: [
        .target(
            name: "Vortex",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
