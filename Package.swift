// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Musicfy",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/alexeichhorn/YouTubeKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Musicfy",
            dependencies: ["YouTubeKit"]
        )
    ]
)
