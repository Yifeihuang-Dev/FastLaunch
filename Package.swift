// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RightMenuHelper",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "RightMenuHelper",
            path: "Sources/RightMenuHelper"
        )
    ]
)
