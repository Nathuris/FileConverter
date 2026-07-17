// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileConverter",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "FileConverter",
            targets: ["FileConverter"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FileConverter",
            path: "FileConverter",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
