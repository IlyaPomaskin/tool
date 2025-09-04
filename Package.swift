// swift-tools-version: 6.0
// swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mic-gpt",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.1.0"),
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.4.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "mic-gpt",
            dependencies: ["HotKey", "OpenAI"]
        ),
    ]
)
