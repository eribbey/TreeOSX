// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftTree",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "SwiftTreeApp", targets: ["App"]),
        .executable(name: "swifttree", targets: ["CLI"])
    ],
    targets: [
        .target(
            name: "CoreC",
            path: "CoreC",
            sources: ["src"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "Core",
            dependencies: ["CoreC"],
            path: "Core"
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Core"],
            path: "App"
        ),
        .executableTarget(
            name: "CLI",
            dependencies: ["Core"],
            path: "CLI"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        )
    ]
)
