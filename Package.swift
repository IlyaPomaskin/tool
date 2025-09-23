// swift-tools-version: 6.0
// swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tool",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.1.0"),
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.4.0")
    ],
    targets: [
        .executableTarget(
            name: "tool",
            dependencies: ["HotKey", "OpenAI", "WhisperFramework"],
            path: "Sources"
        ),
        .binaryTarget(
            name: "WhisperFramework",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.5/whisper-v1.7.5-xcframework.zip",
            checksum: "c7faeb328620d6012e130f3d705c51a6ea6c995605f2df50f6e1ad68c59c6c4a"
        ),
    ]
)
