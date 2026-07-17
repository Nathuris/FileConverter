import Foundation

/// 转换设置（每个文件独立或全局统一）
struct ConversionSettings: Codable {
    /// 图片质量 0.0 - 1.0
    var imageQuality: Double = 0.85

    /// 图片最大尺寸（像素），nil 表示保持原尺寸
    var imageMaxDimension: Int? = nil

    /// 音频比特率 kbps
    var audioBitrate: Int = 256

    /// 音频采样率 Hz
    var audioSampleRate: Int = 44100

    /// 视频比特率 kbps
    var videoBitrate: Int = 5000

    /// 视频分辨率预设
    var videoResolution: VideoResolution = .original

    /// 是否保留元数据（EXIF 等）
    var preserveMetadata: Bool = true

    /// 是否覆盖已存在的文件
    var overwriteExisting: Bool = false

    /// 视频分辨率选项
    enum VideoResolution: String, CaseIterable, Codable {
        case original = "原始尺寸"
        case uhd4K    = "4K (3840×2160)"
        case qhd1440p = "2K (2560×1440)"
        case fhd1080p = "1080p (1920×1080)"
        case hd720p   = "720p (1280×720)"
        case sd480p   = "480p (854×480)"

        var ffmpegScale: String? {
            switch self {
            case .original: return nil
            case .uhd4K:    return "3840:2160"
            case .qhd1440p: return "2560:1440"
            case .fhd1080p: return "1920:1080"
            case .hd720p:   return "1280:720"
            case .sd480p:   return "854:480"
            }
        }
    }

    static let `default` = ConversionSettings()
}
