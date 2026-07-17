import Foundation
import UniformTypeIdentifiers

/// UTI (Uniform Type Identifier) 辅助工具
enum UTIHelper {

    /// 获取文件的 UTI
    static func typeIdentifier(of url: URL) -> String? {
        try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
    }

    /// 获取文件的 MIME 类型
    static func mimeType(of url: URL) -> String? {
        guard let identifier = typeIdentifier(of: url),
              let utType = UTType(identifier) else { return nil }
        return utType.preferredMIMEType
    }

    /// UTI 是否属于某个类别
    static func conforms(_ uti: String, to parentUTI: String) -> Bool {
        guard let type = UTType(uti),
              let parent = UTType(parentUTI) else { return false }
        return type.conforms(to: parent)
    }

    /// 文件扩展名是否匹配某个 UTI
    static func fileExtension(_ ext: String, matches uti: String) -> Bool {
        guard let type = UTType(uti) else { return false }
        return type.tags[.filenameExtension]?.contains(ext.lowercased()) == true
    }
}
