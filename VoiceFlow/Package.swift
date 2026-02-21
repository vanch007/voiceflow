// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "./local_packages/qwen3-asr-swift"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceFlow",
            dependencies: [
                .product(name: "Qwen3ASR", package: "qwen3-asr-swift"),
            ],
            path: "Sources",
            resources: [
                .copy("../Resources/Info.plist")
            ]
        ),
        .testTarget(
            name: "VoiceFlowTests",
            dependencies: ["VoiceFlow"],
            path: "Tests/VoiceFlowTests"
        )
    ]
)
