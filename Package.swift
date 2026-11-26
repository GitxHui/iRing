// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AIStage",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "AIStage", targets: ["AIStage"]),
        .library(name: "AIStageCore", targets: ["AIStageCore"])
    ],
    dependencies: [
        .package(path: "Packages/Vortex")
    ],
    targets: [
        .target(
            name: "AIStageCore",
            path: "Sources/AIStage",
            exclude: ["App", "UI"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "AIStage",
            dependencies: [
                "AIStageCore",
                .product(name: "Vortex", package: "Vortex")
            ],
            path: "Sources/AIStage",
            exclude: ["Models", "Core"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "AIStageSelfTest",
            dependencies: ["AIStageCore"],
            path: "Tests/AIStageSelfTest",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
