// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HAMRechner",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HAMRechner",
            path: "Sources/HAMRechner",
            resources: [
                .process("Assets.xcassets"),
                .process("Content")
            ],
            linkerSettings: [
                // Logbuch-SQLite: System-SQLite (macOS hat sqlite3 in /usr/lib)
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
