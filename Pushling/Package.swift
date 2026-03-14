// swift-tools-version: 5.9
// Pushling — Touch Bar Virtual Pet
// A menu-bar daemon that renders a SpriteKit creature on the Touch Bar.

import PackageDescription

let package = Package(
    name: "Pushling",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Pushling",
            path: "Sources/Pushling",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/System/Library/PrivateFrameworks"
                ])
            ]
        ),
        .testTarget(
            name: "PushlingTests",
            dependencies: ["Pushling"],
            path: "Tests/PushlingTests"
        )
    ]
)
