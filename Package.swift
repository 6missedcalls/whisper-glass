// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WhisperGlass",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WhisperGlass", targets: ["WhisperGlassApp"]),
        .library(name: "WhisperGlassCore", targets: ["WhisperGlassCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", from: "1.0.0")
    ],
    targets: [
        // Core library — all non-UI logic, testable from CLI
        .target(
            name: "WhisperGlassCore",
            dependencies: [
                .product(name: "SwiftWhisper", package: "SwiftWhisper")
            ],
            path: "Sources",
            exclude: ["App"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // App executable — entry point, wires everything together
        .executableTarget(
            name: "WhisperGlassApp",
            dependencies: ["WhisperGlassCore"],
            path: "Sources/App",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Tests
        .testTarget(
            name: "AudioTests",
            dependencies: ["WhisperGlassCore"],
            path: "Tests/AudioTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "TranscriptionTests",
            dependencies: ["WhisperGlassCore"],
            path: "Tests/TranscriptionTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "InjectionTests",
            dependencies: ["WhisperGlassCore"],
            path: "Tests/InjectionTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SettingsTests",
            dependencies: ["WhisperGlassCore"],
            path: "Tests/SettingsTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
