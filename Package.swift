// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ParakeetTranscriber",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ParakeetTranscriber", targets: ["ParakeetTranscriber"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "ParakeetTranscriber",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: ".",
            exclude: ["Tests", "dist", "script", ".codex", ".github", "Resources", "README.md", "appcast.xml"],
            sources: ["App", "Models", "Services", "Stores", "Support", "Views"]
        ),
        .testTarget(
            name: "ParakeetTranscriberTests",
            dependencies: ["ParakeetTranscriber"],
            path: "Tests"
        )
    ]
)
