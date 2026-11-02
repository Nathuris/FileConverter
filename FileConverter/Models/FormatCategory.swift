import Foundation

/// 文件格式的大类别
enum FormatCategory: String, CaseIterable, Identifiable, Codable {
    case all = "全部"
    case images = "图片"
    case documents = "文档"
    case audio = "音频"
    case video = "视频"
    case archives = "归档"
    case textData = "文本数据"
    case ebooks = "电子书"
    case fonts = "字体"
    case cad3D = "3D 模型"

    var id: String { rawValue }

    /// SF Symbol 图标名称
    var sfSymbol: String {
        switch self {
        case .all:        return "doc.on.doc"
        case .images:     return "photo.on.rectangle"
        case .documents:  return "doc.text"
        case .audio:      return "waveform"
        case .video:      return "film"
        case .archives:   return "archivebox"
        case .textData:   return "tablecells"
        case .ebooks:     return "book"
        case .fonts:      return "character.textbox"
        case .cad3D:      return "cube.transparent"
        }
    }

    /// 类别对应的工具依赖（用于判断是否能工作）
    var requiredTools: [String] {
        switch self {
        case .all:        return []
        case .images:     return ["sips"]
        case .documents:  return ["textutil"]
        case .audio:      return ["afconvert"]
        case .video:      return ["ffmpeg"]
        case .archives:   return ["ditto"]
        case .textData:   return ["plutil"]
        case .ebooks:     return ["pandoc"]
        // 字体依赖 Python + fonttools 包；类别先以 python3 为准，转换器内部再查 fonttools
        case .fonts:      return ["python3"]
        // 3D 主要靠系统 Model I/O，不强制额外工具
        case .cad3D:      return []
        }
    }

    /// 此类别的核心转换器是否可用（至少有一个必需工具就可用）
    func isAvailable(given availableTools: Set<String>) -> Bool {
        guard !requiredTools.isEmpty else { return true }
        return requiredTools.contains { availableTools.contains($0) }
    }
}
