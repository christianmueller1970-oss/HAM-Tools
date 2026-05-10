// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HAMRechner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HAMRechner",
            path: "Sources/HAMRechner",
            resources: [
                .process("Assets.xcassets"),
                .process("Content")
            ]
        )
    ]
)
