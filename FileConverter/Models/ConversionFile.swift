import Foundation
import AppKit

/// 代表一个在转换队列中的文件
struct ConversionFile: Identifiable, Hashable {
    let id = UUID()
    let sourceURL: URL
    let detectedFormat: ConversionFormat
    var targetFormat: ConversionFormat
    var status: FileStatus = .pending
    var thumbnail: NSImage? = nil
    var fileSize: Int64 = 0

    /// 原文件名（不含路径）
    var fileName: String {
        sourceURL.lastPathComponent
    }

    /// 转换后的建议输出文件名
    var suggestedOutputName: String {
        let baseName = (sourceURL.deletingPathExtension().lastPathComponent)
        return "\(baseName).\(targetFormat.preferredExtension)"
    }

    /// 是否可预览
    var canPreview: Bool {
        switch detectedFormat.category {
        case .images, .textData:
            return true
        case .documents:
            return detectedFormat == .txt || detectedFormat == .markdown || detectedFormat == .html
        default:
            return false
        }
    }

    enum FileStatus: Hashable {
        case pending
        case converting
        case completed
        case failed(String)  // 错误信息

        var displayText: String {
            switch self {
            case .pending:    return "等待转换"
            case .converting: return "转换中…"
            case .completed:  return "已完成"
            case .failed(let msg): return "失败：\(msg)"
            }
        }
    }

    // hash 只用 id（保持 Set/Dictionary 查找性能与语义）
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // == 必须比较所有影响显示的字段，否则 SwiftUI 的 ForEach 会因 id 相同而
    // 误判元素未变化，导致 targetFormat 等改动后界面不刷新。
    // （Hashable 协议只要求「相等则 hash 相等」，所以 hash 用 id、== 比较多字段是合法的。）
    static func == (lhs: ConversionFile, rhs: ConversionFile) -> Bool {
        lhs.id == rhs.id &&
        lhs.detectedFormat == rhs.detectedFormat &&
        lhs.targetFormat == rhs.targetFormat &&
        lhs.status == rhs.status &&
        lhs.fileSize == rhs.fileSize
        // thumbnail (NSImage) 不参与比较：异步加载、指针比较不可靠，且其变化无需触发格式行刷新
    }
}
