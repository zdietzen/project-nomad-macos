// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NOMADMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NOMADMenuBar",
            path: "Sources/NOMADMenuBar",
            // Info.plist is injected into the .app bundle by the install script.
            // Exclude it here so SPM doesn't try to bundle it as a resource.
            exclude: ["Info.plist"]
        )
    ]
)
