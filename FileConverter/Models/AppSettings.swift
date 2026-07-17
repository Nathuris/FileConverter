import Foundation

/// 应用全局设置
struct AppSettings: Codable {
    /// 默认输出目录
    var defaultOutputDirectory: String = ""

    /// 默认转换设置
    var defaultConversionSettings: ConversionSettings = .default

    /// 最大并行转换数
    var maxConcurrentConversions: Int = ProcessInfo.processInfo.activeProcessorCount

    /// 自定义工具路径 [工具名: 路径]
    var customToolPaths: [String: String] = [:]

    /// 是否在转换完成后显示通知
    var showNotificationOnCompletion: Bool = true

    /// 是否在 Finder 中显示转换后的文件
    var revealInFinderAfterConversion: Bool = true

    /// 从 UserDefaults 加载
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "appSettings") else {
            return AppSettings()
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    /// 保存到 UserDefaults
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: "appSettings")
        } catch {
            print("无法保存设置：\(error.localizedDescription)")
        }
    }
}
