import Foundation

/// 工具提供者协议 — Converter 通过它查询哪些工具可用
protocol ToolProviding: AnyObject, Sendable {
    /// 检查某个工具是否可用
    func isAvailable(_ toolName: String) -> Bool

    /// 获取工具的完整路径
    func path(for toolName: String) -> String?

    /// 获取工具版本
    func version(for toolName: String) -> String?

    /// 获取所有已检测到的工具信息
    func allAvailableTools() -> [ToolInfo]

    /// 获取所有未找到的工具信息（用于显示安装提示）
    func allMissingTools() -> [ToolInfo]

    /// 获取可用工具名称的集合
    func availableToolNames() -> Set<String>
}
