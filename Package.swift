// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Andon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Andon",
            path: "Sources/Andon"
        )
    ]
)
