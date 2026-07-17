import Foundation
import Observation

/// 拖放区域 ViewModel
@MainActor
@Observable
final class DropZoneViewModel {
    var isTargeted = false
    var lastDroppedCount = 0

    func validateURLs(_ urls: [URL]) -> [URL] {
        // 过滤出文件（排除目录）
        let fileManager = FileManager.default
        return urls.compactMap { url in
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                return nil
            }
            if isDirectory.boolValue {
                // 跳过目录，可以后续用于归档转换
                return nil
            }
            return url
        }
    }
}
