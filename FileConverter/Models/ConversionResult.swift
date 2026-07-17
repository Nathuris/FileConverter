import Foundation

/// 一次转换操作的结果
struct ConversionResult: Identifiable {
    let id = UUID()
    let sourceFile: ConversionFile
    let outputURL: URL
    let success: Bool
    let sourceSize: Int64
    let outputSize: Int64
    let duration: TimeInterval
    let errorMessage: String?

    /// 节省的空间（负值表示变大了）
    var savedBytes: Int64 {
        sourceSize - outputSize
    }

    /// 节省的百分比
    var savedPercent: Double {
        guard sourceSize > 0 else { return 0 }
        return Double(savedBytes) / Double(sourceSize) * 100
    }

    /// 是否变小了
    var isSmaller: Bool {
        outputSize < sourceSize
    }

    /// 输出文件名
    var outputFileName: String {
        outputURL.lastPathComponent
    }

    /// 耗时描述
    var durationText: String {
        if duration < 1 {
            return "不到 1 秒"
        } else if duration < 60 {
            return String(format: "%.1f 秒", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes) 分 \(seconds) 秒"
        }
    }

    /// 大小变化描述
    var sizeChangeText: String {
        if !success { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        let sourceStr = formatter.string(fromByteCount: sourceSize)
        let outputStr = formatter.string(fromByteCount: outputSize)

        if isSmaller {
            let savedStr = formatter.string(fromByteCount: savedBytes)
            return "\(sourceStr) → \(outputStr)（节省 \(savedStr)）"
        } else if savedBytes < 0 {
            let addedStr = formatter.string(fromByteCount: -savedBytes)
            return "\(sourceStr) → \(outputStr)（增大 \(addedStr)）"
        } else {
            return "\(sourceStr) → \(outputStr)（大小不变）"
        }
    }
}
