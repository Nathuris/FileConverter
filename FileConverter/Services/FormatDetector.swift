import Foundation
import UniformTypeIdentifiers

/// 文件格式识别服务
final class FormatDetector: Sendable {

    // MARK: - 格式识别

    /// 识别文件的格式
    /// 先用 UTType，失败则用扩展名匹配
    func detectFormat(of url: URL) -> ConversionFormat? {
        let ext = url.pathExtension.lowercased()

        // 1. 尝试用 UTType 识别
        if let utType = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
           let utt = UTType(utType) {
            if let format = matchByUTType(utt) {
                return format
            }
        }

        // 2. 通过文件扩展名创建 UTType 再试
        if let utt = UTType(filenameExtension: ext) {
            if let format = matchByUTType(utt) {
                return format
            }
        }

        // 3. 纯扩展名后备匹配
        return matchByExtension(ext)
    }

    /// 识别文件的类别
    func detectCategory(of url: URL) -> FormatCategory? {
        detectFormat(of: url)?.category
    }

    // MARK: - 通过 UTType 匹配

    private func matchByUTType(_ utType: UTType) -> ConversionFormat? {
        // 遍历所有格式，找到匹配的
        for format in ConversionFormat.allCases {
            guard let formatUT = format.utType else { continue }

            if utType.conforms(to: formatUT) || utType == formatUT {
                // 特殊处理：区分 RAW 格式
                if format.isRAW {
                    return format
                }
                return format
            }
        }

        // 对没有注册系统 UTI 的格式，先用自定义 UTI 字符串检查
        let customUTIs: [(String, ConversionFormat)] = [
            ("org.matroska.mkv", .mkv),
            ("org.xiph.flac", .flac),
            ("org.xiph.ogg", .ogg),
            ("com.apple.m4a-audio", .m4a),
            ("com.apple.m4a-alac", .alac),
            ("com.apple.m4v-video", .m4v),
            ("com.truevision.tga-image", .tga),
            ("com.ilm.openexr-image", .exr),
            ("com.adobe.photoshop-image", .psd),
            ("com.autodesk.stl", .stl),
            ("com.autodesk.obj", .obj),
            ("com.autodesk.fbx", .fbx),
            ("com.pixar.universal-scene-description-mobile", .usdz),
            ("public.aac-audio", .aac),
            ("public.tar-archive", .tar),
            ("public.xz-archive", .xz),
            ("public.cpio-archive", .cpio),
            ("public.avif", .avif),
            ("public.jpeg-2000", .jp2),
            ("public.truetype-font", .ttf),
            ("public.opentype-font", .otf),
        ]
        for (utiStr, format) in customUTIs {
            if let customUT = UTType(utiStr), utType.conforms(to: customUT) {
                return format
            }
        }

        // 标准系统 UTI 匹配（只对确实存在的 UTI 做检查）
        if utType.conforms(to: .jpeg) { return .jpeg }
        if utType.conforms(to: .png) { return .png }
        if utType.conforms(to: .gif) { return .gif }
        if utType.conforms(to: .bmp) { return .bmp }
        if utType.conforms(to: .tiff) { return .tiff }
        if utType.conforms(to: .heic) { return .heic }
        if utType.conforms(to: .pdf) { return .pdfDoc }
        if utType.conforms(to: .mp3) { return .mp3 }
        if utType.conforms(to: .wav) { return .wav }
        if utType.conforms(to: .mpeg4Movie) { return .mp4 }
        if utType.conforms(to: .quickTimeMovie) { return .mov }
        if utType.conforms(to: .avi) { return .avi }
        if utType.conforms(to: .zip) { return .zip }
        if utType.conforms(to: .json) { return .json }
        if utType.conforms(to: .xml) { return .xml }
        if utType.conforms(to: .commaSeparatedText) { return .csv }
        if utType.conforms(to: .epub) { return .epub }
        if utType.conforms(to: .gzip) { return .gz }
        if utType.conforms(to: .bz2) { return .bz2 }
        if utType.conforms(to: .aiff) { return .aiff }
        if utType.conforms(to: .icns) { return .icns }
        if utType.conforms(to: .svg) { return .svg }
        if utType.conforms(to: .webP) { return .webp }
        if utType.conforms(to: .ico) { return .ico }
        if utType.conforms(to: .propertyList) { return .plist }

        // 文本类格式（这些 UTI 在系统中是可靠的）
        if utType.conforms(to: .plainText) { return .txt }
        if utType.conforms(to: .rtf) { return .rtf }
        if utType.conforms(to: .html) { return .html }

        return nil
    }

    // MARK: - 通过扩展名匹配（后备）

    private func matchByExtension(_ ext: String) -> ConversionFormat? {
        switch ext {
        // 图片
        case "jpg", "jpeg":  return .jpeg
        case "png":          return .png
        case "gif":          return .gif
        case "bmp":          return .bmp
        case "tif", "tiff":  return .tiff
        case "heic", "heif": return .heic
        case "webp":         return .webp
        case "ico":          return .ico
        case "svg":          return .svg
        case "psd":          return .psd
        case "avif":         return .avif
        case "jp2", "jpx":   return .jp2
        case "jxl":          return .jxl
        case "tga":          return .tga
        case "exr":          return .exr
        case "dds":          return .dds
        case "icns":         return .icns
        // RAW
        case "cr2":          return .cr2
        case "nef":          return .nef
        case "arw":          return .arw
        case "dng":          return .dng
        case "orf":          return .orf
        case "raf":          return .raf
        case "rw2":          return .rw2
        case "pef":          return .pef

        // 文档
        case "docx":         return .docx
        case "doc":          return .doc
        case "rtf":          return .rtf
        case "rtfd":         return .rtfd
        case "txt":          return .txt
        case "md", "markdown": return .markdown
        case "htm", "html":  return .html
        case "odt":          return .odt
        case "pages":        return .pages
        case "pdf":          return .pdfDoc

        // 音频
        case "mp3":          return .mp3
        case "wav", "wave":  return .wav
        case "aac":          return .aac
        case "flac":         return .flac
        case "ogg", "oga":   return .ogg
        case "m4a":          return .m4a
        case "aif", "aiff":  return .aiff
        case "alac":         return .alac
        case "opus":         return .opus
        case "wma":          return .wma
        case "caf":          return .caf

        // 视频
        case "mp4", "mpeg4": return .mp4
        case "mov":          return .mov
        case "avi":          return .avi
        case "mkv":          return .mkv
        case "webm":         return .webm
        case "flv":          return .flv
        case "wmv":          return .wmv
        case "m4v":          return .m4v

        // 归档
        case "zip":          return .zip
        case "tar":          return .tar
        case "gz", "gzip":   return .gz
        case "bz2", "bzip2": return .bz2
        case "xz":           return .xz
        case "7z":           return .sevenZ
        case "rar":          return .rar
        case "dmg":          return .dmg
        case "cpio":         return .cpio

        // 文本数据
        case "csv":          return .csv
        case "json":         return .json
        case "xml":          return .xml
        case "plist":        return .plist
        case "yaml", "yml":  return .yaml
        case "tsv", "tab":   return .tsv

        // 电子书
        case "epub":         return .epub
        case "mobi":         return .mobi
        case "azw3", "azw":  return .azw3
        case "fb2":          return .fb2

        // 字体
        case "ttf":          return .ttf
        case "otf":          return .otf
        case "woff":         return .woff
        case "woff2":        return .woff2

        // 3D
        case "stl":          return .stl
        case "obj":          return .obj
        case "fbx":          return .fbx
        case "usdz":         return .usdz

        default:             return nil
        }
    }

    /// 检查一个格式是否被某个转换器支持
    func isFormat(_ format: ConversionFormat, supportedBy converter: FormatConverter) -> Bool {
        converter.supportedInputFormats().contains(format)
    }
}
