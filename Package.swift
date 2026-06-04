// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexSoundGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexSoundGuard", targets: ["CodexSoundGuard"])
    ],
    targets: [
        .target(
            name: "CodexSoundGuardCore"
        ),
        .executableTarget(
            name: "CodexSoundGuard",
            dependencies: ["CodexSoundGuardCore"]
        ),
        .testTarget(
            name: "CodexSoundGuardCoreTests",
            dependencies: ["CodexSoundGuardCore"]
        )
    ]
)
