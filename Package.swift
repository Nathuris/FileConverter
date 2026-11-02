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
            path: "FileConverter"
            // Info.plist / 图标由 package_dmg.sh、build_app.sh 手工拷进 .app，
            // 不走 SwiftPM 资源打包（仓库里的 Resources 在项目根目录）。
        )
    ]
)
