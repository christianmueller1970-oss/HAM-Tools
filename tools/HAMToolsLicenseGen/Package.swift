// swift-tools-version: 5.9
import PackageDescription

// Mini-Helper für Christian: generiert signierte HAM-Tools-Lizenz-Strings.
// Privater Schlüssel liegt unter ~/Library/Application Support/HAM-Tools License Generator/
// und wird NIE in die App geleakt.
//
// Bauen + starten:
//   cd tools/HAMToolsLicenseGen
//   swift run HAMToolsLicenseGen
let package = Package(
    name: "HAMToolsLicenseGen",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HAMToolsLicenseGen",
            path: "Sources/HAMToolsLicenseGen"
        )
    ]
)
