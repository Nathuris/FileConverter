import Foundation

/// 文件大小格式化工具
enum FileSizeFormatter {

    /// 格式化字节数为人类可读的文本
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    /// 格式化两个大小的对比
    static func compare(original: Int64, converted: Int64) -> String {
        let origStr = format(original)
        let convStr = format(converted)
        let diff = original - converted

        if diff > 0 {
            let saved = format(diff)
            return "\(origStr) → \(convStr)，节省 \(saved)"
        } else if diff < 0 {
            let added = format(-diff)
            return "\(origStr) → \(convStr)，增大 \(added)"
        } else {
            return "\(origStr) → \(convStr)，大小不变"
        }
    }

    /// 节省百分比
    static func savedPercent(original: Int64, converted: Int64) -> Double {
        guard original > 0 else { return 0 }
        return Double(original - converted) / Double(original) * 100
    }
}
