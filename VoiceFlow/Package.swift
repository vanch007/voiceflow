// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/ivan-digital/qwen3-asr-swift.git", branch: "main"),
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
