import Foundation

/// 代表一个被检测到的命令行工具
struct ToolInfo: Identifiable, Codable {
    var id: String { name }

    /// 工具短名称，如 "ffmpeg"
    let name: String

    /// 显示名称，如 "FFmpeg"
    let displayName: String

    /// 可执行文件的绝对路径
    var path: String

    /// 版本号
    var version: String?

    /// 是否为 macOS 系统自带
    let isBuiltIn: Bool

    /// 安装说明（Homebrew 命令）
    let installCommand: String?

    /// 项目主页
    let homepage: String?

    /// 该工具解锁的功能描述
    let unlocksDescription: String

    /// 工具状态
    enum Status: String, Codable {
        case available       = "可用"
        case notFound        = "未找到"
        case outdatedVersion  = "版本过旧"

        var colorName: String {
            switch self {
            case .available:       return "green"
            case .notFound:        return "red"
            case .outdatedVersion: return "yellow"
            }
        }
    }

    var status: Status {
        if path.isEmpty || path == "not_found" { return .notFound }
        // 如果找不到路径对应的文件，也返回未找到
        if !FileManager.default.isExecutableFile(atPath: path) { return .notFound }
        return .available
    }
}
